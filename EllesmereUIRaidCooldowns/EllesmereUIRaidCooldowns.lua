-------------------------------------------------------------------------------
-- EllesmereUIRaidCooldowns.lua
-- Event-driven raid cooldown tracking with dynamic, unlock-mode-aware groups.
-------------------------------------------------------------------------------

local ADDON_FOLDER = ...
local EUI = EllesmereUI
if not EUI or not EUI.Lite then return end

-- NewAddon supplies the zero-cost fallback when CDM is disabled. When CDM is
-- present, Raid Cooldowns deliberately joins its shared event fan-out so the
-- two systems do not duplicate native registrations.
local RCD = EUI.Lite.NewAddon("EllesmereUIRaidCooldowns")
EUI.RaidCooldowns = RCD

local Catalog = EUI.RaidCooldownCatalog
local LGT = LibStub and LibStub:GetLibrary("LibGroupTalents-1.0", true)
local PREFIX = "EUIRCD1"
local ROW_GAP, HEADER_H, MIN_WIDTH = 1, 22, 150
local GROUP_KEY_PREFIX = "ERCD_Group_"

local defaults = {
    profile = {
        enabled = false,
        nextGroupID = 1,
        groupOrder = {},
        groups = {},
        interactions = {
            LeftButton = "none",
            ShiftLeftButton = "announce",
            AltLeftButton = "request",
            CtrlLeftButton = "none",
            RightButton = "none",
        },
        announceTemplate = "%playerName - %spellLink - %state%target",
        requestTemplate = "Please use %spellName on me",
        notificationDuration = 5,
        savedState = {},
    },
}

RCD.db = nil
RCD.roster = {}
RCD.state = {}
RCD.groupFrames = {}
RCD.rowPool = {}
RCD.eventsActive = false
RCD.usingSharedEvents = false
RCD.preview = false
RCD.restored = false

local classSpecIDs = {
    WARRIOR = { 71, 72, 73 }, PALADIN = { 65, 66, 70 },
    HUNTER = { 253, 254, 255 }, ROGUE = { 259, 260, 261 },
    PRIEST = { 256, 257, 258 }, DEATHKNIGHT = { 250, 251, 252 },
    SHAMAN = { 262, 263, 264 }, MAGE = { 62, 63, 64 },
    WARLOCK = { 265, 266, 267 }, DRUID = { 102, 103, 105 },
}

local function DB()
    return RCD.db and RCD.db.profile
end
RCD.GetDB = DB

local function TableHasTrue(t)
    if not t then return false end
    for _, value in pairs(t) do if value then return true end end
    return false
end

local function FullName(unit)
    local name, realm = UnitName(unit)
    if not name then return nil end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function ShortName(name)
    return name and name:match("^[^-]+") or name
end

local function ForEachGroupUnit(fn)
    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raidCount > 0 then
        for i = 1, raidCount do fn("raid" .. i) end
        return
    end
    fn("player")
    local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, partyCount do fn("party" .. i) end
end

local function UnitRole(unit)
    local detector = EUI.RoleDetector
    local role = detector and detector:GetRole(unit)
    if role and role ~= "NONE" then return role end
    if LGT then
        local legacy = LGT:GetUnitRole(unit)
        if legacy == "tank" then return "TANK" end
        if legacy == "healer" then return "HEALER" end
        if legacy == "melee" or legacy == "caster" then return "DAMAGER" end
    end
    return "DAMAGER"
end

local function UnitSpecID(unit, class)
    if UnitIsUnit(unit, "player") and EUI.Spec then
        return EUI.Spec:GetCurrentID()
    end
    if not LGT then return nil end
    local _, p1, p2, p3 = LGT:GetUnitTalentSpec(unit)
    if not p1 and not p2 and not p3 then return nil end
    p1, p2, p3 = p1 or 0, p2 or 0, p3 or 0
    local index = 1
    if p2 > p1 and p2 > p3 then index = 2
    elseif p3 > p1 and p3 > p2 then index = 3 end
    local ids = classSpecIDs[class]
    return ids and ids[index] or nil
end

local function IsTalentKnown(unit)
    return UnitIsUnit(unit, "player") or (LGT and LGT:GetUnitTalents(unit) ~= nil)
end

local function HasTalent(unit, talent)
    if not talent then return true end
    if not LGT or not IsTalentKnown(unit) then return false end
    local _, _, _, _, points = LGT:GetTalentInfo(unit, talent[1], talent[2])
    return (points or 0) > 0
end

local function CooldownDuration(unit, def)
    local duration = def.duration or 0
    if LGT and unit then
        for _, reduction in ipairs(def.reductions or {}) do
            local _, _, _, _, points = LGT:GetTalentInfo(unit, reduction[1], reduction[2])
            duration = duration - (points or 0) * (reduction[3] or 0)
        end
    end
    return math.max(1, duration)
end

local function StateFor(guid)
    local state = RCD.state[guid]
    if not state then state = {}; RCD.state[guid] = state end
    return state
end

local function EquippedTrackedItem(unit, def)
    if not def.itemIDs then return false end
    for _, slot in ipairs({ 13, 14 }) do
        local itemID = GetInventoryItemID(unit, slot)
        for _, wanted in ipairs(def.itemIDs) do
            if itemID == wanted then return true end
        end
    end
    return false
end

local function SeedUnit(entry)
    if not entry or not Catalog then return end
    local now = GetTime()
    local state = StateFor(entry.guid)
    local classDefs = Catalog.byClass[entry.class]
    if classDefs then
        for spellID, def in pairs(classDefs) do
            local faction = UnitFactionGroup and UnitFactionGroup("player")
            local unavailableLust = (faction == "Horde" and spellID == 32182)
                or (faction == "Alliance" and spellID == 2825)
            local available = not unavailableLust and HasTalent(entry.unit, def.talent)
            if available and not state[spellID] then
                state[spellID] = { duration = CooldownDuration(entry.unit, def), expires = 0 }
            elseif (unavailableLust or def.talent) and not available
                and state[spellID] and (state[spellID].expires or 0) <= now then
                state[spellID] = nil
            end
        end
    end

    local itemDefs = Catalog.byClass.ITEMS
    if itemDefs then
        for spellID, def in pairs(itemDefs) do
            if EquippedTrackedItem(entry.unit, def) then
                if not state[spellID] then
                    state[spellID] = { duration = def.duration, expires = 0, isItem = true }
                end
            elseif state[spellID] and (state[spellID].expires or 0) <= now then
                state[spellID] = nil
            end
        end
    end
end

local function RestoreState()
    if RCD.restored then return end
    RCD.restored = true
    local db = DB()
    local saved = db and db.savedState
    if not saved then return end
    local wallNow, now = time(), GetTime()
    for guid, unitSaved in pairs(saved) do
        if RCD.roster[guid] then
            local state = StateFor(guid)
            for savedSpellID, info in pairs(unitSaved) do
                local spellID = tonumber(savedSpellID)
                local def = spellID and Catalog:Get(spellID)
                local remaining = info.expiresAt and (info.expiresAt - wallNow) or 0
                if def and remaining > 0 then
                    state[def.spellID] = {
                        duration = info.duration or def.duration,
                        expires = now + remaining,
                        targetName = info.targetName,
                        targetClass = info.targetClass,
                        isItem = def.class == "ITEMS",
                    }
                end
            end
        end
    end
end

function RCD:SaveState()
    local db = DB()
    if not db then return end
    local now, wallNow, saved = GetTime(), time(), {}
    for guid, spells in pairs(self.state) do
        local unitSaved = {}
        for spellID, info in pairs(spells) do
            local remaining = (info.expires or 0) - now
            if remaining > 0 then
                unitSaved[spellID] = {
                    duration = info.duration,
                    expiresAt = wallNow + remaining,
                    targetName = info.targetName,
                    targetClass = info.targetClass,
                }
            end
        end
        if next(unitSaved) then saved[guid] = unitSaved end
    end
    db.savedState = saved
end

function RCD:RefreshRoster()
    local seen = {}
    ForEachGroupUnit(function(unit)
        if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
        local guid = UnitGUID(unit)
        local _, class = UnitClass(unit)
        if not guid or not class then return end
        seen[guid] = true
        local entry = self.roster[guid] or {}
        entry.guid = guid
        entry.unit = unit
        entry.name = FullName(unit)
        entry.class = class
        entry.role = UnitRole(unit)
        entry.specID = UnitSpecID(unit, class)
        self.roster[guid] = entry
        SeedUnit(entry)
    end)
    for guid in pairs(self.roster) do
        if not seen[guid] then
            self.roster[guid] = nil
            self.state[guid] = nil
        end
    end
    RestoreState()
    self:RefreshAllGroups()
end

local function DefaultEnabledSpells()
    local enabled = {}
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for spellID in pairs(Catalog and Catalog.bySpellID or {}) do
        local unavailableLust = (faction == "Horde" and spellID == 32182)
            or (faction == "Alliance" and spellID == 2825)
        if not unavailableLust then enabled[spellID] = true end
    end
    return enabled
end

function RCD:CreateGroup(name)
    local db = DB()
    if not db then return nil end
    local id = tostring(db.nextGroupID or 1)
    db.nextGroupID = (db.nextGroupID or 1) + 1
    db.groups[id] = {
        id = id,
        name = (name and name ~= "") and name or ("Raid Cooldowns " .. id),
        enabled = true,
        showReady = true,
        showHeader = true,
        showIcon = true,
        showSpellName = true,
        colorBarByClass = false,
        width = 270,
        rowHeight = 26,
        spacing = 4,
        targetDisplay = "none",
        enabledSpells = DefaultEnabledSpells(),
        visibility = { classes = {}, specs = {}, roles = {} },
        memberFilter = { classes = {}, specs = {}, roles = {} },
        position = {
            point = "CENTER", relPoint = "CENTER", x = 0,
            y = -80 * #(db.groupOrder or {}),
        },
    }
    db.groupOrder[#db.groupOrder + 1] = id
    if db.enabled then
        self:CreateGroupFrame(id)
        self:RegisterGroupUnlock(id)
        self:RefreshAllGroups()
    end
    return id
end

function RCD:DeleteGroup(id)
    local db = DB()
    if not db or not db.groups[id] then return end
    db.groups[id] = nil
    for i = #db.groupOrder, 1, -1 do
        if db.groupOrder[i] == id then table.remove(db.groupOrder, i) end
    end
    self:DestroyGroupFrame(id)
    local key = GROUP_KEY_PREFIX .. id
    if EUI.UnregisterUnlockElement then EUI:UnregisterUnlockElement(key) end
    self:RefreshAllGroups()
end

local function LocalVisibilityMatches(group)
    local vis = group.visibility or {}
    local _, class = UnitClass("player")
    local spec = EUI.Spec and EUI.Spec:GetCurrent()
    local specID = spec and spec.id
    local role = spec and spec.role or UnitRole("player")
    if TableHasTrue(vis.classes) and not vis.classes[class] then return false end
    if TableHasTrue(vis.specs) and not vis.specs[specID] then return false end
    if TableHasTrue(vis.roles) and not vis.roles[role] then return false end
    return true
end

local function MemberMatches(group, entry)
    local filter = group.memberFilter or {}
    if TableHasTrue(filter.classes) and not filter.classes[entry.class] then return false end
    if TableHasTrue(filter.specs) and not filter.specs[entry.specID] then return false end
    if TableHasTrue(filter.roles) and not filter.roles[entry.role] then return false end
    return true
end

local function FormatTime(remaining)
    if remaining <= 0 then return "Ready" end
    if remaining < 10 then return string.format("%.1f", remaining) end
    if remaining < 60 then return string.format("%d", math.ceil(remaining)) end
    if remaining < 3600 then
        return string.format("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
    end
    return string.format("%dh %02dm", math.floor(remaining / 3600), math.floor((remaining % 3600) / 60))
end

local function SpellNameAndLink(spellID, isItem)
    local def = Catalog:Get(spellID)
    if isItem and def and def.itemIDs then
        local name, link = GetItemInfo(def.itemIDs[1])
        return name or (GetSpellInfo(spellID)) or tostring(spellID), link or name
    end
    local name = GetSpellInfo(spellID) or tostring(spellID)
    return name, GetSpellLink(spellID) or name
end

local function SpellIcon(spellID, isItem)
    local def = Catalog:Get(spellID)
    if isItem and def and def.itemIDs then
        local icon = select(10, GetItemInfo(def.itemIDs[1]))
        if icon then return icon end
    end
    return select(3, GetSpellInfo(spellID))
end

local function FormatMessage(template, data, request)
    local spellName, spellLink = SpellNameAndLink(data.spellID, data.isItem)
    local target = data.targetName and (" - Last Target: " .. ShortName(data.targetName)) or ""
    local state = data.remaining > 0 and ("On Cooldown: " .. FormatTime(data.remaining)) or "Ready"
    local msg = template or ""
    local function Replace(pattern, value)
        msg = msg:gsub(pattern, function() return value end)
    end
    Replace("%%playerName", ShortName(data.name) or "Unknown")
    Replace("%%spellName", spellName or "Unknown")
    Replace("%%spellLink", spellLink or spellName or "Unknown")
    Replace("%%targetName", ShortName(data.targetName) or "")
    Replace("%%timeLeft", FormatTime(data.remaining))
    Replace("%%state", state)
    Replace("%%target", target)
    if request then return msg end
    return msg
end

local function SendAddon(prefix, message, channel, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(prefix, message, channel, target)
    elseif SendAddonMessage then
        SendAddonMessage(prefix, message, channel, target)
    end
end

local function GroupChannel()
    if (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 then return "RAID" end
    if (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0 then return "PARTY" end
    return "SAY"
end

function RCD:RunInteraction(action, data)
    if action == "announce" then
        SendChatMessage(FormatMessage(DB().announceTemplate, data), GroupChannel())
    elseif action == "request" and data.remaining <= 0 and data.name then
        local message = FormatMessage(DB().requestTemplate, data, true)
        SendChatMessage(message, "WHISPER", nil, data.name)
        SendAddon(PREFIX, "R;" .. tostring(data.spellID), "WHISPER", data.name)
    end
end

local function InteractionKey(button)
    if IsShiftKeyDown() then return "Shift" .. button end
    if IsAltKeyDown() then return "Alt" .. button end
    if IsControlKeyDown() then return "Ctrl" .. button end
    return button
end

local function AcquireRow(parent)
    local row = table.remove(RCD.rowPool)
    if not row then
        row = EUI.SafeCreateFrame("Button", nil, parent)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture(0.06, 0.08, 0.10, 0.90)
        row.bar = row:CreateTexture(nil, "BORDER")
        row.bar:SetPoint("TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.nameText = row:CreateFontString(nil, "OVERLAY")
        row.spellText = row:CreateFontString(nil, "OVERLAY")
        row.timeText = row:CreateFontString(nil, "OVERLAY")
        row.timeText:SetJustifyH("RIGHT")
        row.targetText = row:CreateFontString(nil, "OVERLAY")
        row.targetText:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function(self, button)
            if RCD.preview then return end
            local data = self._data
            local interactions = DB() and DB().interactions
            local action = interactions and interactions[InteractionKey(button)] or "none"
            if data and action ~= "none" then RCD:RunInteraction(action, data) end
        end)
        row:SetScript("OnEnter", function(self)
            local data = self._data
            if not data then return end
            local spellName = SpellNameAndLink(data.spellID, data.isItem)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(spellName)
            GameTooltip:AddLine((ShortName(data.name) or "Unknown") .. " - " .. FormatTime(data.remaining), 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        row:SetParent(parent)
    end
    row:Show()
    return row
end

local function ReleaseRow(row)
    row._data = nil
    row:Hide()
    row:ClearAllPoints()
    RCD.rowPool[#RCD.rowPool + 1] = row
end

local function ApplyGroupPosition(id)
    local frame = RCD.groupFrames[id]
    local db = DB()
    local group = db and db.groups[id]
    if not frame or not group then return end
    local key = GROUP_KEY_PREFIX .. id
    local anchor = EllesmereUIDB and EllesmereUIDB.unlockAnchors and EllesmereUIDB.unlockAnchors[key]
    if anchor and anchor.target and EUI.ReapplyOwnAnchor then
        EUI.ReapplyOwnAnchor(key)
        if frame:GetNumPoints() > 0 then return end
    end
    local pos = group.position
    frame:ClearAllPoints()
    if pos and pos.point then
        -- Rows are laid out from TOPLEFT, so retain a width-independent top
        -- edge instead of letting a CENTER anchor split height changes across
        -- both the top and bottom. Populate this lazily for existing profiles.
        if pos.point == "CENTER" and (pos.relPoint or pos.point) == "CENTER" then
            if not pos.growEdge then
                pos.growEdge = {
                    anchor = "TOP",
                    x = pos.x or 0,
                    y = (pos.y or 0) + (frame:GetHeight() or 0) / 2,
                }
            end
            local edge = pos.growEdge
            frame:SetPoint(edge.anchor or "TOP", UIParent, "CENTER",
                edge.x or pos.x or 0, edge.y or pos.y or 0)
        else
            frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        end
    else
        frame:SetPoint("TOP", UIParent, "CENTER", 0, (frame:GetHeight() or 0) / 2)
    end
end

local function LayoutRow(row, data, group, width, height)
    row._data = data
    row:SetSize(width, height)
    local iconSize = math.max(8, height - 4)
    row.icon:SetSize(iconSize, iconSize)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon:SetTexture(SpellIcon(data.spellID, data.isItem))
    if group.showIcon == false then row.icon:Hide() else row.icon:Show() end

    local font = EUI.GetFontPath and EUI.GetFontPath("raidCooldowns") or STANDARD_TEXT_FONT
    local fontSize = math.max(8, math.min(14, height - 10))
    row.nameText:SetFont(font, fontSize, "")
    row.spellText:SetFont(font, fontSize, "")
    row.timeText:SetFont(font, fontSize, "OUTLINE")
    row.targetText:SetFont(font, fontSize, "")
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("LEFT", group.showIcon == false and row or row.icon,
        group.showIcon == false and "LEFT" or "RIGHT", group.showIcon == false and 4 or 5, 0)
    row.nameText:SetWidth(math.max(60, width * 0.31))
    row.spellText:ClearAllPoints()
    row.spellText:SetPoint("LEFT", row.nameText, "RIGHT", 3, 0)
    row.spellText:SetPoint("RIGHT", row.timeText, "LEFT", -4, 0)
    row.timeText:ClearAllPoints()
    row.timeText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.timeText:SetWidth(50)

    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.class]
    row.nameText:SetText(ShortName(data.name) or "Unknown")
    row.nameText:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
    local spellName = SpellNameAndLink(data.spellID, data.isItem)
    local spellText = group.showSpellName == false and "" or spellName
    if group.targetDisplay == "inline" and data.targetName then
        spellText = spellText .. (spellText ~= "" and " -> " or "") .. ShortName(data.targetName)
    end
    row.spellText:SetText(spellText)
    row.timeText:SetText(FormatTime(data.remaining))
    if data.remaining <= 0 then
        row.timeText:SetTextColor(0.15, 1, 0.35)
    elseif data.remaining < 10 then
        row.timeText:SetTextColor(1, 0.2, 0.2)
    else
        row.timeText:SetTextColor(1, 0.82, 0)
    end
    local pct = data.remaining > 0 and math.max(0, 1 - data.remaining / math.max(1, data.duration)) or 1
    row.bar:SetWidth(math.max(1, width * pct))
    if group.colorBarByClass and color then
        row.bar:SetTexture(color.r, color.g, color.b, 0.35)
    elseif data.remaining <= 0 then
        row.bar:SetTexture(0.08, 0.55, 0.22, 0.30)
    else
        row.bar:SetTexture(0.05, 0.50, 0.78, 0.35)
    end
end

local function FillRow(rows, index, guid, name, class, role, specID, spellID,
        duration, remaining, targetName, targetClass, isItem)
    local row = rows[index]
    if not row then row = {}; rows[index] = row end
    row.guid = guid
    row.name = name
    row.class = class
    row.role = role
    row.specID = specID
    row.spellID = spellID
    row.duration = duration
    row.remaining = remaining
    row.targetName = targetName
    row.targetClass = targetClass
    row.isItem = isItem
end

function RCD:CollectRows(group, rows)
    rows = rows or {}
    local now, active, count = GetTime(), false, 0
    if self.preview then
        local _, class = UnitClass("player")
        local sampleID
        for spellID in pairs(group.enabledSpells or {}) do sampleID = spellID; break end
        sampleID = sampleID or 33206
        FillRow(rows, 1, UnitGUID("player"), UnitName("player"), class, nil, nil,
            sampleID, 180, 73.4, UnitName("player"))
        FillRow(rows, 2, UnitGUID("player"), UnitName("player"), class, nil, nil,
            sampleID, 180, 0)
        for i = #rows, 3, -1 do rows[i] = nil end
        return rows, true
    end
    for guid, spells in pairs(self.state) do
        local member = self.roster[guid]
        if member and MemberMatches(group, member) then
            for spellID, info in pairs(spells) do
                if group.enabledSpells and group.enabledSpells[spellID] then
                    local remaining = math.max(0, (info.expires or 0) - now)
                    if remaining > 0 then active = true end
                    if group.showReady or remaining > 0 then
                        count = count + 1
                        FillRow(rows, count, guid, member.name, member.class,
                            member.role, member.specID, spellID, info.duration or 1,
                            remaining, info.targetName, info.targetClass, info.isItem)
                    end
                end
            end
        end
    end
    for i = #rows, count + 1, -1 do rows[i] = nil end
    table.sort(rows, function(a, b)
        local da, db = Catalog:Get(a.spellID), Catalog:Get(b.spellID)
        local ca, cb = da and da.class or a.class, db and db.class or b.class
        if ca ~= cb then return ca < cb end
        local oa, ob = da and da.order or 999, db and db.order or 999
        if oa ~= ob then return oa < ob end
        if a.spellID ~= b.spellID then return a.spellID < b.spellID end
        if (a.remaining > 0) ~= (b.remaining > 0) then return a.remaining > 0 end
        if a.remaining ~= b.remaining then return a.remaining < b.remaining end
        return (a.name or "") < (b.name or "")
    end)
    return rows, active
end

function RCD:RefreshGroup(id)
    local db = DB()
    local group = db and db.groups[id]
    local frame = self.groupFrames[id]
    if not group or not frame then return false end
    if not db.enabled or not group.enabled
        or (not self.preview and not LocalVisibilityMatches(group)) then
        frame:Hide()
        return false
    end
    local rows, active = self:CollectRows(group, frame.rowData)
    while #frame.rows > #rows do ReleaseRow(table.remove(frame.rows)) end
    while #frame.rows < #rows do frame.rows[#frame.rows + 1] = AcquireRow(frame) end
    local width = math.max(MIN_WIDTH, group.width or 270)
    local rowHeight = math.max(16, group.rowHeight or 26)
    local y = group.showHeader == false and 0 or HEADER_H
    local previous
    for i, data in ipairs(rows) do
        local def = Catalog:Get(data.spellID)
        local classKey = def and def.class or data.class
        if previous and previous ~= classKey .. ":" .. data.spellID then y = y + (group.spacing or 4) end
        previous = classKey .. ":" .. data.spellID
        local row = frame.rows[i]
        LayoutRow(row, data, group, width, rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
        y = y + rowHeight + ROW_GAP
    end
    frame:SetWidth(width)
    local newHeight = math.max(group.showHeader == false and 4 or HEADER_H + 4, y)
    if frame:GetHeight() ~= newHeight then
        frame:SetHeight(newHeight)
        if EUI.NotifyElementResized then EUI.NotifyElementResized(GROUP_KEY_PREFIX .. id) end
    end
    if group.showHeader == false then frame.header:Hide(); frame.title:Hide()
    else frame.header:Show(); frame.title:Show(); frame.title:SetText(group.name) end
    if #rows > 0 or self.preview then frame:Show() else frame:Hide() end
    return active
end

local countdownTicker
countdownTicker = EUI.Tick.NewAnimTicker(RCD._eventFrame, function()
    local anyActive = false
    for id in pairs(RCD.groupFrames) do
        if RCD:RefreshGroup(id) then anyActive = true end
    end
    return anyActive or RCD.preview
end, 0.1)

function RCD:RefreshAllGroups()
    local anyActive = false
    for id in pairs(self.groupFrames) do
        if self:RefreshGroup(id) then anyActive = true end
    end
    if anyActive or self.preview then countdownTicker.Start() else countdownTicker.Stop() end
end

function RCD:CreateGroupFrame(id)
    if self.groupFrames[id] then return self.groupFrames[id] end
    local db = DB()
    local group = db and db.groups[id]
    if not group then return nil end
    local frame = EUI.SafeCreateFrame("Frame", nil, UIParent)
    frame:SetSize(group.width or 270, HEADER_H + 4)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame.rows = {}
    frame.rowData = {}
    frame.header = frame:CreateTexture(nil, "BACKGROUND")
    frame.header:SetPoint("TOPLEFT")
    frame.header:SetPoint("TOPRIGHT")
    frame.header:SetHeight(HEADER_H)
    frame.header:SetTexture(0.04, 0.06, 0.08, 0.94)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont(EUI.GetFontPath and EUI.GetFontPath("raidCooldowns") or STANDARD_TEXT_FONT, 12, "")
    frame.title:SetPoint("LEFT", frame, "TOPLEFT", 5, -HEADER_H / 2)
    frame.title:SetText(group.name)
    local ar, ag, ab = 0.05, 0.82, 0.62
    if EUI.GetAccentColor then ar, ag, ab = EUI.GetAccentColor() end
    frame.title:SetTextColor(ar, ag, ab)
    self.groupFrames[id] = frame
    ApplyGroupPosition(id)
    return frame
end

function RCD:DestroyGroupFrame(id)
    local frame = self.groupFrames[id]
    if not frame then return end
    for i = #frame.rows, 1, -1 do ReleaseRow(frame.rows[i]); frame.rows[i] = nil end
    frame:Hide()
    self.groupFrames[id] = nil
end

function RCD:RegisterGroupUnlock(id)
    if not EUI.RegisterUnlockElements or not EUI.MakeUnlockElement then return end
    local db = DB()
    local group = db and db.groups[id]
    if not group then return end
    local key = GROUP_KEY_PREFIX .. id
    EUI:RegisterUnlockElements({ EUI.MakeUnlockElement({
        key = key,
        label = group.name or "Raid Cooldowns",
        group = "Raid Cooldowns",
        order = 730 + (tonumber(id) or 0),
        noResize = true,
        getGrowDirection = function() return "DOWN" end,
        isHidden = function()
            local db = DB(); local group = db and db.groups[id]
            return not db or not db.enabled or not group or not group.enabled
        end,
        getFrame = function() return RCD:CreateGroupFrame(id) end,
        getSize = function()
            local frame = RCD.groupFrames[id]
            local db = DB(); local group = db and db.groups[id]
            return frame and frame:GetWidth() or (group and group.width or 270),
                frame and frame:GetHeight() or HEADER_H + 4
        end,
        savePos = function(_, point, relPoint, x, y)
            local db = DB(); local group = db and db.groups[id]
            if group and point then
                local frame = RCD.groupFrames[id]
                local height = frame and frame:GetHeight() or HEADER_H + 4
                group.position = {
                    point = point, relPoint = relPoint, x = x, y = y,
                    growEdge = {
                        anchor = "TOP",
                        x = x or 0,
                        y = (y or 0) + height / 2,
                    },
                }
            end
            if not EUI._unlockActive then ApplyGroupPosition(id) end
        end,
        loadPos = function()
            local db = DB(); local group = db and db.groups[id]
            return group and group.position or nil
        end,
        clearPos = function()
            local db = DB(); local group = db and db.groups[id]
            if group then group.position = nil end
        end,
        applyPos = function() ApplyGroupPosition(id) end,
    }) }, ADDON_FOLDER)
end

function RCD:RegisterAllUnlocks()
    local db = DB()
    if not db then return end
    for _, id in ipairs(db.groupOrder) do
        if db.groups[id] then self:RegisterGroupUnlock(id) end
    end
end

local function BroadcastCast(spellID, targetName)
    local channel = GroupChannel()
    if channel == "SAY" then return end
    SendAddon(PREFIX, "C;" .. tostring(spellID) .. ";" .. (targetName or ""), channel)
end

function RCD:RecordCast(sourceGUID, rawSpellID, targetName, targetGUID, noBroadcast)
    local member = self.roster[sourceGUID]
    local def = Catalog and Catalog:Get(rawSpellID)
    if not member or not def or (def.class ~= "ITEMS" and def.class ~= member.class) then return end
    local spellID = def.spellID
    local duration = def.class == "ITEMS" and def.duration or CooldownDuration(member.unit, def)
    local targetMember = targetGUID and self.roster[targetGUID]
    local state = StateFor(sourceGUID)
    state[spellID] = state[spellID] or {}
    state[spellID].duration = duration
    state[spellID].expires = GetTime() + duration
    state[spellID].targetName = targetName
    state[spellID].targetClass = targetMember and targetMember.class
    state[spellID].isItem = def.class == "ITEMS"
    for _, resetID in ipairs(def.resets or {}) do
        if state[resetID] then state[resetID].expires = 0 end
    end
    if not noBroadcast and sourceGUID == UnitGUID("player") then BroadcastCast(spellID, targetName) end
    self:RefreshAllGroups()
end

function RCD:OnCombatLog(_, _, subEvent, sourceGUID, sourceName, _, destinationGUID, destinationName, _, rawSpellID)
    if not sourceGUID or not rawSpellID then return end
    local def = Catalog and Catalog:Get(rawSpellID)
    if not def or not self.roster[sourceGUID] then return end
    if def.startOnAuraRemoved then
        local state = StateFor(sourceGUID)
        if subEvent == "SPELL_CAST_SUCCESS" then
            state[def.spellID] = state[def.spellID] or { duration = def.duration, expires = 0 }
            state[def.spellID].pendingTarget = destinationName
            state[def.spellID].pendingTargetGUID = destinationGUID
        elseif subEvent == "SPELL_AURA_REMOVED" then
            local info = state[def.spellID]
            self:RecordCast(sourceGUID, def.spellID,
                info and info.pendingTarget or destinationName,
                info and info.pendingTargetGUID or destinationGUID)
            if info then info.pendingTarget = nil; info.pendingTargetGUID = nil end
        end
        return
    end
    if (def.trigger == "SPELL_CAST_SUCCESS" and subEvent == "SPELL_CAST_SUCCESS")
        or (def.trigger == "SPELL_AURA_APPLIED" and (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH"))
        or (def.trigger == "SPELL_RESURRECT" and subEvent == "SPELL_RESURRECT")
        or (def.spellID == 47883 and subEvent == "SPELL_RESURRECT") then
        self:RecordCast(sourceGUID, def.spellID, destinationName, destinationGUID)
    end
end

function RCD:OnSpellcastSucceeded(_, unit, spellName, spellID)
    if not unit or not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or not self.roster[guid] then return end
    local rebirthName = GetSpellInfo(48477)
    if spellName == rebirthName or tonumber(spellID) == 48477 then
        self:RecordCast(guid, 48477, nil, nil)
    end
end

function RCD:ShowRequest(sender, spellID)
    local db = DB()
    if not db then return end
    if not self.requestFrame then
        local frame = EUI.SafeCreateFrame("Frame", nil, UIParent)
        frame:SetSize(500, 70)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text:SetFont(EUI.GetFontPath and EUI.GetFontPath("raidCooldowns") or STANDARD_TEXT_FONT, 22, "OUTLINE")
        frame.text:SetPoint("CENTER")
        self.requestFrame = frame
    end
    local spellName = SpellNameAndLink(spellID)
    self.requestFrame.text:SetText((ShortName(sender) or "Someone") .. " requests " .. (spellName or "a cooldown"))
    self.requestFrame:Show()
    if self.requestTimer then self.requestTimer:Cancel() end
    self.requestTimer = C_Timer.NewTimer(db.notificationDuration or 5, function()
        if RCD.requestFrame then RCD.requestFrame:Hide() end
        RCD.requestTimer = nil
    end)
end

function RCD:OnAddonMessage(_, prefix, message, _, sender)
    if prefix ~= PREFIX or type(message) ~= "string" then return end
    local kind, sid, target = strsplit(";", message)
    sid = tonumber(sid)
    if kind == "R" and sid then
        self:ShowRequest(sender, sid)
        return
    end
    if kind ~= "C" or not sid then return end
    local senderShort = ShortName(sender)
    for guid, member in pairs(self.roster) do
        if ShortName(member.name) == senderShort then
            self:RecordCast(guid, sid, target ~= "" and target or nil, nil, true)
            return
        end
    end
end

function RCD:OnEvent(event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if select("#", ...) == 0 and CombatLogGetCurrentEventInfo then
            local timestamp, subEvent, hideCaster, sourceGUID, sourceName,
                sourceFlags, sourceRaidFlags, destinationGUID, destinationName,
                destinationFlags, destinationRaidFlags, rawSpellID =
                CombatLogGetCurrentEventInfo()
            self:OnCombatLog(event, timestamp, subEvent, sourceGUID, sourceName,
                sourceFlags, destinationGUID, destinationName, destinationFlags,
                rawSpellID)
        else
            self:OnCombatLog(event, ...)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        self:OnSpellcastSucceeded(event, ...)
    elseif event == "CHAT_MSG_ADDON" then
        self:OnAddonMessage(event, ...)
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        self:SaveState()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit and UnitExists(unit) then
            local member = self.roster[UnitGUID(unit)]
            if member then SeedUnit(member); self:RefreshAllGroups() end
        end
    else
        if self.rosterRefreshPending then return end
        self.rosterRefreshPending = true
        C_Timer.After(0.25, function()
            RCD.rosterRefreshPending = false
            if DB() and DB().enabled then RCD:RefreshRoster() end
        end)
    end
end

local trackedEvents = {
    "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_SPELLCAST_SUCCEEDED",
    "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "UNIT_INVENTORY_CHANGED", "CHAT_MSG_ADDON", "PLAYER_LOGOUT",
    "PLAYER_LEAVING_WORLD",
}

function RCD:SetEventsActive(active)
    active = active == true
    if self.eventsActive == active then return end
    self.eventsActive = active
    if active then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        elseif RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(PREFIX)
        end
        if EUI.RegisterCDMEventCallback then
            EUI.RegisterCDMEventCallback("qolRaidCooldowns", function(_, event, ...)
                RCD:OnEvent(event, ...)
            end, trackedEvents)
            self.usingSharedEvents = true
        else
            for _, event in ipairs(trackedEvents) do self:RegisterEvent(event, "OnEvent") end
            self.usingSharedEvents = false
        end
        if LGT and LGT.RegisterCallback and not self.lgtRegistered then
            self.lgtRegistered = true
            self.lgtCallback = self.lgtCallback or function()
                if DB() and DB().enabled then RCD:RefreshRoster() end
            end
            LGT.RegisterCallback(self, "LibGroupTalents_Update", self.lgtCallback)
        end
        if EUI.RoleDetector and not self.roleCallback then
            self.roleCallback = function()
                if DB() and DB().enabled then RCD:RefreshRoster() end
            end
            EUI.RoleDetector:RegisterCallback(self.roleCallback)
        end
        if EUI.RegisterUnlockModeListener and not self.unlockCallback then
            self.unlockCallback = function(active)
                RCD.preview = active == true
                RCD:RefreshAllGroups()
            end
            EUI:RegisterUnlockModeListener("RaidCooldowns", self.unlockCallback)
        end
    else
        if self.usingSharedEvents and EUI.UnregisterCDMEventCallback then
            EUI.UnregisterCDMEventCallback("qolRaidCooldowns")
        else
            for _, event in ipairs(trackedEvents) do self:UnregisterEvent(event) end
        end
        self.usingSharedEvents = false
        countdownTicker.Stop()
        self:SaveState()
        if self.requestTimer then
            self.requestTimer:Cancel()
            self.requestTimer = nil
        end
        if self.requestFrame then self.requestFrame:Hide() end
        if LGT and LGT.UnregisterCallback and self.lgtRegistered then
            LGT.UnregisterCallback(self, "LibGroupTalents_Update")
            self.lgtRegistered = false
        end
        if EUI.RoleDetector and self.roleCallback then
            EUI.RoleDetector:UnregisterCallback(self.roleCallback)
            self.roleCallback = nil
        end
        if EUI.UnregisterUnlockModeListener and self.unlockCallback then
            EUI:UnregisterUnlockModeListener("RaidCooldowns")
            self.unlockCallback = nil
        end
        self.preview = false
    end
end

function RCD:ApplyEnabled()
    local db = DB()
    local enabled = db and db.enabled == true
    if enabled and #db.groupOrder == 0 then self:CreateGroup("Raid Cooldowns") end
    self:SetEventsActive(enabled)
    if enabled then
        for _, id in ipairs(db.groupOrder) do
            if db.groups[id] then self:CreateGroupFrame(id) end
        end
        self:RegisterAllUnlocks()
        self:RefreshRoster()
    else
        local stale = {}
        for id, frame in pairs(self.groupFrames) do
            if db and db.groups[id] then frame:Hide()
            else stale[#stale + 1] = id end
        end
        for i = 1, #stale do
            local id = stale[i]
            self:DestroyGroupFrame(id)
            if EUI.UnregisterUnlockElement then
                EUI:UnregisterUnlockElement(GROUP_KEY_PREFIX .. id)
            end
        end
    end
end

function RCD:RefreshConfiguration()
    local db = DB()
    if not db or not db.enabled then return end
    self:RegisterAllUnlocks()
    for id in pairs(self.groupFrames) do ApplyGroupPosition(id) end
    self:RefreshAllGroups()
end

function RCD:OnInitialize()
    self.db = EUI.Lite.NewDB("EllesmereUIRaidCooldownsDB", defaults, true)
end

function RCD:OnEnable()
    self:ApplyEnabled()
end

_G._EUI_RaidCooldowns_Apply = function() RCD:ApplyEnabled() end
_G._EUI_RaidCooldowns_Refresh = function() RCD:RefreshConfiguration() end
