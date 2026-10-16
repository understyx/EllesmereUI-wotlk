-------------------------------------------------------------------------------
--  EUI_RaidFrames_RaidDebuffs.lua
--  Per-instance raid debuff catalog and the runtime "active set".
--
--  Saved data (profile, party-context aware through the options proxy):
--    raidDebuffs      = { [instanceKey] = { [spellID] = true | false } }
--                       Overrides on top of the catalog: false switches a
--                       catalog debuff off, true tracks it (catalog or custom).
--    raidDebuffHidden = { [spellID] = true }  -- never shown, anywhere.
--    raidDebuffSettings = { [spellID] = { colorHealth = bool,
--                                         healthColor = { r, g, b } } }
--                       Per-spell extras set from the picker's right-click
--                       menu; apply wherever the spell is tracked.
--
--  Matching is by spell NAME as well as ID: WotLK raids use a different spell
--  ID per difficulty (10 / 25 / heroic), and the catalog only lists one of
--  them. Outside a known instance only the "Everywhere" bucket applies, and
--  when that is empty the lookup is skipped entirely.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- mapIDs are GetCurrentMapAreaID() values on the 3.3.5 client (the same IDs
-- DBM's module TOCs use). names are the enUS GetInstanceInfo() names, used
-- when the map ID cannot be read (world map open).
-- Default debuffs: ElvUI-WotLK's RaidDebuffs filter
-- (ElvUI/Settings/Filters/UnitFrame.lua, commit 58ea24f7), plus a few
-- player debuffs from the DBM-Warmane boss modules.
ns.RAID_DEBUFF_INSTANCES = {
    { key = "global", name = "Everywhere", global = true, spells = {} },
    { key = "icc", name = "Icecrown Citadel", mapID = 605, spells = {
        69065, -- Impaled
        72109, -- Death and Decay
        71289, -- Dominate Mind
        71237, -- Curse of Torpor
        72293, -- Mark of the Fallen Champion
        72442, -- Boiling Blood
        72449, -- Rune of Blood
        72769, -- Scent of Blood
        71218, -- Vile Gas
        72219, -- Gastric Bloat
        69279, -- Gas Spore
        71224, -- Mutated Infection
        71278, -- Choking Gas Bomb
        70215, -- Gaseous Bloat
        72549, -- Malleable Goo
        70953, -- Plague Sickness
        72856, -- Unbound Plague
        70447, -- Volatile Ooze Adhesive
        72796, -- Glittering Sparks
        71822, -- Shadow Resonance
        72265, -- Delirious Slash
        71473, -- Essence of the Blood Queen
        71474, -- Frenzied Bloodthirst
        71340, -- Pact of the Darkfallen
        71265, -- Swarming Shadows
        70923, -- Uncontrollable Frenzy
        71733, -- Acid Burst
        71738, -- Corrosion
        70873, -- Emerald Vigor
        71283, -- Gut Spray
        70106, -- Chilled to the Bone
        70126, -- Frost Beacon
        70157, -- Ice Tomb
        69766, -- Instability
        69762, -- Unchained Magic
        72762, -- Defile
        70541, -- Infest
        70337, -- Necrotic Plague
        72149, -- Shockwave
        69409, -- Soul Reaper
        69242, -- Soul Shriek
    } },
    { key = "rs", name = "The Ruby Sanctum", mapID = 610, spells = {
        75887, -- Blazing Aura
        74502, -- Enervating Brand
        74367, -- Cleave Armor
        74562, -- Fiery Combustion
        74567, -- Mark of Combustion
        74792, -- Soul Consumption
        74795, -- Mark of Consumption
    } },
    { key = "toc", name = "Trial of the Crusader", mapID = 544, spells = {
        66331, -- Impale
        66406, -- Snobolled!
        66869, -- Burning Bile
        67618, -- Paralytic Toxin
        66689, -- Arctic Breath
        66237, -- Incinerate Flesh
        66197, -- Legion Flame
        65812, -- Unstable Affliction
        67309, -- Twin Spike
        66013, -- Penetrating Cold
        67574, -- Pursued by Anub'arak
        67847, -- Expose Weakness
    } },
    { key = "ulduar", name = "Ulduar", mapID = 530, spells = {
        62717, -- Slag Pot
        63024, -- Gravity Bomb
        63018, -- Light Bomb
        61903, -- Fusion Punch
        61912, -- Static Disruption
        64290, -- Stone Grip
        62130, -- Unbalancing Strike
        63134, -- Sara's Blessing
        64157, -- Curse of Doom
        64412, -- Phase Punch
    } },
    { key = "naxx", name = "Naxxramas", mapID = 536, spells = {
        54022, -- Locust Swarm
        54098, -- Poison Bolt Volley
        54121, -- Necrotic Poison
        54125, -- Web Spray
        29306, -- Infected Wound
        54378, -- Mortal Wound
        27825, -- Shadow Mark
        28679, -- Harvest Soul
        55645, -- Death Plague
        28832, -- Mark of Korth'azz
        28833, -- Mark of Blaumeux
        28834, -- Mark of Rivendare
        28835, -- Mark of Zeliek
        57369, -- Unholy Shadow
        29212, -- Cripple
        29213, -- Curse of the Plaguebringer
        29214, -- Wrath of the Plaguebringer
        29310, -- Spell Disruption
        29998, -- Decrepit Fever
        55052, -- Inevitable Doom
        55053, -- Deathbloom
        28522, -- Icebolt
        55665, -- Life Drain
        55699, -- Chill
        28410, -- Chains of Kel'Thuzad
        27819, -- Detonate Mana
        27808, -- Frost Blast
    } },
    { key = "os", name = "The Obsidian Sanctum", mapID = 532, spells = {
        57491, -- Flame Tsunami
    } },
    { key = "eoe", name = "The Eye of Eternity", mapID = 528, spells = {
        57407, -- Surge of Power
        60936, -- Surge of Power (25)
    } },
    { key = "voa", name = "Vault of Archavon", mapID = 533, spells = {
        58678, -- Rock Shards
        66684, -- Flaming Cinder
        72004, -- Frostbite
    } },
    { key = "ony", name = "Onyxia's Lair", mapID = 719, spells = {} },
}

local INSTANCES = ns.RAID_DEBUFF_INSTANCES
local BY_KEY, BY_MAP, BY_NAME = {}, {}, {}
for _, inst in ipairs(INSTANCES) do
    BY_KEY[inst.key] = inst
    if inst.mapID then BY_MAP[inst.mapID] = inst end
    BY_NAME[inst.name] = inst
    inst.defaults = {}
    for _, id in ipairs(inst.spells) do inst.defaults[id] = true end
end
ns.RAID_DEBUFF_BY_KEY = BY_KEY

-------------------------------------------------------------------------------
--  Current instance
-------------------------------------------------------------------------------
local currentKey      -- key of the instance the player is in, or nil
local generation = 0  -- bumped whenever currentKey changes

local function ResolveInstance()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "raid" and instanceType ~= "party") then
        return nil
    end
    -- SetMapToCurrentZone would yank an open world map to the player's zone.
    if GetCurrentMapAreaID and not (WorldMapFrame and WorldMapFrame:IsShown()) then
        SetMapToCurrentZone()
        local inst = BY_MAP[GetCurrentMapAreaID()]
        if inst then return inst.key end
    end
    local inst = BY_NAME[GetInstanceInfo() or ""] or BY_NAME[GetRealZoneText() or ""]
    return inst and inst.key or nil
end

local function UpdateInstance()
    local key = ResolveInstance()
    if key == currentKey then return end
    currentKey = key
    generation = generation + 1
    if ns._RefreshAllDebuffs then ns._RefreshAllDebuffs() end
end

ns.RD_GetCurrentInstanceKey = function() return currentKey end

do
    local watcher = CreateFrame("Frame")
    local pending = 0
    watcher:SetScript("OnUpdate", function(self, elapsed)
        pending = pending - elapsed
        if pending <= 0 then
            self:Hide()
            UpdateInstance()
        end
    end)
    watcher:Hide()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:SetScript("OnEvent", function()
        -- Resolve now so the entering-world frame reload already sees the
        -- right set, then once more after the map/instance info settles.
        UpdateInstance()
        pending = 2
        watcher:Show()
    end)
end

-------------------------------------------------------------------------------
--  Set helpers (shared with the picker)
-------------------------------------------------------------------------------
-- True when spellID is tracked in instance inst under the saved overrides.
ns.RD_IsTracked = function(overrides, inst, spellID)
    local ov = type(overrides) == "table" and overrides[inst.key]
    if type(ov) == "table" and ov[spellID] ~= nil then return ov[spellID] == true end
    return inst.defaults[spellID] == true
end

-- Ordered spell list for an instance: catalog entries, then custom ones.
ns.RD_GetInstanceSpells = function(overrides, inst)
    local list = {}
    for _, id in ipairs(inst.spells) do list[#list + 1] = id end
    local ov = type(overrides) == "table" and overrides[inst.key]
    if type(ov) == "table" then
        local extra = {}
        for id, v in pairs(ov) do
            local n = tonumber(id)
            -- Hand-added entries stay listed while switched off (false).
            if v ~= nil and n and not inst.defaults[n] then extra[#extra + 1] = n end
        end
        table.sort(extra)
        for _, id in ipairs(extra) do list[#list + 1] = id end
    end
    return list
end

ns.RD_CountTracked = function(overrides, inst)
    local count = 0
    for _, id in ipairs(ns.RD_GetInstanceSpells(overrides, inst)) do
        if ns.RD_IsTracked(overrides, inst, id) then count = count + 1 end
    end
    return count
end

local function AddSpell(set, id)
    set[id] = true
    local name = GetSpellInfo(id)
    if name then set[name] = true end
end

-------------------------------------------------------------------------------
--  Runtime lookups (debuff filter hot path)
--  Sets are keyed by spellID AND spell name. Caches are keyed by the saved
--  table itself, so a picker write (always a fresh copy) or a profile swap
--  misses the cache naturally; instance changes bump `generation`.
-------------------------------------------------------------------------------
local activeCache = setmetatable({}, { __mode = "k" })
local hiddenCache = setmetatable({}, { __mode = "k" })
local EMPTY = {}

-- Returns the tracked set for the current location, or nil when nothing is
-- tracked here (the caller then skips the lookup).
ns.RD_GetActiveSet = function(overrides)
    local cacheKey = type(overrides) == "table" and overrides or EMPTY
    local c = activeCache[cacheKey]
    if c and c.gen == generation then return c.set end
    local set, any = {}, false
    for _, key in ipairs({ "global", currentKey }) do
        local inst = BY_KEY[key]
        if inst then
            for _, id in ipairs(ns.RD_GetInstanceSpells(overrides, inst)) do
                if ns.RD_IsTracked(overrides, inst, id) then
                    AddSpell(set, id)
                    any = true
                end
            end
        end
    end
    if not any then set = nil end
    activeCache[cacheKey] = { gen = generation, set = set }
    return set
end

ns.RD_GetHiddenSet = function(hidden)
    if type(hidden) ~= "table" or next(hidden) == nil then return nil end
    local set = hiddenCache[hidden]
    if set then return set end
    set = {}
    for id, v in pairs(hidden) do
        local n = tonumber(id)
        if v == true and n then AddSpell(set, n) end
    end
    hiddenCache[hidden] = set
    return set
end

ns.RD_DEFAULT_HEALTH_COLOR = { r = 0.8, g = 0.2, b = 0.8 }

-- Returns { [spellID|name] = color } for spells whose settings tint the health
-- bar, or nil when none do.
local colorCache = setmetatable({}, { __mode = "k" })
ns.RD_GetHealthColorSet = function(settings)
    if type(settings) ~= "table" or next(settings) == nil then return nil end
    local set = colorCache[settings]
    if set ~= nil then return set or nil end
    for id, cfg in pairs(settings) do
        local n = tonumber(id)
        if n and type(cfg) == "table" and cfg.colorHealth then
            set = set or {}
            local col = cfg.healthColor or ns.RD_DEFAULT_HEALTH_COLOR
            set[n] = col
            local name = GetSpellInfo(n)
            if name then set[name] = col end
        end
    end
    colorCache[settings] = set or false
    return set
end

-------------------------------------------------------------------------------
--  Migration from the comma-separated whitelist / blacklist inputs
-------------------------------------------------------------------------------
local function CatalogInstanceFor(id)
    for _, inst in ipairs(INSTANCES) do
        if inst.defaults[id] then return inst end
    end
end

local function MigrateKeys(pf, prefix)
    local wl = pf[prefix .. "raidDebuffWhitelist"]
    local bl = pf[prefix .. "raidDebuffBlacklist"]
    if wl == nil and bl == nil then return end
    if type(wl) == "table" then
        local rd = pf[prefix .. "raidDebuffs"] or {}
        for id, v in pairs(wl) do
            local n = tonumber(id)
            if n then
                local inst = CatalogInstanceFor(n)
                if inst and v == false then
                    rd[inst.key] = rd[inst.key] or {}
                    rd[inst.key][n] = false
                elseif not inst and v == true then
                    rd.global = rd.global or {}
                    rd.global[n] = true
                end
            end
        end
        if next(rd) then pf[prefix .. "raidDebuffs"] = rd end
    end
    if type(bl) == "table" then
        local hidden = pf[prefix .. "raidDebuffHidden"] or {}
        for id, v in pairs(bl) do
            local n = tonumber(id)
            if n and v == true then hidden[n] = true end
        end
        if next(hidden) then pf[prefix .. "raidDebuffHidden"] = hidden end
    end
    pf[prefix .. "raidDebuffWhitelist"] = nil
    pf[prefix .. "raidDebuffBlacklist"] = nil
end

-- Called from OnInitialize for every saved profile's raid frames table.
ns.RD_MigrateProfile = function(pf)
    if type(pf) ~= "table" then return end
    MigrateKeys(pf, "")
    MigrateKeys(pf, "party_")
end
