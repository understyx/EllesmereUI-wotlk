-------------------------------------------------------------------------------
--  EllesmereUIQoL_BuffRemoval.lua
--  Automatically removes selected player buffs. Rules live in one table so
--  per-spell conditions share one UNIT_AURA handler. The context gate is also
--  used by the Tricks/Misdirection threat-transfer cleanup in the main file.
-------------------------------------------------------------------------------

local CHAOS_BANE_BOSSES = {
    { isHeader = true, label = "Icecrown Citadel" },
    { key = "marrowgar",       label = "Lord Marrowgar",          npcIDs = { 36612 } },
    { key = "deathwhisper",    label = "Lady Deathwhisper",       npcIDs = { 36855 } },
    { key = "gunship",        label = "Gunship Battle",          npcIDs = { 36939, 36948 } },
    { key = "saurfang",       label = "Deathbringer Saurfang",   npcIDs = { 37813 } },
    { key = "festergut",      label = "Festergut",               npcIDs = { 36626 } },
    { key = "rotface",        label = "Rotface",                 npcIDs = { 36627 } },
    { key = "putricide",      label = "Professor Putricide",     npcIDs = { 36678 } },
    { key = "blood_princes",  label = "Blood Prince Council",    npcIDs = { 37970, 37972, 37973 } },
    { key = "lana_thel",      label = "Blood-Queen Lana'thel",   npcIDs = { 37955 } },
    { key = "valithria",      label = "Valithria Dreamwalker",   npcIDs = { 36789 } },
    { key = "sindragosa",     label = "Sindragosa",              npcIDs = { 36853 } },
    { key = "lich_king",      label = "The Lich King",           npcIDs = { 36597 } },
    { isHeader = true, label = "The Ruby Sanctum" },
    { key = "saviana",        label = "Saviana Ragefire",        npcIDs = { 39747 } },
    { key = "baltharus",      label = "Baltharus the Warborn",   npcIDs = { 39751, 39899 } },
    { key = "zarithrian",     label = "General Zarithrian",      npcIDs = { 39746 } },
    { key = "halion",         label = "Halion",                  npcIDs = { 39863, 40142 } },
}
EllesmereUI.BuffRemovalBosses = CHAOS_BANE_BOSSES

local bossKeyByNPCID = {}
for _, boss in ipairs(CHAOS_BANE_BOSSES) do
    for _, npcID in ipairs(boss.npcIDs or {}) do bossKeyByNPCID[npcID] = boss.key end
end

local function SettingEnabled(key, default)
    local value = EllesmereUIDB and EllesmereUIDB[key]
    if value == nil then return default == true end
    return value == true
end

local function CancellationContextAllowed()
    local _, instanceType = IsInInstance()
    if instanceType == "arena" then
        return SettingEnabled("auraCancelInArena", false)
    end
    if (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 then
        return SettingEnabled("auraCancelInRaid", true)
    end
    if (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0 then
        return SettingEnabled("auraCancelInParty", true)
    end
    return SettingEnabled("auraCancelSoloOpenWorld", false)
end
EllesmereUI.IsAuraCancellationAllowed = CancellationContextAllowed

local function NPCIDFromGUID(guid)
    if not guid then return nil end
    if guid:sub(1, 2) == "0x" then
        return tonumber(guid:sub(7, 12), 16)
    end
    return tonumber(guid:match("^.-%-(%d+)%-%x+$"))
end

local function UnitIsBlacklistedBoss(unit, blacklist)
    if not UnitExists(unit) then return false end
    local key = bossKeyByNPCID[NPCIDFromGUID(UnitGUID(unit))]
    return key and blacklist[key] == true
end

local function HasBlacklistedBoss()
    local blacklist = EllesmereUIDB and EllesmereUIDB.chaosBaneBossBlacklist
    if type(blacklist) ~= "table" or next(blacklist) == nil then return false end

    local direct = { "target", "focus", "mouseover", "boss1", "boss2", "boss3", "boss4" }
    for _, unit in ipairs(direct) do
        if UnitIsBlacklistedBoss(unit, blacklist) then return true end
    end
    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    for index = 1, raidCount do
        if UnitIsBlacklistedBoss("raid" .. index .. "target", blacklist) then return true end
    end
    local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    for index = 1, partyCount do
        if UnitIsBlacklistedBoss("party" .. index .. "target", blacklist) then return true end
    end
    return false
end

local function HasBlacklistedSeal()
    local blacklist = EllesmereUIDB and EllesmereUIDB.chaosBaneSealBlacklist
    if type(blacklist) ~= "table" or next(blacklist) == nil then return false end
    for index = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", index)
        if not name then break end
        if spellID and blacklist[tostring(spellID)] == true then return true end
    end
    return false
end

local function CanCancelChaosBane()
    return not HasBlacklistedSeal() and not HasBlacklistedBoss()
end

local AURA_RULES = {
    -- Divine Intervention's cast is 19752 and its triggered immunity buff is
    -- 19753. Accept both so servers that expose either ID on UnitBuff work.
    { setting = "autoCancelDivineIntervention", spells = { 19752, 19753 } },
    { setting = "autoCancelHandOfProtection",   spells = { 1022, 5599, 10278 } },
    { setting = "autoCancelDivineSacrifice",    spells = { 64205 }, class = "PALADIN" },
    { setting = "autoCancelChaosBane",          spells = { 73422 }, class = "PALADIN", canCancel = CanCancelChaosBane },
}

local enabledAuras = {}
local removalFrame = EllesmereUI.SafeCreateFrame("Frame")

local function RebuildEnabledAuras()
    wipe(enabledAuras)
    local playerClass = select(2, UnitClass("player"))
    for _, rule in ipairs(AURA_RULES) do
        if EllesmereUIDB and EllesmereUIDB[rule.setting] == true
            and (not rule.class or rule.class == playerClass) then
            for _, spellID in ipairs(rule.spells) do
                enabledAuras[spellID] = rule
            end
        end
    end
end

local function CancelEnabledAuras()
    if next(enabledAuras) == nil or not CancellationContextAllowed() then return end
    for index = 40, 1, -1 do
        local name, _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", index)
        local rule = spellID and enabledAuras[spellID]
        if name and rule and (not rule.canCancel or rule.canCancel()) then
            CancelUnitBuff("player", index)
        end
    end
end

local function ApplyBuffRemoval()
    removalFrame:UnregisterAllEvents()
    RebuildEnabledAuras()
    if next(enabledAuras) == nil then return end
    removalFrame:RegisterUnitEvent("UNIT_AURA", "player")
    CancelEnabledAuras()
end

removalFrame:SetScript("OnEvent", function(_, _, unit)
    if unit == "player" then CancelEnabledAuras() end
end)

EllesmereUI._applyBuffRemoval = ApplyBuffRemoval

local boot = EllesmereUI.SafeCreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    ApplyBuffRemoval()
end)
