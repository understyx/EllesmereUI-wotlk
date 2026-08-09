local addonName, ns = ...

if not C_CooldownViewer or not C_CooldownViewer.RegisterDefinition then return end

local CDM_CATEGORY_ESSENTIAL = 1
local CDM_CATEGORY_UTILITY   = 2
local CDM_CATEGORY_BUFF_ICON = 3
local CDM_CATEGORY_BUFF_BAR  = 4

local function HasLearnedTalent(tabIndex, talentIndex)
    if not GetTalentInfo or not GetNumTalentTabs or not GetNumTalents then
        return false
    end
    if tabIndex > GetNumTalentTabs() or talentIndex > GetNumTalents(tabIndex) then
        return false
    end
    local _, _, _, _, rank = GetTalentInfo(tabIndex, talentIndex)
    return (rank or 0) > 0
end

-- Rogue = class 04. Cooldowns = 104XXX, Buffs/Procs = 204XXX.
-- Talent indices are the stable GetTalentInfo(tab, index) positions from the
-- 3.3.5a (12340) Rogue trees. Aura-only proc IDs are resolved through the
-- owning talent because proc auras themselves are not spellbook entries.

local AURA_TAGS = {
    ["rogue.evasion"] = { defensive = true },
    ["rogue.cloak_of_shadows"] = { defensive = true },
    ["rogue.tricks_of_the_trade"] = { external = true },
    ["rogue.cheating_death"] = { defensive = true },
    ["rogue.evasion_buff"] = { defensive = true },
    ["rogue.cloak_of_shadows_buff"] = { defensive = true },
    ["rogue.tricks_of_the_trade_buff"] = { external = true },
}

local function Register(def)
    def.class = "ROGUE"
    def.auraTags = def.auraTags or AURA_TAGS[def.key]
    C_CooldownViewer.RegisterDefinition(def)
end

-- Major cooldowns
Register({
    key = "rogue.adrenaline_rush",
    cooldownID = 104001,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 10,
    spellID = 13750,
    iconSpellID = 13750,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 20) -- Combat: Adrenaline Rush
        end,
        resolveSpellID = function()
            return 13750
        end,
    },
})

Register({
    key = "rogue.killing_spree",
    cooldownID = 104002,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 20,
    spellID = 51690,
    iconSpellID = 51690,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 28) -- Combat: Killing Spree
        end,
        resolveSpellID = function()
            return 51690
        end,
    },
})

Register({
    key = "rogue.shadow_dance",
    cooldownID = 104003,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 30,
    spellID = 51713,
    iconSpellID = 51713,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 28) -- Subtlety: Shadow Dance
        end,
        resolveSpellID = function()
            return 51713
        end,
    },
})

Register({
    key = "rogue.cold_blood",
    cooldownID = 104005,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 50,
    spellID = 14177,
    iconSpellID = 14177,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 13) -- Assassination: Cold Blood
        end,
        resolveSpellID = function()
            return 14177
        end,
    },
})

Register({
    key = "rogue.preparation",
    cooldownID = 104006,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 60,
    spellID = 14185,
    iconSpellID = 14185,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 14) -- Subtlety: Preparation
        end,
        resolveSpellID = function()
            return 14185
        end,
    },
})

Register({
    key = "rogue.hunger_for_blood",
    cooldownID = 104007,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 70,
    spellID = 51662,
    iconSpellID = 51662,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 27) -- Assassination: Hunger for Blood
        end,
        resolveSpellID = function()
            return 51662
        end,
    },
})

-- Defensive / utility
Register({
    key = "rogue.evasion",
    cooldownID = 104008,
    category = CDM_CATEGORY_UTILITY,
    order = 10,
    spellID = 26669,
    iconSpellID = 26669,
    trackingType = "cooldown",
})

Register({
    key = "rogue.cloak_of_shadows",
    cooldownID = 104009,
    category = CDM_CATEGORY_UTILITY,
    order = 20,
    spellID = 31224,
    iconSpellID = 31224,
    trackingType = "cooldown",
})

Register({
    key = "rogue.vanish",
    cooldownID = 104010,
    category = CDM_CATEGORY_UTILITY,
    order = 30,
    spellID = 26889,
    iconSpellID = 26889,
    trackingType = "cooldown",
})

Register({
    key = "rogue.sprint",
    cooldownID = 104011,
    category = CDM_CATEGORY_UTILITY,
    order = 40,
    spellID = 11305,
    iconSpellID = 11305,
    trackingType = "cooldown",
})

Register({
    key = "rogue.tricks_of_the_trade",
    cooldownID = 104012,
    category = CDM_CATEGORY_UTILITY,
    order = 50,
    spellID = 57934,
    iconSpellID = 57934,
    trackingType = "cooldown",
})

Register({
    key = "rogue.kick",
    cooldownID = 104013,
    category = CDM_CATEGORY_UTILITY,
    order = 60,
    spellID = 1769,
    iconSpellID = 1769,
    trackingType = "cooldown",
})

Register({
    key = "rogue.blind",
    cooldownID = 104014,
    category = CDM_CATEGORY_UTILITY,
    order = 70,
    spellID = 2094,
    iconSpellID = 2094,
    trackingType = "cooldown",
})

Register({
    key = "rogue.shadowstep",
    cooldownID = 104015,
    category = CDM_CATEGORY_UTILITY,
    order = 80,
    spellID = 36554,
    iconSpellID = 36554,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 25) -- Subtlety: Shadowstep
        end,
        resolveSpellID = function()
            return 36554
        end,
    },
})

Register({
    key = "rogue.dismantle",
    cooldownID = 104016,
    category = CDM_CATEGORY_UTILITY,
    order = 90,
    spellID = 51722,
    iconSpellID = 51722,
    trackingType = "cooldown",
})

Register({
    key = "rogue.fan_of_knives",
    cooldownID = 104017,
    category = CDM_CATEGORY_UTILITY,
    order = 100,
    spellID = 51723,
    iconSpellID = 51723,
    trackingType = "cooldown",
})

Register({
    key = "rogue.blade_flurry_cooldown",
    cooldownID = 104018,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 80,
    spellID = 13877,
    iconSpellID = 13877,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 15) -- Combat: Blade Flurry
        end,
        resolveSpellID = function()
            return 13877
        end,
    },
})

Register({
    key = "rogue.ghostly_strike",
    cooldownID = 104019,
    category = CDM_CATEGORY_UTILITY,
    order = 110,
    spellID = 14278,
    iconSpellID = 14278,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 8) -- Subtlety: Ghostly Strike
        end,
        resolveSpellID = function()
            return 14278
        end,
    },
})

Register({
    key = "rogue.riposte",
    cooldownID = 104020,
    category = CDM_CATEGORY_UTILITY,
    order = 120,
    spellID = 14251,
    iconSpellID = 14251,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 8) -- Combat: Riposte
        end,
        resolveSpellID = function()
            return 14251
        end,
    },
})

Register({
    key = "rogue.premeditation",
    cooldownID = 104021,
    category = CDM_CATEGORY_UTILITY,
    order = 130,
    spellID = 14183,
    iconSpellID = 14183,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 20) -- Subtlety: Premeditation
        end,
        resolveSpellID = function()
            return 14183
        end,
    },
})

Register({
    key = "rogue.feint",
    cooldownID = 104022,
    category = CDM_CATEGORY_UTILITY,
    order = 140,
    spellID = 48659,
    spellIDs = { 1966, 6768, 8637, 11303, 25302, 27448, 48658, 48659 },
    iconSpellID = 48659,
    trackingType = "cooldown",
})

Register({
    key = "rogue.gouge",
    cooldownID = 104023,
    category = CDM_CATEGORY_UTILITY,
    order = 150,
    spellID = 48668,
    spellIDs = { 1776, 1777, 8629, 11285, 11286, 38764, 48667, 48668 },
    iconSpellID = 48668,
    trackingType = "cooldown",
})

Register({
    key = "rogue.kidney_shot",
    cooldownID = 104024,
    category = CDM_CATEGORY_UTILITY,
    order = 160,
    spellID = 8643,
    spellIDs = { 408, 8643 },
    iconSpellID = 8643,
    trackingType = "cooldown",
})

Register({
    key = "rogue.distract",
    cooldownID = 104025,
    category = CDM_CATEGORY_UTILITY,
    order = 170,
    spellID = 1725,
    iconSpellID = 1725,
    trackingType = "cooldown",
})

-- Proc auras
Register({
    key = "rogue.blade_flurry",
    cooldownID = 204001,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 10,
    spellID = 13877,
    auraSpellID = 13877,
    iconSpellID = 13877,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 15) -- Combat: Blade Flurry
        end,
        resolveSpellID = function()
            return 13877
        end,
    },
})

Register({
    key = "rogue.slice_and_dice",
    cooldownID = 204002,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 20,
    spellID = 6774,
    auraSpellID = 6774,
    iconSpellID = 6774,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "rogue.envenom",
    cooldownID = 204003,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 30,
    spellID = 57993,
    auraSpellID = 57993,
    iconSpellID = 57993,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "rogue.adrenaline_rush_buff",
    cooldownID = 204004,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 40,
    spellID = 13750,
    auraSpellID = 13750,
    iconSpellID = 13750,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 20) -- Combat: Adrenaline Rush
        end,
        resolveSpellID = function()
            return 13750
        end,
    },
})

Register({
    key = "rogue.cold_blood_buff",
    cooldownID = 204005,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 50,
    spellID = 14177,
    auraSpellID = 14177,
    iconSpellID = 14177,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 13) -- Assassination: Cold Blood
        end,
        resolveSpellID = function()
            return 14177
        end,
    },
})

Register({
    key = "rogue.hunger_for_blood_buff",
    cooldownID = 204006,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 60,
    spellID = 51662,
    auraSpellID = 51662,
    iconSpellID = 51662,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 27) -- Assassination: Hunger for Blood
        end,
        resolveSpellID = function()
            return 51662
        end,
    },
})

Register({
    key = "rogue.killing_spree_buff",
    cooldownID = 204007,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 70,
    spellID = 51690,
    auraSpellID = 51690,
    iconSpellID = 51690,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 28) -- Combat: Killing Spree
        end,
        resolveSpellID = function()
            return 51690
        end,
    },
})

Register({
    key = "rogue.shadow_dance_buff",
    cooldownID = 204008,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 80,
    spellID = 51713,
    auraSpellID = 51713,
    iconSpellID = 51713,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 28) -- Subtlety: Shadow Dance
        end,
        resolveSpellID = function()
            return 51713
        end,
    },
})

Register({
    key = "rogue.overkill",
    cooldownID = 204009,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 90,
    spellID = 58427,
    auraSpellID = 58427,
    iconSpellID = 58427,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 19) -- Assassination: Overkill
        end,
        resolveSpellID = function()
            return 58427
        end,
    },
})

Register({
    key = "rogue.master_of_subtlety",
    cooldownID = 204010,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 100,
    spellID = 31665,
    auraSpellID = 31665,
    iconSpellID = 31665,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 17) -- Subtlety: Master of Subtlety
        end,
        resolveSpellID = function()
            return 31665
        end,
    },
})

Register({
    key = "rogue.cheating_death",
    cooldownID = 204011,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 110,
    spellID = 45182,
    auraSpellID = 45182,
    iconSpellID = 45182,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    internalCooldown = 60,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 21) -- Subtlety: Cheat Death
        end,
        resolveSpellID = function()
            return 45182
        end,
    },
})

Register({
    key = "rogue.ghostly_strike_buff",
    cooldownID = 204012,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 120,
    spellID = 14278,
    auraSpellID = 14278,
    iconSpellID = 14278,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 8) -- Subtlety: Ghostly Strike
        end,
        resolveSpellID = function()
            return 14278
        end,
    },
})

Register({
    key = "rogue.remorseless_attacks",
    cooldownID = 204013,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 130,
    spellID = 14149,
    auraSpellID = 14149,
    auraSpellIDs = { 14143, 14149 },
    iconSpellID = 14149,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 2) -- Assassination: Remorseless Attacks
        end,
        resolveSpellID = function()
            return 14149
        end,
    },
})

Register({
    key = "rogue.turn_the_tables",
    cooldownID = 204014,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 140,
    spellID = 52910,
    auraSpellID = 52910,
    iconSpellID = 52910,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 25) -- Assassination: Turn the Tables
        end,
        resolveSpellID = function()
            return 52910
        end,
    },
})

Register({
    key = "rogue.sprint_buff",
    cooldownID = 204015,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 150,
    spellID = 11305,
    auraSpellID = 11305,
    iconSpellID = 11305,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "rogue.evasion_buff",
    cooldownID = 204016,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 160,
    spellID = 26669,
    auraSpellID = 26669,
    iconSpellID = 26669,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "rogue.cloak_of_shadows_buff",
    cooldownID = 204017,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 170,
    spellID = 31224,
    auraSpellID = 31224,
    iconSpellID = 31224,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "rogue.tricks_of_the_trade_buff",
    cooldownID = 204018,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 180,
    spellID = 57934,
    auraSpellID = 59628,
    auraSpellIDs = { 59628, 57934, 57933 },
    iconSpellID = 57934,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

-- Persistent self-buffs
Register({
    key = "rogue.stealth",
    cooldownID = 204101,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 10,
    spellID = 1787,
    auraSpellID = 1787,
    iconSpellID = 1787,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})
