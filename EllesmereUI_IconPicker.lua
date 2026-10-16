-------------------------------------------------------------------------------
--  EllesmereUI_IconPicker.lua
--
--  Shared searchable icon picker (modelled on the WeakAuras icon picker).
--  3.3.5 textures are file PATHS -- numeric fileIDs render as nothing -- so
--  the picker always hands back a texture path string.
--
--  Icon sources, merged and deduped by lower-cased path:
--    * macro icons + macro item icons (instant; the full Interface\Icons set
--      the client exposes, searchable by file name)
--    * a time-sliced GetSpellInfo scan (built on first open, kept for the
--      session) that attaches spell names so "frost nova" finds its icon
--  Typing a number also offers that spell ID's and item ID's icon; typing a
--  path (anything with a slash) offers that texture directly.
--
--  Usage:
--    EllesmereUI.ShowIconPicker({
--        title       = "Custom Icon",
--        current     = "Interface\\Icons\\Spell_Nature_Lightning",  -- or nil
--        allowRemove = true,          -- shows a Remove button (onPick(nil))
--        onPick      = function(path) ... end,
--    })
-------------------------------------------------------------------------------

local EllesmereUI = _G.EllesmereUI
if not EllesmereUI then return end

local L = function(s) return EllesmereUI.L and EllesmereUI.L(s) or s end

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local COLS, ROWS = 9, 7
local BTN, GAP = 36, 4
local MAX_SEARCH_LEN = 240   -- per-icon search string cap (names appended)
local SCAN_MISS_LIMIT = 20000
local SCAN_BUDGET_MS = 8

-------------------------------------------------------------------------------
--  Icon index
-------------------------------------------------------------------------------
local iconPaths  = {}   -- [i] = texture path (original case)
local iconSearch = {}   -- [i] = lower-case "filename name1 name2 ..."
local iconLabel  = {}   -- [i] = first spell name seen, for the tooltip
local iconByKey  = {}   -- lower(path) -> i

local scanState      -- nil = not started, "running", "done"
local scanNextID, scanMisses = 1, 0
local onIndexGrew    -- set by the picker while shown

local function Toggle(obj, show)
    if show then obj:Show() else obj:Hide() end
end

local function FileName(path)
    return path:match("([^\\/]+)$") or path
end

local function AddIcon(path, name)
    if type(path) ~= "string" or path == "" then return end
    local key = path:lower()
    local i = iconByKey[key]
    if not i then
        i = #iconPaths + 1
        iconPaths[i] = path
        iconSearch[i] = FileName(key)
        iconByKey[key] = i
    end
    if name and name ~= "" then
        if not iconLabel[i] then iconLabel[i] = name end
        local s = iconSearch[i]
        if #s < MAX_SEARCH_LEN then
            local ln = name:lower()
            if not s:find(ln, 1, true) then iconSearch[i] = s .. " " .. ln end
        end
    end
end

local function SeedMacroIcons()
    if #iconPaths > 0 then return end
    if GetNumMacroIcons and GetMacroIconInfo then
        for i = 1, GetNumMacroIcons() do AddIcon(GetMacroIconInfo(i)) end
    end
    if GetNumMacroItemIcons and GetMacroItemIconInfo then
        for i = 1, GetNumMacroItemIcons() do AddIcon(GetMacroItemIconInfo(i)) end
    end
end

-- Time-sliced spell scan. Stops after SCAN_MISS_LIMIT consecutive empty IDs.
local scanFrame = CreateFrame("Frame")
scanFrame:Hide()
scanFrame:SetScript("OnUpdate", function(self)
    local deadline = debugprofilestop() + SCAN_BUDGET_MS
    local before = #iconPaths
    while debugprofilestop() < deadline do
        local name, _, icon = GetSpellInfo(scanNextID)
        if name and name ~= "" and icon then
            AddIcon(icon, name)
            scanMisses = 0
        else
            scanMisses = scanMisses + 1
            if scanMisses >= SCAN_MISS_LIMIT then
                scanState = "done"
                self:Hide()
                break
            end
        end
        scanNextID = scanNextID + 1
    end
    if onIndexGrew and (#iconPaths ~= before or scanState == "done") then onIndexGrew() end
end)

local function StartScan()
    SeedMacroIcons()
    if scanState then return end
    scanState = "running"
    scanFrame:Show()
end

-------------------------------------------------------------------------------
--  Picker frame
-------------------------------------------------------------------------------
local picker

local function NormalizePath(text)
    text = text:gsub("/", "\\")
    return text
end

local function BuildPicker()
    local FONT = (EllesmereUI.GetFontPath and EllesmereUI.GetFontPath()) or EllesmereUI.EXPRESSWAY
    local OUTLINE = (EllesmereUI.GetFontOutlineFlag and EllesmereUI.GetFontOutlineFlag()) or ""
    local ar, ag, ab = EllesmereUI.GetAccentColor()
    local PP = EllesmereUI.PP

    local gridW = COLS * BTN + (COLS - 1) * GAP
    local gridH = ROWS * BTN + (ROWS - 1) * GAP
    local POP_W, POP_H = gridW + 50, gridH + 190

    local dimmer = EllesmereUI.SafeCreateFrame("Frame", "EUI_IconPickerDimmer", UIParent)
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    dimmer:SetAllPoints(UIParent)
    dimmer:EnableMouse(true)
    dimmer:Hide()
    local dimTex = dimmer:CreateTexture(nil, "BACKGROUND")
    dimTex:SetAllPoints(); dimTex:SetTexture(0, 0, 0, 0.25)
    dimmer:SetScript("OnMouseDown", function(self) self:Hide() end)

    local p = EllesmereUI.SafeCreateFrame("Frame", "EUI_IconPicker", dimmer)
    p:SetSize(POP_W, POP_H)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetFrameLevel(dimmer:GetFrameLevel() + 10)
    p:EnableMouse(true)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture(0.06, 0.08, 0.10, 1)
    EllesmereUI.MakeBorder(p, 1, 1, 1, 0.15, PP)
    p._dimmer = dimmer

    local title = p:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 14, OUTLINE)
    title:SetPoint("TOP", p, "TOP", 0, -16)
    title:SetTextColor(1, 1, 1, 1)
    p._title = title

    -- Search box
    local box = EllesmereUI.SafeCreateFrame("EditBox", nil, p)
    box:SetSize(gridW, 26)
    box:SetPoint("TOP", title, "BOTTOM", 0, -12)
    box:SetAutoFocus(false)
    box:SetMaxLetters(200)
    box:SetFont(FONT, 12, OUTLINE)
    box:SetTextColor(1, 1, 1, 0.9)
    box:SetTextInsets(8, 8, 0, 0)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints(); boxBg:SetTexture(0.04, 0.06, 0.08, 1)
    EllesmereUI.MakeBorder(box, 1, 1, 1, 0.12, PP)
    local placeholder = box:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(FONT, 11, OUTLINE)
    placeholder:SetPoint("LEFT", box, "LEFT", 8, 0)
    placeholder:SetTextColor(0.5, 0.5, 0.5, 0.8)
    placeholder:SetText(L("Search spell name, icon file, spell/item ID or path"))
    p._box = box

    local status = p:CreateFontString(nil, "OVERLAY")
    status:SetFont(FONT, 10, OUTLINE)
    status:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -4)
    status:SetTextColor(0.6, 0.6, 0.6, 0.85)
    p._status = status

    -- Grid (virtualized: COLS*ROWS buttons, scrolled by row offset)
    local grid = EllesmereUI.SafeCreateFrame("Frame", nil, p)
    grid:SetSize(gridW, gridH)
    grid:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -20)
    grid:EnableMouseWheel(true)

    local results, resultLabels = {}, {}
    local offset = 0
    local selected
    local buttons = {}

    local function MaxOffset()
        return math.max(0, math.ceil(#results / COLS) - ROWS)
    end

    local slider = CreateFrame("Slider", nil, p)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(8)
    slider:SetPoint("TOPLEFT", grid, "TOPRIGHT", 8, 0)
    slider:SetPoint("BOTTOMLEFT", grid, "BOTTOMRIGHT", 8, 0)
    local trackBg = slider:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints(); trackBg:SetTexture(1, 1, 1, 0.05)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(ar, ag, ab, 0.6)
    thumb:SetSize(8, 32)
    slider:SetThumbTexture(thumb)
    slider:SetValueStep(1)
    slider:SetMinMaxValues(0, 0)
    slider:SetValue(0)

    local function UpdateButtons()
        for idx, b in ipairs(buttons) do
            local r = offset * COLS + idx
            local path = results[r]
            if path then
                b._path = path
                b._label = resultLabels[r]
                b._tex:SetTexture(path)
                Toggle(b._sel, selected ~= nil and path:lower() == selected:lower())
                b:Show()
            else
                b._path = nil
                b:Hide()
            end
        end
    end

    local function SetOffset(v)
        v = math.max(0, math.min(MaxOffset(), math.floor(v + 0.5)))
        if v ~= offset then offset = v; UpdateButtons() end
        if math.floor(slider:GetValue() + 0.5) ~= v then slider:SetValue(v) end
    end
    slider:SetScript("OnValueChanged", function(_, v) SetOffset(v) end)
    grid:SetScript("OnMouseWheel", function(_, delta) SetOffset(offset - delta * 2) end)

    -- Preview / selection footer
    local prevFrame = EllesmereUI.SafeCreateFrame("Frame", nil, p)
    prevFrame:SetSize(40, 40)
    prevFrame:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -14)
    local prev = prevFrame:CreateTexture(nil, "ARTWORK")
    prev:SetAllPoints()
    prev:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    EllesmereUI.MakeBorder(prevFrame, ar, ag, ab, 0.6, PP)

    local prevName = p:CreateFontString(nil, "OVERLAY")
    prevName:SetFont(FONT, 12, OUTLINE)
    prevName:SetPoint("TOPLEFT", prevFrame, "TOPRIGHT", 10, -4)
    prevName:SetPoint("RIGHT", grid, "RIGHT", 0, 0)
    prevName:SetJustifyH("LEFT")
    prevName:SetTextColor(1, 1, 1, 0.95)
    local prevPath = p:CreateFontString(nil, "OVERLAY")
    prevPath:SetFont(FONT, 10, OUTLINE)
    prevPath:SetPoint("TOPLEFT", prevName, "BOTTOMLEFT", 0, -4)
    prevPath:SetPoint("RIGHT", grid, "RIGHT", 0, 0)
    prevPath:SetJustifyH("LEFT")
    prevPath:SetTextColor(0.6, 0.6, 0.6, 0.9)

    local function Select(path, label)
        selected = path
        prev:SetTexture(path or QUESTION_MARK)
        prevName:SetText(path and (label or FileName(path)) or L("No icon selected"))
        prevPath:SetText(path or "")
        UpdateButtons()
    end

    for i = 1, COLS * ROWS do
        local b = EllesmereUI.SafeCreateFrame("Button", nil, grid)
        b:SetSize(BTN, BTN)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        b:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (BTN + GAP), -row * (BTN + GAP))
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b._tex = t
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetTexture(1, 1, 1, 0.2)
        local sel = EllesmereUI.SafeCreateFrame("Frame", nil, b)
        sel:SetAllPoints()
        EllesmereUI.MakeBorder(sel, ar, ag, ab, 1, PP)
        sel:Hide()
        b._sel = sel
        b:SetScript("OnClick", function(s) Select(s._path, s._label) end)
        b:SetScript("OnDoubleClick", function(s)
            Select(s._path, s._label)
            p._commit(s._path)
        end)
        b:SetScript("OnEnter", function(s)
            if not s._path then return end
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            if s._label then GameTooltip:AddLine(s._label, 1, 1, 1) end
            GameTooltip:AddLine(s._path, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        buttons[i] = b
    end

    local function UpdateStatus()
        local txt = string.format(L("%d icons"), #results)
        if scanState == "running" then
            txt = txt .. "  |cff888888(" .. L("indexing spells...") .. ")|r"
        end
        status:SetText(txt)
    end

    local function Filter(keepOffset)
        wipe(results); wipe(resultLabels)
        local q = (box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        Toggle(placeholder, q == "")
        local seen = {}
        local function Direct(path, label)
            if path and not seen[path:lower()] then
                seen[path:lower()] = true
                results[#results + 1] = path
                resultLabels[#results] = label
            end
        end

        local num = tonumber(q)
        if num and num > 0 and num < 2 ^ 31 then
            local sName, _, sIcon = GetSpellInfo(num)
            Direct(sIcon, sName and (sName .. " (" .. L("spell") .. " " .. num .. ")"))
            local iIcon = GetItemIcon and GetItemIcon(num)
            local iName = GetItemInfo(num)
            Direct(iIcon, (iName or L("Item")) .. " (" .. L("item") .. " " .. num .. ")")
        elseif q:find("[\\/]") then
            Direct(NormalizePath(q))
        end

        local lq = q:lower()
        for i = 1, #iconPaths do
            if lq == "" or iconSearch[i]:find(lq, 1, true) then
                local key = iconPaths[i]:lower()
                if not seen[key] then
                    seen[key] = true
                    results[#results + 1] = iconPaths[i]
                    resultLabels[#results] = iconLabel[i]
                end
            end
        end

        slider:SetMinMaxValues(0, MaxOffset())
        if not keepOffset then offset = -1; SetOffset(0) else SetOffset(offset); UpdateButtons() end
        UpdateStatus()
    end
    p._filter = Filter

    box:SetScript("OnTextChanged", function() Filter(false) end)
    box:SetScript("OnEscapePressed", function(s)
        if s:GetText() ~= "" then s:SetText("") else dimmer:Hide() end
    end)
    box:SetScript("OnEnterPressed", function(s)
        s:ClearFocus()
        if results[1] and not selected then Select(results[1], resultLabels[1]) end
    end)

    -- Throttled refresh while the spell scan grows the index.
    local lastGrow = 0
    onIndexGrew = function()
        if not dimmer:IsShown() then return end
        local now = GetTime()
        if scanState == "done" or now - lastGrow > 0.4 then
            lastGrow = now
            Filter(true)
        end
    end

    -- Buttons
    local function MakeButton(text, primary)
        local btn = EllesmereUI.SafeCreateFrame("Button", nil, p)
        btn:SetSize(90, 26)
        local bbg = btn:CreateTexture(nil, "BACKGROUND")
        bbg:SetAllPoints()
        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT, 12, OUTLINE)
        lbl:SetPoint("CENTER"); lbl:SetText(L(text))
        local r, g, bl, a
        if primary then
            bbg:SetTexture(ar, ag, ab, 0.15)
            EllesmereUI.MakeBorder(btn, ar, ag, ab, 0.3, PP)
            r, g, bl, a = ar, ag, ab, 0.9
        else
            bbg:SetTexture(0.12, 0.12, 0.12, 0.5)
            EllesmereUI.MakeBorder(btn, 1, 1, 1, 0.10, PP)
            r, g, bl, a = 0.7, 0.7, 0.7, 0.8
        end
        lbl:SetTextColor(r, g, bl, a)
        btn:SetScript("OnEnter", function() lbl:SetTextColor(1, 1, 1, 1) end)
        btn:SetScript("OnLeave", function() lbl:SetTextColor(r, g, bl, a) end)
        return btn
    end

    local cancelBtn = MakeButton("Cancel")
    cancelBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 14)
    cancelBtn:SetScript("OnClick", function() dimmer:Hide() end)

    local okBtn = MakeButton("Save", true)
    okBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -8, 0)
    okBtn:SetScript("OnClick", function() p._commit(selected) end)

    local removeBtn = MakeButton("Remove")
    removeBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
    removeBtn:SetScript("OnClick", function()
        dimmer:Hide()
        if p._onPick then p._onPick(nil) end
    end)
    p._removeBtn = removeBtn

    p._commit = function(path)
        if not path then return end
        dimmer:Hide()
        if p._onPick then p._onPick(path) end
    end
    p._select = Select

    dimmer:SetScript("OnHide", function() GameTooltip:Hide() end)

    return p
end

function EllesmereUI.ShowIconPicker(opts)
    opts = opts or {}
    StartScan()
    picker = picker or BuildPicker()
    local p = picker
    if EllesmereUI.GetPopupScale then p._dimmer:SetScale(EllesmereUI.GetPopupScale() or 1) end
    p._title:SetText(L(opts.title or "Choose Icon"))
    p._onPick = opts.onPick
    Toggle(p._removeBtn, opts.allowRemove)
    local cur = type(opts.current) == "string" and opts.current ~= "" and opts.current or nil
    local ci = cur and iconByKey[cur:lower()]
    p._select(cur, ci and iconLabel[ci] or nil)
    p._dimmer:Show()
    p._box:SetText("")
    p._filter(false)
    p._box:SetFocus()
end
