local _, ns = ...
ns.SnapshotTracker = ns.SnapshotTracker or {}

-- Create module here so data tables can reference it
local SnapshotTracker = {}
ns.SnapshotTracker.SnapshotTracker = SnapshotTracker

-- Localize globals needed by data tables
local GetLocale = GetLocale

local function GetNumSetItemsEquipped(setId)
    if WeakAuras and WeakAuras.GetNumSetItemsEquipped then
        return WeakAuras.GetNumSetItemsEquipped(setId)
    end
    return 0
end

-- ==========================================================
-- CLASS-SPECIFIC DATA TABLES
-- ==========================================================

-- The unit used for target-dependent calculations (level, debuffs, health)
local TARGET_UNIT = "target"

-- DoTs refreshed through talents/glyphs keep their original snapshot.
-- Only a fresh SPELL_AURA_APPLIED recalculates damage/crit modifiers.
-- A manual recast (detected via SPELL_CAST_SUCCESS) also recalculates.
local noRecalcOnRefresh = {
    -- Warlock: Corruption — refreshed by Everlasting Affliction
    [172]   = true, [6222]  = true, [6223]  = true, [7648]  = true,
    [11671] = true, [11672] = true, [25311] = true, [27216] = true,
    [47812] = true, [47813] = true,
    -- Hunter: Serpent Sting — refreshed by Chimera Shot
    [1978]  = true, [13549] = true, [13550] = true, [13551] = true,
    [13552] = true, [13553] = true, [13554] = true, [13555] = true,
    [25295] = true, [27016] = true, [49000] = true, [49001] = true,
    -- Priest: Shadow Word: Pain — refreshed by Pain and Suffering (Mind Flay)
    [589]   = true, [594]   = true, [970]   = true, [9014]  = true,
    [9752]  = true, [25367] = true, [25368] = true, [48124] = true,
    [48125] = true,
    -- DK: Blood Plague — refreshed by Pestilence (Glyph of Disease, when equipped).
    -- Without the glyph only Plague Strike can refresh it, which is tracked via
    -- indirectApplicators, so snapshot recalculation is always correct.
    [55078] = true,
    -- DK: Frost Fever — refreshed by Pestilence (Glyph of Disease, when equipped)
    -- or Howling Blast. Both are tracked via indirectApplicators when cast directly.
    [55095] = true,
}

-- Abilities that directly (re)apply a noRecalcOnRefresh DoT via a different
-- spell (e.g. Plague Strike applies Blood Plague). Value = the DoT spell ID.
-- For Corruption/Serpent Sting/Shadow Word: Pain the cast ID already matches
-- the aura ID, so they don't need entries here.
local indirectApplicators = {
    -- Plague Strike → Blood Plague (55078)
    [45462] = 55078, [49917] = 55078, [49918] = 55078,
    [49919] = 55078, [49920] = 55078, [49921] = 55078,
    -- Icy Touch → Frost Fever (55095)
    [45477] = 55095, [49896] = 55095, [49903] = 55095,
    [49904] = 55095, [49909] = 55095,
    -- Howling Blast → Frost Fever (55095)
    [49184] = 55095, [51409] = 55095, [51410] = 55095, [51411] = 55095,
}

-- Spell crit school per class (shadow=6, nature=4, etc.)
local critSchools = {
    WARLOCK = 6,
    PRIEST  = 6,
    HUNTER  = 4,
}

-- Talent-based crit chance bonuses. Key = tab*100 + talentIndex, value = % per rank.
local critChanceTalents = {
    WARLOCK = {
        [116] = 3, -- Malediction
    },
    PRIEST = {
        [319] = 3, -- Mind Melt
    },
}

-- Set-bonus crit chance
local critChanceSetBonuses = {
    WARLOCK = {
        function() return GetNumSetItemsEquipped(884) >= 2 and 5 or nil end, -- T10 2set
    },
    PRIEST = {
        function() return GetNumSetItemsEquipped(886) >= 2 and 5 or nil end, -- T10 2set
    },
}

-- Talents that enable periodic crit damage bonus. Key = tab*100+index, value = bonus per rank.
local critModDamageBonusTalents = {
    WARLOCK = {
        [128] = 2, -- Pandemic
    },
}

-- Buffs that enable periodic crit damage bonus
local critModDamageBonusBuffs = {
    PRIEST = {
        [15473] = 2, -- Shadowform
    },
}

-- Set bonuses that enable periodic crit damage bonus
local critModDamageBonusSetBonuses = {
    HUNTER = {
        function() return GetNumSetItemsEquipped(859) >= 2 and 2 or nil end, -- T9 2set
    },
}

-- Buffs that multiply the crit damage value itself
local critModBuffs = {
    [65134] = 1.35, -- Storm Power (Hodir)
}

-- Meta gems that multiply crit damage
local critModMetaGems = {
    ["32409"] = 0.03,
    ["34220"] = 0.03,
    ["41285"] = 0.03,
    ["41398"] = 0.03,
}

-- Enemy debuffs that increase crit chance against the target
local critChanceEnemyDebuffs = {
    [17800] = 5, -- Shadow Mastery
    [22959] = 5, -- Improved Scorch
    [12579] = 1, -- Winter's Chill
    [21183] = 1, -- Heart of the Crusader (Rank 1)
    [54498] = 2, -- Heart of the Crusader (Rank 2)
    [54499] = 3, -- Heart of the Crusader (Rank 3)
    [30708] = 3, -- Totem of Wrath
}

-- Export section 1 data tables
SnapshotTracker._TARGET_UNIT = TARGET_UNIT
SnapshotTracker._noRecalcOnRefresh = noRecalcOnRefresh
SnapshotTracker._indirectApplicators = indirectApplicators
SnapshotTracker._critSchools = critSchools
SnapshotTracker._critChanceTalents = critChanceTalents
SnapshotTracker._critChanceSetBonuses = critChanceSetBonuses
SnapshotTracker._critModDamageBonusTalents = critModDamageBonusTalents
SnapshotTracker._critModDamageBonusBuffs = critModDamageBonusBuffs
SnapshotTracker._critModDamageBonusSetBonuses = critModDamageBonusSetBonuses
SnapshotTracker._critModBuffs = critModBuffs
SnapshotTracker._critModMetaGems = critModMetaGems
SnapshotTracker._critChanceEnemyDebuffs = critChanceEnemyDebuffs


-- Player buff damage modifiers (class-specific)
local damageModBuffs = {
    PRIEST = {
        [15473] = 0.15, -- Shadowform
        [15258] = 0.02, -- Shadow Weaving
    },
}

-- Player debuff damage modifiers (generic + class-specific)
local damageModDebuffs = {
    [63277] = 1, -- Shadow Crash (General Vezax)
    WARLOCK = {
        [40880] = -0.25, -- Prismatic Aura: Shadow (Mother Shahraz)
        [40897] = 0.25,  -- Prismatic Aura: Holy (Mother Shahraz)
    },
    PRIEST = {
        [40880] = -0.25, -- Prismatic Aura: Shadow
        [40897] = 0.25,  -- Prismatic Aura: Holy
    },
    HUNTER = {
        [40883] = -0.25, -- Prismatic Aura: Nature
        [40891] = 0.25,  -- Prismatic Aura: Arcane
    },
}

-- Talent damage modifiers
local damageModTalents = {
    HUNTER = {
        [208] = 0.1, -- Improved Stings
    },
}

-- Set-bonus damage modifiers
local damageModSetBonuses = {
    WARLOCK = {
        function() return GetNumSetItemsEquipped(529) >= 4 and 0.12 or nil end, -- T3 4set
        function() return GetNumSetItemsEquipped(646) >= 4 and 0.05 or nil end, -- T5 4set
        function() return GetNumSetItemsEquipped(846) >= 4 and 0.1 or nil end,  -- T9 4set
    },
    HUNTER = {
        function() return GetNumSetItemsEquipped(838) >= 2 and 0.1 or nil end, -- T8 2set
    },
}

-- Weapon enchant damage modifiers (class-specific)
local damageModWeaponEnchants = {
    WARLOCK = {
        [3615] = 0.01, -- Spellstone (Rank 1)
        [3616] = 0.01, -- Spellstone (Rank 2)
        [3617] = 0.01, -- Spellstone (Rank 3)
        [3618] = 0.01, -- Spellstone (Rank 4)
        [3619] = 0.01, -- Spellstone (Rank 5)
        [3620] = 0.01, -- Spellstone (Rank 6)
    },
}

-- Execute-range talent damage modifiers
local damageModExecuteTalents = {
    WARLOCK = {
        [123] = 0.04, -- Death's Embrace
    },
}

-- Tracking talent damage modifiers (Hunter)
local damageModTrackingTalents = {
    HUNTER = {
        [314] = 0.01, -- Improved Tracking
    },
}

-- ==========================================================
-- TRACKING LOCALIZATION (for Hunter Improved Tracking)
-- ==========================================================

local GAME_LOCALE = GetLocale()

local localizations = {
    enUS = {
        ["Beast"]     = "Beast",  ["Demon"]       = "Demon",
        ["Dragonkin"] = "Dragonkin", ["Elemental"] = "Elemental",
        ["Giant"]     = "Giant",  ["Humanoid"]    = "Humanoid",
        ["Undead"]    = "Undead",
    },
    deDE = {
        ["Wildtier"]  = "Beast",  ["D\195\164mon"]    = "Demon",
        ["Drachkin"]  = "Dragonkin", ["Elementar"]  = "Elemental",
        ["Riese"]     = "Giant",  ["Humanoid"]    = "Humanoid",
        ["Untoter"]   = "Undead",
    },
    frFR = {
        ["B\195\170te"]       = "Beast",  ["D\195\169mon"]      = "Demon",
        ["Draconien"]  = "Dragonkin", ["El\195\169mentaire"] = "Elemental",
        ["G\195\169ant"]      = "Giant",  ["Humano\195\175de"]  = "Humanoid",
        ["Mort-vivant"]= "Undead",
    },
    koKR = {
        ["\236\149\188\236\136\152"]     = "Beast",
        ["\236\149\133\235\167\136"]     = "Demon",
        ["\236\154\169\236\161\177"]     = "Dragonkin",
        ["\236\160\149\235\160\185"]     = "Elemental",
        ["\234\177\176\236\157\184"]     = "Giant",
        ["\236\157\184\234\176\132\237\152\149"] = "Humanoid",
        ["\236\150\184\235\141\176\235\147\156"] = "Undead",
    },
    esES = {
        ["Bestia"]    = "Beast",  ["Demonio"]     = "Demon",
        ["Drag\195\179n"]     = "Dragonkin", ["Elemental"]  = "Elemental",
        ["Gigante"]   = "Giant",  ["Humanoide"]   = "Humanoid",
        ["No-muerto"] = "Undead",
    },
    esMX = {
        ["Bestia"]    = "Beast",  ["Demonio"]     = "Demon",
        ["Dragon"]    = "Dragonkin", ["Elemental"]  = "Elemental",
        ["Gigante"]   = "Giant",  ["Humanoide"]   = "Humanoid",
        ["No-muerto"] = "Undead",
    },
    ptBR = {
        ["Fera"]          = "Beast",  ["Dem\195\180nio"]    = "Demon",
        ["Drac\195\180nico"]  = "Dragonkin", ["Elemental"]  = "Elemental",
        ["Gigante"]       = "Giant",  ["Humanoide"]   = "Humanoid",
        ["Morto-vivo"]    = "Undead",
    },
    itIT = {
        ["Bestia"]    = "Beast",  ["Demone"]      = "Demon",
        ["Dragoide"]  = "Dragonkin", ["Elementale"] = "Elemental",
        ["Gigante"]   = "Giant",  ["Umanoide"]    = "Humanoid",
        ["Non Morto"] = "Undead",
    },
    ruRU = {
        ["\208\150\208\184\208\178\208\190\209\130\208\189\208\190\208\181"] = "Beast",
        ["\208\148\208\181\208\188\208\190\208\189"]     = "Demon",
        ["\208\148\209\128\208\176\208\186\208\190\208\189"]     = "Dragonkin",
        ["\208\173\208\187\208\181\208\188\208\181\208\189\209\130\208\176\208\187\209\140"] = "Elemental",
        ["\208\146\208\181\208\187\208\184\208\186\208\176\208\189"]   = "Giant",
        ["\208\147\209\131\208\188\208\176\208\189\208\190\208\184\208\180"] = "Humanoid",
        ["\208\157\208\181\208\182\208\184\209\130\209\140"]     = "Undead",
    },
    zhCN = {
        ["\233\135\142\229\133\189"] = "Beast",
        ["\230\129\182\233\173\148"] = "Demon",
        ["\233\190\153\231\177\187"] = "Dragonkin",
        ["\229\133\131\231\180\160\231\148\159\231\137\169"] = "Elemental",
        ["\229\183\168\228\186\186"] = "Giant",
        ["\228\186\186\229\158\139\231\148\159\231\137\169"] = "Humanoid",
        ["\228\186\161\231\129\181"] = "Undead",
    },
    zhTW = {
        ["\233\135\142\231\184\189"] = "Beast",
        ["\230\131\161\233\173\148"] = "Demon",
        ["\233\190\141\233\161\158"] = "Dragonkin",
        ["\229\133\131\231\180\160\231\148\159\231\137\169"] = "Elemental",
        ["\229\183\168\228\186\186"] = "Giant",
        ["\228\186\186\229\158\139\231\148\159\231\137\169"] = "Humanoid",
        ["\228\184\141\230\173\187\230\151\143"] = "Undead",
    },
}

local trackingSpells = {
    [1494]  = "Beast",
    [19878] = "Demon",
    [19879] = "Dragonkin",
    [19880] = "Elemental",
    [19882] = "Giant",
    [19883] = "Humanoid",
    [19884] = "Undead",
}

local function DelocalizeTracking(localized)
    if not localized or not localizations[GAME_LOCALE] then return nil end
    return localizations[GAME_LOCALE][localized]
end

-- Export section 2 data tables
SnapshotTracker._damageModBuffs = damageModBuffs
SnapshotTracker._damageModDebuffs = damageModDebuffs
SnapshotTracker._damageModTalents = damageModTalents
SnapshotTracker._damageModSetBonuses = damageModSetBonuses
SnapshotTracker._damageModWeaponEnchants = damageModWeaponEnchants
SnapshotTracker._damageModExecuteTalents = damageModExecuteTalents
SnapshotTracker._damageModTrackingTalents = damageModTrackingTalents
SnapshotTracker._GAME_LOCALE = GAME_LOCALE
SnapshotTracker._localizations = localizations
SnapshotTracker._trackingSpells = trackingSpells
SnapshotTracker._DelocalizeTracking = DelocalizeTracking
