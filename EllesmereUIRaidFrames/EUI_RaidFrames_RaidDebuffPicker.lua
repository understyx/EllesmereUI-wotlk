-------------------------------------------------------------------------------
--  EUI_RaidFrames_RaidDebuffPicker.lua
--  Icon-grid editor for the per-instance raid debuff lists. Left rail: one
--  entry per instance (plus Everywhere and Hidden Debuffs); right: the
--  instance's debuffs in one section per boss (trash and hand-added last),
--  tracked icons full color with an accent border. Click a section header to
--  toggle that boss's debuffs. Click toggles a debuff; right-click opens its settings (health bar color,
--  hide everywhere, remove a hand-added one). Any spell ID can be added to the selected list
--  from the footer.
--  Catalog and saved-data format: EUI_RaidFrames_RaidDebuffs.lua.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local POPUP_W, POPUP_H = 760, 560
local PAD = 20
local RAIL_W, RAIL_ROW_H = 190, 26
local CELL_W, CELL_H, CELL_ICON = 84, 64, 34
local HEADER_H, SECTION_GAP = 24, 8
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local HIDDEN_KEY = "_hidden"

local popup
local opts          -- { getTracked, setTracked, getHidden, setHidden,
                    --   getSettings, setSettings, onClose }
local selectedKey
local settingsPanel

local L = function(s) return EllesmereUI.L(s) end

local function Toggle(obj, show)
    if show then obj:Show() else obj:Hide() end
end

-------------------------------------------------------------------------------
--  Data access (writes always go through fresh copies so the party context
--  never mutates the raid table and the runtime caches miss correctly)
-------------------------------------------------------------------------------
local function Tracked()
    local t = opts and opts.getTracked()
    return type(t) == "table" and t or {}
end

local function Hidden()
    local t = opts and opts.getHidden()
    return type(t) == "table" and t or {}
end

local function CopyTracked()
    local copy = {}
    for key, ov in pairs(Tracked()) do
        if type(ov) == "table" then
            copy[key] = {}
            for id, v in pairs(ov) do copy[key][id] = v end
        end
    end
    return copy
end

local function CopyHidden()
    local copy = {}
    for id, v in pairs(Hidden()) do copy[id] = v end
    return copy
end

-- Per-spell settings. Entries are replaced whole, never mutated, so a
-- shallow copy of the outer table is enough to bust the runtime cache.
local function SpellSettings(id)
    local t = opts and opts.getSettings and opts.getSettings()
    local cfg = type(t) == "table" and t[id]
    return type(cfg) == "table" and cfg or nil
end

local function WriteSpellSettings(id, cfg)
    local copy = {}
    local t = opts.getSettings()
    if type(t) == "table" then
        for k, v in pairs(t) do copy[k] = v end
    end
    copy[id] = cfg
    opts.setSettings(copy)
end

local function HealthColorOf(cfg)
    return (cfg and cfg.healthColor) or ns.RD_DEFAULT_HEALTH_COLOR
end

local function IsHiddenPage() return selectedKey == HIDDEN_KEY end

local function SelectedInstance()
    return ns.RAID_DEBUFF_BY_KEY[selectedKey]
end

local function IsOn(id)
    if IsHiddenPage() then return Hidden()[id] == true end
    return ns.RD_IsTracked(Tracked(), SelectedInstance(), id)
end

-- value: true / false, or nil to drop a hand-added entry entirely.
local function SetOn(id, value)
    if IsHiddenPage() then
        local copy = CopyHidden()
        copy[id] = value and true or nil
        opts.setHidden(copy)
        return
    end
    local inst = SelectedInstance()
    local copy = CopyTracked()
    local ov = copy[inst.key] or {}
    if value == nil or (inst.defaults[id] and value == true) then
        ov[id] = nil   -- back to the catalog default
    else
        ov[id] = value
    end
    copy[inst.key] = next(ov) and ov or nil
    opts.setTracked(copy)
end

local function IsCustom(id)
    if IsHiddenPage() then return true end
    return not SelectedInstance().defaults[id]
end

local function PageSpells()
    if IsHiddenPage() then
        local list = {}
        for id, v in pairs(Hidden()) do
            local n = tonumber(id)
            if v == true and n then list[#list + 1] = n end
        end
        table.sort(list)
        return list
    end
    return ns.RD_GetInstanceSpells(Tracked(), SelectedInstance())
end

-- Sections for the current page. A page with a single unnamed group (Hidden
-- Debuffs, Everywhere, an instance with no catalog) draws no header.
local function PageGroups()
    if IsHiddenPage() then return { { spells = PageSpells() } } end
    local groups = ns.RD_GetInstanceGroups(Tracked(), SelectedInstance())
    if #groups == 1 and groups[1].custom then groups[1].custom = nil end
    return groups
end

-- Switch a set of the selected instance's spells together: all on unless
-- they already are, else all off.
local function ToggleSpells(spells)
    local anyOff = false
    for _, id in ipairs(spells) do
        if not IsOn(id) then anyOff = true; break end
    end
    local inst = SelectedInstance()
    local copy = CopyTracked()
    local ov = copy[inst.key] or {}
    for _, id in ipairs(spells) do
        if inst.defaults[id] then
            ov[id] = (not anyOff) and false or nil
        else
            ov[id] = anyOff
        end
    end
    copy[inst.key] = next(ov) and ov or nil
    opts.setTracked(copy)
end

local function RailCount(key)
    if key == HIDDEN_KEY then
        local n = 0
        for _, v in pairs(Hidden()) do if v == true then n = n + 1 end end
        return n
    end
    return ns.RD_CountTracked(Tracked(), ns.RAID_DEBUFF_BY_KEY[key])
end

-------------------------------------------------------------------------------
--  Shared widgets
-------------------------------------------------------------------------------
local function MakeButton(parent, text, w, onClick)
    local ar, ag, ab = EllesmereUI.GetAccentColor()
    local btn = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    btn:SetSize(w, 28)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture(ar, ag, ab, 0.15)
    EllesmereUI.MakeBorder(btn, ar, ag, ab, 0.3, EllesmereUI.PP)
    local lbl = EllesmereUI.MakeFont(btn, 12, nil, ar, ag, ab, 0.9)
    lbl:SetPoint("CENTER")
    lbl:SetText(L(text))
    btn:SetScript("OnEnter", function() lbl:SetTextColor(1, 1, 1, 1) end)
    btn:SetScript("OnLeave", function() lbl:SetTextColor(ar, ag, ab, 0.9) end)
    btn:SetScript("OnClick", onClick)
    btn._label = lbl
    return btn
end

-------------------------------------------------------------------------------
--  Grid cells
-------------------------------------------------------------------------------
local Rebuild, RefreshRail

local function RefreshCell(cell)
    local cfg = not IsHiddenPage() and SpellSettings(cell.spellID)
    if cfg and cfg.colorHealth then
        local c = HealthColorOf(cfg)
        cell._tint:SetTexture(c.r, c.g, c.b, 1)
        cell._tintFrame:Show()
    else
        cell._tintFrame:Hide()
    end
    local on = IsOn(cell.spellID)
    local r, g, b = EllesmereUI.GetAccentColor()
    cell._icon:SetDesaturated(not on)
    cell._icon:SetAlpha(on and 1 or 0.4)
    cell._label:SetAlpha(on and 1 or 0.45)
    if on then
        cell._border:SetColor(r, g, b, 1)
    else
        cell._border:SetColor(1, 1, 1, 0.08)
    end
end

local function OnCellEnter(self)
    self._hover:Show()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("spell:" .. self.spellID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L("Spell ID") .. ": " .. self.spellID, 0.72, 0.72, 0.72)
    if IsHiddenPage() then
        GameTooltip:AddLine(L("Hidden everywhere - click to show again."), 0.72, 0.72, 0.72)
    else
        GameTooltip:AddLine(L(IsOn(self.spellID)
            and "Tracked - click to stop tracking." or "Not tracked - click to track."), 0.72, 0.72, 0.72)
        local cfg = SpellSettings(self.spellID)
        if cfg and cfg.colorHealth then
            GameTooltip:AddLine(L("Colors the health bar while active."), 0.72, 0.72, 0.72)
        end
        GameTooltip:AddLine(L("Right-click for settings."), 0.72, 0.72, 0.72)
    end
    GameTooltip:Show()
end

local ShowSettings

local function OnCellClick(self, button)
    if IsHiddenPage() then
        SetOn(self.spellID, nil)
        Rebuild()
        return
    end
    if button == "RightButton" then
        GameTooltip:Hide()
        ShowSettings(self)
        return
    end
    SetOn(self.spellID, not IsOn(self.spellID))
    RefreshCell(self)
    if self._header then RefreshHeader(self._header) end
    RefreshRail()
    if GameTooltip:IsOwned(self) then OnCellEnter(self) end
end

local function OnCellLeave(self)
    self._hover:Hide()
    GameTooltip:Hide()
end

local function CreateCell(parent)
    local PPx = EllesmereUI.PanelPP
    local cell = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    PPx.Size(cell, CELL_W - 4, CELL_H - 4)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local iconHolder = EllesmereUI.SafeCreateFrame("Frame", nil, cell)
    PPx.Size(iconHolder, CELL_ICON, CELL_ICON)
    PPx.Point(iconHolder, "TOP", cell, "TOP", 0, -4)
    cell._icon = iconHolder:CreateTexture(nil, "ARTWORK")
    cell._icon:SetAllPoints()
    cell._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell._border = EllesmereUI.MakeBorder(iconHolder, 1, 1, 1, 0.08, PPx)
    -- Health bar color marker (bottom-right corner of the icon).
    cell._tintFrame = EllesmereUI.SafeCreateFrame("Frame", nil, iconHolder)
    PPx.Size(cell._tintFrame, 10, 10)
    PPx.Point(cell._tintFrame, "BOTTOMRIGHT", iconHolder, "BOTTOMRIGHT", 3, -3)
    cell._tintFrame:SetFrameLevel(iconHolder:GetFrameLevel() + 2)
    local tintBg = cell._tintFrame:CreateTexture(nil, "BACKGROUND")
    tintBg:SetAllPoints(); tintBg:SetTexture(0, 0, 0, 1)
    cell._tint = cell._tintFrame:CreateTexture(nil, "ARTWORK")
    PPx.SetInside(cell._tint, cell._tintFrame, 1, 1)
    cell._tintFrame:Hide()

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

-------------------------------------------------------------------------------
--  Section headers (one per boss / trash / custom group)
-------------------------------------------------------------------------------
local function GroupLabel(group)
    if group.custom then return L("Custom") end
    if group.trash then return L("Trash") end
    return group.name
end

local function RefreshHeader(h)
    local on = 0
    for _, id in ipairs(h.spells) do
        if IsOn(id) then on = on + 1 end
    end
    h._count:SetText(on .. "/" .. #h.spells)
    local r, g, b = EllesmereUI.GetAccentColor()
    if on > 0 then
        h._count:SetTextColor(r, g, b, 1)
    else
        h._count:SetTextColor(0.7, 0.7, 0.7, 0.6)
    end
end

local function CreateHeader(parent)
    local h = EllesmereUI.SafeCreateFrame("Button", nil, parent)
    h:SetHeight(HEADER_H)
    h._label = EllesmereUI.MakeFont(h, 11, nil, 1, 1, 1, 0.85)
    h._label:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 2, 6)
    h._count = EllesmereUI.MakeFont(h, 10, nil, 0.7, 0.7, 0.7, 0.6)
    h._count:SetPoint("LEFT", h._label, "RIGHT", 8, 0)
    local line = EllesmereUI.SolidTex(h, "ARTWORK", 1, 1, 1, 0.08)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 1)
    line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -4, 1)
    h:SetScript("OnClick", function(self)
        ToggleSpells(self.spells)
        Rebuild()
    end)
    h:SetScript("OnEnter", function(self)
        self._label:SetTextColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self._label:GetText(), 1, 1, 1)
        GameTooltip:AddLine(L("Click to toggle every debuff in this section."), 0.72, 0.72, 0.72)
        GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function(self)
        self._label:SetTextColor(1, 1, 1, 0.85)
        GameTooltip:Hide()
    end)
    return h
end

-------------------------------------------------------------------------------
--  Per-spell settings popout (right-click a cell)
-------------------------------------------------------------------------------
local SETTINGS_W = 230

local function HideSettings()
    if settingsPanel then settingsPanel:Hide() end
end

local function RefreshSettings()
    local f = settingsPanel
    local cfg = SpellSettings(f.spellID)
    f._applyCheck(cfg and cfg.colorHealth, f._colorRow:IsMouseOver())
    f._updateSwatch()
    if f._cell and f._cell.spellID == f.spellID then RefreshCell(f._cell) end
end

local function CreateSettingsPanel()
    local f = EllesmereUI.SafeCreateFrame("Frame", nil, popup)
    settingsPanel = f
    f:SetWidth(SETTINGS_W)
    -- Just above the grid (cells reach popup + 6); kept low so the panel's
    -- children stay at modest frame levels too.
    f:SetFrameLevel(popup:GetFrameLevel() + 10)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f._noCapture = true   -- keep the swatch out of Spec Overrides capture
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture(0.04, 0.06, 0.08, 1)
    EllesmereUI.MakeBorder(f, 1, 1, 1, 0.18, EllesmereUI.PP)

    f._title = EllesmereUI.MakeFont(f, 12, nil, 1, 1, 1, 1)
    f._title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    f._title:SetWidth(SETTINGS_W - 20)
    f._title:SetJustifyH("LEFT")
    f._title:SetWordWrap(false)

    -- Color health bar: checkbox row + color swatch.
    local row = EllesmereUI.SafeCreateFrame("Button", nil, f)
    row:SetHeight(26)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -30)
    row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -30)
    local box, _, _, applyCheck = EllesmereUI.BuildCheckboxControl(row, row:GetFrameLevel() + 1)
    box:SetPoint("LEFT", row, "LEFT", 4, 0)
    local lbl = EllesmereUI.MakeFont(row, 12, nil, 1, 1, 1, 0.9)
    lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
    lbl:SetText(L("Color health bar"))
    f._colorRow, f._applyCheck = row, applyCheck

    local function SetColorHealth(on, color)
        local cfg = SpellSettings(f.spellID)
        local col = color or (cfg and cfg.healthColor)
        WriteSpellSettings(f.spellID, (on or col) and { colorHealth = on or nil, healthColor = col } or nil)
        RefreshSettings()
    end
    row:SetScript("OnClick", function()
        local cfg = SpellSettings(f.spellID)
        SetColorHealth(not (cfg and cfg.colorHealth))
    end)
    row:SetScript("OnEnter", function()
        local cfg = SpellSettings(f.spellID)
        applyCheck(cfg and cfg.colorHealth, true)
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Color health bar"), 1, 1, 1)
        GameTooltip:AddLine(L("Recolors the unit's health bar while this debuff is on it. The first tracked debuff with a color wins."), 0.72, 0.72, 0.72, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        local cfg = SpellSettings(f.spellID)
        applyCheck(cfg and cfg.colorHealth, false)
        GameTooltip:Hide()
    end)

    local swatch, updateSwatch = EllesmereUI.BuildColorSwatch(f, row:GetFrameLevel() + 2,
        function()
            local c = HealthColorOf(SpellSettings(f.spellID))
            return c.r, c.g, c.b, 1
        end,
        function(r, g, b)
            -- Picking a color implies wanting it shown.
            SetColorHealth(true, { r = r, g = g, b = b })
        end, false, 18)
    swatch:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    f._updateSwatch = updateSwatch

    -- Untrack here and add to Hidden Debuffs in one step. Catalog entries
    -- are switched off; hand-added ones leave the list.
    f._hide = MakeButton(f, "Hide everywhere", SETTINGS_W - 20, function()
        local id = f.spellID
        SetOn(id, IsCustom(id) and nil or false)
        local hidden = CopyHidden()
        hidden[id] = true
        opts.setHidden(hidden)
        Rebuild()
    end)
    f._hide:SetHeight(24)
    f._hide:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 4, -8)
    f._hide:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L("Hide everywhere"), 1, 1, 1)
        GameTooltip:AddLine(L("Stops tracking it here and never shows it on any frame. Undo from Hidden Debuffs."), 0.72, 0.72, 0.72, true)
        GameTooltip:Show()
    end)
    f._hide:HookScript("OnLeave", function() GameTooltip:Hide() end)

    f._remove = MakeButton(f, "Remove from list", SETTINGS_W - 20, function()
        SetOn(f.spellID, nil)
        HideSettings()
        Rebuild()
    end)
    f._remove:SetHeight(24)
    f._remove:SetPoint("TOPLEFT", f._hide, "BOTTOMLEFT", 0, -8)

    -- Dismiss on a left click anywhere else (the color picker is its own
    -- frame, so leave the panel up while it is open).
    f:SetScript("OnUpdate", function(self)
        if IsMouseButtonDown("LeftButton") and not self:IsMouseOver() then
            local cp = EllesmereUI._colorPickerPopup
            if not (cp and cp:IsShown()) then self:Hide() end
        end
    end)
    return f
end

ShowSettings = function(cell)
    if not (opts and opts.getSettings) then return end
    local f = settingsPanel or CreateSettingsPanel()
    f.spellID, f._cell = cell.spellID, cell
    f._title:SetText(GetSpellInfo(cell.spellID) or ("Spell " .. cell.spellID))
    local custom = IsCustom(cell.spellID)
    Toggle(f._remove, custom)
    f:SetHeight(custom and 130 or 98)
    -- Open toward the popup's center so it stays inside the window.
    f:ClearAllPoints()
    local cx = cell:GetCenter()
    local px = popup:GetCenter()
    if cx and px and cx > px then
        f:SetPoint("TOPRIGHT", cell, "TOPLEFT", -2, 0)
    else
        f:SetPoint("TOPLEFT", cell, "TOPRIGHT", 2, 0)
    end
    f:Show()
    RefreshSettings()
end

-------------------------------------------------------------------------------
--  Left rail
-------------------------------------------------------------------------------
local function RailEntries()
    local list = {}
    for _, inst in ipairs(ns.RAID_DEBUFF_INSTANCES) do
        list[#list + 1] = { key = inst.key, name = inst.name }
    end
    list[#list + 1] = { key = HIDDEN_KEY, name = "Hidden Debuffs" }
    return list
end

RefreshRail = function()
    local here = ns.RD_GetCurrentInstanceKey and ns.RD_GetCurrentInstanceKey()
    local r, g, b = EllesmereUI.GetAccentColor()
    for _, row in ipairs(popup._railRows) do
        local selected = row.key == selectedKey
        row._bg:SetAlpha(selected and 1 or 0)
        Toggle(row._accent, selected)
        row._label:SetTextColor(1, 1, 1, selected and 1 or 0.7)
        row._count:SetText(tostring(RailCount(row.key)))
        Toggle(row._here, row.key == here)
        row._here:SetTextColor(r, g, b, 1)
    end
end

local function CreateRail(p)
    local rail = EllesmereUI.SafeCreateFrame("Frame", nil, p)
    rail:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -60)
    rail:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD, 56)
    rail:SetWidth(RAIL_W)
    local railBg = rail:CreateTexture(nil, "BACKGROUND")
    railBg:SetAllPoints(); railBg:SetTexture(0.04, 0.06, 0.08, 1)
    EllesmereUI.MakeBorder(rail, 1, 1, 1, 0.08, EllesmereUI.PP)

    local r, g, b = EllesmereUI.GetAccentColor()
    p._railRows = {}
    for i, entry in ipairs(RailEntries()) do
        local row = EllesmereUI.SafeCreateFrame("Button", nil, rail)
        row:SetHeight(RAIL_ROW_H)
        local yOff = -(i - 1) * RAIL_ROW_H - 4
        -- Hidden Debuffs sits apart from the instance list.
        if entry.key == HIDDEN_KEY then yOff = yOff - 10 end
        row:SetPoint("TOPLEFT", rail, "TOPLEFT", 1, yOff)
        row:SetPoint("TOPRIGHT", rail, "TOPRIGHT", -1, yOff)
        row.key = entry.key

        row._bg = row:CreateTexture(nil, "BACKGROUND")
        row._bg:SetAllPoints(); row._bg:SetTexture(r, g, b, 0.12)
        row._accent = row:CreateTexture(nil, "ARTWORK")
        row._accent:SetPoint("TOPLEFT"); row._accent:SetPoint("BOTTOMLEFT")
        row._accent:SetWidth(2); row._accent:SetTexture(r, g, b, 1)
        row._hover = EllesmereUI.SolidTex(row, "BACKGROUND", 1, 1, 1, 0.04)
        row._hover:SetAllPoints(); row._hover:Hide()

        row._label = EllesmereUI.MakeFont(row, 11, nil, 1, 1, 1, 0.7)
        row._label:SetPoint("LEFT", row, "LEFT", 10, 0)
        row._label:SetText(L(entry.name))
        row._count = EllesmereUI.MakeFont(row, 10, nil, 0.7, 0.7, 0.7, 0.8)
        row._count:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row._here = EllesmereUI.MakeFont(row, 10, nil, r, g, b, 1)
        row._here:SetPoint("RIGHT", row._count, "LEFT", -6, 0)
        row._here:SetText(L("here"))

        row:SetScript("OnClick", function(self)
            selectedKey = self.key
            Rebuild()
        end)
        row:SetScript("OnEnter", function(self) self._hover:Show() end)
        row:SetScript("OnLeave", function(self) self._hover:Hide() end)
        p._railRows[i] = row
    end
end

-------------------------------------------------------------------------------
--  Layout
-------------------------------------------------------------------------------
Rebuild = function()
    HideSettings()
    local child = popup._child
    for _, cell in ipairs(popup._cells) do cell:Hide() end

    local hiddenPage = IsHiddenPage()
    local inst = SelectedInstance()
    popup._pageTitle:SetText(string.upper(L(hiddenPage and "Hidden Debuffs" or inst.name)))
    if hiddenPage then
        popup._pageHint:SetText(L("Never shown on any frame, whatever the filter. Click an icon to show it again."))
    elseif inst.global then
        popup._pageHint:SetText(L("Tracked in every instance and in the open world."))
    else
        popup._pageHint:SetText(L("Tracked only while you are inside this instance."))
    end
    Toggle(popup._toggleAll, not hiddenPage)

    for _, h in ipairs(popup._headers) do h:Hide() end

    local width = POPUP_W - PAD * 3 - RAIL_W
    local perRow = math.max(1, math.floor(width / CELL_W))
    local y, nCells, nHeaders, total = 0, 0, 0, 0
    for _, group in ipairs(PageGroups()) do
        local spells = group.spells
        local header
        if #spells > 0 and (group.name or group.custom) then
            if nHeaders > 0 then y = y + SECTION_GAP end
            nHeaders = nHeaders + 1
            header = popup._headers[nHeaders]
            if not header then
                header = CreateHeader(child)
                popup._headers[nHeaders] = header
            end
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            header:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
            header.spells = spells
            header._label:SetText(GroupLabel(group))
            RefreshHeader(header)
            header:Show()
            y = y + HEADER_H + 4
        end
        for i, id in ipairs(spells) do
            nCells = nCells + 1
            local cell = popup._cells[nCells]
            if not cell then
                cell = CreateCell(child)
                popup._cells[nCells] = cell
            end
            local col = (i - 1) % perRow
            local row = math.floor((i - 1) / perRow)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", child, "TOPLEFT", col * CELL_W, -(y + row * CELL_H))
            cell.spellID = id
            cell._header = header
            local name, _, icon = GetSpellInfo(id)
            cell._icon:SetTexture(icon or FALLBACK_ICON)
            cell._label:SetText(name or ("Spell " .. id))
            RefreshCell(cell)
            cell:Show()
        end
        y = y + math.ceil(#spells / perRow) * CELL_H
        total = total + #spells
    end

    if total == 0 then
        popup._empty:SetText(L(hiddenPage and "No hidden debuffs. Add a spell ID below to hide it everywhere."
            or "No debuffs listed. Add a spell ID below."))
        popup._empty:Show()
    else
        popup._empty:Hide()
    end
    child:SetHeight(math.max(1, y))
    popup._scroll:SetVerticalScroll(0)
    RefreshRail()
end

local function CreatePopup()
    local dimmer = EllesmereUI.SafeCreateFrame("Frame", "EUI_RF_RaidDebuffPickerDimmer", UIParent)
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    -- Above the test-mode overlay (same strata, level 50 + its panel).
    dimmer:SetFrameLevel(100)
    dimmer:SetAllPoints(UIParent)
    dimmer:EnableMouse(true)
    dimmer:Hide()
    local dimTex = dimmer:CreateTexture(nil, "BACKGROUND")
    dimTex:SetAllPoints(); dimTex:SetTexture(0, 0, 0, 0.25)
    dimmer:SetScript("OnMouseDown", function(self) self:Hide() end)
    dimmer:SetScript("OnHide", function()
        GameTooltip:Hide()
        HideSettings()
        if opts and opts.onClose then opts.onClose() end
    end)
    tinsert(UISpecialFrames, "EUI_RF_RaidDebuffPickerDimmer")

    local p = EllesmereUI.SafeCreateFrame("Frame", nil, dimmer)
    popup = p
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
    title:SetText(L("Raid Debuffs"))
    local hint = EllesmereUI.MakeFont(p, 11, nil, 0.7, 0.7, 0.7, 0.85)
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText(L("Tracked debuffs are always shown and sorted first. Matched by name, so every difficulty is covered."))

    CreateRail(p)

    local contentLeft = PAD * 2 + RAIL_W
    local pageTitle = EllesmereUI.MakeFont(p, 11, nil, 1, 1, 1, 1)
    pageTitle:SetPoint("TOPLEFT", p, "TOPLEFT", contentLeft, -62)
    p._pageTitle = pageTitle
    local pageHint = EllesmereUI.MakeFont(p, 10, nil, 0.7, 0.7, 0.7, 0.8)
    pageHint:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -4)
    p._pageHint = pageHint

    local toggleAll = MakeButton(p, "Toggle All", 90, function()
        ToggleSpells(PageSpells())
        Rebuild()
    end)
    toggleAll:SetHeight(22)
    toggleAll:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -60)
    p._toggleAll = toggleAll

    local scroll = EllesmereUI.SafeCreateFrame("ScrollFrame", nil, p)
    scroll:SetPoint("TOPLEFT", p, "TOPLEFT", contentLeft, -96)
    scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 56)
    scroll:EnableMouseWheel(true)
    local child = EllesmereUI.SafeCreateFrame("Frame", nil, scroll)
    child:SetSize(POPUP_W - PAD * 3 - RAIL_W, 1)
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
    empty:Hide()
    p._empty = empty

    -- Footer: add a spell ID to the selected list | Done
    local box = EllesmereUI.SafeCreateFrame("EditBox", nil, p)
    box:SetSize(110, 28)
    box:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", contentLeft, 16)
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
    ph:SetText(L("Spell ID"))
    box:SetScript("OnTextChanged", function(self)
        if (self:GetText() or "") == "" then ph:Show() else ph:Hide() end
    end)
    local function AddTypedID()
        local id = tonumber(box:GetText())
        box:SetText("")
        box:ClearFocus()
        if id and id > 0 and GetSpellInfo(id) then
            SetOn(id, true)
            Rebuild()
        end
    end
    box:SetScript("OnEnterPressed", AddTypedID)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local addBtn = MakeButton(p, "Add", 60, AddTypedID)
    addBtn:SetPoint("LEFT", box, "RIGHT", 6, 0)

    local doneBtn = MakeButton(p, "Done", 80, function() dimmer:Hide() end)
    doneBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 16)

    return p
end

-- o = { getTracked, setTracked, getHidden, setHidden, getSettings,
--       setSettings, onClose, hidden }
-- hidden = true opens on the Hidden Debuffs page.
-- getTracked/getHidden return the saved tables; the setters receive
-- replacement tables.
function ns.ShowRaidDebuffPicker(o)
    if EllesmereUI.HideWidgetTooltip then EllesmereUI.HideWidgetTooltip() end
    opts = o
    if not popup then CreatePopup() end
    -- Open on the requested page, else the instance the player is in, else
    -- keep the last page.
    local here = ns.RD_GetCurrentInstanceKey and ns.RD_GetCurrentInstanceKey()
    selectedKey = (o.hidden and HIDDEN_KEY) or here or selectedKey or ns.RAID_DEBUFF_INSTANCES[2].key
    popup._dimmer:Show()
    Rebuild()
end

-- Tracked debuffs across all instances (for the options button label).
function ns.CountRaidDebuffs(tracked)
    local count = 0
    for _, inst in ipairs(ns.RAID_DEBUFF_INSTANCES) do
        count = count + ns.RD_CountTracked(tracked, inst)
    end
    return count
end
