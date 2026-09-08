-------------------------------------------------------------------------------
--  EUI_PallyPower_Options.lua
--  Native settings for the EllesmereUI PallyPower module.
--
--  Runtime functionality is published as EllesmereUI.PallyPower so sibling
--  modules can consume blessing state without reaching into addon globals.
-------------------------------------------------------------------------------

local EllesmereUI = _G.EllesmereUI
if not EllesmereUI then return end

local registered = false

local function PP()
    local addon = EllesmereUI.PallyPower
    if addon and addon.opt then return addon end
end

local function RefreshLayout()
    local addon = PP()
    if not addon or not addon.UpdateLayout then return end
    if InCombatLockdown and InCombatLockdown() then return end
    addon:UpdateLayout()
end

local function Get(path1, path2, fallback)
    local addon = PP()
    local value = addon and addon.opt
    if value and path1 then value = value[path1] end
    if value and path2 then value = value[path2] end
    if value == nil then return fallback end
    return value
end

local function Set(path1, path2, value, refresh)
    local addon = PP()
    if not addon then return end
    if path2 then
        addon.opt[path1] = addon.opt[path1] or {}
        addon.opt[path1][path2] = value
    else
        addon.opt[path1] = value
    end
    if refresh then RefreshLayout() end
end

local CLASS_NAMES = {
    WARRIOR="Warrior", ROGUE="Rogue", PRIEST="Priest", DRUID="Druid",
    PALADIN="Paladin", HUNTER="Hunter", MAGE="Mage", WARLOCK="Warlock",
    SHAMAN="Shaman", DEATHKNIGHT="Death Knight", PET="Pets",
}

local function ClassName(addon, classID)
    local classToken = addon.ClassID[classID]
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken])
           or CLASS_NAMES[classToken] or classToken
end

local function AssignmentControlReason(addon, paladinName)
    if paladinName == addon.player then return "Your assignments" end
    if IsPartyLeader() or IsRaidLeader() or IsRaidOfficer() then
        return "Leader/assistant control"
    end
    local paladin = addon:GetRoster()[paladinName]
    if paladin and paladin.freeassign == true then return "Free assignment enabled" end
    return "Read only"
end

local function ShowAssignmentTooltip(cell)
    local addon = PP()
    if not addon then return end
    local assignments = addon:GetAssignments()
    local blessingID = assignments and assignments[cell.paladinName]
                       and assignments[cell.paladinName][cell.classID] or 0
    local blessingName = blessingID > 0 and addon.Spells[blessingID] or "None"
    local canControl = addon:CanControl(cell.paladinName)

    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(cell.paladinName .. " - " .. ClassName(addon, cell.classID), 1, 1, 1)
    GameTooltip:AddLine(blessingName, 1, 0.82, 0, true)
    GameTooltip:AddLine(AssignmentControlReason(addon, cell.paladinName),
        canControl and 0.35 or 1, canControl and 1 or 0.35, 0.35, true)
    if InCombatLockdown and InCombatLockdown() then
        GameTooltip:AddLine("Assignments cannot be changed in combat.", 1, 0.35, 0.35, true)
    elseif canControl then
        GameTooltip:AddLine("Scroll to change. Shift + scroll changes the entire row.", 0.72, 0.72, 0.72, true)
        GameTooltip:AddLine("Left-click advances; right-click clears.", 0.72, 0.72, 0.72, true)
    else
        GameTooltip:AddLine("This row is editable by its Paladin, a group leader/assistant, or anyone when that Paladin enables Free Assignment.", 0.72, 0.72, 0.72, true)
    end
    GameTooltip:Show()
end

local function RefreshAssignmentCell(cell)
    local addon = PP()
    if not addon then return end
    local assignments = addon:GetAssignments()
    local blessingID = assignments and assignments[cell.paladinName]
                       and assignments[cell.paladinName][cell.classID] or 0
    local canControl = addon:CanControl(cell.paladinName)
                       and not (InCombatLockdown and InCombatLockdown())
    local icon = blessingID > 0 and addon.BlessingIcons[blessingID]

    cell._icon:SetTexture(icon)
    if icon then cell._empty:Hide() else cell._empty:Show() end
    cell._icon:SetAlpha(canControl and 1 or 0.38)
    cell._empty:SetAlpha(canControl and 0.5 or 0.22)
    cell._bg:SetTexture(1, 1, 1, canControl and 0.045 or 0.018)
    cell._border:SetColor(1, 1, 1, canControl and 0.11 or 0.045)
end

local function ApplyAssignmentChange(cell, delta, clear)
    local addon = PP()
    if not addon or (InCombatLockdown and InCombatLockdown())
       or not addon:CanControl(cell.paladinName) then return end

    if clear then
        addon:SetClassAssignment(cell.paladinName, cell.classID, 0)
    elseif delta < 0 then
        addon:PerformCycle(cell.paladinName, cell.classID)
    else
        addon:PerformCycleBackwards(cell.paladinName, cell.classID)
    end

    addon:UpdateLayout()
    if _G._EABR_RequestRefresh then _G._EABR_RequestRefresh() end
    if addon._euiAssignmentGrid and addon._euiAssignmentGrid.Refresh then
        addon._euiAssignmentGrid:Refresh()
    end
    if GameTooltip:IsOwned(cell) then ShowAssignmentTooltip(cell) end
end

local function BuildAssignmentGrid(parent, addon, paladins, y)
    local PPx = EllesmereUI.PanelPP
    local pad = EllesmereUI.CONTENT_PAD or 24
    local gridWidth = parent:GetWidth() - pad * 2
    local nameWidth = 142
    local headerHeight = 58
    local rowHeight = 50
    local columnWidth = (gridWidth - nameWidth) / PALLYPOWER_MAXCLASSES
    local gridHeight = headerHeight + #paladins * rowHeight
    local grid = EllesmereUI.SafeCreateFrame("Frame", nil, parent)
    PPx.Size(grid, gridWidth, gridHeight)
    PPx.Point(grid, "TOPLEFT", parent, "TOPLEFT", pad, y)
    grid.cells = {}
    grid.rows = {}

    local headerBg = EllesmereUI.SolidTex(grid, "BACKGROUND", 1, 1, 1, 0.025)
    PPx.Point(headerBg, "TOPLEFT", grid, "TOPLEFT", 0, 0)
    PPx.Point(headerBg, "TOPRIGHT", grid, "TOPRIGHT", 0, 0)
    PPx.Height(headerBg, headerHeight)

    local paladinHeader = EllesmereUI.MakeFont(grid, 11, nil, 0.72, 0.72, 0.72, 1)
    PPx.Point(paladinHeader, "LEFT", grid, "TOPLEFT", 8, -headerHeight / 2)
    paladinHeader:SetText("PALADIN")

    for classID = 1, PALLYPOWER_MAXCLASSES do
        local x = nameWidth + (classID - 1) * columnWidth
        local classHeader = EllesmereUI.SafeCreateFrame("Frame", nil, grid)
        PPx.Size(classHeader, columnWidth, headerHeight)
        PPx.Point(classHeader, "TOPLEFT", grid, "TOPLEFT", x, 0)

        local icon = classHeader:CreateTexture(nil, "ARTWORK")
        PPx.Size(icon, 24, 24)
        PPx.Point(icon, "TOP", classHeader, "TOP", 0, -7)
        icon:SetTexture(addon.ClassIcons[classID])

        local label = EllesmereUI.MakeFont(classHeader, 9, nil, 0.72, 0.72, 0.72, 1)
        PPx.Point(label, "TOPLEFT", icon, "BOTTOMLEFT", -columnWidth / 2 + 12, -4)
        PPx.Size(label, columnWidth, 15)
        label:SetJustifyH("CENTER")
        label:SetText(ClassName(addon, classID))
    end

    for rowIndex, paladinName in ipairs(paladins) do
        local row = EllesmereUI.SafeCreateFrame("Frame", nil, grid)
        PPx.Size(row, gridWidth, rowHeight)
        PPx.Point(row, "TOPLEFT", grid, "TOPLEFT", 0, -(headerHeight + (rowIndex - 1) * rowHeight))
        grid.rows[#grid.rows + 1] = row

        if rowIndex % 2 == 0 then
            local rowBg = EllesmereUI.SolidTex(row, "BACKGROUND", 1, 1, 1, 0.018)
            rowBg:SetAllPoints()
        end

        local name = EllesmereUI.MakeFont(row, 12, nil, 1, 1, 1, 1)
        PPx.Point(name, "TOPLEFT", row, "TOPLEFT", 8, -9)
        PPx.Size(name, nameWidth - 14, 15)
        name:SetJustifyH("LEFT")
        name:SetText(paladinName)

        local status = EllesmereUI.MakeFont(row, 9, nil, 0.62, 0.62, 0.62, 1)
        PPx.Point(status, "TOPLEFT", name, "BOTTOMLEFT", 0, -2)
        PPx.Size(status, nameWidth - 14, 13)
        status:SetJustifyH("LEFT")

        row.paladinName = paladinName
        row._name = name
        row._status = status

        for classID = 1, PALLYPOWER_MAXCLASSES do
            local cell = EllesmereUI.SafeCreateFrame("Button", nil, row)
            PPx.Size(cell, columnWidth - 3, rowHeight - 4)
            PPx.Point(cell, "TOPLEFT", row, "TOPLEFT",
                nameWidth + (classID - 1) * columnWidth + 1, -2)
            cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cell:EnableMouseWheel(true)
            cell.paladinName = paladinName
            cell.classID = classID

            cell._bg = EllesmereUI.SolidTex(cell, "BACKGROUND", 1, 1, 1, 0.045)
            cell._bg:SetAllPoints()
            cell._border = EllesmereUI.MakeBorder(cell, 1, 1, 1, 0.11, PPx)

            cell._icon = cell:CreateTexture(nil, "ARTWORK")
            PPx.Size(cell._icon, 32, 32)
            PPx.Point(cell._icon, "CENTER", cell, "CENTER", 0, 0)

            cell._empty = EllesmereUI.MakeFont(cell, 14, nil, 0.55, 0.55, 0.55, 1)
            cell._empty:SetPoint("CENTER")
            cell._empty:SetText("-")

            cell:SetScript("OnEnter", function(self)
                self._bg:SetTexture(1, 1, 1, addon:CanControl(self.paladinName) and 0.09 or 0.03)
                ShowAssignmentTooltip(self)
            end)
            cell:SetScript("OnLeave", function(self)
                RefreshAssignmentCell(self)
                GameTooltip:Hide()
            end)
            cell:SetScript("OnClick", function(self, mouseButton)
                ApplyAssignmentChange(self, -1, mouseButton == "RightButton")
            end)
            cell:SetScript("OnMouseWheel", function(self, delta)
                ApplyAssignmentChange(self, delta, false)
            end)

            grid.cells[#grid.cells + 1] = cell
        end
    end

    function grid:Refresh()
        for _, row in ipairs(self.rows) do
            local canControl = addon:CanControl(row.paladinName)
            row._status:SetText(AssignmentControlReason(addon, row.paladinName))
            if canControl then
                row._name:SetTextColor(1, 1, 1, 1)
                row._status:SetTextColor(0.38, 0.86, 0.68, 1)
            else
                row._name:SetTextColor(0.58, 0.58, 0.58, 1)
                row._status:SetTextColor(0.58, 0.42, 0.42, 1)
            end
        end
        for _, cell in ipairs(self.cells) do RefreshAssignmentCell(cell) end
    end

    grid:SetScript("OnShow", function(self) self:Refresh() end)
    grid:Refresh()
    addon._euiAssignmentGrid = grid
    return gridHeight
end

local function BuildAssignmentsPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local addon = PP()
    local y = yOffset
    local _, h

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "BLESSING ASSIGNMENTS", y); y = y - h

    if not addon then
        _, h = W:DualRow(parent, y, { type="label", text="PallyPower is not ready." }, nil)
        y = y - h
        return math.abs(y)
    end

    local paladins = {}
    for name in pairs(addon:GetRoster() or {}) do paladins[#paladins + 1] = name end
    table.sort(paladins, function(a, b)
        if a == b then return false end
        if a == addon.player then return true end
        if b == addon.player then return false end
        return a < b
    end)

    if #paladins == 0 then
        _, h = W:DualRow(parent, y,
            { type="label", text="No Paladins are currently available in the group." }, nil)
        y = y - h
        return math.abs(y)
    end

    local hint = EllesmereUI.MakeFont(parent, 11, nil, 0.62, 0.62, 0.62, 1)
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", EllesmereUI.CONTENT_PAD or 24, y - 8)
    hint:SetText("Scroll a class cell to change it. Hold Shift while scrolling to change the entire Paladin row.")
    y = y - 34

    y = y - BuildAssignmentGrid(parent, addon, paladins, y)

    return math.abs(y)
end

function PallyPower:RefreshAssignmentOptions(forceRebuild)
    if forceRebuild then
        if EllesmereUI:IsShown() and EllesmereUI:GetActiveModule() == "EllesmereUIPallyPower"
           and EllesmereUI:GetActivePage() == "Assignments" then
            EllesmereUI:RefreshPage(true)
        elseif EllesmereUI.InvalidateModulePageCache then
            EllesmereUI:InvalidateModulePageCache("EllesmereUIPallyPower")
        end
    elseif self._euiAssignmentGrid and self._euiAssignmentGrid.Refresh then
        self._euiAssignmentGrid:Refresh()
    end
end

local function BuildGeneralPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h

    _, h = W:Spacer(parent, y, 20); y = y - h

    _, h = W:SectionHeader(parent, "BUFF LOGIC", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type="toggle", text="Smart Buffs",
          tooltip="Skips blessings that do not benefit a class.",
          getValue=function() return Get("smartbuffs", nil, true) end,
          setValue=function(v) Set("smartbuffs", nil, v) end },
        { type="toggle", text="Smart Pets",
          tooltip="Associates pets with the class responsible for their greater blessing.",
          getValue=function() return Get("smartpets", nil, true) end,
          setValue=function(v) Set("smartpets", nil, v) end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Wait for Everyone",
          tooltip="Waits for every member of a class to be online and in range before buffing it.",
          getValue=function() return Get("autobuff", "waitforpeople", false) end,
          setValue=function(v) Set("autobuff", "waitforpeople", v) end },
        { type="toggle", text="Free Assignment",
          tooltip="Allows other PallyPower users to change your blessings without being group leader or assistant.",
          getValue=function() return Get("freeassign", nil, false) end,
          setValue=function(v)
              local addon = PP()
              if addon and addon.SetFreeAssignment then addon:SetFreeAssignment(v) end
          end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Ignore Groups 6-8",
          tooltip="Ignores standby players placed in raid groups 6 through 8.",
          getValue=function() return Get("extras", nil, false) end,
          setValue=function(v)
              Set("extras", nil, v)
              local addon = PP()
              if addon and addon.UpdateRoster then addon:UpdateRoster() end
          end },
        { type="toggle", text="Show Auto Buff Button",
          tooltip="Shows the button used by PallyPower's automatic buff bindings.",
          getValue=function() return Get("autobuff", "autobutton", true) end,
          setValue=function(v) Set("autobuff", "autobutton", v, true) end }
    ); y = y - h

    _, h = W:Spacer(parent, y, 16); y = y - h
    _, h = W:SectionHeader(parent, "VISIBILITY", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type="toggle", text="Show in Party",
          getValue=function() return Get("ShowInParty", nil, true) end,
          setValue=function(v) Set("ShowInParty", nil, v, true) end },
        { type="toggle", text="Show while Solo",
          getValue=function() return Get("ShowWhenSingle", nil, true) end,
          setValue=function(v) Set("ShowWhenSingle", nil, v, true) end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Righteous Fury & Seals",
          tooltip="Shows Righteous Fury and seal monitoring on the PallyPower bar.",
          getValue=function() return Get("rfbuff", nil, false) end,
          setValue=function(v) Set("rfbuff", nil, v, true) end },
        { type="toggle", text="Aura Monitoring",
          tooltip="Shows aura monitoring on the PallyPower bar.",
          getValue=function() return Get("auras", nil, false) end,
          setValue=function(v) Set("auras", nil, v, true) end }
    ); y = y - h

    return math.abs(y)
end

local function BuildDisplayPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h
    local addon = PP()
    local textureValues, textureOrder = {}, {}
    local textureNames = addon and addon.EUIBarTextureNames or {}
    for _, key in ipairs(addon and addon.EUIBarTextureOrder or {}) do
        if key ~= "---" then textureValues[key] = textureNames[key] or key end
        textureOrder[#textureOrder + 1] = key
    end
    textureValues._menuOpts = {
        itemHeight = 28,
        background = function(key)
            return addon and addon.EUIBarTextures and addon.EUIBarTextures[key]
        end,
    }
    local edgeValues = { LEFT="Left", RIGHT="Right", TOP="Top", BOTTOM="Bottom" }
    local edgeOrder = { "LEFT", "RIGHT", "TOP", "BOTTOM" }

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "LAYOUT", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type="dropdown", text="Bar Texture", values=textureValues, order=textureOrder,
          tooltip="Uses EllesmereUI's bar textures, including textures provided through SharedMedia.",
          getValue=function() return Get("display", "barTexture", "melli") end,
          setValue=function(v) Set("display", "barTexture", v, true) end },
        { type="dropdown", text="Flyout Edge", values=edgeValues, order=edgeOrder,
          tooltip="Anchors the PallyPower tab to this edge of the screen. The controls open toward the center.",
          getValue=function() return Get("display", "flyoutEdge", "RIGHT") end,
          setValue=function(v) Set("display", "flyoutEdge", v, true) end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="slider", text="Buff Bar Scale", min=0.4, max=1.5, step=0.05,
          getValue=function() return Get("buffscale", nil, 0.75) end,
          setValue=function(v) Set("buffscale", nil, v, true) end },
        nil
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="slider", text="Rows", min=1, max=11, step=1,
          getValue=function() return Get("display", "rows", 11) end,
          setValue=function(v) Set("display", "rows", v, true) end },
        { type="slider", text="Columns", min=1, max=11, step=1,
          getValue=function() return Get("display", "columns", 1) end,
          setValue=function(v) Set("display", "columns", v, true) end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="slider", text="Edge Position", min=0, max=100, step=1,
          tooltip="Positions the flyout tab along the selected screen edge. You can also drag the PallyPower mover in Unlock Mode.",
          getValue=function() return Get("display", "flyoutPosition", 50) end,
          setValue=function(v) Set("display", "flyoutPosition", v, true) end },
        { type="toggle", text="Keep Flyout Open",
          tooltip="Keeps the blessing controls visible instead of opening them on hover.",
          getValue=function() return Get("display", "flyoutPinned", false) end,
          setValue=function(v) Set("display", "flyoutPinned", v, true) end }
    ); y = y - h

    _, h = W:Spacer(parent, y, 16); y = y - h
    _, h = W:SectionHeader(parent, "BUTTONS", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type="toggle", text="Hide Player Buttons",
          getValue=function() return Get("display", "hidePlayerButtons", false) end,
          setValue=function(v) Set("display", "hidePlayerButtons", v, true) end },
        nil
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Class-Colored Buttons",
          getValue=function() return Get("classColor", nil, false) end,
          setValue=function(v) Set("classColor", nil, v, true) end },
        { type="toggle", text="Class-Colored Names",
          getValue=function() return Get("nameClassColor", nil, false) end,
          setValue=function(v) Set("nameClassColor", nil, v, true) end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Flash Missing Buffs",
          tooltip="Flashes player and auto-buff buttons when an assigned blessing is missing.",
          getValue=function() return Get("flashBuffAutoButtons", nil, true) end,
          setValue=function(v) Set("flashBuffAutoButtons", nil, v, true) end },
        { type="toggle", text="Show Button Borders",
          getValue=function() return Get("display", "edges", true) end,
          setValue=function(v) Set("display", "edges", v, true) end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="slider", text="Button Gap", min=-1, max=5, step=1,
          getValue=function() return Get("display", "gapping", -1) end,
          setValue=function(v) Set("display", "gapping", v, true) end },
        nil
    ); y = y - h

    return math.abs(y)
end

local function RegisterPallyPower()
    if registered or not PP() or not EllesmereUI.RegisterModule then return end
    registered = true
    EllesmereUI:RegisterModule("EllesmereUIPallyPower", {
        title       = "PallyPower",
        description = "Paladin blessing assignments, buff monitoring, and raid synchronization.",
        pages       = { "Assignments", "General", "Display" },
        searchTerms = "paladin pally blessings class assignments buffs auras seals righteous fury smart pets",
        buildPage   = function(pageName, parent, yOffset)
            if pageName == "Assignments" then return BuildAssignmentsPage(parent, yOffset) end
            if pageName == "General" then return BuildGeneralPage(parent, yOffset) end
            if pageName == "Display" then return BuildDisplayPage(parent, yOffset) end
        end,
        onReset = function()
            local addon = PP()
            if addon and addon.ResetProfile then addon:ResetProfile() end
            EllesmereUI:InvalidatePageCache()
        end,
        onPageCacheRestore = function(pageName)
            local addon = PP()
            if pageName == "Assignments" and addon and addon._euiAssignmentGrid
               and addon._euiAssignmentGrid.Refresh then
                addon._euiAssignmentGrid:Refresh()
            end
        end,
    })
end

local loader = EllesmereUI.SafeCreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "EllesmereUIPallyPower" then return end
    RegisterPallyPower()
    if registered then self:UnregisterAllEvents() end
end)

SLASH_EUIPP1 = "/pp"
SLASH_EUIPP2 = "/epp"
SlashCmdList.EUIPP = function()
    if InCombatLockdown and InCombatLockdown() then return end
    EllesmereUI:ShowModule("EllesmereUIPallyPower")
    EllesmereUI:SelectPage("Assignments")
end
