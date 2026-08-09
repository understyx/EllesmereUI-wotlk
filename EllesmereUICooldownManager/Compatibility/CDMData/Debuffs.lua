local addonName, ns = ...

if not C_CooldownViewer or not C_CooldownViewer.RegisterDefinition then return end

-- WotLK has no native tracked-debuff viewer. These definitions feed the
-- compatibility viewer with the player's common class debuffs. The active rank
-- is resolved from the spellbook and the actual duration/stacks always come
-- from the current target's PLAYER-filtered harmful auras.
local CDM_CATEGORY_DEBUFF = 5

local classIDs = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

local nextID = {}
local function Register(class, key, spellIDs, auraSpellID, iconSpellID, auraSpellIDs, anySourceDebuff)
    local classID = classIDs[class]
    if not classID then return end
    nextID[class] = (nextID[class] or 0) + 1
    local spellID = spellIDs[#spellIDs]
    C_CooldownViewer.RegisterDefinition({
        key = string.lower(class) .. ".debuff." .. key,
        cooldownID = 500000 + classID * 1000 + nextID[class],
        category = CDM_CATEGORY_DEBUFF,
        order = nextID[class] * 10,
        spellID = spellID,
        spellIDs = spellIDs,
        auraSpellID = auraSpellID,
        auraSpellIDs = auraSpellIDs,
        anySourceDebuff = anySourceDebuff,
        debuffScope = anySourceDebuff and "raid" or "personal",
        iconSpellID = iconSpellID or spellID,
        trackingType = "debuff",
        hasAura = true,
        auraUnit = "target",
        class = class,
    })
end

-- Equivalent raid-debuff effects share one detection family.  The player only
-- adds their own class's familiar spell to the bar, but the timer activates for
-- any equivalent aura on the target, regardless of who applied it.
local MAJOR_ARMOR_AURAS = {
    -- Sunder Armor (all standard ranks plus the server's level-52 debuff
    -- variant 58567), Expose Armor, Acid Spit (hunter pet).
    7386, 7405, 8380, 11596, 11597, 25225, 47467,
    58567,
    8647, 8649, 8650, 11197, 11198, 26866, 48669,
    55749, 55750,
}

-- Warrior
Register("WARRIOR", "rend",              { 772, 6546, 6547, 6548, 11572, 11573, 11574, 25208, 46845, 47465 })
Register("WARRIOR", "hamstring",         { 1715, 7372, 7373, 25212 })
Register("WARRIOR", "mortal_strike",     { 12294, 21551, 21552, 21553, 25248, 30330, 47485, 47486 })
Register("WARRIOR", "sunder_armor",      { 7386, 7405, 8380, 11596, 11597, 25225, 47467 }, nil, nil, MAJOR_ARMOR_AURAS, true)
Register("WARRIOR", "demoralizing_shout",{ 1160, 6190, 11554, 11555, 11556, 25202, 25203, 47437 })
Register("WARRIOR", "thunder_clap",      { 6343, 8198, 8204, 8205, 11580, 11581, 25264, 47501, 47502 })
Register("WARRIOR", "piercing_howl",     { 12323 })

-- Paladin
Register("PALADIN", "judgement_of_light",    { 20271 }, 20185, 20271)
Register("PALADIN", "judgement_of_wisdom",   { 53408 }, 20186, 53408)
Register("PALADIN", "judgement_of_justice",  { 53407 }, 20184, 53407)
Register("PALADIN", "hammer_of_justice",     { 853, 5588, 5589, 10308 })
Register("PALADIN", "repentance",            { 20066 })
Register("PALADIN", "turn_evil",             { 10326 })
Register("PALADIN", "holy_vengeance",        { 31803 }, 31803, 31803)
Register("PALADIN", "blood_corruption",      { 53742 }, 53742, 53742)
Register("PALADIN", "heart_of_the_crusader", { 20335, 20336, 20337 }, 20337, 20337)
Register("PALADIN", "hand_of_reckoning",     { 62124 })
Register("PALADIN", "righteous_defense",     { 31789 })

-- Hunter
Register("HUNTER", "serpent_sting",   { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 25295, 27016, 49000, 49001 })
Register("HUNTER", "viper_sting",     { 3034 })
Register("HUNTER", "scorpid_sting",   { 3043 })
Register("HUNTER", "black_arrow",     { 3674, 63668, 63669, 63670, 63671, 63672 })
Register("HUNTER", "hunters_mark",    { 1130, 14323, 14324, 14325, 53338 })
Register("HUNTER", "concussive_shot", { 5116 })
Register("HUNTER", "wyvern_sting",    { 19386, 24132, 24133, 27068, 49011, 49012 })

-- Rogue
Register("ROGUE", "rupture",      { 1943, 8639, 8640, 11273, 11274, 11275, 26867, 48671, 48672 })
Register("ROGUE", "garrote",      { 703, 8631, 8632, 8633, 11289, 11290, 26839, 26884, 48675, 48676 })
Register("ROGUE", "kidney_shot",  { 408, 8643 })
Register("ROGUE", "cheap_shot",   { 1833 })
Register("ROGUE", "gouge",       { 1776 })
Register("ROGUE", "blind",       { 2094 })
Register("ROGUE", "sap",         { 6770, 2070, 11297, 51724 })
Register("ROGUE", "expose_armor", { 8647, 8649, 8650, 11197, 11198, 26866, 48669 }, nil, nil, MAJOR_ARMOR_AURAS, true)

-- Priest
Register("PRIEST", "shadow_word_pain", { 589, 594, 970, 992, 2767, 10892, 10893, 10894, 25367, 25368, 48124, 48125 })
Register("PRIEST", "vampiric_touch",   { 34914, 34916, 34917, 48159, 48160 })
Register("PRIEST", "devouring_plague", { 2944, 19276, 19277, 19278, 19279, 19280, 25467, 48299, 48300 })
Register("PRIEST", "holy_fire",        { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261, 25384, 48134, 48135 })
Register("PRIEST", "psychic_scream",   { 8122, 8124, 10888, 10890 })
Register("PRIEST", "silence",          { 15487 })

-- Death Knight
Register("DEATHKNIGHT", "frost_fever",  { 45477 }, 55095, 45477)
Register("DEATHKNIGHT", "blood_plague", { 45462 }, 55078, 45462)
Register("DEATHKNIGHT", "chains_of_ice",{ 45524 })
Register("DEATHKNIGHT", "strangulate",  { 47476 })

-- Shaman
Register("SHAMAN", "flame_shock", { 8050, 8052, 8053, 10447, 10448, 29228, 25457, 49232, 49233 })
Register("SHAMAN", "frost_shock", { 8056, 8058, 10472, 10473, 25464, 49235, 49236 })
Register("SHAMAN", "hex",         { 51514 })
Register("SHAMAN", "stormstrike", { 17364 })

-- Mage
Register("MAGE", "living_bomb",     { 44457, 55359, 55360 })
Register("MAGE", "frostfire_bolt",  { 44614, 47610 })
Register("MAGE", "pyroblast",       { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 27132, 33938, 42890, 42891 })
Register("MAGE", "slow",            { 31589 })
Register("MAGE", "polymorph",       { 118, 12824, 12825, 12826 })
Register("MAGE", "frost_nova",      { 122, 865, 6131, 10230, 27088, 42917 })
Register("MAGE", "deep_freeze",     { 44572 })

-- Warlock. Haunt deliberately exists here as well as in the cooldown catalog:
-- its target-debuff timer and its spell cooldown are independent CDM slots.
Register("WARLOCK", "corruption",          { 172, 6222, 6223, 7648, 11671, 11672, 25311, 27216, 47812, 47813 })
Register("WARLOCK", "curse_of_agony",      { 980, 1014, 6217, 11711, 11712, 11713, 27218, 47863, 47864 })
Register("WARLOCK", "curse_of_doom",       { 603, 30910, 47867 })
Register("WARLOCK", "unstable_affliction", { 30108, 30404, 30405, 47841, 47843 })
Register("WARLOCK", "haunt",               { 48181, 59161, 59163, 59164 })
Register("WARLOCK", "immolate",            { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309, 27215, 47810, 47811 })
Register("WARLOCK", "seed_of_corruption",  { 27243, 47835, 47836 })
Register("WARLOCK", "curse_of_elements",   { 1490, 11721, 11722, 27228, 47865 })
Register("WARLOCK", "curse_of_weakness",   { 702, 1108, 6205, 7646, 11707, 11708, 27224, 30909, 50511 })
Register("WARLOCK", "fear",                { 5782, 6213, 6215 })

-- Druid
Register("DRUID", "moonfire",          { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835, 26987, 48462, 48463 })
Register("DRUID", "insect_swarm",      { 5570, 24974, 24975, 24976, 24977, 27013, 48468 })
Register("DRUID", "rake",              { 1822, 1823, 1824, 9904, 27003, 48573, 48574 })
Register("DRUID", "rip",               { 1079, 9492, 9493, 9752, 9894, 9896, 27008, 49799, 49800 })
Register("DRUID", "lacerate",          { 33745, 48567, 48568 })
Register("DRUID", "faerie_fire",       { 770, 778, 9749, 9907, 26993, 48469 })
Register("DRUID", "faerie_fire_feral", { 16857 })
Register("DRUID", "entangling_roots",  { 339, 1062, 5195, 5196, 9852, 9853, 26989, 53308 })
Register("DRUID", "cyclone",           { 33786 })
Register("DRUID", "hibernate",         { 2637, 18657, 18658 })
