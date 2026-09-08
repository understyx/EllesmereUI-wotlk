-------------------------------------------------------------------------------
-- EllesmereUIRaidCooldowns_Data.lua
-- Shared WotLK raid-cooldown catalog. Raid Cooldowns owns remote cooldown
-- timing; CDM enriches matching entries with its canonical rank/alias data.
-------------------------------------------------------------------------------

local EUI = EllesmereUI
if not EUI then return end

local Catalog = EUI.RaidCooldownCatalog or {}
EUI.RaidCooldownCatalog = Catalog

Catalog.classOrder = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "ITEMS",
}

Catalog.classNames = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
    ROGUE = "Rogue", PRIEST = "Priest", DEATHKNIGHT = "Death Knight",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock",
    DRUID = "Druid", ITEMS = "Items",
}

Catalog.byClass = Catalog.byClass or {}
Catalog.bySpellID = Catalog.bySpellID or {}
Catalog.aliases = Catalog.aliases or {}
Catalog.itemBySpellID = Catalog.itemBySpellID or {}

local function Register(class, spellID, duration, order, opts)
    opts = opts or {}
    local def = {
        class = class,
        spellID = spellID,
        duration = duration,
        order = order,
        talent = opts.talent,
        reductions = opts.reductions,
        castableOnOthers = opts.castableOnOthers == true,
        startOnAuraRemoved = opts.startOnAuraRemoved == true,
        trigger = opts.trigger or "SPELL_CAST_SUCCESS",
        resets = opts.resets,
        tags = opts.tags or {},
        itemIDs = opts.itemIDs,
    }
    Catalog.byClass[class] = Catalog.byClass[class] or {}
    Catalog.byClass[class][spellID] = def
    Catalog.bySpellID[spellID] = def
    Catalog.aliases[spellID] = spellID
    for _, alias in ipairs(opts.aliases or {}) do Catalog.aliases[alias] = spellID end
    if opts.itemIDs then
        Catalog.itemBySpellID[spellID] = opts.itemIDs
    end
    return def
end

-- Death Knight
Register("DEATHKNIGHT", 48707, 45, 1, { tags = { defensive = true } })
Register("DEATHKNIGHT", 51052, 120, 2, { talent = { 3, 22 }, castableOnOthers = true, tags = { raid = true, defensive = true, external = true } })
Register("DEATHKNIGHT", 49016, 180, 3, { talent = { 1, 19 }, castableOnOthers = true, tags = { external = true } })
Register("DEATHKNIGHT", 48792, 120, 4, { tags = { defensive = true } })
Register("DEATHKNIGHT", 49005, 180, 5, { talent = { 1, 15 } })
Register("DEATHKNIGHT", 48982, 60, 6, { talent = { 1, 7 }, reductions = { { 1, 10, 10 } }, tags = { defensive = true } })
Register("DEATHKNIGHT", 55233, 60, 7, { talent = { 1, 23 }, tags = { defensive = true } })
Register("DEATHKNIGHT", 42650, 600, 8, { reductions = { { 3, 13, 120 } }, tags = { raid = true } })
Register("DEATHKNIGHT", 45529, 60, 9)

-- Druid
Register("DRUID", 29166, 180, 1, { castableOnOthers = true, tags = { external = true } })
Register("DRUID", 48477, 600, 2, { castableOnOthers = true, trigger = "UNIT_SPELLCAST_SUCCEEDED", tags = { raid = true, battleRes = true } })
Register("DRUID", 48447, 480, 3, { castableOnOthers = true, tags = { raid = true, healing = true } })
Register("DRUID", 22812, 60, 4, { tags = { defensive = true } })
Register("DRUID", 61336, 180, 5, { talent = { 2, 7 }, tags = { defensive = true } })
Register("DRUID", 22842, 180, 6, { tags = { defensive = true } })

-- Hunter
Register("HUNTER", 19263, 60, 1, { tags = { defensive = true } })
Register("HUNTER", 34477, 30, 2, { castableOnOthers = true, startOnAuraRemoved = true, tags = { external = true } })
Register("HUNTER", 53271, 60, 3, { castableOnOthers = true, tags = { external = true } })
Register("HUNTER", 23989, 180, 4, { resets = { 34477 } })

-- Mage
Register("MAGE", 45438, 300, 1, { tags = { defensive = true } })
Register("MAGE", 66, 180, 2, { tags = { defensive = true } })

-- Paladin
Register("PALADIN", 31821, 120, 1, { talent = { 1, 6 }, castableOnOthers = true, tags = { raid = true, defensive = true } })
Register("PALADIN", 498, 180, 2, { reductions = { { 2, 14, 30 } }, tags = { defensive = true } })
Register("PALADIN", 64205, 120, 3, { talent = { 2, 6 }, castableOnOthers = true, tags = { raid = true, defensive = true } })
Register("PALADIN", 642, 300, 4, { reductions = { { 2, 14, 30 } }, tags = { defensive = true } })
Register("PALADIN", 48788, 900, 5, { reductions = { { 1, 8, 120 } }, castableOnOthers = true, tags = { external = true, healing = true } })
Register("PALADIN", 1044, 25, 6, { castableOnOthers = true, tags = { external = true } })
Register("PALADIN", 10278, 300, 7, { reductions = { { 2, 4, 60 } }, castableOnOthers = true, tags = { external = true, defensive = true } })
Register("PALADIN", 6940, 120, 8, { castableOnOthers = true, tags = { external = true, defensive = true } })
Register("PALADIN", 1038, 120, 9, { castableOnOthers = true, tags = { external = true } })
Register("PALADIN", 10308, 60, 10, { reductions = { { 2, 10, 10 }, { 2, 25, 5 } } })
Register("PALADIN", 48817, 30, 11)
Register("PALADIN", 54428, 60, 12)
Register("PALADIN", 66233, 120, 13, { talent = { 2, 18 }, trigger = "SPELL_AURA_APPLIED", tags = { defensive = true } })

-- Priest
Register("PRIEST", 64843, 480, 1, { castableOnOthers = true, tags = { raid = true, healing = true } })
Register("PRIEST", 6346, 180, 2, { castableOnOthers = true, tags = { external = true } })
Register("PRIEST", 47788, 180, 3, { talent = { 2, 27 }, castableOnOthers = true, tags = { external = true, defensive = true } })
Register("PRIEST", 64901, 360, 4, { castableOnOthers = true, tags = { raid = true } })
Register("PRIEST", 33206, 180, 5, { talent = { 1, 25 }, reductions = { { 1, 23, 18 } }, castableOnOthers = true, tags = { external = true, defensive = true } })
Register("PRIEST", 10060, 120, 6, { talent = { 1, 19 }, reductions = { { 1, 23, 12 } }, castableOnOthers = true, tags = { external = true } })

-- Rogue
Register("ROGUE", 31224, 90, 1, { reductions = { { 3, 7, 15 } }, tags = { defensive = true } })
Register("ROGUE", 26669, 180, 2, { reductions = { { 2, 7, 30 } }, tags = { defensive = true } })
Register("ROGUE", 57934, 30, 3, { reductions = { { 3, 26, 5 } }, castableOnOthers = true, startOnAuraRemoved = true, tags = { external = true } })
Register("ROGUE", 26889, 180, 4, { reductions = { { 3, 7, 30 } }, tags = { defensive = true } })

-- Shaman
Register("SHAMAN", 2825, 300, 1, { castableOnOthers = true, tags = { raid = true } })
Register("SHAMAN", 32182, 300, 2, { castableOnOthers = true, tags = { raid = true } })
Register("SHAMAN", 16190, 300, 3, { talent = { 3, 17 }, castableOnOthers = true, tags = { raid = true } })
Register("SHAMAN", 21169, 1800, 4, { reductions = { { 3, 3, 420 } }, trigger = "SPELL_RESURRECT", tags = { battleRes = true } })
Register("SHAMAN", 30823, 60, 5, { talent = { 2, 26 }, tags = { defensive = true } })

-- Warlock
Register("WARLOCK", 47883, 900, 1, { castableOnOthers = true, trigger = "SPELL_AURA_APPLIED", tags = { battleRes = true, external = true } })
Register("WARLOCK", 29858, 180, 2, { tags = { defensive = true } })

-- Warrior
Register("WARRIOR", 55694, 180, 1, { tags = { defensive = true } })
Register("WARRIOR", 12975, 180, 2, { talent = { 3, 6 }, tags = { defensive = true } })
Register("WARRIOR", 2565, 60, 3, { reductions = { { 3, 8, 10 } }, tags = { defensive = true } })
Register("WARRIOR", 871, 300, 4, { reductions = { { 3, 8, 13 } }, tags = { defensive = true } })

-- Tracked raid-use items. Aliases are effect spell IDs used by heroic items.
Register("ITEMS", 75490, 120, 1, { aliases = { 75495 }, itemIDs = { 54573, 54589 }, tags = { item = true, raid = true } })
Register("ITEMS", 71635, 60, 2, { aliases = { 71638 }, itemIDs = { 50361, 50364 }, tags = { item = true, defensive = true } })

function Catalog:ResolveSpellID(spellID)
    spellID = tonumber(spellID)
    return spellID and self.aliases[spellID] or nil
end

function Catalog:Get(spellID)
    local canonical = self:ResolveSpellID(spellID)
    return canonical and self.bySpellID[canonical] or nil
end

function Catalog:MergeCDMDefinition(cdmDef)
    if type(cdmDef) ~= "table" then return end
    local match = self:Get(cdmDef.spellID) or self:Get(cdmDef.iconSpellID)
    if not match then
        for _, spellID in ipairs(cdmDef.spellIDs or {}) do
            match = self:Get(spellID)
            if match then break end
        end
    end
    if not match then return end

    cdmDef.raidCooldown = match
    match.cooldownID = match.cooldownID or cdmDef.cooldownID
    match.cdmCategory = match.cdmCategory or cdmDef.category
    match.cdmKey = match.cdmKey or cdmDef.key
    for tag, enabled in pairs(cdmDef.auraTags or {}) do
        if enabled then match.tags[tag] = true end
    end
    for _, spellID in ipairs(cdmDef.spellIDs or {}) do
        self.aliases[spellID] = match.spellID
    end
    if cdmDef.spellID then self.aliases[cdmDef.spellID] = match.spellID end
    if cdmDef.iconSpellID then self.aliases[cdmDef.iconSpellID] = match.spellID end
end

-- CDM normally loads first because it is an optional dependency of this
-- addon. Merge its already-registered definitions once our catalog exists.
if EUI.MergeCDMRaidCooldownCatalog then
    EUI.MergeCDMRaidCooldownCatalog(Catalog)
end
