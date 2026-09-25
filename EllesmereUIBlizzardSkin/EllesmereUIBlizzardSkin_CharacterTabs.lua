--------------------------------------------------------------------------------
--  Custom CharacterFrame Reputation, Skills, and Currency pages
--
--  These pages deliberately do not reuse Blizzard's fixed-width row widgets.
--  Blizzard still owns CharacterFrame tab routing and the underlying game APIs;
--  EUI owns every visible control, row, scrollbar, and detail card below.
--------------------------------------------------------------------------------
local CustomTabs = {}
_G.EllesmereUIBlizzardSkin_CustomCharacterTabs = CustomTabs

local PAGE_WIDTH = 440
local ROW_HEIGHT = 30
local ROW_COUNT = 7
local REPUTATION_ROW_COUNT = 13
local REPUTATION_DETAIL_ROWS = 2
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local panels = setmetatable({}, { __mode = "k" })

local function FontPath()
    return EllesmereUI and EllesmereUI.GetFontPath
        and EllesmereUI.GetFontPath("blizzardSkin") or STANDARD_TEXT_FONT
end

local function Accent()
    local c = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    return (c and c.r) or 0.51, (c and c.g) or 0.784, (c and c.b) or 1
end

local function Number(value)
    value = tonumber(value) or 0
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(value) end
    return tostring(value)
end

local function SetFont(region, size, alpha)
    if not region then return end
    region:SetFont(FontPath(), size or 10, "")
    region:SetTextColor(1, 1, 1, alpha or 0.82)
end

local function Surface(frame, kind, r, g, b, a)
    local skin = _G.EllesmereUIBlizzardSkin
    if skin and skin.ApplyRetailSurface then
        skin:ApplyRetailSurface(frame, kind or "card", r, g, b, a)
    elseif frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1 })
        frame:SetBackdropColor(r or 0.025, g or 0.035, b or 0.04, a or 0.96)
        frame:SetBackdropBorderColor(1, 1, 1, 0.08)
    end
end

local function StyleRow(row, selected, header, alternate)
    local skin = _G.EllesmereUIBlizzardSkin
    if skin and skin.UpdateRetailRow then
        skin:UpdateRetailRow(row, selected, header, alternate)
    else
        Surface(row, header and "header" or "row")
    end
end

local function HideNative(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(0) end
    if object.EnableMouse then object:EnableMouse(false) end
end

local function SuppressNative(kind)
    local names
    if kind == "reputation" then
        names = {
            "ReputationListScrollFrame", "ReputationFrameFactionLabel",
            "ReputationFrameStandingLabel", "ReputationDetailFrame",
        }
    elseif kind == "skills" then
        names = {
            "SkillFrameExpandButtonFrame", "SkillListScrollFrame",
            "SkillDetailScrollFrame", "SkillDetailStatusBar", "SkillFrameCancelButton",
        }
    else
        names = {
            "TokenFrameContainer", "TokenFrameMoneyFrame", "TokenFrameCancelButton",
            "TokenFramePopup",
        }
    end
    for _, name in ipairs(names) do HideNative(_G[name]) end

    -- Wrath parents the visible faction buttons directly to ReputationFrame,
    -- not to ReputationListScrollFrame. The former opaque custom body happened
    -- to cover them; a transparent retail-style page must suppress every row
    -- explicitly, including its bar, tree lines, and expand button children.
    if kind == "reputation" then
        local index = 1
        while index <= 32 do
            local row = _G["ReputationBar" .. index]
            if row then HideNative(row) end
            index = index + 1
        end
    elseif kind == "skills" then
        -- SkillRankFrame and SkillTypeLabel are also direct SkillFrame
        -- children, so they need the same explicit treatment as reputation.
        for index = 1, 12 do
            HideNative(_G["SkillRankFrame" .. index])
            HideNative(_G["SkillTypeLabel" .. index])
        end
        HideNative(_G.SkillFrameCollapseAllButton)
    end

    -- Wrath's TokenFrame also owns an anonymous UIPanelCloseButton as its
    -- fourth child. It closes only the currency pane, so the themed sheet's
    -- CharacterFrame close button is the sole close control we retain.
    if kind == "currency" and _G.TokenFrame then
        local children = { _G.TokenFrame:GetChildren() }
        HideNative(children[4])
    end
end

local function CreateLabel(parent, layer, size, alpha)
    local label = parent:CreateFontString(nil, layer or "OVERLAY")
    SetFont(label, size, alpha)
    label:SetJustifyH("LEFT")
    return label
end

local function CreateTextButton(parent, text, width)
    local button = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    button:SetSize(width or 86, 22)
    Surface(button, "button", 0.04, 0.055, 0.06, 0.96)
    button.label = CreateLabel(button, "OVERLAY", 9, 0.8)
    button.label:SetPoint("CENTER")
    button.label:SetText(text or "")
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetTexture(1, 1, 1, 0.06)
    button:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 1, 1, 1) end)
    button:SetScript("OnLeave", function(self) self.label:SetTextColor(1, 1, 1, 0.8) end)
    return button
end

local function CreateCheck(parent, labelText)
    local check = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    check:SetHeight(18)
    check.box = EllesmereUI.SafeCreateFrame("Frame", nil, check)
    check.box:SetSize(13, 13)
    check.box:SetPoint("LEFT")
    Surface(check.box, "input", 0.025, 0.035, 0.04, 1)
    check.mark = check.box:CreateTexture(nil, "OVERLAY")
    check.mark:SetPoint("TOPLEFT", 3, -3)
    check.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    local r, g, b = Accent()
    check.mark:SetTexture(r, g, b, 1)
    if EllesmereUI and EllesmereUI.RegAccent then
        EllesmereUI.RegAccent({ type = "solid", obj = check.mark, a = 1 })
    end
    check.label = CreateLabel(check, "OVERLAY", 9, 0.72)
    check.label:SetPoint("LEFT", check.box, "RIGHT", 5, 0)
    check.label:SetText(labelText or "")
    check:SetWidth(check.label:GetStringWidth() + 23)
    function check:SetChecked(checked)
        self.checked = checked and true or false
        self.mark:SetShown(self.checked)
    end
    function check:SetEnabledState(enabled)
        self.enabled = enabled and true or false
        self:SetAlpha(self.enabled and 1 or 0.35)
    end
    check:SetChecked(false)
    check:SetEnabledState(true)
    check:SetScript("OnClick", function(self)
        if self.enabled and self.callback then self.callback(not self.checked) end
    end)
    return check
end

local function CreateRow(parent, index, rowHeight)
    rowHeight = rowHeight or ROW_HEIGHT
    local row = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    row:SetHeight(rowHeight - 1)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * rowHeight))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -((index - 1) * rowHeight))

    row.glyph = CreateLabel(row, "OVERLAY", 14, 1)
    row.glyph:SetPoint("LEFT", 9, 0)
    local ar, ag, ab = Accent()
    row.glyph:SetTextColor(ar, ag, ab, 1)
    if EllesmereUI and EllesmereUI.RegAccent then
        local glyph = row.glyph
        EllesmereUI.RegAccent({
            type = "callback", obj = glyph,
            fn = function(r, g, b) glyph:SetTextColor(r, g, b, 1) end,
        })
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 25, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = CreateLabel(row, "OVERLAY", 10, 0.88)
    row.name:SetPoint("LEFT", 53, 0)
    row.name:SetPoint("RIGHT", -82, 0)
    row.name:SetWordWrap(false)

    row.value = CreateLabel(row, "OVERLAY", 9, 0.58)
    row.value:SetPoint("RIGHT", -9, 0)
    row.value:SetJustifyH("RIGHT")

    row.bar = EllesmereUI.SafeCreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture(BAR_TEXTURE)
    row.bar:SetPoint("BOTTOMLEFT", row.name, "BOTTOMLEFT", 0, -5)
    row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -9, 5)
    row.bar:SetHeight(3)
    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetTexture(1, 1, 1, 0.08)
    row.bar.standing = CreateLabel(row.bar, "OVERLAY", 9, 0.94)
    row.bar.standing:SetPoint("CENTER", 0, 0)
    row.bar.standing:SetJustifyH("CENTER")
    row.bar.standing:Hide()

    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetTexture(1, 1, 1, 0.055)
    return row
end

local function CreateBase(pane, kind, sectionTitle, rowCount)
    if panels[pane] then return panels[pane] end
    rowCount = rowCount or ROW_COUNT
    pane:ClearAllPoints()
    pane:SetWidth(PAGE_WIDTH)
    pane:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
    pane:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 0, 0)
    local skin = _G.EllesmereUIBlizzardSkin
    if skin and skin.StripTextures then skin:StripTextures(pane, true) end
    SuppressNative(kind)

    local panel = EllesmereUI.SafeCreateFrame("Frame", nil, pane)
    panel:SetPoint("TOPLEFT", pane, "TOPLEFT", 14, -43)
    panel:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -14, 41)
    panel:SetFrameLevel(pane:GetFrameLevel() + 25)
    panel:EnableMouse(true)
    Surface(panel, "body", 0.012, 0.02, 0.024, 0.98)
    panel.kind = kind
    panel.offset = 0
    panel.selectedIndex = nil
    panel.rowCount = rowCount
    panel.visibleRowCount = rowCount

    panel.section = CreateLabel(panel, "OVERLAY", 10, 0.92)
    panel.section:SetPoint("TOPLEFT", 10, -10)
    panel.section:SetText(sectionTitle)
    panel.summary = CreateLabel(panel, "OVERLAY", 9, 0.44)
    panel.summary:SetPoint("LEFT", panel.section, "RIGHT", 7, 0)

    panel.list = EllesmereUI.SafeCreateFrame("Frame", nil, panel)
    panel.list:SetPoint("TOPLEFT", 8, -35)
    panel.list:SetPoint("TOPRIGHT", -8, -35)
    panel.list:SetHeight(rowCount * ROW_HEIGHT)
    panel.list:EnableMouseWheel(true)

    panel.slider = EllesmereUI.SafeCreateFrame("Slider", nil, panel.list)
    panel.slider:SetPoint("TOPRIGHT", 0, -2)
    panel.slider:SetPoint("BOTTOMRIGHT", 0, 2)
    panel.slider:SetWidth(8)
    panel.slider:SetOrientation("VERTICAL")
    panel.slider:SetValueStep(1)
    panel.slider:SetMinMaxValues(0, 0)
    local thumb = panel.slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(1, 1, 1, 0.5)
    thumb:SetSize(4, 22)
    panel.slider:SetThumbTexture(thumb)
    if skin and skin.HandleRetailScrollBar then skin:HandleRetailScrollBar(panel.slider) end

    panel.rows = {}
    for i = 1, rowCount do
        panel.rows[i] = CreateRow(panel.list, i, ROW_HEIGHT)
    end

    panel.detail = EllesmereUI.SafeCreateFrame("Frame", nil, panel)
    panel.detail:SetPoint("BOTTOMLEFT", 8, 8)
    panel.detail:SetPoint("BOTTOMRIGHT", -8, 8)
    panel.detail:SetHeight(77)
    Surface(panel.detail, "card", 0.025, 0.038, 0.043, 0.98)
    panel.detail.title = CreateLabel(panel.detail, "OVERLAY", 10, 0.92)
    panel.detail.title:SetPoint("TOPLEFT", 10, -9)
    panel.detail.title:SetPoint("TOPRIGHT", -10, -9)
    panel.detail.description = CreateLabel(panel.detail, "OVERLAY", 9, 0.55)
    panel.detail.description:SetPoint("TOPLEFT", 10, -27)
    panel.detail.description:SetPoint("TOPRIGHT", -10, -27)
    panel.detail.description:SetHeight(30)
    panel.detail.description:SetJustifyV("TOP")
    panel.detail.empty = CreateLabel(panel.detail, "OVERLAY", 9, 0.38)
    panel.detail.empty:SetPoint("CENTER")

    panel.empty = CreateLabel(panel.list, "OVERLAY", 10, 0.4)
    panel.empty:SetPoint("CENTER", -6, 0)
    panel.empty:SetText(_G.NONE or EllesmereUI.L("None"))

    panel.slider:SetScript("OnValueChanged", function(_, value)
        local nextOffset = math.floor((value or 0) + 0.5)
        if nextOffset ~= panel.offset then
            panel.offset = nextOffset
            if panel.Refresh then panel:Refresh() end
        end
    end)
    panel.list:SetScript("OnMouseWheel", function(_, delta)
        local _, maximum = panel.slider:GetMinMaxValues()
        panel.slider:SetValue(math.max(0, math.min(maximum or 0, panel.offset - delta)))
    end)
    panel:SetScript("OnShow", function(self)
        SuppressNative(self.kind)
        if self.Refresh then self:Refresh() end
    end)

    panels[pane] = panel
    return panel
end

local function FinishRows(panel, total, visibleRowCount)
    visibleRowCount = visibleRowCount or panel.rowCount or ROW_COUNT
    panel.visibleRowCount = visibleRowCount
    local maximum = math.max(0, total - visibleRowCount)
    panel.slider:SetMinMaxValues(0, maximum)
    if panel.offset > maximum then
        panel.offset = maximum
        panel.slider:SetValue(maximum)
    end
    panel.slider:SetShown(maximum > 0)
    panel.empty:SetShown(total == 0)
    panel.summary:SetText(string.format("%d", total))
end

local function RegisterPanelEvents(panel, events)
    for _, event in ipairs(events) do panel:RegisterEvent(event) end
    panel:SetScript("OnEvent", function(self)
        if self:IsShown() and self.Refresh then self:Refresh() end
    end)
end

local function RowTooltip(row, title, body)
    if not title then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if body and body ~= "" then GameTooltip:AddLine(body, nil, nil, nil, true) end
    GameTooltip:Show()
end

local function SetupGroupedPanel(panel, listTopInset)
    panel.section:Hide()
    panel.summary:Hide()
    panel:SetBackdrop(nil)
    if listTopInset then
        panel.list:ClearAllPoints()
        panel.list:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -listTopInset)
        panel.list:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -listTopInset)
        panel.list:SetHeight(panel.rowCount * ROW_HEIGHT)
    end

    if panel.groupBackgrounds then return end
    panel.groupBackgrounds = {}
    for i = 1, panel.rowCount do
        local background = panel.list:CreateTexture(nil, "BACKGROUND")
        background:SetTexture(0, 0, 0, 0.22)
        background:Hide()
        panel.groupBackgrounds[i] = background
    end

    function panel:RefreshGroupBackgrounds(visibleRows)
        local used = 0
        local groupTopRow, lastChildRow, startsWithHeader
        local function FinishGroup()
            if groupTopRow and lastChildRow then
                used = used + 1
                local background = self.groupBackgrounds[used]
                background:ClearAllPoints()
                if startsWithHeader then
                    background:SetPoint("TOPLEFT", groupTopRow, "BOTTOMLEFT", 0, 0)
                else
                    -- The header may have scrolled just above the viewport;
                    -- continue its backplate behind the remaining child rows.
                    background:SetPoint("TOPLEFT", groupTopRow, "TOPLEFT", 0, 0)
                end
                background:SetPoint("BOTTOMRIGHT", lastChildRow, "BOTTOMRIGHT", 0, 0)
                background:Show()
            end
            groupTopRow = nil
            lastChildRow = nil
            startsWithHeader = nil
        end
        for rowNumber = 1, visibleRows do
            local row = self.rows[rowNumber]
            if row and row.data then
                if row.data.isHeader then
                    FinishGroup()
                    groupTopRow = row
                    startsWithHeader = true
                else
                    if not groupTopRow then
                        groupTopRow = row
                        startsWithHeader = false
                    end
                    lastChildRow = row
                end
            end
        end
        FinishGroup()
        for i = used + 1, #self.groupBackgrounds do
            self.groupBackgrounds[i]:Hide()
        end
    end
end

local function StyleGroupedRow(row, selected, isHeader, alternate)
    StyleRow(row, selected, isHeader, alternate)
    if isHeader then
        row:SetBackdropColor(0.12, 0.12, 0.11, 0.94)
        row:SetBackdropBorderColor(1, 1, 1, 0.08)
    elseif not selected then
        row:SetBackdropColor(0, 0, 0, 0)
        row:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function BuildReputation(pane)
    local panel = CreateBase(
        pane,
        "reputation",
        _G.FACTIONS or _G.REPUTATION or EllesmereUI.L("Reputation"),
        REPUTATION_ROW_COUNT
    )
    if panel.built then return panel end
    panel.built = true
    -- Reputation uses the character window artwork as its canvas. The shared
    -- section label and body surface made this page look like a panel nested
    -- inside another panel, unlike the retail accordion list.
    SetupGroupedPanel(panel, 8)

    panel.detail.empty:SetText(EllesmereUI.L("Select a faction to view reputation options"))
    panel.detail.atWar = CreateCheck(panel.detail, _G.AT_WAR or EllesmereUI.L("At War"))
    panel.detail.atWar:SetPoint("BOTTOMLEFT", 10, 8)
    panel.detail.inactive = CreateCheck(panel.detail, _G.INACTIVE or EllesmereUI.L("Inactive"))
    panel.detail.inactive:SetPoint("LEFT", panel.detail.atWar, "RIGHT", 15, 0)
    panel.detail.watched = CreateCheck(panel.detail, _G.SHOW_FACTION_ON_MAINSCREEN or _G.SHOW_AS_XP or EllesmereUI.L("Show as XP Bar"))
    panel.detail.watched:SetPoint("LEFT", panel.detail.inactive, "RIGHT", 15, 0)
    panel.detail:EnableMouse(true)
    panel.detail.close = EllesmereUI.SafeCreateFrame("Button", nil, panel.detail)
    panel.detail.close:SetSize(18, 18)
    panel.detail.close:SetPoint("TOPRIGHT", -5, -5)
    panel.detail.close.icon = panel.detail.close:CreateTexture(nil, "OVERLAY")
    panel.detail.close.icon:SetTexture("Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-close.tga")
    panel.detail.close.icon:SetSize(10, 10)
    panel.detail.close.icon:SetPoint("CENTER")
    panel.detail.close.icon:SetVertexColor(1, 1, 1, 0.65)
    panel.detail.close:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1)
    end)
    panel.detail.close:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(1, 1, 1, 0.65)
    end)
    panel.detail.close:SetScript("OnClick", function()
        panel.selectedIndex = nil
        panel.selectedName = nil
        panel:Refresh()
    end)
    panel.detail.title:ClearAllPoints()
    panel.detail.title:SetPoint("TOPLEFT", 10, -9)
    panel.detail.title:SetPoint("TOPRIGHT", -28, -9)
    panel.detail:Hide()

    function panel:Refresh()
        SuppressNative("reputation")
        local total = GetNumFactions and (GetNumFactions() or 0) or 0
        local selected, selectedData
        if self.selectedIndex and self.selectedIndex <= total and GetFactionInfo then
            local name, description, standingID, barMin, barMax, barValue,
                atWar, canToggleAtWar, isHeader, _, _, isWatched = GetFactionInfo(self.selectedIndex)
            if name and not isHeader and (not self.selectedName or name == self.selectedName) then
                selected = true
                selectedData = {
                    name = name, description = description, standingID = standingID,
                    barMin = barMin, barMax = barMax, barValue = barValue,
                    atWar = atWar, canToggleAtWar = canToggleAtWar, isWatched = isWatched,
                }
            else
                self.selectedIndex = nil
                self.selectedName = nil
            end
        end
        local visibleRows = selected and (REPUTATION_ROW_COUNT - REPUTATION_DETAIL_ROWS)
            or REPUTATION_ROW_COUNT
        FinishRows(self, total, visibleRows)
        self.list:SetHeight(visibleRows * ROW_HEIGHT)
        -- When a row from the bottom of the expanded list is selected, the
        -- options card consumes two row slots. Keep that faction in view
        -- rather than letting the card appear after its source row vanishes.
        if selected then
            local nextOffset = self.offset
            if self.selectedIndex <= nextOffset then
                nextOffset = math.max(0, self.selectedIndex - 1)
            elseif self.selectedIndex > nextOffset + visibleRows then
                nextOffset = self.selectedIndex - visibleRows
            end
            local _, maximum = self.slider:GetMinMaxValues()
            nextOffset = math.max(0, math.min(maximum or 0, nextOffset))
            if nextOffset ~= self.offset then
                self.offset = nextOffset
                self.slider:SetValue(nextOffset)
            end
        end
        for rowNumber, row in ipairs(self.rows) do
            local index = self.offset + rowNumber
            local name, description, standingID, barMin, barMax, barValue,
                atWar, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild
            if rowNumber <= visibleRows and index <= total and GetFactionInfo then
                name, description, standingID, barMin, barMax, barValue,
                    atWar, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(index)
            end
            row:SetShown(name ~= nil)
            if name then
                row.data = {
                    index = index, name = name, description = description, standingID = standingID,
                    barMin = barMin, barMax = barMax, barValue = barValue, atWar = atWar,
                    canToggleAtWar = canToggleAtWar, isHeader = isHeader, isCollapsed = isCollapsed,
                    hasRep = hasRep, isWatched = isWatched, isChild = isChild,
                }
                StyleGroupedRow(row, self.selectedIndex == index, isHeader, rowNumber % 2 == 0)
                row.glyph:SetShown(isHeader and true or false)
                row.glyph:SetText(isCollapsed and "+" or "-")
                row.glyph:ClearAllPoints()
                row.glyph:SetPoint("RIGHT", -10, 0)
                row.icon:Hide()
                -- CreateRow initially places the thin Skills-style bar relative
                -- to row.name. Break that relationship before anchoring the
                -- reputation name back to the bar, or WoW rejects the cycle.
                row.bar:ClearAllPoints()
                row.bar:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                row.bar:SetSize(126, 14)
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", isHeader and 16 or (isChild and 38 or 20), 0)
                if isHeader then
                    row.name:SetPoint("RIGHT", -36, 0)
                else
                    row.name:SetPoint("RIGHT", row.bar, "LEFT", -10, 0)
                end
                row.name:SetText(name)
                row.name:SetTextColor(1, 1, 1, isHeader and 0.94 or 0.82)
                local standing = standingID and _G["FACTION_STANDING_LABEL" .. standingID] or ""
                row.value:SetText("")
                row.bar:SetShown(not isHeader and barMax and barMax > barMin)
                row.bar.standing:SetShown(not isHeader and barMax and barMax > barMin)
                if not isHeader and barMax and barMax > barMin then
                    if not row.repBarStyled then
                        Surface(row.bar, "input", 0.08, 0.08, 0.08, 0.94)
                        row.repBarStyled = true
                    end
                    row.bar:SetMinMaxValues(barMin, barMax)
                    row.bar:SetValue(barValue or barMin)
                    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standingID]
                    row.bar:SetStatusBarColor((c and c.r) or 0.3, (c and c.g) or 0.7, (c and c.b) or 0.9, 0.9)
                    row.bar.standing:SetText(standing)
                end
            else
                row.data = nil
                row.bar.standing:Hide()
            end
        end
        self:RefreshGroupBackgrounds(visibleRows)

        if selected and selectedData then
            local standing = selectedData.standingID
                and (_G["FACTION_STANDING_LABEL" .. selectedData.standingID] or "") or ""
            local progress = string.format(
                "%s / %s",
                Number((selectedData.barValue or 0) - (selectedData.barMin or 0)),
                Number((selectedData.barMax or 0) - (selectedData.barMin or 0))
            )
            self.detail.title:SetText(selectedData.name .. (standing ~= "" and ("  |cffaaaaaa" .. standing .. "|r") or ""))
            self.detail.description:SetText(selectedData.description or progress)
            self.detail.atWar:SetChecked(selectedData.atWar)
            self.detail.atWar:SetEnabledState(selectedData.canToggleAtWar)
            self.detail.inactive:SetChecked(IsFactionInactive and IsFactionInactive(self.selectedIndex))
            self.detail.inactive:SetEnabledState(SetFactionInactive ~= nil)
            self.detail.watched:SetChecked(selectedData.isWatched)
        end
        self.detail:SetShown(selected and true or false)
        self.detail.title:SetShown(selected and true or false)
        self.detail.description:SetShown(selected and true or false)
        self.detail.atWar:SetShown(selected and true or false)
        self.detail.inactive:SetShown(selected and true or false)
        self.detail.watched:SetShown(selected and true or false)
        self.detail.empty:Hide()
    end

    for _, row in ipairs(panel.rows) do
        row:SetScript("OnClick", function(self)
            local data = self.data
            if not data then return end
            if data.isHeader then
                panel.selectedIndex = nil
                panel.selectedName = nil
                if data.isCollapsed and ExpandFactionHeader then ExpandFactionHeader(data.index)
                elseif CollapseFactionHeader then CollapseFactionHeader(data.index) end
            else
                if panel.selectedIndex == data.index and panel.selectedName == data.name then
                    panel.selectedIndex = nil
                    panel.selectedName = nil
                else
                    panel.selectedIndex = data.index
                    panel.selectedName = data.name
                end
            end
            panel:Refresh()
        end)
        row:SetScript("OnEnter", function(self)
            if self.data and not self.data.isHeader then RowTooltip(self, self.data.name, self.data.description) end
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end
    panel.detail.atWar.callback = function(value)
        if panel.selectedIndex then
            if value and SetFactionAtWar then SetFactionAtWar(panel.selectedIndex)
            elseif not value and SetFactionNotAtWar then SetFactionNotAtWar(panel.selectedIndex) end
        end
        panel:Refresh()
    end
    panel.detail.inactive.callback = function(value)
        if panel.selectedIndex then
            if value and SetFactionInactive then SetFactionInactive(panel.selectedIndex)
            elseif not value and SetFactionActive then SetFactionActive(panel.selectedIndex) end
        end
        panel.selectedIndex = nil
        panel.selectedName = nil
        panel:Refresh()
    end
    panel.detail.watched.callback = function(value)
        if panel.selectedIndex and SetWatchedFactionIndex then SetWatchedFactionIndex(value and panel.selectedIndex or 0) end
        panel:Refresh()
    end
    RegisterPanelEvents(panel, { "UPDATE_FACTION" })
    panel:Refresh()
    return panel
end

local function BuildSkills(pane)
    local panel = CreateBase(pane, "skills", _G.SKILLS or EllesmereUI.L("Skills"))
    if panel.built then return panel end
    panel.built = true
    SetupGroupedPanel(panel)
    panel.detail.empty:SetText(EllesmereUI.L("Select a skill to view its details"))
    panel.collapse = CreateTextButton(panel, _G.COLLAPSE_ALL_BUTTON or EllesmereUI.L("Collapse All"), 86)
    panel.collapse:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -6)
    panel.unlearn = CreateTextButton(panel.detail, _G.UNLEARN or EllesmereUI.L("Unlearn"), 68)
    panel.unlearn:SetPoint("BOTTOMRIGHT", -8, 7)

    function panel:Refresh()
        SuppressNative("skills")
        local total = GetNumSkillLines and (GetNumSkillLines() or 0) or 0
        FinishRows(self, total)
        for rowNumber, row in ipairs(self.rows) do
            local index = self.offset + rowNumber
            local name, isHeader, isExpanded, rank, temporary, modifier, maxRank,
                isAbandonable, stepCost, rankCost, minLevel, costType, description
            if index <= total and GetSkillLineInfo then
                name, isHeader, isExpanded, rank, temporary, modifier, maxRank,
                    isAbandonable, stepCost, rankCost, minLevel, costType, description = GetSkillLineInfo(index)
            end
            row:SetShown(name ~= nil)
            if name then
                row.data = {
                    index = index, name = name, isHeader = isHeader, isExpanded = isExpanded,
                    rank = rank, temporary = temporary, modifier = modifier, maxRank = maxRank,
                    isAbandonable = isAbandonable, description = description,
                }
                StyleGroupedRow(row, self.selectedIndex == index, isHeader, rowNumber % 2 == 0)
                row.glyph:SetShown(isHeader and true or false)
                row.glyph:SetText(isExpanded and "-" or "+")
                row.glyph:ClearAllPoints()
                row.glyph:SetPoint("RIGHT", -10, 0)
                row.icon:Hide()
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", 16, 0)
                row.name:SetPoint("RIGHT", isHeader and -36 or -90, 0)
                row.name:SetText(name)
                row.name:SetTextColor(1, 1, 1, isHeader and 0.94 or 0.82)
                local effective = (tonumber(rank) or 0) + (tonumber(temporary) or 0) + (tonumber(modifier) or 0)
                row.value:SetText(isHeader and "" or string.format("%d / %d", effective, tonumber(maxRank) or 0))
                row.bar:SetShown(not isHeader and (tonumber(maxRank) or 0) > 0)
                if not isHeader and (tonumber(maxRank) or 0) > 0 then
                    row.bar:SetMinMaxValues(0, maxRank)
                    row.bar:SetValue(effective)
                    local r, g, b = Accent()
                    row.bar:SetStatusBarColor(r, g, b, 0.8)
                end
            else
                row.data = nil
            end
        end
        self:RefreshGroupBackgrounds(self.visibleRowCount)
        local selected
        if self.selectedIndex and self.selectedIndex <= total and GetSkillLineInfo then
            local name, isHeader, _, rank, temporary, modifier, maxRank, isAbandonable,
                _, _, _, _, description = GetSkillLineInfo(self.selectedIndex)
            if name and not isHeader and (not self.selectedName or name == self.selectedName) then
                selected = true
                local effective = (tonumber(rank) or 0) + (tonumber(temporary) or 0) + (tonumber(modifier) or 0)
                self.detail.title:SetText(string.format("%s  |cffaaaaaa%d / %d|r", name, effective, tonumber(maxRank) or 0))
                self.detail.description:SetText(description or "")
                self.unlearn.skillName = name
                self.unlearn:SetShown(isAbandonable and true or false)
            end
        end
        self.detail.title:SetShown(selected and true or false)
        self.detail.description:SetShown(selected and true or false)
        if not selected then self.unlearn:Hide() end
        self.detail.empty:SetShown(not selected)
    end
    for _, row in ipairs(panel.rows) do
        row:SetScript("OnClick", function(self)
            local data = self.data
            if not data then return end
            if data.isHeader then
                panel.selectedIndex = nil
                panel.selectedName = nil
                if data.isExpanded and CollapseSkillHeader then CollapseSkillHeader(data.index)
                elseif ExpandSkillHeader then ExpandSkillHeader(data.index) end
            else
                panel.selectedIndex = data.index
                panel.selectedName = data.name
                pane.selectedSkill = data.index
            end
            panel:Refresh()
        end)
        row:SetScript("OnEnter", function(self)
            if self.data and not self.data.isHeader then RowTooltip(self, self.data.name, self.data.description) end
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end
    panel.collapse:SetScript("OnClick", function()
        if not (GetNumSkillLines and GetSkillLineInfo and CollapseSkillHeader) then return end
        for i = GetNumSkillLines(), 1, -1 do
            local _, isHeader, isExpanded = GetSkillLineInfo(i)
            if isHeader and isExpanded then CollapseSkillHeader(i) end
        end
        panel.offset = 0
        panel.slider:SetValue(0)
        panel:Refresh()
    end)
    panel.unlearn:SetScript("OnClick", function(self)
        if not panel.selectedIndex then return end
        pane.selectedSkill = panel.selectedIndex
        if SkillFrame_UnlearnSkill then
            SkillFrame_UnlearnSkill()
        elseif StaticPopupDialogs and StaticPopupDialogs.UNLEARN_SKILL then
            StaticPopup_Show("UNLEARN_SKILL", self.skillName, nil, panel.selectedIndex)
        end
    end)
    RegisterPanelEvents(panel, { "SKILL_LINES_CHANGED" })
    panel:Refresh()
    return panel
end

local function CurrencyInfo(index)
    if not GetCurrencyListInfo then return end
    local name, isHeader, isExpanded, isUnused, isWatched, quantity,
        extraCurrencyType, icon, itemID = GetCurrencyListInfo(index)
    return name, isHeader, isExpanded, isUnused, isWatched, quantity,
        extraCurrencyType, icon, itemID
end

local function BuildCurrency(pane)
    local panel = CreateBase(pane, "currency", _G.CURRENCY or EllesmereUI.L("Currency"))
    if panel.built then return panel end
    panel.built = true
    SetupGroupedPanel(panel)
    panel.detail.empty:SetText(EllesmereUI.L("Select a currency to view its options"))
    panel.money = CreateLabel(panel, "OVERLAY", 9, 0.58)
    panel.money:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
    panel.detail.backpack = CreateCheck(panel.detail, _G.TOKEN_SHOW_ON_BACKPACK or EllesmereUI.L("Show in Backpack"))
    panel.detail.backpack:SetPoint("BOTTOMLEFT", 10, 8)
    panel.detail.unused = CreateCheck(panel.detail, _G.TOKEN_MARK_UNUSED or EllesmereUI.L("Mark as Unused"))
    panel.detail.unused:SetPoint("LEFT", panel.detail.backpack, "RIGHT", 18, 0)

    function panel:Refresh()
        SuppressNative("currency")
        local total = GetCurrencyListSize and (GetCurrencyListSize() or 0) or 0
        FinishRows(self, total)
        if GetMoney and GetCoinTextureString then self.money:SetText(GetCoinTextureString(GetMoney()))
        else self.money:SetText("") end
        for rowNumber, row in ipairs(self.rows) do
            local index = self.offset + rowNumber
            local name, isHeader, isExpanded, isUnused, isWatched, quantity,
                extraCurrencyType, icon, itemID
            if index <= total then
                name, isHeader, isExpanded, isUnused, isWatched, quantity,
                    extraCurrencyType, icon, itemID = CurrencyInfo(index)
            end
            row:SetShown(name ~= nil)
            if name then
                row.data = {
                    index = index, name = name, isHeader = isHeader, isExpanded = isExpanded,
                    isUnused = isUnused, isWatched = isWatched, quantity = quantity,
                    extraCurrencyType = extraCurrencyType, icon = icon, itemID = itemID,
                }
                StyleGroupedRow(row, self.selectedIndex == index, isHeader, rowNumber % 2 == 0)
                row.glyph:SetShown(isHeader and true or false)
                row.glyph:SetText(isExpanded and "-" or "+")
                row.glyph:ClearAllPoints()
                row.glyph:SetPoint("RIGHT", -10, 0)
                row.icon:SetShown(not isHeader)
                if not isHeader then
                    if extraCurrencyType == 1 and not icon then icon = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon" end
                    if extraCurrencyType == 2 and not icon then
                        local faction = UnitFactionGroup and UnitFactionGroup("player")
                        if faction then icon = "Interface\\TargetingFrame\\UI-PVP-" .. faction end
                    end
                    row.icon:SetTexture(icon or 134400)
                end
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", isHeader and 16 or 53, 0)
                row.name:SetPoint("RIGHT", isHeader and -36 or -90, 0)
                row.name:SetText(name)
                row.name:SetTextColor(1, 1, 1, isHeader and 0.94 or (isUnused and 0.42 or 0.82))
                row.value:SetText(isHeader and "" or Number(quantity))
                row.bar:Hide()
            else
                row.data = nil
            end
        end
        self:RefreshGroupBackgrounds(self.visibleRowCount)
        local selected
        if self.selectedIndex and self.selectedIndex <= total then
            local name, isHeader, _, isUnused, isWatched, quantity, _, _, itemID = CurrencyInfo(self.selectedIndex)
            if name and not isHeader and (not self.selectedName or name == self.selectedName) then
                selected = true
                self.detail.title:SetText(string.format("%s  |cffaaaaaa%s|r", name, Number(quantity)))
                self.detail.description:SetText("")
                self.detail.backpack:SetChecked(isWatched)
                self.detail.backpack:SetEnabledState(SetCurrencyBackpack ~= nil)
                self.detail.unused:SetChecked(isUnused)
                self.detail.unused:SetEnabledState(SetCurrencyUnused ~= nil)
                self.detail.itemID = itemID
            end
        end
        self.detail.title:SetShown(selected and true or false)
        self.detail.description:SetShown(selected and true or false)
        self.detail.backpack:SetShown(selected and true or false)
        self.detail.unused:SetShown(selected and true or false)
        self.detail.empty:SetShown(not selected)
    end
    for _, row in ipairs(panel.rows) do
        row:SetScript("OnClick", function(self)
            local data = self.data
            if not data then return end
            if data.isHeader then
                panel.selectedIndex = nil
                panel.selectedName = nil
                if ExpandCurrencyList then ExpandCurrencyList(data.index, data.isExpanded and 0 or 1) end
            else
                panel.selectedIndex = data.index
                panel.selectedName = data.name
            end
            panel:Refresh()
        end)
        row:SetScript("OnEnter", function(self)
            local data = self.data
            if not data or data.isHeader then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.SetCurrencyToken then GameTooltip:SetCurrencyToken(data.index)
            elseif data.itemID then GameTooltip:SetHyperlink("item:" .. data.itemID)
            else GameTooltip:SetText(data.name, 1, 1, 1) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end
    panel.detail.backpack.callback = function(value)
        if panel.selectedIndex and SetCurrencyBackpack then SetCurrencyBackpack(panel.selectedIndex, value) end
        panel:Refresh()
    end
    panel.detail.unused.callback = function(value)
        if panel.selectedIndex and SetCurrencyUnused then SetCurrencyUnused(panel.selectedIndex, value) end
        panel.selectedIndex = nil
        panel.selectedName = nil
        panel:Refresh()
    end
    RegisterPanelEvents(panel, { "CURRENCY_DISPLAY_UPDATE", "BAG_UPDATE", "PLAYER_MONEY" })
    panel:Refresh()
    return panel
end

function CustomTabs:Build(kind, pane)
    if not pane then return end
    if kind == "reputation" then return BuildReputation(pane) end
    if kind == "skills" then return BuildSkills(pane) end
    if kind == "currency" then return BuildCurrency(pane) end
end

function CustomTabs:ResizePane(pane)
    if not pane then return end
    pane:ClearAllPoints()
    pane:SetWidth(PAGE_WIDTH)
    pane:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
    pane:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 0, 0)
    local panel = panels[pane]
    if panel and panel.Refresh then panel:Refresh() end
end

function CustomTabs:GetPageWidth()
    return PAGE_WIDTH
end
