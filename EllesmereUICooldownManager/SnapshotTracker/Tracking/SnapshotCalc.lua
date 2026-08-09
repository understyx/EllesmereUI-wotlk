local _, ns = ...
ns.SnapshotTracker = ns.SnapshotTracker or {}

-- Pure calculation functions for snapshot damage/crit modifiers.
-- These functions read WoW API state and return values without mutating
-- any module-level variables.  SnapshotTracker.lua uses them as delegates.

local SnapshotTracker = ns.SnapshotTracker.SnapshotTracker

-- Localize frequently-used globals
local pairs, ipairs, select, type = pairs, ipairs, select, type
local math_floor = math.floor
local string_match = string.match
local GetTime = GetTime
local UnitAura = UnitAura
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitDamage = UnitDamage
local UnitCreatureType = UnitCreatureType
local GetSpellCritChance = GetSpellCritChance
local GetTalentInfo = GetTalentInfo
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemLink = GetInventoryItemLink
local INVSLOT_HEAD = INVSLOT_HEAD

-- Minimap tracking API (C_Minimap in Classic, global in original WotLK)
local GetNumTrackingTypes = (C_Minimap and C_Minimap.GetNumTrackingTypes) or _G.GetNumTrackingTypes
local GetTrackingInfo = (C_Minimap and C_Minimap.GetTrackingInfo) or _G.GetTrackingInfo

-- Data table aliases (populated by SnapshotData.lua, which loads first)
local TARGET_UNIT                              = SnapshotTracker._TARGET_UNIT
local critSchools                              = SnapshotTracker._critSchools
local critChanceTalents                        = SnapshotTracker._critChanceTalents
local critChanceSetBonuses                     = SnapshotTracker._critChanceSetBonuses
local critModDamageBonusTalents                = SnapshotTracker._critModDamageBonusTalents
local critModDamageBonusBuffs                  = SnapshotTracker._critModDamageBonusBuffs
local critModDamageBonusSetBonuses             = SnapshotTracker._critModDamageBonusSetBonuses
local critModBuffs                             = SnapshotTracker._critModBuffs
local critModMetaGems                          = SnapshotTracker._critModMetaGems
local critChanceEnemyDebuffs                   = SnapshotTracker._critChanceEnemyDebuffs
local damageModBuffs                           = SnapshotTracker._damageModBuffs
local damageModDebuffs                         = SnapshotTracker._damageModDebuffs
local damageModTalents                         = SnapshotTracker._damageModTalents
local damageModSetBonuses                      = SnapshotTracker._damageModSetBonuses
local damageModWeaponEnchants                  = SnapshotTracker._damageModWeaponEnchants
local damageModExecuteTalents                  = SnapshotTracker._damageModExecuteTalents
local damageModTrackingTalents                 = SnapshotTracker._damageModTrackingTalents
local trackingSpells                           = SnapshotTracker._trackingSpells
local DelocalizeTracking                       = SnapshotTracker._DelocalizeTracking

local SnapshotCalc = {}
ns.SnapshotTracker.SnapshotCalc = SnapshotCalc

-- ==========================================================
-- CALCULATION: CRIT CHANCE
-- ==========================================================

--- Returns the player's effective spell crit chance including talents,
--- and target debuffs.
--- @param playerClass  string  WoW class token (e.g. "MAGE")
function SnapshotCalc.CalcCritChance(playerClass)
    local baseCrit = GetSpellCritChance(critSchools[playerClass] or 1)
    local now = GetTime()

    -- Talent-based crit (only one class-specific talent applies)
    local talentCrit = 0
    for indices, val in pairs(critChanceTalents[playerClass] or {}) do
        local talentIndex = indices % 100
        local tab = (indices - talentIndex) / 100
        local _, _, _, _, rank = GetTalentInfo(tab, talentIndex)
        if rank and rank > 0 then
            talentCrit = val * rank
            break -- only one talent applies per class
        end
    end

    -- Crit suppression based on target level
    local targetLevel = UnitLevel(TARGET_UNIT)
    local playerLevel = UnitLevel("player")
    if targetLevel == -1 then
        targetLevel = playerLevel + 3
    elseif targetLevel < playerLevel then
        targetLevel = playerLevel
    end
    local critSuppression = playerLevel - targetLevel

    -- Enemy debuffs that increase crit chance
    local critDebuff = 0
    for i = 1, 40 do
        local name, _, _, count, _, _, _, source, _, _, spellId =
            UnitAura(TARGET_UNIT, i, "HARMFUL")
        if not name then break end

        local debuffVal = critChanceEnemyDebuffs[spellId]
        if debuffVal then
            local stacks = count or 0
            if stacks == 0 then stacks = 1 end
            critDebuff = critDebuff + debuffVal * stacks
        end
    end

    -- Set-bonus crit
    local critSet = 0
    for _, func in ipairs(critChanceSetBonuses[playerClass] or {}) do
        local val = func()
        if val then critSet = critSet + val end
    end

    return baseCrit + talentCrit + critDebuff + critSuppression + critSet
end

-- ==========================================================
-- CALCULATION: CRIT DAMAGE MULTIPLIER
-- ==========================================================

--- Returns the periodic crit damage bonus multiplier for the player's class.
--- @param playerClass  string  WoW class token
function SnapshotCalc.CalcCritDamage(playerClass)
    local critDamageBonus = 0
    local critDamage = 1.5

    -- Talent-based periodic crit damage bonus (only one per class)
    for indices, val in pairs(critModDamageBonusTalents[playerClass] or {}) do
        local talentIndex = indices % 100
        local tab = (indices - talentIndex) / 100
        local _, _, _, _, rank = GetTalentInfo(tab, talentIndex)
        if rank and rank > 0 then
            critDamageBonus = val * rank
            break -- only one talent applies per class
        end
    end

    -- Buff-based periodic crit damage bonus (only used if no talent provides one)
    if critDamageBonus == 0 then
        local classBuffs = critModDamageBonusBuffs[playerClass]
        if classBuffs then
            for i = 1, 40 do
                local name, _, _, _, _, _, _, _, _, _, spellId =
                    UnitAura("player", i, "HELPFUL")
                if not name then break end
                local val = classBuffs[spellId]
                if val then
                    critDamageBonus = val
                    break -- only one buff source applies
                end
            end
        end
    end

    -- Set-bonus periodic crit damage bonus (fallback)
    if critDamageBonus == 0 then
        for _, func in ipairs(critModDamageBonusSetBonuses[playerClass] or {}) do
            local val = func()
            if val then critDamageBonus = val end
        end
    end

    if critDamageBonus == 0 then
        return 0
    end

    -- Buffs that multiply the crit damage value
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId =
            UnitAura("player", i, "HELPFUL")
        if not name then break end
        local val = critModBuffs[spellId]
        if not val and critModBuffs[playerClass] then
            val = critModBuffs[playerClass][spellId]
        end
        if val then
            critDamage = critDamage * (1 + val)
            break
        end
    end

    -- Meta gem crit damage multiplier
    if INVSLOT_HEAD then
        local link = GetInventoryItemLink("player", INVSLOT_HEAD)
        if link then
            local g1, g2, g3, g4 = string_match(link,
                "item:%d+:[^:]*:([^:]*):([^:]*):([^:]*):([^:]*)")
            local gems = { g1, g2, g3, g4 }
            for _, gem in ipairs(gems) do
                if gem then
                    local val = critModMetaGems[gem]
                    if val then
                        critDamage = critDamage * (1 + val)
                        break
                    end
                end
            end
        end
    end

    return (critDamage - 1) * critDamageBonus
end

-- ==========================================================
-- CALCULATION: TRACKING CHECK (pure WoW API query)
-- ==========================================================

--- Returns true if the player is actively tracking a creature type that
--- matches the target's creature type.
function SnapshotCalc.IsTrackingTarget()
    if not GetNumTrackingTypes or not GetTrackingInfo then
        return false
    end
    for i = 1, GetNumTrackingTypes() do
        local _, _, active, _, _, spellID = GetTrackingInfo(i)
        -- Tracking types without spell IDs (e.g. herbs, minerals) come after
        -- creature-tracking spells; stop once we reach them.
        if not spellID then break end
        if active then
            local creatureType = trackingSpells[spellID]
            -- Active tracking is not a creature-type spell (e.g. Find Fish)
            if not creatureType then break end
            return DelocalizeTracking(UnitCreatureType(TARGET_UNIT)) == creatureType
        end
    end
    return false
end

-- ==========================================================
-- CALCULATION: DAMAGE MODIFIER
-- ==========================================================

--- Returns the combined damage modifier for the player's current buffs,
--- debuffs, talents, set bonuses, weapon enchants, and situational bonuses.
--- @param playerClass  string  WoW class token
function SnapshotCalc.CalcDamageMod(playerClass)
    local damageMod = select(7, UnitDamage("player")) or 1

    -- Player buff modifiers (class-specific)
    local classBuffs = damageModBuffs[playerClass]
    if classBuffs then
        for i = 1, 40 do
            local name, _, _, count, _, _, _, _, _, _, spellId =
                UnitAura("player", i, "HELPFUL")
            if not name then break end
            local val = classBuffs[spellId]
            if val then
                local stacks = count or 0
                if stacks == 0 then stacks = 1 end
                damageMod = damageMod * (1 + val * stacks)
            end
        end
    end

    -- Player debuff modifiers (generic + class-specific)
    local classDebuffs = type(damageModDebuffs[playerClass]) == "table"
        and damageModDebuffs[playerClass] or nil
    for i = 1, 40 do
        local name, _, _, count, _, _, _, _, _, _, spellId =
            UnitAura("player", i, "HARMFUL")
        if not name then break end
        local val = damageModDebuffs[spellId]
        if not val and classDebuffs then
            val = classDebuffs[spellId]
        end
        if val then
            local stacks = count or 0
            if stacks == 0 then stacks = 1 end
            damageMod = damageMod * (1 + val * stacks)
        end
    end

    -- Talent modifiers
    for indices, val in pairs(damageModTalents[playerClass] or {}) do
        local talentIndex = indices % 100
        local tab = (indices - talentIndex) / 100
        local _, _, _, _, rank = GetTalentInfo(tab, talentIndex)
        if rank and rank > 0 then
            damageMod = damageMod * (1 + val * rank)
            break
        end
    end

    -- Set-bonus modifiers
    for _, func in ipairs(damageModSetBonuses[playerClass] or {}) do
        local val = func()
        if val then damageMod = damageMod * (1 + val) end
    end

    -- Weapon enchant modifiers
    local hasEnchant, _, _, enchantID = GetWeaponEnchantInfo()
    if hasEnchant and enchantID then
        local classEnchants = damageModWeaponEnchants[playerClass]
        local val = classEnchants and classEnchants[enchantID]
        if val then damageMod = damageMod * (1 + val) end
    end

    -- Execute-range talent modifiers
    for indices, val in pairs(damageModExecuteTalents[playerClass] or {}) do
        local talentIndex = indices % 100
        local tab = (indices - talentIndex) / 100
        local _, _, _, _, rank = GetTalentInfo(tab, talentIndex)
        if rank and rank > 0 then
            local maxHP = UnitHealthMax(TARGET_UNIT)
            if maxHP and maxHP > 0 and UnitHealth(TARGET_UNIT) / maxHP <= 0.35 then
                damageMod = damageMod * (1 + val * rank)
            end
            break
        end
    end

    -- Tracking talent modifiers (Hunter)
    for indices, val in pairs(damageModTrackingTalents[playerClass] or {}) do
        local talentIndex = indices % 100
        local tab = (indices - talentIndex) / 100
        local _, _, _, _, rank = GetTalentInfo(tab, talentIndex)
        if rank and rank > 0 then
            if SnapshotCalc.IsTrackingTarget() then
                damageMod = damageMod * (1 + val * rank)
            end
            break
        end
    end

    return damageMod
end
