local _, ns = ...
ns.SnapshotTracker = ns.SnapshotTracker or {}

local SnapshotTracker = ns.SnapshotTracker.SnapshotTracker

-- Localize frequently-used globals
local pairs, ipairs, select, type = pairs, ipairs, select, type
local math_floor = math.floor
local string_format = string.format
local GetTime = GetTime
local UnitAura = UnitAura
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local GetLocale = GetLocale

-- Module-private state
local playerClass = nil
local playerGUID = nil
local snapshots = {}        -- [destGUID][spellName] = { damageMod, critChance }
local recentDirectDotCasts = {} -- [destGUID][dotSpellId] = expiryTime
local DIRECT_CAST_WINDOW = 2

-- Per-frame cache for expensive calculations
local cachedDamageMod, cachedCritChance, cachedCritDamage
local cacheTime = 0
local CACHE_TTL = 0.25
-- Start dirty so the first query triggers a full calculation.
local cacheIsDirty = true


-- ==========================================================
-- HELPERS
-- ==========================================================

local function Round(num, nearest)
    nearest = nearest or 1
    local lower = math_floor(num / nearest) * nearest
    local upper = lower + nearest
    return (upper - num < num - lower) and upper or lower
end

-- Aliases for data tables defined in SnapshotData.lua (still needed here)
local TARGET_UNIT             = SnapshotTracker._TARGET_UNIT
local noRecalcOnRefresh       = SnapshotTracker._noRecalcOnRefresh
local indirectApplicators     = SnapshotTracker._indirectApplicators

-- ==========================================================
-- INITIALIZATION
-- ==========================================================

function SnapshotTracker:Init(controller)
    self.controller = controller
    playerGUID = UnitGUID("player")
    playerClass = select(2, UnitClass("player"))
end

function SnapshotTracker:ResetPlayerInfo()
    playerGUID = UnitGUID("player")
    playerClass = select(2, UnitClass("player"))
end

-- ==========================================================
-- CALCULATION DELEGATES  (pure math lives in SnapshotCalc.lua)
-- ==========================================================

function SnapshotTracker:GetCritChance()
    local SC = ns.SnapshotTracker.SnapshotCalc
    return SC.CalcCritChance(playerClass)
end

function SnapshotTracker:GetCritDamage()
    local SC = ns.SnapshotTracker.SnapshotCalc
    return SC.CalcCritDamage(playerClass)
end

function SnapshotTracker:IsTrackingTarget()
    local SC = ns.SnapshotTracker.SnapshotCalc
    return SC.IsTrackingTarget()
end

function SnapshotTracker:GetDamageMod()
    local SC = ns.SnapshotTracker.SnapshotCalc
    return SC.CalcDamageMod(playerClass)
end

-- ==========================================================
-- CACHED CALCULATION ACCESS
-- ==========================================================

local function GetCachedValues(self)
    local now = GetTime()
    if cacheIsDirty or (now - cacheTime > CACHE_TTL) then
        cachedDamageMod = self:GetDamageMod()
        cachedCritChance = self:GetCritChance()
        cachedCritDamage = self:GetCritDamage()
        cacheTime = now
        cacheIsDirty = false
    end
    return cachedDamageMod, cachedCritChance, cachedCritDamage
end

function SnapshotTracker:InvalidateCache()
    cacheIsDirty = true
end

-- ==========================================================
-- CLEU EVENT HANDLING
-- ==========================================================

function SnapshotTracker:ProcessEvent(subEvent, sourceGUID, destGUID, spellId, spellName)
    -- UNIT_DIED has no source; clean up regardless
    if subEvent == "UNIT_DIED" then
        if destGUID then
            snapshots[destGUID] = nil
            recentDirectDotCasts[destGUID] = nil
        end
        return
    end

    if subEvent == "SPELL_CAST_SUCCESS" then
        -- Track direct casts of noRecalcOnRefresh DoTs so we can
        -- distinguish manual recasts from talent/glyph refreshes.
        if sourceGUID == playerGUID and destGUID then
            local dotId = noRecalcOnRefresh[spellId] and spellId
                          or indirectApplicators[spellId]
            if dotId then
                if not recentDirectDotCasts[destGUID] then
                    recentDirectDotCasts[destGUID] = {}
                end
                recentDirectDotCasts[destGUID][dotId] = GetTime() + DIRECT_CAST_WINDOW
            end
        end
        return
    end

    -- For aura events, only track player-applied auras (no whitelist)
    if sourceGUID ~= playerGUID then return end

    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
        if not spellName then return end
        -- Talent/glyph refreshes only extend the timer; they do not
        -- reapply the aura, so damage and crit snapshots stay unchanged.
        -- A manual recast (recent SPELL_CAST_SUCCESS for the same DoT)
        -- is allowed through so the snapshot is recalculated.
        if subEvent == "SPELL_AURA_REFRESH" and noRecalcOnRefresh[spellId]
           and snapshots[destGUID] and snapshots[destGUID][spellName] then
            local casts = recentDirectDotCasts[destGUID]
            local isDirectCast = casts and casts[spellId]
                                 and casts[spellId] > GetTime()
            if isDirectCast then
                casts[spellId] = nil  -- consume the flag
            else
                return  -- talent/glyph refresh: keep existing snapshot
            end
        end
        if not snapshots[destGUID] then
            snapshots[destGUID] = {}
        end
        self:InvalidateCache()
        local damageMod, critChance = GetCachedValues(self)
        snapshots[destGUID][spellName] = {
            damageMod  = damageMod,
            critChance = critChance,
        }
    elseif subEvent == "SPELL_AURA_REMOVED" then
        if spellName and snapshots[destGUID] then
            snapshots[destGUID][spellName] = nil
        end
    end
end

function SnapshotTracker:HandleCLEU(...)
    -- WotLK 3.3.5 CLEU format: timestamp(1), subEvent(2), sourceGUID(3),
    -- sourceName(4), sourceFlags(5), destGUID(6), destName(7), destFlags(8),
    -- spellId(9), spellName(10), spellSchool(11), ...
    local _, subEvent, sourceGUID, _, _, destGUID, _, _, spellId, spellName = ...

    if subEvent then
        self:ProcessEvent(subEvent, sourceGUID, destGUID, spellId, spellName)
    end
end

-- ==========================================================
-- QUERY API
-- ==========================================================

function SnapshotTracker:GetSnapshotDiff(unit, spellName)
    if not unit or not spellName then return nil end

    local guid = UnitGUID(unit)
    if not guid then return nil end

    local unitSnaps = snapshots[guid]
    if not unitSnaps then return nil end

    local snap = unitSnaps[spellName]
    if not snap then return nil end

    local damageMod, critChance, critDamage = GetCachedValues(self)

    -- critDamage (from talents/set bonuses) is intentionally shared between
    -- expected and current calculations: these modifiers are semi-permanent
    -- and don't change between DoT application and now. Only damageMod and
    -- critChance (which change with temporary buffs/debuffs) are snapshotted.
    local expectedTick = (100 + critChance * critDamage) * damageMod
    local currentTick  = (100 + snap.critChance * critDamage) * snap.damageMod

    if currentTick == 0 then return nil end

    local diff = Round((expectedTick / currentTick - 1) * 100, 0.1)

    if diff > 0 then
        return "|cff00ff00+" .. string_format("%.1f", diff) .. "%|r"
    elseif diff < 0 then
        return "|cffff0000" .. string_format("%.1f", diff) .. "%|r"
    end
    return nil  -- no diff worth showing at exactly 0
end

function SnapshotTracker:HasSnapshot(unit, spellName)
    if not unit or not spellName then return false end
    local guid = UnitGUID(unit)
    if not guid then return false end
    return snapshots[guid] and snapshots[guid][spellName] ~= nil
end
