-------------------------------------------------------------------------------
--  EUI_QoL_AutoLogging_Options.lua
--  Options page for the Auto Combat Logging feature.
-------------------------------------------------------------------------------

-- Must match TRIGGER_DEFAULTS in the runtime.
local TRIGGER_DEFAULTS = {
    logHeroic   = true,
    logNormal   = true,
    logArena    = true,
    delaystop   = true,
}

local TRIGGER_ITEMS = {
    { key = "logHeroic",   label = "Heroic Raid" },
    { key = "logNormal",   label = "Normal Raid" },
    { key = "logArena",    label = "Arena" },
}

local function Cfg()
    if not EllesmereUIDB then return {} end
    EllesmereUIDB.autoLogging = EllesmereUIDB.autoLogging or {}
    return EllesmereUIDB.autoLogging
end

local function Recheck()
    if _G._EUI_AutoLogging_Check then _G._EUI_AutoLogging_Check() end
end

-- Built as the tail of the Quality of Life page (chained from BuildQoLPage),
-- not as its own tab. Lays out from yOffset and returns the height used,
-- like every other section builder.
local function BuildAutoLoggingPage(pageName, parent, yOffset)
    local W  = EllesmereUI.Widgets
    local PP = EllesmereUI.PanelPP
    local y  = yOffset
    local _, h

    parent._showRowDivider = true


    ---------------------------------------------------------------------------
    --  AUTO COMBAT LOGGING
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "AUTO COMBAT LOGGING", y); y = y - h

    local trigRow, trigH = W:DualRow(parent, y,
        { type    = "toggle",
          text    = "Enable Auto Logging",
          tooltip = "Automatically starts and stops combat logging when entering or leaving a loggable instance.",
          getValue = function() return Cfg().enabled == true end,
          -- DependentSetValue: the Warcraft Recorder row below is hidden
          -- while auto logging is off; the flip forces the full rebuild.
          setValue = EllesmereUI.DependentSetValue(
              function() return Cfg().enabled == true end,
              function(v)
                  Cfg().enabled = v or nil
                  Recheck()
                  EllesmereUI:RefreshPage()
              end) },
        { type    = "dropdown", text = "Auto-Log Triggers",
          values  = { __placeholder = "..." }, order = { "__placeholder" },
          getValue = function() return "__placeholder" end,
          setValue = function() end }
    ); y = y - trigH

    -- Replace dummy dropdown with a checkbox dropdown.
    do
        local rightRgn = trigRow._rightRegion
        if rightRgn._control then rightRgn._control:Hide() end

        local cbDD, cbDDRefresh = EllesmereUI.BuildVisOptsCBDropdown(
            rightRgn,
            210,
            rightRgn:GetFrameLevel() + 2,
            TRIGGER_ITEMS,
            function(k)
                local v = Cfg()[k]
                if v == nil then return TRIGGER_DEFAULTS[k] end
                return v
            end,
            function(k, v) Cfg()[k] = v; Recheck() end
        )
        PP.Point(cbDD, "RIGHT", rightRgn, "RIGHT", -20, 0)
        rightRgn._control = cbDD
        rightRgn._lastInline = nil

        EllesmereUI.RegisterWidgetRefresh(cbDDRefresh)

        -- Gray + block the triggers dropdown (and its label) while Auto
        -- Logging is off; the CB dropdown has no native disabled handling.
        local function UpdateTrigDisabled()
            local off = Cfg().enabled ~= true
            cbDD:SetAlpha(off and 0.3 or 1)
            cbDD:EnableMouse(not off)
            if rightRgn._label then rightRgn._label:SetAlpha(off and 0.3 or 1) end
        end
        UpdateTrigDisabled()
        EllesmereUI.RegisterWidgetRefresh(UpdateTrigDisabled)
    end

    -- Warcraft Recorder row: HIDDEN entirely while Auto Logging is off.
    if Cfg().enabled == true then
    _, h = W:DualRow(parent, y,
        { type    = "toggle",
          text    = "Warcraft Recorder Compatibility",
          tooltip = "Delays stopping combat logging by 30 seconds after leaving an instance. Recommended for Warcraft Recorder compatibility.",
          getValue = function()
              local v = Cfg().delaystop
              if v == nil then return TRIGGER_DEFAULTS.delaystop end
              return v
          end,
          setValue = function(v)
              Cfg().delaystop = v
          end },
        { type = "label", text = "" }
    ); y = y - h
    end   -- close Auto Logging hidden-while-disabled gate

    _, h = W:Spacer(parent, y, 20); y = y - h

    ---------------------------------------------------------------------------
    --  BLOODLUST TRACKER
    ---------------------------------------------------------------------------
    if _G._EUI_BuildBloodlustSection then
        local lustH = _G._EUI_BuildBloodlustSection(parent, y, W, EllesmereUI.PP)
        y = y - lustH
    end

    return math.abs(y - yOffset)
end

_G._EUI_BuildAutoLoggingPage = BuildAutoLoggingPage
