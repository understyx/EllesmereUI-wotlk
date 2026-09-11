-------------------------------------------------------------------------------
-- EllesmereUIQuestTracker_Wrath.lua
--
-- Wrath 3.3.5 compatibility for the Blizzard-backed quest tracker. The retail
-- implementation in the other files targets ObjectiveTrackerFrame and its
-- module/block pools; Wrath renders the same feature through WatchFrame and
-- WATCHFRAME_* line pools. This file replaces the three entry points only on
-- clients where WatchFrame is the native tracker.
-------------------------------------------------------------------------------
local _, ns = ...
local EQT = ns.EQT

if _G.ObjectiveTrackerFrame or not _G.WatchFrame then return end

local WatchFrame = _G.WatchFrame
local hiddenParent = EllesmereUI.SafeCreateFrame("Frame", "EllesmereUIQTWrathHiddenParent", UIParent)
hiddenParent:Hide()

local initializedSkin
local initializedVisibility
local initializedQoL
local visibilityHidden
local suppressed
local background
local resizeQueued
local relayoutQueued

local function GetAccent()
    local color = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if color then return color.r, color.g, color.b end
    return 0.047, 0.824, 0.624
end

local function GetClassColor()
    local token = EllesmereUI and EllesmereUI._playerClass
    local color = token and EllesmereUI.GetClassColor and EllesmereUI.GetClassColor(token)
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

local function GetHeaderColor()
    local cfg = EQT.DB()
    if cfg.headerShowClassColor then return GetClassColor() end
    if cfg.headerUseAccent ~= false then return GetAccent() end
    return cfg.headerR or 1, cfg.headerG or 1, cfg.headerB or 1
end

local function GetLineColor()
    local cfg = EQT.DB()
    if cfg.lineShowClassColor then return GetClassColor() end
    if cfg.lineUseAccent ~= false then return GetAccent() end
    return cfg.lineR or 1, cfg.lineG or 1, cfg.lineB or 1
end

local function GetTitleColor()
    local cfg = EQT.DB()
    return cfg.titleR or 1, cfg.titleG or 0.910, cfg.titleB or 0.471
end

local function GetCompletedColor()
    local cfg = EQT.DB()
    return cfg.completedR or 0.251, cfg.completedG or 1, cfg.completedB or 0.349
end

local function GetFont()
    local cfg = EQT.DB()
    if cfg.font and cfg.font ~= "__global" and EllesmereUI.ResolveFontName then
        local font = EllesmereUI.ResolveFontName(cfg.font)
        if font then return font end
    end
    if EllesmereUI.GetFontPath then
        return EllesmereUI.GetFontPath("questTracker") or "Fonts\\FRIZQT__.TTF"
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetOutline()
    if EllesmereUI.GetFontOutlineFlag then
        return EllesmereUI.GetFontOutlineFlag("questTracker") or ""
    end
    return ""
end

local function StyleFont(fontString, size, r, g, b)
    if not fontString then return end
    if EllesmereUI.PrimeFontShadow then
        local useShadow = EllesmereUI.GetFontUseShadow
            and EllesmereUI.GetFontUseShadow("questTracker")
        EllesmereUI.PrimeFontShadow(fontString, useShadow and true or false)
    end
    local ok = pcall(fontString.SetFont, fontString, GetFont(), size, GetOutline())
    if not ok then fontString:SetFont("Fonts\\FRIZQT__.TTF", size, GetOutline()) end
    if fontString.SetTextColor then fontString:SetTextColor(r, g, b) end
end

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function HasVisibleContent()
    local pools = {
        _G.WATCHFRAME_TIMERLINES,
        _G.WATCHFRAME_ACHIEVEMENTLINES,
        _G.WATCHFRAME_QUESTLINES,
    }
    for _, pool in ipairs(pools) do
        if pool then
            for _, line in ipairs(pool) do
                if IsShown(line) then return true end
            end
        end
    end
    return false
end

local function ShouldHideHeader()
    return EQT.Cfg("hideAllObjectivesHeader") ~= false
end

local function ApplyMasterHeaderVisibility()
    local header = _G.WatchFrameHeader
    local button = _G.WatchFrameCollapseExpandButton
    if ShouldHideHeader() then
        if header then header:Hide() end
        if button then button:Hide() end
    elseif HasVisibleContent() then
        if header then header:Show() end
        if button then button:Show() end
    end
end
EQT.ApplyMasterHeaderVisibility = ApplyMasterHeaderVisibility

local function StyleLine(line, isTitle, completed)
    if not line then return end
    local size
    local r, g, b
    if isTitle then
        size = EQT.Cfg("titleFontSize") or 12
        r, g, b = GetTitleColor()
    elseif completed then
        size = EQT.Cfg("objectiveFontSize") or 10
        r, g, b = GetCompletedColor()
    else
        size = EQT.Cfg("objectiveFontSize") or 10
        r, g, b = 0.72, 0.72, 0.72
    end
    StyleFont(line.text, size, r, g, b)
    if line.dash and not isTitle then
        StyleFont(line.dash, size, r, g, b)
    end
end

local function QuestIsComplete(watchIndex)
    if not watchIndex or not GetQuestIndexForWatch then return false end
    local questIndex = GetQuestIndexForWatch(watchIndex)
    if not questIndex then return false end
    local complete = select(7, GetQuestLogTitle(questIndex))
    return complete == true or complete == 1
end

local function StyleLinkButton(button)
    if not button or not button.lines then return end
    local complete = button.type == "QUEST" and QuestIsComplete(button.index)
    for index = button.startLine or 1, button.lastLine or 0 do
        StyleLine(button.lines[index], index == button.startLine, complete)
    end
end

local styledItems = setmetatable({}, { __mode = "k" })
local function StyleQuestItems()
    for index = 1, (_G.WATCHFRAME_NUM_ITEMS or 0) do
        local button = _G["WatchFrameItem" .. index]
        if button and not styledItems[button] then
            styledItems[button] = true
            local normal = _G["WatchFrameItem" .. index .. "NormalTexture"]
            local icon = _G["WatchFrameItem" .. index .. "IconTexture"]
            if normal then normal:SetAlpha(0) end
            if icon then
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            if EllesmereUI.PanelPP and EllesmereUI.PanelPP.CreateBorder then
                EllesmereUI.PanelPP.CreateBorder(button, 1, 0, 0, 0, 1)
            end
        end
    end
end

local function RestyleAll()
    local objectiveSize = EQT.Cfg("objectiveFontSize") or 10
    local lineHeight = math.max(16, objectiveSize + 4)
    local metricsChanged = _G.WATCHFRAME_LINEHEIGHT ~= lineHeight
        or _G.WATCHFRAME_MULTIPLE_LINEHEIGHT ~= math.max(29, lineHeight * 2 - 3)
    _G.WATCHFRAME_LINEHEIGHT = lineHeight
    _G.WATCHFRAME_MULTIPLE_LINEHEIGHT = math.max(29, lineHeight * 2 - 3)
    _G.WATCHFRAMELINES_FONTHEIGHT = objectiveSize
    _G.WATCHFRAMELINES_FONTSPACING = (lineHeight - objectiveSize) / 2

    local hr, hg, hb = GetHeaderColor()
    StyleFont(_G.WatchFrameTitle, EQT.Cfg("headerFontSize") or 13, hr, hg, hb)

    for _, button in ipairs(_G.WATCHFRAME_LINKBUTTONS or {}) do
        if IsShown(button) then StyleLinkButton(button) end
    end

    for index, line in ipairs(_G.WATCHFRAME_TIMERLINES or {}) do
        if IsShown(line) then StyleLine(line, index == 1, false) end
    end

    StyleQuestItems()
    ApplyMasterHeaderVisibility()
    if EQT.QueueResize then EQT.QueueResize() end
    if initializedSkin and metricsChanged and not relayoutQueued then
        relayoutQueued = true
        C_Timer.After(0, function()
            relayoutQueued = nil
            if _G.WatchFrame_Update and not WatchFrame.updating then
                _G.WatchFrame_Update(WatchFrame)
            end
        end)
    end
end
EQT.RestyleAll = RestyleAll
EQT.RefreshFonts = RestyleAll

-------------------------------------------------------------------------------
-- Background sized to the active WatchFrame line pools.
-------------------------------------------------------------------------------
local function GetTopAnchor()
    -- WatchFrameLines starts 30px below WatchFrame. Leave a 3px inset above
    -- its first line when the master header is hidden.
    return WatchFrame, "TOP", ShouldHideHeader() and -27 or 0
end

local function GetLowestFrame()
    local lowest, lowestY
    local pools = {
        _G.WATCHFRAME_TIMERLINES,
        _G.WATCHFRAME_ACHIEVEMENTLINES,
        _G.WATCHFRAME_QUESTLINES,
    }
    for _, pool in ipairs(pools) do
        if pool then
            for _, line in ipairs(pool) do
                if IsShown(line) and line.GetBottom then
                    local bottom = line:GetBottom()
                    if bottom and (not lowestY or bottom < lowestY) then
                        lowest, lowestY = line, bottom
                    end
                end
            end
        end
    end
    for index = 1, (_G.WATCHFRAME_NUM_ITEMS or 0) do
        local button = _G["WatchFrameItem" .. index]
        if IsShown(button) then
            local bottom = button:GetBottom()
            if bottom and (not lowestY or bottom < lowestY) then
                lowest, lowestY = button, bottom
            end
        end
    end
    return lowest, lowestY
end

local function EnsureBackground()
    if background then return background end
    background = EllesmereUI.SafeCreateFrame("Frame", "EllesmereUIQTBackground", UIParent)
    background:SetFrameStrata("BACKGROUND")
    background:EnableMouse(false)

    local texture = background:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    background.texture = texture

    local divider = background:CreateTexture(nil, "OVERLAY")
    background.divider = divider
    return background
end

local function TrackerMayRender()
    if visibilityHidden or suppressed then return false end
    if WatchFrame:GetParent() == hiddenParent then return false end
    if WatchFrame:GetAlpha() <= 0 then return false end
    return HasVisibleContent()
end

local function ResizeBackground()
    local bg = EnsureBackground()
    if not TrackerMayRender() then
        bg:Hide()
        return
    end

    local lowest, bottom = GetLowestFrame()
    if not lowest or not bottom then
        bg:Hide()
        return
    end

    local topFrame, topPoint, yOffset = GetTopAnchor()
    local top = topPoint == "TOP" and topFrame:GetTop() or topFrame:GetBottom()
    if not top then return end

    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", -6, yOffset)
    bg:SetPoint("TOPRIGHT", WatchFrame, "TOPRIGHT", 6, yOffset)
    bg:SetHeight(math.max(1, top + yOffset - bottom + 8))

    local cfg = EQT.DB()
    bg.texture:SetTexture(cfg.bgR or 0.035, cfg.bgG or 0.035, cfg.bgB or 0.035, cfg.bgAlpha or 0.75)

    local divider = bg.divider
    if cfg.showTopLine == false then
        divider:Hide()
    else
        local r, g, b = GetLineColor()
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", bg, "TOPLEFT")
        divider:SetPoint("TOPRIGHT", bg, "TOPRIGHT")
        divider:SetHeight(1)
        divider:SetTexture(r, g, b, 1)
        divider:Show()
    end
    bg:SetAlpha(WatchFrame:GetAlpha())
    bg:Show()
end
EQT.ResizeBGToContent = ResizeBackground

local function QueueResize()
    if resizeQueued then return end
    resizeQueued = true
    C_Timer.After(0, function()
        resizeQueued = nil
        ResizeBackground()
    end)
end
EQT.QueueResize = QueueResize

function EQT.ApplyBackground()
    ResizeBackground()
end

-------------------------------------------------------------------------------
-- Visibility and positioning.
-------------------------------------------------------------------------------
local function InBossCombat()
    if UnitExists and UnitExists("boss1") then return true end
    -- The original 3.3.5 client has no ENCOUNTER_START/END event. Raid combat
    -- is the closest stable fallback on servers that do not expose boss units.
    return UnitAffectingCombat and UnitAffectingCombat("player") or false
end

local function ShouldAutoHide()
    local _, instanceType = GetInstanceInfo()
    if instanceType == "arena" then return true end
    if instanceType ~= "raid" then return false end
    if EQT.Cfg("hideInRaidMode") == "always" then return true end
    return InBossCombat()
end

local function EvaluateVisibility()
    if EQT.Cfg("enabled") == false or suppressed or ShouldAutoHide() then
        return false
    end
    if EllesmereUI and EllesmereUI.EvalVisibility then
        return EllesmereUI.EvalVisibility(EQT.DB())
    end
    return true
end

local function UpdateVisibility()
    local result = EvaluateVisibility()
    visibilityHidden = result == false

    if visibilityHidden then
        if WatchFrame:GetParent() ~= hiddenParent then WatchFrame:SetParent(hiddenParent) end
        WatchFrame:SetAlpha(1)
    else
        if WatchFrame:GetParent() == hiddenParent then WatchFrame:SetParent(UIParent) end
        WatchFrame:SetAlpha(result == "mouseover" and 0 or 1)
    end

    if background then
        background:SetAlpha(WatchFrame:GetAlpha())
        if visibilityHidden then background:Hide() end
    end
    QueueResize()
end
EQT.UpdateVisibility = UpdateVisibility
EQT.RefreshStateDriver = UpdateVisibility

function EQT.ApplySuppression(on)
    suppressed = on and true or false
    UpdateVisibility()
end

function EQT.TrackerIsVisible()
    return not visibilityHidden and WatchFrame:GetAlpha() > 0 and HasVisibleContent()
end

function EQT.ApplyForceOnScreen()
    WatchFrame:SetClampedToScreen(EQT.Cfg("forceOnScreen") == true)
end

local function ApplySavedPosition()
    local pos = EQT.DB().unlockPos
    if not pos then return end
    WatchFrame:ClearAllPoints()
    WatchFrame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or pos.point or "TOPRIGHT", pos.x or 0, pos.y or 0)
    if WatchFrame.SetUserPlaced then
        WatchFrame:SetMovable(true)
        WatchFrame:SetUserPlaced(true)
        WatchFrame:SetMovable(false)
    end
end

local function RegisterUnlockElement()
    if not (EllesmereUI.RegisterUnlockElements and EllesmereUI.MakeUnlockElement) then return end
    local make = EllesmereUI.MakeUnlockElement
    EllesmereUI:RegisterUnlockElements({
        make({
            key = "EQT_WatchFrame",
            label = "Quest Tracker",
            group = "Blizzard Windows",
            order = 640,
            noResize = true,
            noAnchorTarget = true,
            getFrame = function() return WatchFrame end,
            getSize = function()
                return WatchFrame:GetWidth() or 204, WatchFrame:GetHeight() or 140
            end,
            savePos = function(_, point, relPoint, x, y)
                EQT.DB().unlockPos = { point = point, relPoint = relPoint, x = x, y = y }
            end,
            loadPos = function() return EQT.DB().unlockPos end,
            clearPos = function()
                EQT.DB().unlockPos = nil
                if WatchFrame.SetUserPlaced then
                    WatchFrame:SetMovable(true)
                    WatchFrame:SetUserPlaced(false)
                    WatchFrame:SetMovable(false)
                end
                WatchFrame:ClearAllPoints()
                WatchFrame:SetPoint("TOPRIGHT", _G.MinimapCluster or UIParent, "BOTTOMRIGHT", 0, 0)
            end,
            applyPos = ApplySavedPosition,
        })
    }, "EllesmereUIQuestTracker")
end

function EQT.InitVisibility()
    if initializedVisibility then return end
    initializedVisibility = true

    ApplySavedPosition()
    EQT.ApplyForceOnScreen()
    EnsureBackground()
    RegisterUnlockElement()

    local eventFrame = EllesmereUI.SafeCreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:SetScript("OnEvent", UpdateVisibility)

    if EllesmereUI.RegisterVisibilityUpdater then
        EllesmereUI.RegisterVisibilityUpdater(UpdateVisibility)
    end

    if EllesmereUI.RegisterMouseoverTarget then
        local proxy = {}
        proxy.IsShown = function() return not visibilityHidden and HasVisibleContent() end
        proxy.IsMouseOver = function()
            return WatchFrame:IsMouseOver()
                or (background and background:IsShown() and background:IsMouseOver())
        end
        proxy.GetRect = function() return WatchFrame:GetRect() end
        proxy.GetEffectiveScale = function() return WatchFrame:GetEffectiveScale() end
        proxy.SetAlpha = function(_, alpha)
            WatchFrame:SetAlpha(alpha)
            if background then background:SetAlpha(alpha) end
        end
        proxy.Show = function() QueueResize() end
        proxy.Hide = function()
            WatchFrame:SetAlpha(0)
            if background then background:SetAlpha(0) end
        end
        proxy.EnableMouse = function() end
        EllesmereUI.RegisterMouseoverTarget(proxy, function()
            if visibilityHidden or suppressed or ShouldAutoHide() then return false end
            return EllesmereUI.VisWantsMouseover(EQT.DB(), "visibility")
        end)
    end

    UpdateVisibility()
end

-------------------------------------------------------------------------------
-- Wrath quest QoL APIs.
-------------------------------------------------------------------------------
local function InstallAutoQuests()
    local frame = EllesmereUI.SafeCreateFrame("Frame")
    frame:RegisterEvent("QUEST_DETAIL")
    frame:RegisterEvent("QUEST_COMPLETE")
    frame:RegisterEvent("GOSSIP_SHOW")
    frame:SetScript("OnEvent", function(_, event)
        if EQT.Cfg("enabled") == false then return end

        if event == "QUEST_DETAIL" then
            if EQT.Cfg("autoAccept")
                and not (EQT.Cfg("autoAcceptShiftSkip") and IsShiftKeyDown()) then
                AcceptQuest()
            end
            return
        end

        if event == "QUEST_COMPLETE" then
            if EQT.Cfg("autoTurnIn")
                and not (EQT.Cfg("autoTurnInShiftSkip") and IsShiftKeyDown()) then
                local choices = GetNumQuestChoices()
                if choices <= 1 then GetQuestReward(choices) end
            end
            return
        end

        if event ~= "GOSSIP_SHOW" then return end
        if EQT.Cfg("autoTurnIn")
            and not (EQT.Cfg("autoTurnInShiftSkip") and IsShiftKeyDown())
            and GetNumGossipActiveQuests
            and SelectGossipActiveQuest and GetGossipActiveQuests then
            local count = GetNumGossipActiveQuests() or 0
            local quests = { GetGossipActiveQuests() }
            local stride = count > 0 and math.floor(#quests / count) or 0
            for index = 1, count do
                local base = (index - 1) * stride
                if quests[base + 4] then
                    SelectGossipActiveQuest(index)
                    return
                end
            end
        end

        if not EQT.Cfg("autoAccept")
            or (EQT.Cfg("autoAcceptShiftSkip") and IsShiftKeyDown()) then return end
        if not (GetNumGossipAvailableQuests and SelectGossipAvailableQuest) then return end
        local available = GetNumGossipAvailableQuests() or 0
        if available == 1 or (available > 0 and not EQT.Cfg("autoAcceptPreventMulti")) then
            SelectGossipAvailableQuest(1)
        end
    end)
end

local function ScanForQuestItem()
    if GetNumQuestWatches and GetQuestIndexForWatch then
        for index = 1, GetNumQuestWatches() do
            local questIndex = GetQuestIndexForWatch(index)
            local link = questIndex and GetQuestLogSpecialItemInfo(questIndex)
            local name = link and link:match("%[(.-)%]")
            if name then return name end
        end
    end
    for index = 1, (GetNumQuestLogEntries and GetNumQuestLogEntries() or 0) do
        local _, _, _, _, isHeader = GetQuestLogTitle(index)
        if not isHeader then
            local link = GetQuestLogSpecialItemInfo(index)
            local name = link and link:match("%[(.-)%]")
            if name then return name end
        end
    end
    return nil
end

local function InstallQuestItemHotkey()
    local button = EllesmereUI.SafeCreateFrame("Button", "EUI_QuestItemHotkeyBtn", UIParent,
        "SecureActionButtonTemplate, SecureFrameTemplate, SecureHandlerBaseTemplate")
    button:SetSize(1, 1)
    button:SetPoint("CENTER")
    button:SetAlpha(0)
    button:EnableMouse(false)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("type", "item")
    EQT.qItemBtn = button
    _G.BINDING_NAME_EUI_QUESTITEM = "Use Quest Item"

    local function ApplyHotkey()
        if InCombatLockdown() then return end
        local key = EQT.Cfg("questItemHotkey")
        local old1, old2 = GetBindingKey("EUI_QUESTITEM")
        local changed
        if old1 and old1 ~= key then SetBinding(old1); changed = true end
        if old2 and old2 ~= key then SetBinding(old2); changed = true end
        if key and key ~= "" and key ~= old1 and key ~= old2 then
            SetBinding(key, "EUI_QUESTITEM")
            changed = true
        end
        if changed then
            local bindingSet = GetCurrentBindingSet()
            if bindingSet and bindingSet >= 1 and bindingSet <= 2 then SaveBindings(bindingSet) end
        end
        button:SetAttribute("item", ScanForQuestItem())
        if button.ClearBindings then button:ClearBindings() end
        if key and key ~= "" and button:GetAttribute("item") and button.SetBindingClick then
            button:SetBindingClick(false, key, button, "LeftButton")
        end
    end
    EQT.ApplyQuestItemHotkey = ApplyHotkey
    EQT.UpdateQuestItemAttribute = ApplyHotkey

    local frame = EllesmereUI.SafeCreateFrame("Frame")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("UPDATE_BINDINGS")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", ApplyHotkey)
    C_Timer.After(1, ApplyHotkey)
end

function EQT.InitQoL()
    if initializedQoL then return end
    initializedQoL = true
    InstallAutoQuests()
    InstallQuestItemHotkey()
end

function EQT.InitSkin()
    if initializedSkin then return end
    initializedSkin = true

    hooksecurefunc("WatchFrame_Update", function()
        RestyleAll()
        UpdateVisibility()
    end)
    if _G.WatchFrameLinkButtonTemplate_Highlight then
        hooksecurefunc("WatchFrameLinkButtonTemplate_Highlight", function(button, onEnter)
            if not onEnter then StyleLinkButton(button) end
        end)
    end
    if EllesmereUI.RegAccent then
        EllesmereUI.RegAccent({ type = "callback", fn = RestyleAll })
    end

    RestyleAll()
    C_Timer.After(0.5, RestyleAll)
end
