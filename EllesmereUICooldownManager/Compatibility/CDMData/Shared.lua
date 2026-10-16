local addonName, ns = ...

if not C_CooldownViewer or not C_CooldownViewer.RegisterDefinition then return end

-- Shared definitions are intentionally class-neutral. Racials, equipped-item
-- effects, enchants, and similar proc auras belong here so every class can use
-- the same stable cooldownID and settings entry.
local CDM_CATEGORY_UTILITY   = 2
local CDM_CATEGORY_BUFF_ICON = 3

-- cooldownID Schema: [CD type 1 digit][Owner ID 2 digits][Unique ID 3 digits]
-- Shared definitions use owner 00:
-- 300XXX = racials
-- 400XXX = items, enchants, trinkets, rings, and their proc auras

-- Racials
C_CooldownViewer.RegisterDefinition({
    key = "racial.blood_fury",
    cooldownID = 300001,
    category = CDM_CATEGORY_UTILITY,
    order = 10,

    spellID = 20572,
    iconSpellID = 20572,
    trackingType = "cooldown",
})

-- Short raid-wide and consumable buffs. On 3.3.5 these are ordinary readable
-- auras on the player, so they need no cast detection: the entry shows while
-- the buff is up. 400001-400099 are reserved for this list (item procs start
-- at 400101). Names also match, in case a core exposes another rank's ID.
-- options: displayName, section (buffCatalogSection), externalBuff,
-- pickerHidden, exactIDs (skip name matching -- group rows whose aura names
-- are generic words such as "Speed" or "Haste").
local function RegisterSharedBuff(key, cooldownID, order, auraSpellIDs, options)
    options = options or {}
    C_CooldownViewer.RegisterDefinition({
        key = key,
        cooldownID = cooldownID,
        category = CDM_CATEGORY_BUFF_ICON,
        order = order,

        spellID = auraSpellIDs[1],
        auraSpellID = auraSpellIDs[1],
        auraSpellIDs = auraSpellIDs,
        iconSpellID = auraSpellIDs[1],
        displayName = options.displayName,
        pickerHidden = options.pickerHidden,
        externalBuff = options.externalBuff,
        buffCatalogSection = options.section or "consumable",

        trackingType = "aura",
        hasAura = true,
        selfAura = true,
        matchAuraByName = not options.exactIDs or nil,

        resolvers = {
            requirements = function() return true end,
            resolveSpellID = function() return auraSpellIDs[1] end,
        },
    })
end

-- Every combat potion buff, as one row: the potions share a cooldown, so only
-- one is ever up and a single slot follows whichever was drunk. Speed stays
-- first so layouts saved with the former Potion of Speed row (same
-- cooldownID and spellID) keep resolving to this row.
local POTIONS = {
    53908, -- Potion of Speed
    53909, -- Potion of Wild Magic
    53762, -- Indestructible Potion
    53910, 53911, 53913, 53914, 53915, -- Mighty Arcane/Fire/Frost/Nature/Shadow Protection
    28507, -- Haste Potion
    28508, -- Destruction Potion
    28506, -- Heroic Potion
    28515, -- Ironshield Potion
    28494, -- Insane Strength Potion
    38929, -- Fel Mana Potion
    28536, 28511, 28512, 28513, 28537, 28538, -- Major Arcane/Fire/Frost/Nature/Shadow/Holy Protection
}

-- Weapon, cloak, glove and rune enchant proc auras, as one row. Berserking
-- stays first: the row reuses the former Berserking row's cooldownID and
-- spellID so saved layouts carry over.
local ENCHANTS = {
    59620, -- Berserking
    28093, -- Mongoose (Lightning Speed)
    42976, -- Executioner
    20007, -- Crusader (Holy Strength)
    59626, -- Black Magic
    64440, -- Blade Warding
    64568, -- Blood Draining (Blood Reserve)
    55637, -- Lightweave Embroidery
    55767, -- Darkglow Embroidery
    55775, -- Swordguard Embroidery
    54758, -- Hyperspeed Accelerators
    54861, -- Nitro Boosts
    53365, -- Rune of the Fallen Crusader (Unholy Strength)
    53386, -- Rune of Cinderglacier
}

RegisterSharedBuff("enchant.procs",   400001, 10, ENCHANTS,
    { displayName = "Enchant Procs", section = "enchant", exactIDs = true })
RegisterSharedBuff("buff.bloodlust",  400002, 20, { 2825, 32182 },
    { displayName = "Bloodlust / Heroism", section = "raid", externalBuff = true })
RegisterSharedBuff("consumable.potions", 400003, 30, POTIONS,
    { displayName = "Potions", exactIDs = true })
-- Absorbed by the Potions row; kept registered so saved layouts still resolve.
RegisterSharedBuff("consumable.potion_of_wild_magic",  400004, 31, { 53909 },
    { pickerHidden = true })
RegisterSharedBuff("consumable.indestructible_potion", 400005, 32, { 53762 },
    { pickerHidden = true })
RegisterSharedBuff("consumable.flame_cap",             400006, 33, { 28714 })
-- Classic consumable whose aura is named "Fire Shield"; hidden from the picker
-- (it read as a class buff), kept registered for saved layouts.
RegisterSharedBuff("consumable.oil_of_immolation",     400007, 34, { 11350 },
    { pickerHidden = true })
