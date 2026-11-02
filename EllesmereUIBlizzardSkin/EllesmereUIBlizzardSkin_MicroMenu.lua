-------------------------------------------------------------------------------
--  3.3.5 micro menu layout and per-menu button styles.
--  Modern visuals adapt DragonUI/modules/micromenu.lua, Copyright (c) 2026
--  NeticSoul and DragonUI contributors, and DragonflightUI, Copyright (c) 2022
--  Karl-HeinzSchneider; both under MIT (see DRAGONUI_NOTICES.md).
-------------------------------------------------------------------------------
local MODERN_TEXTURE = "Interface\\AddOns\\EllesmereUIBlizzardSkin\\Media\\MicroMenu\\uimicromenu2x"
local MODERN_PVP_TEXTURE = "Interface\\AddOns\\EllesmereUIBlizzardSkin\\Media\\MicroMenu\\micropvp"
local FLAT_TEXTURE_ROOT = "Interface\\AddOns\\EllesmereUIDataBars\\media\\micromenu\\"
local BAR_NAME = "EllesmereUIMicroMenuBar"

local BUTTON_NAMES = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "PVPMicroButton",
    "LFDMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
}

local MODERN_STATES = {
    SpellbookMicroButton = {
        up = {0.452148, 0.514648, 0.494141, 0.654297},
        down = {0.452148, 0.514648, 0.658203, 0.818359},
        disabled = {0.452148, 0.514648, 0.822266, 0.982422},
        highlight = {0.516602, 0.579102, 0.00195312, 0.162109},
    },
    TalentMicroButton = {
        up = {0.452148, 0.514648, 0.330078, 0.490234},
        down = {0.452148, 0.514648, 0.00195312, 0.162109},
        disabled = {0.387695, 0.450195, 0.822266, 0.982422},
        highlight = {0.452148, 0.514648, 0.166016, 0.326172},
    },
    AchievementMicroButton = {
        up = {0.000976562, 0.0634766, 0.494141, 0.654297},
        down = {0.000976562, 0.0634766, 0.166016, 0.326172},
        disabled = {0.000976562, 0.0634766, 0.00195312, 0.162109},
        highlight = {0.000976562, 0.0634766, 0.330078, 0.490234},
    },
    QuestLogMicroButton = {
        up = {0.387695, 0.450195, 0.00195312, 0.162109},
        down = {0.323242, 0.385742, 0.658203, 0.818359},
        disabled = {0.323242, 0.385742, 0.494141, 0.654297},
        highlight = {0.323242, 0.385742, 0.822266, 0.982422},
    },
    SocialsMicroButton = {
        up = {0.258789, 0.321289, 0.822266, 0.982422},
        down = {0.194336, 0.256836, 0.822266, 0.982422},
        disabled = {0.194336, 0.256836, 0.658203, 0.818359},
        highlight = {0.258789, 0.321289, 0.658203, 0.818359},
    },
    LFDMicroButton = {
        up = {0.194336, 0.256836, 0.494141, 0.654297},
        down = {0.194336, 0.256836, 0.166016, 0.326172},
        disabled = {0.194336, 0.256836, 0.00195312, 0.162109},
        highlight = {0.194336, 0.256836, 0.330078, 0.490234},
    },
    MainMenuMicroButton = {
        up = {0.387695, 0.450195, 0.658203, 0.818359},
        down = {0.387695, 0.450195, 0.494141, 0.654297},
        disabled = {0.129883, 0.192383, 0.330078, 0.490234},
        highlight = {0.129883, 0.192383, 0.658203, 0.818359},
    },
    HelpMicroButton = {
        up = {0.129883, 0.192383, 0.822266, 0.982422},
        down = {0.129883, 0.192383, 0.494141, 0.654297},
        disabled = {0.129883, 0.192383, 0.330078, 0.490234},
        highlight = {0.129883, 0.192383, 0.658203, 0.818359},
    },
}

local FLAT_ICONS = {
    CharacterMicroButton = "menu-character.tga",
    SpellbookMicroButton = "menu-spellbook.tga",
    TalentMicroButton = "menu-adventure.tga",
    AchievementMicroButton = "menu-acheivements.tga",
    QuestLogMicroButton = "menu-quests.tga",
    SocialsMicroButton = "menu-friends.tga",
    PVPMicroButton = "menu-pvp.tga",
    LFDMicroButton = "menu-group.tga",
    MainMenuMicroButton = "menu-options.tga",
    HelpMicroButton = "menu-cs.tga",
}

local FLAT_ICON_FIT = {
    SocialsMicroButton = {
        coords = { 12 / 128, 117 / 128, 63 / 128, 122 / 128 },
        width = 25,
        height = 14,
    },
}

local function GetMenuFrame()
    local frame = _G[BAR_NAME]
    if not frame then
        frame = CreateFrame("Frame", BAR_NAME, UIParent)
        frame:SetSize(253, 58)
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 2)
    end
    return frame
end

local menuFrame = GetMenuFrame()
local style
local layoutPending = false
local buttons = {}
local stockButtonArt = {}

local function CaptureRegion(region)
    if not region then return nil end
    local saved = {
        texture = region:GetTexture(),
        alpha = region:GetAlpha(),
        width = region:GetWidth(),
        height = region:GetHeight(),
        points = {},
    }
    if region.GetTexCoord then
        saved.texCoord = {region:GetTexCoord()}
    end
    if region.GetBlendMode then
        saved.blendMode = region:GetBlendMode()
    end
    if region.GetVertexColor then
        saved.vertexColor = {region:GetVertexColor()}
    end
    if region.GetNumPoints then
        for i = 1, region:GetNumPoints() do
            saved.points[#saved.points + 1] = {region:GetPoint(i)}
        end
    end
    return saved
end

local function CaptureButtonArt(button)
    local saved = {}
    if button.GetNormalTexture then saved.normal = CaptureRegion(button:GetNormalTexture()) end
    if button.GetPushedTexture then saved.pushed = CaptureRegion(button:GetPushedTexture()) end
    if button.GetDisabledTexture then saved.disabled = CaptureRegion(button:GetDisabledTexture()) end
    if button.GetHighlightTexture then saved.highlight = CaptureRegion(button:GetHighlightTexture()) end
    return saved
end

for i = 1, #BUTTON_NAMES do
    local button = _G[BUTTON_NAMES[i]]
    if button then
        buttons[#buttons + 1] = button
        stockButtonArt[button] = CaptureButtonArt(button)
    end
end
local stockPortraitArt = CaptureRegion(_G.MicroButtonPortrait)
local stockPVPArt = CaptureRegion(_G.PVPMicroButtonTexture)

local function GetStyle()
    local style = EllesmereUI.GetBlizzWindowStyle("micromenu")
    if style == "modern" then return "modern" end
    if style == "eui" then return "eui" end
    return "classic"
end

local function GetGeometry()
    if style == "modern" then
        return 32, 40, 26
    elseif style == "eui" then
        return 32, 40, 36
    end
    -- Native 3.3.5 micro buttons are 28x58 with an 18px top hit inset.
    return 28, 58, 25
end

local function SetStateTexture(button, getter, setter, coords)
    local texture = button[getter](button)
    if not texture then
        button[setter](button, MODERN_TEXTURE)
        texture = button[getter](button)
    end
    if not texture then return end
    texture:SetTexture(MODERN_TEXTURE)
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    texture:ClearAllPoints()
    texture:SetAllPoints(button)
    texture:SetVertexColor(1, 1, 1)
    texture:SetAlpha(1)
end

local function ApplyModernPVPArt(button)
    local faction = UnitFactionGroup("player")
    local texture, coords
    if faction == "Alliance" then
        texture = MODERN_PVP_TEXTURE
        coords = { 0, 118 / 256, 0, 151 / 256 }
    elseif faction == "Horde" then
        texture = MODERN_PVP_TEXTURE
        coords = { 118 / 256, 236 / 256, 0, 151 / 256 }
    else
        texture = FLAT_TEXTURE_ROOT .. FLAT_ICONS.PVPMicroButton
        coords = { 0, 1, 0, 1 }
    end

    local icon = button._euiModernPVPIcon
    if not icon then
        icon = button:CreateTexture(nil, "ARTWORK")
        button._euiModernPVPIcon = icon
    end
    icon:SetTexture(texture)
    icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(button:GetWidth(), button:GetHeight())
    icon:SetAlpha(button:GetButtonState() == "PUSHED" and 0.7 or 1)
    icon:Show()

    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetTexture(texture)
        highlight:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        highlight:ClearAllPoints()
        highlight:SetAllPoints(button)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.5)
    end

    local pvpTexture = _G.PVPMicroButtonTexture
    if pvpTexture then pvpTexture:Hide() end
end

local function ApplyModernButton(button)
    local name = button:GetName()
    local normal = button:GetNormalTexture()
    local pushed = button:GetPushedTexture()
    local disabled = button:GetDisabledTexture()
    local highlight = button:GetHighlightTexture()

    if normal then normal:SetVertexColor(1, 1, 1); normal:SetAlpha(1) end
    if pushed then pushed:SetVertexColor(1, 1, 1); pushed:SetAlpha(1) end
    if disabled then disabled:SetVertexColor(1, 1, 1); disabled:SetAlpha(1) end
    if highlight then highlight:SetVertexColor(1, 1, 1); highlight:SetAlpha(1) end

    if name == "CharacterMicroButton" or name == "PVPMicroButton" then
        if normal then normal:SetTexture(nil) end
        if pushed then pushed:SetTexture(nil) end
        if disabled then disabled:SetTexture(nil) end
        if highlight then highlight:SetTexture(nil) end
        if name == "PVPMicroButton" then ApplyModernPVPArt(button) end
    else
        local states = MODERN_STATES[name]
        if states then
            SetStateTexture(button, "GetNormalTexture", "SetNormalTexture", states.up)
            SetStateTexture(button, "GetPushedTexture", "SetPushedTexture", states.down)
            SetStateTexture(button, "GetDisabledTexture", "SetDisabledTexture", states.disabled)
            SetStateTexture(button, "GetHighlightTexture", "SetHighlightTexture", states.highlight)
            if highlight then highlight:SetBlendMode("ADD") end
        end
    end

    local portrait = _G.MicroButtonPortrait
    if name == "CharacterMicroButton" and portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("CENTER", button, "CENTER", 0, 0)
        portrait:SetSize(18, 24)
        portrait:SetAlpha(1)
        portrait:Show()
    end

end

local function CreateModernBackground(button)
    if not button._euiModernBG then
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(MODERN_TEXTURE)
        bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
        bg:SetPoint("CENTER", button, "CENTER", -1, 1)
        bg:SetSize(32, 41)
        button._euiModernBG = bg

        local pushed = button:CreateTexture(nil, "BACKGROUND")
        pushed:SetTexture(MODERN_TEXTURE)
        pushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
        pushed:SetPoint("CENTER", button, "CENTER", -1, 1)
        pushed:SetSize(32, 41)
        pushed:Hide()
        button._euiModernPushedBG = pushed

        if not button._euiModernStateHooked then
            hooksecurefunc(button, "SetButtonState", function(self)
                local pushedNow = self:GetButtonState() == "PUSHED"
                if style == "modern" then
                    if self._euiModernBG then
                        if pushedNow then self._euiModernBG:Hide() else self._euiModernBG:Show() end
                    end
                    if self._euiModernPushedBG then
                        if pushedNow then self._euiModernPushedBG:Show() else self._euiModernPushedBG:Hide() end
                    end
                    if self._euiModernPVPIcon then
                        self._euiModernPVPIcon:SetAlpha(pushedNow and 0.7 or 1)
                    end
                end
            end)
            button._euiModernStateHooked = true
        end
    end

    local pushedNow = button.GetButtonState and button:GetButtonState() == "PUSHED"
    if pushedNow then
        button._euiModernBG:Hide()
        button._euiModernPushedBG:Show()
    else
        button._euiModernBG:Show()
        button._euiModernPushedBG:Hide()
    end
end

local function CreateFlatArt(button)
    if not button._euiFlatBG then
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(0.055, 0.055, 0.055, 0.94)
        bg:SetAllPoints(button)
        button._euiFlatBG = bg

        local border = {}
        for i = 1, 4 do
            local edge = button:CreateTexture(nil, "OVERLAY")
            edge:SetTexture(0.22, 0.22, 0.22, 0.9)
            border[i] = edge
        end
        border[1]:SetPoint("TOPLEFT", button, "TOPLEFT")
        border[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT")
        border[1]:SetHeight(1)
        border[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
        border[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
        border[2]:SetHeight(1)
        border[3]:SetPoint("TOPLEFT", button, "TOPLEFT")
        border[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
        border[3]:SetWidth(1)
        border[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT")
        border[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
        border[4]:SetWidth(1)
        button._euiFlatBorder = border

        button:HookScript("OnEnter", function(self)
            local edges = self._euiFlatBorder
            if edges then
                for i = 1, 4 do edges[i]:SetTexture(0.05, 0.82, 0.62, 0.95) end
            end
        end)
        button:HookScript("OnLeave", function(self)
            local edges = self._euiFlatBorder
            if edges then
                for i = 1, 4 do edges[i]:SetTexture(0.22, 0.22, 0.22, 0.9) end
            end
        end)
    end

    button._euiFlatBG:Show()
    for i = 1, #button._euiFlatBorder do
        button._euiFlatBorder[i]:Show()
    end

    local name = button:GetName()
    local path = FLAT_ICONS[name]
    local fit = FLAT_ICON_FIT[name]
    local normal = button:GetNormalTexture()
    local pushed = button:GetPushedTexture()
    local disabled = button:GetDisabledTexture()
    local highlight = button:GetHighlightTexture()
    if path then
        path = FLAT_TEXTURE_ROOT .. path
        if not disabled then
            button:SetDisabledTexture(path)
            disabled = button:GetDisabledTexture()
            if disabled then button._euiFlatCreatedDisabledTexture = true end
        end
        local coords = fit and fit.coords or { 0, 1, 0, 1 }
        local iconWidth = fit and fit.width or 21
        local iconHeight = fit and fit.height or 21
        local function PlaceIcon(texture, width, height)
            if not texture then return end
            texture:SetTexture(path)
            texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", button, "CENTER", 0, 0)
            texture:SetSize(width, height)
            texture:SetAlpha(1)
        end
        PlaceIcon(normal, iconWidth, iconHeight)
        PlaceIcon(pushed, iconWidth, iconHeight)
        PlaceIcon(disabled, iconWidth, iconHeight)
        if disabled then disabled:SetAlpha(0.4) end
        if pushed then pushed:SetVertexColor(0.75, 0.75, 0.75) end
        if highlight then
            highlight:SetTexture(path)
            highlight:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            highlight:ClearAllPoints()
            highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
            highlight:SetSize(iconWidth + 2, iconHeight + 2)
            highlight:SetBlendMode("ADD")
            highlight:SetAlpha(0.45)
        end
    end

    if name == "PVPMicroButton" and _G.PVPMicroButtonTexture then
        _G.PVPMicroButtonTexture:Hide()
    end
    if button._euiModernPVPIcon then
        button._euiModernPVPIcon:Hide()
    end

    if name == "CharacterMicroButton" and _G.MicroButtonPortrait then
        _G.MicroButtonPortrait:Hide()
    end
end

local function RestoreRegion(region, saved, preserveAppearance)
    if not region or not saved then return end
    if not preserveAppearance then
        region:SetTexture(saved.texture)
        if saved.texCoord then region:SetTexCoord(unpack(saved.texCoord)) end
        if saved.blendMode and region.SetBlendMode then
            region:SetBlendMode(saved.blendMode)
        end
        if saved.vertexColor then region:SetVertexColor(unpack(saved.vertexColor)) end
    end
    region:SetAlpha(saved.alpha or 1)
    region:ClearAllPoints()
    for i = 1, #saved.points do
        region:SetPoint(unpack(saved.points[i]))
    end
    if #saved.points == 0 and saved.width and saved.height then
        region:SetSize(saved.width, saved.height)
    end
end

local function HideCustomArt(button)
    if button._euiModernBG then button._euiModernBG:Hide() end
    if button._euiModernPushedBG then button._euiModernPushedBG:Hide() end
    if button._euiModernPVPIcon then button._euiModernPVPIcon:Hide() end
    if button._euiFlatBG then button._euiFlatBG:Hide() end
    if button._euiFlatBorder then
        for i = 1, #button._euiFlatBorder do
            button._euiFlatBorder[i]:Hide()
        end
    end
end

local function RestoreClassicButton(button)
    local saved = stockButtonArt[button]
    if button._euiFlatCreatedDisabledTexture then
        button:SetDisabledTexture(nil)
        button._euiFlatCreatedDisabledTexture = nil
    end
    if saved then
        RestoreRegion(button:GetNormalTexture(), saved.normal)
        RestoreRegion(button:GetPushedTexture(), saved.pushed)
        RestoreRegion(button:GetDisabledTexture(), saved.disabled)
        RestoreRegion(button:GetHighlightTexture(), saved.highlight)
    end
    HideCustomArt(button)

    if button:GetName() == "CharacterMicroButton" and _G.MicroButtonPortrait then
        -- Keep Blizzard's current player portrait; only restore its Classic
        -- geometry because UpdateMicroButtons may have refreshed it since load.
        RestoreRegion(_G.MicroButtonPortrait, stockPortraitArt, true)
        _G.MicroButtonPortrait:Show()
    elseif button:GetName() == "PVPMicroButton" and _G.PVPMicroButtonTexture then
        -- Faction art can change at runtime, so restore its position/size only.
        RestoreRegion(_G.PVPMicroButtonTexture, stockPVPArt, true)
        _G.PVPMicroButtonTexture:Show()
    end
end

local function ApplyButtonArt(button)
    if style == "modern" then
        if button._euiFlatBG then button._euiFlatBG:Hide() end
        if button._euiFlatBorder then
            for i = 1, #button._euiFlatBorder do button._euiFlatBorder[i]:Hide() end
        end
        ApplyModernButton(button)
        CreateModernBackground(button)
    elseif style == "eui" then
        if button._euiModernBG then button._euiModernBG:Hide() end
        if button._euiModernPushedBG then button._euiModernPushedBG:Hide() end
        CreateFlatArt(button)
    else
        RestoreClassicButton(button)
    end
end

local function LayoutButtons(force)
    if not IsAddOnLoaded("EllesmereUIActionBars") then return end
    if InCombatLockdown() then
        layoutPending = true
        return
    end

    style = GetStyle()
    local width, height, xStep = GetGeometry()
    local count = #buttons
    if count == 0 then return end

    local menuWidth = width + (count - 1) * xStep
    if menuFrame:GetWidth() ~= menuWidth or menuFrame:GetHeight() ~= height then
        menuFrame:SetSize(menuWidth, height)
    end
    if not menuFrame:GetPoint(1) then
        menuFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 2)
    end
    if _G.MainMenuBarArtFrame then
        local frameLevel = _G.MainMenuBarArtFrame:GetFrameLevel() + 2
        if menuFrame:GetFrameLevel() ~= frameLevel then
            menuFrame:SetFrameLevel(frameLevel)
        end
    end

    for i = 1, count do
        local button = buttons[i]
        if button:GetParent() ~= menuFrame then
            button:SetParent(menuFrame)
            force = true
        end

        if force or button:GetWidth() ~= width or button:GetHeight() ~= height then
            button:SetSize(width, height)
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", menuFrame, "BOTTOMLEFT", (i - 1) * xStep, 0)
        else
            local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
            if point ~= "BOTTOMLEFT" or relativeTo ~= menuFrame or relativePoint ~= "BOTTOMLEFT"
                or x ~= (i - 1) * xStep or y ~= 0 then
                button:ClearAllPoints()
                button:SetPoint("BOTTOMLEFT", menuFrame, "BOTTOMLEFT", (i - 1) * xStep, 0)
            end
        end

        if style == "classic" then
            button:SetHitRectInsets(0, 0, 18, 0)
        else
            button:SetHitRectInsets(0, 0, 0, 0)
        end
        if button._euiMicroArtStyle ~= style then
            ApplyButtonArt(button)
            button._euiMicroArtStyle = style
        end
    end

    layoutPending = false
end

local function SetModernPVPPressed(pressed)
    if style ~= "modern" then return end
    local button = _G.PVPMicroButton
    local icon = button and button._euiModernPVPIcon
    if icon then icon:SetAlpha(pressed and 0.7 or 1) end
end

if type(PVPMicroButton_SetPushed) == "function" then
    hooksecurefunc("PVPMicroButton_SetPushed", function() SetModernPVPPressed(true) end)
end
if type(PVPMicroButton_SetNormal) == "function" then
    hooksecurefunc("PVPMicroButton_SetNormal", function() SetModernPVPPressed(false) end)
end

local function QueueLayout()
    if InCombatLockdown() then
        layoutPending = true
    else
        LayoutButtons(false)
    end
end

-- The shared window-style picker calls this when EUI/Modern changes can apply
-- live. Chain any existing window refresh before updating the micro buttons.
if EllesmereUI then
    local refreshStyles = EllesmereUI._WSkinRefreshStyles
    EllesmereUI._WSkinRefreshStyles = function(...)
        if refreshStyles then refreshStyles(...) end
        QueueLayout()
    end
end

-- Called from ActionBars after it hides/reparents MainMenuBar. The fallback
-- layout keeps the bar usable if the Blizzard Skins sub-addon is disabled.
_G.EllesmereUI_ApplyMicroMenuLayout = function()
    LayoutButtons(true)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("VEHICLE_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" or event == "VEHICLE_UPDATE" then
        if event == "PLAYER_REGEN_ENABLED" and not layoutPending then return end
        QueueLayout()
    end
end)

if type(UpdateMicroButtons) == "function" then
    hooksecurefunc("UpdateMicroButtons", QueueLayout)
end
if type(MoveMicroButtons) == "function" then
    hooksecurefunc("MoveMicroButtons", QueueLayout)
end
if type(VehicleMenuBar_MoveMicroButtons) == "function" then
    hooksecurefunc("VehicleMenuBar_MoveMicroButtons", QueueLayout)
end
