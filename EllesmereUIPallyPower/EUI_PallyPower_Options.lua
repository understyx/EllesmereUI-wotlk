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

local function AssignmentChoices(addon)
    local values = { [0] = "None" }
    local order = { 0 }
    for blessingID = 1, PALLYPOWER_MAXBLESSINGS do
        values[blessingID] = addon.Spells[blessingID] or ("Blessing " .. blessingID)
        order[#order + 1] = blessingID
    end
    return values, order
end

local function AssignmentConfig(addon, paladinName, classID, values, order)
    local classToken = addon.ClassID[classID]
    local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken])
                      or CLASS_NAMES[classToken] or classToken
    local icon = addon.ClassIcons and addon.ClassIcons[classID]
    if icon then className = "|T" .. icon .. ":16:16:0:0|t " .. className end
    return {
        type="dropdown", text=className, values=values, order=order,
        tooltip="The greater blessing " .. paladinName .. " casts for this class.",
        disabled=function()
            return (InCombatLockdown and InCombatLockdown()) or not addon:CanControl(paladinName)
        end,
        disabledTooltip="Assignments cannot be changed in combat, or without permission to control this Paladin.",
        itemDisabled=function(blessingID)
            blessingID = tonumber(blessingID) or 0
            if blessingID == 0 then return false end
            local paladin = addon:GetRoster()[paladinName]
            return not paladin or not paladin[blessingID]
                   or (paladin[blessingID].rank or 0) == 0
        end,
        itemDisabledTooltip=function()
            return paladinName .. " does not know this blessing."
        end,
        getValue=function()
            local assignments = addon:GetAssignments()
            return assignments and assignments[paladinName]
                   and assignments[paladinName][classID] or 0
        end,
        setValue=function(blessingID)
            addon:SetClassAssignment(paladinName, classID, blessingID)
        end,
    }
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

    local values, order = AssignmentChoices(addon)
    for paladinIndex, paladinName in ipairs(paladins) do
        if paladinIndex > 1 then _, h = W:Spacer(parent, y, 14); y = y - h end
        _, h = W:SectionHeader(parent, paladinName, y); y = y - h
        local classID = 1
        while classID <= PALLYPOWER_MAXCLASSES do
            local left = AssignmentConfig(addon, paladinName, classID, values, order)
            local right
            if classID + 1 <= PALLYPOWER_MAXCLASSES then
                right = AssignmentConfig(addon, paladinName, classID + 1, values, order)
            end
            _, h = W:DualRow(parent, y, left, right); y = y - h
            classID = classID + 2
        end
    end

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
    elseif EllesmereUI:IsShown() and EllesmereUI:GetActiveModule() == "EllesmereUIPallyPower"
           and EllesmereUI:GetActivePage() == "Assignments" then
        EllesmereUI:RefreshPage()
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
          setValue=function(v) Set("freeassign", nil, v, true) end }
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
