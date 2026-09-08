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
    return GetSpellInfo(def.spellID) or ("Spell " .. tostring(def.spellID))
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

_G._EUI_BuildRaidCooldownsPage = function(_, parent, yOffset)
    local W = EUI.Widgets
    local db = DB()
    if not W or not db or not Catalog then return 0 end
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

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "MODULE-WIDE CLICK BINDINGS", y); y = y - h
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
        { type = "slider", text = "Request Notice Duration", min = 2, max = 15, step = 1,
          getValue = function() return db.notificationDuration or 5 end,
          setValue = function(value) db.notificationDuration = value end }
    ); y = y - h
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

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "GROUPS", y); y = y - h

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

    _, h = W:WideDualButton(parent, "Add Group", "Rename Group", y,
        function()
            EUI:ShowInputPopup({
                title = "Create Raid Cooldown Group",
                message = "Choose a name for the new group.",
                placeholder = "Raid Cooldowns",
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
        end)
    y = y - h

    local group = CurrentGroup(db)
    if not group then
        _, h = W:Spacer(parent, y, 12); y = y - h
        return math.abs(y)
    end

    _, h = W:WideButton(parent, "Delete Selected Group", y, function()
        EUI:ShowConfirmPopup({
            title = "Delete Raid Cooldown Group",
            message = "Delete " .. (group.name or "this group") .. "? This cannot be undone.",
            confirmText = "Delete",
            onConfirm = function()
                Module():DeleteGroup(group.id)
                selectedGroupID = nil
                EUI:RefreshPage(true)
            end,
        })
    end, 450)
    y = y - h

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
          getValue = function() return group.colorBarByClass == true end,
          setValue = function(value) group.colorBarByClass = value; RefreshRuntime(false) end }
    ); y = y - h
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
        { type = "dropdown", text = "Last Target", values = TARGET_VALUES, order = TARGET_ORDER,
          getValue = function() return group.targetDisplay or "none" end,
          setValue = function(value) group.targetDisplay = value; RefreshRuntime(false) end }
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

    _, h = W:Spacer(parent, y, 8); y = y - h
    _, h = W:SectionHeader(parent, "TRACKED COOLDOWNS", y); y = y - h
    _, h = W:WideDualButton(parent, "Enable All", "Disable All", y,
        function()
            for spellID in pairs(Catalog.bySpellID) do group.enabledSpells[spellID] = true end
            RefreshRuntime(true)
        end,
        function()
            group.enabledSpells = {}
            RefreshRuntime(true)
        end)
    y = y - h

    for classIndex, class in ipairs(Catalog.classOrder) do
        local spells = OrderedSpells(class)
        if #spells > 0 then
            _, h = W:SectionHeader(parent, string.upper(Catalog.classNames[class] or class), y); y = y - h
            local index = 1
            while index <= #spells do
                local left = spells[index]
                local right = spells[index + 1]
                local function ToggleConfig(def)
                    if not def then return { type = "label", text = "" } end
                    return {
                        type = "toggle",
                        text = SpellLabel(def),
                        getValue = function() return group.enabledSpells[def.spellID] == true end,
                        setValue = function(value)
                            group.enabledSpells[def.spellID] = value and true or nil
                            RefreshRuntime(false)
                        end,
                    }
                end
                _, h = W:DualRow(parent, y, ToggleConfig(left), ToggleConfig(right)); y = y - h
                index = index + 2
            end
        end
    end

    _, h = W:Spacer(parent, y, 16); y = y - h
    return math.abs(y)
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
        pages = { "Raid Cooldowns" },
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
