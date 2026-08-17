-------------------------------------------------------------------------------
--  EllesmereUIDamageMeters_SkadaAdapter.lua
--  Backend adapter for EllesmereUI Damage Meters using Skada on WotLK 3.3.5a.
--  Provides full C_DamageMeter and C_DeathRecap emulation layer.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = ns or {}
local EUI = EllesmereUI

-- ---------------------------------------------------------------------------
--  Enums & Global Namespaces
-- ---------------------------------------------------------------------------
_G.Enum = _G.Enum or {}

Enum.DamageMeterType = Enum.DamageMeterType or {
    DamageDone           = 1,
    HealingDone          = 2,
    DamageTaken          = 3,
    AvoidableDamageTaken = 4,
    EnemyDamageTaken     = 5,
    Interrupts           = 6,
    Dispels              = 7,
    Deaths               = 8,
}

Enum.DamageMeterSessionType = Enum.DamageMeterSessionType or {
    Current = 0,
    Overall = 1,
}

Enum.AddOnProfilerMetric = Enum.AddOnProfilerMetric or {
    LastTime    = 1,
    AverageTime = 2,
    PeakTime    = 3,
    Count       = 4,
}

_G.C_DamageMeter = _G.C_DamageMeter or {}
_G.C_DeathRecap  = _G.C_DeathRecap or {}

-- Declare backend on addon namespace
ns.DamageMeterBackend = "skada"

-- ---------------------------------------------------------------------------
--  Spec Icon Lookup for WotLK 3.3.5
-- ---------------------------------------------------------------------------
local SPEC_ICONS = {
    -- Warrior
    [71]  = [[Interface\Icons\Ability_Warrior_SavageBlow]],       -- Arms
    [72]  = [[Interface\Icons\Ability_Warrior_InnerRage]],        -- Fury
    [73]  = [[Interface\Icons\Ability_Warrior_DefensiveStance]],  -- Protection
    -- Paladin
    [65]  = [[Interface\Icons\Spell_Holy_HolyBolt]],              -- Holy
    [66]  = [[Interface\Icons\Spell_Holy_DevotionAura]],          -- Protection
    [70]  = [[Interface\Icons\Spell_Holy_AuraOfLight]],           -- Retribution
    -- Hunter
    [253] = [[Interface\Icons\Ability_Hunter_BeastTaming]],       -- Beast Mastery
    [254] = [[Interface\Icons\Ability_Marksmanship]],             -- Marksmanship
    [255] = [[Interface\Icons\Ability_Hunter_SwiftStrike]],       -- Survival
    -- Rogue
    [259] = [[Interface\Icons\Ability_Rogue_Eviscerate]],         -- Assassination
    [260] = [[Interface\Icons\Ability_BackStab]],                 -- Combat
    [261] = [[Interface\Icons\Ability_Stealth]],                  -- Subtlety
    -- Priest
    [256] = [[Interface\Icons\Spell_Holy_PowerWordShield]],       -- Discipline
    [257] = [[Interface\Icons\Spell_Holy_GuardianSpirit]],        -- Holy
    [258] = [[Interface\Icons\Spell_Shadow_ShadowWordPain]],      -- Shadow
    -- Death Knight
    [250] = [[Interface\Icons\Spell_Deathknight_BloodPresence]],  -- Blood
    [251] = [[Interface\Icons\Spell_Deathknight_FrostPresence]],  -- Frost
    [252] = [[Interface\Icons\Spell_Deathknight_UnholyPresence]], -- Unholy
    -- Shaman
    [262] = [[Interface\Icons\Spell_Nature_Lightning]],           -- Elemental
    [263] = [[Interface\Icons\Spell_Nature_LightningShield]],     -- Enhancement
    [264] = [[Interface\Icons\Spell_Nature_MagicImmunity]],       -- Restoration
    -- Mage
    [62]  = [[Interface\Icons\Spell_Holy_MagicalSentry]],         -- Arcane
    [63]  = [[Interface\Icons\Spell_Fire_FireBolt02]],            -- Fire
    [64]  = [[Interface\Icons\Spell_Frost_FrostBolt02]],          -- Frost
    -- Warlock
    [265] = [[Interface\Icons\Spell_Shadow_DeathCoil]],           -- Affliction
    [266] = [[Interface\Icons\Spell_Shadow_Metamorphosis]],       -- Demonology
    [267] = [[Interface\Icons\Spell_Shadow_RainOfFire]],          -- Destruction
    -- Druid
    [102] = [[Interface\Icons\Spell_Nature_StarFall]],            -- Balance
    [103] = [[Interface\Icons\Ability_Racial_BearForm]],          -- Feral
    [105] = [[Interface\Icons\Spell_Nature_HealingTouch]],        -- Restoration
}

local function ResolveSpecIcon(specID, classFilename)
    if specID and SPEC_ICONS[specID] then
        return SPEC_ICONS[specID]
    end
    if specID and EUI and EUI.Spec and EUI.Spec.GetInfoByID then
        local info = EUI.Spec:GetInfoByID(specID)
        if info and info.icon then return info.icon end
    end
    return nil
end

local function GetSkada()
    return _G.Skada
end

-- ---------------------------------------------------------------------------
--  Spell Data Resolution Helper (handles negative IDs for DoT/HoT, pets, suffixes)
-- ---------------------------------------------------------------------------
local function ResolveSpellData(spellKey, isHot)
    local Skada = GetSkada()
    local spellid, school, suffix

    if Skada and Skada.Private and Skada.Private.SpellSplit then
        spellid, school, suffix = Skada.Private.SpellSplit(spellKey)
    elseif type(spellKey) == "string" and string.find(spellKey, "%.") then
        local id, sch, sfx = strsplit(".", spellKey, 3)
        spellid, school, suffix = tonumber(id), tonumber(sch), sfx
    elseif type(spellKey) == "number" then
        spellid = spellKey
    elseif type(spellKey) == "string" then
        spellid = tonumber(spellKey)
    end

    local rawID = spellid or 0
    local cleanID = math.abs(rawID)
    local isPeriodic = (rawID < 0)

    -- Get icon and base name
    local name, icon
    if Skada and Skada.spellnames and Skada.spellnames[rawID] then
        name = Skada.spellnames[rawID]
        icon = Skada.spellicons and Skada.spellicons[rawID]
    elseif Skada and Skada.Private and Skada.Private.SpellInfo then
        local n, _, ic = Skada.Private.SpellInfo(rawID)
        name, icon = n, ic
    end

    if not name or name == "" then
        if cleanID > 0 and C_Spell and C_Spell.GetSpellName then
            name = C_Spell.GetSpellName(cleanID)
        elseif cleanID > 0 and GetSpellInfo then
            name = GetSpellInfo(cleanID)
        end
    end

    if not icon and cleanID > 0 then
        if C_Spell and C_Spell.GetSpellTexture then
            icon = C_Spell.GetSpellTexture(cleanID)
        elseif GetSpellInfo then
            icon = select(3, GetSpellInfo(cleanID))
        end
    end

    -- Special fallbacks for WoW melee / auto shot / common IDs
    if cleanID == 6603 or spellKey == "6603" or spellKey == "Melee" then
        if not name or name == "" or name == "6603" then name = (Skada and Skada.Locale and Skada.Locale["Melee"]) or "Melee" end
        if not icon then icon = [[Interface\ICONS\inv_sword_04]] end
    elseif cleanID == 75 or spellKey == "75" or spellKey == "Auto Shot" then
        if not name or name == "" or name == "75" then name = (Skada and Skada.Locale and Skada.Locale["Auto Shot"]) or "Auto Shot" end
        if not icon then icon = [[Interface\ICONS\inv_weapon_bow_07]] end
    end

    if not name or name == "" then
        name = tostring(spellKey or "Unknown")
    end

    -- Suffix / Pet / Extra attacks handling (mimic Skada's Window:spell format)
    local L_DoT = (Skada and Skada.Locale and Skada.Locale["DoT"]) or "DoT"
    local L_HoT = (Skada and Skada.Locale and Skada.Locale["HoT"]) or "HoT"

    local label = name
    if tonumber(suffix) then
        local extraID = tonumber(suffix)
        local extraName = (Skada and Skada.spellnames and Skada.spellnames[extraID])
            or (cleanID > 0 and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(extraID))
            or (GetSpellInfo and GetSpellInfo(extraID))
            or tostring(extraID)
        label = string.format("%s (%s)", extraName, name)
    elseif suffix and suffix ~= "" then
        label = string.format("%s (%s)", name, suffix)
    end

    if isPeriodic and isHot ~= false then
        local tag = isHot and L_HoT or L_DoT
        label = string.format("%s (%s)", label, tag)
    end

    return cleanID, label, icon, school
end

-- ---------------------------------------------------------------------------
--  Death Recap Cache & C_DeathRecap Implementation
-- ---------------------------------------------------------------------------
local _deathRecaps = {}

function C_DeathRecap.GetRecapEvents(recapID)
    if not recapID or recapID <= 0 then return nil end
    local dlog = _deathRecaps[recapID]
    if not dlog or not dlog.log or #dlog.log == 0 then return nil end

    local events = {}
    for _, logEntry in ipairs(dlog.log) do
        local rawID = logEntry.id
        local isHeal = logEntry.amt and logEntry.amt > 0
        local sid, sname, sicon = ResolveSpellData(rawID, isHeal)

        local evType = isHeal and "SPELL_HEAL" or "SPELL_DAMAGE"
        if rawID == "6603" or sid == 6603 or rawID == "Melee" then
            evType = "SWING_DAMAGE"
        end

        events[#events + 1] = {
            spellId   = sid,
            spellName = sname,
            icon      = sicon,
            event     = evType,
            currentHP = logEntry.hp or 0,
            amount    = logEntry.amt or 0,
            overkill  = logEntry.ovk or 0,
            timestamp = logEntry.time or 0,
        }
    end

    return events
end

function C_DeathRecap.GetRecapMaxHealth(recapID)
    if not recapID or recapID <= 0 then return 1 end
    local dlog = _deathRecaps[recapID]
    return (dlog and dlog.hpm and dlog.hpm > 0) and dlog.hpm or 1
end

-- ---------------------------------------------------------------------------
--  Skada Data Helpers
-- ---------------------------------------------------------------------------
local function GetSetFromType(sessionType)
    local Skada = GetSkada()
    if not Skada then return nil end
    if sessionType == Enum.DamageMeterSessionType.Overall then
        return Skada.total
    end
    -- Current fight (fall back to last or newest stored segment if idle)
    return Skada.current or Skada.last or (Skada.sets and Skada.sets[1])
end

local function GetSetFromID(sessionID)
    local Skada = GetSkada()
    if not Skada or not Skada.sets then return nil end
    return Skada.sets[sessionID]
end

local function GetSetDuration(set)
    if not set then return 0 end
    if set.GetTime then
        return set:GetTime() or 0
    end
    local Skada = GetSkada()
    if Skada and Skada.GetSetTime then
        return Skada:GetSetTime(set) or 0
    end
    return set.time or 0
end

local function ResolveClassFilename(actor, actorName)
    local c = actor.class
    if c and c ~= "" and c ~= "UNKNOWN" and c ~= "PLAYER" then
        return c
    end
    if actorName then
        local _, unitClass = UnitClass(actorName)
        if unitClass then return unitClass end
    end
    if actor.id and UnitExists(actor.id) then
        local _, unitClass = UnitClass(actor.id)
        if unitClass then return unitClass end
    end
    return actor.class or "UNKNOWN"
end

local function FindActorInSet(set, guid, creatureID, name)
    if not set or not set.actors then return nil end
    -- Direct name lookup
    if name and set.actors[name] then
        local actor = set.actors[name]
        actor.name = actor.name or name
        return actor
    end
    -- GUID or fallback name lookup
    for actorName, actor in pairs(set.actors) do
        actor.name = actor.name or actorName
        if guid and (actor.id == guid or actor.name == guid or actorName == guid) then
            return actor
        end
        if creatureID and actor.enemy then
            local Skada = GetSkada()
            local cId = (Skada and Skada.GetCreatureId and Skada.GetCreatureId(actor.id)) or tonumber(actor.id)
            if cId == creatureID then
                return actor
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Virtual Skada Window for generic mode execution
-- ---------------------------------------------------------------------------
local virtualWin = {
    dataset = {},
    metadata = {},
    history = {},
    selectedset = nil,
    db = {
        columns = {},
        showtotals = false,
    },
}

function virtualWin:GetSelectedSet()
    return self.selectedset
end

function virtualWin:show_actor(actor, set, strict)
    if not actor then return false end
    if self.class and actor.class ~= self.class then return false end
    if strict and actor.fake then return false end
    if strict and actor.enemy and not (set and set.arena) then return false end
    return true
end

function virtualWin:nr(index)
    local d = self.dataset[index]
    if d then
        wipe(d)
        return d
    end
    d = {}
    self.dataset[index] = d
    return d
end

function virtualWin:actor(d, actor, is_enemy, actorname)
    if type(d) == "number" then d = self:nr(d) end
    if not actor then return d end
    if type(actor) == "string" then
        d.id = actor
        d.label = actorname or actor
        return d
    end
    d.id = actor.id or actorname
    d.label = actorname or (actor.name) or "Unknown"
    if string.match(d.label, "^%<(.+)%>$") then
        d.class = "PET"
        return d
    end
    if is_enemy then
        d.class = actor.class or "ENEMY"
        d.role = actor.role
        d.spec = actor.spec
        return d
    end
    d.class = actor.class or "UNKNOWN"
    d.role = actor.role
    d.spec = actor.spec
    return d
end

function virtualWin:spell(d, spell, is_hot)
    if type(d) == "number" then d = self:nr(d) end
    if not spell then return d end
    d.id = spell
    local sid, sname, sicon, sschool = ResolveSpellData(spell, is_hot)
    d.spellid = sid
    d.spellschool = sschool
    d.icon = sicon
    d.label = sname
    return d
end

function virtualWin:color(d, set, is_enemy)
end

function virtualWin:reset()
    self.title = nil
    self.class = nil
    self.actorid = nil
    self.actorname = nil
    wipe(self.dataset)
    wipe(self.metadata)
end

local function FindSkadaMode(nameOrType)
    local Skada = GetSkada()
    if not Skada or not Skada.GetModes then return nil end
    local modes = Skada:GetModes()
    if not modes then return nil end
    if type(nameOrType) == "table" and nameOrType.Update then
        return nameOrType
    end

    local targetName = nameOrType
    if nameOrType == Enum.DamageMeterType.DamageDone then targetName = "Damage"
    elseif nameOrType == Enum.DamageMeterType.HealingDone then targetName = "Healing"
    elseif nameOrType == Enum.DamageMeterType.DamageTaken then targetName = "Damage Taken"
    elseif nameOrType == Enum.DamageMeterType.AvoidableDamageTaken then targetName = "Failbot"
    elseif nameOrType == Enum.DamageMeterType.EnemyDamageTaken then targetName = "Enemy Damage Taken"
    elseif nameOrType == Enum.DamageMeterType.Interrupts then targetName = "Interrupts"
    elseif nameOrType == Enum.DamageMeterType.Dispels then targetName = "Dispels"
    elseif nameOrType == Enum.DamageMeterType.Deaths then targetName = "Deaths"
    end

    for _, mode in ipairs(modes) do
        if mode.moduleName == targetName or mode.localeName == targetName or mode.name == targetName then
            return mode
        end
    end
    local targetLower = string.lower(tostring(targetName or ""))
    for _, mode in ipairs(modes) do
        if string.lower(mode.moduleName or "") == targetLower or string.lower(mode.localeName or "") == targetLower then
            return mode
        end
    end
    return nil
end

function ns.GetSkadaModes()
    local Skada = GetSkada()
    if not Skada or not Skada.GetModes then return {} end
    local rawModes = Skada:GetModes()
    local list = {}
    for _, m in ipairs(rawModes) do
        list[#list + 1] = {
            moduleName = m.moduleName,
            localeName = m.localeName or m.moduleName,
            category   = m.category or "Other",
            icon       = m.metadata and m.metadata.icon,
        }
    end
    return list
end
C_DamageMeter.GetAvailableModes = ns.GetSkadaModes

-- ---------------------------------------------------------------------------
--  Combat Session Builder (Converts Skada Set -> C_DamageMeter structure)
-- ---------------------------------------------------------------------------
local function BuildCombatSources(set, dmType)
    if not set or not set.actors then return {} end
    local Skada = GetSkada()
    local setTime = math.max(1, GetSetDuration(set))
    local isAbsDamage = Skada and Skada.db and Skada.db.profile and Skada.db.profile.absdamage
    local playerGUID = UnitGUID("player")
    local playerName = UnitName("player")
    local sources = {}

    if dmType == Enum.DamageMeterType.DamageDone then
        for actorName, actor in pairs(set.actors) do
            if not actor.enemy then
                local resolvedName = actor.name or actorName
                actor.name = resolvedName
                local amount = 0
                if isAbsDamage and actor.totaldamage then
                    amount = actor.totaldamage
                elseif actor.GetDamage then
                    amount = actor:GetDamage()
                elseif actor.damage then
                    amount = actor.damage
                end

                if amount and amount > 0 then
                    local dps = 0
                    if actor.GetDPS then
                        dps = select(1, actor:GetDPS(set))
                    else
                        local actTime = (actor.GetTime and actor:GetTime(set)) or setTime
                        dps = amount / math.max(1, actTime)
                    end

                    local cFilename = ResolveClassFilename(actor, resolvedName)
                    local isLocal = (actor.id == playerGUID) or (resolvedName == playerName) or (Skada and Skada.userGUID and actor.id == Skada.userGUID)

                    sources[#sources + 1] = {
                        name            = resolvedName,
                        sourceGUID      = actor.id,
                        classFilename   = cFilename,
                        specIconID      = ResolveSpecIcon(actor.spec, cFilename),
                        totalAmount     = amount,
                        amountPerSecond = dps,
                        isLocalPlayer   = isLocal,
                    }
                end
            end
        end
        table.sort(sources, function(a, b) return a.totalAmount > b.totalAmount end)

    elseif dmType == Enum.DamageMeterType.HealingDone then
        for actorName, actor in pairs(set.actors) do
            if not actor.enemy then
                local resolvedName = actor.name or actorName
                actor.name = resolvedName
                local amount = 0
                if actor.GetAbsorbHeal then
                    amount = actor:GetAbsorbHeal()
                else
                    amount = (actor.heal or 0) + (actor.absorb or 0)
                end

                if amount and amount > 0 then
                    local hps = 0
                    if actor.GetAHPS then
                        hps = select(1, actor:GetAHPS(set))
                    elseif actor.GetHPS then
                        hps = select(1, actor:GetHPS(set))
                    else
                        local actTime = (actor.GetTime and actor:GetTime(set)) or setTime
                        hps = amount / math.max(1, actTime)
                    end

                    local cFilename = ResolveClassFilename(actor, resolvedName)
                    local isLocal = (actor.id == playerGUID) or (resolvedName == playerName) or (Skada and Skada.userGUID and actor.id == Skada.userGUID)

                    sources[#sources + 1] = {
                        name            = resolvedName,
                        sourceGUID      = actor.id,
                        classFilename   = cFilename,
                        specIconID      = ResolveSpecIcon(actor.spec, cFilename),
                        totalAmount     = amount,
                        amountPerSecond = hps,
                        isLocalPlayer   = isLocal,
                    }
                end
            end
        end
        table.sort(sources, function(a, b) return a.totalAmount > b.totalAmount end)

    elseif dmType == Enum.DamageMeterType.DamageTaken then
        for actorName, actor in pairs(set.actors) do
            if not actor.enemy then
                local resolvedName = actor.name or actorName
                actor.name = resolvedName
                local amount = 0
                if isAbsDamage and actor.totaldamaged then
                    amount = actor.totaldamaged
                elseif actor.GetDamageTaken then
                    amount = actor:GetDamageTaken()
                elseif actor.damaged then
                    amount = actor.damaged
                end

                if amount and amount > 0 then
                    local dtps = 0
                    if actor.GetDTPS then
                        dtps = select(1, actor:GetDTPS(set))
                    else
                        local actTime = (actor.GetTime and actor:GetTime(set)) or setTime
                        dtps = amount / math.max(1, actTime)
                    end

                    local cFilename = ResolveClassFilename(actor, resolvedName)
                    local isLocal = (actor.id == playerGUID) or (resolvedName == playerName) or (Skada and Skada.userGUID and actor.id == Skada.userGUID)

                    sources[#sources + 1] = {
                        name            = resolvedName,
                        sourceGUID      = actor.id,
                        classFilename   = cFilename,
                        specIconID      = ResolveSpecIcon(actor.spec, cFilename),
                        totalAmount     = amount,
                        amountPerSecond = dtps,
                        isLocalPlayer   = isLocal,
                    }
                end
            end
        end
        table.sort(sources, function(a, b) return a.totalAmount > b.totalAmount end)

    elseif dmType == Enum.DamageMeterType.EnemyDamageTaken then
        for actorName, actor in pairs(set.actors) do
            if actor.enemy then
                local resolvedName = actor.name or actorName
                actor.name = resolvedName
                local amount = 0
                if isAbsDamage and actor.totaldamaged then
                    amount = actor.totaldamaged
                elseif actor.GetDamageTaken then
                    amount = actor:GetDamageTaken()
                elseif actor.damaged then
                    amount = actor.damaged
                end

                if amount and amount > 0 then
                    local dtps = 0
                    if actor.GetDTPS then
                        dtps = select(1, actor:GetDTPS(set))
                    else
                        local actTime = (actor.GetTime and actor:GetTime(set)) or setTime
                        dtps = amount / math.max(1, actTime)
                    end

                    local cId = (Skada and Skada.GetCreatureId and Skada.GetCreatureId(actor.id)) or tonumber(actor.id)
                    local cFilename = ResolveClassFilename(actor, resolvedName)
                    if cFilename == "UNKNOWN" then cFilename = "MONSTER" end

                    sources[#sources + 1] = {
                        name             = resolvedName,
                        sourceGUID       = actor.id,
                        sourceCreatureID = cId,
                        classFilename    = cFilename,
                        totalAmount      = amount,
                        amountPerSecond  = dtps,
                        isLocalPlayer    = false,
                    }
                end
            end
        end
        table.sort(sources, function(a, b) return a.totalAmount > b.totalAmount end)

    elseif dmType == Enum.DamageMeterType.Interrupts then
        for actorName, actor in pairs(set.actors) do
            if not actor.enemy then
                local resolvedName = actor.name or actorName
                actor.name = resolvedName
                local count = actor.interrupt or 0
                if count > 0 then
                    local cFilename = ResolveClassFilename(actor, resolvedName)
                    local isLocal = (actor.id == playerGUID) or (resolvedName == playerName) or (Skada and Skada.userGUID and actor.id == Skada.userGUID)

                    sources[#sources + 1] = {
                        name            = resolvedName,
                        sourceGUID      = actor.id,
                        classFilename   = cFilename,
                        specIconID      = ResolveSpecIcon(actor.spec, cFilename),
                        totalAmount     = count,
                        amountPerSecond = count / setTime,
                        isLocalPlayer   = isLocal,
                    }
                end
            end
        end
        table.sort(sources, function(a, b) return a.totalAmount > b.totalAmount end)

    elseif dmType == Enum.DamageMeterType.Dispels then
        for actorName, actor in pairs(set.actors) do
            if not actor.enemy then
                local resolvedName = actor.name or actorName
                actor.name = resolvedName
                local count = actor.dispel or 0
                if count > 0 then
                    local cFilename = ResolveClassFilename(actor, resolvedName)
                    local isLocal = (actor.id == playerGUID) or (resolvedName == playerName) or (Skada and Skada.userGUID and actor.id == Skada.userGUID)

                    sources[#sources + 1] = {
                        name            = resolvedName,
                        sourceGUID      = actor.id,
                        classFilename   = cFilename,
                        specIconID      = ResolveSpecIcon(actor.spec, cFilename),
                        totalAmount     = count,
                        amountPerSecond = count / setTime,
                        isLocalPlayer   = isLocal,
                    }
                end
            end
        end
        table.sort(sources, function(a, b) return a.totalAmount > b.totalAmount end)

    elseif dmType == Enum.DamageMeterType.Deaths then
        for actorName, actor in pairs(set.actors) do
            if not actor.enemy then
                local resolvedName = actor.name or actorName
                actor.name = resolvedName
                local cFilename = ResolveClassFilename(actor, resolvedName)
                local isLocal = (actor.id == playerGUID) or (resolvedName == playerName) or (Skada and Skada.userGUID and actor.id == Skada.userGUID)
                local deathlogs = actor.deathlog

                if deathlogs and #deathlogs > 0 then
                    for _, dlog in ipairs(deathlogs) do
                        local recapID = #_deathRecaps + 1
                        _deathRecaps[recapID] = dlog

                        local deathOffset = 0
                        if dlog.time and set.starttime and set.starttime > 0 then
                            deathOffset = math.max(0, dlog.time - set.starttime)
                        elseif dlog.time then
                            deathOffset = dlog.time
                        end

                        sources[#sources + 1] = {
                            name             = resolvedName,
                            sourceGUID       = actor.id,
                            classFilename    = cFilename,
                            specIconID       = ResolveSpecIcon(actor.spec, cFilename),
                            deathTimeSeconds = deathOffset,
                            deathRecapID     = recapID,
                            totalAmount      = 1,
                            amountPerSecond  = 0,
                            isLocalPlayer    = isLocal,
                        }
                    end
                elseif actor.death and actor.death > 0 then
                    sources[#sources + 1] = {
                        name             = resolvedName,
                        sourceGUID       = actor.id,
                        classFilename    = cFilename,
                        specIconID       = ResolveSpecIcon(actor.spec, cFilename),
                        deathTimeSeconds = 0,
                        deathRecapID     = 0,
                        totalAmount      = actor.death,
                        amountPerSecond  = 0,
                        isLocalPlayer    = isLocal,
                    }
                end
            end
        end
        -- Sort deaths chronologically
        table.sort(sources, function(a, b)
            return (a.deathTimeSeconds or 0) < (b.deathTimeSeconds or 0)
        end)

    elseif dmType == Enum.DamageMeterType.AvoidableDamageTaken then
        for actorName, actor in pairs(set.actors) do
            if not actor.enemy then
                local resolvedName = actor.name or actorName
                actor.name = resolvedName
                local count = actor.fail or 0
                if count > 0 then
                    local cFilename = ResolveClassFilename(actor, resolvedName)
                    local isLocal = (actor.id == playerGUID) or (resolvedName == playerName) or (Skada and Skada.userGUID and actor.id == Skada.userGUID)

                    sources[#sources + 1] = {
                        name            = resolvedName,
                        sourceGUID      = actor.id,
                        classFilename   = cFilename,
                        specIconID      = ResolveSpecIcon(actor.spec, cFilename),
                        totalAmount     = count,
                        amountPerSecond = count / setTime,
                        isLocalPlayer   = isLocal,
                    }
                end
            end
        end
        table.sort(sources, function(a, b) return a.totalAmount > b.totalAmount end)
    else
        -- Generic fallback: Run ANY Skada mode via virtual window
        local mode = FindSkadaMode(dmType)
        if mode and mode.Update then
            virtualWin:reset()
            virtualWin.selectedset = set
            if mode.metadata then
                for k, v in pairs(mode.metadata) do
                    virtualWin.metadata[k] = v
                end
            end
            local ok = pcall(mode.Update, mode, virtualWin, set)
            if ok and virtualWin.dataset then
                for _, d in ipairs(virtualWin.dataset) do
                    if not d.ignore and (d.value or d.valuetext) then
                        local cFilename = d.class or "UNKNOWN"
                        local resolvedName = d.label or tostring(d.id or "Unknown")
                        local actor = set and set.actors and (set.actors[resolvedName] or (d.id and set.actors[d.id]))
                        if (not cFilename or cFilename == "UNKNOWN") and actor then
                            cFilename = ResolveClassFilename(actor, resolvedName)
                        end
                        if (not cFilename or cFilename == "UNKNOWN") and resolvedName then
                            local _, uClass = UnitClass(resolvedName)
                            if uClass then cFilename = uClass end
                        end

                        local specId = d.spec or (actor and actor.spec)
                        local specIcon = d.icon or ResolveSpecIcon(specId, cFilename)
                        local isLocal = (d.id == playerGUID) or (resolvedName == playerName) or (Skada and Skada.userGUID and d.id == Skada.userGUID)
                        local val = type(d.value) == "number" and d.value or 0
                        local aps = setTime > 0 and (val / setTime) or 0

                        sources[#sources + 1] = {
                            name            = resolvedName,
                            sourceGUID      = d.id or resolvedName,
                            classFilename   = cFilename,
                            specIconID      = specIcon,
                            totalAmount     = val,
                            amountPerSecond = aps,
                            formattedValue  = d.valuetext,
                            isLocalPlayer   = isLocal,
                            icon            = d.icon,
                            color           = d.color,
                        }
                    end
                end

                if not (mode.metadata and mode.metadata.ordersort) then
                    table.sort(sources, function(a, b) return a.totalAmount > b.totalAmount end)
                end
            end
        end
    end

    return sources
end

-- ---------------------------------------------------------------------------
--  Combat Session Source Breakdown Builder (Spells / Targets)
-- ---------------------------------------------------------------------------
local function BuildSourceBreakdown(set, dmType, guid, creatureID)
    local actor = FindActorInSet(set, guid, creatureID, (type(guid) == "string" and guid) or nil)
    if not actor and (dmType == Enum.DamageMeterType.DamageDone or dmType == Enum.DamageMeterType.HealingDone or dmType == Enum.DamageMeterType.DamageTaken or dmType == Enum.DamageMeterType.AvoidableDamageTaken or dmType == Enum.DamageMeterType.EnemyDamageTaken or dmType == Enum.DamageMeterType.Interrupts or dmType == Enum.DamageMeterType.Dispels or dmType == Enum.DamageMeterType.Deaths) then
        return nil
    end

    local resolvedName = (actor and actor.name) or (guid and tostring(guid)) or "Unknown"
    if actor then actor.name = resolvedName end

    local Skada = GetSkada()
    local setTime = math.max(1, GetSetDuration(set))
    local actorTime = (actor and actor.GetTime and actor:GetTime(set)) or setTime
    local isAbsDamage = Skada and Skada.db and Skada.db.profile and Skada.db.profile.absdamage
    local combatSpells = {}
    local combatTargets = nil

    if dmType == Enum.DamageMeterType.DamageDone then
        local targetsMap = {}
        if actor.damagespells then
            for sidStr, sp in pairs(actor.damagespells) do
                local sid, sname, sicon, sschool = ResolveSpellData(sidStr, false)
                local amt = (isAbsDamage and sp.total) or sp.amount or 0
                if amt > 0 then
                    combatSpells[#combatSpells + 1] = {
                        spellID            = sid,
                        name               = sname,
                        icon               = sicon,
                        spellschool        = sschool,
                        totalAmount        = amt,
                        amountPerSecond    = amt / math.max(1, actorTime),
                        combatSpellDetails = {
                            hits   = sp.hits or 0,
                            crits  = sp.crits or 0,
                            misses = sp.misses or 0,
                        },
                    }
                end
                if sp.targets then
                    for tName, tInfo in pairs(sp.targets) do
                        local tAmt = (isAbsDamage and tInfo.total) or tInfo.amount or 0
                        if tAmt > 0 then
                            targetsMap[tName] = (targetsMap[tName] or 0) + tAmt
                        end
                    end
                end
            end
            table.sort(combatSpells, function(a, b) return a.totalAmount > b.totalAmount end)
        end

        local tList = {}
        for tName, total in pairs(targetsMap) do
            tList[#tList + 1] = {
                name            = tName,
                total           = total,
                amountPerSecond = total / math.max(1, actorTime),
            }
        end
        table.sort(tList, function(a, b) return a.total > b.total end)
        combatTargets = tList

    elseif dmType == Enum.DamageMeterType.HealingDone then
        if actor.healspells then
            for sidStr, sp in pairs(actor.healspells) do
                local sid, sname, sicon, sschool = ResolveSpellData(sidStr, true)
                local amt = sp.amount or 0
                if amt > 0 then
                    combatSpells[#combatSpells + 1] = {
                        spellID            = sid,
                        name               = sname,
                        icon               = sicon,
                        spellschool        = sschool,
                        totalAmount        = amt,
                        amountPerSecond    = amt / math.max(1, actorTime),
                        combatSpellDetails = {
                            hits     = sp.count or sp.hits or 0,
                            crits    = sp.c_num or sp.crits or 0,
                            overheal = sp.o_amt or sp.overheal or 0,
                        },
                    }
                end
            end
        end
        if actor.absorbspells then
            for sidStr, sp in pairs(actor.absorbspells) do
                local sid, sname, sicon, sschool = ResolveSpellData(sidStr, false)
                local amt = sp.amount or 0
                if amt > 0 then
                    combatSpells[#combatSpells + 1] = {
                        spellID            = sid,
                        name               = sname,
                        icon               = sicon,
                        spellschool        = sschool,
                        totalAmount        = amt,
                        amountPerSecond    = amt / math.max(1, actorTime),
                        combatSpellDetails = {
                            hits = sp.count or sp.hits or 0,
                        },
                    }
                end
            end
        end
        table.sort(combatSpells, function(a, b) return a.totalAmount > b.totalAmount end)

    elseif dmType == Enum.DamageMeterType.DamageTaken then
        if actor.damagedspells then
            for sidStr, sp in pairs(actor.damagedspells) do
                local sid, sname, sicon, sschool = ResolveSpellData(sidStr, false)
                local amt = (isAbsDamage and sp.total) or sp.amount or 0
                if amt > 0 then
                    combatSpells[#combatSpells + 1] = {
                        spellID            = sid,
                        name               = sname,
                        icon               = sicon,
                        spellschool        = sschool,
                        totalAmount        = amt,
                        amountPerSecond    = amt / math.max(1, actorTime),
                        combatSpellDetails = {},
                    }
                end
            end
            table.sort(combatSpells, function(a, b) return a.totalAmount > b.totalAmount end)
        end

    elseif dmType == Enum.DamageMeterType.EnemyDamageTaken then
        -- For an enemy, breakdown shows the players that dealt damage to it
        local sources = actor.GetDamageSources and actor:GetDamageSources(set)
        if sources then
            for pName, srcInfo in pairs(sources) do
                local amt = (isAbsDamage and srcInfo.total) or srcInfo.amount or 0
                if amt > 0 then
                    local pClass = srcInfo.class
                    local pSpec = srcInfo.spec
                    combatSpells[#combatSpells + 1] = {
                        spellID            = 135274, -- Default melee/attack icon
                        name               = pName,
                        totalAmount        = amt,
                        amountPerSecond    = amt / setTime,
                        combatSpellDetails = {
                            unitName          = pName,
                            unitClassFilename = pClass,
                            specIconID        = ResolveSpecIcon(pSpec, pClass),
                        },
                    }
                end
            end
            table.sort(combatSpells, function(a, b) return a.totalAmount > b.totalAmount end)
        end

    elseif dmType == Enum.DamageMeterType.Interrupts then
        if actor.interruptspells then
            for sidStr, sp in pairs(actor.interruptspells) do
                local sid, sname, sicon, sschool = ResolveSpellData(sidStr, false)
                local count = (type(sp) == "table" and (sp.count or sp.amount)) or (type(sp) == "number" and sp) or 0
                if count > 0 then
                    combatSpells[#combatSpells + 1] = {
                        spellID            = sid,
                        name               = sname,
                        icon               = sicon,
                        spellschool        = sschool,
                        totalAmount        = count,
                        amountPerSecond    = count / setTime,
                        combatSpellDetails = {},
                    }
                end
            end
            table.sort(combatSpells, function(a, b) return a.totalAmount > b.totalAmount end)
        end

    elseif dmType == Enum.DamageMeterType.Dispels then
        if actor.dispelspells then
            for sidStr, sp in pairs(actor.dispelspells) do
                local sid, sname, sicon, sschool = ResolveSpellData(sidStr, false)
                local count = (type(sp) == "table" and (sp.count or sp.amount)) or (type(sp) == "number" and sp) or 0
                if count > 0 then
                    combatSpells[#combatSpells + 1] = {
                        spellID            = sid,
                        name               = sname,
                        icon               = sicon,
                        spellschool        = sschool,
                        totalAmount        = count,
                        amountPerSecond    = count / setTime,
                        combatSpellDetails = {},
                    }
                end
            end
            table.sort(combatSpells, function(a, b) return a.totalAmount > b.totalAmount end)
        end

    elseif dmType == Enum.DamageMeterType.AvoidableDamageTaken then
        if actor.failspells then
            for sidStr, count in pairs(actor.failspells) do
                local sid, sname, sicon, sschool = ResolveSpellData(sidStr, false)
                local amt = (type(count) == "table" and (count.count or count.amount)) or (type(count) == "number" and count) or 0
                if amt > 0 then
                    combatSpells[#combatSpells + 1] = {
                        spellID            = sid,
                        name               = sname,
                        icon               = sicon,
                        spellschool        = sschool,
                        totalAmount        = amt,
                        amountPerSecond    = amt / setTime,
                        combatSpellDetails = {},
                    }
                end
            end
            table.sort(combatSpells, function(a, b) return a.totalAmount > b.totalAmount end)
        end

    else
        -- Generic mode subview (drilldown / click1)
        local mode = FindSkadaMode(dmType)
        if mode and mode.metadata and mode.metadata.click1 then
            local submode = mode.metadata.click1
            virtualWin:reset()
            virtualWin.selectedset = set
            if submode.metadata then
                for k, v in pairs(submode.metadata) do
                    virtualWin.metadata[k] = v
                end
            end
            local targetID = (actor and actor.id) or guid or resolvedName
            if submode.Enter then
                pcall(submode.Enter, submode, virtualWin, targetID, resolvedName)
            end
            if submode.Update then
                local ok = pcall(submode.Update, submode, virtualWin, set)
                if ok and virtualWin.dataset then
                    for _, d in ipairs(virtualWin.dataset) do
                        if not d.ignore and (d.value or d.valuetext) then
                            local sid = d.spellid or tonumber(d.id) or 0
                            local sname = d.label or tostring(d.id or "Unknown")
                            local val = type(d.value) == "number" and d.value or 0
                            local aps = setTime > 0 and (val / setTime) or 0
                            combatSpells[#combatSpells + 1] = {
                                spellID            = sid,
                                name               = sname,
                                totalAmount        = val,
                                amountPerSecond    = aps,
                                formattedValue     = d.valuetext,
                                icon               = d.icon,
                                combatSpellDetails = {
                                    unitName          = d.label,
                                    unitClassFilename = d.class,
                                    specIconID        = ResolveSpecIcon(d.spec, d.class) or d.icon,
                                },
                            }
                        end
                    end
                    table.sort(combatSpells, function(a, b) return a.totalAmount > b.totalAmount end)
                end
            end
        end
    end

    return {
        name          = resolvedName,
        sourceGUID    = (actor and actor.id) or guid,
        combatSpells  = combatSpells,
        combatTargets = combatTargets,
    }
end

-- ---------------------------------------------------------------------------
--  C_DamageMeter API Implementation
-- ---------------------------------------------------------------------------

function C_DamageMeter.GetSessionDurationSeconds(sessionType)
    local set = GetSetFromType(sessionType)
    return GetSetDuration(set)
end

function C_DamageMeter.GetAvailableCombatSessions()
    local Skada = GetSkada()
    local list = {}
    if not Skada or not Skada.sets then return list end

    for idx, set in ipairs(Skada.sets) do
        list[#list + 1] = {
            sessionID       = idx,
            name            = set.name or ("Segment " .. idx),
            durationSeconds = GetSetDuration(set),
            inProgress      = (set == Skada.current and not set.stopped),
            timestamp       = set.starttime or set.time or 0,
        }
    end

    return list
end

function C_DamageMeter.GetCombatSessionFromType(sessionType, damageMeterType)
    local set = GetSetFromType(sessionType)
    if not set then
        return { durationSeconds = 0, combatSources = {} }
    end
    return {
        durationSeconds = GetSetDuration(set),
        combatSources   = BuildCombatSources(set, damageMeterType),
    }
end

function C_DamageMeter.GetCombatSessionFromID(sessionID, damageMeterType)
    local set = GetSetFromID(sessionID)
    if not set then
        return { durationSeconds = 0, combatSources = {} }
    end
    return {
        durationSeconds = GetSetDuration(set),
        combatSources   = BuildCombatSources(set, damageMeterType),
    }
end

function C_DamageMeter.GetCombatSessionSourceFromType(sessionType, damageMeterType, sourceGUID, sourceCreatureID)
    local set = GetSetFromType(sessionType)
    if not set then return nil end
    return BuildSourceBreakdown(set, damageMeterType, sourceGUID, sourceCreatureID)
end

function C_DamageMeter.GetCombatSessionSourceFromID(sessionID, damageMeterType, sourceGUID, sourceCreatureID)
    local set = GetSetFromID(sessionID)
    if not set then return nil end
    return BuildSourceBreakdown(set, damageMeterType, sourceGUID, sourceCreatureID)
end

function C_DamageMeter.GetCombatSessionSourceTargets(sessionTypeOrID, playerNameOrGUID, maxTargets)
    local set
    if type(sessionTypeOrID) == "number" then
        set = GetSetFromID(sessionTypeOrID) or GetSetFromType(sessionTypeOrID)
    else
        set = GetSetFromType(sessionTypeOrID)
    end
    if not set or not set.actors then return nil end

    local actor = FindActorInSet(set, playerNameOrGUID, nil, playerNameOrGUID)
    if not actor then return nil end

    local Skada = GetSkada()
    local setTime = math.max(1, GetSetDuration(set))
    local actorTime = (actor.GetTime and actor:GetTime(set)) or setTime
    local isAbsDamage = Skada and Skada.db and Skada.db.profile and Skada.db.profile.absdamage

    local targetsMap = {}
    if actor.damagespells then
        for _, sp in pairs(actor.damagespells) do
            if sp.targets then
                for tName, tInfo in pairs(sp.targets) do
                    local amt = (isAbsDamage and tInfo.total) or tInfo.amount or 0
                    if amt > 0 then
                        targetsMap[tName] = (targetsMap[tName] or 0) + amt
                    end
                end
            end
        end
    end

    local list = {}
    for tName, total in pairs(targetsMap) do
        list[#list + 1] = {
            name            = tName,
            total           = total,
            amountPerSecond = total / math.max(1, actorTime),
        }
    end
    table.sort(list, function(a, b) return a.total > b.total end)

    if maxTargets and #list > maxTargets then
        local trimmed = {}
        for i = 1, maxTargets do trimmed[i] = list[i] end
        return trimmed
    end

    return list
end

function C_DamageMeter.ResetAllCombatSessions()
    local Skada = GetSkada()
    if Skada and Skada.Reset then
        Skada:Reset(true)
    end
    wipe(_deathRecaps)
    if EUI and EUI.API and EUI.API.FireEvent then
        EUI.API.FireEvent("DAMAGE_METER_RESET")
    end
end

-- ---------------------------------------------------------------------------
--  Skada Window Suppression & Frame Creation Stub
-- ---------------------------------------------------------------------------
function ns.StubbedSkadaCreateWindow(self, name, db, display)
    -- Stub function: Prevent Skada from creating visual GUI frames / bargroups
    return nil
end

local function StubSkadaCreateWindow()
    local Skada = GetSkada()
    if not Skada then return end

    if not ns.OrigSkadaCreateWindow and Skada.CreateWindow and Skada.CreateWindow ~= ns.StubbedSkadaCreateWindow then
        ns.OrigSkadaCreateWindow = Skada.CreateWindow
    end

    Skada.CreateWindow = ns.StubbedSkadaCreateWindow

    -- Clean up and hide any windows that may already have been created
    if Skada.GetWindows then
        local windows = Skada:GetWindows()
        if windows and #windows > 0 then
            for i = #windows, 1, -1 do
                local win = windows[i]
                if win then
                    if win.Destroy then
                        pcall(win.Destroy, win)
                    elseif win.bargroup and win.bargroup.Hide then
                        pcall(win.bargroup.Hide, win.bargroup)
                    end
                end
                windows[i] = nil
            end
        end
    end
end

local function RestoreSkadaCreateWindow()
    local Skada = GetSkada()
    if not Skada then return end

    if ns.OrigSkadaCreateWindow then
        Skada.CreateWindow = ns.OrigSkadaCreateWindow
    end

    -- Re-create profile windows if Skada is loaded and has window configurations
    if Skada.data and Skada.data.profile and Skada.data.profile.windows then
        local wins = Skada.data.profile.windows
        for i = 1, #wins do
            local win = wins[i]
            if win and Skada.CreateWindow and Skada.CreateWindow ~= ns.StubbedSkadaCreateWindow then
                pcall(Skada.CreateWindow, Skada, win.name, win)
            end
        end
    end
end

function ns.ApplySkadaWindowVisibility()
    local Skada = GetSkada()
    if not Skada then return end

    local hideSkada = true
    if EllesmereUIDamageMetersDB and EllesmereUIDamageMetersDB.profile and EllesmereUIDamageMetersDB.profile.dm then
        if EllesmereUIDamageMetersDB.profile.dm.hideSkadaWindows ~= nil then
            hideSkada = (EllesmereUIDamageMetersDB.profile.dm.hideSkadaWindows == true)
        end
    end

    if hideSkada then
        StubSkadaCreateWindow()
    else
        RestoreSkadaCreateWindow()
    end
end

-- Immediately stub if Skada is already present when this file is evaluated
if _G.Skada and _G.Skada.CreateWindow then
    StubSkadaCreateWindow()
end

-- ---------------------------------------------------------------------------
--  Lifecycle Callbacks & Event Hooks
-- ---------------------------------------------------------------------------
local function HookSkadaCallbacks()
    local Skada = GetSkada()
    if not Skada or type(Skada.RegisterCallback) ~= "function" then return end

    if not ns._skadaCallbacksHooked then
        ns._skadaCallbacksHooked = true

        Skada.RegisterCallback(ns, "Skada_SetCreated", function(_, set)
            wipe(_deathRecaps)
            if EUI and EUI.API and EUI.API.FireEvent then
                EUI.API.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
            end
        end)

        Skada.RegisterCallback(ns, "Skada_SetComplete", function(_, set)
            if EUI and EUI.API and EUI.API.FireEvent then
                EUI.API.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
            end
        end)

        Skada.RegisterCallback(ns, "Skada_DataReset", function()
            wipe(_deathRecaps)
            if EUI and EUI.API and EUI.API.FireEvent then
                EUI.API.FireEvent("DAMAGE_METER_RESET")
            end
        end)
    end
end

-- Initialization frame for Skada hooking and window management
local adapterInit = (EllesmereUI and EllesmereUI.SafeCreateFrame and EllesmereUI.SafeCreateFrame("Frame")) or (CreateFrame and CreateFrame("Frame"))
if adapterInit then
    adapterInit:RegisterEvent("ADDON_LOADED")
    adapterInit:RegisterEvent("PLAYER_LOGIN")
    adapterInit:RegisterEvent("PLAYER_ENTERING_WORLD")
    adapterInit:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 and type(arg1) == "string" and string.lower(arg1) ~= "skada" and string.lower(arg1) ~= "ellesmereuidamagemeters" then
            return
        end
        HookSkadaCallbacks()
        ns.ApplySkadaWindowVisibility()
    end)
end

