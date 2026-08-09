local addonName, ns = ...

if not C_CooldownViewer or not C_CooldownViewer.RegisterDefinition then return end

-- Category Constants based on EllesmereUI defaults
-- These correspond to the internal enum values mapped to the specific cooldown viewer bars:
-- 1 = EssentialCooldownViewer
-- 2 = UtilityCooldownViewer
-- 3 = BuffIconCooldownViewer
-- 4 = BuffBarCooldownViewer
local CDM_CATEGORY_ESSENTIAL = 1
local CDM_CATEGORY_UTILITY   = 2
local CDM_CATEGORY_BUFF_ICON = 3
local CDM_CATEGORY_BUFF_BAR  = 4

-- Proc auras generally are not spellbook entries, so IsSpellKnown(auraID)
-- cannot decide whether their talent is learned.  The warrior dump records
-- the stable WotLK talent tab/index for these proc talents, so resolve them
-- directly from the talent tree instead.
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

-- cooldownID Schema: [CD type 1 digit][Class ID 2 digits][Unique ID 3 digits]
-- These IDs MUST be globally unique across the entire addon.
-- CD Types:
-- 1 = Class abilities (cooldowns)
-- 2 = Class buffs and procs
-- 3 = Racials
-- 4 = Items/Trinkets
-- Class IDs (standard WoW API):
-- 01=Warrior, 02=Paladin, 03=Hunter, 04=Rogue, 05=Priest, 06=Death Knight,
-- 07=Shaman, 08=Mage, 09=Warlock, 11=Druid.
-- The spell IDs below are the rank-appropriate IDs captured by the WotLK
-- warrior dump. Talent abilities remain registered so they become available
-- automatically when the player changes specialization.

-- Major cooldowns and defensive abilities
C_CooldownViewer.RegisterDefinition({
    key = "warrior.death_wish",
    cooldownID = 101001,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 10,

    spellID = 12292,
    iconSpellID = 12292,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.recklessness",
    cooldownID = 101002,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 20,

    spellID = 1719,
    iconSpellID = 1719,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.shattering_throw",
    cooldownID = 101003,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 30,

    spellID = 64382,
    iconSpellID = 64382,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.enraged_regeneration",
    cooldownID = 101004,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 40,

    spellID = 55694,
    iconSpellID = 55694,
    trackingType = "cooldown",
    auraTags = { defensive = true },

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.shield_wall",
    cooldownID = 101005,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 50,

    spellID = 871,
    iconSpellID = 871,
    trackingType = "cooldown",
    auraTags = { defensive = true },

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.shield_block",
    cooldownID = 101006,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 60,

    spellID = 2565,
    iconSpellID = 2565,
    trackingType = "cooldown",
    auraTags = { defensive = true },

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.last_stand",
    cooldownID = 101007,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 70,

    spellID = 12975,
    auraSpellIDs = { 12975, 12976 },
    iconSpellID = 12975,
    trackingType = "cooldown",
    auraTags = { defensive = true },

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.bladestorm",
    cooldownID = 101008,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 80,

    spellID = 46924,
    iconSpellID = 46924,
    trackingType = "cooldown",

    class = "WARRIOR",
})

-- Execute has no meaningful long cooldown, but belongs in the ability viewer
-- so its readiness can be shown. The compatibility renderer desaturates it
-- using IsUsableSpell, which also honors Sudden Death above execute range.
C_CooldownViewer.RegisterDefinition({
    key = "warrior.execute",
    cooldownID = 101021,
    category = CDM_CATEGORY_ESSENTIAL,
    order = 90,
    spellID = 47471,
    spellIDs = { 5308, 20658, 20660, 20661, 20662, 25234, 25236, 47470, 47471 },
    iconSpellID = 47471,
    trackingType = "cooldown",
    execute = true,
    class = "WARRIOR",
})

-- Mobility, interrupt, crowd-control, and secondary cooldowns
C_CooldownViewer.RegisterDefinition({
    key = "warrior.charge",
    cooldownID = 101009,
    category = CDM_CATEGORY_UTILITY,
    order = 10,

    spellID = 11578,
    iconSpellID = 11578,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.intercept",
    cooldownID = 101010,
    category = CDM_CATEGORY_UTILITY,
    order = 20,

    spellID = 20252,
    iconSpellID = 20252,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.intervene",
    cooldownID = 101022,
    category = CDM_CATEGORY_UTILITY,
    order = 25,

    spellID = 3411,
    iconSpellID = 3411,
    trackingType = "cooldown",
    auraTags = { external = true, defensive = true },

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.pummel",
    cooldownID = 101011,
    category = CDM_CATEGORY_UTILITY,
    order = 30,

    spellID = 6552,
    iconSpellID = 6552,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.spell_reflection",
    cooldownID = 101012,
    category = CDM_CATEGORY_UTILITY,
    order = 40,

    spellID = 23920,
    iconSpellID = 23920,
    trackingType = "cooldown",
    auraTags = { defensive = true },

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.heroic_throw",
    cooldownID = 101013,
    category = CDM_CATEGORY_UTILITY,
    order = 50,

    spellID = 57755,
    iconSpellID = 57755,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.berserker_rage",
    cooldownID = 101014,
    category = CDM_CATEGORY_UTILITY,
    order = 60,

    spellID = 18499,
    iconSpellID = 18499,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.bloodrage",
    cooldownID = 101015,
    category = CDM_CATEGORY_UTILITY,
    order = 70,

    spellID = 2687,
    iconSpellID = 2687,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.intimidating_shout",
    cooldownID = 101016,
    category = CDM_CATEGORY_UTILITY,
    order = 80,

    spellID = 5246,
    iconSpellID = 5246,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.challenging_shout",
    cooldownID = 101017,
    category = CDM_CATEGORY_UTILITY,
    order = 90,

    spellID = 1161,
    iconSpellID = 1161,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.piercing_howl",
    cooldownID = 101018,
    category = CDM_CATEGORY_UTILITY,
    order = 100,

    spellID = 12323,
    iconSpellID = 12323,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.concussion_blow",
    cooldownID = 101019,
    category = CDM_CATEGORY_UTILITY,
    order = 110,

    spellID = 12809,
    iconSpellID = 12809,
    trackingType = "cooldown",

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.shockwave",
    cooldownID = 101020,
    category = CDM_CATEGORY_UTILITY,
    order = 120,

    spellID = 46968,
    iconSpellID = 46968,
    trackingType = "cooldown",

    class = "WARRIOR",
})

-- Warrior proc auras recorded by the dump
C_CooldownViewer.RegisterDefinition({
    key = "warrior.flurry",
    cooldownID = 201001,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 10,

    spellID = 12970,
    auraSpellID = 12970,
    iconSpellID = 12970,

    trackingType = "aura",
    hasAura = true,
    selfAura = true,

    class = "WARRIOR",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 17) -- Fury: Flurry
        end,
        resolveSpellID = function()
            return 12970
        end,
    },
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.bloodsurge",
    cooldownID = 201002,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 20,

    spellID = 46916,
    auraSpellID = 46916,
    iconSpellID = 46916,

    trackingType = "aura",
    hasAura = true,
    selfAura = true,

    class = "WARRIOR",
    resolvers = {
        requirements = function()
            return HasLearnedTalent(2, 25) -- Fury: Bloodsurge
        end,
        resolveSpellID = function()
            return 46916
        end,
    },
})

-- Persistent self-buffs recorded by the dump
C_CooldownViewer.RegisterDefinition({
    key = "warrior.battle_shout",
    cooldownID = 201004,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 10,

    spellID = 47436,
    auraSpellID = 47436,
    iconSpellID = 47436,

    trackingType = "aura",
    hasAura = true,
    selfAura = true,

    class = "WARRIOR",
})

C_CooldownViewer.RegisterDefinition({
    key = "warrior.commanding_shout",
    cooldownID = 201005,
    category = CDM_CATEGORY_BUFF_BAR,
    order = 20,

    spellID = 47440,
    auraSpellID = 47440,
    iconSpellID = 47440,

    trackingType = "aura",
    hasAura = true,
    selfAura = true,

    class = "WARRIOR",
})

local function RegisterBasic(key, cooldownID, order, spellIDs, category, auraTags)
    C_CooldownViewer.RegisterDefinition({
        key = "warrior." .. key,
        cooldownID = cooldownID,
        category = category or CDM_CATEGORY_ESSENTIAL,
        order = order,
        spellID = spellIDs[#spellIDs],
        spellIDs = spellIDs,
        iconSpellID = spellIDs[#spellIDs],
        trackingType = "cooldown",
        auraTags = auraTags,
        class = "WARRIOR",
    })
end

RegisterBasic("mortal_strike",    101023, 100, { 12294, 21551, 21552, 21553, 25248, 30330, 47485, 47486 })
RegisterBasic("bloodthirst",      101024, 110, { 23881, 23892, 23893, 23894, 25251, 30335, 47449, 47450 })
RegisterBasic("shield_slam",      101025, 120, { 23922, 23923, 23924, 23925, 25258, 30356, 47487, 47488 })
RegisterBasic("revenge",          101026, 130, { 6572, 6574, 7379, 11600, 11601, 25288, 25269, 30357, 57823 })
RegisterBasic("overpower",        101027, 140, { 7384 })
RegisterBasic("whirlwind",        101028, 150, { 1680 })
RegisterBasic("thunder_clap",     101029, 160, { 6343, 8198, 8204, 8205, 11580, 11581, 25264, 47501, 47502 })
RegisterBasic("mocking_blow",     101030, 110, { 694 }, CDM_CATEGORY_UTILITY)
RegisterBasic("disarm",           101031, 120, { 676 }, CDM_CATEGORY_UTILITY)
RegisterBasic("retaliation",      101032, 170, { 20230 }, CDM_CATEGORY_ESSENTIAL, { defensive = true })
RegisterBasic("sweeping_strikes", 101033, 180, { 12328 })
RegisterBasic("heroic_fury",      101034, 130, { 60970 }, CDM_CATEGORY_UTILITY)
RegisterBasic("taunt",            101035, 140, { 355 }, CDM_CATEGORY_UTILITY)
RegisterBasic("shield_bash",      101036, 150, { 72, 1671, 1672, 29704 }, CDM_CATEGORY_UTILITY)
