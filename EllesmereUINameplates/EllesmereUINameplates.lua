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
local nextPlateSortID = 0

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

-- The stock raid/classification textures are regions of the native root frame,
-- so they cannot be assigned an independent frame level. Mirror them onto the
-- EUI content frame and leave the native regions alive (at alpha zero) as the
-- authoritative texture/visibility source.
local function CreateNativeIconMirror(source, parent)
    if not source or not parent then return nil end
    local mirror = parent:CreateTexture(nil, "OVERLAY")
    mirror._nativeSource = source
    mirror:SetTexture(source:GetTexture())
    local ulx, uly, llx, lly, urx, ury, lrx, lry = source:GetTexCoord()
    if ulx then mirror:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry) end
    if not source:IsShown() then mirror:Hide() end
    SuppressTexture(source)
    return mirror
end

local function SyncNativeIconMirror(mirror, enabled)
    if not mirror then return end
    local source = mirror._nativeSource
    if not source or not enabled or not source:IsShown() then
        mirror:Hide()
        return
    end
    local texture = source:GetTexture()
    if texture then mirror:SetTexture(texture) end
    local ulx, uly, llx, lly, urx, ury, lrx, lry = source:GetTexCoord()
    if ulx then mirror:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry) end
    mirror:Show()
end

--------------------------------------------------------------------------------
-- Nameplate Frame Construction & Methods
--------------------------------------------------------------------------------
local PlateMethods = {}
local StyleAuraSlots

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
    local anchors = {
        textSlotTop = { "BOTTOM", "TOP", 0, 3 },
        textSlotRight = { "RIGHT", "RIGHT", -2, 0 },
        textSlotLeft = { "LEFT", "LEFT", 2, 0 },
        textSlotCenter = { "CENTER", "CENTER", 0, 0 },
    }
    for _, slotKey in ipairs(ns.textSlotKeys) do
        local fs = self[slotKey]
        local cfg = anchors[slotKey]
        if fs and cfg then
            local xOff, yOff = GetTextSlotOffsets(slotKey)
            if slotKey == "textSlotTop" then yOff = yOff + GetNameYOffset() end
            if self.nameOnly and GetTextSlot(slotKey) == "enemyName" then
                yOff = yOff + (DB().friendlyNameOnlyYOffset or 0)
            end
            fs:ClearAllPoints()
            fs:SetPoint(cfg[1], self.health, cfg[2], cfg[3] + xOff, cfg[4] + yOff)
            if GetTextSlot(slotKey) == "enemyName" then
                local barW = ns.GetHealthBarWidth()
                local pct = DB().enemyNameWidthPct or 100
                fs:SetWidth(max(1, barW * pct / 100))
            else
                fs:SetWidth(ns.GetHealthBarWidth())
            end
        end
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
    local xOff, yOff = GetSlotOffsets(pos)
    if pos == "left" then
        icon:SetPoint("RIGHT", self.health, "LEFT", -3 + xOff, yOff)
    elseif pos == "right" then
        icon:SetPoint("LEFT", self.health, "RIGHT", 3 + xOff, yOff)
    elseif pos == "bottom" then
        icon:SetPoint("TOP", self.cast or self.health, "BOTTOM", xOff, -3 + yOff)
    elseif pos == "topleft" then
        icon:SetPoint("BOTTOMRIGHT", self.health, "TOPLEFT", xOff, 3 + yOff)
    elseif pos == "topright" then
        icon:SetPoint("BOTTOMLEFT", self.health, "TOPRIGHT", xOff, 3 + yOff)
    else
        icon:SetPoint("BOTTOM", self.health, "TOP", xOff, 3 + yOff)
    end
end

function PlateMethods:SyncNativeIndicators()
    local raidPos = ns.GetRaidMarkerPos and ns.GetRaidMarkerPos() or "topright"
    SyncNativeIconMirror(self.raidIcon, raidPos ~= "none")

    local classPos = GetClassificationSlot()
    local classEnabled = DB().showClassificationIndicator == true and classPos ~= "none"
    SyncNativeIconMirror(self.bossIcon, classEnabled)
    SyncNativeIconMirror(self.eliteIcon, classEnabled)
end

function PlateMethods:UpdateClassification()
    local pos = GetClassificationSlot()
    local size = GetRareEliteIconSize()
    local enabled = DB().showClassificationIndicator == true
    for _, icon in ipairs({ self.bossIcon, self.eliteIcon }) do
        if icon then
            local source = icon._nativeSource
            if not enabled or pos == "none" or (source and not source:IsShown()) then
                icon:Hide()
            else
                icon:SetSize(size, size)
                icon:ClearAllPoints()
                local xOff, yOff = GetSlotOffsets(pos)
                if pos == "left" then
                    icon:SetPoint("RIGHT", self.health, "LEFT", -3 + xOff, yOff)
                elseif pos == "right" then
                    icon:SetPoint("LEFT", self.health, "RIGHT", 3 + xOff, yOff)
                elseif pos == "bottom" then
                    icon:SetPoint("TOP", self.cast or self.health, "BOTTOM", xOff, -3 + yOff)
                elseif pos == "topleft" then
                    icon:SetPoint("BOTTOMRIGHT", self.health, "TOPLEFT", xOff, 3 + yOff)
                elseif pos == "topright" then
                    icon:SetPoint("BOTTOMLEFT", self.health, "TOPRIGHT", xOff, 3 + yOff)
                else
                    icon:SetPoint("BOTTOM", self.health, "TOP", xOff, 3 + yOff)
                end
                icon:Show()
            end
        end
    end
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

function PlateMethods:LayoutHealthBar(width, height)
    local health = self.health
    if not health then return end

    -- Stock 3.3.5 nameplates anchor the health bar by an edge on some client
    -- builds. Changing its width/height then makes the bar grow to one side.
    -- Re-anchor the bar by its original centre so custom sizes (and target
    -- scaling) expand evenly in every direction.
    if self.nativeHealthRelativePoint then
        health:ClearAllPoints()
        health:SetPoint("CENTER", self.nativeHealthRelativeTo,
            self.nativeHealthRelativePoint,
            self.nativeHealthCenterX or 0, self.nativeHealthCenterY or 0)
    end
    health:SetSize(width, height)
end

function PlateMethods:ApplyAppearance()
    local db = DB()
    local barW = ns.GetHealthBarWidth()
    local barH = ns.GetHealthBarHeight()

    self:LayoutHealthBar(barW, barH)

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
    local customBorder = db.customBorderEnabled == true
    local bSize = customBorder and (db.customBorderSize or 1) or (db.borderSize or 1)
    local bColor = customBorder and (db.customBorderColor or ns.defaults.borderColor)
        or (db.borderColor or ns.defaults.borderColor)
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
    self:RefreshNamePosition()
    self:UpdateRaidIcon()
    self:UpdateClassification()
    self:SyncNativeIndicators()
    if StyleAuraSlots then StyleAuraSlots(self) end
    if ns.ApplySlotStrata then ns.ApplySlotStrata(self) end

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
    self:SyncStrata()
    if ns.ApplyNamePlateClickArea then ns.ApplyNamePlateClickArea(self) end
end

function PlateMethods:UpdateHealthValues()
    -- The Wrath client can re-show its stock name/level strings after our
    -- initial skin pass. Keep those source regions suppressed; EUI renders
    -- their text through its own configurable slots.
    for _, source in ipairs(self.nativeFonts or {}) do
        SuppressSourceFont(source)
    end

    local db = DB()
    local showLevel = db.showLevelText == true
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
            elseif el == "level" and showLevel then
                fs:SetText(self:GetLevelText())
            else
                fs:SetText("")
            end
            local show = el and el ~= "none"
            if el == "level" and not showLevel then show = false end
            if self.nameOnly and el ~= "enemyName" then show = false end
            if show then fs:Show() else fs:Hide() end
        end
    end
end

function PlateMethods:UpdateHealthColor()
    if self.applyingColor then return end
    self.applyingColor = true

    local db = DB()
    local r = self.nativeHealthR
    local g = self.nativeHealthG
    local b = self.nativeHealthB
    if not r then r, g, b = self.health:GetStatusBarColor() end
    local isTarget = ns.MatchTracker and ns.MatchTracker:IsTarget(self)
    local isFocus = ns.MatchTracker and ns.MatchTracker:IsFocus(self)

    -- Check reaction from Blizzard native color
    local isHostile = r > 0.85 and g < 0.25 and b < 0.25
    local isNeutral = r > 0.75 and g > 0.65 and b < 0.35
    local isTapped  = abs(r - g) < 0.08 and abs(g - b) < 0.08 and r < 0.7
    local isFriendly = not isHostile and not isNeutral and not isTapped
    local wasNameOnly = self.nameOnly
    self.isFriendly = isFriendly
    self.isFriendlyPlayer = isFriendly and not (r < 0.05 and g > 0.95 and b < 0.05)
    self.nameOnly = self.isFriendlyPlayer and db.friendlyNameOnly ~= false
    if wasNameOnly ~= self.nameOnly then
        for _, slotKey in ipairs(ns.textSlotKeys) do
            local fs = self[slotKey]
            if fs and GetTextSlot(slotKey) == "enemyName" then
                local size = self.nameOnly and (db.friendlyNameSize or 15) or GetTextSlotSize(slotKey)
                SetFSFont(fs, size, GetNPOutline())
            end
        end
        self:RefreshNamePosition()
    end

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
    self:UpdateHealthColor()
    self:UpdateHealthValues()
    -- Classification textures are native regions and the client may restore
    -- their visibility/anchors after a unit changes. Reassert EUI's setting.
    self:UpdateClassification()
end

function PlateMethods:ApplyScale()
    local isTarget = ns.MatchTracker and ns.MatchTracker:IsTarget(self)
    local targetScale = ns.GetTargetScale()
    local scale = isTarget and targetScale or 1.0
    local castScale = scale * ((DB().castScale or 100) / 100)

    local changed = false
    if self.currentScale ~= scale then
        self.currentScale = scale
        self.health:SetScale(scale)
        if self.targetGlowFrame then self.targetGlowFrame:SetScale(scale) end
        changed = true
    end
    if self.cast and self.currentCastScale ~= castScale then
        self.currentCastScale = castScale
        self.cast:SetScale(castScale)
    end
    if changed and ns.ApplyNamePlateClickArea then
        ns.ApplyNamePlateClickArea(self)
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
    local customBorder = db.customBorderEnabled == true
    local borderColor = customBorder and (db.customBorderColor or ns.defaults.borderColor)
        or (db.borderColor or ns.defaults.borderColor)
    local borderSize = customBorder and (db.customBorderSize or 1) or (db.borderSize or 1)
    if isTarget and ns.GetTargetGlowBorderColor() then
        borderColor = ns.GetTargetBorderColor()
    end
    if isTarget and ns.GetTargetGlowBorderSize() then
        borderSize = ns.GetTargetBorderSizeValue() or borderSize
    end
    SetBorder(self.border, db.showBorder ~= false and borderSize > 0, borderColor, borderSize)

    -- Target/focus texture overlays.
    local isFocus = ns.MatchTracker and ns.MatchTracker:IsFocus(self)
    local overlayKey, overlayAlpha, overlayColor, noTint
    if isTarget and db.targetOverlayTexture and db.targetOverlayTexture ~= "none" then
        overlayKey = db.targetOverlayTexture
        overlayAlpha = db.targetOverlayAlpha or 1
        overlayColor = db.targetOverlayColor or { r = 1, g = 1, b = 1 }
        noTint = db.targetOverlayNoTint == true
    elseif isFocus and (db.focusOverlayTexture or "striped-v2") ~= "none" then
        overlayKey = db.focusOverlayTexture or "striped-v2"
        overlayAlpha = db.focusOverlayAlpha or 1
        overlayColor = db.focusOverlayColor or { r = 1, g = 1, b = 1 }
        noTint = db.focusOverlayNoTint == true
    end
    if overlayKey then
        self.specialOverlay:SetTexture(ns.ResolveOverlayTexPath(overlayKey) or WHITE)
        if noTint then
            local r, g, b = self.health:GetStatusBarColor()
            self.specialOverlay:SetVertexColor(r, g, b, overlayAlpha)
        else
            self.specialOverlay:SetVertexColor(overlayColor.r, overlayColor.g, overlayColor.b, overlayAlpha)
        end
        self.specialOverlay:Show()
    else
        self.specialOverlay:Hide()
    end

    local isMouseover = ns.MatchTracker and ns.MatchTracker:IsMouseover(self)
    local hoverKey = db.hoverOverlayTexture or "none"
    if isMouseover and hoverKey ~= "none" then
        local color = db.hoverColor or ns.defaults.hoverColor
        self.hoverOverlay:SetTexture(ns.ResolveOverlayTexPath(hoverKey) or WHITE)
        self.hoverOverlay:SetVertexColor(color.r, color.g, color.b, db.hoverAlpha or 0.3)
        self.hoverOverlay:Show()
    else
        self.hoverOverlay:Hide()
    end

    if isFocus and db.focusLetterEnabled then
        local anchor = db.focusLetterAnchor or "CENTER"
        self.focusLetter:ClearAllPoints()
        self.focusLetter:SetPoint(anchor, self.health, anchor, db.focusLetterX or 0, db.focusLetterY or 0)
        SetFSFont(self.focusLetter, db.focusLetterSize or 18, GetNPOutline())
        self.focusLetter:Show()
    else
        self.focusLetter:Hide()
    end

    -- Non-target opacity
    ns.NT_Apply(self)
end

function PlateMethods:UpdateAuras()
    if not ns.AuraTracker then return end
    local db = DB()
    local harmful = ns.AuraTracker:GetAurasForPlate(self, "HARMFUL")
    local helpful = ns.AuraTracker:GetAurasForPlate(self, "HELPFUL")
    local playerGUID = UnitGUID("player")
    local petGUID = UnitGUID("pet")

    local function SetSlot(slot, aura)
        slot.icon:SetTexture(aura.icon)
        if aura.count and aura.count > 1 then
            slot.countText:SetText(aura.count)
            if slot.countEnabled ~= false then slot.countText:Show() else slot.countText:Hide() end
        else
            slot.countText:SetText("")
            slot.countText:Hide()
        end
        if aura.expirationTime and aura.expirationTime < math.huge then
            local rem = max(0, aura.expirationTime - GetTime())
            slot.durationText:SetFormattedText(rem < 10 and "%.1f" or "%.0f", rem)
            if slot.durationEnabled ~= false then slot.durationText:Show() else slot.durationText:Hide() end
        else
            slot.durationText:SetText("")
            slot.durationText:Hide()
        end
        slot:Show()
    end

    local debuffCount, ccCount, buffCount = 0, 0, 0
    local maxDebuffs = min(db.maxDebuffs or 5, #self.debuffSlots)
    for i = 1, #self.debuffSlots do self.debuffSlots[i]:Hide() end
    for i = 1, #self.cc do self.cc[i]:Hide() end
    for i = 1, #self.buffs do self.buffs[i]:Hide() end

    if harmful then
        for _, aura in ipairs(harmful) do
            local isCC = ns.DiminishingReturnsSpells and ns.DiminishingReturnsSpells[aura.spellId]
            if isCC and ccCount < #self.cc then
                ccCount = ccCount + 1
                SetSlot(self.cc[ccCount], aura)
            end
            local isMine = aura.casterGUID == playerGUID or (petGUID and aura.casterGUID == petGUID)
            if isMine and debuffCount < maxDebuffs and (not isCC or db.debuffIncludeCC) then
                debuffCount = debuffCount + 1
                SetSlot(self.debuffSlots[debuffCount], aura)
            end
        end
    end
    if helpful then
        for _, aura in ipairs(helpful) do
            if buffCount >= #self.buffs then break end
            buffCount = buffCount + 1
            SetSlot(self.buffs[buffCount], aura)
        end
    end

    local ds, bs, cs = GetAuraSlots()
    local dx, dy = GetAuraSlotOffsets("debuffSlot")
    local bx, by = GetAuraSlotOffsets("buffSlot")
    local cx, cy = GetAuraSlotOffsets("ccSlot")
    local dsz, bsz, csz = GetDebuffIconSize(), GetBuffIconSize(), GetCCIconSize()
    ns.PositionAuraSlot(self.debuffSlots, debuffCount, ds, self, dsz,
        ns.GetAuraCropHeight(ns.GetAuraCrop("debuffs"), dsz), GetAuraSpacing("debuffs"), dx, dy)
    ns.PositionAuraSlot(self.buffs, buffCount, bs, self, bsz,
        ns.GetAuraCropHeight(ns.GetAuraCrop("buffs"), bsz), GetAuraSpacing("buffs"), bx, by)
    ns.PositionAuraSlot(self.cc, ccCount, cs, self, csz,
        ns.GetAuraCropHeight(ns.GetAuraCrop("ccs"), csz), GetAuraSpacing("ccs"), cx, cy)
end

--------------------------------------------------------------------------------
-- Plate Factory & Skinner
--------------------------------------------------------------------------------
local function CreateAuraSlots(parent, anchor, count, element)
    local slots = {}
    local sz = element == "buffs" and ns.GetBuffIconSize()
        or element == "ccs" and ns.GetCCIconSize() or ns.GetDebuffIconSize()
    local crop = ns.GetAuraCrop(element)
    local h = ns.GetAuraCropHeight(crop, sz)

    for i = 1, count do
        local slot = CreateFrame("Frame", nil, parent)
        slot.auraElement = element
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
        slot.count = countText

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


StyleAuraSlots = function(plate)
    local db = DB()
    local groups = {
        { slots = plate.debuffSlots, element = "debuffs", size = GetDebuffIconSize(), pos = db.debuffSlot or ns.defaults.debuffSlot },
        { slots = plate.buffs, element = "buffs", size = GetBuffIconSize(), pos = db.buffSlot or ns.defaults.buffSlot },
        { slots = plate.cc, element = "ccs", size = GetCCIconSize(), pos = db.ccSlot or ns.defaults.ccSlot },
    }
    for _, group in ipairs(groups) do
        local crop = ns.GetAuraCrop(group.element)
        local height = ns.GetAuraCropHeight(crop, group.size)
        for _, slot in ipairs(group.slots) do
            ns.ApplyAuraSlotCrop(slot, crop, group.size)
            SetFSFont(slot.countText, db.auraStackTextSize or 11, GetNPOutline())
            local stackColor = db.auraStackTextColor or ns.defaults.auraStackTextColor
            slot.countText:SetTextColor(stackColor.r, stackColor.g, stackColor.b, 1)
            local prefix = group.element == "ccs" and "cc" or group.element == "buffs" and "buff" or "debuff"
            SetFSFont(slot.durationText, db[prefix .. "DurationTextSize"] or db.auraDurationTextSize or 11, GetNPOutline())
            local durationColor = db[prefix .. "DurationTextColor"] or db.auraDurationTextColor or ns.defaults.auraDurationTextColor
            slot.durationText:SetTextColor(durationColor.r, durationColor.g, durationColor.b, 1)
            local durationPos = db[prefix .. "TimerPosition"] or db.auraTextPosition or "topleft"
            local durationX = db[prefix .. "DurationTextX"] or db.auraDurationTextX or 0
            local durationY = db[prefix .. "DurationTextY"] or db.auraDurationTextY or 0
            slot.durationEnabled = durationPos ~= "none"
            if not slot.durationEnabled then slot.durationText:Hide() end
            slot.durationText:ClearAllPoints()
            if durationPos == "center" then
                slot.durationText:SetPoint("CENTER", slot, "CENTER", durationX, durationY)
            elseif durationPos == "topright" then
                slot.durationText:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 3 + durationX, 4 + durationY)
            elseif durationPos == "bottomleft" then
                slot.durationText:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", -3 + durationX, -4 + durationY)
            elseif durationPos == "bottomright" then
                slot.durationText:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 3 + durationX, -4 + durationY)
            else
                slot.durationText:SetPoint("TOPLEFT", slot, "TOPLEFT", -3 + durationX, 4 + durationY)
            end
            local stackPos = db.auraStackTextPosition or "bottomright"
            local stackX, stackY = db.auraStackTextX or 0, db.auraStackTextY or 0
            slot.countEnabled = stackPos ~= "none"
            if not slot.countEnabled then slot.countText:Hide() end
            slot.countText:ClearAllPoints()
            if stackPos == "center" then
                slot.countText:SetPoint("CENTER", slot, "CENTER", stackX, stackY)
            elseif stackPos == "topright" then
                slot.countText:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 3 + stackX, 4 + stackY)
            elseif stackPos == "bottomleft" then
                slot.countText:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", -3 + stackX, -4 + stackY)
            elseif stackPos == "topleft" then
                slot.countText:SetPoint("TOPLEFT", slot, "TOPLEFT", -3 + stackX, 4 + stackY)
            else
                slot.countText:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 3 + stackX, -4 + stackY)
            end
            SetBorder(slot.border, true, db.auraBorderColor or { r = 0, g = 0, b = 0 }, 1)
        end
    end
end

local function SkinPlate(frame)
    if plates[frame] then return plates[frame] end

    -- Extract Blizzard parts
    local health, nativeCast, nativeGlow, highlight
    local fonts = {}

    for i = 1, select("#", frame:GetChildren()) do
        local child = select(i, frame:GetChildren())
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            if not health then health = child elseif not nativeCast then nativeCast = child end
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
                local keepNative = false
                if path and type(path) == "string" then
                    path = lower(path)
                    if find(path, "nameplate-glow", 1, true) then
                        nativeGlow = r
                    elseif find(path, "nameplate-highlight", 1, true) or find(path, "ui-targetingframe-flash", 1, true) then
                        highlight = r
                    elseif find(path, "ui-raidtargetingicons", 1, true) then
                        raidIcon = r
                        keepNative = true
                    elseif find(path, "ui-targetingframe-skull", 1, true) then
                        bossIcon = r
                        keepNative = true
                    elseif find(path, "elitedragon", 1, true)
                        or find(path, "rareelite", 1, true)
                        or find(path, "rare-elite", 1, true)
                        or find(path, "rare_elite", 1, true)
                        or find(path, "targetingframe-elite", 1, true)
                        or find(path, "nameplate-elite", 1, true) then
                        eliteIcon = r
                        keepNative = true
                    end
                end
                if not keepNative then
                    SuppressTexture(r)
                end
            end
        end
    end

    -- Identify source texts
    local nameSource, levelSource
    for _, fs in ipairs(fonts) do
        local txt = fs:GetText()
        if txt and (tostring(txt) == "??" or tostring(txt):match("^%??%d+[%+%-]?$")) then
            levelSource = levelSource or fs
        elseif txt and txt ~= "" then
            nameSource = nameSource or fs
        end
    end
    nameSource = nameSource or fonts[1]

    -- Build plate object
    local plate = setmetatable({}, { __index = PlateMethods })
    nextPlateSortID = nextPlateSortID + 1
    plate.depthSortID = nextPlateSortID
    plate.frame = frame
    plate.health = health
    plate.nativeCast = nativeCast
    plate.nameSource = nameSource
    plate.levelSource = levelSource
    plate.nativeFonts = fonts
    plate.nativeGlow = nativeGlow
    plate.nativeHighlight = highlight
    plate.nativeRaidIcon = raidIcon
    plate.nativeBossIcon = bossIcon
    plate.nativeEliteIcon = eliteIcon

    -- All visible EUI regions that used to live directly on the native root
    -- are hosted here. SyncStrata can therefore move the whole custom plate
    -- into a non-overlapping depth band without modifying Blizzard's root
    -- level (which remains our depth signal).
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetAllPoints(frame)
    plate.contentFrame = contentFrame

    -- Regions share their owner's frame level, so text/arrows/indicators use
    -- a separate overlay host while child frames remain parented to the low
    -- band root. This keeps every child level at or above its parent's level.
    local overlayFrame = CreateFrame("Frame", nil, contentFrame)
    overlayFrame:SetAllPoints(frame)
    plate.overlayFrame = overlayFrame

    plate.raidIcon = CreateNativeIconMirror(raidIcon, overlayFrame)
    plate.bossIcon = CreateNativeIconMirror(bossIcon, overlayFrame)
    plate.eliteIcon = CreateNativeIconMirror(eliteIcon, overlayFrame)

    -- Preserve the stock health bar's visual centre before replacing its
    -- dimensions. Keeping the relative anchor also avoids depending on
    -- screen coordinates, which are unavailable while a plate is hidden.
    do
        local point, relativeTo, relativePoint, x, y = health:GetPoint(1)
        local nativeW = health:GetWidth() or 0
        local nativeH = health:GetHeight() or 0
        if point then
            x, y = x or 0, y or 0
            if find(point, "LEFT", 1, true) then
                x = x + nativeW * 0.5
            elseif find(point, "RIGHT", 1, true) then
                x = x - nativeW * 0.5
            end
            if find(point, "TOP", 1, true) then
                y = y - nativeH * 0.5
            elseif find(point, "BOTTOM", 1, true) then
                y = y + nativeH * 0.5
            end
            plate.nativeHealthRelativeTo = relativeTo or frame
            plate.nativeHealthRelativePoint = relativePoint or point
            plate.nativeHealthCenterX = x
            plate.nativeHealthCenterY = y
        end
        plate.nativeHealthWidth = nativeW
        plate.nativeHealthHeight = nativeH
    end

    -- Keep the stock cast StatusBar as the physical cast source. Anonymous
    -- Wrath plates cannot otherwise be associated with most CLEU source GUIDs.
    -- Hide only its stock chrome; Cast:CreateCastBar adds EUI replacements.
    if nativeCast then
        local fill = nativeCast.GetStatusBarTexture and nativeCast:GetStatusBarTexture()
        for i = 1, select("#", nativeCast:GetRegions()) do
            local region = select(i, nativeCast:GetRegions())
            if region and region ~= fill and region.GetObjectType then
                if region:GetObjectType() == "FontString" then
                    plate.nativeCastTextSource = plate.nativeCastTextSource or region
                    SuppressSourceFont(region)
                elseif region:GetObjectType() == "Texture" then
                    local path = region:GetTexture()
                    if type(path) == "string" and find(lower(path), "shield", 1, true) then
                        plate.nativeCastShieldSource = region
                    end
                    SuppressTexture(region)
                end
            end
        end
    end

    -- Health Background
    local healthBg = health:CreateTexture(nil, "BACKGROUND")
    healthBg:SetTexture(WHITE)
    healthBg:SetAllPoints(health)
    plate.healthBg = healthBg
    plate.healthBG = healthBg -- options compatibility

    -- Border lives on a dedicated child frame so its frame level can be
    -- managed independently of the health StatusBar.  This prevents border
    -- edge textures from one nameplate bleeding over the health-bar fill of
    -- another nameplate that shares the same engine-assigned frame level.
    local borderFrame = CreateFrame("Frame", nil, contentFrame)
    borderFrame:SetAllPoints(health)
    plate.borderFrame = borderFrame
    plate.border = CreateBorder(health, borderFrame)

    -- EUI Target Glow & Highlight
    plate.targetGlowFrame = CreateTargetGlowFrame(contentFrame, health)
    plate.targetHighlight = health:CreateTexture(nil, "OVERLAY")
    plate.targetHighlight:SetTexture(WHITE)
    plate.targetHighlight:SetAllPoints(health)
    plate.targetHighlight:Hide()

    plate.specialOverlay = health:CreateTexture(nil, "OVERLAY")
    plate.specialOverlay:SetAllPoints(health)
    plate.specialOverlay:Hide()
    plate.hoverOverlay = health:CreateTexture(nil, "OVERLAY")
    plate.hoverOverlay:SetAllPoints(health)
    plate.hoverOverlay:Hide()
    plate.focusLetter = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plate.focusLetter:SetText("F")
    plate.focusLetter:Hide()

    -- Target Arrows
    plate.leftArrow = overlayFrame:CreateTexture(nil, "OVERLAY")
    plate.rightArrow = overlayFrame:CreateTexture(nil, "OVERLAY")
    plate.leftArrow:Hide()
    plate.rightArrow:Hide()

    -- Text Slots
    local nameText = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, 3)
    plate.nameText = nameText
    plate.textSlotTop = nameText

    local textSlotRight = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textSlotRight:SetPoint("RIGHT", health, "RIGHT", -2, 0)
    plate.textSlotRight = textSlotRight

    local textSlotLeft = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textSlotLeft:SetPoint("LEFT", health, "LEFT", 2, 0)
    plate.textSlotLeft = textSlotLeft

    local textSlotCenter = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textSlotCenter:SetPoint("CENTER", health, "CENTER", 0, 0)
    plate.textSlotCenter = textSlotCenter

    -- Cast Bar
    if ns.Cast and ns.Cast.CreateCastBar then
        ns.Cast:CreateCastBar(plate)
    end

    -- Aura Slots
    plate.debuffSlots = CreateAuraSlots(contentFrame, health, 10, "debuffs")
    plate.debuffs     = plate.debuffSlots           -- alias for options compat
    plate.buffs       = CreateAuraSlots(contentFrame, health, 4, "buffs")
    plate.cc          = CreateAuraSlots(contentFrame, health, 2, "ccs")

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

    plate.nativeHealthR, plate.nativeHealthG, plate.nativeHealthB = health:GetStatusBarColor()
    if hooksecurefunc then
        hooksecurefunc(health, "SetStatusBarColor", function(_, r, g, b)
            if not plate.applyingColor then
                plate.nativeHealthR, plate.nativeHealthG, plate.nativeHealthB = r, g, b
                plate:UpdateHealthColor()
            end
        end)
    end

    if frame:IsShown() then plate:OnShow() else plate:ApplyAppearance() end
    return plate
end
ns.CreateNameplate = SkinPlate
ns.SkinPlate = SkinPlate

function PlateMethods:OnShow()
    if not self.nativeHealthR then
        self.nativeHealthR, self.nativeHealthG, self.nativeHealthB = self.health:GetStatusBarColor()
    end
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
    for _, slot in ipairs(self.buffs) do slot:Hide() end
    for _, slot in ipairs(self.cc) do slot:Hide() end
    self.nativeHealthR, self.nativeHealthG, self.nativeHealthB = nil, nil, nil
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
local depthSortScratch = {}

-- Native WotLK frame levels are depth-aware but are not unique: nearby units
-- can receive the same level. Rank every visible plate so equal native levels
-- get deterministic, non-overlapping bands. Within a native-level tie, a lower
-- screen anchor is treated as nearer; that matches the projected ordering of
-- ordinary ground units and, importantly, produces one whole-plate winner.
local function UpdatePlateDepthRanks()
    local count = 0
    for _, plate in pairs(plates) do
        if plate.frame:IsShown() then
            count = count + 1
            depthSortScratch[count] = plate
            plate.depthNativeLevel = plate.frame:GetFrameLevel() or 0
            local _, screenY = plate.frame:GetCenter()
            plate.depthScreenY = screenY
        end
    end
    for i = count + 1, #depthSortScratch do depthSortScratch[i] = nil end

    table.sort(depthSortScratch, function(a, b)
        local aNative = a.depthNativeLevel or 0
        local bNative = b.depthNativeLevel or 0
        if aNative ~= bNative then return aNative < bNative end

        local aY = a.depthScreenY
        local bY = b.depthScreenY
        if aY and bY and aY ~= bY then return aY > bY end
        if aY ~= nil and bY == nil then return false end
        if aY == nil and bY ~= nil then return true end
        return (a.depthSortID or 0) < (b.depthSortID or 0)
    end)

    for rank = 1, count do
        depthSortScratch[rank].depthRank = rank
    end
end

driver:SetScript("OnUpdate", function(self, elapsed)
    scanElapsed = scanElapsed + elapsed
    if scanElapsed < 0.05 then return end
    scanElapsed = 0
    ScanWorldFrame()
    if ns.MatchTracker then
        if ns.MatchTracker.pendingFullUpdate then
            ns.MatchTracker.pendingFullUpdate = nil
            ns.MatchTracker:UpdateAll()
        else
            ns.MatchTracker:UpdateSpecialUnits()
        end
    end
    UpdatePlateDepthRanks()

    -- Update active plates
    for _, plate in pairs(plates) do
        if plate.frame:IsShown() then
            plate:SyncStrata()
            plate:SyncNativeIndicators()
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
    local customBorder = db.customBorderEnabled == true
    local bSize = customBorder and (db.customBorderSize or 1) or (db.borderSize or 1)
    local bColor = customBorder and (db.customBorderColor or ns.defaults.borderColor)
        or (db.borderColor or ns.defaults.borderColor)
    for _, plate in pairs(plates) do
        SetBorder(plate.border, db.showBorder ~= false, bColor, bSize)
    end
end

function ns.RefreshBorderColor()
    local db = DB()
    local bColor = db.customBorderEnabled and (db.customBorderColor or ns.defaults.borderColor)
        or (db.borderColor or ns.defaults.borderColor)
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
    if configured < 0 then configured = 0 elseif configured > 100 then configured = 100 end

    local isTarget = ns.MatchTracker and ns.MatchTracker:IsTarget(plate)
    local isFocus = ns.MatchTracker and ns.MatchTracker:IsFocus(plate)
    local wanted = 1
    if configured < 100 and UnitExists("target") and not isTarget
        and not (db.nonTargetKeepFocus ~= false and isFocus) then
        wanted = configured / 100
    end

    -- Never write the stock root alpha: it is the authoritative WotLK target
    -- marker and also carries Blizzard's distance fade. Compensate child alpha
    -- so the configured value acts as a cap on the final rendered opacity.
    local native = plate.frame:GetAlpha() or 1
    local alpha = wanted
    if native > 0 then alpha = min(1, wanted / native) end
    if plate.visualAlpha == alpha and plate.visualNameOnly == plate.nameOnly then return end
    plate.visualAlpha = alpha
    plate.visualNameOnly = plate.nameOnly

    plate.health:SetAlpha(plate.nameOnly and 0 or alpha)
    if plate.borderFrame then
        plate.borderFrame:SetAlpha(plate.nameOnly and 0 or alpha)
    end
    if plate.cast then plate.cast:SetAlpha(alpha) end
    if plate.targetGlowFrame then plate.targetGlowFrame:SetAlpha(alpha) end
    if plate.targetHighlight then plate.targetHighlight:SetAlpha(alpha) end
    if plate.leftArrow then plate.leftArrow:SetAlpha(alpha) end
    if plate.rightArrow then plate.rightArrow:SetAlpha(alpha) end
    if plate.focusLetter then plate.focusLetter:SetAlpha(alpha) end
    for _, slotKey in ipairs(ns.textSlotKeys) do
        local fs = plate[slotKey]
        if fs then fs:SetAlpha(alpha) end
    end
    for _, slots in ipairs({ plate.debuffSlots, plate.buffs, plate.cc }) do
        for _, slot in ipairs(slots or {}) do slot:SetAlpha(alpha) end
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

local function GetEffectiveScale(frame)
    if frame and frame.GetEffectiveScale then
        local scale = frame:GetEffectiveScale()
        if scale and scale > 0 then return scale end
    end
    if frame and frame.GetScale then
        local scale = frame:GetScale()
        if scale and scale > 0 then return scale end
    end
    return 1
end

local function EnsureHitboxOverlay(plate)
    if plate.hitboxOverlay then return plate.hitboxOverlay end
    local overlay = (plate.overlayFrame or plate.contentFrame or plate.frame):CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(0.1, 0.65, 1, 0.22)
    overlay:SetBlendMode("ADD")
    overlay:Hide()
    plate.hitboxOverlay = overlay
    return overlay
end

function ns.ApplyNamePlateClickArea(targetPlate)
    local db = DB()
    local scaleX = max(0.01, (db.hitboxScaleX or 100) / 100)
    local scaleY = max(0.01, (db.hitboxScaleY or 100) / 100)

    local function Apply(plate)
        local frame, health = plate.frame, plate.health
        if not (frame and health) then return end

        if plate.isFriendly then
            if frame.SetHitRectInsets then
                pcall(frame.SetHitRectInsets, frame, 0, 0, 0, 0)
            end
            if plate.hitboxOverlay then plate.hitboxOverlay:Hide() end
            return
        end

        local frameScale = GetEffectiveScale(frame)
        local healthScale = GetEffectiveScale(health)
        local relativeScale = healthScale / frameScale
        local desiredW = max(1, (health:GetWidth() or 1) * relativeScale * scaleX)
        local desiredH = max(1, (health:GetHeight() or 1) * relativeScale * scaleY)

        -- SetHitRectInsets is available on Wrath Frames/Buttons. Negative
        -- values expand the clickable region; positive values shrink it.
        -- Align the region with the health bar rather than assuming the stock
        -- nameplate root and bar share the same vertical centre.
        if frame.SetHitRectInsets then
            local frameW = frame:GetWidth() or 0
            local frameH = frame:GetHeight() or 0
            local offsetX, offsetY = 0, 0
            if plate.nativeHealthRelativeTo == frame and plate.nativeHealthRelativePoint then
                local relativePoint = plate.nativeHealthRelativePoint
                if find(relativePoint, "LEFT", 1, true) then
                    offsetX = -frameW * 0.5
                elseif find(relativePoint, "RIGHT", 1, true) then
                    offsetX = frameW * 0.5
                end
                if find(relativePoint, "TOP", 1, true) then
                    offsetY = frameH * 0.5
                elseif find(relativePoint, "BOTTOM", 1, true) then
                    offsetY = -frameH * 0.5
                end
                offsetX = offsetX + (plate.nativeHealthCenterX or 0)
                offsetY = offsetY + (plate.nativeHealthCenterY or 0)
            elseif frame.GetCenter and health.GetCenter then
                local frameX, frameY = frame:GetCenter()
                local healthX, healthY = health:GetCenter()
                if frameX and healthX then
                    offsetX = healthX * healthScale / frameScale - frameX
                end
                if frameY and healthY then
                    offsetY = healthY * healthScale / frameScale - frameY
                end
            end
            local left = frameW * 0.5 + offsetX - desiredW * 0.5
            local right = frameW * 0.5 - offsetX - desiredW * 0.5
            local top = frameH * 0.5 - offsetY - desiredH * 0.5
            local bottom = frameH * 0.5 + offsetY - desiredH * 0.5
            local ok = pcall(frame.SetHitRectInsets, frame, left, right, top, bottom)
            plate.hitboxInsetsSupported = ok
        end

        local overlay = plate.hitboxOverlay
        if ns._hitboxOverlayShown then
            overlay = overlay or EnsureHitboxOverlay(plate)
            overlay:ClearAllPoints()
            overlay:SetPoint("CENTER", health, "CENTER", 0, 0)
            overlay:SetSize(desiredW, desiredH)
            overlay:Show()
        elseif overlay then
            overlay:Hide()
        end
    end

    if targetPlate then
        Apply(targetPlate)
    else
        for _, plate in pairs(plates) do Apply(plate) end
    end
end

function ns.RefreshHitboxSize()
    ns.ApplyNamePlateClickArea()
end

function ns.SetHitboxOverlayShown(shown)
    ns._hitboxOverlayShown = shown == true
    ns.ApplyNamePlateClickArea()
end
ns.RefreshStackingMotion = function() end
ns.RefreshStackingBounds = function() end
function ns.UpdateClassificationIcon(plate)
    if plate and plate.UpdateClassification then
        plate:UpdateClassification()
        return
    end
    for _, activePlate in pairs(plates) do activePlate:UpdateClassification() end
end
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
        if plate.ApplyTarget then plate:ApplyTarget() end
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
ns.OVERLAY_STRIPE_KEYS = {
    ["striped-v2"] = true,
    ["striped-wide-v2"] = true,
    ["stripes-medium"] = true,
    ["stripes-small-close"] = true,
    ["stripes-small-spread"] = true,
    ["striped-tiny"] = true,
}

function ns.ResolveOverlayTexPath(key)
    if not key or key == "none" or key == "---" then return nil end
    -- Stripe keys resolve to a bundled texture under the addon Media directory.
    if ns.OVERLAY_STRIPE_KEYS[key] then
        return "Interface\\AddOns\\EllesmereUINameplates\\Media\\" .. key .. ".tga"
    end
    if EllesmereUI and EllesmereUI.ResolveTexturePath then
        return EllesmereUI.ResolveTexturePath(ns.healthBarTextures, key, WHITE)
    end
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
        local tex = EllesmereUI and EllesmereUI.ResolveTexturePath
            and EllesmereUI.ResolveTexturePath(ns.healthBarTextures, key, WHITE)
            or (key and ns.healthBarTextures[key]) or WHITE
        plate.health:SetStatusBarTexture(tex)
    end
end

function ns.ApplyCastBarTexture(plate)
    if plate and plate.cast and ns.healthBarTextures then
        local key = DB().castBarTexture or DB().healthBarTexture or
                    (ns.defaults and (ns.defaults.castBarTexture or ns.defaults.healthBarTexture))
        local tex = EllesmereUI and EllesmereUI.ResolveTexturePath
            and EllesmereUI.ResolveTexturePath(ns.healthBarTextures, key, WHITE)
            or (key and ns.healthBarTextures[key]) or WHITE
        plate.cast:SetStatusBarTexture(tex)
    end
end

-- Each native depth level receives a private range of child frame levels.
-- Without this expansion, a raised element at native base+21 can draw over a
-- closer plate whose root is only base+1. Keep every offset below the stride.
local PLATE_LEVEL_STRIDE = 32
local PLATE_LEVEL_ROOT = 1
local PLATE_LEVEL_GLOW = 3
local PLATE_LEVEL_BAR = 4
local PLATE_LEVEL_BORDER = 5
local PLATE_LEVEL_CONTENT = 6
local PLATE_LEVEL_AURA = 7
local PLATE_LEVEL_RAISED_AURA = 24

local function GetPlateDepthBase(plate)
    local nativeLevel = plate and plate.frame and plate.frame:GetFrameLevel() or 0
    local depthRank = plate and plate.depthRank
    return max(0, depthRank or nativeLevel or 0) * PLATE_LEVEL_STRIDE
end

-- Slot strata refresh – re-raise aura frames that need it inside the plate's
-- isolated depth band.
function ns.ApplySlotStrata(plate)
    if not plate then return end
    local db = DB()
    local base = plate.depthFrameLevel or GetPlateDepthBase(plate)
    local groups = {
        { slots = plate.debuffSlots, pos = db.debuffSlot or ns.defaults.debuffSlot },
        { slots = plate.buffs, pos = db.buffSlot or ns.defaults.buffSlot },
        { slots = plate.cc, pos = db.ccSlot or ns.defaults.ccSlot },
    }
    for _, group in ipairs(groups) do
        local level = base + (GetSlotRaiseStrata(group.pos)
            and PLATE_LEVEL_RAISED_AURA or PLATE_LEVEL_AURA)
        for _, slot in ipairs(group.slots or {}) do slot:SetFrameLevel(level) end
    end
end

-- SyncStrata – track the engine-driven native root level (WoW changes it by
-- 3-D depth) and expand it into an isolated band. The root itself is never
-- changed: it remains the authoritative depth signal for future updates.
function PlateMethods:SyncStrata()
    local nativeLevel = self.frame:GetFrameLevel() or 0
    local depthRank = self.depthRank
    local base = max(0, depthRank or nativeLevel) * PLATE_LEVEL_STRIDE
    local expectedBarLevel = base + PLATE_LEVEL_BAR
    local levelsIntact = self.health and self.health:GetFrameLevel() == expectedBarLevel
        and (not self.cast or self.cast:GetFrameLevel() == expectedBarLevel)
        and (not self.contentFrame
            or self.contentFrame:GetFrameLevel() == base + PLATE_LEVEL_ROOT)
        and (not self.overlayFrame
            or self.overlayFrame:GetFrameLevel() == base + PLATE_LEVEL_CONTENT)
        and (not self.targetGlowFrame
            or self.targetGlowFrame:GetFrameLevel() == base + PLATE_LEVEL_GLOW)
        and (not self.borderFrame
            or self.borderFrame:GetFrameLevel() == base + PLATE_LEVEL_BORDER)
        and (not self.castBorderFrame
            or self.castBorderFrame:GetFrameLevel() == base + PLATE_LEVEL_BORDER)
        and (not self.castIconFrame
            or self.castIconFrame:GetFrameLevel() == base + PLATE_LEVEL_CONTENT)
    if nativeLevel == self._lastNativeFrameLevel
        and depthRank == self._lastDepthRank and levelsIntact then return end

    self._lastNativeFrameLevel = nativeLevel
    self._lastDepthRank = depthRank
    self.depthFrameLevel = base

    if self.contentFrame then
        self.contentFrame:SetFrameLevel(base + PLATE_LEVEL_ROOT)
    end
    if self.overlayFrame then
        self.overlayFrame:SetFrameLevel(base + PLATE_LEVEL_CONTENT)
    end
    if self.health then self.health:SetFrameLevel(expectedBarLevel) end
    if self.cast then self.cast:SetFrameLevel(expectedBarLevel) end
    if self.targetGlowFrame then
        self.targetGlowFrame:SetFrameLevel(base + PLATE_LEVEL_GLOW)
    end
    if self.borderFrame then
        self.borderFrame:SetFrameLevel(base + PLATE_LEVEL_BORDER)
    end
    if self.castBorderFrame then
        self.castBorderFrame:SetFrameLevel(base + PLATE_LEVEL_BORDER)
    end
    if self.castIconFrame then
        self.castIconFrame:SetFrameLevel(base + PLATE_LEVEL_CONTENT)
    end

    if ns.ApplySlotStrata then ns.ApplySlotStrata(self) end
end

-- PositionAuraSlot – reanchor `count` icon slots to their position key.
-- Signature: (slots, maxCount, posKey, plate, sz, h, spacing, xOff, yOff)
do
    function ns.PositionAuraSlot(slots, count, posKey, plate, sz, h, spacing, xOff, yOff)
        if not slots or not plate or not plate.health then return end
        if posKey == "none" or not posKey then
            for i = 1, count do if slots[i] then slots[i]:Hide() end end
            return
        end
        xOff, yOff = xOff or 0, yOff or 0
        spacing = spacing or 2
        local stepX, stepY = sz + spacing, h + spacing
        local bottomAnchor = plate.cast or plate.health
        for i = 1, count do
            local slot = slots[i]
            if not slot then break end
            slot:SetSize(sz, h)
            slot:ClearAllPoints()
            if posKey == "left" then
                slot:SetPoint("RIGHT", plate.health, "LEFT", -GetSideAuraXOffset() - (i - 1) * stepX + xOff, yOff)
            elseif posKey == "right" then
                slot:SetPoint("LEFT", plate.health, "RIGHT", GetSideAuraXOffset() + (i - 1) * stepX + xOff, yOff)
            elseif posKey == "bottom" then
                slot:SetPoint("TOP", bottomAnchor, "BOTTOM", (i - (count + 1) / 2) * stepX + xOff, -2 + yOff)
            elseif posKey == "topleft" then
                local growth = DB().topleftSlotGrowth or "left"
                local dx, dy = -(i - 1) * stepX, 0
                if growth == "right" then dx = (i - 1) * stepX end
                if growth == "up" then dx, dy = 0, (i - 1) * stepY end
                slot:SetPoint("BOTTOMLEFT", plate.health, "TOPLEFT", xOff + dx, GetDebuffYOffset() + yOff + dy)
            elseif posKey == "topright" then
                local growth = DB().toprightSlotGrowth or "right"
                local dx, dy = (i - 1) * stepX, 0
                if growth == "left" then dx = -(i - 1) * stepX end
                if growth == "up" then dx, dy = 0, (i - 1) * stepY end
                slot:SetPoint("BOTTOMRIGHT", plate.health, "TOPRIGHT", xOff + dx, GetDebuffYOffset() + yOff + dy)
            else
                slot:SetPoint("BOTTOM", plate.health, "TOP", (i - (count + 1) / 2) * stepX + xOff, GetDebuffYOffset() + yOff)
            end
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
