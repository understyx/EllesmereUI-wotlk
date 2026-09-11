-------------------------------------------------------------------------------
--  EllesmereUIQoL_AutoLogging.lua
--  Toggles combat logging on zone transitions based on instance type/difficulty.
--  Also forces Advanced Combat Logging on whenever logging starts.
-------------------------------------------------------------------------------

-- Wrath raid difficulty IDs. Both 10- and 25-player variants map to the same
-- user-facing Normal/Heroic trigger.
local RAID_DIFF_KEYS = {
    [3] = "logNormal",  -- 10-player Normal
    [4] = "logNormal",  -- 25-player Normal
    [5] = "logHeroic",  -- 10-player Heroic
    [6] = "logHeroic",  -- 25-player Heroic
}

local TRIGGER_DEFAULTS = {
    logHeroic   = true,
    logNormal   = true,
    logArena    = true,
    delaystop   = true,
}

local function GetTrigger(c, key)
    local v = c[key]
    if v == nil then return TRIGGER_DEFAULTS[key] end
    return v
end

local function Cfg()
    if not EllesmereUIDB then return {} end
    EllesmereUIDB.autoLogging = EllesmereUIDB.autoLogging or {}
    return EllesmereUIDB.autoLogging
end

-- Silently sets advancedCombatLogging if it isn't already on.
local function EnsureAdvancedLogging()
    if GetCVar and GetCVar("advancedCombatLogging") ~= "1" then
        SetCVar("advancedCombatLogging", 1)
    end
end

local function ZoneShouldBeLogged()
    local c = Cfg()
    if not c.enabled then return false end

    local _, zoneType, rawDiff = GetInstanceInfo()
    local diff  = tonumber(rawDiff)
    if not diff then return false end

    if zoneType == "raid" then
        local key = RAID_DIFF_KEYS[diff]
        if key then return GetTrigger(c, key) end
        return false
    end

    if GetTrigger(c, "logArena") and (zoneType == "arena" or zoneType == "ratedarena") then
        return true
    end

    return false
end

local STOP_DELAY_SECONDS = 30

local wasLogging = false
local _stopTimer  = nil

local function CancelStopTimer()
    if _stopTimer then _stopTimer:Cancel(); _stopTimer = nil end
end

local function ApplyLoggingState()
    local shouldLog = ZoneShouldBeLogged()
    if shouldLog then
        CancelStopTimer()
        EnsureAdvancedLogging()
        LoggingCombat(true)
    elseif wasLogging and LoggingCombat() then
        local c = Cfg()
        local delay = GetTrigger(c, "delaystop")
        if delay and not _stopTimer then
            _stopTimer = C_Timer.NewTimer(STOP_DELAY_SECONDS, function()
                _stopTimer = nil
                if LoggingCombat() then LoggingCombat(false) end
            end)
        elseif not delay then
            LoggingCombat(false)
        end
    end
    wasLogging = shouldLog
end

local events = {
    ZONE_CHANGED_NEW_AREA = function() C_Timer.After(2, ApplyLoggingState) end,
}

-- Zone events are registered only while the feature is enabled, so a disabled
-- feature costs nothing on zone changes. The options toggle calls
-- _EUI_AutoLogging_Check, which re-syncs registration AND applies the logging
-- state immediately (disabling mid-instance still stops an active log).
local logFrame = EllesmereUI.SafeCreateFrame("Frame")
local _eventsRegistered = false
local function SyncEventRegistration()
    local want = Cfg().enabled and true or false
    if want == _eventsRegistered then return end
    _eventsRegistered = want
    for ev in pairs(events) do
        if want then logFrame:RegisterEvent(ev) else logFrame:UnregisterEvent(ev) end
    end
end

_G._EUI_AutoLogging_Check = function()
    SyncEventRegistration()
    ApplyLoggingState()
end

logFrame:RegisterEvent("PLAYER_LOGIN")
logFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        SyncEventRegistration()
        C_Timer.After(2, ApplyLoggingState)
    elseif events[event] then
        events[event]()
    end
end)
