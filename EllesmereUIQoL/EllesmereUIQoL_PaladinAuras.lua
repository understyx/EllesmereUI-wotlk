-------------------------------------------------------------------------------
--  EllesmereUIQoL_PaladinAuras.lua
--  Compact group-aura overview based on Merfin's Paladin Auras WeakAura.
--  One row is shown for each aura currently supplied by a Paladin, with all
--  providers listed beside it. Empty aura rows may optionally remain visible.
-------------------------------------------------------------------------------

local UNLOCK_KEY = "EUI_PaladinAuras"
local AURA_IDS = { 48942, 54043, 19746, 48943, 48945, 48947, 32223 }

local defaults = {
    profile = {
        paladinAuras = {
            enabled    = false,
            showEmpty  = false,
            classColor = false,
            iconSize   = 27,
            iconZoom   = 30,
            textSize   = 15,
            spacing    = 2,
            growDirection = "UP",
            order      = { "48942", "54043", "19746", "48943", "48945", "48947", "32223" },
            pos        = nil,
        },
    },
}

local addon = { db = nil }
local function P()
    return addon.db and addon.db.profile and addon.db.profile.paladinAuras
end

local auraDefs = {}
local auraByName = {}
local frame
local rows = {}
local paladinUnits = {}

local function GrowthDirection(p)
    return p and p.growDirection == "DOWN" and "DOWN" or "UP"
end

local function SetGrowEdge(pos, grow, width, height)
    if not pos or pos.point ~= "CENTER" or (pos.relPoint or pos.point) ~= "CENTER" then return end
    width = width or (frame and frame:GetWidth()) or 180
    height = height or (frame and frame:GetHeight()) or 27
    pos.growEdge = {
        anchor = grow == "DOWN" and "TOPLEFT" or "BOTTOMLEFT",
        x = (pos.x or 0) - width / 2,
        y = (pos.y or 0) + (grow == "DOWN" and height / 2 or -height / 2),
    }
end

local function LiveCenterPosition()
    if not (frame and frame:GetLeft() and frame:GetRight()
        and frame:GetTop() and frame:GetBottom()) then return nil end
    local uiScale = UIParent:GetEffectiveScale()
    local ratio = frame:GetEffectiveScale() / uiScale
    local cx = (frame:GetLeft() + frame:GetRight()) * ratio / 2 - UIParent:GetWidth() / 2
    local cy = (frame:GetTop() + frame:GetBottom()) * ratio / 2 - UIParent:GetHeight() / 2
    return cx, cy
end

local function NormalizeOrder(p)
    local order = p and p.order
    if type(order) ~= "table" then
        order = {}
        p.order = order
    end

    local valid, seen, normalized = {}, {}, {}
    for _, spellID in ipairs(AURA_IDS) do valid[tostring(spellID)] = true end
    for _, key in ipairs(order) do
        key = tostring(key)
        if valid[key] and not seen[key] then
            seen[key] = true
            normalized[#normalized + 1] = key
        end
    end
    for _, spellID in ipairs(AURA_IDS) do
        local key = tostring(spellID)
        if not seen[key] then normalized[#normalized + 1] = key end
    end
    p.order = normalized
    return normalized
end

local function CacheAuraInfo()
    wipe(auraDefs)
    wipe(auraByName)
    for _, spellID in ipairs(AURA_IDS) do
        local name, _, icon = GetSpellInfo(spellID)
        local def = { id = spellID, name = name or tostring(spellID), icon = icon }
        auraDefs[spellID] = def
        if name then auraByName[name] = spellID end
    end
end

local function SetBorderColor(border, r, g, b, a)
    if border and border.SetColor then border:SetColor(r, g, b, a or 1) end
end

local function CreateRow(parent, index)
    local row = EllesmereUI.SafeCreateFrame("Frame", nil, parent)
    row:SetFrameLevel(parent:GetFrameLevel() + 1)

    local iconFrame = EllesmereUI.SafeCreateFrame("Frame", nil, row)
    iconFrame:SetPoint("LEFT", row, "LEFT", 0, 0)
    iconFrame:SetFrameLevel(row:GetFrameLevel() + 1)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if icon.SetSnapToPixelGrid then
        icon:SetSnapToPixelGrid(false)
        icon:SetTexelSnappingBias(0)
    end

    local border = EllesmereUI.MakeBorder(iconFrame, 0, 0, 0, 1)

    local names = row:CreateFontString(nil, "OVERLAY")
    names:SetPoint("LEFT", iconFrame, "RIGHT", 5, 0)
    names:SetJustifyH("LEFT")
    names:SetWordWrap(false)
    names:SetTextColor(1, 1, 1, 1)

    row.iconFrame = iconFrame
    row.icon = icon
    row.border = border
    row.names = names
    row.index = index
    rows[index] = row
    return row
end

local function ApplyPosition()
    if not frame then return end
    local anchor = EllesmereUIDB and EllesmereUIDB.unlockAnchors
        and EllesmereUIDB.unlockAnchors[UNLOCK_KEY]
    if anchor and anchor.target and EllesmereUI.ReapplyOwnAnchor then
        EllesmereUI.ReapplyOwnAnchor(UNLOCK_KEY)
        if frame:GetNumPoints() > 0 then return end
    end

    local p = P()
    local pos = p and p.pos
    frame:ClearAllPoints()
    if pos and pos.point then
        if pos.point == "CENTER" and (pos.relPoint or pos.point) == "CENTER" then
            if not pos.growEdge then
                SetGrowEdge(pos, GrowthDirection(p))
            end
            local edge = pos.growEdge
            frame:SetPoint(edge.anchor or "BOTTOMLEFT", UIParent, "CENTER",
                edge.x or pos.x or 0, edge.y or pos.y or 0)
        else
            frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        end
    else
        if GrowthDirection(p) == "DOWN" then
            frame:SetPoint("TOPLEFT", UIParent, "CENTER", 240, -14 + ((p and p.iconSize) or 27))
        else
            frame:SetPoint("BOTTOMLEFT", UIParent, "CENTER", 240, -14)
        end
    end
end

local function EnsureFrame()
    if frame then return frame end
    frame = EllesmereUI.SafeCreateFrame("Frame", "EUI_PaladinAurasFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetSize(180, 27)
    frame:Hide()
    ApplyPosition()
    return frame
end

local function GroupUnits()
    local units = {}
    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raidCount > 0 then
        for i = 1, raidCount do units[#units + 1] = "raid" .. i end
        return units
    end

    units[#units + 1] = "player"
    local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, partyCount do units[#units + 1] = "party" .. i end
    return units
end

local function PaladinAuraForUnit(unit)
    local unitGUID = UnitGUID(unit)
    local unitName = UnitName(unit)
    if not unitGUID or not unitName or unitName == UNKNOWNOBJECT then return nil end

    for index = 1, 40 do
        local name, _, _, _, _, _, _, caster, _, _, spellID = UnitBuff(unit, index)
        if not name then break end
        local canonicalID = auraByName[name]
        if not canonicalID and spellID and auraDefs[spellID] then canonicalID = spellID end
        if canonicalID and caster then
            local casterGUID = UnitExists(caster) and UnitGUID(caster)
            local casterName = UnitExists(caster) and UnitName(caster)
            if caster == unit or casterGUID == unitGUID or casterName == unitName then
                return canonicalID
            end
        end
    end
end

local function CollectAuras()
    local state = {}
    wipe(paladinUnits)
    for _, unit in ipairs(GroupUnits()) do
        local _, class = UnitClass(unit)
        if class == "PALADIN" then
            paladinUnits[unit] = true
            local spellID = PaladinAuraForUnit(unit)
            if spellID then
                local bucket = state[spellID]
                if not bucket then
                    bucket = { names = {}, player = false }
                    state[spellID] = bucket
                end
                local name = UnitName(unit)
                if name and name ~= UNKNOWNOBJECT then bucket.names[#bucket.names + 1] = name end
                if UnitIsUnit and UnitIsUnit(unit, "player") then bucket.player = true end
            end
        end
    end
    for _, bucket in pairs(state) do table.sort(bucket.names) end
    return state
end

local function PaladinNameColor(text, enabled)
    if not enabled or text == "" then return text end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
    local hex = c and c.colorStr or "fff58cba"
    if #hex == 6 then hex = "ff" .. hex end
    return "|c" .. hex .. text .. "|r"
end

local function Refresh()
    EnsureFrame()
    local p = P()
    if not p or not p.enabled then
        frame:Hide()
        return
    end

    local state = CollectAuras()
    local display = {}
    for _, key in ipairs(NormalizeOrder(p)) do
        local spellID = tonumber(key)
        if p.showEmpty or state[spellID] then display[#display + 1] = spellID end
    end

    local iconSize = math.max(12, tonumber(p.iconSize) or 27)
    local textSize = math.max(8, tonumber(p.textSize) or 15)
    local spacing = math.max(0, tonumber(p.spacing) or 2)
    local zoom = math.max(0, math.min(45, tonumber(p.iconZoom) or 30)) / 100
    local font = (EllesmereUI.GetFontPath and EllesmereUI.GetFontPath("extras")) or STANDARD_TEXT_FONT
    local outline = (EllesmereUI.SlugFlag and EllesmereUI.SlugFlag("OUTLINE, SLUG")) or "OUTLINE"
    local maxWidth = iconSize
    local grow = GrowthDirection(p)

    for i, spellID in ipairs(display) do
        local row = rows[i] or CreateRow(frame, i)
        local def = auraDefs[spellID]
        local bucket = state[spellID]
        local nameText = bucket and table.concat(bucket.names, ", ") or ""

        row:SetSize(iconSize, iconSize)
        row:ClearAllPoints()
        if grow == "DOWN" then
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * (iconSize + spacing))
        else
            row:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, (i - 1) * (iconSize + spacing))
        end
        row.iconFrame:SetSize(iconSize, iconSize)
        row.icon:SetTexture(def and def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        row.names:SetFont(font, textSize, outline)
        row.names:SetText(PaladinNameColor(nameText, p.classColor))

        if bucket then
            row.icon:SetVertexColor(1, 1, 1, 1)
            if bucket.player then SetBorderColor(row.border, 1, 1, 0, 1)
            else SetBorderColor(row.border, 0, 0, 0, 1) end
        else
            row.icon:SetVertexColor(0.4, 0.4, 0.4, 1)
            SetBorderColor(row.border, 0, 0, 0, 1)
        end

        row:Show()
        maxWidth = math.max(maxWidth, iconSize + 5 + (row.names:GetStringWidth() or 0))
    end
    for i = #display + 1, #rows do rows[i]:Hide() end

    if #display == 0 then
        frame:SetSize(math.max(180, iconSize + 5), iconSize)
        frame:Hide()
        return
    end

    local oldW, oldH = frame:GetWidth(), frame:GetHeight()
    frame:SetSize(math.max(iconSize, math.ceil(maxWidth)),
        #display * iconSize + (#display - 1) * spacing)
    frame:Show()
    if (oldW ~= frame:GetWidth() or oldH ~= frame:GetHeight())
        and EllesmereUI.NotifyElementResized then
        EllesmereUI.NotifyElementResized(UNLOCK_KEY)
    end
end

local eventFrame = EllesmereUI.SafeCreateFrame("Frame")
local function Apply()
    local p = P()
    eventFrame:UnregisterAllEvents()
    if p and p.enabled then
        eventFrame:RegisterEvent("UNIT_AURA")
        eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
        eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    Refresh()
    ApplyPosition()
end

local function RegisterUnlock()
    if not (EllesmereUI and EllesmereUI.RegisterUnlockElements and EllesmereUI.MakeUnlockElement) then return end
    local MK = EllesmereUI.MakeUnlockElement
    EllesmereUI:RegisterUnlockElements({
        MK({
            key = UNLOCK_KEY,
            label = "Paladin Auras",
            group = "Quality of Life",
            order = 735,
            noResize = true,
            noSizeMatchTarget = true,
            getGrowDirection = function() return GrowthDirection(P()) end,
            isHidden = function()
                local p = P()
                return not p or not p.enabled
            end,
            getFrame = function() return EnsureFrame() end,
            getSize = function()
                local p = P()
                local size = p and p.iconSize or 27
                return frame and frame:GetWidth() or 180, frame and frame:GetHeight() or size
            end,
            savePos = function(_, point, relPoint, x, y)
                local p = P()
                if not p or not point then return end
                p.pos = { point = point, relPoint = relPoint, x = x, y = y }
                SetGrowEdge(p.pos, GrowthDirection(p))
                if not EllesmereUI._unlockActive then ApplyPosition() end
            end,
            loadPos = function()
                local p = P()
                return p and p.pos or nil
            end,
            clearPos = function()
                local p = P()
                if p then p.pos = nil end
                ApplyPosition()
            end,
            applyPos = ApplyPosition,
        }),
    }, "EllesmereUIQoL")
end

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event ~= "UNIT_AURA" or paladinUnits[unit] then Refresh() end
end)

_G._EUI_PaladinAuras_DB = function() return addon.db end
_G._EUI_PaladinAuras_Apply = Apply
_G._EUI_PaladinAuras_Refresh = Refresh
_G._EUI_PaladinAuras_SetGrowth = function(value)
    local p = P()
    if not p then return end
    value = value == "DOWN" and "DOWN" or "UP"
    if GrowthDirection(p) == value then return end

    -- Rebase from the live center so changing direction does not jump the
    -- display. Future row-count changes then keep the new starting edge fixed.
    EnsureFrame()
    local cx, cy = LiveCenterPosition()
    p.growDirection = value
    if cx and cy then
        p.pos = { point = "CENTER", relPoint = "CENTER", x = cx, y = cy }
    end
    Refresh()
    if p.pos then SetGrowEdge(p.pos, value) end
    ApplyPosition()
end
_G._EUI_PaladinAuras_Reset = function()
    local p = P()
    if not p then return end
    wipe(p)
    for key, value in pairs(defaults.profile.paladinAuras) do
        p[key] = type(value) == "table" and EllesmereUI.Lite.DeepCopy(value) or value
    end
    if EllesmereUIDB and EllesmereUIDB.unlockAnchors then
        EllesmereUIDB.unlockAnchors[UNLOCK_KEY] = nil
    end
    Apply()
end

local boot = EllesmereUI.SafeCreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not (EllesmereUI and EllesmereUI.Lite and EllesmereUI.Lite.NewDB) then return end
    addon.db = EllesmereUI.Lite.NewDB("EllesmereUIQoLDB", defaults, true)
    CacheAuraInfo()
    EnsureFrame()
    Apply()
    RegisterUnlock()
end)
