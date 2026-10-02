local addon, ns = ...

local pairs, ipairs, type = pairs, ipairs, type
local max, min, floor = math.max, math.min, math.floor
local GetTime = GetTime
local UnitExists = UnitExists
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitName = UnitName
local UnitClass = UnitClass
local GetSpellInfo = GetSpellInfo
local IsSpellKnown = IsSpellKnown
local CreateFrame = CreateFrame
local FAILED = FAILED or "Failed"
local INTERRUPTED = INTERRUPTED or "Interrupted"

local Cast = {}
ns.Cast = Cast

local function DB()
    return (ns.db and ns.db.profile) or ns.defaults or {}
end

--------------------------------------------------------------------------------
-- Interrupt Cooldown Detection for Kick Hint
--------------------------------------------------------------------------------
local PLAYER_INTERRUPTS = {
    -- Kick (Rogue)
    [1766]  = true,
    -- Pummel (Warrior)
    [6552]  = true,
    -- Shield Bash (Warrior/Paladin)
    [72]    = true,
    -- Mind Freeze (Death Knight)
    [47528] = true,
    -- Strangulate (Death Knight)
    [47476] = true,
    -- Counterspell (Mage)
    [2139]  = true,
    -- Wind Shear (Shaman)
    [57994] = true,
    -- Feral Charge Effect (Druid)
    [16979] = true,
    -- Bash (Druid)
    [5211]  = true,
    -- Silence (Priest)
    [15487] = true,
    -- Silencing Shot (Hunter)
    [34490] = true,
    -- Spell Lock (Warlock Pet)
    [19647] = true,
}

local function IsPlayerInterruptReady()
    for spellId in pairs(PLAYER_INTERRUPTS) do
        local known = not IsSpellKnown or IsSpellKnown(spellId) or IsSpellKnown(spellId, true)
        local name = known and GetSpellInfo(spellId)
        if name and known then
            local start, duration = GetSpellCooldown(name)
            if start == 0 or (start and duration and (GetTime() >= start + duration)) then
                return true
            end
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Border Helpers
--------------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function AddEdge(parent, first, second, vertical)
    local edge = parent:CreateTexture(nil, "OVERLAY")
    edge:SetTexture(WHITE)
    edge:SetVertexColor(0, 0, 0, 1)
    edge:SetPoint(unpack(first))
    edge:SetPoint(unpack(second))
    if vertical then edge:SetWidth(1) else edge:SetHeight(1) end
    return edge
end

local function CreateBorder(bar, texParent)
    texParent = texParent or bar
    return {
        AddEdge(texParent, { "TOPLEFT", bar, "TOPLEFT", -1, 1 }, { "TOPRIGHT", bar, "TOPRIGHT", 1, 1 }),
        AddEdge(texParent, { "BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1 }, { "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1 }),
        AddEdge(texParent, { "TOPLEFT", bar, "TOPLEFT", -1, 1 }, { "BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1 }, true),
        AddEdge(texParent, { "TOPRIGHT", bar, "TOPRIGHT", 1, 1 }, { "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1 }, true),
    }
end

local function SetBorder(border, shown, color, size)
    if not border then return end
    size = tonumber(size) or 1
    border[1]:SetHeight(size)
    border[2]:SetHeight(size)
    border[3]:SetWidth(size)
    border[4]:SetWidth(size)
    for _, edge in ipairs(border) do
        if color then edge:SetVertexColor(color.r or 0, color.g or 0, color.b or 0, 1) end
        if shown then edge:Show() else edge:Hide() end
    end
end

--------------------------------------------------------------------------------
-- Cast Bar Construction & Skinning
--------------------------------------------------------------------------------
function Cast:CreateCastBar(plate)
    if plate.cast then return end

    local cast = plate.nativeCast or CreateFrame("StatusBar", nil, plate.frame or plate)
    plate.cast = cast
    cast.isNativeNameplateCast = plate.nativeCast ~= nil
    if not cast.isNativeNameplateCast then cast:Hide() end

    -- Cast Background
    local castBg = cast:CreateTexture(nil, "BACKGROUND")
    castBg:SetTexture(WHITE)
    castBg:SetAllPoints(cast)
    plate.castBg = castBg
    plate.castBG = castBg -- options compatibility

    -- Cast Border – lives on a dedicated frame (child of plate.frame) so its
    -- level can be controlled by SyncStrata, matching how health borders work.
    local castBorderFrame = CreateFrame("Frame", nil, plate.frame or plate)
    castBorderFrame:SetAllPoints(cast)
    plate.castBorderFrame = castBorderFrame
    plate.castBorder = CreateBorder(cast, castBorderFrame)

    -- Cast Spark
    local spark = cast:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetWidth(16)
    plate.castSpark = spark

    -- Spell Icon
    local iconFrame = CreateFrame("Frame", nil, cast)
    iconFrame:SetSize(16, 16)
    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(iconFrame)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    plate.castIconFrame = iconFrame
    plate.castIcon = iconTex

    -- Uninterruptible Shield
    local shield = cast:CreateTexture(nil, "OVERLAY")
    shield:SetTexture("Interface\\AddOns\\EllesmereUI\\media\\textures\\cast-shield.tga")
    shield:SetSize(14, 14)
    shield:SetPoint("CENTER", cast, "LEFT", 0, 0)
    shield:Hide()
    plate.castShield = shield

    -- Cast Spell Name Text
    local nameText = cast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.castText = nameText
    plate.castName = nameText

    local targetText = cast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.castTarget = targetText

    -- Cast Timer Text
    local timerText = cast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.castTimer = timerText

    -- Never replace the stock cast bar's engine script. Hook it so its physical
    -- show/value lifecycle remains authoritative for anonymous nameplates.
    cast:HookScript("OnUpdate", function(self, elapsed)
        Cast:OnCastUpdate(plate, elapsed)
    end)
    if cast.isNativeNameplateCast then
        cast:HookScript("OnShow", function()
            Cast:ApplyStyle(plate)
            Cast:UpdateCastColor(plate)
        end)
        cast:HookScript("OnHide", function()
            cast.spellName = nil
            cast.startTime = nil
            cast.endTime = nil
            cast.flashTimer = nil
            cast.interrupted = false
            cast.failed = false
            cast.lastNativeValue = nil
            cast.nativeIsChannel = nil
        end)
    end

    self:ApplyStyle(plate)
end

function Cast:ApplyStyle(plate)
    local cast = plate.cast
    if not cast then return end

    local db = DB()
    local castH = db.castBarHeight or 17
    local barW = ns.GetHealthBarWidth and ns.GetHealthBarWidth() or ns.BAR_W

    if ns.LayoutCastBar then
        ns.LayoutCastBar(plate, barW, castH)
    else
        cast:ClearAllPoints()
        cast:SetPoint("TOP", plate.health, "BOTTOM", 0, -2)
        cast:SetSize(barW, castH)
    end

    -- Texture
    local texKey = db.castBarTexture or "none"
    local texPath = EllesmereUI and EllesmereUI.ResolveTexturePath
        and EllesmereUI.ResolveTexturePath(ns.healthBarTextures, texKey, "Interface\\Buttons\\WHITE8x8")
        or "Interface\\Buttons\\WHITE8x8"
    cast:SetStatusBarTexture(texPath)

    -- Background
    if plate.castBg then
        local bgC = db.castBgColor or ns.defaults.castBgColor
        local bgA = db.castBgAlpha or ns.defaults.castBgAlpha or 0.9
        plate.castBg:SetVertexColor(bgC.r, bgC.g, bgC.b, bgA)
    end

    -- Border
    local bSize = db.castBorderSize or 0
    local bColor = db.castBorderColor or ns.defaults.castBorderColor
    SetBorder(plate.castBorder, bSize > 0, bColor, bSize)

    -- Spark
    if plate.castSpark then
        if db.castBarSparkEnabled ~= false then
            plate.castSpark:SetHeight(castH * 2.2)
            plate.castSpark:Show()
        else
            plate.castSpark:Hide()
        end
    end

    -- Icon
    if ns.LayoutCastIcon and plate.castIconFrame then
        ns.LayoutCastIcon(plate, castH)
        if ns.GetShowCastIcon and ns.GetShowCastIcon() then
            plate.castIconFrame:Show()
        else
            plate.castIconFrame:Hide()
        end
    end

    -- Font formatting
    local outline = ns.GetNPOutline and ns.GetNPOutline() or "OUTLINE"

    if plate.castText then
        local nSize = db.castNameSize or 10
        local nColor = db.castNameColor or ns.defaults.castNameColor
        if ns.SetFSFont then ns.SetFSFont(plate.castText, nSize, outline) end
        plate.castText:SetTextColor(nColor.r, nColor.g, nColor.b, 1)
        plate.castText:ClearAllPoints()
        local nSide = db.castNameSide or "left"
        if nSide == "none" then
            plate.castText:Hide()
        elseif nSide == "right" then
            plate.castText:SetPoint("RIGHT", cast, "RIGHT", -2 + (db.castNameOffsetX or 0), db.castNameOffsetY or 0)
            plate.castText:Show()
        elseif nSide == "center" then
            plate.castText:SetPoint("CENTER", cast, "CENTER", db.castNameOffsetX or 0, db.castNameOffsetY or 0)
            plate.castText:Show()
        else
            plate.castText:SetPoint("LEFT", cast, "LEFT", 2 + (db.castNameOffsetX or 0), db.castNameOffsetY or 0)
            plate.castText:Show()
        end
        plate.castText:SetWidth(max(1, barW * (db.castNameWidthPct or 42) / 100))
        if plate.castText.SetWordWrap then plate.castText:SetWordWrap(db.castNameWrap == true) end
    end

    if plate.castTarget then
        local size = db.castTargetSize or 10
        local color = db.castTargetColor or ns.defaults.castTargetColor
        if ns.SetFSFont then ns.SetFSFont(plate.castTarget, size, outline) end
        plate.castTarget:SetTextColor(color.r, color.g, color.b, 1)
        plate.castTarget:ClearAllPoints()
        local side = db.castTargetSide or "right"
        if side == "none" then
            plate.castTarget:Hide()
        elseif side == "left" then
            plate.castTarget:SetPoint("LEFT", cast, "LEFT", 2 + (db.castTargetOffsetX or 0), db.castTargetOffsetY or 0)
            plate.castTarget:Show()
        elseif side == "center" then
            plate.castTarget:SetPoint("CENTER", cast, "CENTER", db.castTargetOffsetX or 0, db.castTargetOffsetY or 0)
            plate.castTarget:Show()
        else
            plate.castTarget:SetPoint("RIGHT", cast, "RIGHT", -2 + (db.castTargetOffsetX or 0), db.castTargetOffsetY or 0)
            plate.castTarget:Show()
        end
        plate.castTarget:SetWidth(max(1, barW * (db.castTargetWidthPct or 42) / 100))
        if plate.castTarget.SetWordWrap then plate.castTarget:SetWordWrap(db.castTargetWrap == true) end
    end

    if plate.castTimer then
        local tSize = db.castTimerSize or 10
        local tColor = db.castTimerColor or ns.defaults.castTimerColor
        if ns.SetFSFont then ns.SetFSFont(plate.castTimer, tSize, outline) end
        plate.castTimer:SetTextColor(tColor.r, tColor.g, tColor.b, 1)
        plate.castTimer:ClearAllPoints()
        local tSide = db.castTimerSide or "right"
        if tSide == "left" then
            plate.castTimer:SetPoint("LEFT", cast, "LEFT", 2 + (db.castTimerOffsetX or 0), db.castTimerOffsetY or 0)
        else
            plate.castTimer:SetPoint("RIGHT", cast, "RIGHT", -2 + (db.castTimerOffsetX or 0), db.castTimerOffsetY or 0)
        end
        if db.showCastTimer == false then
            plate.castTimer:Hide()
        else
            plate.castTimer:Show()
        end
    end
end

--------------------------------------------------------------------------------
-- Cast Lifecycle Handlers
--------------------------------------------------------------------------------
function Cast:StartCast(plate, spellName, texture, startTime, endTime, notInterruptible, isChannel)
    if not plate or not plate.cast then return end

    local db = DB()
    local cast = plate.cast

    cast.spellName = spellName
    cast.texture = texture
    cast.startTime = startTime
    cast.endTime = endTime
    cast.isChannel = isChannel
    cast.notInterruptible = notInterruptible
    cast.interrupted = false
    cast.failed = false
    cast.flashTimer = nil

    local total = max(0.001, endTime - startTime)
    cast:SetMinMaxValues(0, total)

    if isChannel then
        cast.value = max(0, endTime - GetTime())
    else
        cast.value = max(0, GetTime() - startTime)
    end
    cast:SetValue(cast.value)

    -- Icon
    if plate.castIcon then
        plate.castIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Text
    if plate.castText then
        plate.castText:SetText(spellName or "")
    end

    -- Shield
    if plate.castShield then
        if notInterruptible and db.castBarShieldEnabled ~= false then
            plate.castShield:Show()
        else
            plate.castShield:Hide()
        end
    end

    -- Color
    self:UpdateCastColor(plate)

    cast:Show()
end

function Cast:StopCast(plate, success)
    if not plate or not plate.cast then return end
    local cast = plate.cast
    cast.spellName = nil
    cast.startTime = nil
    cast.endTime = nil
    cast.interrupted = false
    cast.failed = false
    cast:Hide()
end

function Cast:InterruptCast(plate, isFailed)
    if not plate or not plate.cast or not plate.cast:IsShown() then return end
    local db = DB()
    local cast = plate.cast

    if isFailed then
        cast.failed = true
        if plate.castText then plate.castText:SetText(FAILED) end
    else
        cast.interrupted = true
        if plate.castText then plate.castText:SetText(INTERRUPTED) end
    end

    if db.interruptedFlashEnabled ~= false then
        local fc = db.interruptedFlashColor or ns.defaults.interruptedFlashColor
        cast:SetStatusBarColor(fc.r, fc.g, fc.b)
    end

    cast.flashTimer = GetTime() + 0.6
end

function Cast:UpdateCastColor(plate)
    local cast = plate.cast
    if not cast then return end
    local db = DB()

    if cast.interrupted or cast.failed then
        local fc = db.interruptedFlashColor or ns.defaults.interruptedFlashColor
        cast:SetStatusBarColor(fc.r, fc.g, fc.b)
        return
    end

    if cast.notInterruptible then
        local uc = db.castBarUninterruptible or ns.defaults.castBarUninterruptible
        cast:SetStatusBarColor(uc.r, uc.g, uc.b)
        return
    end

    -- Mid-Cast Kick Ready Tint
    if db.interruptMidCastEnabled and IsPlayerInterruptReady() then
        local kc = db.interruptMidCastColor or ns.defaults.interruptMidCastColor
        cast:SetStatusBarColor(kc.r, kc.g, kc.b)
        return
    end

    local c = db.castBar or ns.defaults.castBar
    cast:SetStatusBarColor(c.r, c.g, c.b)
end

function Cast:OnCastUpdate(plate, elapsed)
    local cast = plate.cast
    if not cast or not cast:IsShown() then return end

    local now = GetTime()

    -- Post-interrupt fade out
    if cast.flashTimer then
        if now >= cast.flashTimer then
            cast.flashTimer = nil
            self:StopCast(plate)
        end
        return
    end

    if not cast.startTime or not cast.endTime then
        if cast.isNativeNameplateCast then
            local minimum, maximum = cast:GetMinMaxValues()
            local value = cast:GetValue() or minimum or 0
            local total = max(0.001, (maximum or 1) - (minimum or 0))
            local progress = max(0, value - (minimum or 0))
            if cast.lastNativeValue ~= nil and value ~= cast.lastNativeValue then
                cast.nativeIsChannel = value < cast.lastNativeValue
            end
            cast.lastNativeValue = value
            if plate.castText and plate.nativeCastTextSource then
                plate.castText:SetText(plate.nativeCastTextSource:GetText() or "")
            end
            if plate.castShield and plate.nativeCastShieldSource then
                local shieldShown = plate.nativeCastShieldSource:IsShown()
                if cast.notInterruptible ~= shieldShown then
                    cast.notInterruptible = shieldShown
                    self:UpdateCastColor(plate)
                end
                if DB().castBarShieldEnabled ~= false and shieldShown then
                    plate.castShield:Show()
                else
                    plate.castShield:Hide()
                end
            end
            if plate.castSpark and plate.castSpark:IsShown() and cast:GetWidth() > 0 then
                plate.castSpark:ClearAllPoints()
                plate.castSpark:SetPoint("CENTER", cast, "LEFT", min(1, progress / total) * cast:GetWidth(), 0)
            end
            if plate.castTimer and plate.castTimer:IsShown() then
                local remaining = cast.nativeIsChannel and progress or max(0, (maximum or 0) - value)
                plate.castTimer:SetFormattedText("%.1f", remaining)
            end
            return
        end
        cast:Hide()
        return
    end

    local total = max(0.001, cast.endTime - cast.startTime)
    local val

    if cast.isChannel then
        val = max(0, cast.endTime - now)
        if val <= 0 then
            self:StopCast(plate, true)
            return
        end
    else
        val = max(0, now - cast.startTime)
        if val >= total then
            self:StopCast(plate, true)
            return
        end
    end

    cast.value = val
    cast:SetValue(val)

    -- Spark placement
    if plate.castSpark and plate.castSpark:IsShown() then
        local width = cast:GetWidth()
        if width > 0 and total > 0 then
            local pct = val / total
            local sparkPos = (pct * width)
            plate.castSpark:ClearAllPoints()
            plate.castSpark:SetPoint("CENTER", cast, "LEFT", sparkPos, 0)
        end
    end

    -- Timer text
    if plate.castTimer and plate.castTimer:IsShown() then
        local rem = max(0, cast.endTime - now)
        plate.castTimer:SetFormattedText("%.1f", rem)
    end

    -- Update dynamic colors (e.g. kick becoming ready mid-cast)
    self:UpdateCastColor(plate)
end

--------------------------------------------------------------------------------
-- Unit & Event Polling
--------------------------------------------------------------------------------
function Cast:UpdateUnitCast(plate, unit)
    if not plate or not unit or not UnitExists(unit) then return end

    if plate.castTarget then
        local targetUnit = unit .. "target"
        local targetName = UnitExists(targetUnit) and UnitName(targetUnit) or ""
        plate.castTarget:SetText(targetName or "")
        local db = DB()
        if targetName and targetName ~= "" and db.castTargetClassColor ~= false then
            local _, class = UnitClass(targetUnit)
            local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if color then plate.castTarget:SetTextColor(color.r, color.g, color.b, 1) end
        else
            local color = db.castTargetColor or ns.defaults.castTargetColor
            plate.castTarget:SetTextColor(color.r, color.g, color.b, 1)
        end
    end

    local name, _, _, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(unit)
    if name and startTime and endTime then
        self:StartCast(plate, name, texture, startTime / 1000, endTime / 1000, notInterruptible, false)
        return
    end

    local cName, _, _, cTexture, cStart, cEnd, _, notInterruptibleCh = UnitChannelInfo(unit)
    if cName and cStart and cEnd then
        self:StartCast(plate, cName, cTexture, cStart / 1000, cEnd / 1000, notInterruptibleCh, true)
        return
    end

    -- No active cast reported by unit API
    if plate.cast and plate.cast:IsShown() and not plate.cast.interrupted and not plate.cast.failed then
        self:StopCast(plate)
    end
end

function Cast:OnPlateBound(plate, guid, unit)
    if unit then
        self:UpdateUnitCast(plate, unit)
    end
end

--------------------------------------------------------------------------------
-- Event Frame for UNIT_SPELLCAST & CLEU (Direct 3.3.5 Argument Unpacking)
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
eventFrame:RegisterEvent("UNIT_TARGET")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- WoW 3.3.5a has no hideCaster/sourceRaidFlags/destRaidFlags fields.
        local timestamp, subEvent,
              sourceGUID, sourceName, sourceFlags,
              destGUID, destName, destFlags,
              spellId, spellName, spellSchool = ...

        if not ns.MatchTracker then return end

        -- Cast events belong to the source. SPELL_INTERRUPT belongs to the
        -- interrupted destination, and UNIT_DIED has no source GUID at all.
        local plateGUID = (subEvent == "SPELL_INTERRUPT" or subEvent == "UNIT_DIED")
            and destGUID or sourceGUID
        local plate = ns.MatchTracker:GetPlateByGUID(plateGUID)
        if not plate or ns.MatchTracker:IsAmbiguous(plate) then
            -- FAIL-CLOSED: never clone CLEU casts onto ambiguous plates
            return
        end

        if subEvent == "SPELL_CAST_START" then
            -- Fallback cast estimate if unit API is unavailable
            if not (plate.cast and plate.cast:IsShown()) then
                local _, _, icon, castTime = GetSpellInfo(spellId)
                if castTime and castTime > 0 then
                    local now = GetTime()
                    Cast:StartCast(plate, spellName, icon, now, now + (castTime / 1000), false, false)
                end
            end
        elseif subEvent == "SPELL_CAST_SUCCESS" then
            if plate.cast and plate.cast.spellName == spellName and not plate.cast.isChannel then
                Cast:StopCast(plate, true)
            end
        elseif subEvent == "SPELL_INTERRUPT" then
            Cast:InterruptCast(plate, false)
        elseif subEvent == "SPELL_CAST_FAILED" then
            if plate.cast and plate.cast.spellName == spellName then
                Cast:InterruptCast(plate, true)
            end
        elseif subEvent == "UNIT_DIED" then
            Cast:StopCast(plate)
        end
        return
    end

    -- Unit-based cast events
    local unit = ...
    if not unit or not ns.MatchTracker then return end
    local castUnit = unit
    local plate = ns.MatchTracker.unitToPlate[castUnit]
    if event == "UNIT_TARGET" and not plate then
        castUnit = unit .. "target"
        plate = ns.MatchTracker.unitToPlate[castUnit]
    end
    if not plate then return end

    if event == "UNIT_TARGET" then
        Cast:UpdateUnitCast(plate, castUnit)
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
       or event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        Cast:UpdateUnitCast(plate, unit)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if not (plate.cast and plate.cast.flashTimer) then
            Cast:StopCast(plate, true)
        end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        Cast:InterruptCast(plate, true)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        Cast:InterruptCast(plate, false)
    end
end)
