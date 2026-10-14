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

-- Equipment and enchant procs
C_CooldownViewer.RegisterDefinition({
    key = "enchant.berserking",
    cooldownID = 400001,
    category = CDM_CATEGORY_BUFF_ICON,
    order = 10,

    spellID = 59620,
    auraSpellID = 59620,
    iconSpellID = 59620,

    trackingType = "aura",
    hasAura = true,
    selfAura = true,

    -- Proc auras are not spellbook entries. Keep the shared slot available;
    -- the adapter itself is only shown while aura 59620 is active.
    resolvers = {
        requirements = function()
            return true
        end,
        resolveSpellID = function()
            return 59620
        end,
    },
})

-- Short raid-wide and consumable buffs. On 3.3.5 these are ordinary readable
-- auras on the player, so they need no cast detection: the entry shows while
-- the buff is up. 400002-400099 are reserved for this list (item procs start
-- at 400101). Names also match, in case a core exposes another rank's ID.
local function RegisterSharedBuff(key, cooldownID, order, auraSpellIDs, displayName)
    C_CooldownViewer.RegisterDefinition({
        key = key,
        cooldownID = cooldownID,
        category = CDM_CATEGORY_BUFF_ICON,
        order = order,

        spellID = auraSpellIDs[1],
        auraSpellID = auraSpellIDs[1],
        auraSpellIDs = auraSpellIDs,
        iconSpellID = auraSpellIDs[1],
        displayName = displayName,

        trackingType = "aura",
        hasAura = true,
        selfAura = true,
        matchAuraByName = true,

        resolvers = {
            requirements = function() return true end,
            resolveSpellID = function() return auraSpellIDs[1] end,
        },
    })
end

RegisterSharedBuff("buff.bloodlust",                   400002, 20, { 2825, 32182 }, "Bloodlust / Heroism")
RegisterSharedBuff("consumable.potion_of_speed",       400003, 30, { 53908 })
RegisterSharedBuff("consumable.potion_of_wild_magic",  400004, 31, { 53909 })
RegisterSharedBuff("consumable.indestructible_potion", 400005, 32, { 53762 })
RegisterSharedBuff("consumable.flame_cap",             400006, 33, { 28714 })
RegisterSharedBuff("consumable.oil_of_immolation",     400007, 34, { 11350 })
