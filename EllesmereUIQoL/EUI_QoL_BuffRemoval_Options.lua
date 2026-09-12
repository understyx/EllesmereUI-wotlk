-------------------------------------------------------------------------------
--  EUI_QoL_BuffRemoval_Options.lua
--  Options page for automatic player-buff removal and threat-transfer cleanup.
-------------------------------------------------------------------------------

local SEAL_IDS = { 21084, 20164, 20165, 20166, 20375, 31801, 53736 }

local function GetSetting(key, default)
    local value = EllesmereUIDB and EllesmereUIDB[key]
    if value == nil then return default == true end
    return value == true
end

local function SetSetting(key, value, apply)
    if not EllesmereUIDB then EllesmereUIDB = {} end
    EllesmereUIDB[key] = value and true or false
    if apply then apply() end
end

local function GetListSetting(key, itemKey)
    local list = EllesmereUIDB and EllesmereUIDB[key]
    return type(list) == "table" and list[itemKey] == true
end

local function SetListSetting(key, itemKey, value)
    if not EllesmereUIDB then EllesmereUIDB = {} end
    local list = EllesmereUIDB[key]
    if type(list) ~= "table" then
        list = {}
        EllesmereUIDB[key] = list
    end
    list[itemKey] = value and true or nil
    if next(list) == nil then EllesmereUIDB[key] = nil end
end

local function ApplyCancellationSettings()
    if EllesmereUI._applyBuffRemoval then EllesmereUI._applyBuffRemoval() end
    if EllesmereUI._applyThreatTransfer then EllesmereUI._applyThreatTransfer() end
end

local function SealItems()
    local items = {}
    for _, spellID in ipairs(SEAL_IDS) do
        local name, _, icon = GetSpellInfo(spellID)
        local label = name or tostring(spellID)
        if icon then label = "|T" .. icon .. ":18:18:0:0:64:64:4:60:4:60|t " .. label end
        items[#items + 1] = { key = tostring(spellID), label = label }
    end
    return items
end

local function BossItems()
    local items = {}
    for _, boss in ipairs(EllesmereUI.BuffRemovalBosses or {}) do
        items[#items + 1] = {
            key = boss.key,
            label = boss.label,
            isHeader = boss.isHeader,
        }
    end
    return items
end

local function InstallBlacklistDropdown(region, items, settingKey, searchable, maxVisible)
    if region._control then region._control:Hide() end
    local dropdown, refresh = EllesmereUI.BuildVisOptsCBDropdown(
        region, 220, region:GetFrameLevel() + 2, items,
        function(key) return GetListSetting(settingKey, key) end,
        function(key, value)
            SetListSetting(settingKey, key, value)
            if EllesmereUI._applyBuffRemoval then EllesmereUI._applyBuffRemoval() end
        end,
        nil, maxVisible, searchable, true)
    local PP = EllesmereUI.PanelPP
    PP.Point(dropdown, "RIGHT", region, "RIGHT", -20, 0)
    region._control = dropdown
    region._lastInline = nil
    EllesmereUI.RegisterWidgetRefresh(refresh)
end

local function BuildBuffRemovalPage(_, parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h
    parent._showRowDivider = true
    if EllesmereUI.ClearContentHeader then EllesmereUI:ClearContentHeader() end

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "WHEN TO CANCEL", y); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="In Party",
          tooltip="Allows automatic aura removal while you are in a party.",
          getValue=function() return GetSetting("auraCancelInParty", true) end,
          setValue=function(v) SetSetting("auraCancelInParty", v, ApplyCancellationSettings) end },
        { type="toggle", text="In Raid",
          tooltip="Allows automatic aura removal while you are in a raid group.",
          getValue=function() return GetSetting("auraCancelInRaid", true) end,
          setValue=function(v) SetSetting("auraCancelInRaid", v, ApplyCancellationSettings) end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Solo / Open World",
          tooltip="Allows automatic aura removal while you are not in a party or raid.",
          getValue=function() return GetSetting("auraCancelSoloOpenWorld", false) end,
          setValue=function(v) SetSetting("auraCancelSoloOpenWorld", v, ApplyCancellationSettings) end },
        { type="toggle", text="In Arenas",
          tooltip="Allows automatic aura removal in arenas. This takes precedence over the Party setting.",
          getValue=function() return GetSetting("auraCancelInArena", false) end,
          setValue=function(v) SetSetting("auraCancelInArena", v, ApplyCancellationSettings) end }
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "ALL CLASSES", y); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Cancel Divine Intervention",
          tooltip="Automatically removes Divine Intervention when it is applied to you in an enabled cancellation context.",
          getValue=function() return GetSetting("autoCancelDivineIntervention") end,
          setValue=function(v)
              SetSetting("autoCancelDivineIntervention", v, EllesmereUI._applyBuffRemoval)
          end },
        { type="toggle", text="Cancel Hand of Protection",
          tooltip="Automatically removes Hand of Protection when it is applied to you in an enabled cancellation context.",
          getValue=function() return GetSetting("autoCancelHandOfProtection") end,
          setValue=function(v)
              SetSetting("autoCancelHandOfProtection", v, EllesmereUI._applyBuffRemoval)
          end }
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "PALADIN", y); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Cancel Divine Sacrifice",
          tooltip="Automatically removes Divine Sacrifice after it activates, stopping the damage redirected to you while leaving Divine Guardian active.",
          getValue=function() return GetSetting("autoCancelDivineSacrifice") end,
          setValue=function(v)
              SetSetting("autoCancelDivineSacrifice", v, EllesmereUI._applyBuffRemoval)
          end },
        { type="toggle", text="Cancel Chaos Bane",
          tooltip="Automatically removes Shadowmourne's Chaos Bane buff so Soul Fragments can begin accumulating again. Selected seals and bosses can prevent its removal.",
          getValue=function() return GetSetting("autoCancelChaosBane") end,
          setValue=function(v)
              SetSetting("autoCancelChaosBane", v, EllesmereUI._applyBuffRemoval)
          end }
    ); y = y - h

    local blacklistRow
    blacklistRow, h = W:DualRow(parent, y,
        { type="dropdown", text="Chaos Bane: Seal Blacklist",
          tooltip="Chaos Bane is kept while any selected seal is active.",
          noCapture=true,
          values={ _placeholder="..." }, order={ "_placeholder" },
          getValue=function() return "_placeholder" end, setValue=function() end },
        { type="dropdown", text="Chaos Bane: Boss Blacklist",
          tooltip="Chaos Bane is kept while a selected Icecrown Citadel or Ruby Sanctum boss is detected.",
          noCapture=true,
          values={ _placeholder="..." }, order={ "_placeholder" },
          getValue=function() return "_placeholder" end, setValue=function() end }
    ); y = y - h

    InstallBlacklistDropdown(blacklistRow._leftRegion, SealItems(), "chaosBaneSealBlacklist", false, 8)
    InstallBlacklistDropdown(blacklistRow._rightRegion, BossItems(), "chaosBaneBossBlacklist", true, 9)

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "ROGUE", y); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Cancel Tricks on Non-Tanks",
          tooltip="After Tricks of the Trade activates, automatically removes only your threat-transfer aura when the recipient is detected as a healer or DPS. Tank, pet, and unknown recipients keep the transfer.",
          getValue=function() return GetSetting("autoCancelTricksThreat") end,
          setValue=function(v)
              SetSetting("autoCancelTricksThreat", v, EllesmereUI._applyThreatTransfer)
          end }
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h
    _, h = W:SectionHeader(parent, "HUNTER", y); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Cancel Misdirection on Non-Tanks",
          tooltip="After Misdirection activates, automatically removes its threat-transfer aura when the recipient is detected as a healer or DPS. Tank, pet, and unknown recipients keep the transfer.",
          getValue=function() return GetSetting("autoCancelMisdirectionThreat") end,
          setValue=function(v)
              SetSetting("autoCancelMisdirectionThreat", v, EllesmereUI._applyThreatTransfer)
          end }
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h
    return math.abs(y - yOffset)
end

_G._EUI_BuildBuffRemovalPage = BuildBuffRemovalPage
