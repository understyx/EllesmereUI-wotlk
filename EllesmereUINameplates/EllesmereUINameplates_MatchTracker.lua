local addon, ns = ...

local pairs, ipairs, type = pairs, ipairs, type
local abs = math.abs
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAttack = UnitCanAttack
local MouseIsOver = MouseIsOver
local GetTime = GetTime

local MatchTracker = {}
ns.MatchTracker = MatchTracker

-- Registries
MatchTracker.plates = {}            -- [plate] = true
MatchTracker.guidToPlate = {}       -- [guid] = plate
MatchTracker.unitToPlate = {}       -- [unit] = plate

-- Static unit tokens list to scan in priority order
local SPECIAL_UNITS = { "target", "focus", "mouseover" }
local GROUP_UNITS = {}
for i = 1, 4 do
    GROUP_UNITS[#GROUP_UNITS + 1] = "party" .. i .. "target"
end
for i = 1, 40 do
    GROUP_UNITS[#GROUP_UNITS + 1] = "raid" .. i .. "target"
end
for i = 1, 5 do
    GROUP_UNITS[#GROUP_UNITS + 1] = "arena" .. i .. "target"
    GROUP_UNITS[#GROUP_UNITS + 1] = "arena" .. i
end

local function PlateIsShown(plate)
    if not plate then return false end
    if plate.frame and plate.frame.IsShown then
        return plate.frame:IsShown() and true or false
    end
    if plate.IsShown then
        return plate:IsShown() and true or false
    end
    return false
end

local function PlateNameMatches(plate, unit)
    if not UnitExists(unit) then return false end
    local pName = plate:GetNameText()
    local uName = UnitName(unit)
    return pName and uName and pName == uName
end

local function PlateMatchesUnit(plate, unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) then return false end
    if not PlateNameMatches(plate, unit) then return false end

    -- Check level if available
    local pLevel = plate:GetLevelText()
    if pLevel and pLevel ~= "" and pLevel ~= "??" then
        local uLevel = UnitLevel(unit)
        local uLevelStr = (uLevel and uLevel > 0) and tostring(uLevel) or nil
        if uLevelStr and pLevel ~= uLevelStr then
            return false
        end
    end

    -- Health comparison
    local pHealth, pMax = plate:GetHealthValues()
    local uHealth = UnitHealth(unit)
    local uMax = UnitHealthMax(unit)

    if pMax and pMax > 0 and uMax and uMax > 0 then
        if abs(pMax - uMax) < 1 and abs(pHealth - uHealth) < 1 then
            return true
        end
        return abs((pHealth / pMax) - (uHealth / uMax)) < 0.015
    end

    return true
end

function MatchTracker:RegisterPlate(plate)
    if not plate then return end
    self.plates[plate] = true
end

function MatchTracker:UnregisterPlate(plate)
    if not plate then return end
    self:ClearPlateMatch(plate)
    self.plates[plate] = nil
end

function MatchTracker:ClearPlateMatch(plate)
    if not plate then return end
    local oldUnit = plate.unit
    local oldGuid = plate.guid

    if oldUnit and self.unitToPlate[oldUnit] == plate then
        self.unitToPlate[oldUnit] = nil
    end
    if oldGuid and self.guidToPlate[oldGuid] == plate then
        self.guidToPlate[oldGuid] = nil
    end

    plate.unit = nil
    plate.guid = nil
    plate.isAmbiguous = false
end

function MatchTracker:BindPlateGUID(plate, guid, unit)
    if not plate or not guid then return false end

    -- If another shown plate already claims this GUID, ensure no conflict
    local existing = self.guidToPlate[guid]
    if existing and existing ~= plate and PlateIsShown(existing) then
        return false
    end

    if plate.guid and plate.guid ~= guid then
        -- Frame was bound to a different GUID; release old
        if self.guidToPlate[plate.guid] == plate then
            self.guidToPlate[plate.guid] = nil
        end
    end

    plate.guid = guid
    self.guidToPlate[guid] = plate
    plate.isAmbiguous = false

    if unit then
        if plate.unit and plate.unit ~= unit and self.unitToPlate[plate.unit] == plate then
            self.unitToPlate[plate.unit] = nil
        end
        plate.unit = unit
        self.unitToPlate[unit] = plate
    end

    -- Notify modules (Cast, Aura) of confirmed GUID binding
    if ns.AuraTracker and ns.AuraTracker.OnPlateBound then
        ns.AuraTracker:OnPlateBound(plate, guid, unit)
    end
    if ns.Cast and ns.Cast.OnPlateBound then
        ns.Cast:OnPlateBound(plate, guid, unit)
    end

    return true
end

function MatchTracker:IsTarget(plate)
    if not UnitExists("target") then return false end
    if plate.unit == "target" then return true end
    local targetGUID = UnitGUID("target")
    if targetGUID and plate.guid == targetGUID then return true end
    if plate.frame and plate.frame:GetAlpha() >= 0.99 then
        local pName = plate:GetNameText()
        if pName and pName == UnitName("target") then
            return true
        end
    end
    return false
end

function MatchTracker:IsMouseover(plate)
    if not UnitExists("mouseover") then return false end
    if plate.unit == "mouseover" then return true end
    local mouseoverGUID = UnitGUID("mouseover")
    if mouseoverGUID and plate.guid == mouseoverGUID then return true end
    if plate.nativeHighlight and plate.nativeHighlight:IsShown() then
        return true
    end
    if plate.frame and MouseIsOver(plate.frame) then
        return true
    end
    return false
end

function MatchTracker:IsFocus(plate)
    if not UnitExists("focus") then return false end
    if plate.unit == "focus" then return true end
    local focusGUID = UnitGUID("focus")
    if focusGUID and plate.guid == focusGUID then return true end
    return false
end

function MatchTracker:GetPlateByGUID(guid)
    if not guid then return nil end
    local plate = self.guidToPlate[guid]
    if plate and PlateIsShown(plate) then
        return plate
    end
    return nil
end

function MatchTracker:GetGUID(plate)
    return plate and plate.guid
end

function MatchTracker:GetUnit(plate)
    return plate and plate.unit
end

function MatchTracker:IsAmbiguous(plate)
    return plate and (plate.isAmbiguous == true)
end

-- Resolve active special tokens (target, mouseover, focus) with physical certainty
function MatchTracker:UpdateSpecialUnits()
    -- 1. Target
    if UnitExists("target") then
        local targetGUID = UnitGUID("target")
        for plate in pairs(self.plates) do
            if PlateIsShown(plate) and self:IsTarget(plate) then
                self:BindPlateGUID(plate, targetGUID, "target")
                break
            end
        end
    else
        if self.unitToPlate["target"] then
            local p = self.unitToPlate["target"]
            if p.unit == "target" then p.unit = nil end
            self.unitToPlate["target"] = nil
        end
    end

    -- 2. Mouseover
    if UnitExists("mouseover") then
        local mouseoverGUID = UnitGUID("mouseover")
        for plate in pairs(self.plates) do
            if PlateIsShown(plate) and self:IsMouseover(plate) then
                self:BindPlateGUID(plate, mouseoverGUID, "mouseover")
                break
            end
        end
    else
        if self.unitToPlate["mouseover"] then
            local p = self.unitToPlate["mouseover"]
            if p.unit == "mouseover" then p.unit = nil end
            self.unitToPlate["mouseover"] = nil
        end
    end

    -- 3. Focus
    if UnitExists("focus") then
        local focusGUID = UnitGUID("focus")
        for plate in pairs(self.plates) do
            if PlateIsShown(plate) and PlateMatchesUnit(plate, "focus") then
                self:BindPlateGUID(plate, focusGUID, "focus")
                break
            end
        end
    else
        if self.unitToPlate["focus"] then
            local p = self.unitToPlate["focus"]
            if p.unit == "focus" then p.unit = nil end
            self.unitToPlate["focus"] = nil
        end
    end
end

-- Scan group target tokens with fail-closed ambiguity guard
function MatchTracker:UpdateGroupUnits()
    for _, unit in ipairs(GROUP_UNITS) do
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            local uGUID = UnitGUID(unit)
            if uGUID and not self.guidToPlate[uGUID] then
                -- Count candidate plates matching this unit
                local candidate = nil
                local count = 0
                for plate in pairs(self.plates) do
                    if PlateIsShown(plate) and not plate.guid and PlateMatchesUnit(plate, unit) then
                        count = count + 1
                        candidate = plate
                    end
                end

                if count == 1 and candidate then
                    -- Unambiguous unique match: bind safely
                    self:BindPlateGUID(candidate, uGUID, unit)
                elseif count > 1 then
                    -- Multiple candidates share the same stats: FAIL CLOSED
                    for plate in pairs(self.plates) do
                        if PlateIsShown(plate) and not plate.guid and PlateMatchesUnit(plate, unit) then
                            plate.isAmbiguous = true
                        end
                    end
                end
            end
        end
    end
end

function MatchTracker:OnPlateShow(plate)
    self:ClearPlateMatch(plate)
    self:UpdateSpecialUnits()
end

function MatchTracker:OnPlateHide(plate)
    self:ClearPlateMatch(plate)
end

function MatchTracker:UpdateAll()
    self:UpdateSpecialUnits()
    self:UpdateGroupUnits()
end

--------------------------------------------------------------------------------
-- Event Frame for State Changes
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("UNIT_TARGET")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, unitId)
    if event == "PLAYER_TARGET_CHANGED" then
        MatchTracker:UpdateSpecialUnits()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        MatchTracker:UpdateSpecialUnits()
    elseif event == "PLAYER_FOCUS_CHANGED" then
        MatchTracker:UpdateSpecialUnits()
    elseif event == "UNIT_TARGET" then
        MatchTracker:UpdateGroupUnits()
    elseif event == "PLAYER_ENTERING_WORLD" then
        MatchTracker:UpdateAll()
    end
end)
