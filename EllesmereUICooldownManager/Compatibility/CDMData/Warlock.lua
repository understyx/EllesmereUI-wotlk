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

-- Warlock = class 09. Cooldowns = 109XXX, Buffs/Procs = 209XXX.

local AURA_TAGS = {
    ["warlock.sacrifice"] = { defensive = true },
}

local function Register(def)
    def.class = "WARLOCK"
    def.auraTags = def.auraTags or AURA_TAGS[def.key]
    C_CooldownViewer.RegisterDefinition(def)
end

-- Major cooldowns
Register({
    key = "warlock.metamorphosis",
    cooldownID = 109001,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 10,
    spellID = 47241,
    iconSpellID = 47241,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 26) -- Demo: Metamorphosis
        end,
        resolveSpellID = function()
            return 47241
        end,
    },
})

Register({
    key = "warlock.summon_infernal",
    cooldownID = 109002,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 20,
    spellID = 1122,
    iconSpellID = 1122,
    trackingType = "cooldown",
})

Register({
    key = "warlock.summon_doomguard",
    cooldownID = 109003,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 30,
    spellID = 18540,
    iconSpellID = 18540,
    trackingType = "cooldown",
})

Register({
    key = "warlock.chaos_bolt",
    cooldownID = 109004,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 40,
    spellID = 59172,
    spellIDs = { 50796, 59170, 59171, 59172 },
    iconSpellID = 59172,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 24) -- Destro: Chaos Bolt
        end,
        resolveSpellID = function()
            return 59172
        end,
    },
})

Register({
    key = "warlock.conflagrate",
    cooldownID = 109005,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 50,
    spellID = 17962,
    iconSpellID = 17962,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 13) -- Destro: Conflagrate
        end,
        resolveSpellID = function()
            return 17962
        end,
    },
})

Register({
    key = "warlock.shadowburn",
    cooldownID = 109006,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 60,
    spellID = 47827,
    spellIDs = { 47826, 47827 },
    iconSpellID = 47827,
    trackingType = "cooldown",
    -- Shadowburn requires the target to be below 20% health.
    -- IsUsableSpell handles the health threshold check, so the icon
    -- desaturates automatically when the target is not in execute range.
    execute = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 3) -- Destro: Shadowburn
        end,
        resolveSpellID = function()
            return 47827
        end,
    },
})

Register({
    key = "warlock.haunt",
    cooldownID = 109007,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 70,
    spellID = 59164,
    spellIDs = { 48181, 59161, 59163, 59164 },
    iconSpellID = 59164,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 26) -- Affliction: Haunt
        end,
        resolveSpellID = function()
            return 59164
        end,
    },
})

Register({
    key = "warlock.demonic_empowerment",
    cooldownID = 109008,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 80,
    spellID = 47193,
    iconSpellID = 47193,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 20) -- Demo: Demonic Empowerment
        end,
        resolveSpellID = function()
            return 47193
        end,
    },
})

-- Utility cooldowns
Register({
    key = "warlock.shadowfury",
    cooldownID = 109009,
    category = CDM_CATEGORY_UTILITY,
    order = 10,
    spellID = 47847,
    spellIDs = { 47846, 47847 },
    iconSpellID = 47847,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 18) -- Destro: Shadowfury
        end,
        resolveSpellID = function()
            return 47847
        end,
    },
})

Register({
    key = "warlock.death_coil",
    cooldownID = 109010,
    category = CDM_CATEGORY_UTILITY,
    order = 20,
    spellID = 47860,
    spellIDs = { 47859, 47860 },
    iconSpellID = 47860,
    trackingType = "cooldown",
})

Register({
    key = "warlock.howl_of_terror",
    cooldownID = 109011,
    category = CDM_CATEGORY_UTILITY,
    order = 30,
    spellID = 17928,
    iconSpellID = 17928,
    trackingType = "cooldown",
})

Register({
    key = "warlock.fear",
    cooldownID = 109012,
    category = CDM_CATEGORY_UTILITY,
    order = 40,
    spellID = 6215,
    iconSpellID = 6215,
    trackingType = "cooldown",
})

Register({
    key = "warlock.demonic_circle_teleport",
    cooldownID = 109013,
    category = CDM_CATEGORY_UTILITY,
    order = 50,
    spellID = 48020,
    iconSpellID = 48020,
    trackingType = "cooldown",
})

Register({
    key = "warlock.soulshatter",
    cooldownID = 109014,
    category = CDM_CATEGORY_UTILITY,
    order = 60,
    spellID = 29858,
    iconSpellID = 29858,
    trackingType = "cooldown",
})

Register({
    key = "warlock.sacrifice",
    cooldownID = 109016,
    category = CDM_CATEGORY_UTILITY,
    order = 65,
    spellID = 47986,
    spellIDs = { 7812, 19438, 19440, 19441, 19442, 19443, 27273, 47985, 47986 },
    iconSpellID = 47986,
    trackingType = "cooldown",
    resolvers = {
        requirements = function()
            return HasPetSpellByID(47986)
        end,
        resolveSpellID = function()
            return 47986
        end,
    },
})

Register({
    key = "warlock.shadowflame",
    cooldownID = 109015,
    category = CDM_CATEGORY_UTILITY,
    order = 70,
    spellID = 61290,
    spellIDs = { 47897, 61290 },
    iconSpellID = 61290,
    trackingType = "cooldown",
})

-- Proc auras
Register({
    key = "warlock.nightfall",
    cooldownID = 209001,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 10,
    spellID = 17941,
    auraSpellID = 17941,
    iconSpellID = 17941,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(1, 5) -- Affliction: Nightfall
        end,
        resolveSpellID = function()
            return 17941
        end,
    },
})

Register({
    key = "warlock.backdraft",
    cooldownID = 209002,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 20,
    spellID = 54277,
    auraSpellID = 54277,
    iconSpellID = 54277,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 16) -- Destro: Backdraft
        end,
        resolveSpellID = function()
            return 54277
        end,
    },
})

Register({
    key = "warlock.molten_core",
    cooldownID = 209003,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 30,
    spellID = 71165,
    auraSpellID = 71165,
    iconSpellID = 71165,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 21) -- Demo: Molten Core
        end,
        resolveSpellID = function()
            return 71165
        end,
    },
})

Register({
    key = "warlock.decimation",
    cooldownID = 209004,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 40,
    spellID = 63167,
    auraSpellID = 63167,
    iconSpellID = 63167,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 22) -- Demo: Decimation
        end,
        resolveSpellID = function()
            return 63167
        end,
    },
})

Register({
    key = "warlock.backlash",
    cooldownID = 209005,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 50,
    spellID = 34939,
    auraSpellID = 34939,
    iconSpellID = 34939,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
    resolvers = {
        requirements = function()
            return HasLearnedTalent(3, 11) -- Destro: Backlash
        end,
        resolveSpellID = function()
            return 34939
        end,
    },
})

-- Persistent buffs
Register({
    key = "warlock.fel_armor",
    cooldownID = 209101,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 10,
    spellID = 47893,
    auraSpellID = 47893,
    iconSpellID = 47893,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "warlock.demon_armor",
    cooldownID = 209102,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 20,
    spellID = 47889,
    auraSpellID = 47889,
    iconSpellID = 47889,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

Register({
    key = "warlock.life_tap_glyph",
    cooldownID = 209103,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 30,
    spellID = 63321,
    auraSpellID = 63321,
    iconSpellID = 63321,
    trackingType = "aura",
    hasAura = true,
    selfAura = true,
})

local function RegisterBasic(key, cooldownID, order, spellIDs, category, auraTags)
    Register({
        key = "warlock." .. key,
        cooldownID = cooldownID,
        category = category or CDM_CATEGORY_UTILITY,
        order = order,
        spellID = spellIDs[#spellIDs],
        spellIDs = spellIDs,
        iconSpellID = spellIDs[#spellIDs],
        trackingType = "cooldown",
        auraTags = auraTags,
    })
end

RegisterBasic("fel_domination", 109017, 70, { 18708 }, CDM_CATEGORY_ESSENTIAL)
RegisterBasic("shadow_ward",    109018, 80, { 6229, 11739, 11740, 28610, 47890, 47891 }, CDM_CATEGORY_UTILITY, { defensive = true })
RegisterBasic("spell_lock",     109019, 90, { 19244, 19647 }, CDM_CATEGORY_UTILITY)
RegisterBasic("devour_magic",   109020, 100, { 19505, 19731, 19734, 19736, 27276, 27277, 48011 }, CDM_CATEGORY_UTILITY)
RegisterBasic("intercept",      109021, 110, { 30151, 30194, 30198, 47996 }, CDM_CATEGORY_UTILITY)
