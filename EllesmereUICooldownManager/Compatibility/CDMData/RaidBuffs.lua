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

    local section = options.section or "external"
    -- `externalBuff` below describes where the picker sourced the spell: it
    -- was cast on the player by somebody else. The aura-filter `external`
    -- tag is intentionally narrower and marks targeted externals only. Raid
    -- buffs and routine healing buffs must not enter the raid-frame external
    -- row merely because another player supplied them.
    local tags = {}
    if section == "external" then tags.external = true end
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
        pickerHidden = options.pickerHidden,

        trackingType = "aura",
        hasAura = true,
        selfAura = false,
        auraTags = tags,

        externalBuff = true,
        providerClass = providerClass,
        recipientClasses = relevantClasses,
        buffCatalogSection = section,

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
--
-- WotLK raid bonuses from different classes often do not stack with each
-- other. Each such effect is one row whose aura list holds every provider and
-- rank, so the row follows whatever the raid actually supplied. Rows that a
-- group row has absorbed stay registered (cooldownIDs are sequential and saved
-- bar assignments must keep resolving) but are hidden from the picker.
--
-- Totem rows list the recipient-side buff auras, not the summon spells: the
-- summon never appears on the player.
-------------------------------------------------------------------------------

local MARK_OF_THE_WILD = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 48469 }
local GIFT_OF_THE_WILD = { 21849, 21850, 26991, 48470 }
local POWER_WORD_FORTITUDE = { 1243, 1244, 1245, 2791, 10937, 10938, 25389, 48161 }
local PRAYER_OF_FORTITUDE = { 21562, 21564, 25392, 48162 }
local DIVINE_SPIRIT = { 14752, 14818, 14819, 27841, 25312, 48073 }
local PRAYER_OF_SPIRIT = { 27681, 32999, 48074 }
local SHADOW_PROTECTION = { 976, 10957, 10958, 25433, 48169 }
local PRAYER_OF_SHADOW_PROTECTION = { 27683, 39374, 48170 }
local ARCANE_INTELLECT = { 1459, 1460, 1461, 10156, 10157, 27126, 42995 }
local ARCANE_BRILLIANCE = { 23028, 27127, 43002 }
local DALARAN_INTELLECT = { 61024, 61316 }
local FEL_INTELLIGENCE = { 54424, 57564, 57565, 57566, 57567 }
local BLESSING_OF_MIGHT = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932 }
local GREATER_BLESSING_OF_MIGHT = { 25782, 25916, 27141, 48933, 48934 }
local BLESSING_OF_WISDOM = { 19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936 }
local GREATER_BLESSING_OF_WISDOM = { 25894, 25918, 27143, 48937, 48938 }
local BATTLE_SHOUT = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048, 47436 }
local COMMANDING_SHOUT = { 469, 47439, 47440 }
local BLOOD_PACT = { 6307, 7804, 7805, 11766, 11767, 27268, 47982 }
local HORN_OF_WINTER = { 57330, 57623 }
local STRENGTH_OF_EARTH = { 8076, 8162, 8163, 10441, 25362, 25527, 57621, 58646 }
local MANA_SPRING = { 5677, 10491, 10493, 10494, 25569, 58775, 58776, 58777 }
local DEVOTION_AURA = { 465, 10290, 643, 10291, 1032, 10292, 10293, 27149, 48941, 48942 }
local STONESKIN = { 8072, 8156, 8157, 10403, 10404, 10405, 25506, 25507, 58752, 58754 }
local SHADOW_RESISTANCE_AURA = { 19876, 19895, 19896, 27151, 48943 }
local FIRE_RESISTANCE_AURA = { 19891, 19899, 19900, 27153, 48947 }
local FIRE_RESISTANCE_TOTEM = { 8185, 10534, 10535, 25562, 58738, 58740 }
local FROST_RESISTANCE_AURA = { 19888, 19897, 19898, 27152, 48945 }
local FROST_RESISTANCE_TOTEM = { 8182, 10476, 10477, 25559, 58742, 58744 }
local ASPECT_OF_THE_WILD = { 20043, 20190, 27045, 49071 }
local NATURE_RESISTANCE_TOTEM = { 10596, 10598, 10599, 25573, 58748, 58750 }

local function Merge(...)
    local merged = {}
    for i = 1, select("#", ...) do
        local list = select(i, ...)
        if type(list) == "number" then
            merged[#merged + 1] = list
        else
            for _, id in ipairs(list) do merged[#merged + 1] = id end
        end
    end
    return merged
end

-- Stats, armor, resistances
Register("DRUID", "mark_of_the_wild", 48469,
    Merge(MARK_OF_THE_WILD, GIFT_OF_THE_WILD, 69381), ALL,
    { section = "raid", excludeProvider = true })

Register("PRIEST", "power_word_fortitude", 48161,
    Merge(POWER_WORD_FORTITUDE, PRAYER_OF_FORTITUDE, 69377), ALL,
    { section = "raid" })

-- Fel Intelligence shares a slot with both Divine Spirit and Arcane
-- Intellect, so it belongs to both rows.
Register(nil, "divine_spirit", 48073,
    Merge(DIVINE_SPIRIT, PRAYER_OF_SPIRIT, FEL_INTELLIGENCE), MANA,
    { section = "raid", displayName = "Spirit" })

Register(nil, "shadow_protection", 48169,
    Merge(SHADOW_PROTECTION, PRAYER_OF_SHADOW_PROTECTION, SHADOW_RESISTANCE_AURA), ALL,
    { section = "raid", displayName = "Shadow Resistance" })

Register(nil, "arcane_intellect", 42995,
    Merge(ARCANE_INTELLECT, ARCANE_BRILLIANCE, DALARAN_INTELLECT, FEL_INTELLIGENCE), MANA,
    { section = "raid", displayName = "Intellect" })

Register("PALADIN", "blessing_of_kings", 25898,
    { 20217, 25898, 69378 }, ALL,
    { section = "raid", excludeProvider = true })

-- Absorbed by "attack_power".
Register("PALADIN", "blessing_of_might", 48934,
    Merge(BLESSING_OF_MIGHT, GREATER_BLESSING_OF_MIGHT), PHYSICAL,
    { section = "raid", excludeProvider = true, pickerHidden = true })

Register(nil, "blessing_of_wisdom", 48938,
    Merge(BLESSING_OF_WISDOM, GREATER_BLESSING_OF_WISDOM, MANA_SPRING), MANA,
    { section = "raid", displayName = "Mana Regeneration" })

Register("PALADIN", "blessing_of_sanctuary", 25899,
    { 20911, 25899 }, TANK,
    { section = "raid", excludeProvider = true })

-- Key kept for saved assignments; this is the Attack Power row.
Register(nil, "battle_shout", 47436,
    Merge(BATTLE_SHOUT, BLESSING_OF_MIGHT, GREATER_BLESSING_OF_MIGHT), PHYSICAL,
    { section = "raid", displayName = "Attack Power" })

Register(nil, "commanding_shout", 47440,
    Merge(COMMANDING_SHOUT, BLOOD_PACT), ALL,
    { section = "raid", displayName = "Max Health" })

Register(nil, "horn_of_winter", 57623,
    Merge(HORN_OF_WINTER, STRENGTH_OF_EARTH), PHYSICAL,
    { section = "raid", displayName = "Strength & Agility" })

-- Absorbed by "commanding_shout".
Register("WARLOCK", "blood_pact", 47982,
    BLOOD_PACT, ALL,
    { section = "raid", pickerHidden = true })

-- Absorbed by "blessing_of_wisdom".
Register("SHAMAN", "mana_spring", 58774,
    MANA_SPRING, MANA,
    { section = "raid", auraSpellID = 58777, pickerHidden = true })

Register(nil, "replenishment", 57669, { 57669 }, MANA,
    { section = "raid" })

-- WotLK deliberately shares most raid bonuses between several specs. Both
-- talent/cast IDs and recipient-side aura IDs are included; legacy cores
-- differ on which identity UnitAura reports for passive effects.
Register(nil, "attack_power_percent", 19506,
    { 19506, 53137, 53138, 30802, 30808, 30809 }, PHYSICAL,
    { section = "raid", displayName = "Attack Power %" })
Register(nil, "damage_percent", 31583,
    { 31579, 31582, 31583, 34455, 34459, 34460, 31869 }, ALL,
    { section = "raid", displayName = "Damage %" })
Register(nil, "haste_percent", 53648,
    { 48384, 48395, 48396, 53648 }, ALL,
    { section = "raid", displayName = "Haste %" })
Register(nil, "melee_haste", 55610,
    { 55610, 8515 }, PHYSICAL,
    { section = "raid", displayName = "Melee Haste" })
Register(nil, "physical_crit", 17007,
    { 17007, 29801 }, PHYSICAL,
    { section = "raid", displayName = "Melee & Ranged Crit" })
Register(nil, "spell_crit", 24907,
    { 24907, 51466, 51470 }, SPELLCASTER,
    { section = "raid", displayName = "Spell Crit" })
Register("SHAMAN", "wrath_of_air", 3738,
    { 2895 }, SPELLCASTER,
    { section = "raid", auraSpellID = 2895 })
Register(nil, "spell_power", 48090,
    { 48090, 47240,
      52109, 52110, 52111, 52112, 52113, 58651, 58654, 58655, -- Flametongue Totem
      57658, 57660, 57662, 57663, -- Totem of Wrath
    }, SPELLCASTER,
    { section = "raid", displayName = "Spell Power" })
-- Absorbed by "divine_spirit" and "arcane_intellect".
Register("WARLOCK", "fel_intelligence", 57567,
    FEL_INTELLIGENCE, MANA,
    { section = "raid", pickerHidden = true })
-- Renewed Hope, Vigilance and Blessing of Sanctuary's 3% damage reduction do
-- not stack. Sanctuary keeps its own row for the stat bonus as well.
Register(nil, "renewed_hope", 63944,
    { 63944, 68066, 50720, 20911, 25899 }, ALL,
    { section = "raid", displayName = "Damage Reduction" })
Register(nil, "healing_received", 65139,
    { 34123, 65139 }, ALL,
    { section = "raid", displayName = "Healing Received" })

-- Persistent class auras and encounter-specific resist coverage. Paladin-only
-- rows skip paladins, who receive their own aura definitions from the class
-- catalogue; rows shared with a totem stay visible to everyone.
Register(nil, "devotion_aura", 48942,
    Merge(DEVOTION_AURA, STONESKIN), ALL,
    { section = "raid", displayName = "Armor" })
Register("PALADIN", "retribution_aura", 54043,
    { 7294, 10298, 10299, 10300, 10301, 27150, 54043 }, TANK,
    { section = "raid", excludeProvider = true })
Register("PALADIN", "concentration_aura", 19746,
    { 19746 }, SPELLCASTER,
    { section = "raid", excludeProvider = true })
Register(nil, "fire_resistance_aura", 48947,
    Merge(FIRE_RESISTANCE_AURA, FIRE_RESISTANCE_TOTEM), ALL,
    { section = "raid", displayName = "Fire Resistance" })
Register(nil, "frost_resistance_aura", 48945,
    Merge(FROST_RESISTANCE_AURA, FROST_RESISTANCE_TOTEM), ALL,
    { section = "raid", displayName = "Frost Resistance" })
-- Absorbed by "shadow_protection".
Register("PALADIN", "shadow_resistance_aura", 48943,
    SHADOW_RESISTANCE_AURA, ALL,
    { section = "raid", excludeProvider = true, pickerHidden = true })
Register(nil, "nature_resistance", 49071,
    Merge(ASPECT_OF_THE_WILD, NATURE_RESISTANCE_TOTEM), ALL,
    { section = "raid", displayName = "Nature Resistance", auraTags = { defensive = true } })

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
Register("PALADIN", "hand_of_protection", 10278, { 1022, 5599, 10278 }, ALL,
    { excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "hand_of_sacrifice", 6940, { 6940 }, ALL,
    { excludeProvider = true, auraTags = { defensive = true } })
Register("PALADIN", "hand_of_salvation", 1038, { 1038 }, ALL,
    { excludeProvider = true })
Register("PALADIN", "divine_sacrifice", 64205,
    { 64205, 70940 }, ALL,
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
    { 974, 32593, 32594, 49283, 49284 }, TANK,
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

Register("DRUID", "rejuvenation", 48441,
    { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299, 26981, 26982, 48440, 48441 }, ALL,
    { section = "healing" })
Register("DRUID", "regrowth", 48443,
    { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, 26980, 48442, 48443 }, ALL,
    { section = "healing" })
Register("DRUID", "lifebloom", 48451, { 33763, 48450, 48451 }, ALL,
    { section = "healing" })
Register("DRUID", "wild_growth", 53251, { 48438, 53248, 53249, 53251 }, ALL,
    { section = "healing" })

Register("PRIEST", "power_word_shield", 48066,
    { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218, 48065, 48066 }, ALL,
    { section = "healing" })
Register("PRIEST", "divine_aegis", 47753, { 47753 }, ALL,
    { section = "healing", auraTags = { defensive = true } })
Register("PRIEST", "prayer_of_mending", 48113,
    { 41635, 48110, 48111 }, ALL,
    { section = "healing" })
Register("PRIEST", "renew", 48068,
    { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 25221, 25222, 48067, 48068 }, ALL,
    { section = "healing" })
Register("PRIEST", "inspiration", 15363, { 15363 }, ALL,
    { section = "healing", auraTags = { defensive = true } })
Register("PRIEST", "grace", 47930, { 47930 }, ALL,
    { section = "healing" })

Register("SHAMAN", "riptide", 61301, { 61295, 61299, 61300, 61301 }, ALL,
    { section = "healing" })
Register("SHAMAN", "earthliving", 52000, { 51945, 51990, 51997, 51998, 51999, 52000 }, ALL,
    { section = "healing" })
Register("SHAMAN", "ancestral_fortitude", 16237, { 16237 }, ALL,
    { section = "healing" })
