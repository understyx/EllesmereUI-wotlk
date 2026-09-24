-------------------------------------------------------------------------------
--  EUI_SwingBars_Options.lua
--  Native EllesmereUI settings page for the Swingbars subaddon.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local PAGE_SWINGBARS = "Swingbars"

local initFrame = EllesmereUI.SafeCreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not EllesmereUI or not EllesmereUI.RegisterModule then return end

    local function P()
        return ns.GetProfile and ns.GetProfile()
    end

    local function Disabled()
        local p = P()
        return not p or not p.enabled
    end

    local function Apply()
        if ns.Apply then ns.Apply() end
    end

    local function ColorGetter(key)
        return function()
            local c = P()[key]
            return c.r, c.g, c.b, c.a or 1
        end
    end

    local function ColorSetter(key)
        return function(r, g, b, a)
            P()[key] = { r = r, g = g, b = b, a = a or 1 }
            Apply()
        end
    end

    local function BuildSwingbarsPage(_, parent, yOffset)
        local W = EllesmereUI.Widgets
        local y = yOffset
        local _, h
        parent._showRowDivider = true

        _, h = W:Spacer(parent, y, 20); y = y - h
        _, h = W:SectionHeader(parent, "GENERAL", y); y = y - h

        _, h = W:DualRow(parent, y,
            { type = "toggle", text = "Enable Swingbars",
              tooltip = "Shows weapon swing timers for main-hand and off-hand attacks, plus Auto Shot for Hunters.",
              getValue = function() return P().enabled end,
              setValue = EllesmereUI.DependentSetValue(
                  function() return P().enabled end,
                  function(v)
                      P().enabled = v and true or false
                      Apply()
                      EllesmereUI:RefreshPage()
                  end) },
            { type = "button", text = "Test Swingbars", width = 180,
              disabled = Disabled, disabledTooltip = "Swingbars",
              onClick = function() if ns.Preview then ns.Preview() end end }
        ); y = y - h

        local _, playerClass = UnitClass("player")
        if playerClass == "HUNTER" then
            _, h = W:DualRow(parent, y,
                { type = "toggle", text = "Hunter: Do Not Reset Ranged Swing on Melee Attacks",
                  tooltip = "Keeps melee attacks from restarting the ranged swing timer. Enabled by default for Warmane; disable it on servers where melee and ranged attacks share a swing reset.",
                  disabled = Disabled, disabledTooltip = "Swingbars",
                  getValue = function() return P().hunterMeleeDoesNotResetRanged end,
                  setValue = function(v)
                      P().hunterMeleeDoesNotResetRanged = v and true or false
                  end }
            ); y = y - h
        end

        _, h = W:DualRow(parent, y,
            { type = "slider", text = "Bar Width", min = 50, max = 500, step = 1,
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = function() return P().width end,
              setValue = function(v) P().width = v; Apply() end },
            { type = "slider", text = "Bar Height", min = 4, max = 40, step = 1,
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = function() return P().barHeight end,
              setValue = function(v) P().barHeight = v; Apply() end }
        ); y = y - h

        _, h = W:DualRow(parent, y,
            { type = "slider", text = "Bar Spacing", min = 0, max = 20, step = 1,
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = function() return P().barSpacing end,
              setValue = function(v) P().barSpacing = v; Apply() end },
            { type = "toggle", text = "Show Bar Labels",
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = function() return P().showLabels end,
              setValue = EllesmereUI.DependentSetValue(
                  function() return P().showLabels end,
                  function(v) P().showLabels = v and true or false; Apply(); EllesmereUI:RefreshPage() end) }
        ); y = y - h

        _, h = W:DualRow(parent, y,
            { type = "slider", text = "Label Font Size", min = 8, max = 24, step = 1,
              disabled = function() return Disabled() or not P().showLabels end,
              disabledTooltip = function() return Disabled() and "Swingbars" or "Show Bar Labels" end,
              getValue = function() return P().fontSize end,
              setValue = function(v) P().fontSize = v; Apply() end },
            { type = "toggle", text = "Show Border",
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = function() return P().showBorder end,
              setValue = function(v) P().showBorder = v and true or false; Apply(); EllesmereUI:RefreshPage() end }
        ); y = y - h

        _, h = W:Spacer(parent, y, 20); y = y - h
        _, h = W:SectionHeader(parent, "APPEARANCE", y); y = y - h

        local textureValues = ns.BAR_TEXTURE_NAMES
        textureValues._menuOpts = {
            itemHeight = 28,
            background = function(key) return ns.BAR_TEXTURES[key] end,
        }
        _, h = W:DualRow(parent, y,
            { type = "dropdown", text = "Bar Texture",
              values = textureValues, order = ns.BAR_TEXTURE_ORDER,
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = function() return P().barTexture end,
              setValue = function(v) P().barTexture = v; Apply() end },
            { type = "colorpicker", text = "Background Color", hasAlpha = true,
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = ColorGetter("backgroundColor"),
              setValue = ColorSetter("backgroundColor") }
        ); y = y - h

        _, h = W:DualRow(parent, y,
            { type = "colorpicker", text = "Main Hand Color", hasAlpha = true,
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = ColorGetter("mainHandColor"),
              setValue = ColorSetter("mainHandColor") },
            { type = "colorpicker", text = "Off Hand Color", hasAlpha = true,
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = ColorGetter("offHandColor"),
              setValue = ColorSetter("offHandColor") }
        ); y = y - h

        _, h = W:DualRow(parent, y,
            { type = "colorpicker", text = "Ranged Color", hasAlpha = true,
              disabled = Disabled, disabledTooltip = "Swingbars",
              getValue = ColorGetter("rangedColor"),
              setValue = ColorSetter("rangedColor") },
            { type = "colorpicker", text = "Border Color", hasAlpha = true,
              disabled = function() return Disabled() or not P().showBorder end,
              disabledTooltip = function() return Disabled() and "Swingbars" or "Show Border" end,
              getValue = ColorGetter("borderColor"),
              setValue = ColorSetter("borderColor") }
        ); y = y - h

        return math.abs(y)
    end

    EllesmereUI:RegisterModule(ADDON_NAME, {
        title = "Swingbars",
        description = "Weapon swing timers for melee attacks and ranged Auto Shot.",
        pages = { PAGE_SWINGBARS },
        searchTerms = {
            "swing", "swing timer", "weapon timer", "main hand", "off hand",
            "ranged", "auto shot", "attack speed", "melee", "hunter",
            "warmane", "ranged reset",
        },
        buildPage = BuildSwingbarsPage,
        onReset = function()
            if ns.Reset then ns.Reset() end
            EllesmereUI:InvalidatePageCache()
        end,
    })

    SLASH_ELLESMERESWINGBARS1 = "/esb"
    SLASH_ELLESMERESWINGBARS2 = "/swingbars"
    SlashCmdList.ELLESMERESWINGBARS = function()
        if InCombatLockdown and InCombatLockdown() then
            EllesmereUI.Print("|cffff6060[EllesmereUI]|r " .. EllesmereUI.L("Cannot open options during combat."))
            return
        end
        EllesmereUI:ShowModule(ADDON_NAME)
    end
end)
