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
local UnitIsUnit = UnitIsUnit
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

-- Name and level are the only stable identity fields exposed by anonymous
-- 3.3.5 nameplates. Health is intentionally excluded from ambiguity checks:
-- native bar values and UnitHealth update on different frames, so damage can
-- make the wrong identical plate look temporarily unique.
local function PlateIdentityMatches(plate, unit)
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

    return true
end

local function PlateMatchesUnit(plate, unit)
    if not PlateIdentityMatches(plate, unit) then return false end

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
    local oldGuid = plate.guid

    for unit, owner in pairs(self.unitToPlate) do
        if owner == plate then
            self.unitToPlate[unit] = nil
        end
    end
    if oldGuid and self.guidToPlate[oldGuid] == plate then
        self.guidToPlate[oldGuid] = nil
    end

    plate.unit = nil
    plate.guid = nil
    plate.isAmbiguous = false

    -- A GUID can be invalidated while its physical plate remains visible
    -- (for example when authoritative mouseover evidence repairs an older
    -- bad association). Remove its aura display immediately.
    if oldGuid and plate.UpdateAuras then plate:UpdateAuras() end
end

local function RefreshPrimaryUnit(self, plate)
    if not plate then return end
    local preferred = { "target", "focus", "mouseover" }
    for _, unit in ipairs(preferred) do
        if self.unitToPlate[unit] == plate then
            plate.unit = unit
            return
        end
    end
    for unit, owner in pairs(self.unitToPlate) do
        if owner == plate then
            plate.unit = unit
            return
        end
    end
    plate.unit = nil
end

function MatchTracker:ReleaseUnit(unit)
    local plate = unit and self.unitToPlate[unit]
    if not plate then return end
    self.unitToPlate[unit] = nil
    RefreshPrimaryUnit(self, plate)
end

function MatchTracker:BindPlateGUID(plate, guid, unit)
    if not plate or not guid then return false end

    -- If another shown plate already claims this GUID, ensure no conflict
    local existing = self.guidToPlate[guid]
    if existing and existing ~= plate and PlateIsShown(existing) then
        return false
    end

    if plate.guid and plate.guid ~= guid then
        -- A visible anonymous plate keeps its established identity. Rebinding
        -- it during the one-frame target/alpha transition would clone the new
        -- unit's casts and auras onto the old physical plate. Frame recycling
        -- goes through OnHide, which clears the GUID safely.
        if PlateIsShown(plate) then return false end
        if self.guidToPlate[plate.guid] == plate then self.guidToPlate[plate.guid] = nil end
    end

    plate.guid = guid
    self.guidToPlate[guid] = plate
    plate.isAmbiguous = false

    if unit then
        local previous = self.unitToPlate[unit]
        if previous and previous ~= plate then
            self.unitToPlate[unit] = nil
            RefreshPrimaryUnit(self, previous)
        end
        self.unitToPlate[unit] = plate
        RefreshPrimaryUnit(self, plate)
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

-- Mouseover plus one unique physical hit-test is the only WotLK signal that
-- identifies an otherwise identical plate directly. It is strong enough to
-- repair a stale association instead of allowing KnownGUID to make the bad
-- mapping permanent.
function MatchTracker:BindAuthoritativePlateGUID(plate, guid, unit)
    if not plate or not guid then return false end

    local existing = self.guidToPlate[guid]
    if existing and existing ~= plate then
        self:ClearPlateMatch(existing)
    end
    if plate.guid and plate.guid ~= guid then
        self:ClearPlateMatch(plate)
    end

    return self:BindPlateGUID(plate, guid, unit)
end

function MatchTracker:IsTarget(plate)
    if not UnitExists("target") then return false end
    if self.unitToPlate["target"] == plate then return true end
    local targetGUID = UnitGUID("target")
    if targetGUID and plate.guid == targetGUID then return true end
    return false
end

function MatchTracker:IsMouseover(plate)
    if not UnitExists("mouseover") then return false end
    if self.unitToPlate["mouseover"] == plate then return true end
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
    if self.unitToPlate["focus"] == plate then return true end
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
    local function UniqueIdentity(unit)
        local candidate, count
        count = 0
        for plate in pairs(self.plates) do
            if PlateIsShown(plate) and PlateIdentityMatches(plate, unit) then
                candidate = plate
                count = count + 1
            end
        end
        return count == 1 and candidate and PlateMatchesUnit(candidate, unit)
            and candidate or nil
    end

    local function KnownGUID(unit)
        local guid = UnitGUID(unit)
        local plate = guid and self.guidToPlate[guid]
        return plate and PlateIsShown(plate) and plate or nil
    end

    local targetOwner, mouseoverOwner, focusOwner

    if UnitExists("mouseover") then
        local hovered, hoverCount = nil, 0
        for plate in pairs(self.plates) do
            -- Native highlight visibility can lag UPDATE_MOUSEOVER_UNIT by a
            -- frame. A unique physical hit-test does not make that stale-frame
            -- guess and fails closed when overlapping hit boxes both match.
            if PlateIsShown(plate) and PlateNameMatches(plate, "mouseover")
                and plate.frame and MouseIsOver(plate.frame) then
                hovered = plate
                hoverCount = hoverCount + 1
            end
        end
        if hoverCount == 1 and hovered then
            local mouseoverGUID = UnitGUID("mouseover")
            if mouseoverGUID then
                self:BindAuthoritativePlateGUID(hovered, mouseoverGUID, "mouseover")
            end
            mouseoverOwner = hovered
        else
            mouseoverOwner = KnownGUID("mouseover") or UniqueIdentity("mouseover")
        end
    end

    if UnitExists("target") then
        if UnitIsUnit and mouseoverOwner
            and UnitExists("mouseover") and UnitIsUnit("target", "mouseover") then
            targetOwner = mouseoverOwner
        end
        -- Never infer identity from root alpha or a momentarily unique health
        -- value. Duplicate name/level identities stay unresolved unless direct
        -- mouseover evidence (or an existing verified GUID) identifies them.
        targetOwner = targetOwner or KnownGUID("target") or UniqueIdentity("target")
    end

    if UnitExists("focus") then
        focusOwner = KnownGUID("focus")
        if not focusOwner and UnitIsUnit and targetOwner and UnitIsUnit("focus", "target") then
            focusOwner = targetOwner
        elseif not focusOwner and UnitIsUnit and mouseoverOwner
            and UnitExists("mouseover") and UnitIsUnit("focus", "mouseover") then
            focusOwner = mouseoverOwner
        end
        focusOwner = focusOwner or UniqueIdentity("focus")
    end

    local function ApplyOwner(unit, owner)
        local current = self.unitToPlate[unit]
        if current ~= owner then
            if current then self:ReleaseUnit(unit) end
            if owner then self:BindPlateGUID(owner, UnitGUID(unit), unit) end
        end
    end
    ApplyOwner("target", targetOwner)
    ApplyOwner("mouseover", mouseoverOwner)
    ApplyOwner("focus", focusOwner)
end

-- Scan group target tokens with fail-closed ambiguity guard
function MatchTracker:UpdateGroupUnits()
    for _, unit in ipairs(GROUP_UNITS) do
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            local uGUID = UnitGUID(unit)
            local current = self.unitToPlate[unit]
            if current and current.guid ~= uGUID then self:ReleaseUnit(unit) end
            local known = uGUID and self.guidToPlate[uGUID]
            if known and PlateIsShown(known) then
                self:BindPlateGUID(known, uGUID, unit)
            elseif uGUID then
                -- Count every visible plate with the same stable identity.
                -- Do not let asynchronous health changes make one identical
                -- plate look unique, even if another candidate is already
                -- bound through a different token.
                local candidate = nil
                local count = 0
                for plate in pairs(self.plates) do
                    if PlateIsShown(plate) and PlateIdentityMatches(plate, unit) then
                        count = count + 1
                        candidate = plate
                    end
                end

                if count == 1 and candidate and not candidate.guid
                    and PlateMatchesUnit(candidate, unit) then
                    -- Unambiguous unique match: bind safely
                    self:BindPlateGUID(candidate, uGUID, unit)
                elseif count > 1 then
                    -- Multiple candidates share the same stats: FAIL CLOSED
                    for plate in pairs(self.plates) do
                        if PlateIsShown(plate) and not plate.guid
                            and PlateIdentityMatches(plate, unit) then
                            plate.isAmbiguous = true
                        end
                    end
                end
            end
        else
            self:ReleaseUnit(unit)
        end
    end
end

function MatchTracker:OnPlateShow(plate)
    self:ClearPlateMatch(plate)
    -- SkinPlate discovers already-visible WorldFrame children one at a time.
    -- Resolving here would let the first of several identical plates look
    -- unique before the rest have been registered. The main driver consumes
    -- this flag only after the complete WorldFrame scan.
    self.pendingFullUpdate = true
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
