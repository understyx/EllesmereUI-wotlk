local addonName, ns = ...

if not C_CooldownViewer or not C_CooldownViewer.RegisterDefinition then return end

-- Category Constants based on EllesmereUI defaults
-- 1 = EssentialCooldownViewer
-- 2 = UtilityCooldownViewer
-- 3 = BuffIconCooldownViewer
-- 4 = BuffBarCooldownViewer
local CDM_CATEGORY_ESSENTIAL = 1
local CDM_CATEGORY_UTILITY   = 2
local CDM_CATEGORY_BUFF_ICON = 3
local CDM_CATEGORY_BUFF_BAR  = 4

-- Talent Helpers:
-- 1. HasLearnedTalent: uses stable WotLK talent tree tab/index.
-- 2. HasLearnedTalentBySpellID: matches talent name against spell info for flexible proc/talent lookups.
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

local function HasLearnedTalentBySpellID(spellID)
    local talentName = GetSpellInfo and GetSpellInfo(spellID)
    if not talentName or not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo then
        return false
    end
    for tab = 1, GetNumTalentTabs() do
        for index = 1, GetNumTalents(tab) do
            local name, _, _, _, rank = GetTalentInfo(tab, index)
            if name == talentName and (rank or 0) > 0 then
                return true
            end
        end
    end
    return false
end

-- cooldownID Schema: [CD type 1 digit][Class ID 2 digits][Unique ID 3 digits]
-- Paladin class abilities use 102XXX; paladin buffs and procs use 202XXX.
-- These IDs are stable handles and must remain globally unique.
local DEFENSIVE = { defensive = true }
local EXTERNAL = { external = true }
local EXTERNAL_DEFENSIVE = { external = true, defensive = true }
local AURA_TAGS = {
    ["paladin.divine_shield"] = DEFENSIVE,
    ["paladin.divine_protection"] = DEFENSIVE,
    ["paladin.hand_of_protection"] = EXTERNAL_DEFENSIVE,
    ["paladin.hand_of_freedom"] = EXTERNAL,
    ["paladin.hand_of_sacrifice"] = EXTERNAL_DEFENSIVE,
    ["paladin.hand_of_salvation"] = EXTERNAL,
    ["paladin.aura_mastery"] = DEFENSIVE,
    ["paladin.divine_sacrifice"] = DEFENSIVE,
    ["paladin.sacred_shield"] = EXTERNAL_DEFENSIVE,
    ["paladin.holy_shield"] = DEFENSIVE,
    ["paladin.ardent_defender"] = DEFENSIVE,
    ["paladin.buff.divine_protection"] = DEFENSIVE,
    ["paladin.buff.divine_shield"] = DEFENSIVE,
    ["paladin.buff.hand_of_freedom"] = EXTERNAL,
    ["paladin.buff.hand_of_protection"] = EXTERNAL_DEFENSIVE,
    ["paladin.buff.hand_of_sacrifice"] = EXTERNAL_DEFENSIVE,
    ["paladin.buff.hand_of_salvation"] = EXTERNAL,
    ["paladin.buff.divine_sacrifice"] = DEFENSIVE,
    ["paladin.buff.aura_mastery"] = DEFENSIVE,
    ["paladin.buff.sacred_shield"] = EXTERNAL_DEFENSIVE,
    ["paladin.bar.sacred_shield"] = EXTERNAL_DEFENSIVE,
}
local function Register(def)
    def.class = "PALADIN"
    def.auraTags = def.auraTags or AURA_TAGS[def.key]
    C_CooldownViewer.RegisterDefinition(def)
end

-------------------------------------------------------------------------------
-- 1. ESSENTIAL COOLDOWNS (Category 1)
-------------------------------------------------------------------------------

-- Baseline & Major Cooldowns
Register({
    key = "paladin.avenging_wrath",
    cooldownID = 102001,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 10,
    spellID = 31884,
    iconSpellID = 31884,
    trackingType = "cooldown",
})

Register({
    key = "paladin.divine_shield",
    cooldownID = 102002,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 20,
    spellID = 642,
    iconSpellID = 642,
    trackingType = "cooldown",
})

Register({
    key = "paladin.divine_protection",
    cooldownID = 102003,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 30,
    spellID = 498,
    iconSpellID = 498,
    trackingType = "cooldown",
})

Register({
    key = "paladin.exorcism",
    cooldownID = 102004,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 40,
    spellID = 48801,
    spellIDs = { 879, 5614, 5615, 10312, 10313, 10314, 27138, 48800, 48801 },
    iconSpellID = 48801,
    trackingType = "cooldown",
})

Register({
    key = "paladin.hammer_of_wrath",
    cooldownID = 102005,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 50,
    spellID = 48806,
    spellIDs = { 24275, 24274, 24239, 27180, 48805, 48806 },
    iconSpellID = 48806,
    trackingType = "cooldown",
    execute = true,
})

Register({
    key = "paladin.consecration",
    cooldownID = 102006,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 60,
    spellID = 48819,
    spellIDs = { 26573, 20116, 20922, 20923, 20924, 24239, 27173, 48818, 48819 },
    iconSpellID = 48819,
    trackingType = "cooldown",
})

-- Judgements
Register({
    key = "paladin.judgement_of_justice",
    cooldownID = 102017,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 120,
    spellID = 53407,
    iconSpellID = 53407,
    trackingType = "cooldown",
})

Register({
    key = "paladin.judgement_of_light",
    cooldownID = 102018,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 130,
    spellID = 20271,
    iconSpellID = 20271,
    trackingType = "cooldown",
})

Register({
    key = "paladin.judgement_of_wisdom",
    cooldownID = 102019,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 140,
    spellID = 53408,
    iconSpellID = 53408,
    trackingType = "cooldown",
})

-- Holy Specific Cooldowns
Register({
    key = "paladin.holy_shock",
    cooldownID = 102020,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 65,
    spellID = 48825,
    spellIDs = { 20473, 20929, 20930, 27174, 33072, 48824, 48825 },
    iconSpellID = 48825,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 17) or HasLearnedTalentBySpellID(48825) -- Holy: Holy Shock
        end,
        resolveSpellID = function()
            return 48825
        end,
    },
})

Register({
    key = "paladin.divine_favor",
    cooldownID = 102021,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 66,
    spellID = 20216,
    iconSpellID = 20216,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 12) or HasLearnedTalentBySpellID(20216) -- Holy: Divine Favor
        end,
        resolveSpellID = function()
            return 20216
        end,
    },
})

Register({
    key = "paladin.divine_illumination",
    cooldownID = 102022,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 67,
    spellID = 31842,
    iconSpellID = 31842,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 21) or HasLearnedTalentBySpellID(31842) -- Holy: Divine Illumination
        end,
        resolveSpellID = function()
            return 31842
        end,
    },
})

Register({
    key = "paladin.beacon_of_light",
    cooldownID = 102023,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 68,
    spellID = 53563,
    iconSpellID = 53563,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 25) or HasLearnedTalentBySpellID(53563) -- Holy: Beacon of Light
        end,
        resolveSpellID = function()
            return 53563
        end,
    },
})

Register({
    key = "paladin.sacred_shield",
    cooldownID = 102024,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 69,
    spellID = 53601,
    iconSpellID = 53601,
    trackingType = "cooldown",
})

-- Retribution Talent Abilities
Register({
    key = "paladin.crusader_strike",
    cooldownID = 102101,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 70,
    spellID = 35395,
    iconSpellID = 35395,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 23) or HasLearnedTalentBySpellID(35395) -- Retribution: Crusader Strike
        end,
        resolveSpellID = function()
            return 35395
        end,
    },
})

Register({
    key = "paladin.divine_storm",
    cooldownID = 102102,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 80,
    spellID = 53385,
    iconSpellID = 53385,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 26) or HasLearnedTalentBySpellID(53385) -- Retribution: Divine Storm
        end,
        resolveSpellID = function()
            return 53385
        end,
    },
})

-- Protection Talent & Specialty Abilities
Register({
    key = "paladin.avengers_shield",
    cooldownID = 102201,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 90,
    spellID = 48827,
    spellIDs = { 31935, 32699, 32700, 48826, 48827 },
    iconSpellID = 48827,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 22) or HasLearnedTalentBySpellID(48827) or HasLearnedTalentBySpellID(31935) -- Protection: Avenger's Shield
        end,
        resolveSpellID = function()
            return 48827
        end,
    },
})

Register({
    key = "paladin.hammer_of_the_righteous",
    cooldownID = 102202,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 100,
    spellID = 53595,
    iconSpellID = 53595,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 26) or HasLearnedTalentBySpellID(53595) -- Protection: Hammer of the Righteous
        end,
        resolveSpellID = function()
            return 53595
        end,
    },
})

Register({
    key = "paladin.shield_of_righteousness",
    cooldownID = 102203,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 110,
    spellID = 61411,
    spellIDs = { 53600, 61411 },
    iconSpellID = 61411,
    trackingType = "cooldown",
})

-------------------------------------------------------------------------------
-- 2. UTILITY COOLDOWNS (Category 2)
-------------------------------------------------------------------------------

Register({
    key = "paladin.holy_wrath",
    cooldownID = 102007,
    category = CDM_CATEGORY_UTILITY,
    order = 10,
    spellID = 48817,
    spellIDs = { 2812, 10318, 27139, 48816, 48817 },
    iconSpellID = 48817,
    trackingType = "cooldown",
})

Register({
    key = "paladin.hammer_of_justice",
    cooldownID = 102008,
    category = CDM_CATEGORY_UTILITY,
    order = 20,
    spellID = 10308,
    spellIDs = { 853, 5588, 5589, 10308 },
    iconSpellID = 10308,
    trackingType = "cooldown",
})

Register({
    key = "paladin.hand_of_reckoning",
    cooldownID = 102009,
    category = CDM_CATEGORY_UTILITY,
    order = 30,
    spellID = 62124,
    iconSpellID = 62124,
    trackingType = "cooldown",
})

Register({
    key = "paladin.righteous_defense",
    cooldownID = 102010,
    category = CDM_CATEGORY_UTILITY,
    order = 40,
    spellID = 31789,
    iconSpellID = 31789,
    trackingType = "cooldown",
})

Register({
    key = "paladin.lay_on_hands",
    cooldownID = 102011,
    category = CDM_CATEGORY_UTILITY,
    order = 50,
    spellID = 48788,
    spellIDs = { 633, 2800, 10310, 27154, 48788 },
    iconSpellID = 48788,
    trackingType = "cooldown",
})

Register({
    key = "paladin.hand_of_protection",
    cooldownID = 102012,
    category = CDM_CATEGORY_UTILITY,
    order = 60,
    spellID = 10278,
    spellIDs = { 1022, 5599, 10278 },
    iconSpellID = 10278,
    trackingType = "cooldown",
})

Register({
    key = "paladin.hand_of_freedom",
    cooldownID = 102013,
    category = CDM_CATEGORY_UTILITY,
    order = 70,
    spellID = 1044,
    iconSpellID = 1044,
    trackingType = "cooldown",
})

Register({
    key = "paladin.hand_of_sacrifice",
    cooldownID = 102014,
    category = CDM_CATEGORY_UTILITY,
    order = 80,
    spellID = 6940,
    iconSpellID = 6940,
    trackingType = "cooldown",
})

Register({
    key = "paladin.hand_of_salvation",
    cooldownID = 102015,
    category = CDM_CATEGORY_UTILITY,
    order = 90,
    spellID = 1038,
    iconSpellID = 1038,
    trackingType = "cooldown",
})

Register({
    key = "paladin.turn_evil",
    cooldownID = 102016,
    category = CDM_CATEGORY_UTILITY,
    order = 100,
    spellID = 10326,
    iconSpellID = 10326,
    trackingType = "cooldown",
})

Register({
    key = "paladin.aura_mastery",
    cooldownID = 102025,
    category = CDM_CATEGORY_UTILITY,
    order = 105,
    spellID = 31821,
    iconSpellID = 31821,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 6) or HasLearnedTalent(1, 11) or HasLearnedTalentBySpellID(31821) -- Holy: Aura Mastery
        end,
        resolveSpellID = function()
            return 31821
        end,
    },
})

Register({
    key = "paladin.cleanse",
    cooldownID = 102026,
    category = CDM_CATEGORY_UTILITY,
    order = 106,
    spellID = 4987,
    iconSpellID = 4987,
    trackingType = "cooldown",
})

Register({
    key = "paladin.repentance",
    cooldownID = 102103,
    category = CDM_CATEGORY_UTILITY,
    order = 110,
    spellID = 20066,
    iconSpellID = 20066,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 18) or HasLearnedTalentBySpellID(20066) -- Retribution: Repentance
        end,
        resolveSpellID = function()
            return 20066
        end,
    },
})

Register({
    key = "paladin.divine_sacrifice",
    cooldownID = 102204,
    category = CDM_CATEGORY_UTILITY,
    order = 120,
    spellID = 64205,
    auraSpellIDs = { 53530, 64205 },
    iconSpellID = 64205,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 6) or HasLearnedTalentBySpellID(64205) -- Protection: Divine Sacrifice
        end,
        resolveSpellID = function()
            return 64205
        end,
    },
})

-------------------------------------------------------------------------------
-- 3. PROC & BUFF ICONS (Category 3)
-------------------------------------------------------------------------------

Register({
    key = "paladin.the_art_of_war",
    cooldownID = 202001,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 10,
    spellID = 59578,
    auraSpellID = 59578,
    iconSpellID = 59578,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 17) or HasLearnedTalentBySpellID(59578) or HasLearnedTalentBySpellID(53488) or HasLearnedTalentBySpellID(53486) -- Retribution: The Art of War
        end,
        resolveSpellID = function()
            return 59578
        end,
    },
})

Register({
    key = "paladin.holy_shield",
    cooldownID = 202002,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 20,
    spellID = 48952,
    auraSpellID = 48952,
    iconSpellID = 48952,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 17) or HasLearnedTalentBySpellID(48952) -- Protection: Holy Shield
        end,
        resolveSpellID = function()
            return 48952
        end,
    },
})

Register({
    key = "paladin.ardent_defender",
    cooldownID = 202003,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 30,
    spellID = 66233,
    auraSpellID = 66233,
    iconSpellID = 66233,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 18) or HasLearnedTalentBySpellID(66233) -- Protection: Ardent Defender
        end,
        resolveSpellID = function()
            return 66233
        end,
    },
})

Register({
    key = "paladin.vengeance",
    cooldownID = 202004,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 40,
    spellID = 20053,
    auraSpellID = 20053,
    iconSpellID = 20053,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 15) or HasLearnedTalentBySpellID(20053) -- Retribution: Vengeance
        end,
        resolveSpellID = function()
            return 20053
        end,
    },
})

Register({
    key = "paladin.infusion_of_light",
    cooldownID = 202005,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 45,
    spellID = 54149,
    auraSpellID = 54149,
    iconSpellID = 54149,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 19) or HasLearnedTalent(1, 23) or HasLearnedTalentBySpellID(54149) or HasLearnedTalentBySpellID(53569) -- Holy: Infusion of Light
        end,
        resolveSpellID = function()
            return 54149
        end,
    },
})

Register({
    key = "paladin.buff.divine_favor",
    cooldownID = 202006,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 46,
    spellID = 20216,
    auraSpellID = 20216,
    iconSpellID = 20216,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 12) or HasLearnedTalentBySpellID(20216)
        end,
        resolveSpellID = function()
            return 20216
        end,
    },
})

Register({
    key = "paladin.buff.divine_illumination",
    cooldownID = 202007,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 47,
    spellID = 31842,
    auraSpellID = 31842,
    iconSpellID = 31842,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 21) or HasLearnedTalentBySpellID(31842)
        end,
        resolveSpellID = function()
            return 31842
        end,
    },
})

Register({
    key = "paladin.buff.avenging_wrath",
    cooldownID = 202008,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 48,
    spellID = 31884,
    auraSpellID = 31884,
    iconSpellID = 31884,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.divine_protection",
    cooldownID = 202009,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 49,
    spellID = 498,
    auraSpellID = 498,
    iconSpellID = 498,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.divine_shield",
    cooldownID = 202010,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 50,
    spellID = 642,
    auraSpellID = 642,
    iconSpellID = 642,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.hand_of_freedom",
    cooldownID = 202011,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 51,
    spellID = 1044,
    auraSpellID = 1044,
    iconSpellID = 1044,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.hand_of_protection",
    cooldownID = 202012,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 52,
    spellID = 10278,
    auraSpellID = 10278,
    iconSpellID = 10278,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.hand_of_sacrifice",
    cooldownID = 202013,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 53,
    spellID = 6940,
    auraSpellID = 6940,
    iconSpellID = 6940,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.hand_of_salvation",
    cooldownID = 202014,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 54,
    spellID = 1038,
    auraSpellID = 1038,
    iconSpellID = 1038,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.divine_sacrifice",
    cooldownID = 202015,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 55,
    spellID = 64205,
    auraSpellID = 64205,
    auraSpellIDs = { 53530, 64205 },
    iconSpellID = 64205,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 6) or HasLearnedTalentBySpellID(64205)
        end,
        resolveSpellID = function()
            return 64205
        end,
    },
})

Register({
    key = "paladin.buff.aura_mastery",
    cooldownID = 202016,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 56,
    spellID = 31821,
    auraSpellID = 31821,
    iconSpellID = 31821,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 6) or HasLearnedTalent(1, 11) or HasLearnedTalentBySpellID(31821)
        end,
        resolveSpellID = function()
            return 31821
        end,
    },
})

Register({
    key = "paladin.buff.sacred_shield",
    cooldownID = 202017,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 57,
    spellID = 53601,
    auraSpellID = 53601,
    iconSpellID = 53601,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.beacon_of_light",
    cooldownID = 202018,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 58,
    spellID = 53563,
    auraSpellID = 53563,
    iconSpellID = 53563,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 25) or HasLearnedTalentBySpellID(53563)
        end,
        resolveSpellID = function()
            return 53563
        end,
    },
})

Register({
    key = "paladin.buff.judgements_of_the_pure",
    cooldownID = 202019,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 59,
    spellID = 53655,
    auraSpellID = 53655,
    iconSpellID = 53655,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 22) or HasLearnedTalent(1, 24) or HasLearnedTalentBySpellID(53655) -- Holy: Judgements of the Pure
        end,
        resolveSpellID = function()
            return 53655
        end,
    },
})

Register({
    key = "paladin.buff.redoubt",
    cooldownID = 202020,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 60,
    spellID = 20137,
    auraSpellID = 20137,
    iconSpellID = 20137,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 1) or HasLearnedTalentBySpellID(20137) -- Protection: Redoubt
        end,
        resolveSpellID = function()
            return 20137
        end,
    },
})

Register({
    key = "paladin.buff.lights_grace",
    cooldownID = 202021,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 61,
    spellID = 31834,
    auraSpellID = 31834,
    iconSpellID = 31834,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 16) or HasLearnedTalentBySpellID(31834) -- Holy: Light's Grace
        end,
        resolveSpellID = function()
            return 31834
        end,
    },
})

Register({
    key = "paladin.buff.holy_strength",
    cooldownID = 202022,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 62,
    spellID = 67371,
    auraSpellID = 67371,
    iconSpellID = 67371,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.deliverance",
    cooldownID = 202023,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 63,
    spellID = 64956,
    auraSpellID = 64956,
    iconSpellID = 64956,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.buff.increased_block",
    cooldownID = 202024,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 64,
    spellID = 67380,
    auraSpellID = 67380,
    iconSpellID = 67380,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.debuff.forbearance",
    cooldownID = 202025,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 65,
    spellID = 25771,
    auraSpellID = 25771,
    iconSpellID = 25771,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

-------------------------------------------------------------------------------
-- 4. BUFF BARS & STANCES/AURAS (Category 4)
-------------------------------------------------------------------------------

Register({
    key = "paladin.divine_plea",
    cooldownID = 202101,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 10,
    spellID = 54428,
    auraSpellID = 54428,
    iconSpellID = 54428,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.blessing_of_sanctuary",
    cooldownID = 202102,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 20,
    spellID = 25899,
    auraSpellID = 25899,
    iconSpellID = 25899,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 12) or HasLearnedTalentBySpellID(25899) -- Protection: Blessing of Sanctuary
        end,
        resolveSpellID = function()
            return 25899
        end,
    },
})

Register({
    key = "paladin.retribution_aura",
    cooldownID = 202103,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 30,
    spellID = 54043,
    spellIDs = { 7294, 10298, 10299, 10300, 10301, 27150, 54043 },
    auraSpellID = 54043,
    iconSpellID = 54043,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.crusader_aura",
    cooldownID = 202104,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 40,
    spellID = 32223,
    auraSpellID = 32223,
    iconSpellID = 32223,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.righteous_fury",
    cooldownID = 202105,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 50,
    spellID = 25780,
    auraSpellID = 25780,
    iconSpellID = 25780,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.bar.sacred_shield",
    cooldownID = 202106,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 55,
    spellID = 53601,
    auraSpellID = 53601,
    iconSpellID = 53601,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.bar.beacon_of_light",
    cooldownID = 202107,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 56,
    spellID = 53563,
    auraSpellID = 53563,
    iconSpellID = 53563,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 25) or HasLearnedTalentBySpellID(53563)
        end,
        resolveSpellID = function()
            return 53563
        end,
    },
})

Register({
    key = "paladin.bar.judgements_of_the_pure",
    cooldownID = 202108,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 57,
    spellID = 53655,
    auraSpellID = 53655,
    iconSpellID = 53655,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 22) or HasLearnedTalent(1, 24) or HasLearnedTalentBySpellID(53655)
        end,
        resolveSpellID = function()
            return 53655
        end,
    },
})

Register({
    key = "paladin.blessing_of_kings",
    cooldownID = 202109,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 60,
    spellID = 20217,
    auraSpellID = 20217,
    iconSpellID = 20217,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.blessing_of_might",
    cooldownID = 202110,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 61,
    spellID = 48932,
    spellIDs = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932 },
    auraSpellID = 48932,
    iconSpellID = 48932,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.blessing_of_wisdom",
    cooldownID = 202111,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 62,
    spellID = 48936,
    spellIDs = { 19742, 19850, 19852, 19853, 19854, 25894, 27142, 48935, 48936 },
    auraSpellID = 48936,
    iconSpellID = 48936,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.devotion_aura",
    cooldownID = 202112,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 63,
    spellID = 48942,
    spellIDs = { 465, 10290, 10291, 10292, 10293, 27149, 48941, 48942 },
    auraSpellID = 48942,
    iconSpellID = 48942,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.concentration_aura",
    cooldownID = 202113,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 64,
    spellID = 19746,
    auraSpellID = 19746,
    iconSpellID = 19746,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.shadow_resistance_aura",
    cooldownID = 202114,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 65,
    spellID = 48943,
    spellIDs = { 19876, 19895, 19896, 27151, 48943 },
    auraSpellID = 48943,
    iconSpellID = 48943,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.frost_resistance_aura",
    cooldownID = 202115,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 66,
    spellID = 48945,
    spellIDs = { 19888, 19897, 19898, 27152, 48945 },
    auraSpellID = 48945,
    iconSpellID = 48945,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.fire_resistance_aura",
    cooldownID = 202116,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 67,
    spellID = 48947,
    spellIDs = { 19891, 19899, 19900, 27153, 48947 },
    auraSpellID = 48947,
    iconSpellID = 48947,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.seal_of_righteousness",
    cooldownID = 202117,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 70,
    spellID = 21084,
    spellIDs = { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 27155, 48954 },
    auraSpellID = 21084,
    iconSpellID = 21084,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.seal_of_command",
    cooldownID = 202118,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 71,
    spellID = 20375,
    auraSpellID = 20375,
    iconSpellID = 20375,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 10) or HasLearnedTalentBySpellID(20375) -- Retribution: Seal of Command
        end,
        resolveSpellID = function()
            return 20375
        end,
    },
})

Register({
    key = "paladin.seal_of_vengeance",
    cooldownID = 202119,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 72,
    spellID = 31801,
    auraSpellID = 31801,
    iconSpellID = 31801,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.seal_of_corruption",
    cooldownID = 202120,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 73,
    spellID = 53736,
    auraSpellID = 53736,
    iconSpellID = 53736,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.seal_of_justice",
    cooldownID = 202121,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 74,
    spellID = 20164,
    auraSpellID = 20164,
    iconSpellID = 20164,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.seal_of_light",
    cooldownID = 202122,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 75,
    spellID = 20165,
    auraSpellID = 20165,
    iconSpellID = 20165,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.seal_of_wisdom",
    cooldownID = 202123,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 76,
    spellID = 20166,
    auraSpellID = 20166,
    iconSpellID = 20166,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "paladin.divine_plea_cooldown",
    cooldownID = 102027,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 145,
    spellID = 54428,
    iconSpellID = 54428,
    trackingType = "cooldown",
})

Register({
    key = "paladin.holy_shield_cooldown",
    cooldownID = 102028,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 146,
    spellID = 48952,
    spellIDs = { 20925, 20927, 20928, 27179, 48951, 48952 },
    iconSpellID = 48952,
    trackingType = "cooldown",
    auraTags = { defensive = true },
})

Register({
    key = "paladin.divine_intervention",
    cooldownID = 102029,
    category = CDM_CATEGORY_UTILITY,
    order = 160,
    spellID = 19752,
    iconSpellID = 19752,
    trackingType = "cooldown",
    auraTags = { external = true, defensive = true },
})
