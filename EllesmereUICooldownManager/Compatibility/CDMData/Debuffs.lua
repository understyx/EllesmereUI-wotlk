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

local nextID = {}
local function Register(class, key, spellIDs, auraSpellID, iconSpellID, auraSpellIDs, anySourceDebuff, options)
    local classID = classIDs[class]
    if not classID then return end
    nextID[class] = (nextID[class] or 0) + 1
    local spellID = spellIDs[#spellIDs]
    local definition = {
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
    }
    -- Poison and talent-proc auras are not normal spellbook entries. Let their
    -- owning class/talent make the picker entry available while the runtime
    -- still matches the real target aura IDs above.
    if options and (options.alwaysKnown or options.talentTab or options.talentSpellID) then
        definition.resolvers = {
            requirements = function()
                if options.alwaysKnown then return true end
                if options.talentSpellID then
                    return HasLearnedTalentBySpellID(options.talentSpellID)
                end
                return HasLearnedTalent(options.talentTab, options.talentIndex)
            end,
            resolveSpellID = function()
                return spellID
            end,
        }
    end
    C_CooldownViewer.RegisterDefinition(definition)
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

local MINOR_ARMOR_AURAS = {
    770, 778, 9749, 9907, 26993, 48469, 16857,
    56631, -- Sting (wasp)
    702, 1108, 6205, 7646, 11707, 11708, 27224, 30909, 50511,
}
local PHYSICAL_VULNERABILITY_AURAS = { 30069, 30070, 58683 }
local ATTACK_SPEED_AURAS = {
    6343, 8198, 8204, 8205, 11580, 11581, 25264, 47501, 47502,
    55095, 58180, 58181, 53696, 68055,
}
local ATTACK_POWER_AURAS = {
    1160, 6190, 11554, 11555, 11556, 25202, 25203, 47437,
    99, 1735, 9490, 9747, 9898, 26998, 48559, 48560,
    702, 1108, 6205, 7646, 11707, 11708, 27224, 30909, 50511,
    26016, 26017, 55487,
}
local HIT_REDUCTION_AURAS = {
    3043,
    5570, 24974, 24975, 24976, 24977, 27013, 48468,
}
local SPELL_DAMAGE_AURAS = {
    1490, 11721, 11722, 27228, 47865,
    60431, 60432, 60433,
    51734, 51735,
}
local SPELL_CRIT_AURAS = { 22959, 12579, 17800 }
local CRIT_AURAS = {
    20335, 20336, 20337,
    -- Heart of the Crusader is carried by the active Judgement aura.
    20184, 20185, 20186,
    30708, 57663, 57722,
}
local BLEED_VULNERABILITY_AURAS = {
    33876, 33982, 33983, 48565, 48566,
    33878, 33986, 33987, 48563, 48564,
    46856, 46857, 57386, 57393,
}
local SPELL_HIT_AURAS = {
    33196, 33197, 33198,
    770, 778, 9749, 9907, 26993, 48469, 16857,
}
local HEAL_REDUCTION_AURAS = {
    12294, 21551, 21552, 21553, 25248, 30330, 47485, 47486,
    19434, 20900, 20901, 20902, 20903, 20904, 27065, 49049, 49050,
    13218, 13222, 13223, 13224, 27189, 57974, 57975,
    56112, 56113,
}
local CAST_SPEED_AURAS = {
    1714, 11719, 11720, 12889,
    5760, 31589,
}

local ROGUE_DEADLY_POISON_AURAS = { 2818, 2819, 11353, 11354, 25349, 26968, 27187, 57969, 57970 }
local ROGUE_WOUND_POISON_AURAS  = { 13218, 13222, 13223, 13224, 27189, 57974, 57975 }

-- Warrior
Register("WARRIOR", "rend",              { 772, 6546, 6547, 6548, 11572, 11573, 11574, 25208, 46845, 47465 })
Register("WARRIOR", "hamstring",         { 1715, 7372, 7373, 25212 })
Register("WARRIOR", "mortal_strike",     { 12294, 21551, 21552, 21553, 25248, 30330, 47485, 47486 }, nil, nil, HEAL_REDUCTION_AURAS, true)
Register("WARRIOR", "sunder_armor",      { 7386, 7405, 8380, 11596, 11597, 25225, 47467 }, nil, nil, MAJOR_ARMOR_AURAS, true)
Register("WARRIOR", "demoralizing_shout",{ 1160, 6190, 11554, 11555, 11556, 25202, 25203, 47437 }, nil, nil, ATTACK_POWER_AURAS, true)
Register("WARRIOR", "thunder_clap",      { 6343, 8198, 8204, 8205, 11580, 11581, 25264, 47501, 47502 }, nil, nil, ATTACK_SPEED_AURAS, true)
Register("WARRIOR", "piercing_howl",     { 12323 })
Register("WARRIOR", "blood_frenzy",      { 30069, 30070 }, 30070, 29859, PHYSICAL_VULNERABILITY_AURAS, true,
    { talentSpellID = 29859 })
Register("WARRIOR", "trauma",            { 46856, 46857 }, 46857, 46855, BLEED_VULNERABILITY_AURAS, true,
    { talentSpellID = 46855 })

-- Paladin
Register("PALADIN", "judgement_of_light",    { 20271 }, 20185, 20271)
Register("PALADIN", "judgement_of_wisdom",   { 53408 }, 20186, 53408)
Register("PALADIN", "judgement_of_justice",  { 53407 }, 20184, 53407)
Register("PALADIN", "hammer_of_justice",     { 853, 5588, 5589, 10308 })
Register("PALADIN", "repentance",            { 20066 })
Register("PALADIN", "turn_evil",             { 10326 })
Register("PALADIN", "holy_vengeance",        { 31803 }, 31803, 31803)
Register("PALADIN", "blood_corruption",      { 53742 }, 53742, 53742)
Register("PALADIN", "heart_of_the_crusader", { 20335, 20336, 20337 }, 20337, 20337, CRIT_AURAS, true)
Register("PALADIN", "vindication",            { 26016, 26017 }, 26017, 26017, ATTACK_POWER_AURAS, true,
    { talentSpellID = 26016 })
Register("PALADIN", "judgements_of_the_just", { 53695, 53696 }, 68055, 53696, ATTACK_SPEED_AURAS, true,
    { talentSpellID = 53696 })
Register("PALADIN", "hand_of_reckoning",     { 62124 })
Register("PALADIN", "righteous_defense",     { 31789 })

-- Hunter
Register("HUNTER", "serpent_sting",   { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 25295, 27016, 49000, 49001 })
Register("HUNTER", "viper_sting",     { 3034 })
Register("HUNTER", "scorpid_sting",   { 3043 }, nil, nil, HIT_REDUCTION_AURAS, true)
Register("HUNTER", "black_arrow",     { 3674, 63668, 63669, 63670, 63671, 63672 })
Register("HUNTER", "hunters_mark",    { 1130, 14323, 14324, 14325, 53338 })
Register("HUNTER", "concussive_shot", { 5116 })
Register("HUNTER", "wyvern_sting",    { 19386, 24132, 24133, 27068, 49011, 49012 })
Register("HUNTER", "aimed_shot",      { 19434, 20900, 20901, 20902, 20903, 20904, 27065, 49049, 49050 }, nil, nil, HEAL_REDUCTION_AURAS, true)
Register("HUNTER", "sting_minor_armor", { 56631 }, 56631, 56631, MINOR_ARMOR_AURAS, true,
    { alwaysKnown = true })
Register("HUNTER", "demoralizing_screech", { 55487 }, 55487, 55487, ATTACK_POWER_AURAS, true,
    { alwaysKnown = true })

-- Rogue
Register("ROGUE", "rupture",      { 1943, 8639, 8640, 11273, 11274, 11275, 26867, 48671, 48672 })
Register("ROGUE", "garrote",      { 703, 8631, 8632, 8633, 11289, 11290, 26839, 26884, 48675, 48676 })
Register("ROGUE", "kidney_shot",  { 408, 8643 })
Register("ROGUE", "cheap_shot",   { 1833 })
Register("ROGUE", "gouge",       { 1776 })
Register("ROGUE", "blind",       { 2094 })
Register("ROGUE", "sap",         { 6770, 2070, 11297, 51724 })
Register("ROGUE", "expose_armor", { 8647, 8649, 8650, 11197, 11198, 26866, 48669 }, nil, nil, MAJOR_ARMOR_AURAS, true)
Register("ROGUE", "hemorrhage",  { 16511, 17347, 17348, 26864, 48660 })
Register("ROGUE", "dismantle",   { 51722 })
Register("ROGUE", "riposte",     { 14251 }, nil, nil, nil, false, { talentTab = 2, talentIndex = 8 })
Register("ROGUE", "garrote_silence", { 703, 8631, 8632, 8633, 11289, 11290, 26839, 26884, 48675, 48676 }, 1330, 703)
Register("ROGUE", "improved_kick_silence", { 18425 }, 18425, 1769, nil, false, { talentTab = 2, talentIndex = 10 })

-- Poison applications are aura spell IDs rather than the item-creation spells
-- found in the Rogue spellbook, so they are explicitly exposed for all Rogues.
Register("ROGUE", "deadly_poison", ROGUE_DEADLY_POISON_AURAS, 57970, 57970,
    ROGUE_DEADLY_POISON_AURAS, false, { alwaysKnown = true })
Register("ROGUE", "wound_poison", ROGUE_WOUND_POISON_AURAS, 57975, 57975,
    HEAL_REDUCTION_AURAS, true, { alwaysKnown = true })
Register("ROGUE", "crippling_poison", { 3409 }, 3409, 3409, nil, false, { alwaysKnown = true })
Register("ROGUE", "mind_numbing_poison", { 5760 }, 5760, 5760, CAST_SPEED_AURAS, true, { alwaysKnown = true })


Register("ROGUE", "savage_combat", { 58413 }, 58683, 58413, PHYSICAL_VULNERABILITY_AURAS, true,
    { talentSpellID = 58413 })
Register("ROGUE", "waylay", { 51693 }, 51693, 51693, nil, false,
    { talentTab = 3, talentIndex = 23 })

-- Priest
Register("PRIEST", "shadow_word_pain", { 589, 594, 970, 992, 2767, 10892, 10893, 10894, 25367, 25368, 48124, 48125 })
Register("PRIEST", "vampiric_touch",   { 34914, 34916, 34917, 48159, 48160 })
Register("PRIEST", "devouring_plague", { 2944, 19276, 19277, 19278, 19279, 19280, 25467, 48299, 48300 })
Register("PRIEST", "holy_fire",        { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261, 25384, 48134, 48135 })
Register("PRIEST", "psychic_scream",   { 8122, 8124, 10888, 10890 })
Register("PRIEST", "silence",          { 15487 })
Register("PRIEST", "misery",           { 33196, 33197, 33198 }, 33198, 33193, SPELL_HIT_AURAS, true,
    { talentSpellID = 33193 })

-- Death Knight
Register("DEATHKNIGHT", "frost_fever",  { 45477 }, 55095, 45477, ATTACK_SPEED_AURAS, true)
Register("DEATHKNIGHT", "blood_plague", { 45462 }, 55078, 45462)
Register("DEATHKNIGHT", "chains_of_ice",{ 45524 })
Register("DEATHKNIGHT", "strangulate",  { 47476 })
Register("DEATHKNIGHT", "ebon_plague",  { 51734, 51735 }, 51735, 51161, SPELL_DAMAGE_AURAS, true,
    { talentSpellID = 51161 })

-- Shaman
Register("SHAMAN", "flame_shock", { 8050, 8052, 8053, 10447, 10448, 29228, 25457, 49232, 49233 })
Register("SHAMAN", "frost_shock", { 8056, 8058, 10472, 10473, 25464, 49235, 49236 })
Register("SHAMAN", "hex",         { 51514 })
Register("SHAMAN", "stormstrike", { 17364 })
Register("SHAMAN", "totem_of_wrath", { 30706, 57720, 57721, 57722 }, 30708, 57722, CRIT_AURAS, true,
    { talentSpellID = 30706 })

-- Mage
Register("MAGE", "living_bomb",     { 44457, 55359, 55360 })
Register("MAGE", "frostfire_bolt",  { 44614, 47610 })
Register("MAGE", "pyroblast",       { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 27132, 33938, 42890, 42891 })
Register("MAGE", "slow",            { 31589 }, nil, nil, CAST_SPEED_AURAS, true)
Register("MAGE", "polymorph",       { 118, 12824, 12825, 12826 })
Register("MAGE", "frost_nova",      { 122, 865, 6131, 10230, 27088, 42917 })
Register("MAGE", "deep_freeze",     { 44572 })
Register("MAGE", "improved_scorch", { 22959 }, 22959, 12873, SPELL_CRIT_AURAS, true,
    { talentSpellID = 12873 })
Register("MAGE", "winters_chill",   { 12579 }, 12579, 28593, SPELL_CRIT_AURAS, true,
    { talentSpellID = 28593 })

-- Warlock. Haunt deliberately exists here as well as in the cooldown catalog:
-- its target-debuff timer and its spell cooldown are independent CDM slots.
Register("WARLOCK", "corruption",          { 172, 6222, 6223, 7648, 11671, 11672, 25311, 27216, 47812, 47813 })
Register("WARLOCK", "curse_of_agony",      { 980, 1014, 6217, 11711, 11712, 11713, 27218, 47863, 47864 })
Register("WARLOCK", "curse_of_doom",       { 603, 30910, 47867 })
Register("WARLOCK", "unstable_affliction", { 30108, 30404, 30405, 47841, 47843 })
Register("WARLOCK", "haunt",               { 48181, 59161, 59163, 59164 })
Register("WARLOCK", "immolate",            { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309, 27215, 47810, 47811 })
Register("WARLOCK", "seed_of_corruption",  { 27243, 47835, 47836 })
Register("WARLOCK", "curse_of_elements",   { 1490, 11721, 11722, 27228, 47865 }, nil, nil, SPELL_DAMAGE_AURAS, true)
Register("WARLOCK", "curse_of_weakness",   { 702, 1108, 6205, 7646, 11707, 11708, 27224, 30909, 50511 }, nil, nil, ATTACK_POWER_AURAS, true)
Register("WARLOCK", "curse_of_weakness_armor", { 702, 1108, 6205, 7646, 11707, 11708, 27224, 30909, 50511 }, nil, 50511, MINOR_ARMOR_AURAS, true)
Register("WARLOCK", "curse_of_tongues",    { 1714, 11719, 11720, 12889 }, nil, nil, CAST_SPEED_AURAS, true)
Register("WARLOCK", "improved_shadow_bolt", { 17800 }, 17800, 17803, SPELL_CRIT_AURAS, true,
    { talentSpellID = 17803 })
Register("WARLOCK", "fear",                { 5782, 6213, 6215 })

-- Druid
Register("DRUID", "moonfire",          { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835, 26987, 48462, 48463 })
Register("DRUID", "insect_swarm",      { 5570, 24974, 24975, 24976, 24977, 27013, 48468 }, nil, nil, HIT_REDUCTION_AURAS, true)
Register("DRUID", "rake",              { 1822, 1823, 1824, 9904, 27003, 48573, 48574 })
Register("DRUID", "rip",               { 1079, 9492, 9493, 9752, 9894, 9896, 27008, 49799, 49800 })
Register("DRUID", "lacerate",          { 33745, 48567, 48568 })
Register("DRUID", "faerie_fire",       { 770, 778, 9749, 9907, 26993, 48469 }, nil, nil, MINOR_ARMOR_AURAS, true)
Register("DRUID", "faerie_fire_feral", { 16857 }, nil, nil, MINOR_ARMOR_AURAS, true)
Register("DRUID", "improved_faerie_fire", { 33600, 33601, 33602 }, nil, 33602, SPELL_HIT_AURAS, true,
    { talentSpellID = 33602 })
Register("DRUID", "demoralizing_roar", { 99, 1735, 9490, 9747, 9898, 26998, 48559, 48560 }, nil, nil, ATTACK_POWER_AURAS, true)
Register("DRUID", "mangle", { 33876, 33982, 33983, 48565, 48566, 33878, 33986, 33987, 48563, 48564 }, nil, 48566, BLEED_VULNERABILITY_AURAS, true)
Register("DRUID", "infected_wounds", { 58180, 58181 }, 58181, 48485, ATTACK_SPEED_AURAS, true,
    { talentSpellID = 48485 })
Register("DRUID", "earth_and_moon", { 60431, 60432, 60433 }, 60433, 48511, SPELL_DAMAGE_AURAS, true,
    { talentSpellID = 48511 })
Register("DRUID", "entangling_roots",  { 339, 1062, 5195, 5196, 9852, 9853, 26989, 53308 })
Register("DRUID", "cyclone",           { 33786 })
Register("DRUID", "hibernate",         { 2637, 18657, 18658 })
