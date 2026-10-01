local addon, ns = ...

local pairs, ipairs, type = pairs, ipairs, type
local max, min, floor = math.max, math.min, math.floor
local GetTime = GetTime
local UnitExists = UnitExists
local UnitAura = UnitAura
local UnitGUID = UnitGUID
local GetSpellInfo = GetSpellInfo
local CreateFrame = CreateFrame

local AuraTracker = {}
ns.AuraTracker = AuraTracker

-- Store of learned spell durations: [spellId] = durationSeconds
local learnedDurations = {}

-- Store of aura snapshots by GUID: [guid] = { [key] = auraData }
local guidAuras = {}

-- Store of DR status: [guid] = { [drCategory] = { factor = 1.0, count = 0, resetTime = 0 } }
local guidDR = {}

local DR_RESET_TIME = 18 -- Standard WotLK DR reset window (seconds)

local function DB()
    return (ns.db and ns.db.profile) or ns.defaults or {}
end

local function BuildAuraKey(spellId, casterGUID, isDebuff)
    return (spellId or 0) .. ":" .. (casterGUID or "0") .. ":" .. (isDebuff and "D" or "B")
end

--------------------------------------------------------------------------------
-- Diminishing Returns Tracker
--------------------------------------------------------------------------------
function AuraTracker:GetDRFactor(guid, drType)
    if not guid or not drType then return 1.0 end
    local tracker = guidDR[guid] and guidDR[guid][drType]
    if not tracker then return 1.0 end

    if GetTime() >= tracker.resetTime then
        guidDR[guid][drType] = nil
        return 1.0
    end

    return tracker.factor or 1.0
end

function AuraTracker:ApplyDR(guid, drType)
    if not guid or not drType then return 1.0 end
    if not guidDR[guid] then guidDR[guid] = {} end

    local tracker = guidDR[guid][drType]
    local now = GetTime()

    if not tracker or now >= tracker.resetTime then
        tracker = { count = 1, factor = 1.0, resetTime = now + DR_RESET_TIME }
        guidDR[guid][drType] = tracker
        return 1.0
    end

    tracker.count = tracker.count + 1
    tracker.resetTime = now + DR_RESET_TIME

    if tracker.count == 2 then
        tracker.factor = 0.5
    elseif tracker.count == 3 then
        tracker.factor = 0.25
    else
        tracker.factor = 0
    end

    return tracker.factor
end

--------------------------------------------------------------------------------
-- Duration Learning
--------------------------------------------------------------------------------
function AuraTracker:LearnDuration(spellId, duration)
    if spellId and duration and duration > 0 and duration < 3600 then
        learnedDurations[spellId] = duration
    end
end

function AuraTracker:GetLearnedDuration(spellId)
    return spellId and learnedDurations[spellId]
end

--------------------------------------------------------------------------------
-- UnitAura Authoritative Polling (for verified units)
--------------------------------------------------------------------------------
local function PollUnitAuras(unit, guid)
    if not unit or not guid or not UnitExists(unit) then return end

    local entries = guidAuras[guid]
    if not entries then
        entries = {}
        guidAuras[guid] = entries
    end

    local now = GetTime()
    local seen = {}

    -- Scan Debuffs
    local index = 1
    while true do
        local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellId = UnitAura(unit, index, "HARMFUL")
        if not name then break end

        local casterGUID = unitCaster and UnitGUID(unitCaster) or nil
        local key = BuildAuraKey(spellId or 0, casterGUID, true)
        seen[key] = true

        local aura = entries[key] or {}
        aura.spellId = spellId
        aura.name = name
        aura.icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        aura.count = count or 0
        aura.debuffType = debuffType
        aura.isDebuff = true
        aura.casterGUID = casterGUID

        if duration and duration > 0 then
            aura.duration = duration
            aura.expirationTime = (expirationTime and expirationTime > 0) and expirationTime or (now + duration)
            AuraTracker:LearnDuration(spellId, duration)
        else
            aura.duration = nil
            aura.expirationTime = math.huge
        end

        entries[key] = aura
        index = index + 1
    end

    -- Scan Buffs
    index = 1
    while true do
        local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellId = UnitAura(unit, index, "HELPFUL")
        if not name then break end

        local casterGUID = unitCaster and UnitGUID(unitCaster) or nil
        local key = BuildAuraKey(spellId or 0, casterGUID, false)
        seen[key] = true

        local aura = entries[key] or {}
        aura.spellId = spellId
        aura.name = name
        aura.icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        aura.count = count or 0
        aura.debuffType = debuffType
        aura.isDebuff = false
        aura.casterGUID = casterGUID

        if duration and duration > 0 then
            aura.duration = duration
            aura.expirationTime = (expirationTime and expirationTime > 0) and expirationTime or (now + duration)
            AuraTracker:LearnDuration(spellId, duration)
        else
            aura.duration = nil
            aura.expirationTime = math.huge
        end

        entries[key] = aura
        index = index + 1
    end

    -- Clean expired / removed unit auras
    for key, aura in pairs(entries) do
        if not seen[key] then
            entries[key] = nil
        end
    end
end

function AuraTracker:OnPlateBound(plate, guid, unit)
    if unit and guid then
        PollUnitAuras(unit, guid)
        if plate.UpdateAuras then
            plate:UpdateAuras()
        end
    end
end

--------------------------------------------------------------------------------
-- Plate Aura Query Helper
--------------------------------------------------------------------------------
-- Returns an array of active auras for a plate, sorted by expiration time
local tempAuraList = {}

function AuraTracker:GetAurasForPlate(plate, filterType)
    local guid = plate and plate.guid
    if not guid then return nil, 0 end

    local entries = guidAuras[guid]
    if not entries then return nil, 0 end

    local now = GetTime()
    local n = 0

    for key, aura in pairs(entries) do
        if aura.expirationTime and aura.expirationTime <= now then
            -- Expired
            entries[key] = nil
        else
            local matches = true
            if filterType == "HARMFUL" and not aura.isDebuff then matches = false end
            if filterType == "HELPFUL" and aura.isDebuff then matches = false end

            if matches then
                n = n + 1
                tempAuraList[n] = aura
            end
        end
    end

    -- Clean remainder of recycled array
    for i = n + 1, #tempAuraList do
        tempAuraList[i] = nil
    end

    return tempAuraList, n
end

--------------------------------------------------------------------------------
-- CLEU Combat Log Tracking (3.3.5 Direct Vararg Unpack)
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if not unit or not ns.MatchTracker then return end
        local plate = ns.MatchTracker.unitToPlate[unit]
        if plate and plate.guid then
            PollUnitAuras(unit, plate.guid)
            if plate.UpdateAuras then plate:UpdateAuras() end
        end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- 3.3.5 direct parameter unpack without intermediate tables
        local timestamp, subEvent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags,
              spellId, spellName, spellSchool,
              auraType, amount = ...

        if not destGUID or not ns.MatchTracker then return end

        local plate = ns.MatchTracker:GetPlateByGUID(destGUID)
        if not plate or ns.MatchTracker:IsAmbiguous(plate) then
            -- FAIL-CLOSED: do not snapshot CLEU auras onto ambiguous plates
            return
        end

        local isDebuff = (auraType == "DEBUFF")
        local key = BuildAuraKey(spellId, sourceGUID, isDebuff)
        local entries = guidAuras[destGUID]

        if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
            if not entries then
                entries = {}
                guidAuras[destGUID] = entries
            end

            local now = GetTime()
            local drType = ns.DiminishingReturnsSpells and ns.DiminishingReturnsSpells[spellId]
            local drFactor = drType and AuraTracker:ApplyDR(destGUID, drType) or 1.0

            local baseDuration = AuraTracker:GetLearnedDuration(spellId)
            local duration = nil
            local expiration = math.huge

            if baseDuration and drFactor > 0 then
                duration = baseDuration * drFactor
                expiration = now + duration
            end

            local _, _, icon = GetSpellInfo(spellId)
            local aura = entries[key] or {}
            aura.spellId = spellId
            aura.name = spellName
            aura.icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
            aura.count = (subEvent == "SPELL_AURA_APPLIED_DOSE") and amount or 0
            aura.isDebuff = isDebuff
            aura.casterGUID = sourceGUID
            aura.duration = duration
            aura.expirationTime = expiration

            entries[key] = aura
            if plate.UpdateAuras then plate:UpdateAuras() end

        elseif subEvent == "SPELL_AURA_APPLIED_DOSE" then
            if entries and entries[key] then
                entries[key].count = amount or ((entries[key].count or 0) + 1)
                if plate.UpdateAuras then plate:UpdateAuras() end
            end

        elseif subEvent == "SPELL_AURA_REMOVED" or subEvent == "SPELL_AURA_DISPELLED" then
            if entries and entries[key] then
                entries[key] = nil
                if plate.UpdateAuras then plate:UpdateAuras() end
            end

        elseif subEvent == "UNIT_DIED" then
            guidAuras[destGUID] = nil
            guidDR[destGUID] = nil
            if plate.UpdateAuras then plate:UpdateAuras() end
        end
    end
end)
