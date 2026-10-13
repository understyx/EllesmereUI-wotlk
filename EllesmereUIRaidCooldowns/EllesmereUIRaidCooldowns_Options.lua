-------------------------------------------------------------------------------
-- EllesmereUIRaidCooldowns_Options.lua
-- Group, visibility, spell, and module-wide interaction settings.
-------------------------------------------------------------------------------

local EUI = EllesmereUI
local Catalog = EUI and EUI.RaidCooldownCatalog
local selectedGroupID

local ACTION_VALUES = {
    none = "None",
    announce = "Announce",
    request = "Request / Whisper",
}
local ACTION_ORDER = { "none", "announce", "request" }
local TARGET_VALUES = { none = "Hidden", inline = "Inline" }
local TARGET_ORDER = { "none", "inline" }
local ROLE_ITEMS = {
    { key = "TANK", label = "Tank" },
    { key = "HEALER", label = "Healer" },
    { key = "DAMAGER", label = "Damage" },
}

local function Module()
    return EUI and EUI.RaidCooldowns
end

local function DB()
    local module = Module()
    return module and module:GetDB()
end

local function RefreshRuntime(rebuild)
    local module = Module()
    if module then module:RefreshConfiguration() end
    EUI._settingsChanged = true
    if rebuild then EUI:RefreshPage(true) end
end

local function CurrentGroup(db)
    if selectedGroupID and db.groups[selectedGroupID] then
        return db.groups[selectedGroupID]
    end
    for _, id in ipairs(db.groupOrder or {}) do
        if db.groups[id] then
            selectedGroupID = id
            return db.groups[id]
        end
    end
end

local function ClassItems()
    local items = {}
    for classIndex, class in ipairs(Catalog and Catalog.classOrder or {}) do
        if class ~= "ITEMS" then
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            local hex = color and color.colorStr or "ffffffff"
            items[#items + 1] = {
                key = class,
                label = "|c" .. hex .. (Catalog.classNames[class] or class) .. "|r",
            }
        end
    end
    return items
end

local function AttachMultiSelect(region, items, getTable, label)
    local dropdown, refresh = EUI.BuildVisOptsCBDropdown(
        region, 210, region:GetFrameLevel() + 2, items,
        function(key)
            local values = getTable()
            return values and values[key] == true
        end,
        function(key, value)
            local values = getTable()
            if not values then return end
            values[key] = value and true or nil
            RefreshRuntime(false)
        end,
        nil, 10, false, true)
    EUI.PanelPP.Point(dropdown, "RIGHT", region, "RIGHT", -20, 0)
    region._control = dropdown
    region._slotLabel = label
    EUI.RegisterWidgetRefresh(refresh)
end

local function CopyTrue(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        if value then copy[key] = true end
    end
    return copy
end

local function EditSpecs(group, tableKey, title)
    if not EUI.ShowSpecAssignPopup then return end
    local selected = CopyTrue(group[tableKey] and group[tableKey].specs)
    local dummy = { sets = { current = {} } }
    EUI:ShowSpecAssignPopup({
        db = dummy,
        dbKey = "sets",
        presetKey = "current",
        title = title,
        subtitle = "Nothing selected means all specs.",
        preCheckedSpecs = selected,
        onConfirm = function(assignments)
            group[tableKey].specs = CopyTrue(assignments)
            RefreshRuntime(true)
        end,
    })
end

local function SpellLabel(def)
    if def.class == "ITEMS" and def.itemIDs then
        local itemName = GetItemInfo(def.itemIDs[1])
        if itemName then return itemName end
    end
    return GetSpellInfo(def.spellID) or EllesmereUI.Lf("Spell %d", def.spellID)
end

local function OrderedSpells(class)
    local spells = {}
    for _, def in pairs(Catalog.byClass[class] or {}) do spells[#spells + 1] = def end
    table.sort(spells, function(a, b)
        if (a.order or 999) ~= (b.order or 999) then return (a.order or 999) < (b.order or 999) end
        return a.spellID < b.spellID
    end)
    return spells
end

local function SpellIconFor(def)
    if def.class == "ITEMS" and def.itemIDs and GetItemIcon then
        local icon = GetItemIcon(def.itemIDs[1])
        if icon then return icon end
    end
    local _, _, icon = GetSpellInfo(def.spellID)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function BuildGroupSelector(parent, y, db, allowManage)
    local W = EUI.Widgets
    local _, h
    local selectorValues, selectorOrder = {}, {}
    for _, id in ipairs(db.groupOrder or {}) do
        local entry = db.groups[id]
        if entry then
            selectorValues[id] = entry.name
            selectorOrder[#selectorOrder + 1] = id
        end
    end
    if #selectorOrder > 0 then
        _, h = W:WideDropdown(parent, "Edit Group", y, selectorValues,
            function() local group = CurrentGroup(db); return group and group.id end,
            function(value) selectedGroupID = value; EUI:RefreshPage(true) end,
            selectorOrder, 450)
        y = y - h
    end
    if not allowManage then return y end

    _, h = W:WideTripleButton(parent, "Add Group", "Rename Group", "Delete Group", y,
        function()
            EUI:ShowInputPopup({
                title = "Create Raid Cooldown Group",
                message = "Choose a name for the new group.",
                placeholder = EllesmereUI.L("Raid Cooldowns"),
                confirmText = "Create",
                onConfirm = function(name)
                    selectedGroupID = Module():CreateGroup(name)
                    EUI:RefreshPage(true)
                end,
            })
        end,
        function()
            local group = CurrentGroup(db)
            if not group then return end
            EUI:ShowInputPopup({
                title = "Rename Raid Cooldown Group",
                message = "Enter the new group name.",
                placeholder = group.name,
                confirmText = "Rename",
                onConfirm = function(name)
                    if name and name ~= "" then group.name = name end
                    if db.enabled then Module():RegisterGroupUnlock(group.id) end
                    RefreshRuntime(true)
                end,
            })
        end,
        function()
            local group = CurrentGroup(db)
            if not group then return end
            EUI:ShowConfirmPopup({
                title = "Delete Raid Cooldown Group",
                message = EllesmereUI.Lf("Delete %s? This cannot be undone.", group.name or EllesmereUI.L("this group")),
                confirmText = "Delete",
                onConfirm = function()
                    Module():DeleteGroup(group.id)
                    selectedGroupID = nil
                    EUI:RefreshPage(true)
                end,
            })
        end)
    return y - h
end

local function BuildGeneralPage(parent, yOffset)
    local W = EUI.Widgets
    local db = DB()
    local module = Module()
    local y = yOffset or -10
    local _, h

    _, h = W:SectionHeader(parent, "RAID COOLDOWNS", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Enable Raid Cooldowns",
          tooltip = "Tracks configured group cooldowns. Disabled means no Raid Cooldowns events or timers remain active.",
          getValue = function() return db.enabled == true end,
          setValue = function(value)
              db.enabled = value
              Module():ApplyEnabled()
              EUI:RefreshPage(true)
          end },
        { type = "button", text = "Open Unlock Mode", onClick = function()
              if EUI.OpenUnlockMode then EUI:OpenUnlockMode() end
          end }
    ); y = y - h

    local textureValues, textureOrder = {}, {}
    for _, key in ipairs(module.BAR_TEXTURE_ORDER or {}) do
        if key ~= "---" then textureValues[key] = module.BAR_TEXTURE_NAMES[key] or key end
        textureOrder[#textureOrder + 1] = key
    end
    textureValues._menuOpts = {
        itemHeight = 28,
        background = function(key) return module.BAR_TEXTURES[key] end,
    }

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "APPEARANCE", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Bar Texture", values = textureValues, order = textureOrder,
          tooltip = "Uses EllesmereUI's bar textures, including textures provided through SharedMedia.",
          getValue = function() return db.barTexture or "melli" end,
          setValue = function(value) db.barTexture = value; RefreshRuntime(false) end },
        { type = "toggle", text = "Show Borders",
          tooltip = "Draws EllesmereUI pixel borders around cooldown icons and bars.",
          getValue = function() return db.showBorders ~= false end,
          setValue = function(value) db.showBorders = value; RefreshRuntime(false) end }
    ); y = y - h

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "CLICK BINDINGS", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Left Click", values = ACTION_VALUES, order = ACTION_ORDER,
          getValue = function() return db.interactions.LeftButton or "none" end,
          setValue = function(value) db.interactions.LeftButton = value end },
        { type = "dropdown", text = "Shift + Left Click", values = ACTION_VALUES, order = ACTION_ORDER,
          getValue = function() return db.interactions.ShiftLeftButton or "none" end,
          setValue = function(value) db.interactions.ShiftLeftButton = value end }
    ); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Alt + Left Click", values = ACTION_VALUES, order = ACTION_ORDER,
          getValue = function() return db.interactions.AltLeftButton or "none" end,
          setValue = function(value) db.interactions.AltLeftButton = value end },
        { type = "dropdown", text = "Ctrl + Left Click", values = ACTION_VALUES, order = ACTION_ORDER,
          getValue = function() return db.interactions.CtrlLeftButton or "none" end,
          setValue = function(value) db.interactions.CtrlLeftButton = value end }
    ); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Right Click", values = ACTION_VALUES, order = ACTION_ORDER,
          getValue = function() return db.interactions.RightButton or "none" end,
          setValue = function(value) db.interactions.RightButton = value end },
        nil
    ); y = y - h

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "MESSAGES", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "input", text = "Announcement Text", inputStyle = "popup", inputWidth = 230,
          tooltip = "Tokens: %playerName, %spellName, %spellLink, %state, %timeLeft, %targetName, %target.",
          getValue = function() return db.announceTemplate or "" end,
          setValue = function(value) db.announceTemplate = value end },
        { type = "input", text = "Request Whisper", inputStyle = "popup", inputWidth = 230,
          tooltip = "Tokens: %playerName, %spellName, %spellLink, %timeLeft, and %targetName.",
          getValue = function() return db.requestTemplate or "" end,
          setValue = function(value) db.requestTemplate = value end }
    ); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "Request Notice Duration", min = 2, max = 15, step = 1,
          getValue = function() return db.notificationDuration or 5 end,
          setValue = function(value) db.notificationDuration = value end },
        nil
    ); y = y - h

    _, h = W:Spacer(parent, y, 16); y = y - h
    return math.abs(y)
end

local function BuildGroupsPage(parent, yOffset)
    local W = EUI.Widgets
    local db = DB()
    local y = yOffset or -10
    local _, h

    _, h = W:SectionHeader(parent, "GROUPS", y); y = y - h
    y = BuildGroupSelector(parent, y, db, true)

    local group = CurrentGroup(db)
    if not group then
        _, h = W:Spacer(parent, y, 12); y = y - h
        return math.abs(y)
    end

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "DISPLAY", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Enable This Group",
          getValue = function() return group.enabled ~= false end,
          setValue = function(value) group.enabled = value; RefreshRuntime(false) end },
        { type = "toggle", text = "Show Ready Cooldowns",
          getValue = function() return group.showReady ~= false end,
          setValue = function(value) group.showReady = value; RefreshRuntime(false) end }
    ); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Show Header",
          getValue = function() return group.showHeader ~= false end,
          setValue = function(value) group.showHeader = value; RefreshRuntime(false) end },
        { type = "toggle", text = "Show Spell Icons",
          getValue = function() return group.showIcon ~= false end,
          setValue = function(value) group.showIcon = value; RefreshRuntime(false) end }
    ); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Show Spell Names",
          getValue = function() return group.showSpellName ~= false end,
          setValue = function(value) group.showSpellName = value; RefreshRuntime(false) end },
        { type = "toggle", text = "Class-Colored Bars",
          tooltip = "Colors bars by class. Otherwise cooldowns use the accent color and ready spells turn green.",
          getValue = function() return group.colorBarByClass == true end,
          setValue = function(value) group.colorBarByClass = value; RefreshRuntime(false) end }
    ); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Last Target", values = TARGET_VALUES, order = TARGET_ORDER,
          getValue = function() return group.targetDisplay or "none" end,
          setValue = function(value) group.targetDisplay = value; RefreshRuntime(false) end },
        nil
    ); y = y - h

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "SIZE", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "Group Width", min = 150, max = 600, step = 1,
          getValue = function() return group.width or 270 end,
          setValue = function(value) group.width = value; RefreshRuntime(false) end },
        { type = "slider", text = "Row Height", min = 16, max = 50, step = 1,
          getValue = function() return group.rowHeight or 26 end,
          setValue = function(value) group.rowHeight = value; RefreshRuntime(false) end }
    ); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "Spell Spacing", min = 0, max = 20, step = 1,
          getValue = function() return group.spacing or 4 end,
          setValue = function(value) group.spacing = value; RefreshRuntime(false) end },
        nil
    ); y = y - h

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "WHEN THIS GROUP IS SHOWN (NONE = ALL)", y); y = y - h
    local visRow
    visRow, h = W:DualRow(parent, y,
        { type = "label", text = "Player Classes" },
        { type = "label", text = "Player Roles" }
    ); y = y - h
    AttachMultiSelect(visRow._leftRegion, ClassItems(), function() return group.visibility.classes end, "Player Classes")
    AttachMultiSelect(visRow._rightRegion, ROLE_ITEMS, function() return group.visibility.roles end, "Player Roles")
    _, h = W:WideButton(parent, "Choose Player Specs (None = All)", y, function()
        EditSpecs(group, "visibility", "Show Group for Player Specs")
    end, 450); y = y - h

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "WHICH RAID MEMBERS ARE INCLUDED (NONE = ALL)", y); y = y - h
    local memberRow
    memberRow, h = W:DualRow(parent, y,
        { type = "label", text = "Member Classes" },
        { type = "label", text = "Member Roles" }
    ); y = y - h
    AttachMultiSelect(memberRow._leftRegion, ClassItems(), function() return group.memberFilter.classes end, "Member Classes")
    AttachMultiSelect(memberRow._rightRegion, ROLE_ITEMS, function() return group.memberFilter.roles end, "Member Roles")
    _, h = W:WideButton(parent, "Choose Member Specs (None = All)", y, function()
        EditSpecs(group, "memberFilter", "Include Raid Member Specs")
    end, 450); y = y - h

    _, h = W:Spacer(parent, y, 16); y = y - h
    return math.abs(y)
end

-- Spell picker: one icon per cooldown, grouped by class. Clicking an icon
-- toggles tracking for the selected group; tracked icons are full color with
-- an accent border, untracked ones are dimmed and desaturated.
local SPELL_CELL_W, SPELL_CELL_H, SPELL_ICON = 92, 66, 38

local function RefreshSpellCell(cell, group)
    local tracked = group.enabledSpells[cell.def.spellID] == true
    local r, g, b = EUI.GetAccentColor()
    cell._icon:SetDesaturated(not tracked)
    cell._icon:SetAlpha(tracked and 1 or 0.4)
    cell._label:SetAlpha(tracked and 1 or 0.45)
    if tracked then
        cell._border:SetColor(r, g, b, 1)
    else
        cell._border:SetColor(1, 1, 1, 0.08)
    end
end

local function BuildSpellGrid(parent, y, group, spells)
    local PPx = EUI.PanelPP
    local pad = EUI.CONTENT_PAD or 24
    local width = parent:GetWidth() - pad * 2
    local perRow = math.max(1, math.floor(width / SPELL_CELL_W))
    local rows = math.ceil(#spells / perRow)

    for index, def in ipairs(spells) do
        local col = (index - 1) % perRow
        local row = math.floor((index - 1) / perRow)
        local cell = EUI.SafeCreateFrame("Button", nil, parent)
        PPx.Size(cell, SPELL_CELL_W - 4, SPELL_CELL_H - 4)
        PPx.Point(cell, "TOPLEFT", parent, "TOPLEFT",
            pad + col * SPELL_CELL_W, y - row * SPELL_CELL_H)
        cell.def = def

        local iconHolder = EUI.SafeCreateFrame("Frame", nil, cell)
        PPx.Size(iconHolder, SPELL_ICON, SPELL_ICON)
        PPx.Point(iconHolder, "TOP", cell, "TOP", 0, -4)
        cell._icon = iconHolder:CreateTexture(nil, "ARTWORK")
        cell._icon:SetAllPoints()
        cell._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cell._icon:SetTexture(SpellIconFor(def))
        cell._border = EUI.MakeBorder(iconHolder, 1, 1, 1, 0.08, PPx)

        cell._hover = EUI.SolidTex(cell, "BACKGROUND", 1, 1, 1, 0.05)
        cell._hover:SetAllPoints()
        cell._hover:Hide()

        cell._label = EUI.MakeFont(cell, 10, nil, 1, 1, 1, 0.9)
        PPx.Point(cell._label, "TOP", iconHolder, "BOTTOM", 0, -4)
        PPx.Size(cell._label, SPELL_CELL_W - 8, 12)
        cell._label:SetJustifyH("CENTER")
        cell._label:SetText(SpellLabel(def))

        cell:SetScript("OnClick", function(self)
            local id = self.def.spellID
            group.enabledSpells[id] = (not group.enabledSpells[id]) and true or nil
            RefreshSpellCell(self, group)
            RefreshRuntime(false)
            if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
        end)
        cell:SetScript("OnEnter", function(self)
            self._hover:Show()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.def.class == "ITEMS" and self.def.itemIDs then
                GameTooltip:SetHyperlink("item:" .. self.def.itemIDs[1])
            else
                GameTooltip:SetHyperlink("spell:" .. self.def.spellID)
            end
            local tracked = group.enabledSpells[self.def.spellID] == true
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(EllesmereUI.L(tracked and "Tracked - click to stop tracking."
                or "Not tracked - click to track."), 0.72, 0.72, 0.72)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function(self)
            self._hover:Hide()
            GameTooltip:Hide()
        end)
        RefreshSpellCell(cell, group)
    end
    return rows * SPELL_CELL_H + 6
end

local function BuildSpellsPage(parent, yOffset)
    local W = EUI.Widgets
    local db = DB()
    local y = yOffset or -10
    local _, h

    _, h = W:SectionHeader(parent, "TRACKED COOLDOWNS", y); y = y - h
    y = BuildGroupSelector(parent, y, db, false)
    local group = CurrentGroup(db)
    if not group then
        _, h = W:DualRow(parent, y,
            { type = "label", text = "Create a group on the Groups page first." }, nil)
        y = y - h
        return math.abs(y)
    end

    _, h = W:WideDualButton(parent, "Track All", "Track None", y,
        function()
            for spellID in pairs(Catalog.bySpellID) do group.enabledSpells[spellID] = true end
            RefreshRuntime(true)
        end,
        function()
            group.enabledSpells = {}
            RefreshRuntime(true)
        end)
    y = y - h

    local hint = EUI.MakeFont(parent, 11, nil, 0.62, 0.62, 0.62, 1)
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", EUI.CONTENT_PAD or 24, y - 6)
    hint:SetText(EllesmereUI.L("Click an icon to track or stop tracking it in the selected group."))
    y = y - 28

    for _classIndex, class in ipairs(Catalog.classOrder) do
        local spells = OrderedSpells(class)
        if #spells > 0 then
            _, h = W:SectionHeader(parent, string.upper(Catalog.classNames[class] or class), y); y = y - h
            y = y - BuildSpellGrid(parent, y, group, spells)
        end
    end

    _, h = W:Spacer(parent, y, 16); y = y - h
    return math.abs(y)
end

_G._EUI_BuildRaidCooldownsPage = function(pageName, parent, yOffset)
    if not EUI.Widgets or not DB() or not Catalog then return 0 end
    if pageName == "Groups" then return BuildGroupsPage(parent, yOffset) end
    if pageName == "Spells" then return BuildSpellsPage(parent, yOffset) end
    return BuildGeneralPage(parent, yOffset)
end

local function ResetRaidCooldowns()
    local module = Module()
    local db = module and module:GetDB()
    if not db then return end
    db.enabled = false
    db.nextGroupID = 1
    db.groupOrder = {}
    db.groups = {}
    db.interactions = {
        LeftButton = "none",
        ShiftLeftButton = "announce",
        AltLeftButton = "request",
        CtrlLeftButton = "none",
        RightButton = "none",
    }
    db.announceTemplate = "%playerName - %spellLink - %state%target"
    db.requestTemplate = "Please use %spellName on me"
    db.notificationDuration = 5
    db.barTexture = "melli"
    db.showBorders = true
    db.savedState = {}
    module.state = {}
    module.roster = {}
    module:ApplyEnabled()
    EUI:InvalidatePageCache()
end

if EUI and EUI.RegisterModule then
    EUI:RegisterModule("EllesmereUIRaidCooldowns", {
        title = "Raid Cooldowns",
        description = "Configurable raid cooldown groups, announcements, and requests.",
        pages = { "General", "Groups", "Spells" },
        searchTerms = {
            "raid cooldown", "raid cooldowns", "external", "defensive",
            "announcement", "request cooldown", "whisper cooldown",
            "shift click", "alt click",
        },
        buildPage = function(pageName, parent, yOffset)
            return _G._EUI_BuildRaidCooldownsPage(pageName, parent, yOffset)
        end,
        onReset = ResetRaidCooldowns,
    })
end
