-------------------------------------------------------------------------------
-- EllesmereUIBlizzardSkin_Achievements.lua
--
-- WotLK 3.3.5 Achievements presentation. Blizzard continues to own category
-- expansion, achievement selection/tracking, statistics, comparison, tooltips,
-- and scrolling; this file only replaces the native wood/parchment artwork and
-- reapplies the shared Retail-inspired visual language after native updates.
-------------------------------------------------------------------------------
local WSkin = _G.EllesmereUIBlizzardSkin
local EUI = _G.EllesmereUI
if not WSkin then return end

local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local FFD = setmetatable({}, { __mode = "k" })

local function GetFFD(frame)
    local data = FFD[frame]
    if not data then
        data = {}
        FFD[frame] = data
    end
    return data
end

local function IsForbidden(frame)
    return frame and frame.IsForbidden and frame:IsForbidden()
end

local function Fade(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

local function FadeTextureRegions(frame, keep)
    if not frame or IsForbidden(frame) or not frame.GetRegions then return end
    for i = 1, select("#", frame:GetRegions()) do
        local region = select(i, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture")
            and not (keep and keep[region]) then
            region:SetAlpha(0)
        end
    end
end

local function ApplyTypography(frame, tier, alpha)
    if frame then WSkin:ApplyRetailRegionTypography(frame, tier, alpha) end
end

local function SkinCloseButton(button, owner)
    if not button or not owner then return end
    local data = GetFFD(button)
    for _, getter in ipairs({
        "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture",
    }) do
        local texture = button[getter] and button[getter](button)
        if texture and texture ~= data.closeTexture then texture:SetAlpha(0) end
    end
    FadeTextureRegions(button, data.closeTexture and { [data.closeTexture] = true } or nil)
    if not data.closeTexture then
        local texture = button:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-close.tga")
        texture:SetPoint("CENTER")
        texture:SetSize(14, 14)
        texture:SetVertexColor(1, 1, 1, 0.75)
        data.closeTexture = texture
        button:HookScript("OnEnter", function()
            texture:SetVertexColor(1, 1, 1, 1)
        end)
        button:HookScript("OnLeave", function()
            texture:SetVertexColor(1, 1, 1, 0.75)
        end)
    end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -3, -3)
    button:SetSize(24, 24)
end

local function SkinShell(frame)
    if not frame then return end
    local data = GetFFD(frame)

    for _, name in ipairs({
        "AchievementFrameBackground",
        "AchievementFrameMetalBorderLeft", "AchievementFrameMetalBorderRight",
        "AchievementFrameMetalBorderTop", "AchievementFrameMetalBorderBottom",
        "AchievementFrameMetalBorderTopLeft", "AchievementFrameMetalBorderTopRight",
        "AchievementFrameMetalBorderBottomLeft", "AchievementFrameMetalBorderBottomRight",
        "AchievementFrameWoodBorderTopLeft", "AchievementFrameWoodBorderTopRight",
        "AchievementFrameWoodBorderBottomLeft", "AchievementFrameWoodBorderBottomRight",
        "AchievementFrameCategoriesBG", "AchievementFrameWaterMark",
    }) do
        Fade(_G[name])
    end
    if frame.SetBackdrop then frame:SetBackdrop(nil) end

    if not data.background then
        local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        background:SetTexture("Interface\\AddOns\\EllesmereUI\\media\\modern_blizz.tga")
        background:SetAllPoints(frame)
        data.background = background

        local overlay = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        data.overlay = overlay
        -- Shared retail shade: lifted header band over a near-black body.
        data.topBar = WSkin:ApplyRetailShellShade(frame, overlay)

        local baseLeft, baseRight, baseTop, baseBottom = 0.25, 1, 0, 0.75
        local baseWidth, baseHeight = baseRight - baseLeft, baseBottom - baseTop
        local imageAspect = 561 / 433
        local function UpdateTexCoords()
            local width, height = frame:GetSize()
            if not width or not height or width == 0 or height == 0 then return end
            local frameAspect = width / height
            if frameAspect > imageAspect then
                local visibleHeight = baseHeight * (imageAspect / frameAspect)
                local trim = (baseHeight - visibleHeight) / 2
                background:SetTexCoord(baseLeft, baseRight, baseTop + trim, baseBottom - trim)
            else
                local visibleWidth = baseWidth * (frameAspect / imageAspect)
                local trim = (baseWidth - visibleWidth) / 2
                background:SetTexCoord(baseLeft + trim, baseRight - trim, baseTop, baseBottom)
            end
        end
        hooksecurefunc(frame, "SetSize", UpdateTexCoords)
        hooksecurefunc(frame, "SetWidth", UpdateTexCoords)
        hooksecurefunc(frame, "SetHeight", UpdateTexCoords)
        UpdateTexCoords()

        local border = EUI and (EUI.PanelPP or EUI.PP)
        if border and border.CreateBorder then
            border.CreateBorder(frame, 0.2, 0.2, 0.2, 1, 1, "OVERLAY", 7)
        end
    end
    data.background:Show()
    data.overlay:Show()
    data.topBar:Show()

    local header = _G.AchievementFrameHeader
    if header then FadeTextureRegions(header) end
    local title = _G.AchievementFrameHeaderTitle
    -- On 3.3.5 ACHIEVEMENT_TITLE is the "Achievement Points" header label;
    -- the window name lives in ACHIEVEMENTS.
    WSkin:SetRetailPageTitle(frame, ACHIEVEMENTS or "Achievements", title)

    if not data.pointsCard then
        local card = CreateFrame("Frame", nil, frame)
        card:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -5)
        card:SetSize(154, 26)
        card:SetFrameLevel(frame:GetFrameLevel() + 2)
        WSkin:ApplyRetailSurface(card, "card")
        data.pointsCard = card

        local label = card:CreateFontString(nil, "OVERLAY")
        WSkin:ApplyRetailTypography(label, "secondary")
        label:SetText(ACHIEVEMENT_POINTS or "Achievement Points")
        label:SetPoint("LEFT", card, "LEFT", 8, 0)
        data.pointsLabel = label
    end
    local points = _G.AchievementFrameHeaderPoints
    if points then
        points:ClearAllPoints()
        points:SetPoint("RIGHT", data.pointsCard, "RIGHT", -8, 0)
        WSkin:ApplyRetailTypography(points, "value")
    end
    Fade(_G.AchievementFrameHeaderShield)
    Fade(_G.AchievementFrameHeaderPointBorder)
    Fade(_G.AchievementFrameHeaderLeft)
    Fade(_G.AchievementFrameHeaderRight)
    Fade(_G.AchievementFrameHeaderRightDDLInset)

    SkinCloseButton(_G.AchievementFrameCloseButton, frame)
end

local function LayoutMainPanels()
    local frame = _G.AchievementFrame
    local categories = _G.AchievementFrameCategories
    if not frame or not categories then return end

    categories:ClearAllPoints()
    categories:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -48)
    categories:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
    categories:SetWidth(180)
    WSkin:ApplyRetailSurface(categories, "body")

    for _, pane in ipairs({
        _G.AchievementFrameAchievements,
        _G.AchievementFrameStats,
        _G.AchievementFrameSummary,
        _G.AchievementFrameComparison,
    }) do
        if pane then
            pane:ClearAllPoints()
            pane:SetPoint("TOPLEFT", categories, "TOPRIGHT", 10, 0)
            pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
            FadeTextureRegions(pane)
            WSkin:ApplyRetailSurface(pane, "body")
            -- Each 3.3.5 content pane contains an unnamed, full-size frame
            -- whose tooltip-border backdrop supplies the old inset chrome.
            -- It is decorative only; named scroll/content children stay intact.
            for i = 1, select("#", pane:GetChildren()) do
                local child = select(i, pane:GetChildren())
                if child and child.GetName and not child:GetName() then
                    if child.SetBackdrop then child:SetBackdrop(nil) end
                    FadeTextureRegions(child)
                end
            end
        end
    end

    for _, name in ipairs({
        "AchievementFrameAchievementsBackground", "AchievementFrameSummaryBackground",
        "AchievementFrameComparisonBackground", "AchievementFrameComparisonDark",
        "AchievementFrameComparisonWatermark",
    }) do
        Fade(_G[name])
    end
    if _G.AchievementFrameStatsBG then FadeTextureRegions(_G.AchievementFrameStatsBG) end

    local filter = _G.AchievementFrameFilterDropDown
    if filter then
        filter:ClearAllPoints()
        filter:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -38, -1)
        filter:SetSize(126, 26)
        WSkin:ApplyRetailSurface(filter, "input")
        ApplyTypography(filter, "row")
        local filterButton = _G.AchievementFrameFilterDropDownButton
        if filterButton then
            for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
                Fade(filterButton[getter] and filterButton[getter](filterButton))
            end
        end
    end
end

local function AddRowHover(button)
    if not button then return end
    local data = GetFFD(button)
    if data.hover then return end
    local hover = button:CreateTexture(nil, "ARTWORK", nil, -4)
    hover:SetAllPoints(button)
    hover:SetTexture(1, 1, 1, 0.035)
    hover:Hide()
    data.hover = hover
    button:HookScript("OnEnter", function() hover:Show() end)
    button:HookScript("OnLeave", function() hover:Hide() end)
end

local selectedCategory

-- Blizzard keeps the authoritative selection on the active tab's function
-- table (achievements, statistics or comparison). The comparison summary row
-- is stored under its own ID but displayed as the "summary" element.
local function GetBlizzardSelectedCategory()
    local funcs = _G.achievementFunctions
    local selection = type(funcs) == "table" and funcs.selectedCategory or nil
    if selection ~= nil and selection == _G.ACHIEVEMENT_COMPARISON_SUMMARY_ID then
        selection = "summary"
    end
    return selection
end

local function SkinCategoryButton(button)
    if not button or not button.element then return end
    local data = GetFFD(button)
    Fade(button.background)
    Fade(button.GetHighlightTexture and button:GetHighlightTexture())
    button:SetWidth(176)
    local active = GetBlizzardSelectedCategory()
    if active == nil then active = selectedCategory end
    -- element.parent is true only for top-level categories that have
    -- children; leaf top-level entries (Summary, General, Feats of Strength)
    -- leave it nil. Style every top-level row alike, as retail does.
    local isChild = type(button.element.parent) == "number"
    WSkin:UpdateRetailRow(button, button.categoryID ~= nil and button.categoryID == active, not isChild)
    AddRowHover(button)

    if button.label then
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", isChild and 24 or 10, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -22, 0)
        button.label:SetJustifyH("LEFT")
        WSkin:ApplyRetailTypography(button.label, isChild and "row" or "section")
    end

    if button.element.parent == true then
        if not data.glyph then
            data.glyph = button:CreateFontString(nil, "OVERLAY")
            WSkin:ApplyRetailTypography(data.glyph, "section")
            data.glyph:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        end
        local ar, ag, ab = WSkin:GetRetailAccent()
        data.glyph:SetTextColor(ar, ag, ab, 1)
        data.glyph:SetText(button.element.collapsed and "+" or "-")
        data.glyph:Show()
    elseif data.glyph then
        data.glyph:Hide()
    end
end

local function RefreshCategoryButtons()
    local container = _G.AchievementFrameCategoriesContainer
    local buttons = container and container.buttons
    if not buttons then return end
    local active = GetBlizzardSelectedCategory()
    if active ~= nil then
        selectedCategory = active
        for _, button in ipairs(buttons) do SkinCategoryButton(button) end
        return
    end
    -- Fallback when the selection table is unavailable: Blizzard does not expose the selected category, but LockHighlight keeps
    -- the chosen row's native highlight shown. Read that state after its update
    -- pass (the texture itself stays transparent) so tab changes cannot leave
    -- our accent on a category from the previous page.
    for _, button in ipairs(buttons) do
        local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
        if button:IsShown() and highlight and highlight:IsShown()
            and (not button.IsMouseOver or not button:IsMouseOver()) then
            selectedCategory = button.categoryID
            break
        end
    end
    for _, button in ipairs(buttons) do SkinCategoryButton(button) end
end

local function HideAchievementCardArt(button)
    if not button then return end
    Fade(button.background)
    Fade(button.titleBar)
    Fade(button.glow)
    Fade(button.rewardBackground)
    local name = button.GetName and button:GetName()
    if name then
        for _, suffix in ipairs({
            "Background",
            "BottomLeftTsunami", "BottomRightTsunami", "TopLeftTsunami", "TopRightTsunami",
            "BottomTsunami1", "TopTsunami1", "TitleBackground", "Glow", "RewardBackground",
        }) do
            Fade(_G[name .. suffix])
        end
    end
    if button.highlight then FadeTextureRegions(button.highlight) end
end

local function SkinAchievementIcon(iconFrame, size)
    if not iconFrame then return end
    local name = iconFrame.GetName and iconFrame:GetName()
    local texture = iconFrame.texture or iconFrame.Texture or (name and _G[name .. "Texture"])
    if not texture then return end
    Fade(iconFrame.overlay or (name and _G[name .. "Overlay"]))
    Fade(iconFrame.bling or (name and _G[name .. "Bling"]))
    Fade(iconFrame.backfill or (name and _G[name .. "Backfill"]))
    WSkin:ApplyRetailIcon(texture, iconFrame, size or 48)
end

local function SkinAchievementButton(button)
    if not button then return end
    HideAchievementCardArt(button)
    WSkin:UpdateRetailRow(button, button.selected and true or false, false)
    AddRowHover(button)
    SkinAchievementIcon(button.icon, 48)
    WSkin:ApplyRetailTypography(button.label, "section")
    WSkin:ApplyRetailTypography(button.description, "row")
    WSkin:ApplyRetailTypography(button.hiddenDescription, "row")
    WSkin:ApplyRetailTypography(button.reward, "secondary")
    WSkin:ApplyRetailTypography(button.dateCompleted, "secondary")
    if button.shield and button.shield.points then
        WSkin:ApplyRetailTypography(button.shield.points, "value")
    end
    if button.plusMinus then
        local data = GetFFD(button)
        local shown = button.plusMinus:IsShown()
        button.plusMinus:SetAlpha(0)
        if shown then
            if not data.expandGlyph then
                data.expandGlyph = button:CreateFontString(nil, "OVERLAY")
                WSkin:ApplyRetailTypography(data.expandGlyph, "section")
                data.expandGlyph:SetPoint("TOPLEFT", button, "TOPLEFT", 72, -10)
            end
            local ar, ag, ab = WSkin:GetRetailAccent()
            data.expandGlyph:SetTextColor(ar, ag, ab, 1)
            data.expandGlyph:SetText(button.collapsed and "+" or "-")
            data.expandGlyph:Show()
        elseif data.expandGlyph then
            data.expandGlyph:Hide()
        end
    end
end

local function RefreshAchievementButtons()
    local container = _G.AchievementFrameAchievementsContainer
    local buttons = container and container.buttons
    if not buttons then return end
    for _, button in ipairs(buttons) do
        if button:IsShown() then SkinAchievementButton(button) end
    end
end

local function SkinSummaryButton(button)
    if not button then return end
    HideAchievementCardArt(button)
    WSkin:UpdateRetailRow(button, false, false)
    AddRowHover(button)
    SkinAchievementIcon(button.icon, 36)
    WSkin:ApplyRetailTypography(button.label, "section")
    WSkin:ApplyRetailTypography(button.description, "secondary")
    WSkin:ApplyRetailTypography(button.dateCompleted, "secondary")
    if button.shield and button.shield.points then
        WSkin:ApplyRetailTypography(button.shield.points, "value")
    end
end

local function SkinProgressBar(bar)
    if not bar then return end
    for _, suffix in ipairs({ "Left", "Right", "Middle", "FillBar", "BorderLeft", "BorderRight", "BorderCenter", "BG" }) do
        local name = bar.GetName and bar:GetName()
        if name then Fade(_G[name .. suffix]) end
    end
    WSkin:ApplyRetailSurface(bar, "row")
    if bar.SetStatusBarTexture then bar:SetStatusBarTexture(WHITE8X8) end
    local ar, ag, ab = WSkin:GetRetailAccent()
    if bar.SetStatusBarColor then bar:SetStatusBarColor(ar, ag, ab, 0.82) end
    local name = bar.GetName and bar:GetName()
    if name then
        -- The stock labels sit near the top of the old bar art; centre them
        -- on the flat bar.
        local label = _G[name .. "Label"] or _G[name .. "Title"]
        local text = _G[name .. "Text"]
        if label and label.ClearAllPoints then
            label:ClearAllPoints()
            label:SetPoint("LEFT", bar, "LEFT", 8, 0)
        end
        if text and text.ClearAllPoints then
            text:ClearAllPoints()
            text:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
        end
        WSkin:ApplyRetailTypography(label, "row")
        WSkin:ApplyRetailTypography(text, "value")
    end
end

-- Blizzard spaces the category bars for its taller bar art, which pushes the
-- last row past the bottom of the summary pane. Lay them out as a two-column
-- grid with retail's tighter rhythm.
local SUMMARY_BAR_GAP = 8
local function LayoutSummaryBars()
    local total = _G.AchievementFrameSummaryCategoriesStatusBar
    if not total then return end
    for i = 1, 8 do
        local bar = _G["AchievementFrameSummaryCategoriesCategory" .. i]
        if bar then
            local above = i <= 2 and total or _G["AchievementFrameSummaryCategoriesCategory" .. (i - 2)]
            local gap = i <= 2 and SUMMARY_BAR_GAP * 2 or SUMMARY_BAR_GAP
            bar:ClearAllPoints()
            if i % 2 == 1 then
                bar:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
            else
                bar:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -gap)
            end
        end
    end
end

local function RefreshSummary()
    Fade(_G.AchievementFrameSummaryBackground)
    for _, headerName in ipairs({
        "AchievementFrameSummaryAchievementsHeader",
        "AchievementFrameSummaryCategoriesHeader",
    }) do
        local header = _G[headerName]
        if header then
            FadeTextureRegions(header)
            WSkin:ApplyRetailSurface(header, "header")
            ApplyTypography(header, "section")
        end
    end
    local summaryButtons = _G.AchievementFrameSummaryAchievements
        and _G.AchievementFrameSummaryAchievements.buttons
    if summaryButtons then
        for _, button in ipairs(summaryButtons) do
            if button:IsShown() then SkinSummaryButton(button) end
        end
    end
    SkinProgressBar(_G.AchievementFrameSummaryCategoriesStatusBar)
    for i = 1, 8 do
        SkinProgressBar(_G["AchievementFrameSummaryCategoriesCategory" .. i])
    end
    LayoutSummaryBars()
    WSkin:ApplyRetailTypography(_G.AchievementFrameSummaryAchievementsEmptyText, "secondary")
end

local function SkinStatButton(button, isHeader)
    if not button then return end
    Fade(button.background)
    Fade(button.left)
    Fade(button.middle)
    Fade(button.right)
    Fade(button.GetHighlightTexture and button:GetHighlightTexture())
    WSkin:UpdateRetailRow(button, false, isHeader and true or false)
    AddRowHover(button)
    WSkin:ApplyRetailTypography(button.title, "section")
    WSkin:ApplyRetailTypography(button.text or (button.GetFontString and button:GetFontString()), "row")
    WSkin:ApplyRetailTypography(button.value, "value")
end

local function RefreshStats()
    local container = _G.AchievementFrameStatsContainer
    local buttons = container and container.buttons
    if not buttons then return end
    for _, button in ipairs(buttons) do
        if button:IsShown() then SkinStatButton(button, button.isHeader) end
    end
end

local function RefreshDynamicProgressBars()
    for i = 1, 40 do
        local bar = _G["AchievementFrameProgressBar" .. i]
        if bar then SkinProgressBar(bar) end
    end
end

local function UpdateTabs()
    local frame = _G.AchievementFrame
    if not frame then return end
    local tabs = { _G.AchievementFrameTab1, _G.AchievementFrameTab2 }
    if not tabs[1] or not tabs[2] then return end
    for _, tab in ipairs(tabs) do
        tab:Show()
        WSkin:StyleRetailTab(tab)
        tab:SetFrameLevel(frame:GetFrameLevel() + 5)
    end
    WSkin:LayoutRetailTabRow(tabs, frame)
    WSkin:UpdateRetailTab(tabs[1], frame.selectedTab == 1)
    WSkin:UpdateRetailTab(tabs[2], frame.selectedTab == 2)
end

local function SkinScrollBars()
    for _, scrollbar in ipairs({
        _G.AchievementFrameCategoriesContainerScrollBar,
        _G.AchievementFrameAchievementsContainerScrollBar,
        _G.AchievementFrameStatsContainerScrollBar,
        _G.AchievementFrameComparisonContainerScrollBar,
        _G.AchievementFrameComparisonStatsContainerScrollBar,
    }) do
        if scrollbar then WSkin:HandleRetailScrollBar(scrollbar) end
    end
end

local function RefreshAll()
    local frame = _G.AchievementFrame
    if not frame then return end
    SkinShell(frame)
    LayoutMainPanels()
    SkinScrollBars()
    RefreshCategoryButtons()
    RefreshAchievementButtons()
    RefreshSummary()
    RefreshStats()
    RefreshDynamicProgressBars()
    UpdateTabs()
end

local function InstallAchievementSkin()
    local frame = _G.AchievementFrame
    if not frame or GetFFD(frame).installed then return end
    GetFFD(frame).installed = true

    if _G.AchievementFrameCategories_DisplayButton then
        hooksecurefunc("AchievementFrameCategories_DisplayButton", SkinCategoryButton)
    end
    if _G.AchievementFrameCategories_SelectButton then
        hooksecurefunc("AchievementFrameCategories_SelectButton", function(button)
            selectedCategory = button and button.categoryID
            RefreshCategoryButtons()
        end)
    end
    if _G.AchievementFrameCategories_Update then
        hooksecurefunc("AchievementFrameCategories_Update", function()
            LayoutMainPanels()
            RefreshCategoryButtons()
        end)
    end
    if _G.AchievementButton_DisplayAchievement then
        hooksecurefunc("AchievementButton_DisplayAchievement", function(button)
            SkinAchievementButton(button)
            RefreshDynamicProgressBars()
        end)
    end
    if _G.AchievementButton_OnClick then
        hooksecurefunc("AchievementButton_OnClick", RefreshAchievementButtons)
    end
    if _G.AchievementFrameAchievements_Update then
        hooksecurefunc("AchievementFrameAchievements_Update", function()
            LayoutMainPanels()
            RefreshAchievementButtons()
        end)
    end
    if _G.AchievementFrameSummary_Update then
        hooksecurefunc("AchievementFrameSummary_Update", RefreshSummary)
    end
    if _G.AchievementFrameStats_SetStat then
        hooksecurefunc("AchievementFrameStats_SetStat", function(button)
            SkinStatButton(button, false)
        end)
    end
    if _G.AchievementFrameStats_SetHeader then
        hooksecurefunc("AchievementFrameStats_SetHeader", function(button)
            SkinStatButton(button, true)
        end)
    end
    if _G.AchievementFrameStats_Update then
        hooksecurefunc("AchievementFrameStats_Update", function()
            LayoutMainPanels()
            RefreshStats()
        end)
    end
    if _G.AchievementFrameComparison_Update then
        hooksecurefunc("AchievementFrameComparison_Update", LayoutMainPanels)
    end
    if _G.AchievementFrameComparison_UpdateStats then
        hooksecurefunc("AchievementFrameComparison_UpdateStats", LayoutMainPanels)
    end
    if _G.AchievementFrame_ShowSubFrame then
        hooksecurefunc("AchievementFrame_ShowSubFrame", RefreshAll)
    end
    if _G.AchievementFrameBaseTab_OnClick then
        hooksecurefunc("AchievementFrameBaseTab_OnClick", UpdateTabs)
    end
    if _G.AchievementFrameComparisonTab_OnClick then
        hooksecurefunc("AchievementFrameComparisonTab_OnClick", UpdateTabs)
    end

    frame:HookScript("OnShow", RefreshAll)
    RefreshAll()
end

WSkin:AddCallbackForAddon(
    "Blizzard_AchievementUI",
    "Skin_Achievements",
    InstallAchievementSkin,
    "achievements"
)
