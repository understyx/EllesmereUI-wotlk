local addonName, ns = ...

if not C_CooldownViewer or not C_CooldownViewer.RegisterDefinition then return end

-------------------------------------------------------------------------------
-- WotLK recipient-side buff catalogue
--
-- Class files describe buffs produced by the player. This catalogue describes
-- useful buffs that can be put ON the player by somebody else. Definitions are
-- filtered by recipient class at availability time, so the picker remains
-- relevant instead of showing every caster/melee-only raid effect to everyone.
--
-- The lists are deliberately class-level. Hybrids are included whenever one of
-- their specs benefits, matching the class-level filtering used by Raid Buff
-- Reminders. Spell families carry rank/group/aura aliases so a single picker
-- row follows whichever version a raid member actually supplies.
-------------------------------------------------------------------------------

local CDM_CATEGORY_BUFF_ICON = 3

local ALL = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true,
    PRIEST = true, DEATHKNIGHT = true, SHAMAN = true, MAGE = true,
    WARLOCK = true, DRUID = true,
}

local MANA = {
    PALADIN = true, HUNTER = true, PRIEST = true, SHAMAN = true,
    MAGE = true, WARLOCK = true, DRUID = true,
}

local SPELLCASTER = {
    PALADIN = true, PRIEST = true, SHAMAN = true, MAGE = true,
    WARLOCK = true, DRUID = true,
}

local PHYSICAL = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true,
    DEATHKNIGHT = true, SHAMAN = true, DRUID = true,
}

local TANK = {
    WARRIOR = true, PALADIN = true, DEATHKNIGHT = true, DRUID = true,
}

local nextID = 0

local function RecipientSet(classes, providerClass, excludeProvider)
    local result = {}
    for class, enabled in pairs(classes) do
        if enabled
           and not (excludeProvider and class == providerClass) then
            result[class] = true
        end
    end
    return result
end

local function Register(providerClass, key, spellID, auraSpellIDs, recipients, options)
    options = options or {}
    nextID = nextID + 1

    local relevantClasses = RecipientSet(recipients or ALL, providerClass,
        options.excludeProvider == true)
    local function IsRelevantRecipient()
        local _, playerClass = UnitClass("player")
        return playerClass and relevantClasses[playerClass] == true
    end

    local tags = { external = true }
    for tag, enabled in pairs(options.auraTags or {}) do
        if enabled then tags[tag] = true end
    end

    C_CooldownViewer.RegisterDefinition({
        key = "external_buff." .. key,
        -- Owner 12 is reserved for this recipient-side catalogue.
        cooldownID = 212000 + nextID,
        category = CDM_CATEGORY_BUFF_ICON,
        order = 1000 + nextID,

        spellID = spellID,
        auraSpellID = options.auraSpellID or spellID,
        auraSpellIDs = auraSpellIDs,
        linkedSpellIDs = auraSpellIDs,
        iconSpellID = options.iconSpellID or spellID,
        displayName = options.displayName,

        trackingType = "aura",
        hasAura = true,
        selfAura = false,
        auraTags = tags,

        externalBuff = true,
        providerClass = providerClass,
        recipientClasses = relevantClasses,
        buffCatalogSection = options.section or "external",

        -- External spells are not in the recipient's spellbook. Availability
        -- means "relevant to this class", not "known by this character".
        resolvers = {
            requirements = IsRelevantRecipient,
            resolveSpellID = function() return spellID end,
        },
    })
end

-------------------------------------------------------------------------------
-- Core raid buffs
-------------------------------------------------------------------------------

Register("DRUID", "mark_of_the_wild", 48469,
    { 48469, 48470, 1126, 21849, 69381 }, ALL,
    { section = "raid", excludeProvider = true })

Register("PRIEST", "power_word_fortitude", 48161,
    { 48161, 48162, 1243, 21562, 69377 }, ALL,
    { section = "raid" })

Register("PRIEST", "divine_spirit", 48073,
    { 48073, 48074, 14752, 27681 }, MANA,
    { section = "raid" })

Register("PRIEST", "shadow_protection", 48169,
    { 48169, 48170, 976, 27683 }, ALL,
    { section = "raid" })

Register("MAGE", "arcane_intellect", 42995,
    { 42995, 43002, 1459, 23028, 61024, 61316 }, MANA,
    { section = "raid", excludeProvider = true })

Register("PALADIN", "blessing_of_kings", 25898,
    { 20217, 25898, 69378 }, ALL,
    { section = "raid", excludeProvider = true })

Register("PALADIN", "blessing_of_might", 48934,
    { 48932, 48934, 19740, 25782 }, PHYSICAL,
    { section = "raid", excludeProvider = true })

Register("PALADIN", "blessing_of_wisdom", 48938,
    { 48936, 48938, 19742, 25894 }, MANA,
    { section = "raid", excludeProvider = true })

Register("PALADIN", "blessing_of_sanctuary", 25899,
    { 20911, 25899 }, TANK,
    { section = "raid", excludeProvider = true, auraTags = { defensive = true } })

Register("WARRIOR", "battle_shout", 47436,
    { 47436, 27578, 6673 }, PHYSICAL,
    { section = "raid", excludeProvider = true })

Register("WARRIOR", "commanding_shout", 47440,
    { 47440, 47439, 469 }, ALL,
    { section = "raid", excludeProvider = true, auraTags = { defensive = true } })

Register("DEATHKNIGHT", "horn_of_winter", 57623,
    { 57623, 57330, 58643, 8075 }, PHYSICAL,
    { section = "raid", excludeProvider = true })

Register("WARLOCK", "blood_pact", 47982,
    { 47982, 6307 }, ALL,
    { section = "raid", auraTags = { defensive = true } })

Register("SHAMAN", "mana_spring", 58774,
    { 58774, 5677 }, MANA,
    { section = "raid" })

Register(nil, "replenishment", 57669, { 57669 }, MANA,
    { section = "raid" })

-- WotLK deliberately shares most raid bonuses between several specs. Keep
-- those equivalent providers on one row so the assignment follows the effect
-- the player actually receives without filling the picker with non-stacking
-- duplicates. Both talent/cast IDs and recipient-side aura IDs are included;
-- legacy cores differ on which identity UnitAura reports for passive effects.
Register(nil, "attack_power_percent", 19506,
    { 19506, 53137, 53138, 30802, 30808, 30809 }, PHYSICAL,
    { section = "raid" })
Register(nil, "damage_percent", 31583,
    { 31579, 31582, 31583, 34455, 34459, 34460, 31869 }, ALL,
    { section = "raid" })
Register(nil, "haste_percent", 53648,
    { 48384, 48395, 48396, 53648 }, ALL,
    { section = "raid" })
Register(nil, "melee_haste", 55610,
    { 55610, 8512, 8515 }, PHYSICAL,
    { section = "raid" })
Register(nil, "physical_crit", 17007,
    { 17007, 29801 }, PHYSICAL,
    { section = "raid" })
Register(nil, "spell_crit", 24907,
    { 24907, 51466, 51470 }, SPELLCASTER,
    { section = "raid" })
Register("SHAMAN", "wrath_of_air", 3738,
    { 3738, 2895, 15447 }, SPELLCASTER,
    { section = "raid" })
Register(nil, "spell_power", 48090,
    { 48090, 47240, 58656, 30708, 57662, 57663, 57664, 57722 }, SPELLCASTER,
    { section = "raid" })
Register("WARLOCK", "fel_intelligence", 57567,
    { 57567, 54424 }, MANA,
    { section = "raid" })
Register("PRIEST", "renewed_hope", 63944,
    { 63944, 68066 }, ALL,
    { section = "raid", auraTags = { defensive = true } })
Register(nil, "healing_received", 65139,
    { 34123, 65139 }, ALL,
    { section = "raid" })

-- Persistent class auras and encounter-specific resist coverage. Paladins
-- already receive their own aura definitions from the class catalogue, so the
-- recipient catalogue omits the duplicate only for that provider class.
Register("PALADIN", "devotion_aura", 48942,
    { 465, 10290, 10291, 10292, 10293, 27149, 48941, 48942, 58753 }, ALL,
    { section = "raid", excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "retribution_aura", 54043,
    { 7294, 10298, 10299, 10300, 10301, 27150, 54043 }, TANK,
    { section = "raid", excludeProvider = true })
Register("PALADIN", "concentration_aura", 19746,
    { 19746 }, SPELLCASTER,
    { section = "raid", excludeProvider = true })
Register("PALADIN", "fire_resistance_aura", 48947,
    { 19891, 19899, 19900, 27153, 48947, 58739 }, ALL,
    { section = "raid", excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "frost_resistance_aura", 48945,
    { 19888, 19897, 19898, 27152, 48945, 58745 }, ALL,
    { section = "raid", excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "shadow_resistance_aura", 48943,
    { 19876, 19895, 19896, 27151, 48943 }, ALL,
    { section = "raid", excludeProvider = true, auraTags = { defensive = true } })
Register(nil, "nature_resistance", 49071,
    { 20043, 20190, 27045, 49071, 58749 }, ALL,
    { section = "raid", auraTags = { defensive = true } })

-------------------------------------------------------------------------------
-- Targeted raid externals and utility
-------------------------------------------------------------------------------

Register("DEATHKNIGHT", "anti_magic_zone", 51052,
    { 50461, 51052 }, ALL,
    { auraTags = { defensive = true } })
Register("DEATHKNIGHT", "hysteria", 49016, { 49016 }, PHYSICAL)

Register("DRUID", "innervate", 29166, { 29166 }, MANA)
Register("DRUID", "thorns", 53307,
    { 53307, 26992, 9910, 9756, 8914, 1075, 782, 467 }, TANK,
    { excludeProvider = true })

Register("HUNTER", "misdirection", 34477,
    { 35079, 34477 }, TANK)
Register("HUNTER", "masters_call", 53271, { 53271 }, ALL)
Register("HUNTER", "roar_of_sacrifice", 53480, { 53480 }, ALL,
    { auraTags = { defensive = true } })

Register("MAGE", "focus_magic", 54646, { 54646 }, SPELLCASTER,
    { excludeProvider = true })

Register("PALADIN", "hand_of_freedom", 1044, { 1044 }, ALL,
    { excludeProvider = true })
Register("PALADIN", "hand_of_protection", 10278, { 10278 }, ALL,
    { excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "hand_of_sacrifice", 6940, { 6940 }, ALL,
    { excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "hand_of_salvation", 1038, { 1038 }, ALL,
    { excludeProvider = true })
Register("PALADIN", "divine_sacrifice", 64205,
    { 53530, 64205 }, ALL,
    { excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "aura_mastery", 31821, { 31821 }, ALL,
    { excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "sacred_shield", 53601,
    { 53601, 58597 }, ALL,
    { excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "beacon_of_light", 53563, { 53563 }, TANK,
    { excludeProvider = true, section = "healing" })

Register("PRIEST", "fear_ward", 6346, { 6346 }, ALL)
Register("PRIEST", "guardian_spirit", 47788, { 47788 }, ALL,
    { auraTags = { defensive = true } })
Register("PRIEST", "pain_suppression", 33206, { 33206 }, ALL,
    { auraTags = { defensive = true } })
Register("PRIEST", "power_infusion", 10060, { 10060 }, SPELLCASTER)
Register("PRIEST", "hymn_of_hope", 64904, { 64904 }, MANA)

Register("ROGUE", "tricks_of_the_trade", 57934,
    { 59628, 57934, 57933 }, ALL,
    { excludeProvider = true })

Register("SHAMAN", "earth_shield", 49284,
    { 49284, 974 }, TANK,
    { excludeProvider = true, section = "healing", auraTags = { defensive = true } })
Register("SHAMAN", "mana_tide", 16191, { 16191 }, MANA)

Register("WARLOCK", "soulstone_resurrection", 47883,
    { 47883, 20707 }, ALL,
    { auraTags = { defensive = true } })

Register("WARRIOR", "intervene", 3411,
    { 3411, 46949 }, ALL,
    { auraTags = { defensive = true } })
Register("WARRIOR", "vigilance", 50725,
    { 50725, 50720 }, TANK,
    { auraTags = { defensive = true } })

-------------------------------------------------------------------------------
-- Healing buffs that live on the recipient
-------------------------------------------------------------------------------

Register("DRUID", "rejuvenation", 48441, { 48441, 774 }, ALL,
    { section = "healing" })
Register("DRUID", "regrowth", 48443, { 48443, 8936 }, ALL,
    { section = "healing" })
Register("DRUID", "lifebloom", 48451, { 48451, 33763 }, ALL,
    { section = "healing" })
Register("DRUID", "wild_growth", 53251, { 53251, 48438 }, ALL,
    { section = "healing" })

Register("PRIEST", "power_word_shield", 48066, { 48066, 17 }, ALL,
    { section = "healing", auraTags = { defensive = true } })
Register("PRIEST", "divine_aegis", 47753, { 47753 }, ALL,
    { section = "healing", auraTags = { defensive = true } })
Register("PRIEST", "prayer_of_mending", 48113,
    { 48111, 48113, 33076 }, ALL,
    { section = "healing" })
Register("PRIEST", "renew", 48068, { 48068, 139 }, ALL,
    { section = "healing" })
Register("PRIEST", "inspiration", 15363, { 15363 }, ALL,
    { section = "healing", auraTags = { defensive = true } })
Register("PRIEST", "grace", 47930, { 47930 }, ALL,
    { section = "healing" })

Register("SHAMAN", "riptide", 61301, { 61301, 61295 }, ALL,
    { section = "healing" })
Register("SHAMAN", "earthliving", 52000, { 52000, 51945 }, ALL,
    { section = "healing" })
Register("SHAMAN", "ancestral_fortitude", 16237, { 16237 }, ALL,
    { section = "healing", auraTags = { defensive = true } })
