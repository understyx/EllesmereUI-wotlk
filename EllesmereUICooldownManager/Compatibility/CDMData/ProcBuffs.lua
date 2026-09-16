local addonName, ns = ...

if not C_CooldownViewer or not C_CooldownViewer.RegisterDefinition then return end

-------------------------------------------------------------------------------
-- Class-relevant proc aura catalogue
--
-- Class files contain the original dump's proc coverage. This file fills the
-- important talent gaps and adds item-set proc auras. These entries are kept
-- class-scoped rather than spec/gear-scoped so the picker remains a complete
-- catalogue and can be configured before changing talents or equipment. The
-- runtime frame still appears only while its aura is active (unless the user
-- explicitly enables inactive buff placeholders).
-------------------------------------------------------------------------------

local CDM_CATEGORY_BUFF_ICON = 3
local nextTalentID = 0
local nextSetID = 0

local function CopyIDs(ids)
    local result = {}
    for _, spellID in ipairs(ids or {}) do
        result[#result + 1] = spellID
    end
    return result
end

local function RegisterTalentProc(class, key, spellID, auraSpellIDs, displayName)
    nextTalentID = nextTalentID + 1
    local aliases = CopyIDs(auraSpellIDs)
    if #aliases == 0 then aliases[1] = spellID end

    C_CooldownViewer.RegisterDefinition({
        key = "talent_proc." .. string.lower(class) .. "." .. key,
        -- Owner 13 is reserved for supplementary talent proc auras.
        cooldownID = 213000 + nextTalentID,
        category = CDM_CATEGORY_BUFF_ICON,
        order = 2000 + nextTalentID,

        spellID = spellID,
        auraSpellID = spellID,
        auraSpellIDs = aliases,
        linkedSpellIDs = aliases,
        iconSpellID = spellID,
        displayName = displayName,

        trackingType = "aura",
        hasAura = true,
        selfAura = true,
        class = class,
        isTalentProc = true,
        procSource = "talent",
        buffCatalogSection = "talent",

        -- Proc aura IDs are not normal spellbook entries. Class ownership makes
        -- them picker-available; the aura scan decides whether they are active.
        resolvers = {
            requirements = function() return true end,
            resolveSpellID = function() return spellID end,
        },
    })
end

local function RegisterSetProc(class, key, spellID, displayName, auraSpellIDs)
    nextSetID = nextSetID + 1
    local aliases = CopyIDs(auraSpellIDs)
    if #aliases == 0 then aliases[1] = spellID end

    C_CooldownViewer.RegisterDefinition({
        key = "item_set_proc." .. string.lower(class) .. "." .. key,
        -- Owner 14 is reserved for item-set proc auras.
        cooldownID = 214000 + nextSetID,
        category = CDM_CATEGORY_BUFF_ICON,
        order = 3000 + nextSetID,

        spellID = spellID,
        auraSpellID = spellID,
        auraSpellIDs = aliases,
        linkedSpellIDs = aliases,
        iconSpellID = spellID,
        displayName = displayName,

        trackingType = "aura",
        hasAura = true,
        selfAura = true,
        class = class,
        isItemSetProc = true,
        procSource = "item_set",
        buffCatalogSection = "item_set",

        resolvers = {
            requirements = function() return true end,
            resolveSpellID = function() return spellID end,
        },
    })
end

-- Death Knight talent procs.
RegisterTalentProc("DEATHKNIGHT", "sudden_doom", 49530, { 49530 })
RegisterTalentProc("DEATHKNIGHT", "scent_of_blood", 50421, { 50421, 50422 })
RegisterTalentProc("DEATHKNIGHT", "bloody_vengeance", 50447, { 50447 })
RegisterTalentProc("DEATHKNIGHT", "acclimation", 49200, { 49200 })
RegisterTalentProc("DEATHKNIGHT", "icy_talons", 50887, { 50887 })

-- Warrior talent procs not present in the original class dump.
RegisterTalentProc("WARRIOR", "sudden_death", 52437, { 29724, 52437 })
RegisterTalentProc("WARRIOR", "sword_and_board", 50227, { 50227 })
RegisterTalentProc("WARRIOR", "taste_for_blood", 60503, { 60503 })
RegisterTalentProc("WARRIOR", "wrecking_crew", 57518, { 57518 })

-- Hunter talent procs.
RegisterTalentProc("HUNTER", "rapid_killing", 35099, { 35098, 35099 })
RegisterTalentProc("HUNTER", "quick_shots", 6150, { 6150 })
RegisterTalentProc("HUNTER", "master_tactician", 34839, { 34837, 34838, 34839 })
RegisterTalentProc("HUNTER", "sniper_training", 53304, { 53302, 53303, 53304 })

-- Priest talent procs.
RegisterTalentProc("PRIEST", "holy_concentration", 34860, { 34860 })
RegisterTalentProc("PRIEST", "serendipity", 63737, { 63731, 63735, 63737 })
RegisterTalentProc("PRIEST", "improved_spirit_tap", 59000, { 59000 })

-- Shaman talent procs.
RegisterTalentProc("SHAMAN", "flurry", 16280,
    { 16257, 16277, 16278, 16279, 16280 })
RegisterTalentProc("SHAMAN", "elemental_devastation", 29180,
    { 29177, 29178, 29179, 29180 })

-- Mage talent procs.
RegisterTalentProc("MAGE", "clearcasting", 12536, { 12536 })
RegisterTalentProc("MAGE", "arcane_potency", 57529, { 57529, 57531 })
RegisterTalentProc("MAGE", "firestarter", 54741, { 54741 })
RegisterTalentProc("MAGE", "impact", 64343, { 64343 })

-- Warlock talent procs.
RegisterTalentProc("WARLOCK", "eradication", 64371, { 64368, 64370, 64371 })
RegisterTalentProc("WARLOCK", "empowered_imp", 47283, { 47283 })
RegisterTalentProc("WARLOCK", "pyroclasm", 63244, { 18093, 63243, 63244 })

-- Druid talent procs.
RegisterTalentProc("DRUID", "natures_grace", 16886, { 16886 })
RegisterTalentProc("DRUID", "owlkin_frenzy", 48391, { 48391 })

-- Item-set auras. Only bonuses which produce a player-visible timed aura are
-- listed; passive damage modifiers and instant resource/cooldown effects are
-- intentionally omitted because there is no buff state for CDM to display.
RegisterSetProc("DEATHKNIGHT", "t9_damage_2p", 67117,
    "Thassarian/Koltira Battlegear 2P")
RegisterSetProc("DEATHKNIGHT", "t10_damage_4p", 70657,
    "Scourgelord Battlegear 4P")
RegisterSetProc("DEATHKNIGHT", "t10_tank_4p", 70654,
    "Scourgelord Plate 4P")

RegisterSetProc("WARRIOR", "t7_damage_4p", 61571,
    "Dreadnaught Battlegear 4P")
RegisterSetProc("WARRIOR", "t8_damage_2p", 64937,
    "Siegebreaker Battlegear 2P")
RegisterSetProc("WARRIOR", "t10_damage_2p", 70855,
    "Ymirjar Lord Battlegear 2P")
RegisterSetProc("WARRIOR", "t10_damage_4p", 70847,
    "Ymirjar Lord Battlegear 4P")
RegisterSetProc("WARRIOR", "t10_tank_4p", 70845,
    "Ymirjar Lord Plate 4P")

RegisterSetProc("PALADIN", "t10_tank_4p", 70760,
    "Lightsworn Plate 4P")

RegisterSetProc("HUNTER", "t8_4p", 64861,
    "Scourgestalker Battlegear 4P")

RegisterSetProc("ROGUE", "t9_2p", 67209,
    "VanCleef/Garona Battlegear 2P")

RegisterSetProc("PRIEST", "t8_shadow_4p", 64907,
    "Sanctification Garb 4P")
RegisterSetProc("PRIEST", "t8_healing_4p", 64912,
    "Sanctification Regalia 4P")

RegisterSetProc("SHAMAN", "t10_enhancement_4p", 70831,
    "Frost Witch Battlegear 4P")

RegisterSetProc("MAGE", "t8_2p", 64868,
    "Kirin Tor Garb 2P")
RegisterSetProc("MAGE", "t10_2p", 70752,
    "Bloodmage Regalia 2P")

RegisterSetProc("WARLOCK", "t7_2p", 61595,
    "Plagueheart Garb 2P")
RegisterSetProc("WARLOCK", "t7_4p", 61082,
    "Plagueheart Garb 4P")
RegisterSetProc("WARLOCK", "t10_4p", 70840,
    "Dark Coven Regalia 4P")

RegisterSetProc("DRUID", "t8_balance_4p", 64823,
    "Nightsong Garb 4P")
RegisterSetProc("DRUID", "t10_balance_2p", 70718,
    "Lasherweave Regalia 2P")
