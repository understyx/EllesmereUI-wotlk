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

local function CreateRow(parent, index)
    local row = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT - 1)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -((index - 1) * ROW_HEIGHT))

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

    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetTexture(1, 1, 1, 0.055)
    return row
end

local function CreateBase(pane, kind, sectionTitle)
    if panels[pane] then return panels[pane] end
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

    panel.section = CreateLabel(panel, "OVERLAY", 10, 0.92)
    panel.section:SetPoint("TOPLEFT", 10, -10)
    panel.section:SetText(sectionTitle)
    panel.summary = CreateLabel(panel, "OVERLAY", 9, 0.44)
    panel.summary:SetPoint("LEFT", panel.section, "RIGHT", 7, 0)

    panel.list = EllesmereUI.SafeCreateFrame("Frame", nil, panel)
    panel.list:SetPoint("TOPLEFT", 8, -35)
    panel.list:SetPoint("TOPRIGHT", -8, -35)
    panel.list:SetHeight(ROW_COUNT * ROW_HEIGHT)
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
    for i = 1, ROW_COUNT do
        panel.rows[i] = CreateRow(panel.list, i)
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
    panel.empty:SetText(_G.NONE or "None")

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

local function FinishRows(panel, total)
    local maximum = math.max(0, total - ROW_COUNT)
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

local function BuildReputation(pane)
    local panel = CreateBase(pane, "reputation", _G.FACTIONS or _G.REPUTATION or "Reputation")
    if panel.built then return panel end
    panel.built = true
    panel.detail.empty:SetText("Select a faction to view reputation options")
    panel.detail.atWar = CreateCheck(panel.detail, _G.AT_WAR or "At War")
    panel.detail.atWar:SetPoint("BOTTOMLEFT", 10, 8)
    panel.detail.inactive = CreateCheck(panel.detail, _G.INACTIVE or "Inactive")
    panel.detail.inactive:SetPoint("LEFT", panel.detail.atWar, "RIGHT", 15, 0)
    panel.detail.watched = CreateCheck(panel.detail, _G.SHOW_FACTION_ON_MAINSCREEN or _G.SHOW_AS_XP or "Show as XP Bar")
    panel.detail.watched:SetPoint("LEFT", panel.detail.inactive, "RIGHT", 15, 0)

    function panel:Refresh()
        SuppressNative("reputation")
        local total = GetNumFactions and (GetNumFactions() or 0) or 0
        FinishRows(self, total)
        for rowNumber, row in ipairs(self.rows) do
            local index = self.offset + rowNumber
            local name, description, standingID, barMin, barMax, barValue,
                atWar, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild
            if index <= total and GetFactionInfo then
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
                StyleRow(row, self.selectedIndex == index, isHeader, rowNumber % 2 == 0)
                row.glyph:SetShown(isHeader and true or false)
                row.glyph:SetText(isCollapsed and "+" or "-")
                row.icon:Hide()
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", isHeader and 29 or (isChild and 38 or 16), 0)
                row.name:SetPoint("RIGHT", -90, 0)
                row.name:SetText(name)
                row.name:SetTextColor(1, 1, 1, isHeader and 0.94 or 0.82)
                local standing = standingID and _G["FACTION_STANDING_LABEL" .. standingID] or ""
                row.value:SetText(isHeader and "" or standing)
                row.bar:SetShown(not isHeader and barMax and barMax > barMin)
                if not isHeader and barMax and barMax > barMin then
                    row.bar:SetMinMaxValues(barMin, barMax)
                    row.bar:SetValue(barValue or barMin)
                    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standingID]
                    row.bar:SetStatusBarColor((c and c.r) or 0.3, (c and c.g) or 0.7, (c and c.b) or 0.9, 0.8)
                end
            else
                row.data = nil
            end
        end

        local selected
        if self.selectedIndex and self.selectedIndex <= total and GetFactionInfo then
            local name, description, standingID, barMin, barMax, barValue,
                atWar, canToggleAtWar, isHeader, _, _, isWatched = GetFactionInfo(self.selectedIndex)
            if name and not isHeader and (not self.selectedName or name == self.selectedName) then
                selected = true
                self.detail.title:SetText(name .. (standingID and ("  |cffaaaaaa" .. (_G["FACTION_STANDING_LABEL" .. standingID] or "") .. "|r") or ""))
                self.detail.description:SetText(description or string.format("%s / %s", Number((barValue or 0) - (barMin or 0)), Number((barMax or 0) - (barMin or 0))))
                self.detail.atWar:SetChecked(atWar)
                self.detail.atWar:SetEnabledState(canToggleAtWar)
                self.detail.inactive:SetChecked(IsFactionInactive and IsFactionInactive(self.selectedIndex))
                self.detail.inactive:SetEnabledState(SetFactionInactive ~= nil)
                self.detail.watched:SetChecked(isWatched)
            end
        end
        self.detail.title:SetShown(selected and true or false)
        self.detail.description:SetShown(selected and true or false)
        self.detail.atWar:SetShown(selected and true or false)
        self.detail.inactive:SetShown(selected and true or false)
        self.detail.watched:SetShown(selected and true or false)
        self.detail.empty:SetShown(not selected)
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
                panel.selectedIndex = data.index
                panel.selectedName = data.name
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
    local panel = CreateBase(pane, "skills", _G.SKILLS or "Skills")
    if panel.built then return panel end
    panel.built = true
    panel.detail.empty:SetText("Select a skill to view its details")
    panel.collapse = CreateTextButton(panel, _G.COLLAPSE_ALL_BUTTON or "Collapse All", 86)
    panel.collapse:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -6)
    panel.unlearn = CreateTextButton(panel.detail, _G.UNLEARN or "Unlearn", 68)
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
                StyleRow(row, self.selectedIndex == index, isHeader, rowNumber % 2 == 0)
                row.glyph:SetShown(isHeader and true or false)
                row.glyph:SetText(isExpanded and "-" or "+")
                row.icon:Hide()
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", isHeader and 29 or 16, 0)
                row.name:SetPoint("RIGHT", -90, 0)
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
    local panel = CreateBase(pane, "currency", _G.CURRENCY or "Currency")
    if panel.built then return panel end
    panel.built = true
    panel.detail.empty:SetText("Select a currency to view its options")
    panel.money = CreateLabel(panel, "OVERLAY", 9, 0.58)
    panel.money:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
    panel.detail.backpack = CreateCheck(panel.detail, _G.TOKEN_SHOW_ON_BACKPACK or "Show in Backpack")
    panel.detail.backpack:SetPoint("BOTTOMLEFT", 10, 8)
    panel.detail.unused = CreateCheck(panel.detail, _G.TOKEN_MARK_UNUSED or "Mark as Unused")
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
                StyleRow(row, self.selectedIndex == index, isHeader, rowNumber % 2 == 0)
                row.glyph:SetShown(isHeader and true or false)
                row.glyph:SetText(isExpanded and "-" or "+")
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
                row.name:SetPoint("LEFT", isHeader and 29 or 53, 0)
                row.name:SetPoint("RIGHT", -90, 0)
                row.name:SetText(name)
                row.name:SetTextColor(1, 1, 1, isHeader and 0.94 or (isUnused and 0.42 or 0.82))
                row.value:SetText(isHeader and "" or Number(quantity))
                row.bar:Hide()
            else
                row.data = nil
            end
        end
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
