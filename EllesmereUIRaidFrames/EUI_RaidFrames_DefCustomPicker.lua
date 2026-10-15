-------------------------------------------------------------------------------
--  EUI_RaidFrames_DefCustomPicker.lua
--  Icon-grid picker for the Defensives & Externals "Custom" spell list.
--  Mirrors the Raid Cooldowns spell page: one icon per spell, grouped by
--  class; selected icons are full color with an accent border. The catalog
--  comes from the CDM aura catalog (tagged defensives/externals plus
--  recipient-side utility buffs). Selected IDs the catalog does not know are
--  listed under "Other" so they stay removable, and any ID can be added by
--  hand at the bottom.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local CLASS_ORDER = {
    "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN",
    "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}
local POPUP_W, POPUP_H = 620, 540
local PAD = 20
local CELL_W, CELL_H, CELL_ICON = 84, 64, 34
local HEADER_H = 26
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local popup
local getSet, setSet

-- The saved list is a complete set: explicit false keeps a removed default
-- (Freedom) removed, since NewDB only fills missing default keys. Writes go
-- through a copy so the party context never mutates the raid table.
local function CopySet()
    local copy = {}
    local cur = getSet and getSet()
    if type(cur) == "table" then
        for id, enabled in pairs(cur) do copy[id] = enabled end
    end
    return copy
end

local function IsSelected(spellIDs)
    local cur = getSet and getSet()
    if type(cur) ~= "table" then return false end
    for _, id in ipairs(spellIDs) do
        if cur[id] == true then return true end
    end
    return false
end

local function SetSelected(spellIDs, enabled)
    local copy = CopySet()
    for _, id in ipairs(spellIDs) do copy[id] = enabled and true or false end
    setSet(copy)
end

local function BuildSections()
    local entries = C_CooldownViewer and C_CooldownViewer.GetDefensivePickerEntries
        and C_CooldownViewer.GetDefensivePickerEntries() or {}
    local byClass, known = {}, {}
    for _, entry in ipairs(entries) do
        local name, _, icon = GetSpellInfo(entry.iconSpellID or entry.spellID)
        entry.name = entry.displayName or name or ("Spell " .. tostring(entry.spellID))
        entry.icon = icon or FALLBACK_ICON
        entry.tooltipID = entry.iconSpellID or entry.spellID
        local class = entry.class or "OTHER"
        byClass[class] = byClass[class] or {}
        table.insert(byClass[class], entry)
        for _, id in ipairs(entry.spellIDs) do known[id] = true end
    end

    -- Selected IDs outside the catalog (typed by hand or from older lists).
    local cur = getSet and getSet()
    if type(cur) == "table" then
        local extra = {}
        for id, enabled in pairs(cur) do
            local numericID = tonumber(id)
            if enabled == true and numericID and not known[numericID] then
                extra[#extra + 1] = numericID
            end
        end
        table.sort(extra)
        for _, id in ipairs(extra) do
            local name, _, icon = GetSpellInfo(id)
            byClass.OTHER = byClass.OTHER or {}
            table.insert(byClass.OTHER, {
                name = name or ("Spell " .. id), icon = icon or FALLBACK_ICON,
                spellIDs = { id }, tooltipID = id,
            })
        end
    end

    local sections = {}
    local order = { unpack(CLASS_ORDER) }
    order[#order + 1] = "OTHER"
    for _, class in ipairs(order) do
        local list = byClass[class]
        if list and #list > 0 then
            table.sort(list, function(a, b) return a.name < b.name end)
            local title = class == "OTHER" and EllesmereUI.L("Other")
                or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
            sections[#sections + 1] = { class = class, title = title, entries = list }
        end
    end
    return sections
end

local function RefreshCell(cell)
    local selected = IsSelected(cell.entry.spellIDs)
    local r, g, b = EllesmereUI.GetAccentColor()
    cell._icon:SetDesaturated(not selected)
    cell._icon:SetAlpha(selected and 1 or 0.4)
    cell._label:SetAlpha(selected and 1 or 0.45)
    if selected then
        cell._border:SetColor(r, g, b, 1)
    else
        cell._border:SetColor(1, 1, 1, 0.08)
    end
end

local function OnCellClick(self)
    SetSelected(self.entry.spellIDs, not IsSelected(self.entry.spellIDs))
    RefreshCell(self)
    if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
end

local function OnCellEnter(self)
    self._hover:Show()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("spell:" .. self.entry.tooltipID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(EllesmereUI.L(IsSelected(self.entry.spellIDs)
        and "Shown - click to remove." or "Hidden - click to show."), 0.72, 0.72, 0.72)
    GameTooltip:Show()
end

local function OnCellLeave(self)
    self._hover:Hide()
    GameTooltip:Hide()
end

local function CreateCell(parent)
    local PPx = EllesmereUI.PanelPP
    local cell = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    PPx.Size(cell, CELL_W - 4, CELL_H - 4)

    local iconHolder = EllesmereUI.SafeCreateFrame("Frame", nil, cell)
    PPx.Size(iconHolder, CELL_ICON, CELL_ICON)
    PPx.Point(iconHolder, "TOP", cell, "TOP", 0, -4)
    cell._icon = iconHolder:CreateTexture(nil, "ARTWORK")
    cell._icon:SetAllPoints()
    cell._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell._border = EllesmereUI.MakeBorder(iconHolder, 1, 1, 1, 0.08, PPx)

    cell._hover = EllesmereUI.SolidTex(cell, "BACKGROUND", 1, 1, 1, 0.05)
    cell._hover:SetAllPoints()
    cell._hover:Hide()

    cell._label = EllesmereUI.MakeFont(cell, 10, nil, 1, 1, 1, 0.9)
    PPx.Point(cell._label, "TOP", iconHolder, "BOTTOM", 0, -4)
    PPx.Size(cell._label, CELL_W - 8, 12)
    cell._label:SetJustifyH("CENTER")
    cell._label:SetWordWrap(false)

    cell:SetScript("OnClick", OnCellClick)
    cell:SetScript("OnEnter", OnCellEnter)
    cell:SetScript("OnLeave", OnCellLeave)
    return cell
end

local function CreateHeader(parent)
    local hdr = EllesmereUI.SafeCreateFrame("Frame", nil, parent)
    hdr:SetHeight(HEADER_H)
    hdr._label = EllesmereUI.MakeFont(hdr, 11, nil, 1, 1, 1, 1)
    hdr._label:SetPoint("LEFT", hdr, "LEFT", 0, 0)
    local line = hdr:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", hdr._label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", hdr, "RIGHT", 0, 0)
    line:SetTexture(1, 1, 1, 0.1)
    return hdr
end

-- Lay out every section into the scroll child, reusing pooled frames.
local function Rebuild()
    local child = popup._child
    for _, cell in ipairs(popup._cells) do cell:Hide() end
    for _, hdr in ipairs(popup._headers) do hdr:Hide() end

    local sections = BuildSections()
    local width = POPUP_W - PAD * 2
    local perRow = math.max(1, math.floor(width / CELL_W))
    local y, cellIdx = 0, 0

    for sIdx, section in ipairs(sections) do
        local hdr = popup._headers[sIdx]
        if not hdr then
            hdr = CreateHeader(child)
            popup._headers[sIdx] = hdr
        end
        hdr:ClearAllPoints()
        hdr:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        hdr:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[section.class]
        hdr._label:SetText(string.upper(section.title))
        if cc then
            hdr._label:SetTextColor(cc.r, cc.g, cc.b, 1)
        else
            hdr._label:SetTextColor(0.8, 0.8, 0.8, 1)
        end
        hdr:Show()
        y = y - HEADER_H

        for i, entry in ipairs(section.entries) do
            cellIdx = cellIdx + 1
            local cell = popup._cells[cellIdx]
            if not cell then
                cell = CreateCell(child)
                popup._cells[cellIdx] = cell
            end
            local col = (i - 1) % perRow
            local row = math.floor((i - 1) / perRow)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", child, "TOPLEFT", col * CELL_W, y - row * CELL_H)
            cell.entry = entry
            cell._icon:SetTexture(entry.icon)
            cell._label:SetText(entry.name)
            RefreshCell(cell)
            cell:Show()
        end
        y = y - math.ceil(#section.entries / perRow) * CELL_H - 6
    end

    if #sections == 0 then
        popup._empty:Show()
    else
        popup._empty:Hide()
    end
    child:SetHeight(math.max(1, -y))
    popup._scroll:SetVerticalScroll(0)
end

local function MakeButton(parent, text, w, onClick)
    local ar, ag, ab = EllesmereUI.GetAccentColor()
    local btn = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    btn:SetSize(w, 28)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture(ar, ag, ab, 0.15)
    EllesmereUI.MakeBorder(btn, ar, ag, ab, 0.3, EllesmereUI.PP)
    local lbl = EllesmereUI.MakeFont(btn, 12, nil, ar, ag, ab, 0.9)
    lbl:SetPoint("CENTER")
    lbl:SetText(EllesmereUI.L(text))
    btn:SetScript("OnEnter", function() lbl:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnLeave", function() lbl:SetTextColor(ar, ag, ab, 0.9) end)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function CreatePopup()
    local dimmer = EllesmereUI.SafeCreateFrame("Frame", "EUI_RF_DefCustomPickerDimmer", UIParent)
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    dimmer:SetAllPoints(UIParent)
    dimmer:EnableMouse(true)
    dimmer:Hide()
    local dimTex = dimmer:CreateTexture(nil, "BACKGROUND")
    dimTex:SetAllPoints(); dimTex:SetTexture(0, 0, 0, 0.25)
    dimmer:SetScript("OnMouseDown", function(self) self:Hide() end)
    dimmer:SetScript("OnHide", function()
        GameTooltip:Hide()
        if popup and popup._onClose then popup._onClose() end
    end)
    tinsert(UISpecialFrames, "EUI_RF_DefCustomPickerDimmer")

    local p = EllesmereUI.SafeCreateFrame("Frame", nil, dimmer)
    p:SetSize(POPUP_W, POPUP_H)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetFrameLevel(dimmer:GetFrameLevel() + 10)
    p:EnableMouse(true)
    local scale = EllesmereUI.GetPopupScale and EllesmereUI.GetPopupScale() or 1
    p:SetScale(scale)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture(0.06, 0.08, 0.10, 1)
    EllesmereUI.MakeBorder(p, 1, 1, 1, 0.15, EllesmereUI.PP)
    p._dimmer = dimmer

    local title = EllesmereUI.MakeFont(p, 14, nil, 1, 1, 1, 1)
    title:SetPoint("TOP", p, "TOP", 0, -16)
    title:SetText(EllesmereUI.L("Custom Defensive Spells"))
    local hint = EllesmereUI.MakeFont(p, 11, nil, 0.7, 0.7, 0.7, 0.85)
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText(EllesmereUI.L("Click an icon to show or hide it in the defensives row, from any caster."))

    local scroll = EllesmereUI.SafeCreateFrame("ScrollFrame", nil, p)
    scroll:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -60)
    scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 56)
    scroll:EnableMouseWheel(true)
    local child = EllesmereUI.SafeCreateFrame("Frame", nil, scroll)
    child:SetSize(POPUP_W - PAD * 2, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
        local cur = self:GetVerticalScroll() - delta * CELL_H
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur)))
    end)
    p._scroll, p._child = scroll, child
    p._cells, p._headers = {}, {}

    local empty = EllesmereUI.MakeFont(p, 12, nil, 0.7, 0.7, 0.7, 0.85)
    empty:SetPoint("CENTER", scroll, "CENTER", 0, 0)
    empty:SetText(EllesmereUI.L("Enable the Cooldown Manager module to browse spells, or add spell IDs below."))
    empty:Hide()
    p._empty = empty

    -- Footer: add an arbitrary spell ID | Clear All | Done
    local box = EllesmereUI.SafeCreateFrame("EditBox", nil, p)
    box:SetSize(110, 28)
    box:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD, 16)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(9)
    box:SetFont(EllesmereUI.EXPRESSWAY or "Fonts\\FRIZQT__.TTF", 12, "")
    box:SetTextColor(1, 1, 1, 0.9)
    box:SetTextInsets(8, 8, 0, 0)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints(); boxBg:SetTexture(0.04, 0.06, 0.08, 1)
    EllesmereUI.MakeBorder(box, 1, 1, 1, 0.12, EllesmereUI.PP)
    local ph = EllesmereUI.MakeFont(box, 11, nil, 0.7, 0.7, 0.7, 0.45)
    ph:SetPoint("LEFT", box, "LEFT", 8, 0)
    ph:SetText(EllesmereUI.L("Spell ID"))
    box:SetScript("OnTextChanged", function(self)
        if (self:GetText() or "") == "" then ph:Show() else ph:Hide() end
    end)
    local function AddTypedID()
        local id = tonumber(box:GetText())
        box:SetText("")
        box:ClearFocus()
        if id and id > 0 then
            SetSelected({ id }, true)
            Rebuild()
        end
    end
    box:SetScript("OnEnterPressed", AddTypedID)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local addBtn = MakeButton(p, "Add", 60, AddTypedID)
    addBtn:SetPoint("LEFT", box, "RIGHT", 6, 0)

    local doneBtn = MakeButton(p, "Done", 80, function() dimmer:Hide() end)
    doneBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 16)
    local clearBtn = MakeButton(p, "Clear All", 90, function()
        local copy = CopySet()
        for id in pairs(copy) do copy[id] = false end
        setSet(copy)
        for _, cell in ipairs(p._cells) do
            if cell:IsShown() then RefreshCell(cell) end
        end
    end)
    clearBtn:SetPoint("RIGHT", doneBtn, "LEFT", -8, 0)

    return p
end

-- getFn returns the current spell set; setFn receives a replacement set.
-- onClose runs whenever the picker is dismissed.
function ns.ShowDefCustomSpellPicker(getFn, setFn, onClose)
    if EllesmereUI.HideWidgetTooltip then EllesmereUI.HideWidgetTooltip() end
    popup = popup or CreatePopup()
    getSet, setSet = getFn, setFn
    popup._onClose = onClose
    popup._dimmer:Show()
    Rebuild()
end

-- Number of distinct catalog spells (plus hand-added IDs) currently selected.
function ns.CountDefCustomSpells(set)
    if type(set) ~= "table" then return 0 end
    local count, counted = 0, {}
    local entries = C_CooldownViewer and C_CooldownViewer.GetDefensivePickerEntries
        and C_CooldownViewer.GetDefensivePickerEntries() or {}
    for _, entry in ipairs(entries) do
        local hit = false
        for _, id in ipairs(entry.spellIDs) do
            if set[id] == true then hit = true end
            counted[id] = true
        end
        if hit then count = count + 1 end
    end
    for id, enabled in pairs(set) do
        if enabled == true and not counted[tonumber(id) or 0] then count = count + 1 end
    end
    return count
end
