-------------------------------------------------------------------------------
--  EUI_QoL_PaladinAuras_Options.lua
--  Options page for the Paladin Auras group overview.
-------------------------------------------------------------------------------

local AURA_IDS = { "48942", "54043", "19746", "48943", "48945", "48947", "32223" }

local function P()
    local fn = _G._EUI_PaladinAuras_DB
    local db = fn and fn()
    return db and db.profile and db.profile.paladinAuras
end

local function Cfg(key, fallback)
    local p = P()
    if not p or p[key] == nil then return fallback end
    return p[key]
end

local function Set(key, value)
    local p = P()
    if p then p[key] = value end
end

local function Refresh()
    if _G._EUI_PaladinAuras_Apply then _G._EUI_PaladinAuras_Apply() end
end

local function SetGrowth(value)
    if _G._EUI_PaladinAuras_SetGrowth then
        _G._EUI_PaladinAuras_SetGrowth(value)
    else
        Set("growDirection", value)
        Refresh()
    end
end

local function AuraValues()
    local values = {}
    for _, key in ipairs(AURA_IDS) do
        local spellID = tonumber(key)
        local name, _, icon = GetSpellInfo(spellID)
        values[key] = icon and ("|T" .. icon .. ":18:18:0:0:64:64:4:60:4:60|t " .. (name or key))
            or (name or key)
    end
    return values
end

local function NormalizeOrder()
    local p = P()
    if not p then return AURA_IDS end
    if type(p.order) ~= "table" then p.order = {} end
    local valid, seen, result = {}, {}, {}
    for _, key in ipairs(AURA_IDS) do valid[key] = true end
    for _, raw in ipairs(p.order) do
        local key = tostring(raw)
        if valid[key] and not seen[key] then
            seen[key] = true
            result[#result + 1] = key
        end
    end
    for _, key in ipairs(AURA_IDS) do
        if not seen[key] then result[#result + 1] = key end
    end
    p.order = result
    return result
end

local function SetOrderSlot(index, newKey)
    local order = NormalizeOrder()
    newKey = tostring(newKey)
    local otherIndex
    for i, key in ipairs(order) do
        if key == newKey then otherIndex = i; break end
    end
    if otherIndex and otherIndex ~= index then
        order[index], order[otherIndex] = order[otherIndex], order[index]
    else
        order[index] = newKey
    end
    Refresh()
    EllesmereUI:RefreshPage()
end

local function BuildPaladinAurasPage(_, parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h
    parent._showRowDivider = true
    if EllesmereUI.ClearContentHeader then EllesmereUI:ClearContentHeader() end

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "PALADIN AURAS", y); y = y - h

    local function Off() return not Cfg("enabled", false) end

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Enable Paladin Auras",
          tooltip="Shows which aura each Paladin in your party or raid is providing. Paladins sharing an aura are grouped into one row. Use Unlock Mode to reposition the display.",
          getValue=function() return Cfg("enabled", false) end,
          setValue=function(v) Set("enabled", v); Refresh(); EllesmereUI:RefreshPage() end },
        { type="toggle", text="Show Empty Auras",
          tooltip="Keeps all seven aura icons visible and dims any aura that no Paladin is currently providing.",
          disabled=Off, disabledTooltip="Enable Paladin Auras",
          getValue=function() return Cfg("showEmpty", false) end,
          setValue=function(v) Set("showEmpty", v); Refresh() end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="slider", text="Icon Size",
          disabled=Off, disabledTooltip="Enable Paladin Auras",
          min=16, max=64, step=1, isPercent=false,
          getValue=function() return Cfg("iconSize", 27) end,
          setValue=function(v) Set("iconSize", v); Refresh() end },
        { type="slider", text="Name Size",
          disabled=Off, disabledTooltip="Enable Paladin Auras",
          min=8, max=30, step=1, isPercent=false,
          getValue=function() return Cfg("textSize", 15) end,
          setValue=function(v) Set("textSize", v); Refresh() end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="slider", text="Icon Zoom (%)",
          disabled=Off, disabledTooltip="Enable Paladin Auras",
          min=0, max=45, step=1, isPercent=false,
          getValue=function() return Cfg("iconZoom", 30) end,
          setValue=function(v) Set("iconZoom", v); Refresh() end },
        { type="slider", text="Row Spacing",
          disabled=Off, disabledTooltip="Enable Paladin Auras",
          min=0, max=20, step=1, isPercent=false,
          getValue=function() return Cfg("spacing", 2) end,
          setValue=function(v) Set("spacing", v); Refresh() end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Class Colored Names",
          tooltip="Colors Paladin names with the Paladin class color.",
          disabled=Off, disabledTooltip="Enable Paladin Auras",
          getValue=function() return Cfg("classColor", false) end,
          setValue=function(v) Set("classColor", v); Refresh() end },
        { type="dropdown", text="Growth Direction",
          tooltip="Chooses whether additional aura rows are added above or below the first row.",
          disabled=Off, disabledTooltip="Enable Paladin Auras",
          values={ UP="Up", DOWN="Down" }, order={ "UP", "DOWN" },
          getValue=function() return Cfg("growDirection", "UP") end,
          setValue=SetGrowth }
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "AURA ORDER", y); y = y - h

    local values = AuraValues()
    NormalizeOrder()
    local function OrderDropdown(index)
        return {
            type="dropdown", text="Position " .. index,
            disabled=Off, disabledTooltip="Enable Paladin Auras",
            values=values, order=AURA_IDS,
            getValue=function() return NormalizeOrder()[index] end,
            setValue=function(v) SetOrderSlot(index, v) end,
        }
    end
    for rowIndex = 1, 4 do
        local leftIndex = (rowIndex - 1) * 2 + 1
        local rightIndex = leftIndex + 1
        local left = OrderDropdown(leftIndex)
        local right = rightIndex <= #AURA_IDS and OrderDropdown(rightIndex)
            or { type="label", text="" }
        _, h = W:DualRow(parent, y, left, right); y = y - h
    end

    _, h = W:Spacer(parent, y, 20); y = y - h
    return math.abs(y - yOffset)
end

_G._EUI_BuildPaladinAurasPage = BuildPaladinAurasPage
