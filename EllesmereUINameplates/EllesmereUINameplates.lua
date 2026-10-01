local addon, ns = ...

local ENP = EllesmereUI.Lite.NewAddon("EllesmereUINameplates")

-- Export globals and suite contracts
ns.isLegacyNameplates = true
_G.EllesmereNameplates_NS = ns

local pairs, ipairs, type, select = pairs, ipairs, type, select
local max, min, abs, floor, ceil = math.max, math.min, math.abs, math.floor, math.ceil
local lower, find = string.lower, string.find
local UnitClass, UnitExists, UnitIsUnit = UnitClass, UnitExists, UnitIsUnit
local UnitName, UnitGUID, UnitLevel = UnitName, UnitGUID, UnitLevel
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitCanAttack, UnitIsDeadOrGhost = UnitCanAttack, UnitIsDeadOrGhost
local UnitThreatSituation, UnitDetailedThreatSituation = UnitThreatSituation, UnitDetailedThreatSituation
local CreateFrame, WorldFrame = CreateFrame, WorldFrame
local GetTime = GetTime

local _, PLAYER_CLASS = UnitClass("player")
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Profile reference (set on Init/Enable)
local p
local function DB()
    return p or (ns.db and ns.db.profile) or ns.defaults or {}
end

ns.plates = {}
ns.legacyPlates = ns.plates
local plates = ns.plates

--------------------------------------------------------------------------------
-- Font & Outline Helpers
--------------------------------------------------------------------------------
local function GetFont()
    local f = DB().font
    return (f and f ~= "") and f or (ns.defaults and ns.defaults.font) or "Fonts\\FRIZQT__.TTF"
end
ns.GetFont = GetFont

local function GetNPOutline()
    local flag = (EllesmereUI and EllesmereUI.GetFontOutlineFlag and EllesmereUI.GetFontOutlineFlag("nameplates")) or "OUTLINE"
    if EllesmereUI and EllesmereUI.StripSlugFlag then
        flag = EllesmereUI.StripSlugFlag(flag)
    end
    return flag
end
ns.GetNPOutline = GetNPOutline

local function GetNPUseShadow()
    return not EllesmereUI or not EllesmereUI.GetFontUseShadow or EllesmereUI.GetFontUseShadow("nameplates")
end
ns.GetNPUseShadow = GetNPUseShadow

local function SetFSFont(fs, size, flags)
    if not (fs and fs.SetFont) then return end
    local f = flags or GetNPOutline()
    if EllesmereUI and EllesmereUI.SlugFlag then f = EllesmereUI.SlugFlag(f) end
    if EllesmereUI and EllesmereUI.StripSlugFlag then f = EllesmereUI.StripSlugFlag(f) end
    if not fs:SetFont(GetFont(), size or 11, f) then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size or 11, f)
    end
end
ns.SetFSFont = SetFSFont

--------------------------------------------------------------------------------
-- Metric & Slot Getters (Contract for EUI_Nameplates_Options.lua)
--------------------------------------------------------------------------------
ns._slotKeyMemo = ns._slotKeyMemo or {}
local function GetSlotKeys(posKey)
    local m = ns._slotKeyMemo[posKey]
    if not m then
        m = {
            size = posKey .. "SlotSize",
            x    = posKey .. "SlotXOffset",
            y    = posKey .. "SlotYOffset",
        }
        ns._slotKeyMemo[posKey] = m
    end
    return m
end

local function GetSlotSize(posKey)
    local m = GetSlotKeys(posKey)
    return DB()[m.size] or (ns.defaults and ns.defaults[m.size]) or 24
end
ns.GetSlotSize = GetSlotSize

local function GetSlotOffsets(posKey)
    local m = GetSlotKeys(posKey)
    local xOff = DB()[m.x] or (ns.defaults and ns.defaults[m.x]) or 0
    local yOff = DB()[m.y] or (ns.defaults and ns.defaults[m.y]) or 0
    return xOff, yOff
end
ns.GetSlotOffsets = GetSlotOffsets

local function GetHealthBarWidth()
    local extra = DB().healthBarWidth or (ns.defaults and ns.defaults.healthBarWidth) or 6
    return ns.BAR_W + extra
end
ns.GetHealthBarWidth = GetHealthBarWidth

local function GetHealthBarHeight()
    return DB().healthBarHeight or (ns.defaults and ns.defaults.healthBarHeight) or 17
end
ns.GetHealthBarHeight = GetHealthBarHeight

local function GetCastBarHeight()
    return DB().castBarHeight or (ns.defaults and ns.defaults.castBarHeight) or 17
end
ns.GetCastBarHeight = GetCastBarHeight

local function GetCastIconScale()
    return DB().castIconScale or (ns.defaults and ns.defaults.castIconScale) or 1
end
ns.GetCastIconScale = GetCastIconScale

local function GetShowCastIcon()
    local v = DB().showCastIcon
    if v == nil then return ns.defaults and ns.defaults.showCastIcon end
    return v
end
ns.GetShowCastIcon = GetShowCastIcon

local function GetCastIconInWidth()
    local v = DB().castbarIconInWidth
    if v == nil then return ns.defaults and ns.defaults.castbarIconInWidth end
    return v
end
ns.GetCastIconInWidth = GetCastIconInWidth

local function GetCastIconOnRight()
    local v = DB().castIconOnRight
    if v == nil then return ns.defaults and ns.defaults.castIconOnRight end
    return v
end
ns.GetCastIconOnRight = GetCastIconOnRight

local function GetCastIconFullSize()
    local v = DB().castIconFullSize
    if v == nil then return ns.defaults and ns.defaults.castIconFullSize end
    return v
end
ns.GetCastIconFullSize = GetCastIconFullSize

function ns.GetCastIconReserve(plate)
    if not GetShowCastIcon() then return 0, nil end
    local onRight = GetCastIconOnRight()
    local side = onRight and "right" or "left"
    if GetCastIconFullSize() then
        if plate and plate.cast and not plate.cast:IsShown() then return 0, side end
        return GetHealthBarHeight() + GetCastBarHeight(), side
    end
    if GetCastIconInWidth() then return 0, side end
    return GetCastBarHeight() * (GetCastIconScale() or 1), side
end

function ns.LayoutCastBar(plate, footprintW, castH)
    if not plate or not plate.cast then return end
    local iconW = 0
    local shiftX = 0
    if GetShowCastIcon() and GetCastIconInWidth() and not GetCastIconFullSize() then
        iconW = castH * (GetCastIconScale() or 1)
        if not GetCastIconOnRight() then shiftX = iconW end
    end
    plate.cast:ClearAllPoints()
    plate.cast:SetSize(max(1, footprintW - iconW), castH)
    local offsetY = DB().castBarOffsetY or (ns.defaults and ns.defaults.castBarOffsetY) or 0
    plate.cast:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", shiftX, offsetY)
end

function ns.LayoutCastIcon(plate, castH)
    if not plate or not plate.castIconFrame then return end
    local icon = plate.castIconFrame
    local onRight = GetCastIconOnRight()
    local xOff = DB().castIconOffsetX or 0
    local yOff = DB().castIconOffsetY or 0
    icon:ClearAllPoints()
    if GetCastIconFullSize() then
        local side = GetHealthBarHeight() + castH
        icon:SetScale(1)
        icon:SetSize(side, side)
        if onRight then
            icon:SetPoint("TOPLEFT", plate.health, "TOPRIGHT", xOff, yOff)
        else
            icon:SetPoint("TOPRIGHT", plate.health, "TOPLEFT", xOff, yOff)
        end
    else
        icon:SetScale(GetCastIconScale() or 1)
        icon:SetSize(castH, castH)
        if onRight then
            icon:SetPoint("TOPLEFT", plate.cast, "TOPRIGHT", xOff, yOff)
        else
            icon:SetPoint("TOPRIGHT", plate.cast, "TOPLEFT", xOff, yOff)
        end
    end
end

local function GetAuraSlots()
    local db = DB()
    local ds = db.debuffSlot or (ns.defaults and ns.defaults.debuffSlot) or "top"
    local bs = db.buffSlot or (ns.defaults and ns.defaults.buffSlot) or "left"
    local cs = db.ccSlot or (ns.defaults and ns.defaults.ccSlot) or "right"
    return ds, bs, cs
end
ns.GetAuraSlots = GetAuraSlots

local auraSlotToDBKey = {
    debuffSlot     = "debuffSlot",
    buffSlot       = "buffSlot",
    ccSlot         = "ccSlot",
    classification = "classificationSlot",
    raidMarker     = "raidMarkerPos",
}
local function GetAuraSlotOffsets(slotKey)
    local dbKey = auraSlotToDBKey[slotKey]
    if not dbKey then return 0, 0 end
    local pos = DB()[dbKey] or (ns.defaults and ns.defaults[dbKey])
    if not pos or pos == "none" then return 0, 0 end
    return GetSlotOffsets(pos)
end
ns.GetAuraSlotOffsets = GetAuraSlotOffsets

local function GetAuraSpacing(element)
    local db = DB()
    if element == "debuffs" then return db.debuffSpacing or (ns.defaults and ns.defaults.debuffSpacing) or 2 end
    if element == "buffs" then return db.buffSpacing or (ns.defaults and ns.defaults.buffSpacing) or 2 end
    if element == "ccs" then return db.ccSpacing or (ns.defaults and ns.defaults.ccSpacing) or 2 end
    return db.auraSpacing or (ns.defaults and ns.defaults.auraSpacing) or 2
end
ns.GetAuraSpacing = GetAuraSpacing

local function GetDebuffIconSize()
    local slot = DB().debuffSlot or (ns.defaults and ns.defaults.debuffSlot) or "top"
    if slot == "none" then return (ns.defaults and ns.defaults.debuffIconSize) or 26 end
    return GetSlotSize(slot)
end
ns.GetDebuffIconSize = GetDebuffIconSize

local function GetBuffIconSize()
    local slot = DB().buffSlot or (ns.defaults and ns.defaults.buffSlot) or "left"
    if slot == "none" then return (ns.defaults and ns.defaults.buffIconSize) or 24 end
    return GetSlotSize(slot)
end
ns.GetBuffIconSize = GetBuffIconSize

local function GetCCIconSize()
    local slot = DB().ccSlot or (ns.defaults and ns.defaults.ccSlot) or "right"
    if slot == "none" then return (ns.defaults and ns.defaults.ccIconSize) or 24 end
    return GetSlotSize(slot)
end
ns.GetCCIconSize = GetCCIconSize

local function GetDebuffYOffset()
    return DB().debuffYOffset or (ns.defaults and ns.defaults.debuffYOffset) or 2
end
ns.GetDebuffYOffset = GetDebuffYOffset

local function GetSideAuraXOffset()
    return DB().sideAuraXOffset or (ns.defaults and ns.defaults.sideAuraXOffset) or 2
end
ns.GetSideAuraXOffset = GetSideAuraXOffset

local function GetRaidMarkerPos()
    return DB().raidMarkerPos or (ns.defaults and ns.defaults.raidMarkerPos) or "topright"
end
ns.GetRaidMarkerPos = GetRaidMarkerPos

local function GetRaidMarkerSize()
    local pos = GetRaidMarkerPos()
    if pos == "none" then return (ns.defaults and ns.defaults.raidMarkerSize) or 24 end
    return GetSlotSize(pos)
end
ns.GetRaidMarkerSize = GetRaidMarkerSize

local function GetClassificationSlot()
    return DB().classificationSlot or (ns.defaults and ns.defaults.classificationSlot) or "topleft"
end
ns.GetClassificationSlot = GetClassificationSlot

local function GetRareEliteIconSize()
    local pos = GetClassificationSlot()
    if pos == "none" then return (ns.defaults and ns.defaults.rareEliteIconSize) or 20 end
    return GetSlotSize(pos)
end
ns.GetRareEliteIconSize = GetRareEliteIconSize

local function GetNameYOffset()
    return DB().nameYOffset or (ns.defaults and ns.defaults.nameYOffset) or 0
end
ns.GetNameYOffset = GetNameYOffset

ns.textSlotKeys = { "textSlotTop", "textSlotRight", "textSlotLeft", "textSlotCenter" }
local function GetTextSlot(slotKey)
    return DB()[slotKey] or (ns.defaults and ns.defaults[slotKey])
end
ns.GetTextSlot = GetTextSlot

local function FindSlotForElement(element)
    for _, key in ipairs(ns.textSlotKeys) do
        if GetTextSlot(key) == element then return key end
    end
    return nil
end
ns.FindSlotForElement = FindSlotForElement

local function GetTextSlotOffsets(slotKey)
    local xOff = DB()[slotKey .. "XOffset"] or 0
    local yOff = DB()[slotKey .. "YOffset"] or 0
    return xOff, yOff
end
ns.GetTextSlotOffsets = GetTextSlotOffsets

local function GetTextSlotSize(slotKey)
    return DB()[slotKey .. "Size"] or (ns.defaults and ns.defaults[slotKey .. "Size"]) or 10
end
ns.GetTextSlotSize = GetTextSlotSize

local function GetTextSlotColor(slotKey)
    local c = DB()[slotKey .. "Color"] or (ns.defaults and ns.defaults[slotKey .. "Color"])
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end
ns.GetTextSlotColor = GetTextSlotColor

local function GetSlotRaiseStrata(posKey)
    if not posKey or posKey == "none" then return false end
    local key = posKey .. "SlotRaiseStrata"
    return DB()[key] or false
end
ns.GetSlotRaiseStrata = GetSlotRaiseStrata

--------------------------------------------------------------------------------
-- Aura Cropping
--------------------------------------------------------------------------------
do
    local AURA_CROP_HEIGHT = 0.80
    local AURA_ZOOM = 0.08
    function ns.GetAuraCrop(element)
        local db = DB()
        if element == "debuffs" then return db.debuffCropIcons or false end
        if element == "buffs" then return db.buffCropIcons or false end
        if element == "ccs" then return db.ccCropIcons or false end
        return false
    end

    function ns.GetAuraCropHeight(cropped, w)
        if cropped then return floor(w * AURA_CROP_HEIGHT + 0.5) end
        return w
    end

    function ns.SetAuraIconCrop(icon, cropped, w, h)
        if not icon then return end
        if cropped and w and h and w > 0 then
            local uSpan = 1 - 2 * AURA_ZOOM
            local vSpan = uSpan * (h / w)
            local v0 = 0.5 - vSpan / 2
            icon:SetTexCoord(AURA_ZOOM, 1 - AURA_ZOOM, v0, 1 - v0)
        else
            icon:SetTexCoord(AURA_ZOOM, 1 - AURA_ZOOM, AURA_ZOOM, 1 - AURA_ZOOM)
        end
    end

    function ns.ApplyAuraSlotCrop(slot, cropped, sizeW)
        local h = ns.GetAuraCropHeight(cropped, sizeW)
        slot:SetSize(sizeW, h)
        ns.SetAuraIconCrop(slot.icon, cropped, sizeW, h)
        return sizeW, h
    end
end

--------------------------------------------------------------------------------
-- Target Effect & Glow Getters
--------------------------------------------------------------------------------
function ns.GetTargetGlowStyle()
    return DB().targetGlowStyle or (ns.defaults and ns.defaults.targetGlowStyle) or "ellesmereui"
end

function ns.GetTargetGlowEllesmereUI()
    local db = DB()
    if db.targetGlowEllesmereUI ~= nil then return db.targetGlowEllesmereUI end
    local style = ns.GetTargetGlowStyle()
    return style == "ellesmereui" or style == "vibrant"
end

function ns.GetTargetGlowBorderColor()
    local db = DB()
    if db.targetGlowBorderColor ~= nil then return db.targetGlowBorderColor end
    local style = ns.GetTargetGlowStyle()
    return style == "vibrant"
end

function ns.GetTargetGlowHighlight()
    local db = DB()
    if db.targetGlowHighlight ~= nil then return db.targetGlowHighlight end
    return false
end

function ns.GetTargetGlowBorderSize()
    local db = DB()
    if db.targetGlowBorderSize ~= nil then return db.targetGlowBorderSize end
    return false
end

function ns.GetTargetBorderSizeValue()
    return DB().targetBorderSizeValue
end

function ns.GetTargetBorderColor()
    return DB().targetBorderColor or (ns.defaults and ns.defaults.targetBorderColor) or { r = 1, g = 1, b = 1 }
end

function ns.GetTargetGlowColor()
    return DB().targetGlowColor or (ns.defaults and ns.defaults.targetGlowColor) or { r = 0.41, g = 0.67, b = 1.0 }
end

function ns.GetTargetGlowAlpha()
    local a = DB().targetGlowAlpha
    if a == nil then return (ns.defaults and ns.defaults.targetGlowAlpha) or 1.0 end
    return a
end

function ns.GetTargetHighlightColor()
    return DB().targetHighlightColor or (ns.defaults and ns.defaults.targetHighlightColor) or { r = 1, g = 1, b = 1 }
end

function ns.GetTargetHighlightAlpha()
    local a = DB().targetHighlightAlpha
    if a == nil then return (ns.defaults and ns.defaults.targetHighlightAlpha) or 0.20 end
    return a
end

function ns.GetTargetScale()
    return (DB().targetScale or 100) / 100
end

--------------------------------------------------------------------------------
-- Text Formatting & Truncation Helpers
--------------------------------------------------------------------------------
local COMBO_HEALTH_ELEMENTS = {
    healthPctNum     = true, healthNumPct     = true,
    healthPctNumDash = true, healthNumPctDash = true,
}
function ns.IsComboHealthText(element)
    return COMBO_HEALTH_ELEMENTS[element] == true
end

function ns.SetCombinedHealthText(fs, element, pctText, numText)
    if not fs then return end
    if element == "healthPctNum" then
        fs:SetFormattedText("%s | %s", pctText, numText)
    elseif element == "healthNumPct" then
        fs:SetFormattedText("%s | %s", numText, pctText)
    elseif element == "healthPctNumDash" then
        fs:SetFormattedText("%s - %s", pctText, numText)
    elseif element == "healthNumPctDash" then
        fs:SetFormattedText("%s - %s", numText, pctText)
    else
        fs:SetText("")
    end
end

local healthTextWidths = {
    healthPercent       = 38,
    healthPercentNoSign = 38,
    healthNumber        = 38,
    healthPctNum        = 75,
    healthNumPct        = 75,
    healthPctNumDash    = 75,
    healthNumPctDash    = 75,
}
function ns.EstimateHealthTextWidth(element)
    return (healthTextWidths[element] or 0) + 10
end

function ns.ReflowFontString(fs)
    if not fs then return end
    local t = fs:GetText()
    fs:SetText("")
    if t then fs:SetText(t) end
end

--------------------------------------------------------------------------------
-- Border Construction
--------------------------------------------------------------------------------
local function AddEdge(parent, first, second, vertical)
    local edge = parent:CreateTexture(nil, "OVERLAY")
    edge:SetTexture(WHITE)
    edge:SetVertexColor(0, 0, 0, 1)
    edge:SetPoint(unpack(first))
    edge:SetPoint(unpack(second))
    if vertical then edge:SetWidth(1) else edge:SetHeight(1) end
    return edge
end

local function CreateBorder(bar)
    return {
        AddEdge(bar, { "TOPLEFT", bar, "TOPLEFT", -1, 1 }, { "TOPRIGHT", bar, "TOPRIGHT", 1, 1 }),
        AddEdge(bar, { "BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1 }, { "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1 }),
        AddEdge(bar, { "TOPLEFT", bar, "TOPLEFT", -1, 1 }, { "BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1 }, true),
        AddEdge(bar, { "TOPRIGHT", bar, "TOPRIGHT", 1, 1 }, { "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1 }, true),
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
-- Target Glow Frame (EUI Signature Backing Glow)
--------------------------------------------------------------------------------
local TARGET_GLOW_TEX = "Interface\\AddOns\\EllesmereUINameplates\\Media\\background.tga"
local TARGET_GLOW_MARGIN, TARGET_GLOW_CORNER, TARGET_GLOW_EXTEND = 0.48, 12, 6

local function CreateTargetGlowFrame(parent, anchor)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", -TARGET_GLOW_EXTEND, TARGET_GLOW_EXTEND)
    frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", TARGET_GLOW_EXTEND, -TARGET_GLOW_EXTEND)
    frame.textures = {}

    local function MakeTex()
        local t = frame:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(TARGET_GLOW_TEX)
        t:SetBlendMode("ADD")
        frame.textures[#frame.textures + 1] = t
        return t
    end

    local tl = MakeTex(); tl:SetSize(TARGET_GLOW_CORNER, TARGET_GLOW_CORNER); tl:SetPoint("TOPLEFT"); tl:SetTexCoord(0, TARGET_GLOW_MARGIN, 0, TARGET_GLOW_MARGIN)
    local tr = MakeTex(); tr:SetSize(TARGET_GLOW_CORNER, TARGET_GLOW_CORNER); tr:SetPoint("TOPRIGHT"); tr:SetTexCoord(1 - TARGET_GLOW_MARGIN, 1, 0, TARGET_GLOW_MARGIN)
    local bl = MakeTex(); bl:SetSize(TARGET_GLOW_CORNER, TARGET_GLOW_CORNER); bl:SetPoint("BOTTOMLEFT"); bl:SetTexCoord(0, TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, 1)
    local br = MakeTex(); br:SetSize(TARGET_GLOW_CORNER, TARGET_GLOW_CORNER); br:SetPoint("BOTTOMRIGHT"); br:SetTexCoord(1 - TARGET_GLOW_MARGIN, 1, 1 - TARGET_GLOW_MARGIN, 1)
    local top = MakeTex(); top:SetHeight(TARGET_GLOW_CORNER); top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("TOPRIGHT", tr, "TOPLEFT"); top:SetTexCoord(TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, 0, TARGET_GLOW_MARGIN)
    local bot = MakeTex(); bot:SetHeight(TARGET_GLOW_CORNER); bot:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT"); bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT"); bot:SetTexCoord(TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, 1)
    local left = MakeTex(); left:SetWidth(TARGET_GLOW_CORNER); left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT"); left:SetTexCoord(0, TARGET_GLOW_MARGIN, TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN)
    local right = MakeTex(); right:SetWidth(TARGET_GLOW_CORNER); right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT"); right:SetTexCoord(1 - TARGET_GLOW_MARGIN, 1, TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN)
    local center = MakeTex(); center:SetPoint("TOPLEFT", left, "TOPRIGHT"); center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT"); center:SetTexCoord(TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN)

    frame:Hide()
    return frame
end

--------------------------------------------------------------------------------
-- Native Region Suppression
--------------------------------------------------------------------------------
local function SuppressSourceFont(fs)
    if not fs then return end
    fs:Hide()
    fs:SetAlpha(0)
    if fs._euiSuppressed or not hooksecurefunc then return end
    fs._euiSuppressed = true
    hooksecurefunc(fs, "Show", function(self)
        if not self._euiForcing then
            self._euiForcing = true
            self:Hide()
            self._euiForcing = nil
        end
    end)
    hooksecurefunc(fs, "SetAlpha", function(self, alpha)
        if alpha ~= 0 and not self._euiForcingAlpha then
            self._euiForcingAlpha = true
            self:SetAlpha(0)
            self._euiForcingAlpha = nil
        end
    end)
end

local function SuppressTexture(region)
    if not region then return end
    region:SetAlpha(0)
    if region._euiSuppressed or not hooksecurefunc then return end
    region._euiSuppressed = true
    hooksecurefunc(region, "SetAlpha", function(self, alpha)
        if alpha ~= 0 and not self._euiForcingAlpha then
            self._euiForcingAlpha = true
            self:SetAlpha(0)
            self._euiForcingAlpha = nil
        end
    end)
end

--------------------------------------------------------------------------------
-- Nameplate Frame Construction & Methods
--------------------------------------------------------------------------------
local PlateMethods = {}

function PlateMethods:IsShown()
    return self.frame and self.frame:IsShown() and true or false
end

function PlateMethods:GetAlpha()
    return self.frame and self.frame:GetAlpha() or 1
end

function PlateMethods:SetAlpha(a)
    if self.frame then self.frame:SetAlpha(a) end
end

function PlateMethods:GetWidth()
    return self.frame and self.frame:GetWidth() or 0
end

function PlateMethods:GetHeight()
    return self.frame and self.frame:GetHeight() or 0
end

function PlateMethods:GetPoint(...)
    if self.frame then return self.frame:GetPoint(...) end
end

function PlateMethods:Show()
    if self.frame then self.frame:Show() end
end

function PlateMethods:Hide()
    if self.frame then self.frame:Hide() end
end

function PlateMethods:UpdateNameWidth()
    if not self.nameText then return end
    local barW = ns.GetHealthBarWidth()
    local pct = DB().enemyNameWidthPct or 100
    local maxW = barW * (pct / 100)
    self.nameText:SetWidth(maxW > 0 and maxW or barW)
end

function PlateMethods:RefreshNamePosition(localOnly)
    self:UpdateNameWidth()
    if self.nameText then
        self.nameText:ClearAllPoints()
        local yOff = DB().nameYOffset or (ns.defaults and ns.defaults.nameYOffset) or 3
        self.nameText:SetPoint("BOTTOMLEFT", self.health, "TOPLEFT", 0, yOff)
    end
end

function PlateMethods:UpdateRaidIcon()
    local icon = self.raidIcon
    if not icon then return end
    local pos = ns.GetRaidMarkerPos and ns.GetRaidMarkerPos() or "topright"
    if pos == "none" then
        icon:Hide()
        return
    end
    local sz = ns.GetRaidMarkerSize and ns.GetRaidMarkerSize() or 24
    icon:SetSize(sz, sz)
    icon:ClearAllPoints()
    icon:SetPoint("BOTTOM", self.health, "TOP", 0, 16)
end

function PlateMethods:UpdateClassification()
    -- Native classification updates
end

function PlateMethods:GetNameText()
    local src = self.nameSource
    return src and src:GetText() or ""
end

function PlateMethods:GetLevelText()
    local src = self.levelSource
    return src and src:GetText() or ""
end

function PlateMethods:GetHealthValues()
    local health = self.health
    if not health then return 0, 0 end
    local val = health:GetValue() or 0
    local _, maxVal = health:GetMinMaxValues()
    return val, maxVal or 0
end

function PlateMethods:ApplyAppearance()
    local db = DB()
    local barW = ns.GetHealthBarWidth()
    local barH = ns.GetHealthBarHeight()

    self.health:SetSize(barW, barH)

    -- Status Bar Texture
    local texKey = db.healthBarTexture or "none"
    local texPath = EllesmereUI and EllesmereUI.ResolveTexturePath
        and EllesmereUI.ResolveTexturePath(ns.healthBarTextures, texKey, "Interface\\Buttons\\WHITE8x8")
        or "Interface\\Buttons\\WHITE8x8"
    self.health:SetStatusBarTexture(texPath)

    -- Health Background
    if self.healthBg then
        local bgC = db.bgColor or ns.defaults.bgColor
        local bgA = db.bgAlpha or ns.defaults.bgAlpha or 1.0
        self.healthBg:SetVertexColor(bgC.r, bgC.g, bgC.b, bgA)
    end

    -- Border
    local bSize = db.borderSize or 1
    local bColor = db.borderColor or ns.defaults.borderColor
    SetBorder(self.border, db.showBorder ~= false, bColor, bSize)

    -- Fonts
    local outline = GetNPOutline()
    local fontPath = GetFont()
    local nameSize = db.enemyNameTextSize or 11
    SetFSFont(self.nameText, nameSize, outline)

    for _, slotKey in ipairs(ns.textSlotKeys) do
        local fs = self[slotKey]
        if fs then
            local sz = GetTextSlotSize(slotKey)
            local r, g, b = GetTextSlotColor(slotKey)
            SetFSFont(fs, sz, outline)
            fs:SetTextColor(r, g, b, 1)
        end
    end

    -- Target arrows
    local st = ns.ResolveTargetArrowStyle(db)
    local sc = db.targetArrowScale or 1.0
    local aw = floor(st.w * sc + 0.5)
    local ah = floor(16 * sc + 0.5)
    self.leftArrow:SetSize(aw, ah)
    self.rightArrow:SetSize(aw, ah)
    self.leftArrow:SetTexture(ns.TARGET_ARROW_DIR .. st.l .. ".tga")
    self.rightArrow:SetTexture(ns.TARGET_ARROW_DIR .. st.r .. ".tga")

    local ar, ag, ab = ns.GetTargetArrowColor(db)
    self.leftArrow:SetVertexColor(ar, ag, ab, 1)
    self.rightArrow:SetVertexColor(ar, ag, ab, 1)

    -- Cast styling
    if ns.Cast and ns.Cast.ApplyStyle then
        ns.Cast:ApplyStyle(self)
    end

    self:UpdateHealth()
    self:ApplyScale()
    self:ApplyTarget()
end

function PlateMethods:UpdateHealthValues()
    local val, maxVal = self:GetHealthValues()
    local pct = maxVal > 0 and (val / maxVal * 100) or 0
    local pctText = floor(pct + 0.5) .. "%"
    local numText = floor(val + 0.5)

    for _, slotKey in ipairs(ns.textSlotKeys) do
        local fs = self[slotKey]
        if fs then
            local el = GetTextSlot(slotKey)
            if el == "enemyName" then
                fs:SetText(self:GetNameText())
            elseif el == "healthPercent" then
                fs:SetText(pctText)
            elseif el == "healthPercentNoSign" then
                fs:SetText(floor(pct + 0.5))
            elseif el == "healthNumber" then
                fs:SetText(numText)
            elseif ns.IsComboHealthText(el) then
                ns.SetCombinedHealthText(fs, el, pctText, numText)
            elseif el == "level" then
                fs:SetText(self:GetLevelText())
            else
                fs:SetText("")
            end
        end
    end
end

function PlateMethods:UpdateHealthColor()
    if self.applyingColor then return end
    self.applyingColor = true

    local db = DB()
    local r, g, b = self.health:GetStatusBarColor()
    local isTarget = ns.MatchTracker and ns.MatchTracker:IsTarget(self)
    local isFocus = ns.MatchTracker and ns.MatchTracker:IsFocus(self)

    -- Check reaction from Blizzard native color
    local isHostile = r > 0.85 and g < 0.25 and b < 0.25
    local isNeutral = r > 0.75 and g > 0.65 and b < 0.35
    local isTapped  = abs(r - g) < 0.08 and abs(g - b) < 0.08 and r < 0.7
    local isFriendly = not isHostile and not isNeutral and not isTapped

    local finalR, finalG, finalB = r, g, b

    if isTarget and db.targetColorEnabled then
        local c = db.target or ns.defaults.target
        finalR, finalG, finalB = c.r, c.g, c.b
    elseif isFocus and db.focusColorEnabled then
        local c = db.focus or ns.defaults.focus
        finalR, finalG, finalB = c.r, c.g, c.b
    elseif isFriendly then
        if db.classColorFriendly and self.isFriendlyPlayer then
            -- Keep native class color
            finalR, finalG, finalB = r, g, b
        else
            local c = db.friendlyBarColor or ns.defaults.friendlyBarColor
            finalR, finalG, finalB = c.r, c.g, c.b
        end
    else
        -- Threat Evaluation
        local threatStatus = nil
        if self.unit and UnitExists(self.unit) then
            threatStatus = UnitThreatSituation("player", self.unit)
        elseif self.nativeGlow and self.nativeGlow:IsShown() then
            local gr, gg, gb = self.nativeGlow:GetVertexColor()
            if gr > 0.8 and gg < 0.2 then
                threatStatus = 3 -- Tank has aggro / Player has aggro
            elseif gg > 0.5 then
                threatStatus = 1 -- Transition / losing aggro
            end
        end

        if threatStatus then
            if db.tankHasAggroEnabled and threatStatus >= 3 then
                local c = db.tankHasAggro or ns.defaults.tankHasAggro
                finalR, finalG, finalB = c.r, c.g, c.b
            elseif threatStatus == 1 or threatStatus == 2 then
                local c = db.tankLosingAggro or ns.defaults.tankLosingAggro
                finalR, finalG, finalB = c.r, c.g, c.b
            elseif isHostile then
                local c = db.hostile or ns.defaults.hostile
                finalR, finalG, finalB = c.r, c.g, c.b
            end
        elseif isHostile then
            local c = db.hostile or ns.defaults.hostile
            finalR, finalG, finalB = c.r, c.g, c.b
        elseif isNeutral then
            local c = db.neutral or ns.defaults.neutral
            finalR, finalG, finalB = c.r, c.g, c.b
        elseif isTapped then
            local c = db.tapped or ns.defaults.tapped
            finalR, finalG, finalB = c.r, c.g, c.b
        end
    end

    self.health:SetStatusBarColor(finalR, finalG, finalB)
    self.applyingColor = false
end

function PlateMethods:UpdateHealth()
    self:UpdateHealthValues()
    self:UpdateHealthColor()
end

function PlateMethods:ApplyScale()
    local isTarget = ns.MatchTracker and ns.MatchTracker:IsTarget(self)
    local targetScale = ns.GetTargetScale()
    local scale = isTarget and targetScale or 1.0

    if self.currentScale ~= scale then
        self.currentScale = scale
        self.health:SetScale(scale)
        if self.cast then self.cast:SetScale(scale) end
        if self.targetGlowFrame then self.targetGlowFrame:SetScale(scale) end
    end
end

function PlateMethods:ApplyTarget()
    local db = DB()
    local isTarget = ns.MatchTracker and ns.MatchTracker:IsTarget(self)

    -- Target Arrows
    if isTarget and db.showTargetArrows then
        self.leftArrow:Show()
        self.rightArrow:Show()
        self.leftArrow:SetPoint("RIGHT", self.health, "LEFT", -4, 0)
        self.rightArrow:SetPoint("LEFT", self.health, "RIGHT", 4, 0)
    else
        self.leftArrow:Hide()
        self.rightArrow:Hide()
    end

    -- Target Glow
    if isTarget and ns.GetTargetGlowEllesmereUI() then
        local gc = ns.GetTargetGlowColor()
        local ga = ns.GetTargetGlowAlpha()
        for _, tex in ipairs(self.targetGlowFrame.textures) do
            tex:SetVertexColor(gc.r, gc.g, gc.b, ga)
        end
        self.targetGlowFrame:Show()
    else
        self.targetGlowFrame:Hide()
    end

    -- Target Highlight Wash
    if isTarget and ns.GetTargetGlowHighlight() then
        local hc = ns.GetTargetHighlightColor()
        local ha = ns.GetTargetHighlightAlpha()
        self.targetHighlight:SetVertexColor(hc.r, hc.g, hc.b, ha)
        self.targetHighlight:Show()
    else
        self.targetHighlight:Hide()
    end

    -- Target Border Tint
    if isTarget and ns.GetTargetGlowBorderColor() then
        local tc = ns.GetTargetBorderColor()
        for _, edge in ipairs(self.border) do
            edge:SetVertexColor(tc.r, tc.g, tc.b, 1)
        end
    else
        local bc = db.borderColor or ns.defaults.borderColor
        for _, edge in ipairs(self.border) do
            edge:SetVertexColor(bc.r, bc.g, bc.b, 1)
        end
    end

    -- Non-target opacity
    ns.NT_Apply(self)
end

function PlateMethods:UpdateAuras()
    if not ns.AuraTracker then return end
    local auras, count = ns.AuraTracker:GetAurasForPlate(self, "HARMFUL")
    local db = DB()
    local maxD = min(db.maxDebuffs or 5, #self.debuffSlots)

    for i = 1, maxD do
        local slot = self.debuffSlots[i]
        local aura = auras and auras[i]
        if aura then
            slot.icon:SetTexture(aura.icon)
            if aura.count and aura.count > 1 then
                slot.countText:SetText(aura.count)
                slot.countText:Show()
            else
                slot.countText:Hide()
            end

            if aura.expirationTime and aura.expirationTime < math.huge then
                local rem = max(0, aura.expirationTime - GetTime())
                slot.durationText:SetFormattedText(rem < 10 and "%.1f" or "%.0f", rem)
                slot.durationText:Show()
            else
                slot.durationText:Hide()
            end
            slot:Show()
        else
            slot:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Plate Factory & Skinner
--------------------------------------------------------------------------------
local function CreateAuraSlots(parent, anchor, count)
    local slots = {}
    local sz = ns.GetDebuffIconSize()
    local crop = ns.GetAuraCrop("debuffs")
    local h = ns.GetAuraCropHeight(crop, sz)

    for i = 1, count do
        local slot = CreateFrame("Frame", nil, parent)
        slot:SetSize(sz, h)
        slot.border = CreateBorder(slot)

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
        slot.icon = icon
        ns.SetAuraIconCrop(icon, crop, sz, h)

        local countText = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countText:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 2, -2)
        slot.countText = countText

        local durText = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        durText:SetPoint("TOPLEFT", slot, "TOPLEFT", -2, 2)
        slot.durationText = durText

        if i == 1 then
            slot:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
        else
            slot:SetPoint("LEFT", slots[i - 1], "RIGHT", 2, 0)
        end

        slot:Hide()
        slots[i] = slot
    end
    return slots
end

local function SkinPlate(frame)
    if plates[frame] then return plates[frame] end

    -- Extract Blizzard parts
    local health, nativeGlow, highlight
    local fonts = {}

    for i = 1, select("#", frame:GetChildren()) do
        local child = select(i, frame:GetChildren())
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            if not health then health = child end
        end
    end

    if not health then return nil end

    local raidIcon, bossIcon, eliteIcon
    for i = 1, select("#", frame:GetRegions()) do
        local r = select(i, frame:GetRegions())
        if r and r.GetObjectType then
            local kind = r:GetObjectType()
            if kind == "FontString" then
                fonts[#fonts + 1] = r
                SuppressSourceFont(r)
            elseif kind == "Texture" then
                local path = r:GetTexture()
                local isRaid = false
                if path and type(path) == "string" then
                    path = lower(path)
                    if find(path, "nameplate-glow", 1, true) then
                        nativeGlow = r
                    elseif find(path, "nameplate-highlight", 1, true) or find(path, "ui-targetingframe-flash", 1, true) then
                        highlight = r
                    elseif find(path, "ui-raidtargetingicons", 1, true) then
                        raidIcon = r
                        isRaid = true
                    elseif find(path, "ui-targetingframe-skull", 1, true) then
                        bossIcon = r
                    elseif find(path, "elitedragon", 1, true) then
                        eliteIcon = r
                    end
                end
                if not isRaid then
                    SuppressTexture(r)
                end
            end
        end
    end

    -- Identify source texts
    local nameSource, levelSource
    for _, fs in ipairs(fonts) do
        local txt = fs:GetText()
        if txt and tostring(txt):match("^%??%d+[%+%-]?$") then
            levelSource = levelSource or fs
        elseif txt and txt ~= "" then
            nameSource = nameSource or fs
        end
    end
    nameSource = nameSource or fonts[1]

    -- Build plate object
    local plate = setmetatable({}, { __index = PlateMethods })
    plate.frame = frame
    plate.health = health
    plate.nameSource = nameSource
    plate.levelSource = levelSource
    plate.nativeGlow = nativeGlow
    plate.nativeHighlight = highlight
    plate.raidIcon = raidIcon
    plate.bossIcon = bossIcon
    plate.eliteIcon = eliteIcon

    -- Health Background
    local healthBg = health:CreateTexture(nil, "BACKGROUND")
    healthBg:SetTexture(WHITE)
    healthBg:SetAllPoints(health)
    plate.healthBg = healthBg

    -- Border
    plate.border = CreateBorder(health)

    -- EUI Target Glow & Highlight
    plate.targetGlowFrame = CreateTargetGlowFrame(frame, health)
    plate.targetHighlight = health:CreateTexture(nil, "OVERLAY")
    plate.targetHighlight:SetTexture(WHITE)
    plate.targetHighlight:SetAllPoints(health)
    plate.targetHighlight:Hide()

    -- Target Arrows
    plate.leftArrow = frame:CreateTexture(nil, "OVERLAY")
    plate.rightArrow = frame:CreateTexture(nil, "OVERLAY")
    plate.leftArrow:Hide()
    plate.rightArrow:Hide()

    -- Text Slots
    local nameText = health:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, 3)
    plate.nameText = nameText
    plate.textSlotTop = nameText

    local textSlotRight = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textSlotRight:SetPoint("RIGHT", health, "RIGHT", -2, 0)
    plate.textSlotRight = textSlotRight

    local textSlotLeft = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textSlotLeft:SetPoint("LEFT", health, "LEFT", 2, 0)
    plate.textSlotLeft = textSlotLeft

    local textSlotCenter = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textSlotCenter:SetPoint("CENTER", health, "CENTER", 0, 0)
    plate.textSlotCenter = textSlotCenter

    -- Cast Bar
    if ns.Cast and ns.Cast.CreateCastBar then
        ns.Cast:CreateCastBar(plate)
    end

    -- Aura Slots
    plate.debuffSlots = CreateAuraSlots(frame, health, 5)
    plate.debuffs     = plate.debuffSlots           -- alias for options compat
    plate.buffs       = CreateAuraSlots(frame, health, 4)
    plate.cc          = CreateAuraSlots(frame, health, 2)

    -- Scripts & Lifecycle Hooks
    frame:HookScript("OnShow", function(self)
        plate:OnShow()
    end)
    frame:HookScript("OnHide", function(self)
        plate:OnHide()
    end)

    plates[frame] = plate
    if ns.MatchTracker then
        ns.MatchTracker:RegisterPlate(plate)
    end

    plate:ApplyAppearance()
    return plate
end
ns.CreateNameplate = SkinPlate
ns.SkinPlate = SkinPlate

function PlateMethods:OnShow()
    if ns.MatchTracker then
        ns.MatchTracker:OnPlateShow(self)
    end
    self:ApplyAppearance()
end

function PlateMethods:OnHide()
    if ns.MatchTracker then
        ns.MatchTracker:OnPlateHide(self)
    end
    if self.cast then self.cast:Hide() end
    for _, slot in ipairs(self.debuffSlots) do slot:Hide() end
end

--------------------------------------------------------------------------------
-- WorldFrame Scanner & Driver
--------------------------------------------------------------------------------
local function IsNameplate(frame)
    if not frame or frame == WorldFrame or frame:GetParent() ~= WorldFrame then return false end
    local bars, fonts, signature = 0, 0, false
    for i = 1, select("#", frame:GetRegions()) do
        local r = select(i, frame:GetRegions())
        if r and r.GetObjectType then
            local kind = r:GetObjectType()
            if kind == "FontString" then
                fonts = fonts + 1
            elseif kind == "Texture" then
                local path = r:GetTexture()
                if path and type(path) == "string" then
                    path = lower(path)
                    if find(path, "nameplate", 1, true) or find(path, "targetingframe", 1, true) then
                        signature = true
                    end
                end
            end
        end
    end
    for i = 1, select("#", frame:GetChildren()) do
        local child = select(i, frame:GetChildren())
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            bars = bars + 1
        end
    end
    return signature and bars > 0 and fonts > 0
end

local lastChildren = 0
local function ScanWorldFrame()
    local current = select("#", WorldFrame:GetChildren())
    if current ~= lastChildren then
        lastChildren = current
        for i = 1, current do
            local child = select(i, WorldFrame:GetChildren())
            if child and not plates[child] and IsNameplate(child) then
                SkinPlate(child)
            end
        end
    end
end

local driver = CreateFrame("Frame")
driver:Hide()
local scanElapsed = 0

driver:SetScript("OnUpdate", function(self, elapsed)
    scanElapsed = scanElapsed + elapsed
    if scanElapsed >= 0.1 then
        scanElapsed = 0
        ScanWorldFrame()
    end

    -- Update active plates
    for _, plate in pairs(plates) do
        if plate.frame:IsShown() then
            plate:UpdateHealth()
            plate:ApplyScale()
            plate:ApplyTarget()
            plate:UpdateAuras()
        end
    end
end)

--------------------------------------------------------------------------------
-- Refresh Implementations
--------------------------------------------------------------------------------
function ns.RefreshAllSettings()
    p = ENP.db.profile
    for _, plate in pairs(plates) do
        plate:ApplyAppearance()
    end
    if ns.RangeText_Apply then ns.RangeText_Apply() end
    if ns.NT_RefreshSetting then ns.NT_RefreshSetting() end
end
_G._ENP_RefreshAllSettings = ns.RefreshAllSettings
ns.LegacyRefreshAll = ns.RefreshAllSettings

function ns.RefreshBorder()
    local db = DB()
    local bSize = db.borderSize or 1
    local bColor = db.borderColor or ns.defaults.borderColor
    for _, plate in pairs(plates) do
        SetBorder(plate.border, db.showBorder ~= false, bColor, bSize)
    end
end

function ns.RefreshBorderColor()
    local db = DB()
    local bColor = db.borderColor or ns.defaults.borderColor
    for _, plate in pairs(plates) do
        for _, edge in ipairs(plate.border) do
            edge:SetVertexColor(bColor.r, bColor.g, bColor.b, 1)
        end
    end
end

function ns.RefreshCastBorder()
    for _, plate in pairs(plates) do
        if ns.Cast and ns.Cast.ApplyStyle then ns.Cast:ApplyStyle(plate) end
    end
end
ns.RefreshCastBorderColor = ns.RefreshCastBorder
ns.ApplyBorderWrapToAll = ns.RefreshCastBorder

function ns.NT_Apply(plate)
    if not plate or not plate.frame then return end
    local db = DB()
    local configured = tonumber(db.nonTargetAlpha) or 100
    if configured >= 100 or not UnitExists("target") then
        plate.frame:SetAlpha(1.0)
        return
    end

    local isTarget = ns.MatchTracker and ns.MatchTracker:IsTarget(plate)
    local isFocus = ns.MatchTracker and ns.MatchTracker:IsFocus(plate)

    if not isTarget and not (db.nonTargetKeepFocus ~= false and isFocus) then
        plate.frame:SetAlpha(configured / 100)
    else
        plate.frame:SetAlpha(1.0)
    end
end

function ns.NT_RefreshSetting()
    for _, plate in pairs(plates) do
        ns.NT_Apply(plate)
    end
end

function ns.RefreshFriendlySize()
    for _, plate in pairs(plates) do plate:ApplyAppearance() end
end
ns.RefreshFriendlyNameSize = ns.RefreshFriendlySize
ns.RefreshFriendlyColors = ns.RefreshFriendlySize
ns.RefreshFriendlyPlateOffset = ns.RefreshFriendlySize
ns.RefreshHitboxSize = function() end
ns.ApplyNamePlateClickArea = function() end
ns.SetHitboxOverlayShown = function() end
ns.RefreshStackingMotion = function() end
ns.RefreshStackingBounds = function() end
ns.UpdateClassificationIcon = function() end
ns.UpdateFriendlyNameplateSystem = function() end
ns.ForceFriendlyPlayerCVarsOn = function() end

--------------------------------------------------------------------------------
-- Options-Contract Stubs & Implementations  (WotLK 3.3.5a edition)
-- All symbols listed here are consumed by EUI_Nameplates_Options.lua but are
-- either retail-only features (no-op) or need a WotLK-compatible form.
--------------------------------------------------------------------------------

-- Friendly plates: on 3.3.5 there is no separate container – reuse `plates`.
ns.friendlyPlates = ns.plates

-- NPC overlay reload – no NPC filter system in WotLK, stub.
ns.NPC_ReloadAll = function() end
ns.RefreshAllNPCOverlays = function() end

-- Quest objective refresh – no quest mob highlighting API in 3.3.5, stub.
ns.RefreshQuestObjective = function() end

-- Hover effect refresh – iterate plates and re-apply appearance.
function ns.RefreshHoverEffect()
    for _, plate in pairs(plates) do
        if plate.ApplyAppearance then plate:ApplyAppearance() end
    end
end

-- Friendly resize helpers all map to the same RefreshFriendlySize (no-op aliases).
ns.RefreshFriendlyPlateSize       = ns.RefreshFriendlySize
ns.RefreshFriendlyPlateYOffset    = ns.RefreshFriendlySize
ns.RefreshFriendlyNameTextSize    = ns.RefreshFriendlySize
ns.RefreshFriendlyNameOnlyOffset  = ns.RefreshFriendlySize
ns.RefreshFriendlyHealthText      = ns.RefreshFriendlySize

-- Custom border check – used by target-glow snapshotting.
function ns.IsCustomBorderEnabled()
    return DB().customBorderEnabled == true
end

-- Absorb overlay texture resolution (stripe overlays not available in 3.3.5).
ns.OVERLAY_STRIPE_KEYS = {}   -- empty: no stripe system in WotLK

function ns.ResolveOverlayTexPath(key)
    if not key or key == "none" or key == "---" then return nil end
    -- Stripe keys resolve to a bundled texture under the addon Media directory.
    if ns.OVERLAY_STRIPE_KEYS[key] then
        return "Interface\\AddOns\\EllesmereUINameplates\\Media\\" .. key .. ".tga"
    end
    -- Health-bar textures resolve through the texture registry.
    return ns.healthBarTextures and ns.healthBarTextures[key]
end

-- ApplyAbsorbStyleAll – refresh absorb visual on every live plate (no-op if
-- no absorb overlay is implemented yet).
function ns.ApplyAbsorbStyleAll()
    -- WotLK engine does not have an absorb shield mechanic; safe no-op.
end

-- Per-plate texture refresh helpers (called after texture dropdown changes).
function ns.ApplyHealthBarTexture(plate)
    if plate and plate.health and ns.healthBarTextures then
        local key = DB().healthBarTexture or (ns.defaults and ns.defaults.healthBarTexture)
        local tex = key and ns.healthBarTextures[key]
        if tex then plate.health:SetStatusBarTexture(tex) end
    end
end

function ns.ApplyCastBarTexture(plate)
    if plate and plate.cast and ns.healthBarTextures then
        local key = DB().castBarTexture or DB().healthBarTexture or
                    (ns.defaults and (ns.defaults.castBarTexture or ns.defaults.healthBarTexture))
        local tex = key and ns.healthBarTextures[key]
        if tex then plate.cast:SetStatusBarTexture(tex) end
    end
end

-- Slot strata refresh – re-raise aura frames that need it.
function ns.ApplySlotStrata(plate)
    -- GetSlotRaiseStrata returns whether each position-key's icons should be
    -- raised above everything else; skip if not implemented in this skin.
    if not plate then return end
end

-- PositionAuraSlot – reanchor `count` icon slots to their position key.
-- Signature: (slots, maxCount, posKey, plate, sz, h, spacing, xOff, yOff)
do
    local SLOT_ANCHOR = {
        top      = { pt = "BOTTOM",      xDir =  1, yDir =  1, vertical = false },
        bottom   = { pt = "TOP",         xDir =  1, yDir = -1, vertical = false },
        left     = { pt = "RIGHT",       xDir = -1, yDir =  1, vertical = true  },
        right    = { pt = "LEFT",        xDir =  1, yDir =  1, vertical = true  },
        topleft  = { pt = "BOTTOMRIGHT", xDir = -1, yDir =  1, vertical = false },
        topright = { pt = "BOTTOMLEFT",  xDir =  1, yDir =  1, vertical = false },
    }
    function ns.PositionAuraSlot(slots, count, posKey, plate, sz, h, spacing, xOff, yOff)
        if not slots or not plate or not plate.health then return end
        local cfg = SLOT_ANCHOR[posKey]
        if not cfg then
            for i = 1, count do if slots[i] then slots[i]:Hide() end end
            return
        end
        local anchorPt = cfg.pt
        local isVert   = cfg.vertical
        local step     = (sz + (spacing or 2))
        for i = 1, count do
            local slot = slots[i]
            if not slot then break end
            slot:SetSize(sz, h)
            slot:ClearAllPoints()
            if i == 1 then
                slot:SetPoint(anchorPt, plate.health, anchorPt, xOff, yOff)
            else
                if isVert then
                    slot:SetPoint("TOP", slots[i - 1], "BOTTOM", 0, -(spacing or 2))
                else
                    slot:SetPoint("LEFT", slots[i - 1], "RIGHT", (spacing or 2), 0)
                end
            end
            slot:Show()
        end
    end
end

-- Dispel Glow ------------------------------------------------------------------
-- WotLK edition: a simple "animate" glow using Blizzard's native pixel border.
-- The options file calls StartDispelGlow / StopDispelGlow on preview aura
-- frames only; the preview frames are plain Frames with an .icon texture.
-- We store animated color state in slot._dispelGlow so Stop can clean up.

ns.GLOW_STYLES = {
    { name = "Pixel",   id = 1 },
    { name = "Shine",   id = 2 },
    { name = "Classic", id = 3 },
}

function ns.GetDispelGlowStyle()
    local raw = DB().dispelGlowStyle
    if type(raw) == "number" and raw >= 1 and raw <= #ns.GLOW_STYLES then
        return raw
    end
    return 2  -- default: Shine
end

function ns.StartDispelGlow(slot, size, color)
    if not slot then return end
    -- Simple colored border overlay on the slot frame.
    if not slot._dispelGlowTex then
        local tex = slot:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(slot)
        tex:SetTexture(WHITE)
        tex:SetBlendMode("ADD")
        slot._dispelGlowTex = tex
    end
    local c = color or { r = 0.5, g = 0.5, b = 1.0 }
    slot._dispelGlowTex:SetVertexColor(c.r, c.g, c.b, 0.55)
    slot._dispelGlowTex:Show()
end

function ns.StopDispelGlow(slot)
    if not slot then return end
    if slot._dispelGlowTex then
        slot._dispelGlowTex:Hide()
    end
end

-- GetCastTextAnchor ------------------------------------------------------------
-- Returns (anchorPoint, xBaseOffset, justifyH) for a cast-text FontString.
-- side:          "left" | "right"
-- timerSameSide: true when the countdown timer is on the same side (reserve room)
-- timerW:        pixel width reserved for the timer label
-- isTimer:       true when this is the timer itself (always at the edge)
do
    local CAST_TEXT_EDGE_PAD = 4   -- pixels between bar edge and text
    function ns.GetCastTextAnchor(side, timerSameSide, timerW, isTimer)
        timerW = timerW or 0
        local pt, xb, jh
        if side == "right" then
            pt  = "RIGHT"
            jh  = "RIGHT"
            xb  = -CAST_TEXT_EDGE_PAD
            if not isTimer and timerSameSide then
                xb = xb - timerW
            end
        else  -- default: left
            pt  = "LEFT"
            jh  = "LEFT"
            xb  = CAST_TEXT_EDGE_PAD
            if not isTimer and timerSameSide then
                xb = xb + timerW
            end
        end
        return pt, xb, jh
    end
end

-- GetEnemyNameTextSize & GetDebuffTextColor ------------------------------------
-- Referenced as locals in the options file but only used conditionally.
-- Provide safe defaults so they are not nil after the `local x = ns.x` alias.
function ns.GetEnemyNameTextSize()
    return DB().enemyNameTextSize or (ns.defaults and ns.defaults.enemyNameTextSize) or 11
end

function ns.GetDebuffTextColor()
    local c = (DB() and DB().debuffTextColor) or (ns.defaults and ns.defaults.debuffTextColor)
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end



--------------------------------------------------------------------------------
-- Range to Target Text
--------------------------------------------------------------------------------
do
    local RT = { acc = 0 }

    function RT.Appearance()
        if not RT.fs then return end
        SetFSFont(RT.fs, DB().rangeTextSize or 11, GetNPOutline())
        local c = DB().rangeTextColor or ns.defaults.rangeTextColor
        RT.fs:SetTextColor(c.r, c.g, c.b, 1)
    end

    function RT.Detach()
        RT.plate = nil
        if RT.carrier then RT.carrier:Hide() end
    end

    function RT.Tick()
        if not UnitExists("target") then
            if RT.plate then RT.Detach() end
            return
        end

        local targetPlate
        for _, plate in pairs(plates) do
            if plate.frame:IsShown() and ns.MatchTracker and ns.MatchTracker:IsTarget(plate) then
                targetPlate = plate
                break
            end
        end

        if not targetPlate then
            if RT.plate then RT.Detach() end
            return
        end

        if targetPlate ~= RT.plate then
            if not RT.carrier then
                RT.carrier = CreateFrame("Frame", nil, UIParent)
                RT.carrier:SetSize(2, 2)
                RT.fs = RT.carrier:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            end
            RT.carrier:SetParent(targetPlate.health)
            RT.carrier:SetPoint("LEFT", targetPlate.health, "RIGHT", 5 + (DB().rangeTextOffsetX or 0), DB().rangeTextOffsetY or 0)
            RT.plate = targetPlate
            RT.Appearance()
            RT.carrier:Show()
        end

        if EllesmereUI and EllesmereUI.Range_LowerBound then
            local lower = EllesmereUI.Range_LowerBound("target")
            if lower and lower > 0 then
                RT.fs:SetText(lower .. "+")
                RT.fs:Show()
            else
                RT.fs:Hide()
            end
        else
            RT.fs:Hide()
        end
    end

    ns.RangeText_Refresh = function()
        if RT.plate and RT.fs then RT.Appearance() end
    end

    ns.RangeText_Apply = function()
        if DB().rangeTextEnabled then
            if not RT.drv then
                RT.drv = CreateFrame("Frame")
                RT.drv:Hide()
                RT.drv:SetScript("OnUpdate", function(_, dt)
                    RT.acc = RT.acc + dt
                    if RT.acc < 0.2 then return end
                    RT.acc = 0
                    RT.Tick()
                end)
            end
            if EllesmereUI and EllesmereUI.Range_SetActive then
                EllesmereUI.Range_SetActive("npRangeText", true)
            end
            RT.drv:Show()
        elseif RT.drv then
            if EllesmereUI and EllesmereUI.Range_SetActive then
                EllesmereUI.Range_SetActive("npRangeText", false)
            end
            RT.drv:Hide()
            RT.Detach()
        end
    end
end

--------------------------------------------------------------------------------
-- Addon Lifecycle
--------------------------------------------------------------------------------
function ENP:OnInitialize()
    self.db = EllesmereUI.Lite.NewDB("EllesmereUINameplatesDB", ns.defaults)
    ns.db = self.db
    p = self.db.profile
end

function ENP:OnEnable()
    p = self.db.profile
    driver:Show()
    ScanWorldFrame()
    ns.RefreshAllSettings()
end

function ns.LegacyEnable()
    ENP:OnEnable()
end
