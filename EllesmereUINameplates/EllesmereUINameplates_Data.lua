local addon, ns = ...

local _, PLAYER_CLASS = UnitClass("player")
local ipairs, pairs, type = ipairs, pairs, type

--------------------------------------------------------------------------------
-- Baseline Metrics
--------------------------------------------------------------------------------
ns.BAR_W = 150

--------------------------------------------------------------------------------
-- Target Arrow Styles & Directories
--------------------------------------------------------------------------------
ns.TARGET_ARROW_DIR = "Interface\\AddOns\\EllesmereUINameplates\\Media\\Arrows\\"
ns.TARGET_ARROW_STYLES = {
    simple    = { l = "arrow_left",      r = "arrow_right",      w = 11, label = "Simple Arrows" },
    double    = { l = "arrow_leftx2",    r = "arrow_rightx2",    w = 22, label = "Double Arrows" },
    barbed    = { l = "barbed-left",     r = "barbed-right",     w = 28, label = "Barbed" },
    bracket   = { l = "bracket-left",    r = "bracket-right",    w = 22, label = "Bracket" },
    celestial = { l = "celestial-left",  r = "celestial-right",  w = 28, label = "Celestial" },
    classic   = { l = "classic-left",    r = "classic-right",    w = 22, label = "Classic" },
    crystal   = { l = "crystal-left",    r = "crystal-right",    w = 22, label = "Crystal" },
    curved    = { l = "curved-left",     r = "curved-right",     w = 22, label = "Curved" },
    demon     = { l = "demon-left",      r = "demon-right",      w = 28, label = "Demon" },
    diamond   = { l = "diamond-left",    r = "diamond-right",    w = 28, label = "Diamond" },
    feathered = { l = "feathered-left",  r = "feathered-right",  w = 22, label = "Feathered" },
    halo      = { l = "halo-left",       r = "halo-right",       w = 22, label = "Halo" },
    holyspear = { l = "holy-spear-left", r = "holy-spear-right", w = 28, label = "Holy Spear" },
    rune      = { l = "rune-left",       r = "rune-right",       w = 22, label = "Rune" },
    split     = { l = "split-left",      r = "split-right",      w = 22, label = "Split" },
    winged    = { l = "winged-left",     r = "winged-right",     w = 28, label = "Winged" },
}
ns.TARGET_ARROW_ORDER = {
    "simple", "double", "winged", "feathered", "split", "celestial", "rune", "demon",
    "halo", "curved", "barbed", "holyspear", "bracket", "diamond", "crystal", "classic",
}

function ns.ResolveTargetArrowStyle(prof)
    local key = prof and (prof.targetArrowStyle or (prof.targetArrowDouble and "double")) or nil
    return ns.TARGET_ARROW_STYLES[key] or ns.TARGET_ARROW_STYLES.simple
end

function ns.GetTargetArrowColor(prof)
    if prof and prof.targetArrowClassColor then
        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[PLAYER_CLASS]
        if cc then return cc.r, cc.g, cc.b end
        return 1, 1, 1
    end
    local c = prof and prof.targetArrowColor
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

--------------------------------------------------------------------------------
-- Health Bar Textures
--------------------------------------------------------------------------------
do
    local TB = "Interface\\AddOns\\EllesmereUI\\media\\textures\\"
    ns.healthBarTextures = {
        ["none"]             = nil,
        ["melli"]            = TB .. "melli.tga",
        ["beautiful"]        = TB .. "beautiful.tga",
        ["plating"]          = TB .. "plating.tga",
        ["atrocity"]         = TB .. "atrocity.tga",
        ["divide"]           = TB .. "divide.tga",
        ["glass"]            = TB .. "glass.tga",
        ["fade-right"]       = TB .. "fade-right.tga",
        ["thin-line-top"]    = TB .. "thin-line-top.tga",
        ["thin-line-bottom"] = TB .. "thin-line-bottom.tga",
        ["fade"]             = TB .. "fade.tga",
        ["gradient-lr"]      = TB .. "gradient-lr.tga",
        ["gradient-rl"]      = TB .. "gradient-rl.tga",
        ["gradient-bt"]      = TB .. "gradient-bt.tga",
        ["gradient-tb"]      = TB .. "gradient-tb.tga",
        ["matte"]            = TB .. "matte.tga",
        ["sheer"]            = TB .. "sheer.tga",
        ["blinkii-diamonds"] = TB .. "blinkii-diamonds.tga",
        ["kringel-window"]   = TB .. "kringel-window.tga",
    }
    ns.healthBarTextureOrder = {
        "none", "melli", "atrocity",
        "fade", "fade-right",
        "thin-line-top", "thin-line-bottom",
        "beautiful", "plating",
        "divide", "glass",
        "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
        "matte", "sheer",
        "blinkii-diamonds", "kringel-window",
    }
    ns.healthBarTextureNames = {
        ["none"]             = "None",
        ["melli"]            = "Melli (ElvUI)",
        ["beautiful"]        = "Beautiful",
        ["plating"]          = "Plating",
        ["atrocity"]         = "Atrocity",
        ["divide"]           = "Divide",
        ["glass"]            = "Glass",
        ["fade-right"]       = "Fade Right",
        ["thin-line-top"]    = "Thin Line Top",
        ["thin-line-bottom"] = "Thin Line Bottom",
        ["fade"]             = "Fade",
        ["gradient-lr"]      = "Gradient Right",
        ["gradient-rl"]      = "Gradient Left",
        ["gradient-bt"]      = "Gradient Up",
        ["gradient-tb"]      = "Gradient Down",
        ["matte"]            = "Matte",
        ["sheer"]            = "Sheer",
        ["blinkii-diamonds"] = "Blinkii Diamonds",
        ["kringel-window"]   = "Kringel Window",
    }
end

ns.NP_ABSORB_STYLE_TEX = {
    blizzard = "Interface\\AddOns\\EllesmereUI\\media\\textures\\shields\\blizzard-nameplates.tga",
    striped  = "Interface\\AddOns\\EllesmereUI\\media\\textures\\shields\\striped3.tga",
    clean    = "Interface\\Buttons\\WHITE8X8",
}
ns.NP_ABSORB_STYLE_ALPHA = {
    blizzard = 0.8,
    striped  = 0.8,
    clean    = 0.3,
}

--------------------------------------------------------------------------------
-- 3.3.5 Diminishing Returns Spell Database (from NotPlater)
--------------------------------------------------------------------------------
ns.DiminishingReturnsSpells = {
    --[[ TAUNT ]]--
    [355]   = "taunt",      -- Taunt (Warrior)
    [53477] = "taunt",      -- Taunt (Pet)
    [694]   = "taunt",      -- Mocking Blow
    [6795]  = "taunt",      -- Growl (Druid)
    [56222] = "taunt",      -- Dark Command
    [62124] = "taunt",      -- Hand of Reckoning
    [31790] = "taunt",      -- Righteous Defense
    [20736] = "taunt",      -- Distracting Shot
    [1161]  = "taunt",      -- Challenging Shout
    [5209]  = "taunt",      -- Challenging Roar
    [49560] = "taunt",      -- Death Grip
    [59671] = "taunt",      -- Challenging Howl
    [36213] = "taunt",      -- Angered Earth

    --[[ DISORIENTS ]]--
    [31661] = "disorient",  -- Dragon's Breath
    [33041] = "disorient",
    [33042] = "disorient",
    [33043] = "disorient",
    [42949] = "disorient",
    [42950] = "disorient",
    [49203] = "disorient",  -- Hungering Cold
    [6770]  = "disorient",  -- Sap
    [2070]  = "disorient",
    [11297] = "disorient",
    [51724] = "disorient",
    [1776]  = "disorient",  -- Gouge
    [51514] = "disorient",  -- Hex
    [9484]  = "disorient",  -- Shackle
    [9485]  = "disorient",
    [10955] = "disorient",
    [118]   = "disorient",  -- Polymorph
    [12824] = "disorient",
    [12825] = "disorient",
    [28272] = "disorient",
    [28271] = "disorient",
    [12826] = "disorient",
    [61305] = "disorient",
    [61025] = "disorient",
    [61721] = "disorient",
    [61780] = "disorient",
    [3355]  = "disorient",  -- Freezing Trap
    [14308] = "disorient",
    [14309] = "disorient",
    [60210] = "disorient",  -- Freezing Arrow
    [19386] = "disorient",  -- Wyvern Sting
    [24132] = "disorient",
    [24133] = "disorient",
    [27068] = "disorient",
    [49011] = "disorient",
    [49012] = "disorient",
    [20066] = "disorient",  -- Repentance

    --[[ SILENCES ]]--
    [53588] = "silence",    -- Nether Shock
    [53589] = "silence",
    [1330]  = "silence",    -- Garrote
    [25046] = "silence",    -- Arcane Torrent
    [28730] = "silence",
    [50613] = "silence",
    [69179] = "silence",
    [80483] = "silence",
    [15487] = "silence",    -- Silence (Priest)
    [34490] = "silence",    -- Silencing Shot
    [18469] = "silence",    -- Improved Counterspell
    [55021] = "silence",
    [18498] = "silence",    -- Silenced - Gag Order
    [47476] = "silence",    -- Strangulate
    [49206] = "silence",    -- Summon Gargoyle silence

    --[[ FEARS ]]--
    [5782]  = "fear",       -- Fear (Warlock)
    [6213]  = "fear",
    [6215]  = "fear",
    [5484]  = "fear",       -- Howl of Terror
    [17928] = "fear",
    [5246]  = "fear",       -- Intimidating Shout
    [8122]  = "fear",       -- Psychic Scream
    [8124]  = "fear",
    [10888] = "fear",
    [10890] = "fear",
    [10326] = "fear",       -- Turn Evil
    [1513]  = "fear",       -- Scare Beast

    --[[ STUNS ]]--
    [853]   = "stun",       -- Hammer of Justice
    [5588]  = "stun",
    [5589]  = "stun",
    [10308] = "stun",
    [408]   = "stun",       -- Kidney Shot
    [8643]  = "stun",
    [5211]  = "stun",       -- Mighty Bash / Bash
    [6798]  = "stun",
    [8983]  = "stun",
    [22570] = "stun",       -- Maim
    [49802] = "stun",
    [19577] = "stun",       -- Intimidation
    [24394] = "stun",
    [12809] = "stun",       -- Concussion Blow
    [20252] = "stun",       -- Intercept
    [25272] = "stun",
    [25275] = "stun",
    [46968] = "stun",       -- Shockwave
    [44572] = "stun",       -- Deep Freeze
    [30283] = "stun",       -- Shadowfury
    [30413] = "stun",
    [30414] = "stun",
    [47846] = "stun",
    [47847] = "stun",

    --[[ CONTROL ROOTS ]]--
    [122]   = "ctrlroot",   -- Frost Nova
    [865]   = "ctrlroot",
    [6131]  = "ctrlroot",
    [10230] = "ctrlroot",
    [27088] = "ctrlroot",
    [42917] = "ctrlroot",
    [339]   = "ctrlroot",   -- Entangling Roots
    [1062]  = "ctrlroot",
    [5195]  = "ctrlroot",
    [5196]  = "ctrlroot",
    [9852]  = "ctrlroot",
    [9853]  = "ctrlroot",
    [26989] = "ctrlroot",
    [53308] = "ctrlroot",
    [19970] = "ctrlroot",   -- Nature's Grasp
    [19971] = "ctrlroot",
    [19972] = "ctrlroot",
    [19973] = "ctrlroot",
    [19974] = "ctrlroot",
    [19975] = "ctrlroot",
    [27010] = "ctrlroot",
    [53313] = "ctrlroot",
    [8377]  = "ctrlroot",   -- Earthgrab
    [31983] = "ctrlroot",
    [4167]  = "ctrlroot",   -- Web (Spider)
    [54706] = "ctrlroot",   -- Venom Web Spray
    [55505] = "ctrlroot",
    [55506] = "ctrlroot",
    [55507] = "ctrlroot",
    [55508] = "ctrlroot",
    [55509] = "ctrlroot",

    --[[ RANDOM ROOTS ]]--
    [23694] = "rndroot",    -- Improved Hamstring
    [12494] = "rndroot",    -- Frostbite
    [55080] = "rndroot",    -- Shattered Barrier

    --[[ SLEEPS ]]--
    [2637]  = "sleep",      -- Hibernate
    [18657] = "sleep",
    [18658] = "sleep",

    --[[ HORROR ]]--
    [6789]  = "horror",     -- Death Coil
    [17925] = "horror",
    [17926] = "horror",
    [27223] = "horror",
    [47859] = "horror",
    [47860] = "horror",
    [64044] = "horror",     -- Psychic Horror

    --[[ MISC ]]--
    [19503] = "scatters",   -- Scatter Shot
    [1833]  = "cheapshot",  -- Cheap Shot
    [9005]  = "cheapshot",  -- Pounce
    [9823]  = "cheapshot",
    [9827]  = "cheapshot",
    [27006] = "cheapshot",
    [49803] = "cheapshot",
    [7922]  = "charge",     -- Charge
    [605]   = "mc",         -- Mind Control
    [710]   = "banish",     -- Banish
    [18647] = "banish",
    [64804] = "entrapment", -- Entrapment
    [19185] = "entrapment",
}

--------------------------------------------------------------------------------
-- Clean Defaults (WotLK 3.3.5a - Retail Keys Purged)
--------------------------------------------------------------------------------
function ns._appendDisplayPresetKeys(t)
    for _, k in ipairs({
        "topSlotSize", "topSlotXOffset", "topSlotYOffset", "topSlotRaiseStrata",
        "rightSlotSize", "rightSlotXOffset", "rightSlotYOffset", "rightSlotRaiseStrata",
        "leftSlotSize", "leftSlotXOffset", "leftSlotYOffset", "leftSlotRaiseStrata",
        "toprightSlotSize", "toprightSlotXOffset", "toprightSlotYOffset", "toprightSlotGrowth", "toprightSlotRaiseStrata",
        "topleftSlotSize", "topleftSlotXOffset", "topleftSlotYOffset", "topleftSlotGrowth", "topleftSlotRaiseStrata",
        "textSlotTopSize", "textSlotTopXOffset", "textSlotTopYOffset",
        "textSlotRightSize", "textSlotRightXOffset", "textSlotRightYOffset",
        "textSlotLeftSize", "textSlotLeftXOffset", "textSlotLeftYOffset",
        "textSlotCenterSize", "textSlotCenterXOffset", "textSlotCenterYOffset",
        "textSlotTopColor", "textSlotRightColor", "textSlotLeftColor", "textSlotCenterColor",
        "tankHasAggroEnabled", "tankHasAggro", "classicTankAggro", "tankHasAggroOverrideMobType",
        "tankHasAggroOverrideBoss",
        "dpsHasAggro", "dpsNearAggro", "offTankAggroEnabled", "offTankAggro",
        "dpsNoAggroEnabled", "dpsNoAggro", "dpsNoAggroOverrideMiniBoss", "dpsNoAggroOverrideCaster",
        "targetArrowDouble", "targetArrowStyle", "targetArrowColor", "targetArrowClassColor",
        "auraStackTextSize", "auraStackTextColor",
        "auraStackTextPosition", "auraStackTextX", "auraStackTextY",
        "auraDurationTextX", "auraDurationTextY",
        "debuffDurationTextSize", "debuffDurationTextX", "debuffDurationTextY", "debuffDurationTextColor",
        "buffDurationTextSize", "buffDurationTextX", "buffDurationTextY", "buffDurationTextColor",
        "ccDurationTextSize", "ccDurationTextX", "ccDurationTextY", "ccDurationTextColor",
        "buffTextSize", "buffTextColor", "ccTextSize", "ccTextColor",
        "raidMarkerPos", "classificationSlot", "classificationShowInInstances",
        "showLevelText", "showClassificationIndicator",
        "castNameSize", "castNameColor", "castCombineNameTarget",
        "castTargetSize", "castTargetClassColor", "castTargetColor",
        "showCastTimer", "castTimerSize", "castTimerColor", "targetScale",
        "castNameSide", "castTargetSide", "castTimerSide",
        "castNameWidthPct", "castNameWrap", "castTargetWidthPct", "castTargetWrap",
        "enemyNameWidthPct", "enemyNameWrap", "wrapBorderCastbar",
        "debuffSlot", "buffSlot", "ccSlot",
        "debuffYOffset", "sideAuraXOffset", "auraSpacing",
        "debuffSpacing", "buffSpacing", "ccSpacing",
        "debuffTimerPosition", "buffTimerPosition", "ccTimerPosition",
        "auraDurationTextSize", "auraDurationTextColor",
        "debuffCropIcons", "buffCropIcons", "ccCropIcons",
        "castIconOffsetX", "castIconOffsetY",
        "targetGlowEllesmereUI", "targetGlowBorderColor", "targetGlowHighlight", "targetBorderColor",
        "targetGlowBorderSize", "targetBorderSizeValue",
    }) do t[#t + 1] = k end
end

ns.defaults = {
    absorbStyle = "blizzard",
    absorbCleanAlpha = 30,
    absorbColor = { r = 1, g = 1, b = 1 },
    hostile = { r = 0.39, g = 0.11, b = 0.09 },
    neutral = { r = 0.81, g = 0.72, b = 0.19 },
    tapped  = { r = 0.50, g = 0.50, b = 0.50 },
    focus = { r = 0.051, g = 0.820, b = 0.620 },
    focusColorEnabled = true,
    focusOverlayTexture = "striped-v2",
    focusOverlayAlpha = 1.0,
    focusOverlayColor = { r = 1.0, g = 1.0, b = 1.0 },
    focusOverlayFullBgAlpha = false,
    focusOverlayNoTint = false,
    focusLetterEnabled = false,
    focusLetterAnchor = "CENTER",
    focusLetterX = 0,
    focusLetterY = 0,
    focusLetterSize = 18,
    target = { r = 0.459, g = 0.890, b = 0.580 },
    targetColorEnabled = false,
    targetOverlayTexture = "none",
    targetOverlayAlpha = 1.0,
    targetOverlayColor = { r = 1.0, g = 1.0, b = 1.0 },
    targetOverlayFullBgAlpha = false,
    targetOverlayNoTint = false,
    hoverOverlayTexture = "none",
    caster  = { r = 0.231, g = 0.510, b = 0.965 },
    miniboss = { r = 0.518, g = 0.243, b = 0.984 },
    boss = { r = 0.518, g = 0.243, b = 0.984 },
    enemyInCombat = { r = 0.800, g = 0.137, b = 0.137 },
    darkenEnemiesOOC = true,
    tankHasAggro = { r = 0.05, g = 0.82, b = 0.62 },
    tankHasAggroEnabled = false,
    tankHasAggroOverrideMobType = false,
    tankHasAggroOverrideBoss = true,
    classicTankAggro = false,
    tankLosingAggro = { r = 0.81, g = 0.72, b = 0.19 },
    tankNoAggro = { r = 1.00, g = 0.22, b = 0.17 },
    dpsNearAggro = { r = 0.81, g = 0.72, b = 0.19 },
    dpsHasAggro = { r = 1.00, g = 0.50, b = 0.00 },
    offTankAggro = { r = 0.188, g = 0.761, b = 0.812 },
    offTankAggroEnabled = true,
    dpsNoAggro = { r = 0.35, g = 0.75, b = 0.35 },
    dpsNoAggroEnabled = false,
    dpsNoAggroOverrideMiniBoss = false,
    dpsNoAggroOverrideCaster = false,
    interruptReady = { r = 0.92, g = 0.35, b = 0.20 },
    castBar = { r = 0.70, g = 0.40, b = 0.90 },
    interruptMidCastEnabled = false,
    interruptMidCastColor = { r = 0.318, g = 0.820, b = 0.357 },
    castBarUninterruptible = { r = 0.45, g = 0.45, b = 0.45 },
    castBarImportant = { r = 1, g = 0.2, b = 0.2 },
    importantCastColorEnabled = false,
    castBarShieldEnabled = true,
    interruptedFlashEnabled = true,
    interruptedFlashColor = { r = 0.8, g = 0.0, b = 0.0 },
    healthBarHeight = 17,
    friendlyNameOnly = true,
    friendlyNameOnlyYOffset = -20,
    friendlyNameSize = 15,
    friendlyPlateYOffset = 0,
    friendlyHealthBarHeight = 17,
    friendlyHealthBarWidth = 150,
    showFriendlyNPCs = false,
    showNPCTitles = true,
    showFriendlyPlayers = true,
    friendlyShowDefaultNames = false,
    classColorFriendly = true,
    friendlyBarColor = { r = 0.314, g = 0.800, b = 0.408 },
    friendlyNPCColor = { r = 0, g = 1, b = 0 },
    friendlyNPCNameSize = 13,
    friendlyNameTextSize = 12,
    showEnemyPets = false,
    font = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
    textSlotTop = "enemyName",
    textSlotRight = "healthPercent",
    textSlotLeft = "none",
    textSlotCenter = "none",
    showTargetArrows = false,
    targetArrowDouble = false,
    targetArrowScale = 1.0,
    targetArrowColor = { r = 1, g = 1, b = 1 },
    targetArrowClassColor = false,
    healthBarWidth = 6,
    stackSpacingScale = 100,
    stackingEnabled = true,
    stackingFriendly = false,
    hitboxScaleX = 100,
    hitboxScaleY = 100,
    nameplateYOffset = 0,
    enemyNameTextSize = 11,
    debuffTimerColor = { r = 1, g = 1, b = 1 },
    auraTextPosition = "topleft",
    debuffTimerPosition = "topleft",
    buffTimerPosition = "topleft",
    ccTimerPosition = "topleft",
    auraDurationTextSize = 11,
    auraDurationTextX = 0,
    auraDurationTextY = 0,
    auraDurationTextColor = { r = 1, g = 1, b = 1 },
    auraStackTextSize = 11,
    auraStackTextColor = { r = 1, g = 1, b = 1 },
    auraStackTextPosition = "bottomright",
    auraStackTextX = 0,
    auraStackTextY = 0,
    debuffSlot = "top",
    buffSlot = "left",
    ccSlot = "right",
    debuffYOffset = 2,
    sideAuraXOffset = 2,
    nameYOffset = 0,
    auraSpacing = 2,
    debuffSpacing = 2,
    buffSpacing = 2,
    ccSpacing = 2,
    debuffCropIcons = false,
    buffCropIcons = false,
    ccCropIcons = false,
    debuffIconSize = 26,
    buffIconSize = 24,
    buffTextSize = 12,
    buffTextColor = { r = 1, g = 1, b = 1 },
    ccIconSize = 24,
    ccTextSize = 12,
    ccTextColor = { r = 1, g = 1, b = 1 },
    targetGlowStyle = "ellesmereui",
    targetBorderColor = { r = 1, g = 1, b = 1 },
    targetGlowColor = { r = 0.4117, g = 0.6667, b = 1.0 },
    targetGlowAlpha = 1.0,
    targetHighlightColor = { r = 1, g = 1, b = 1 },
    targetHighlightAlpha = 0.20,
    nameRaidMarkerEnabled = false,
    nameRaidMarkerSize = 14,
    raidMarkerPos = "topright",
    raidMarkerSize = 24,
    classificationSlot = "topleft",
    classificationShowInInstances = false,
    showLevelText = false,
    showClassificationIndicator = false,
    rareEliteIconSize = 20,
    castBarHeight = 17,
    castBarOffsetY = 0,
    castBarSparkEnabled = true,
    castOverlayEnabled = false,
    hideEnemyNameWhileCasting = false,
    castNameSize = 10,
    castNameColor = { r = 1, g = 1, b = 1 },
    castNameOffsetX = 0,
    castNameOffsetY = 0,
    castNameSide = "left",
    castNameWidthPct = 42,
    castNameWrap = false,
    castCombineNameTarget = false,
    castTargetSize = 10,
    castTargetClassColor = true,
    castTargetColor = { r = 1, g = 1, b = 1 },
    castTargetOffsetX = 0,
    castTargetOffsetY = 0,
    castTargetSide = "right",
    castTargetWidthPct = 42,
    castTargetWrap = false,
    showCastTimer = true,
    castTimerSide = "right",
    castTimerSize = 10,
    castTimerColor = { r = 1, g = 1, b = 1 },
    castTimerOffsetX = 0,
    castTimerOffsetY = 0,
    enemyNameWidthPct = 100,
    enemyNameWrap = false,
    targetScale = 100,
    nonTargetKeepFocus = true,
    showAllDebuffs = false,
    rangeTextEnabled = false,
    rangeTextSize = 11,
    rangeTextOffsetX = 0,
    rangeTextOffsetY = 0,
    rangeTextColor = { r = 0.816, g = 0.357, b = 0.220 },
    maxDebuffs = 5,
    showBorder = true,
    borderSize = 1,
    borderColor = { r = 0.067, g = 0.067, b = 0.067 },
    wrapBorderCastbar = false,
    customBorderEnabled = false,
    customBorderTexture = "solid",
    customBorderSize = 1,
    customBorderColor = { r = 0.067, g = 0.067, b = 0.067 },
    customBorderAlpha = 1,
    customBorderBehind = false,
    lowHpGlow = false,
    dispelGlow = false,
    dispelGlowStyle = 2,
    dispelGlowColor = { r = 1.0, g = 1.0, b = 1.0 },
    dispelGlowUseTypeColor = false,
    castScale = 100,
    focusCastHeight = 100,
    showCastIcon = true,
    castIconScale = 1,
    castIconOffsetX = 0,
    castIconOffsetY = 0,
    castbarIconInWidth = false,
    castIconOnRight = false,
    castIconFullSize = false,
    castIconTargetBorder = false,
    bgAlpha = 1.0,
    bgColor = { r = 0.12, g = 0.12, b = 0.12 },
    hoverColor = { r = 1, g = 1, b = 1 },
    hoverAlpha = 0.3,
    hoverOverlayFullBgAlpha = false,
    castBgAlpha = 0.9,
    castBgColor = { r = 0.1, g = 0.1, b = 0.1 },
    castBorderSize = 0,
    castBorderColor = { r = 0, g = 0, b = 0 },
    hashLineEnabled = false,
    hashLinePercent = 30,
    hashLineColor = { r = 1, g = 1, b = 1 },
    kickTickEnabled = true,
    kickTickColor = { r = 1, g = 1, b = 1 },
    importantCastGlow = true,
    importantCastGlowStyle = 1,
    importantCastGlowColor = { r = 1, g = 0.2, b = 0.2 },
    importantCastGlowLines = 8,
    importantCastGlowThickness = 2,
    importantCastGlowSpeed = 4,
    importantCastGlowBackground = false,
    importantCastGlowBackgroundColor = { r = 0, g = 0, b = 0 },
    topSlotSize = 26,        topSlotXOffset = 0,      topSlotYOffset = 0,      topSlotRaiseStrata = false,
    rightSlotSize = 24,      rightSlotXOffset = 0,    rightSlotYOffset = 0,    rightSlotRaiseStrata = false,
    leftSlotSize = 24,       leftSlotXOffset = 0,     leftSlotYOffset = 0,     leftSlotRaiseStrata = false,
    toprightSlotSize = 24,   toprightSlotXOffset = 0, toprightSlotYOffset = 0, toprightSlotGrowth = "right", toprightSlotRaiseStrata = false,
    topleftSlotSize = 24,    topleftSlotXOffset = 0,  topleftSlotYOffset = 0,  topleftSlotGrowth = "left",   topleftSlotRaiseStrata = false,
    bottomSlotSize = 26,     bottomSlotXOffset = 0,   bottomSlotYOffset = 0,   bottomSlotRaiseStrata = false,
    textSlotTopSize = 10,    textSlotTopXOffset = 0,  textSlotTopYOffset = 0,
    textSlotRightSize = 10,  textSlotRightXOffset = 0, textSlotRightYOffset = 0,
    textSlotLeftSize = 10,   textSlotLeftXOffset = 0,  textSlotLeftYOffset = 0,
    textSlotCenterSize = 10, textSlotCenterXOffset = 0, textSlotCenterYOffset = 0,
    textSlotTopColor = { r = 1, g = 1, b = 1 },
    textSlotRightColor = { r = 1, g = 1, b = 1 },
    textSlotLeftColor = { r = 1, g = 1, b = 1 },
    textSlotCenterColor = { r = 1, g = 1, b = 1 },
    healthBarTexture = "none",
    castBarTexture = "none",
}
