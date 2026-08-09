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

local function HasPetSpellByID(spellID)
    if not HasPetSpells or not GetSpellBookItemName or not GetSpellInfo then
        return false
    end
    local count = HasPetSpells()
    if type(count) ~= "number" or count < 1 then return false end
    local wanted = GetSpellInfo(spellID)
    if not wanted then return false end
    for index = 1, count do
        local name = GetSpellBookItemName(index, BOOKTYPE_PET or "pet")
        if name == wanted then return true end
    end
    return false
end

-- cooldownID Schema: [CD type 1 digit][Class ID 2 digits][Unique ID 3 digits]
-- Hunter = class 03. Cooldowns = 103XXX, Buffs/Procs = 203XXX.

local AURA_TAGS = {
    ["hunter.deterrence"] = { defensive = true },
    ["hunter.misdirection"] = { external = true },
    ["hunter.roar_of_sacrifice"] = { external = true, defensive = true },
}

local function Register(def)
    def.class = "HUNTER"
    def.auraTags = def.auraTags or AURA_TAGS[def.key]
    C_CooldownViewer.RegisterDefinition(def)
end

-- Major cooldowns
Register({
    key = "hunter.bestial_wrath",
    cooldownID = 103001,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 10,
    spellID = 19574,
    iconSpellID = 19574,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 18) -- BM: Bestial Wrath
        end,
        resolveSpellID = function()
            return 19574
        end,
    },
})

Register({
    key = "hunter.rapid_fire",
    cooldownID = 103002,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 20,
    spellID = 3045,
    iconSpellID = 3045,
    trackingType = "cooldown",
})

Register({
    key = "hunter.readiness",
    cooldownID = 103003,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 30,
    spellID = 23989,
    iconSpellID = 23989,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 11) -- MM: Readiness
        end,
        resolveSpellID = function()
            return 23989
        end,
    },
})

Register({
    key = "hunter.kill_shot",
    cooldownID = 103004,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 40,
    spellID = 61006,
    spellIDs = { 53351, 61005, 61006 },
    iconSpellID = 61006,
    trackingType = "cooldown",
    execute = true,
})

Register({
    key = "hunter.chimera_shot",
    cooldownID = 103005,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 50,
    spellID = 53209,
    iconSpellID = 53209,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 27) -- MM: Chimera Shot
        end,
        resolveSpellID = function()
            return 53209
        end,
    },
})

Register({
    key = "hunter.explosive_shot",
    cooldownID = 103006,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 60,
    spellID = 60053,
    spellIDs = { 60052, 60053 },
    iconSpellID = 60053,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 28) -- Surv: Explosive Shot
        end,
        resolveSpellID = function()
            return 60053
        end,
    },
})

Register({
    key = "hunter.black_arrow",
    cooldownID = 103007,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 70,
    spellID = 63672,
    spellIDs = { 63668, 63672 },
    iconSpellID = 63672,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 24) -- Surv: Black Arrow
        end,
        resolveSpellID = function()
            return 63672
        end,
    },
})

-- Utility cooldowns
Register({
    key = "hunter.disengage",
    cooldownID = 103008,
    category = CDM_CATEGORY_UTILITY,
    order = 10,
    spellID = 781,
    iconSpellID = 781,
    trackingType = "cooldown",
})

Register({
    key = "hunter.deterrence",
    cooldownID = 103009,
    category = CDM_CATEGORY_UTILITY,
    order = 20,
    spellID = 19263,
    iconSpellID = 19263,
    trackingType = "cooldown",
})

Register({
    key = "hunter.feign_death",
    cooldownID = 103010,
    category = CDM_CATEGORY_UTILITY,
    order = 30,
    spellID = 5384,
    iconSpellID = 5384,
    trackingType = "cooldown",
})

Register({
    key = "hunter.misdirection",
    cooldownID = 103011,
    category = CDM_CATEGORY_UTILITY,
    order = 40,
    spellID = 34477,
    iconSpellID = 34477,
    trackingType = "cooldown",
})

Register({
    key = "hunter.roar_of_sacrifice",
    cooldownID = 103021,
    category = CDM_CATEGORY_UTILITY,
    order = 45,
    spellID = 53480,
    iconSpellID = 53480,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasPetSpellByID(53480)
        end,
        resolveSpellID = function()
            return 53480
        end,
    },
})

Register({
    key = "hunter.silencing_shot",
    cooldownID = 103012,
    category = CDM_CATEGORY_UTILITY,
    order = 50,
    spellID = 34490,
    iconSpellID = 34490,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 14) -- MM: Silencing Shot
        end,
        resolveSpellID = function()
            return 34490
        end,
    },
})

Register({
    key = "hunter.scatter_shot",
    cooldownID = 103013,
    category = CDM_CATEGORY_UTILITY,
    order = 60,
    spellID = 19503,
    iconSpellID = 19503,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 6) -- Surv: Scatter Shot
        end,
        resolveSpellID = function()
            return 19503
        end,
    },
})

Register({
    key = "hunter.wyvern_sting",
    cooldownID = 103014,
    category = CDM_CATEGORY_UTILITY,
    order = 70,
    spellID = 49012,
    spellIDs = { 49011, 49012 },
    iconSpellID = 49012,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 18) -- Surv: Wyvern Sting
        end,
        resolveSpellID = function()
            return 49012
        end,
    },
})

Register({
    key = "hunter.intimidation",
    cooldownID = 103015,
    category = CDM_CATEGORY_UTILITY,
    order = 80,
    spellID = 19577,
    iconSpellID = 19577,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 12) -- BM: Intimidation
        end,
        resolveSpellID = function()
            return 19577
        end,
    },
})

Register({
    key = "hunter.freezing_trap",
    cooldownID = 103016,
    category = CDM_CATEGORY_UTILITY,
    order = 90,
    spellID = 14311,
    iconSpellID = 14311,
    trackingType = "cooldown",
})

Register({
    key = "hunter.explosive_trap",
    cooldownID = 103017,
    category = CDM_CATEGORY_UTILITY,
    order = 100,
    spellID = 49067,
    spellIDs = { 49066, 49067 },
    iconSpellID = 49067,
    trackingType = "cooldown",
})

Register({
    key = "hunter.frost_trap",
    cooldownID = 103018,
    category = CDM_CATEGORY_UTILITY,
    order = 110,
    spellID = 13809,
    iconSpellID = 13809,
    trackingType = "cooldown",
})

Register({
    key = "hunter.snake_trap",
    cooldownID = 103019,
    category = CDM_CATEGORY_UTILITY,
    order = 120,
    spellID = 34600,
    iconSpellID = 34600,
    trackingType = "cooldown",
})

Register({
    key = "hunter.call_of_the_wild",
    cooldownID = 103020,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 80,
    spellID = 53434,
    iconSpellID = 53434,
    trackingType = "cooldown",
})

-- Proc auras
Register({
    key = "hunter.lock_and_load",
    cooldownID = 203001,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 10,
    spellID = 56453,
    auraSpellID = 56453,
    iconSpellID = 56453,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 20) -- Surv: Lock and Load
        end,
        resolveSpellID = function()
            return 56453
        end,
    },
})

Register({
    key = "hunter.improved_steady_shot",
    cooldownID = 203002,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 20,
    spellID = 53220,
    auraSpellID = 53220,
    iconSpellID = 53220,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 12) -- MM: Improved Steady Shot
        end,
        resolveSpellID = function()
            return 53220
        end,
    },
})

Register({
    key = "hunter.kill_command",
    cooldownID = 203003,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 30,
    spellID = 34026,
    auraSpellID = 34026,
    iconSpellID = 34026,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

-- Persistent buffs
Register({
    key = "hunter.aspect_of_the_dragonhawk",
    cooldownID = 203101,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 10,
    spellID = 61847,
    auraSpellID = 61847,
    iconSpellID = 61847,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "hunter.aspect_of_the_viper",
    cooldownID = 203102,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 20,
    spellID = 34074,
    auraSpellID = 34074,
    iconSpellID = 34074,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

local function RegisterBasic(key, cooldownID, order, spellIDs, category, auraTags)
    Register({
        key = "hunter." .. key,
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

RegisterBasic("aimed_shot",       103022, 80,  { 19434, 20900, 20901, 20902, 20903, 20904, 27065, 49049, 49050 })
RegisterBasic("multi_shot",       103023, 90,  { 2643, 14288, 14289, 14290, 25294, 27021, 49047, 49048 })
RegisterBasic("arcane_shot",      103024, 100, { 3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287, 27019, 49044, 49045 })
RegisterBasic("raptor_strike",    103025, 110, { 2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266, 27014, 48995, 48996 })
RegisterBasic("mongoose_bite",    103026, 120, { 1495, 14269, 14270, 14271, 36916, 53339 })
RegisterBasic("counterattack",    103027, 130, { 19306, 20909, 20910, 27067, 48998, 48999 })
RegisterBasic("tranquilizing_shot", 103028, 140, { 19801 }, CDM_CATEGORY_UTILITY)
RegisterBasic("distracting_shot", 103029, 150, { 20736, 14319, 14320, 27022 }, CDM_CATEGORY_UTILITY)
RegisterBasic("masters_call",     103030, 160, { 53271 }, CDM_CATEGORY_UTILITY, { external = true })
RegisterBasic("flare",            103031, 170, { 1543 }, CDM_CATEGORY_UTILITY)
RegisterBasic("immolation_trap",  103032, 180, { 13795, 14302, 14303, 14304, 14305, 27023, 49055, 49056 }, CDM_CATEGORY_UTILITY)
RegisterBasic("freezing_arrow",   103033, 190, { 60192 }, CDM_CATEGORY_UTILITY)
