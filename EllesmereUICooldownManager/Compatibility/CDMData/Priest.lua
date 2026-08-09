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

-- Priest = class 05. Cooldowns = 105XXX, Buffs/Procs = 205XXX.

local AURA_TAGS = {
    ["priest.power_infusion"] = { external = true },
    ["priest.pain_suppression"] = { external = true, defensive = true },
    ["priest.guardian_spirit"] = { external = true, defensive = true },
    ["priest.dispersion"] = { defensive = true },
    ["priest.fear_ward"] = { external = true },
}

local function Register(def)
    def.class = "PRIEST"
    def.auraTags = def.auraTags or AURA_TAGS[def.key]
    C_CooldownViewer.RegisterDefinition(def)
end

-- Major cooldowns
Register({
    key = "priest.inner_focus",
    cooldownID = 105001,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 10,
    spellID = 14751,
    iconSpellID = 14751,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 12) -- Disc: Inner Focus
        end,
        resolveSpellID = function()
            return 14751
        end,
    },
})

Register({
    key = "priest.power_infusion",
    cooldownID = 105002,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 20,
    spellID = 10060,
    iconSpellID = 10060,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 20) -- Disc: Power Infusion
        end,
        resolveSpellID = function()
            return 10060
        end,
    },
})

Register({
    key = "priest.pain_suppression",
    cooldownID = 105003,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 30,
    spellID = 33206,
    iconSpellID = 33206,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 23) -- Disc: Pain Suppression
        end,
        resolveSpellID = function()
            return 33206
        end,
    },
})

Register({
    key = "priest.penance",
    cooldownID = 105004,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 40,
    spellID = 53007,
    spellIDs = { 53005, 53006, 53007 },
    iconSpellID = 53007,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 26) -- Disc: Penance
        end,
        resolveSpellID = function()
            return 53007
        end,
    },
})

Register({
    key = "priest.guardian_spirit",
    cooldownID = 105005,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 50,
    spellID = 47788,
    iconSpellID = 47788,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 27) -- Holy: Guardian Spirit
        end,
        resolveSpellID = function()
            return 47788
        end,
    },
})

Register({
    key = "priest.circle_of_healing",
    cooldownID = 105006,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 60,
    spellID = 48089,
    spellIDs = { 48088, 48089 },
    iconSpellID = 48089,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 22) -- Holy: Circle of Healing
        end,
        resolveSpellID = function()
            return 48089
        end,
    },
})

Register({
    key = "priest.divine_hymn",
    cooldownID = 105007,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 70,
    spellID = 64843,
    iconSpellID = 64843,
    trackingType = "cooldown",
})

Register({
    key = "priest.hymn_of_hope",
    cooldownID = 105008,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 80,
    spellID = 64901,
    iconSpellID = 64901,
    trackingType = "cooldown",
})

Register({
    key = "priest.shadowfiend",
    cooldownID = 105009,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 90,
    spellID = 34433,
    iconSpellID = 34433,
    trackingType = "cooldown",
})

Register({
    key = "priest.dispersion",
    cooldownID = 105010,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 100,
    spellID = 47585,
    iconSpellID = 47585,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 27) -- Shadow: Dispersion
        end,
        resolveSpellID = function()
            return 47585
        end,
    },
})

-- Utility cooldowns
Register({
    key = "priest.psychic_scream",
    cooldownID = 105011,
    category = CDM_CATEGORY_UTILITY,
    order = 10,
    spellID = 10890,
    iconSpellID = 10890,
    trackingType = "cooldown",
})

Register({
    key = "priest.fade",
    cooldownID = 105012,
    category = CDM_CATEGORY_UTILITY,
    order = 20,
    spellID = 586,
    iconSpellID = 586,
    trackingType = "cooldown",
})

Register({
    key = "priest.silence",
    cooldownID = 105013,
    category = CDM_CATEGORY_UTILITY,
    order = 30,
    spellID = 15487,
    iconSpellID = 15487,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 14) -- Shadow: Silence
        end,
        resolveSpellID = function()
            return 15487
        end,
    },
})

Register({
    key = "priest.fear_ward",
    cooldownID = 105014,
    category = CDM_CATEGORY_UTILITY,
    order = 40,
    spellID = 6346,
    iconSpellID = 6346,
    trackingType = "cooldown",
})

Register({
    key = "priest.mass_dispel",
    cooldownID = 105015,
    category = CDM_CATEGORY_UTILITY,
    order = 50,
    spellID = 32375,
    iconSpellID = 32375,
    trackingType = "cooldown",
})

Register({
    key = "priest.desperate_prayer",
    cooldownID = 105016,
    category = CDM_CATEGORY_UTILITY,
    order = 60,
    spellID = 48173,
    iconSpellID = 48173,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 6) -- Holy: Desperate Prayer
        end,
        resolveSpellID = function()
            return 48173
        end,
    },
})

-- Proc auras
Register({
    key = "priest.surge_of_light",
    cooldownID = 205001,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 10,
    spellID = 33151,
    auraSpellID = 33151,
    iconSpellID = 33151,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 16) -- Holy: Surge of Light
        end,
        resolveSpellID = function()
            return 33151
        end,
    },
})

Register({
    key = "priest.shadow_weaving",
    cooldownID = 205002,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 20,
    spellID = 15258,
    auraSpellID = 15258,
    iconSpellID = 15258,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 6) -- Shadow: Shadow Weaving
        end,
        resolveSpellID = function()
            return 15258
        end,
    },
})

Register({
    key = "priest.borrowed_time",
    cooldownID = 205003,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 30,
    spellID = 59889,
    auraSpellID = 59889,
    iconSpellID = 59889,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 25) -- Disc: Borrowed Time
        end,
        resolveSpellID = function()
            return 59889
        end,
    },
})

-- Persistent buffs
Register({
    key = "priest.inner_fire",
    cooldownID = 205101,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 10,
    spellID = 48168,
    auraSpellID = 48168,
    iconSpellID = 48168,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "priest.shadowform",
    cooldownID = 205102,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 20,
    spellID = 15473,
    auraSpellID = 15473,
    iconSpellID = 15473,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 16) -- Shadow: Shadowform
        end,
        resolveSpellID = function()
            return 15473
        end,
    },
})

Register({
    key = "priest.vampiric_embrace",
    cooldownID = 205103,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 30,
    spellID = 15286,
    auraSpellID = 15286,
    iconSpellID = 15286,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 10) -- Shadow: Vampiric Embrace
        end,
        resolveSpellID = function()
            return 15286
        end,
    },
})

local function RegisterBasic(key, cooldownID, order, spellIDs, category, auraTags)
    Register({
        key = "priest." .. key,
        cooldownID = cooldownID,
        category = category or CDM_CATEGORY_ESSENTIAL,
        order = order,
        spellID = spellIDs[#spellIDs],
        spellIDs = spellIDs,
        iconSpellID = spellIDs[#spellIDs],
        trackingType = "cooldown",
        auraTags = auraTags,
    })
end

RegisterBasic("prayer_of_mending", 105017, 110, { 33076, 48112, 48113 }, CDM_CATEGORY_ESSENTIAL, { external = true })
RegisterBasic("mind_blast",        105018, 120, { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947, 25372, 25375, 48126, 48127 })
RegisterBasic("shadow_word_death", 105019, 130, { 32379, 32996, 48157, 48158 })
RegisterBasic("psychic_horror",    105020, 140, { 64044 }, CDM_CATEGORY_UTILITY)
RegisterBasic("lightwell",         105021, 150, { 724, 27870, 27871, 28275, 48086, 48087 })
RegisterBasic("holy_fire",         105022, 160, { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261, 25384, 48134, 48135 })
