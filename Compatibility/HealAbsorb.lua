-- Wrath health-prediction data bridge.
--
-- Retail exposes incoming heals and absorbs through UnitGet* APIs and UNIT_*
-- events.  Wrath has neither, so LibHealComm and SpecializedAbsorbs provide
-- the values and this bridge gives the rest of EUI one version-neutral API.

local tracker = _G.EllesmereUIHealAbsorb or {}
_G.EllesmereUIHealAbsorb = tracker

local healComm = LibStub and LibStub("LibHealComm-4.0", true)
local absorbs = LibStub and LibStub("SpecializedAbsorbs-1.0", true)
local listeners = tracker.listeners or setmetatable({}, { __mode = "k" })
tracker.listeners = listeners
tracker.isLegacy = not (_G.UnitGetIncomingHeals and _G.UnitGetTotalAbsorbs)

function tracker.GetIncomingHeals(unit, casterGUID)
    if not healComm or not unit then return 0 end
    local guid = UnitGUID(unit)
    if not guid then return 0 end
    return healComm:GetHealAmount(guid, healComm.ALL_HEALS, nil, casterGUID) or 0
end

function tracker.GetAbsorbs(unit)
    if not absorbs or not unit then return 0 end
    local guid = UnitGUID(unit)
    return guid and absorbs.UnitTotal(guid) or 0
end

function tracker.GetHealAbsorbs(unit)
    if not absorbs or not unit then return 0 end
    local guid = UnitGUID(unit)
    return guid and (absorbs.UnitTotalHealAbsorbs(guid) or 0) or 0
end

function tracker.Register(owner, callback)
    if owner and callback then listeners[owner] = callback end
end

function tracker.Unregister(owner)
    listeners[owner] = nil
end

local function Notify(guid, change)
    if not guid then return end
    for owner, callback in pairs(listeners) do
        local ok, err = pcall(callback, owner, guid, change)
        if not ok then geterrorhandler()(err) end
    end
end

if tracker.isLegacy then
    _G.UnitGetIncomingHeals = tracker.GetIncomingHeals
    _G.UnitGetTotalAbsorbs = tracker.GetAbsorbs
    _G.UnitGetTotalHealAbsorbs = tracker.GetHealAbsorbs

    if healComm then
        local function HealChanged(_, _, _, _, _, ...)
            for i = 1, select("#", ...) do Notify(select(i, ...), "HEAL") end
        end
        local function HealModifierChanged(_, guid) Notify(guid, "HEAL") end
        healComm.RegisterCallback(tracker, "HealComm_HealStarted", HealChanged)
        healComm.RegisterCallback(tracker, "HealComm_HealUpdated", HealChanged)
        healComm.RegisterCallback(tracker, "HealComm_HealDelayed", HealChanged)
        healComm.RegisterCallback(tracker, "HealComm_HealStopped", HealChanged)
        healComm.RegisterCallback(tracker, "HealComm_ModifierChanged", HealModifierChanged)
        healComm.RegisterCallback(tracker, "HealComm_GUIDDisappeared", HealModifierChanged)
    end

    if absorbs then
        absorbs.RegisterCallback(tracker, "UnitUpdated", function(_, guid) Notify(guid, "ABSORB") end)
        absorbs.RegisterCallback(tracker, "UnitCleared", function(_, guid) Notify(guid, "ABSORB") end)
        absorbs.RegisterCallback(tracker, "HealAbsorbUpdated", function(_, guid) Notify(guid, "HEAL_ABSORB") end)
    end
end
