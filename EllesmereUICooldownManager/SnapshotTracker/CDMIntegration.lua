local _, ns = ...

-- CDM bridge for the embedded SnapshotTracker engine. The standalone addon's
-- controller, Ace libraries, options, and free-floating display frames are not
-- loaded: CDM owns persistence, configuration, and the icon text overlay.
local Snapshot = ns.SnapshotTracker and ns.SnapshotTracker.SnapshotTracker
if not Snapshot then return end

local GetSpellInfo = GetSpellInfo
local DebuffViewer = _G.DebuffIconCooldownViewer

local initialized = false
local elapsedSinceUpdate = 0
local elapsedSinceRescan = 0
local UPDATE_INTERVAL = 0.10
local RESCAN_INTERVAL = 1
local trackingConfigured = false

local SNAPSHOT_POINTS = {
    center      = { "CENTER",      "CENTER",       0,  0 },
    top         = { "TOP",         "TOP",          0, -2 },
    bottom      = { "BOTTOM",      "BOTTOM",       0,  2 },
    left        = { "LEFT",        "LEFT",         2,  0 },
    right       = { "RIGHT",       "RIGHT",       -2,  0 },
    topleft     = { "TOPLEFT",     "TOPLEFT",      2, -2 },
    topright    = { "TOPRIGHT",    "TOPRIGHT",    -2, -2 },
    bottomleft  = { "BOTTOMLEFT",  "BOTTOMLEFT",   2,  2 },
    bottomright = { "BOTTOMRIGHT", "BOTTOMRIGHT", -2,  2 },
}

local function Initialize()
    if initialized then return end
    initialized = true
    Snapshot:Init()
    Snapshot:ResetPlayerInfo()
end

local function IsDebuffIcon(frame, fc)
    if not frame then return false end
    if frame._hostedAuraFamily == "debuffs" then return true end
    if frame.viewerFrame == DebuffViewer
       or frame.viewerFrame == _G.DebuffIconCooldownViewer then
        return true
    end
    local bd = fc and fc.barKey and ns.barDataByKey and ns.barDataByKey[fc.barKey]
    return bd and ns.IsBarDebuffFamily and ns.IsBarDebuffFamily(bd) or false
end

local function SpellNameForID(spellID)
    if not spellID or type(spellID) ~= "number" or spellID <= 0 then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name then return name end
    end
    return GetSpellInfo and GetSpellInfo(spellID) or nil
end

local function AuraNameForFrame(frame, fallbackSpellID)
    local cooldownID = frame and frame.cooldownID
    local getInfo = C_CooldownViewer
        and C_CooldownViewer.GetCooldownViewerCooldownInfo
    if cooldownID and getInfo then
        local info = getInfo(cooldownID)
        if info then
            -- WotLK definitions can display the applying spell while tracking a
            -- differently named aura (Icy Touch -> Frost Fever, for example).
            -- The compatibility viewer exposes the live aura identity explicitly.
            if info.matchedAuraName then return info.matchedAuraName end
            local auraName = SpellNameForID(info.matchedAuraSpellID or info.auraSpellID)
            if auraName then return auraName end
        end
    end
    return SpellNameForID(fallbackSpellID)
end

local function GetSnapshotText(frame, fc)
    if not IsDebuffIcon(frame, fc) then return nil end

    local spellID = fc and (fc.resolvedSid or fc.spellID)
    if not spellID and ns.ResolveFrameSpellID then
        spellID = ns.ResolveFrameSpellID(frame)
    end
    if not spellID then return nil end

    local barData = fc and fc.barKey and ns.barDataByKey
        and ns.barDataByKey[fc.barKey] or nil
    local sd = fc and fc.barKey and ns.GetBarSpellData
        and ns.GetBarSpellData(fc.barKey) or nil
    local settings = ns.ResolveSpellSettings
        and ns.ResolveSpellSettings(frame, spellID, sd, fc and fc.barKey) or nil
    if not (settings and settings.snapshotTracking) then return nil end

    local spellName = AuraNameForFrame(frame, spellID)
    if not spellName then return nil end

    local diff = Snapshot:GetSnapshotDiff("target", spellName)
    if diff then return diff end
    if Snapshot:HasSnapshot("target", spellName) then
        if not barData or barData.snapshotShowZero ~= false then
            return "|cffffffff0%|r"
        end
    end
    return nil
end

local function ApplyTextPosition(text, parent, barData)
    local p = SNAPSHOT_POINTS[(barData and barData.snapshotTextPosition) or "center"]
        or SNAPSHOT_POINTS.center
    text:ClearAllPoints()
    text:SetPoint(p[1], parent, p[2], p[3], p[4])
end

local function EnsureText(frame, fd, barData)
    local text = fd.snapshotText
    local parent = fd.textOverlay or frame
    if not text then
        text = parent:CreateFontString(nil, "OVERLAY")
        text:SetJustifyH("CENTER")
        text:SetDrawLayer("OVERLAY", 7)
        fd.snapshotText = text
    end
    ApplyTextPosition(text, parent, barData)
    local font = (ns.GetCDMFont and ns.GetCDMFont()) or STANDARD_TEXT_FONT
    local size = (barData and barData.snapshotTextSize) or 11
    if fd._snapshotFont ~= font or fd._snapshotFontSize ~= size then
        fd._snapshotFont = font
        fd._snapshotFontSize = size
        if EllesmereUI and EllesmereUI.ApplyIconTextFont then
            EllesmereUI.ApplyIconTextFont(text, font, size, "cdm")
        else
            text:SetFont(font, size, "THICKOUTLINE")
        end
    end
    return text
end

local function UpdateBackground(frame, fd, text, barData)
    if not (barData and barData.snapshotBgEnabled) then
        if fd.snapshotBg then fd.snapshotBg:Hide() end
        return
    end

    local parent = fd.textOverlay or frame
    local bg = fd.snapshotBg
    if not bg then
        bg = parent:CreateTexture(nil, "ARTWORK")
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetDrawLayer("ARTWORK", 0)
        fd.snapshotBg = bg
    end

    bg:ClearAllPoints()
    local width
    if barData.snapshotBgWidthMode == "manual" then
        width = barData.snapshotBgWidth or 36
        bg:SetPoint("CENTER", text, "CENTER", 0, 0)
    else
        width = frame:GetWidth() or 36
        -- A full-icon-width strip stays inside the icon even when the text is
        -- corner-aligned. Manual backgrounds instead remain centered on text.
        local position = barData.snapshotTextPosition or "center"
        local edge = (position == "top" or position == "topleft"
            or position == "topright") and "TOP"
            or ((position == "bottom" or position == "bottomleft"
                or position == "bottomright") and "BOTTOM" or "CENTER")
        bg:SetPoint(edge, frame, edge, 0, 0)
    end
    local height
    if barData.snapshotBgHeightMode == "manual" then
        height = barData.snapshotBgHeight or 16
    else
        height = math.max((text:GetStringHeight() or barData.snapshotTextSize or 11) + 4, 6)
    end
    bg:SetSize(math.max(width, 1), math.max(height, 1))
    bg:SetVertexColor(
        barData.snapshotBgR or 0,
        barData.snapshotBgG or 0,
        barData.snapshotBgB or 0,
        barData.snapshotBgA or 0.65)
    bg:Show()
end

local function UpdateIcon(frame)
    local fd = ns._hookFrameData and ns._hookFrameData[frame]
    local fc = ns._ecmeFC and ns._ecmeFC[frame]
    if not fd then return end

    local value = GetSnapshotText(frame, fc)
    if value and frame:IsShown() then
        local barData = fc and fc.barKey and ns.barDataByKey
            and ns.barDataByKey[fc.barKey] or nil
        local text = EnsureText(frame, fd, barData)
        text:SetText(value)
        text:Show()
        UpdateBackground(frame, fd, text, barData)
    elseif fd.snapshotText then
        fd.snapshotText:Hide()
        if fd.snapshotBg then fd.snapshotBg:Hide() end
    end
end

local function HideAllSnapshotText()
    for _, fd in pairs(ns._hookFrameData or {}) do
        if fd.snapshotText then fd.snapshotText:Hide() end
        if fd.snapshotBg then fd.snapshotBg:Hide() end
    end
end

function ns.RescanSnapshotTracking()
    trackingConfigured = false
    local store = ns.GetSpellSettingsStore and ns.GetSpellSettingsStore("debuffs")
    for _, settings in pairs(store or {}) do
        if type(settings) == "table" and rawget(settings, "snapshotTracking") == true then
            trackingConfigured = true
            break
        end
    end
    if not trackingConfigured then HideAllSnapshotText() end
    return trackingConfigured
end

function ns.RefreshSnapshotTracking()
    Initialize()
    if not trackingConfigured then
        HideAllSnapshotText()
        return
    end

    local seen = {}
    for _, icons in pairs(ns.cdmBarIcons or {}) do
        for i = 1, #icons do
            local frame = icons[i]
            if frame and not seen[frame] then
                seen[frame] = true
                UpdateIcon(frame)
            end
        end
    end
    -- A frame removed from cdmBarIcons can retain its pooled text object. Hide
    -- those too so a later pool reassignment never flashes the old percentage.
    for frame, fd in pairs(ns._hookFrameData or {}) do
        if not seen[frame] then
            if fd.snapshotText then fd.snapshotText:Hide() end
            if fd.snapshotBg then fd.snapshotBg:Hide() end
        end
    end
end

local eventFrame = ns.TakeShell and ns.TakeShell() or CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player", "target")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    Initialize()
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        Snapshot:HandleCLEU(...)
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" or unit == "target" then
            Snapshot:InvalidateCache()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        Snapshot:InvalidateCache()
        ns.RescanSnapshotTracking()
        ns.RefreshSnapshotTracking()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        Snapshot:ResetPlayerInfo()
        Snapshot:InvalidateCache()
        ns.RescanSnapshotTracking()
        ns.RefreshSnapshotTracking()
    end
end)
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceRescan = elapsedSinceRescan + elapsed
    if elapsedSinceRescan >= RESCAN_INTERVAL then
        elapsedSinceRescan = 0
        ns.RescanSnapshotTracking()
    end

    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if not trackingConfigured or elapsedSinceUpdate < UPDATE_INTERVAL then return end
    elapsedSinceUpdate = 0
    ns.RefreshSnapshotTracking()
end)

if IsLoggedIn and IsLoggedIn() then Initialize() end
