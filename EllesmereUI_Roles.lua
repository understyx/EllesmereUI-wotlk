-------------------------------------------------------------------------------
-- EllesmereUI_Roles.lua
-- Shared group-role resolver for legacy clients. Blizzard's assigned-role API
-- commonly returns NONE on 3.3.5, so talent inspection fills that gap. Every
-- consumer (role icons, threat-transfer QoL, and future features) goes through
-- this file so manual overrides and fallback rules stay consistent.
-------------------------------------------------------------------------------

local EUI = EllesmereUI
if not EUI then return end

local RoleDetector = EUI.RoleDetector or {}
EUI.RoleDetector = RoleDetector

local LGT = LibStub and LibStub:GetLibrary("LibGroupTalents-1.0", true)
local callbacks = RoleDetector._callbacks or {}
RoleDetector._callbacks = callbacks

local ROLE_MAP = {
    tank = "TANK",
    healer = "HEALER",
    melee = "DAMAGER",
    caster = "DAMAGER",
    damager = "DAMAGER",
    dps = "DAMAGER",
    TANK = "TANK",
    HEALER = "HEALER",
    DAMAGER = "DAMAGER",
}

local PURE_DPS = {
    HUNTER = true,
    MAGE = true,
    ROGUE = true,
    WARLOCK = true,
}

local function NormalizeRole(role)
    if type(role) ~= "string" then return nil end
    return ROLE_MAP[role] or ROLE_MAP[string.lower(role)]
end

local function UnitFullName(unit)
    local name, realm = UnitName(unit)
    if not name then return nil end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function NameKey(name)
    if not name or name == "" then return nil end
    return "n:" .. string.lower(name)
end

local function GUIDKey(guid)
    return guid and ("g:" .. guid) or nil
end

local function OverrideTable(create)
    if not EllesmereUIDB then
        if not create then return nil end
        EllesmereUIDB = {}
    end
    if create and not EllesmereUIDB.roleOverrides then
        EllesmereUIDB.roleOverrides = {}
    end
    return EllesmereUIDB.roleOverrides
end

local function Notify(unit, guid, role)
    for i = 1, #callbacks do
        local fn = callbacks[i]
        if fn then pcall(fn, unit, guid, role) end
    end
end

function RoleDetector:RegisterCallback(fn)
    if type(fn) ~= "function" then return end
    for i = 1, #callbacks do
        if callbacks[i] == fn then return end
    end
    callbacks[#callbacks + 1] = fn
end

function RoleDetector:UnregisterCallback(fn)
    for i = #callbacks, 1, -1 do
        if callbacks[i] == fn then table.remove(callbacks, i) end
    end
end

function RoleDetector:GetOverride(unit)
    if not unit or not UnitExists(unit) then return nil end
    local overrides = OverrideTable(false)
    if not overrides then return nil end
    local guid = UnitGUID(unit)
    local role = guid and overrides[GUIDKey(guid)]
    if not role then role = overrides[NameKey(UnitFullName(unit))] end
    return NormalizeRole(role)
end

function RoleDetector:GetOverrideByGUID(guid)
    local overrides = OverrideTable(false)
    return overrides and NormalizeRole(overrides[GUIDKey(guid)]) or nil
end

-- Set a persistent override for a live unit. Passing nil/"AUTO" clears it.
function RoleDetector:SetOverride(unit, role)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit)
        or not UnitIsFriend("player", unit) then return false end
    role = NormalizeRole(role)
    local overrides = OverrideTable(true)
    local guid, name = UnitGUID(unit), UnitFullName(unit)
    local gk, nk = GUIDKey(guid), NameKey(name)
    if gk then overrides[gk] = role end
    if nk then overrides[nk] = role end
    Notify(unit, guid, role)
    return true
end

local function FindUnitByGUID(guid)
    if not guid then return nil end
    local direct = { "player", "target", "focus", "mouseover", "pet" }
    for i = 1, #direct do
        if UnitGUID(direct[i]) == guid then return direct[i] end
    end
    local raidN = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, raidN do
        local unit = "raid" .. i
        if UnitGUID(unit) == guid then return unit end
    end
    local partyN = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, partyN do
        local unit = "party" .. i
        if UnitGUID(unit) == guid then return unit end
        local pet = "partypet" .. i
        if UnitGUID(pet) == guid then return pet end
    end
    return nil
end

-- Returns ROLE, SOURCE. Source is useful in tooltips/debugging and is one of
-- override, assigned, talents, class, or unknown.
function RoleDetector:GetRole(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return "NONE", "unknown"
    end

    local override = self:GetOverride(unit)
    if override then return override, "override" end

    if UnitGroupRolesAssigned then
        local assigned = UnitGroupRolesAssigned(unit)
        assigned = NormalizeRole(assigned)
        if assigned then return assigned, "assigned" end
    end

    if LGT then
        local detected = NormalizeRole(LGT:GetUnitRole(unit))
        if detected then return detected, "talents" end
    end

    local _, class = UnitClass(unit)
    if PURE_DPS[class] then return "DAMAGER", "class" end
    return "NONE", "unknown"
end

function RoleDetector:GetRoleByGUID(guid)
    local override = self:GetOverrideByGUID(guid)
    if override then return override, "override" end
    local unit = FindUnitByGUID(guid)
    if unit then return self:GetRole(unit) end
    return "NONE", "unknown"
end

function RoleDetector:Refresh(unit)
    if LGT and unit and UnitExists(unit) and UnitIsPlayer(unit) then
        LGT:GetUnitTalents(unit, true)
    end
    Notify(unit, unit and UnitGUID(unit), unit and self:GetRole(unit))
end

-- Talent results arrive asynchronously. Broadcast their completion so visual
-- consumers repaint without waiting for another roster or aura event.
if LGT and LGT.RegisterCallback then
    LGT.RegisterCallback(RoleDetector, "LibGroupTalents_RoleChange", function(_, guid, unit)
        Notify(unit, guid, unit and RoleDetector:GetRole(unit))
    end)
    LGT.RegisterCallback(RoleDetector, "LibGroupTalents_Update", function(_, guid, unit)
        Notify(unit, guid, unit and RoleDetector:GetRole(unit))
    end)
end

local eventFrame = EUI.SafeCreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TALENT_UPDATE" then
        RoleDetector:Refresh("player")
    else
        Notify(nil, nil, nil)
    end
end)

-- Add role overrides to the normal unit context menu used by EUI party/raid
-- frames. Selecting the currently active override again clears it and returns
-- that player to automatic detection, keeping the submenu to the requested
-- three direct choices.
do
    local ROOT = "EUI_ROLE_OVERRIDE"
    local CHOICES = {
        { key = "EUI_ROLE_TANK", role = "TANK", text = "Tank" },
        { key = "EUI_ROLE_DAMAGER", role = "DAMAGER", text = "DPS" },
        { key = "EUI_ROLE_HEALER", role = "HEALER", text = "Healer" },
    }
    local ROLE_BY_BUTTON = {}
    for i = 1, #CHOICES do ROLE_BY_BUTTON[CHOICES[i].key] = CHOICES[i].role end

    local function AddBeforeCancel(menu, value)
        if not menu then return end
        for i = 1, #menu do if menu[i] == value then return end end
        local at = #menu + 1
        for i = 1, #menu do
            if menu[i] == "CANCEL" then at = i; break end
        end
        table.insert(menu, at, value)
    end

    local function InstallUnitPopupEntries()
        if EUI._rolePopupInstalled or not UnitPopupButtons or not UnitPopupMenus then return end
        EUI._rolePopupInstalled = true

        UnitPopupButtons[ROOT] = {
            text = "Override Role",
            dist = 0,
            nested = 1,
            tooltipText = "Choose the role EllesmereUI should use for this player. Select the active role again to return to automatic detection.",
        }
        UnitPopupMenus[ROOT] = {}
        for i = 1, #CHOICES do
            local choice = CHOICES[i]
            UnitPopupButtons[choice.key] = {
                text = choice.text,
                dist = 0,
                checkable = 1,
                tooltipText = "Select again to return this player to automatic role detection.",
            }
            UnitPopupMenus[ROOT][i] = choice.key
        end

        -- Friendly group menus, including the player's own frame. This makes
        -- the same override available from EUI raid/party frames and any other
        -- unit frame that opens Blizzard's standard group context menu.
        AddBeforeCancel(UnitPopupMenus.SELF, ROOT)
        AddBeforeCancel(UnitPopupMenus.PARTY, ROOT)
        AddBeforeCancel(UnitPopupMenus.RAID_PLAYER, ROOT)

        hooksecurefunc("UnitPopup_ShowMenu", function(dropdown)
            if UIDROPDOWNMENU_MENU_LEVEL ~= 2 or UIDROPDOWNMENU_MENU_VALUE ~= ROOT then return end
            local override = dropdown and dropdown.unit and RoleDetector:GetOverride(dropdown.unit)
            for i = 1, #CHOICES do
                local row = _G["DropDownList2Button" .. i]
                if row then row._euiRoleUnit = dropdown and dropdown.unit end
                if UIDropDownMenu_UncheckButton then UIDropDownMenu_UncheckButton(2, i) end
                if override == CHOICES[i].role and UIDropDownMenu_CheckButton then
                    UIDropDownMenu_CheckButton(2, i)
                end
            end
        end)

        hooksecurefunc("UnitPopup_OnClick", function(button)
            local role = button and ROLE_BY_BUTTON[button.value]
            if not role then return end
            local dropdown = UIDROPDOWNMENU_INIT_MENU
            local unit = button._euiRoleUnit or (dropdown and dropdown.unit)
            if not unit then return end
            local current = RoleDetector:GetOverride(unit)
            if current == role then
                RoleDetector:SetOverride(unit, nil)
            else
                RoleDetector:SetOverride(unit, role)
            end
        end)
    end

    InstallUnitPopupEntries()
end
