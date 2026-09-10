local addon, ns = ...

if not ns or not ns.isLegacyNameplates then return end

-- WoTLK nameplates are anonymous WorldFrame children. They have no unit token,
-- so use Blizzard's native bars/text as the authoritative data source. This is
-- accurate for every visible plate, unlike target/mouseover Unit* fallbacks.
local select, type, pairs, ipairs = select, type, pairs, ipairs
local lower, find, abs, ceil, floor = string.lower, string.find, math.abs, math.ceil, math.floor
local max, sort = math.max, table.sort
local WHITE = "Interface\\Buttons\\WHITE8X8"
local plates = setmetatable({}, { __mode = "k" })
local lastWorldChildCount = 0
local enabled = false
local AURA_UNITS = { "target", "mouseover", "focus", "arena1", "arena2", "arena3", "arena4", "arena5" }
local auraUnitOwners = {}
local depthOrder = {}
local emphasisSettings = {}
local nextPlateSerial = 0
local targetOwner, focusOwner, mouseoverOwner

ns.legacyPlates = plates

local function DB()
    return (ns.db and ns.db.profile) or ns.defaults or {}
end

local function RegionCount(frame)
    return select("#", frame:GetRegions())
end

local function ChildCount(frame)
    return select("#", frame:GetChildren())
end

local function TexturePath(texture)
    if not texture or not texture.GetTexture then return nil end
    local path = texture:GetTexture()
    return type(path) == "string" and lower(path) or nil
end

-- Blizzard refreshes legacy nameplate regions directly and may restore the
-- native name/level FontStrings after we skin the plate.  Keep those regions
-- transparent permanently: their text is still readable through GetText(), so
-- they remain the authoritative source for our replacement FontStrings.
local function SuppressSourceFont(fs)
    if not fs then return end
    fs:Hide()
    fs:SetAlpha(0)
    if fs._euiAlphaSuppressed or not hooksecurefunc then return end
    fs._euiAlphaSuppressed = true
    hooksecurefunc(fs, "Show", function(self)
        if not self._euiForcingHidden then
            self._euiForcingHidden = true
            self:Hide()
            self._euiForcingHidden = nil
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

local function IsLegacyNameplate(frame)
    if not frame or frame == WorldFrame or frame:GetParent() ~= WorldFrame then return false end
    local bars, fonts, signature = 0, 0, false
    for i = 1, RegionCount(frame) do
        local region = select(i, frame:GetRegions())
        if region and region.GetObjectType then
            local kind = region:GetObjectType()
            if kind == "FontString" then
                fonts = fonts + 1
            elseif kind == "Texture" then
                local path = TexturePath(region)
                if path and (find(path, "nameplate", 1, true)
                    or find(path, "targetingframe", 1, true)) then
                    signature = true
                end
            end
        end
    end
    for i = 1, ChildCount(frame) do
        local child = select(i, frame:GetChildren())
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            bars = bars + 1
        end
    end
    return signature and bars > 0 and fonts > 0
end

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

local function SetBorder(border, shown, color)
    if not border then return end
    for _, edge in ipairs(border) do
        if color then edge:SetVertexColor(color.r or 0, color.g or 0, color.b or 0, 1) end
        if shown then edge:Show() else edge:Hide() end
    end
end

local function SetBorderSize(border, size)
    if not border then return end
    size = tonumber(size) or 1
    border[1]:SetHeight(size)
    border[2]:SetHeight(size)
    border[3]:SetWidth(size)
    border[4]:SetWidth(size)
end

-- Anonymous Wrath nameplates do not have unit tokens.  We can still attach
-- accurate aura data whenever the plate represents a targetable unit token
-- (target/focus/mouseover, plus arena opponents), then age that verified
-- snapshot by its real expiration times.  Matching health as well as name
-- prevents one mob's debuffs being copied onto every same-named mob nearby.
local function PlateMatchesUnit(state, unit)
    if not UnitExists(unit) or not UnitCanAttack("player", unit) then return false end
    local plateName = state.nameSource and state.nameSource:GetText()
    local unitName = UnitName(unit)
    if not plateName or plateName == "" or plateName ~= unitName then return false end

    local _, plateMax = state.health:GetMinMaxValues()
    local plateValue = state.health:GetValue()
    local unitMax = UnitHealthMax(unit)
    local unitValue = UnitHealth(unit)
    if plateMax and plateMax > 0 and unitMax and unitMax > 0 then
        if abs(plateMax - unitMax) < 1 and abs(plateValue - unitValue) < 1 then
            return true
        end
        return abs((plateValue / plateMax) - (unitValue / unitMax)) < .015
    end
    return true
end

-- Target/focus/mouseover effects need a friend-or-foe identity check, while
-- the aura resolver above deliberately remains enemy-only.  Health is part of
-- the match so two same-named creatures do not normally inherit each other's
-- state; the native target alpha and mouseover highlight break the remaining
-- ambiguity for those two special units.
local function PlateIdentityMatchesUnit(state, unit)
    if not UnitExists(unit) then return false end
    local plateName = state.nameSource and state.nameSource:GetText()
    local unitName = UnitName(unit)
    if not plateName or plateName == "" or plateName ~= unitName then return false end

    local _, plateMax = state.health:GetMinMaxValues()
    local plateValue = state.health:GetValue()
    local unitMax = UnitHealthMax(unit)
    local unitValue = UnitHealth(unit)
    if plateMax and plateMax > 0 and unitMax and unitMax > 0 then
        if abs(plateMax - unitMax) < 1 and abs(plateValue - unitValue) < 1 then
            return true
        end
        return abs((plateValue / plateMax) - (unitValue / unitMax)) < .015
    end
    return true
end

local function ResolveAuraUnit(state)
    if state.auraUnit and PlateMatchesUnit(state, state.auraUnit) then
        return state.auraUnit
    end
    if state.auraUnit and auraUnitOwners[state.auraUnit] == state then
        auraUnitOwners[state.auraUnit] = nil
    end
    state.auraUnit = nil
    for _, unit in ipairs(AURA_UNITS) do
        local owned = auraUnitOwners[unit]
        local sameUnitOwned = false
        if not owned and UnitIsUnit then
            for ownedUnit, owner in pairs(auraUnitOwners) do
                if owner ~= state and UnitExists(ownedUnit) and UnitIsUnit(unit, ownedUnit) then
                    sameUnitOwned = true
                    break
                end
            end
        end
        if not owned and not sameUnitOwned and PlateMatchesUnit(state, unit) then
            state.auraUnit = unit
            auraUnitOwners[unit] = state
            return unit
        end
    end
end

local function SetAuraTextPoint(text, owner, position, x, y)
    text:ClearAllPoints()
    if position == "center" then
        text:SetPoint("CENTER", owner, "CENTER", x, y)
        text:SetJustifyH("CENTER")
    elseif position == "topright" then
        text:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 3 + x, 4 + y)
        text:SetJustifyH("RIGHT")
    elseif position == "bottomleft" then
        text:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -3 + x, -4 + y)
        text:SetJustifyH("LEFT")
    elseif position == "bottomright" then
        text:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 3 + x, -4 + y)
        text:SetJustifyH("RIGHT")
    else
        text:SetPoint("TOPLEFT", owner, "TOPLEFT", -3 + x, 4 + y)
        text:SetJustifyH("LEFT")
    end
end

local function EnsureDebuffSlots(state)
    if not state.debuffs then state.debuffs = {} end
    local db = DB()
    local wanted = db.maxDebuffs or 5
    for i = #state.debuffs + 1, wanted do
        local slot = CreateFrame("Frame", nil, state.visualFrame or state.frame)
        slot:SetFrameLevel((state.visualFrame or state.frame):GetFrameLevel() + 1)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
        slot.icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
        slot.border = CreateBorder(slot)

        slot.cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        slot.cooldown:SetAllPoints(slot.icon)
        slot.cooldown:SetFrameLevel(slot:GetFrameLevel() + 1)
        if slot.cooldown.SetReverse then slot.cooldown:SetReverse(true) end

        slot.textFrame = CreateFrame("Frame", nil, slot)
        slot.textFrame:SetAllPoints(slot)
        slot.textFrame:SetFrameLevel(slot:GetFrameLevel() + 2)
        slot.durationText = slot.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        slot.countText = slot.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        slot:Hide()
        state.debuffs[i] = slot
    end
    for i = wanted + 1, #state.debuffs do state.debuffs[i]:Hide() end
end

local function StyleDebuffSlots(state)
    EnsureDebuffSlots(state)
    local db = DB()
    local size = ns.GetDebuffIconSize and ns.GetDebuffIconSize() or 26
    local cropped = ns.GetAuraCrop and ns.GetAuraCrop("debuffs")
    local height = ns.GetAuraCropHeight and ns.GetAuraCropHeight(cropped, size) or size
    local durationPos = db.debuffTimerPosition or db.auraTextPosition or "topleft"
    local durationColor = db.debuffDurationTextColor or db.auraDurationTextColor or { r = 1, g = 1, b = 1 }
    local durationSize = db.debuffDurationTextSize or db.auraDurationTextSize or 11
    local durationX = db.debuffDurationTextX or db.auraDurationTextX or 0
    local durationY = db.debuffDurationTextY or db.auraDurationTextY or 0
    local stackPos = db.auraStackTextPosition or "bottomright"
    local stackColor = db.auraStackTextColor or { r = 1, g = 1, b = 1 }
    local stackSize = db.auraStackTextSize or 11
    local stackX = db.auraStackTextX or 0
    local stackY = db.auraStackTextY or 0
    local borderColor = db.auraBorderColor or { r = 0, g = 0, b = 0 }

    for _, slot in ipairs(state.debuffs) do
        slot:SetSize(size, height)
        if ns.SetAuraIconCrop then ns.SetAuraIconCrop(slot.icon, cropped, size, height) end
        SetBorder(slot.border, true, borderColor)
        ns.SetFSFont(slot.durationText, durationSize, ns.GetNPOutline())
        slot.durationText:SetTextColor(durationColor.r, durationColor.g, durationColor.b, 1)
        SetAuraTextPoint(slot.durationText, slot, durationPos, durationX, durationY)
        if durationPos == "none" then slot.durationText:Hide() else slot.durationText:Show() end
        ns.SetFSFont(slot.countText, stackSize, ns.GetNPOutline())
        slot.countText:SetTextColor(stackColor.r, stackColor.g, stackColor.b, 1)
        SetAuraTextPoint(slot.countText, slot, stackPos, stackX, stackY)
        if stackPos == "none" then slot.countText:Hide() else slot.countText:Show() end
    end
end

local function LayoutDebuffSlots(state, count)
    if not state.debuffs then return end
    local db = DB()
    local slotName = (ns.GetAuraSlots and select(1, ns.GetAuraSlots())) or db.debuffSlot or "top"
    if slotName == "none" then count = 0 end
    local size = ns.GetDebuffIconSize and ns.GetDebuffIconSize() or 26
    local cropped = ns.GetAuraCrop and ns.GetAuraCrop("debuffs")
    local height = ns.GetAuraCropHeight and ns.GetAuraCropHeight(cropped, size) or size
    local gap = ns.GetAuraSpacing and ns.GetAuraSpacing("debuffs") or 4
    local spacing, spacingV = size + gap, height + gap
    local xOff, yOff = 0, 0
    if ns.GetAuraSlotOffsets then xOff, yOff = ns.GetAuraSlotOffsets("debuffSlot") end
    local debuffY = ns.GetDebuffYOffset and ns.GetDebuffYOffset() or 2
    local sideOff = ns.GetSideAuraXOffset and ns.GetSideAuraXOffset() or 2
    local anchorBottom = state.cast or state.health

    for i, aura in ipairs(state.debuffs) do
        aura:ClearAllPoints()
        if i <= count then
            if slotName == "left" then
                aura:SetPoint("BOTTOMRIGHT", state.health, "BOTTOMLEFT", -sideOff - (i - 1) * spacing + xOff, yOff)
            elseif slotName == "right" then
                aura:SetPoint("BOTTOMLEFT", state.health, "BOTTOMRIGHT", sideOff + (i - 1) * spacing + xOff, yOff)
            elseif slotName == "topleft" then
                local growth = db.topleftSlotGrowth or "left"
                local dx, dy = -(i - 1) * spacing, 0
                if growth == "right" then dx = (i - 1) * spacing end
                if growth == "up" then dx, dy = 0, (i - 1) * spacingV end
                aura:SetPoint("BOTTOMLEFT", state.health, "TOPLEFT", xOff + dx, debuffY + yOff + dy)
            elseif slotName == "topright" then
                local growth = db.toprightSlotGrowth or "right"
                local dx, dy = (i - 1) * spacing, 0
                if growth == "left" then dx = -(i - 1) * spacing end
                if growth == "up" then dx, dy = 0, (i - 1) * spacingV end
                aura:SetPoint("BOTTOMRIGHT", state.health, "TOPRIGHT", xOff + dx, debuffY + yOff + dy)
            elseif slotName == "bottom" then
                aura:SetPoint("TOP", anchorBottom, "BOTTOM", (i - (count + 1) / 2) * spacing + xOff, -2 + yOff)
            else
                aura:SetPoint("BOTTOM", state.name or state.health, "TOP", (i - (count + 1) / 2) * spacing + xOff, debuffY + yOff)
            end
            aura:Show()
        else
            aura:Hide()
        end
    end
end

local function ClearDebuffs(state)
    if not state.auraUnit and (state.debuffCount or 0) == 0 then return end
    if state.auraUnit and auraUnitOwners[state.auraUnit] == state then
        auraUnitOwners[state.auraUnit] = nil
    end
    state.auraUnit = nil
    state.debuffCount = 0
    if not state.debuffs then return end
    for _, slot in ipairs(state.debuffs) do
        slot.expirationTime = nil
        slot.auraIcon = nil
        slot.auraCount = nil
        slot.remaining = nil
        slot.durationText:SetText("")
        slot.countText:SetText("")
        slot.cooldown:Hide()
        slot:Hide()
    end
end

-- Keep the last authoritative snapshot on its specific plate after the player
-- changes target.  Wrath cannot ask an arbitrary anonymous nameplate for aura
-- data, but the known expiration times remain valid; retaining them makes
-- multi-dotting work as each plate is targeted or moused over.  A removal we
-- cannot observe is corrected the next time that plate resolves to a token.
local function RefreshCachedDebuffs(state, now)
    local count = state.debuffCount or 0
    if count == 0 then return end
    for i = 1, count do
        local slot = state.debuffs[i]
        if not slot.expirationTime then
            ClearDebuffs(state)
            return
        end
        local remaining = ceil(slot.expirationTime - now)
        if remaining <= 0 then
            -- Re-resolving the remaining slots without a unit token would be
            -- guesswork.  Clear the snapshot; it will rebuild authoritatively
            -- as soon as this unit is targeted/focused/moused over again.
            ClearDebuffs(state)
            return
        end
        if slot.remaining ~= remaining then
            slot.durationText:SetText(remaining)
            slot.remaining = remaining
        end
    end
end

local function RefreshDebuffs(state, now)
    local unit = ResolveAuraUnit(state)
    local db = DB()
    local slotName = (ns.GetAuraSlots and select(1, ns.GetAuraSlots())) or db.debuffSlot or "top"
    if slotName == "none" then
        ClearDebuffs(state)
        return
    end
    if not unit then
        RefreshCachedDebuffs(state, now)
        return
    end

    EnsureDebuffSlots(state)
    local maximum = db.maxDebuffs or 5
    local shown = 0
    for index = 1, 40 do
        -- UnitDebuff is already implicitly HARMFUL; PLAYER is the native
        -- caster filter and includes the player's pet.  Do not scan the
        -- unfiltered list in Lua: that can leak another player's debuff onto
        -- the plate on clients whose caster return is incomplete.
        local name, _, icon, count, _, duration, expirationTime = UnitDebuff(unit, index, "PLAYER")
        if not name then break end
        if icon then
            shown = shown + 1
            local slot = state.debuffs[shown]
            if slot.auraIcon ~= icon then
                slot.icon:SetTexture(icon)
                slot.auraIcon = icon
            end
            slot.duration = duration
            local countText = count and count > 1 and count or ""
            if slot.auraCount ~= countText then
                slot.countText:SetText(countText)
                slot.auraCount = countText
            end
            if duration and duration > 0 and expirationTime and expirationTime > 0 then
                if slot.expirationTime ~= expirationTime then
                    local startTime = expirationTime - duration
                    if CooldownFrame_SetTimer then
                        CooldownFrame_SetTimer(slot.cooldown, startTime, duration, 1)
                    elseif slot.cooldown.SetCooldown then
                        slot.cooldown:SetCooldown(startTime, duration)
                    end
                    slot.cooldown:Show()
                    slot.expirationTime = expirationTime
                end
                local remaining = ceil(expirationTime - now)
                if slot.remaining ~= remaining then
                    slot.durationText:SetText(remaining)
                    slot.remaining = remaining
                end
            else
                slot.cooldown:Hide()
                slot.expirationTime = nil
                if slot.remaining ~= "" then
                    slot.durationText:SetText("")
                    slot.remaining = ""
                end
            end
            if shown >= maximum then break end
        end
    end
    local oldShown = state.debuffCount or 0
    state.debuffCount = shown
    if oldShown ~= shown then LayoutDebuffSlots(state, shown) end
end

-- Permanently zero a texture's alpha and hook SetAlpha so the C engine cannot
-- reassert it.  Mirrors the technique used by SuppressSourceFont for FontStrings.
local function SuppressTexture(region)
    region:SetAlpha(0)
    if region._euiAlphaSuppressed or not hooksecurefunc then return end
    region._euiAlphaSuppressed = true
    hooksecurefunc(region, "SetAlpha", function(self, alpha)
        if alpha ~= 0 and not self._euiForcingAlpha then
            self._euiForcingAlpha = true
            self:SetAlpha(0)
            self._euiForcingAlpha = nil
        end
    end)
end

-- Suppress ALL texture regions on `frame` and its non-StatusBar child frames.
-- EllesmereUI replaces every native visual element, so any Blizzard texture on
-- the nameplate frame (border, glow, highlight, elite/rare dragon art, etc.) is
-- unwanted chrome regardless of its texture path.  Only the raid targeting icon
-- is preserved.  Skips StatusBar children (health/cast bars) since those have
-- their textures managed separately.
local function ScanFrameRegions(frame, hiddenArt, raidIconRef, nativeSignals, depth, isStatusBar)
    depth = depth or 0
    -- On StatusBar children, skip region scanning -- their fill texture is
    -- managed by SetStatusBarTexture, not by us zeroing regions.
    if not isStatusBar then
        for i = 1, RegionCount(frame) do
            local region = select(i, frame:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local path = TexturePath(region)
                if path and find(path, "raidtargetingicons", 1, true) then
                    -- Keep the raid icon.
                    if raidIconRef and not raidIconRef[1] then raidIconRef[1] = region end
                else
                    -- The stock highlight is still an authoritative mouseover
                    -- signal after it becomes transparent. RefinedBlizzPlates
                    -- uses the same region's IsShown state for this purpose.
                    if path and nativeSignals and not nativeSignals.highlight
                        and (find(path, "nameplate-highlight", 1, true)
                            or find(path, "nameplate-selected", 1, true)) then
                        nativeSignals.highlight = region
                    end
                    -- Suppress everything else: border, glow, highlight, castbar chrome,
                    -- elite/rare dragon art, or any other Blizzard nameplate texture.
                    SuppressTexture(region)
                    hiddenArt[#hiddenArt + 1] = region
                end
            end
        end
    end
    if depth < 2 then
        for i = 1, ChildCount(frame) do
            local child = select(i, frame:GetChildren())
            if child then
                local childIsBar = child.GetObjectType and child:GetObjectType() == "StatusBar"
                ScanFrameRegions(child, hiddenArt, raidIconRef, nativeSignals, depth + 1, childIsBar)
            end
        end
    end
end

local function FindParts(frame)
    local health, cast
    for i = 1, ChildCount(frame) do
        local child = select(i, frame:GetChildren())
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            if not health then health = child elseif not cast then cast = child end
        end
    end

    local nameSource, levelSource
    local fonts = {}
    local hiddenArt = {}
    local raidIconRef = {}  -- single-element table so ScanFrameRegions can write it
    local nativeSignals = {}
    for i = 1, RegionCount(frame) do
        local region = select(i, frame:GetRegions())
        if region and region.GetObjectType then
            local kind = region:GetObjectType()
            if kind == "FontString" then
                fonts[#fonts + 1] = region
            end
        end
    end
    ScanFrameRegions(frame, hiddenArt, raidIconRef, nativeSignals)
    local raidIcon = raidIconRef[1]
    for _, fs in ipairs(fonts) do
        local value = fs:GetText()
        if value and tostring(value):match("^%??%d+[%+%-]?$" ) then
            levelSource = levelSource or fs
        elseif value and value ~= "" then
            nameSource = nameSource or fs
        end
    end
    nameSource = nameSource or fonts[1]
    if not levelSource then
        for _, fs in ipairs(fonts) do if fs ~= nameSource then levelSource = fs; break end end
    end
    return health, cast, nameSource, levelSource, raidIcon, fonts, hiddenArt,
        nativeSignals.highlight
end

local function ResolveTexture(key)
    if EllesmereUI and EllesmereUI.ResolveTexturePath and ns.healthBarTextures then
        return EllesmereUI.ResolveTexturePath(ns.healthBarTextures, key or "none", WHITE)
    end
    return WHITE
end

local function ApplyVisualAlpha(state)
    local db = DB()
    local configured = tonumber(db.nonTargetAlpha) or 100
    if configured < 0 then configured = 0 elseif configured > 100 then configured = 100 end
    local alpha = 1
    if configured < 100 and UnitExists("target") and not state.isTarget
        and not (db.nonTargetKeepFocus ~= false and state.isFocus) then
        -- The stock plate root already carries Blizzard's target/distance
        -- opacity. Compensate for that multiplier so this setting is a cap on
        -- the final visual opacity, while still respecting a stronger native
        -- distance fade.
        local wanted = configured / 100
        local native = state.frame:GetAlpha() or 1
        if native > 0 then alpha = wanted / native end
        if alpha > 1 then alpha = 1 end
    end

    if state.visualAlpha ~= alpha then
        state.visualAlpha = alpha
        if state.visualFrame then state.visualFrame:SetAlpha(alpha) end
    end
    local barAlpha = state.nameOnly and 0 or alpha
    if state.barAlpha ~= barAlpha then
        state.barAlpha = barAlpha
        state.health:SetAlpha(barAlpha)
        if state.cast then state.cast:SetAlpha(barAlpha) end
    end
    if state.healthText then
        local shown = not state.nameOnly and state.healthElement ~= nil
        if state.healthTextShown ~= shown then
            state.healthTextShown = shown
            if shown then state.healthText:Show() else state.healthText:Hide() end
        end
    end
end

local function ApplyReactionColor(state, r, g, b)
    if state.applyingColor then return end
    local db, color = DB()
    -- Classify by Blizzard's unambiguous native signals.  Invert to detect
    -- friendly: anything that is NOT clearly hostile / neutral / tapped must
    -- be a friendly unit (player class color or friendly-NPC green).  This
    -- avoids trying to enumerate every warm-toned class color, which is
    -- impossible without a unit token on 3.3.5.
    local isHostile = r > .85 and g < .25 and b < .25
    local isNeutral = r > .75 and g > .65 and b < .35
    local isTapped  = abs(r - g) < .08 and abs(g - b) < .08 and r < .7
    state.isFriendly = not isHostile and not isNeutral and not isTapped
    -- Blizzard signals friendly NPCs with pure green (0, 1, 0).  Any other
    -- friendly color is a player class color, so we can now positively
    -- identify friendly players without a unit token.
    if state.isFriendly then
        state.isFriendlyPlayer = not (r < .05 and g > .95 and b < .05)
    else
        state.isFriendlyPlayer = false
    end
    local targetEnabled = db.targetColorEnabled == true
    local focusEnabled = db.focusColorEnabled ~= false
    if state.isTarget and targetEnabled then
        color = db.target or ns.defaults.target
    elseif state.isFocus and focusEnabled then
        color = db.focus or ns.defaults.focus
    elseif isHostile then
        color = db.hostile or ns.defaults.hostile
    elseif isNeutral then
        color = db.neutral or ns.defaults.neutral
    elseif isTapped then
        color = db.tapped or ns.defaults.tapped
    end
    if color then r, g, b = color.r, color.g, color.b end
    state.currentR, state.currentG, state.currentB = r, g, b
    state.applyingColor = true
    state.health:SetStatusBarColor(r, g, b)
    state.applyingColor = false
    if state.name then state.name:SetTextColor(r, g, b) end
    state.nameOnly = state.isFriendlyPlayer == true and db.friendlyNameOnly ~= false
    if state.specialOverlayNoTint and state.specialOverlay then
        state.specialOverlay:SetVertexColor(r, g, b)
    end
    ApplyVisualAlpha(state)
end

local TARGET_GLOW_TEX = "Interface\\AddOns\\EllesmereUINameplates\\Media\\background.tga"
local TARGET_GLOW_MARGIN, TARGET_GLOW_CORNER, TARGET_GLOW_EXTEND = .48, 12, 6

local function EnsureTargetGlow(state)
    if state.targetGlowFrame then return end
    local frame = CreateFrame("Frame", nil, state.frame)
    frame:SetPoint("TOPLEFT", state.health, "TOPLEFT", -TARGET_GLOW_EXTEND, TARGET_GLOW_EXTEND)
    frame:SetPoint("BOTTOMRIGHT", state.health, "BOTTOMRIGHT", TARGET_GLOW_EXTEND, -TARGET_GLOW_EXTEND)
    frame:SetScale(state.visualScale or 1)
    state.targetGlowFrame = frame
    state.targetGlowTextures = {}

    local function Texture()
        local texture = frame:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture(TARGET_GLOW_TEX)
        texture:SetBlendMode("ADD")
        state.targetGlowTextures[#state.targetGlowTextures + 1] = texture
        return texture
    end

    local tl = Texture(); tl:SetSize(TARGET_GLOW_CORNER, TARGET_GLOW_CORNER); tl:SetPoint("TOPLEFT"); tl:SetTexCoord(0, TARGET_GLOW_MARGIN, 0, TARGET_GLOW_MARGIN)
    local tr = Texture(); tr:SetSize(TARGET_GLOW_CORNER, TARGET_GLOW_CORNER); tr:SetPoint("TOPRIGHT"); tr:SetTexCoord(1 - TARGET_GLOW_MARGIN, 1, 0, TARGET_GLOW_MARGIN)
    local bl = Texture(); bl:SetSize(TARGET_GLOW_CORNER, TARGET_GLOW_CORNER); bl:SetPoint("BOTTOMLEFT"); bl:SetTexCoord(0, TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, 1)
    local br = Texture(); br:SetSize(TARGET_GLOW_CORNER, TARGET_GLOW_CORNER); br:SetPoint("BOTTOMRIGHT"); br:SetTexCoord(1 - TARGET_GLOW_MARGIN, 1, 1 - TARGET_GLOW_MARGIN, 1)
    local top = Texture(); top:SetHeight(TARGET_GLOW_CORNER); top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("TOPRIGHT", tr, "TOPLEFT"); top:SetTexCoord(TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, 0, TARGET_GLOW_MARGIN)
    local bottom = Texture(); bottom:SetHeight(TARGET_GLOW_CORNER); bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT"); bottom:SetTexCoord(TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, 1)
    local left = Texture(); left:SetWidth(TARGET_GLOW_CORNER); left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT"); left:SetTexCoord(0, TARGET_GLOW_MARGIN, TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN)
    local right = Texture(); right:SetWidth(TARGET_GLOW_CORNER); right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT"); right:SetTexCoord(1 - TARGET_GLOW_MARGIN, 1, TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN)
    local center = Texture(); center:SetPoint("TOPLEFT", left, "TOPRIGHT"); center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT"); center:SetTexCoord(TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN, TARGET_GLOW_MARGIN, 1 - TARGET_GLOW_MARGIN)
    frame:Hide()
end

local function EnsureEmphasisTextures(state)
    if state.specialOverlay then return end
    state.specialOverlay = state.health:CreateTexture(nil, "OVERLAY")
    state.specialOverlay:SetAllPoints(state.health)
    state.specialOverlay:Hide()
    state.targetHighlight = state.health:CreateTexture(nil, "OVERLAY")
    state.targetHighlight:SetTexture(WHITE)
    state.targetHighlight:SetAllPoints(state.health)
    state.targetHighlight:Hide()
    state.hoverOverlay = state.health:CreateTexture(nil, "OVERLAY")
    state.hoverOverlay:SetAllPoints(state.health)
    state.hoverOverlay:Hide()
end

local function EnsureTargetArrows(state)
    if state.leftArrow then return end
    local parent = state.visualFrame or state.frame
    state.leftArrow = parent:CreateTexture(nil, "OVERLAY")
    state.rightArrow = parent:CreateTexture(nil, "OVERLAY")
    state.leftArrow:Hide()
    state.rightArrow:Hide()
end

local function EnsureFocusLetter(state)
    if state.focusLetter then return end
    local parent = state.visualFrame or state.frame
    state.focusLetter = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    state.focusLetter:SetJustifyH("CENTER")
    state.focusLetter:SetJustifyV("MIDDLE")
    state.focusLetter:SetText("F")
    state.focusLetter:Hide()
end

local function ApplySpecialOverlay(state)
    local db = DB()
    local textureKey, alpha, color, noTint
    local targetTexture = db.targetOverlayTexture or "none"
    local focusTexture = db.focusOverlayTexture or "striped-v2"
    if state.isTarget and targetTexture ~= "none" then
        textureKey = targetTexture
        alpha = db.targetOverlayAlpha or 1
        color = db.targetOverlayColor or { r = 1, g = 1, b = 1 }
        noTint = db.targetOverlayNoTint == true
    elseif state.isFocus and focusTexture ~= "none" then
        textureKey = focusTexture
        alpha = db.focusOverlayAlpha or 1
        color = db.focusOverlayColor or { r = 1, g = 1, b = 1 }
        noTint = db.focusOverlayNoTint == true
    end

    if not textureKey then
        state.specialOverlayNoTint = nil
        if state.specialOverlay then state.specialOverlay:Hide() end
        return
    end
    EnsureEmphasisTextures(state)
    local path = ns.ResolveOverlayTexPath and ns.ResolveOverlayTexPath(textureKey) or ResolveTexture(textureKey)
    state.specialOverlay:SetTexture(path or WHITE)
    if noTint then
        state.specialOverlay:SetVertexColor(state.currentR or 1, state.currentG or 1, state.currentB or 1)
        state.specialOverlayNoTint = true
    else
        state.specialOverlay:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
        state.specialOverlayNoTint = nil
    end
    state.specialOverlay:SetAlpha(alpha)
    state.specialOverlay:Show()
end

local function ApplyTargetGlow(state)
    local shown = state.isTarget and ns.GetTargetGlowEllesmereUI
        and ns.GetTargetGlowEllesmereUI()
    if not shown then
        if state.targetGlowFrame then state.targetGlowFrame:Hide() end
        return
    end
    EnsureTargetGlow(state)
    local color = ns.GetTargetGlowColor and ns.GetTargetGlowColor()
        or DB().targetGlowColor or { r = .4117, g = .6667, b = 1 }
    local alpha = ns.GetTargetGlowAlpha and ns.GetTargetGlowAlpha()
        or DB().targetGlowAlpha or 1
    for _, texture in ipairs(state.targetGlowTextures) do
        texture:SetVertexColor(color.r, color.g, color.b)
        texture:SetAlpha(alpha)
    end
    state.targetGlowFrame:Show()
end

local function ApplyTargetArrows(state)
    local db = DB()
    if not (state.isTarget and db.showTargetArrows) then
        if state.leftArrow then state.leftArrow:Hide(); state.rightArrow:Hide() end
        return
    end
    EnsureTargetArrows(state)
    local style = ns.ResolveTargetArrowStyle and ns.ResolveTargetArrowStyle(db)
        or { l = "arrow_left", r = "arrow_right", w = 11 }
    local scale = db.targetArrowScale or 1
    local width = floor((style.w or 11) * scale + .5)
    local height = floor(16 * scale + .5)
    local directory = ns.TARGET_ARROW_DIR
        or "Interface\\AddOns\\EllesmereUINameplates\\Media\\Arrows\\"
    state.leftArrow:SetTexture(directory .. style.l .. ".tga")
    state.rightArrow:SetTexture(directory .. style.r .. ".tga")
    state.leftArrow:SetSize(width, height)
    state.rightArrow:SetSize(width, height)
    local r, g, b = 1, 1, 1
    if ns.GetTargetArrowColor then r, g, b = ns.GetTargetArrowColor(db) end
    state.leftArrow:SetVertexColor(r, g, b)
    state.rightArrow:SetVertexColor(r, g, b)
    state.leftArrow:ClearAllPoints()
    state.rightArrow:ClearAllPoints()
    state.leftArrow:SetPoint("RIGHT", state.health, "LEFT", -3, 0)
    state.rightArrow:SetPoint("LEFT", state.health, "RIGHT", 3, 0)
    state.leftArrow:Show()
    state.rightArrow:Show()
end

local function ApplyFocusLetter(state)
    local db = DB()
    if not (state.isFocus and db.focusLetterEnabled == true) then
        if state.focusLetter then state.focusLetter:Hide() end
        return
    end
    EnsureFocusLetter(state)
    local size = db.focusLetterSize or 18
    local anchor = ns.GetFocusLetterAnchor and ns.GetFocusLetterAnchor(db) or "CENTER"
    ns.SetFSFont(state.focusLetter, size, ns.GetNPOutline())
    state.focusLetter:ClearAllPoints()
    state.focusLetter:SetPoint(anchor, state.health, anchor,
        db.focusLetterX or 0, db.focusLetterY or 0)
    state.focusLetter:SetTextColor(1, 1, 1, 1)
    state.focusLetter:Show()
end

local function ApplyTargetScale(state)
    local scale = 1
    if state.isTarget then
        scale = (tonumber(DB().targetScale) or 100) / 100
        if scale < .5 then scale = .5 elseif scale > 2 then scale = 2 end
    end
    if state.visualScale == scale then return end
    state.visualScale = scale
    state.health:SetScale(scale)
    if state.cast then state.cast:SetScale(scale) end
    if state.visualFrame then state.visualFrame:SetScale(scale) end
    if state.targetGlowFrame then state.targetGlowFrame:SetScale(scale) end
end

local function ResolveSpecialOwners()
    local oldTarget, oldFocus, oldMouseover = targetOwner, focusOwner, mouseoverOwner
    local targetFallback, focusFallback, mouseoverFallback
    local newTarget, newMouseover
    local hasTarget = UnitExists("target")
    local hasFocus = UnitExists("focus")
    local hasMouseover = UnitExists("mouseover")

    for _, state in pairs(plates) do
        if state.frame:IsShown() then
            if hasTarget and PlateIdentityMatchesUnit(state, "target") then
                targetFallback = targetFallback or state
                local alpha = state.frame:GetAlpha()
                if alpha and alpha >= .99 and (not newTarget or state == oldTarget) then
                    newTarget = state
                end
            end
            if hasFocus and PlateIdentityMatchesUnit(state, "focus") then
                focusFallback = focusFallback or state
            end
            if hasMouseover then
                if state.nativeHighlight and state.nativeHighlight:IsShown() then
                    newMouseover = state
                elseif PlateIdentityMatchesUnit(state, "mouseover") then
                    if state == oldMouseover then
                        mouseoverFallback = state
                    else
                        mouseoverFallback = mouseoverFallback or state
                    end
                end
            end
        end
    end

    if not newTarget and oldTarget and oldTarget.frame:IsShown()
        and PlateIdentityMatchesUnit(oldTarget, "target") then
        newTarget = oldTarget
    end
    targetOwner = hasTarget and (newTarget or targetFallback) or nil
    mouseoverOwner = hasMouseover and (newMouseover or mouseoverFallback) or nil

    if hasFocus and UnitIsUnit and targetOwner and UnitIsUnit("focus", "target") then
        focusOwner = targetOwner
    elseif hasFocus and UnitIsUnit and mouseoverOwner and UnitIsUnit("focus", "mouseover") then
        focusOwner = mouseoverOwner
    elseif hasFocus and oldFocus and oldFocus.frame:IsShown()
        and PlateIdentityMatchesUnit(oldFocus, "focus") then
        focusOwner = oldFocus
    else
        focusOwner = hasFocus and focusFallback or nil
    end
end

local function UpdateEmphasis(state, force)
    local isTarget = state == targetOwner
    local isFocus = state == focusOwner
    local isMouseover = state == mouseoverOwner
    local changed = state.isTarget ~= isTarget or state.isFocus ~= isFocus
        or state.isMouseover ~= isMouseover
    state.isTarget, state.isFocus, state.isMouseover = isTarget, isFocus, isMouseover

    if changed or force then
        local r, g, b = state.nativeR, state.nativeG, state.nativeB
        if not r then r, g, b = state.health:GetStatusBarColor() end
        ApplyReactionColor(state, r or 1, g or 0, b or 0)

        local db = DB()
        local borderColor = db.borderColor or ns.defaults.borderColor
        local borderSize = db.borderSize or 1
        if isTarget and ns.GetTargetGlowBorderColor and ns.GetTargetGlowBorderColor() then
            borderColor = ns.GetTargetBorderColor and ns.GetTargetBorderColor()
                or db.targetBorderColor or borderColor
        end
        if isTarget and ns.GetTargetGlowBorderSize and ns.GetTargetGlowBorderSize() then
            borderSize = ns.GetTargetBorderSizeValue and ns.GetTargetBorderSizeValue()
                or db.targetBorderSizeValue or borderSize
        end
        SetBorderSize(state.healthBorder, borderSize)
        SetBorder(state.healthBorder, db.showBorder ~= false and borderSize > 0, borderColor)
        ApplySpecialOverlay(state)
        ApplyTargetGlow(state)
        ApplyTargetArrows(state)
        ApplyFocusLetter(state)
        ApplyTargetScale(state)

        EnsureEmphasisTextures(state)
        if isTarget and ns.GetTargetGlowHighlight and ns.GetTargetGlowHighlight() then
            local color = ns.GetTargetHighlightColor and ns.GetTargetHighlightColor()
                or db.targetHighlightColor or { r = 1, g = 1, b = 1 }
            local alpha = ns.GetTargetHighlightAlpha and ns.GetTargetHighlightAlpha()
                or db.targetHighlightAlpha or .2
            state.targetHighlight:SetVertexColor(color.r, color.g, color.b)
            state.targetHighlight:SetAlpha(alpha)
            state.targetHighlight:Show()
        else
            state.targetHighlight:Hide()
        end

        if isMouseover then
            local color = db.hoverColor or { r = 1, g = 1, b = 1 }
            local alpha = db.hoverAlpha or .3
            local textureKey = db.hoverOverlayTexture or "none"
            local path = textureKey ~= "none" and ns.ResolveOverlayTexPath
                and ns.ResolveOverlayTexPath(textureKey)
            state.hoverOverlay:SetTexture(path or WHITE)
            state.hoverOverlay:SetVertexColor(color.r, color.g, color.b)
            state.hoverOverlay:SetAlpha(alpha)
            state.hoverOverlay:Show()
        else
            state.hoverOverlay:Hide()
        end
    end
    -- The opacity slider is a live setting whose modern callback does not own
    -- legacy plates; value guards make this cheap when nothing changed.
    ApplyVisualAlpha(state)
end

local function SettingChanged(key, value)
    if emphasisSettings[key] == value then return false end
    emphasisSettings[key] = value
    return true
end

local function ColorSettingChanged(keyR, keyG, keyB, color)
    color = color or emphasisSettings
    local rChanged = SettingChanged(keyR, color.r)
    local gChanged = SettingChanged(keyG, color.g)
    local bChanged = SettingChanged(keyB, color.b)
    return rChanged or gChanged or bChanged
end

-- Most option callbacks target the modern unit-token plate pool. Poll this
-- small scalar fingerprint once per driver tick so the same controls also
-- update visible Wrath plates immediately without changing the options code.
local function EmphasisSettingsChanged()
    local db = DB()
    local changed = false
    changed = SettingChanged("targetColorEnabled", db.targetColorEnabled) or changed
    changed = ColorSettingChanged("targetR", "targetG", "targetB", db.target) or changed
    changed = SettingChanged("focusColorEnabled", db.focusColorEnabled) or changed
    changed = ColorSettingChanged("focusR", "focusG", "focusB", db.focus) or changed
    changed = SettingChanged("targetGlowEUI", ns.GetTargetGlowEllesmereUI and ns.GetTargetGlowEllesmereUI()) or changed
    changed = SettingChanged("targetGlowBorder", ns.GetTargetGlowBorderColor and ns.GetTargetGlowBorderColor()) or changed
    changed = SettingChanged("targetGlowHighlight", ns.GetTargetGlowHighlight and ns.GetTargetGlowHighlight()) or changed
    changed = SettingChanged("targetGlowBorderSize", ns.GetTargetGlowBorderSize and ns.GetTargetGlowBorderSize()) or changed
    changed = SettingChanged("targetBorderSizeValue", db.targetBorderSizeValue) or changed
    changed = ColorSettingChanged("targetGlowR", "targetGlowG", "targetGlowB", db.targetGlowColor) or changed
    changed = SettingChanged("targetGlowAlpha", db.targetGlowAlpha) or changed
    changed = ColorSettingChanged("targetBorderR", "targetBorderG", "targetBorderB", db.targetBorderColor) or changed
    changed = ColorSettingChanged("targetHighlightR", "targetHighlightG", "targetHighlightB", db.targetHighlightColor) or changed
    changed = SettingChanged("targetHighlightAlpha", db.targetHighlightAlpha) or changed
    changed = SettingChanged("showTargetArrows", db.showTargetArrows) or changed
    changed = SettingChanged("targetScale", db.targetScale) or changed
    changed = SettingChanged("targetArrowStyle", db.targetArrowStyle) or changed
    changed = SettingChanged("targetArrowDouble", db.targetArrowDouble) or changed
    changed = SettingChanged("targetArrowScale", db.targetArrowScale) or changed
    changed = SettingChanged("targetArrowClassColor", db.targetArrowClassColor) or changed
    changed = ColorSettingChanged("targetArrowR", "targetArrowG", "targetArrowB", db.targetArrowColor) or changed
    changed = SettingChanged("targetOverlayTexture", db.targetOverlayTexture) or changed
    changed = SettingChanged("targetOverlayAlpha", db.targetOverlayAlpha) or changed
    changed = SettingChanged("targetOverlayNoTint", db.targetOverlayNoTint) or changed
    changed = ColorSettingChanged("targetOverlayR", "targetOverlayG", "targetOverlayB", db.targetOverlayColor) or changed
    changed = SettingChanged("focusOverlayTexture", db.focusOverlayTexture) or changed
    changed = SettingChanged("focusOverlayAlpha", db.focusOverlayAlpha) or changed
    changed = SettingChanged("focusOverlayNoTint", db.focusOverlayNoTint) or changed
    changed = ColorSettingChanged("focusOverlayR", "focusOverlayG", "focusOverlayB", db.focusOverlayColor) or changed
    changed = SettingChanged("focusLetterEnabled", db.focusLetterEnabled) or changed
    changed = SettingChanged("focusLetterAnchor", db.focusLetterAnchor) or changed
    changed = SettingChanged("focusLetterX", db.focusLetterX) or changed
    changed = SettingChanged("focusLetterY", db.focusLetterY) or changed
    changed = SettingChanged("focusLetterSize", db.focusLetterSize) or changed
    changed = SettingChanged("hoverOverlayTexture", db.hoverOverlayTexture) or changed
    changed = SettingChanged("hoverAlpha", db.hoverAlpha) or changed
    changed = ColorSettingChanged("hoverR", "hoverG", "hoverB", db.hoverColor) or changed
    changed = SettingChanged("showBorder", db.showBorder) or changed
    changed = SettingChanged("borderSize", db.borderSize) or changed
    changed = ColorSettingChanged("borderR", "borderG", "borderB", db.borderColor) or changed
    return changed
end

-- Keep nearer plates above farther ones, with the current target always last
-- (highest). This mirrors RefinedBlizzPlates' depth sort and prevents text,
-- auras, and cast bars from a distant plate painting over a nearer plate.
local function UpdateDepthOrder()
    for i = #depthOrder, 1, -1 do depthOrder[i] = nil end
    for _, state in pairs(plates) do
        if state.frame:IsShown() then
            local depth = state.frame.GetEffectiveDepth and state.frame:GetEffectiveDepth() or 0
            state.depth = depth and depth > 0 and depth or 0
            depthOrder[#depthOrder + 1] = state
        end
    end
    sort(depthOrder, function(a, b)
        if a.isTarget ~= b.isTarget then return not a.isTarget end
        if a.depth ~= b.depth then return a.depth > b.depth end
        return a.serial < b.serial
    end)
    for index, state in ipairs(depthOrder) do
        local base = index * 6
        state.health:SetFrameLevel(base)
        if state.cast then state.cast:SetFrameLevel(max(1, base - 1)) end
        if state.visualFrame then state.visualFrame:SetFrameLevel(base + 2) end
        if state.targetGlowFrame then state.targetGlowFrame:SetFrameLevel(max(1, base - 1)) end
        if state.debuffs then
            for _, slot in ipairs(state.debuffs) do slot:SetFrameLevel(base + 3) end
        end
    end
end

local function PositionHealthText(state)
    local db = DB()
    local slots = {
        { key = "textSlotRight", point = "RIGHT", relative = "RIGHT", x = -2, y = 0 },
        { key = "textSlotLeft", point = "LEFT", relative = "LEFT", x = 2, y = 0 },
        { key = "textSlotCenter", point = "CENTER", relative = "CENTER", x = 0, y = 0 },
        { key = "textSlotTop", point = "BOTTOM", relative = "TOP", x = 0, y = 3 },
    }
    state.healthText:ClearAllPoints()
    state.healthText:Hide()
    state.healthTextShown = false
    state.healthElement = nil
    state.value = nil
    for _, slot in ipairs(slots) do
        local element = db[slot.key]
        if element == "healthPercent" or element == "healthPercentNoSign" then
            local x = slot.x + (db[slot.key .. "XOffset"] or 0)
            local y = slot.y + (db[slot.key .. "YOffset"] or 0)
            state.healthText:SetPoint(slot.point, state.health, slot.relative, x, y)
            ns.SetFSFont(state.healthText, db[slot.key .. "Size"] or 9, ns.GetNPOutline())
            local color = db[slot.key .. "Color"]
            if color then state.healthText:SetTextColor(color.r, color.g, color.b, 1) end
            state.healthElement = element
            state.healthText:Show()
            break
        end
    end
end

local function RefreshAppearance(state)
    local db, health = DB(), state.health
    for _, fs in ipairs(state.sourceFonts) do SuppressSourceFont(fs) end
    for _, texture in ipairs(state.hiddenArt) do texture:SetAlpha(0) end
    local width = ns.GetHealthBarWidth and ns.GetHealthBarWidth() or 120
    local height = ns.GetHealthBarHeight and ns.GetHealthBarHeight() or 12
    health:SetWidth(width)
    health:SetHeight(height)
    health:SetStatusBarTexture(ResolveTexture(db.healthBarTexture))
    local bg = db.bgColor or ns.defaults.bgColor
    state.bg:SetVertexColor(bg.r, bg.g, bg.b, db.bgAlpha or ns.defaults.bgAlpha or 1)
    local borderSize = db.borderSize or ns.defaults.borderSize or 1
    SetBorderSize(state.healthBorder, borderSize)
    SetBorder(state.healthBorder, db.showBorder ~= false and borderSize > 0,
        db.borderColor or ns.defaults.borderColor)

    if state.cast then
        local castHeight = ns.GetCastBarHeight and ns.GetCastBarHeight() or 8
        state.cast:ClearAllPoints()
        state.cast:SetPoint("TOP", health, "BOTTOM", 0, -2)
        state.cast:SetWidth(width)
        state.cast:SetHeight(castHeight)
        state.cast:SetStatusBarTexture(ResolveTexture(db.castBarTexture))
        SetBorderSize(state.castBorder, db.castBorderSize or 0)
        SetBorder(state.castBorder, (db.castBorderSize or 0) > 0,
            db.castBorderColor or ns.defaults.castBorderColor)
    end
    ns.SetFSFont(state.name, db.enemyNameTextSize or 11, ns.GetNPOutline())
    state.name:ClearAllPoints()
    state.name:SetPoint("BOTTOM", health, "TOP", 0, 3 + (db.nameYOffset or 0))
    ns.SetFSFont(state.level, 9, ns.GetNPOutline())
    state.level:ClearAllPoints()
    state.level:SetPoint("LEFT", health, "RIGHT", 4, 0)
    PositionHealthText(state)
    StyleDebuffSlots(state)
    LayoutDebuffSlots(state, state.debuffCount or 0)
    if state.castBg then
        local castBg = db.castBgColor or ns.defaults.castBgColor
        state.castBg:SetVertexColor(castBg.r, castBg.g, castBg.b,
            db.castBgAlpha or ns.defaults.castBgAlpha or .9)
    end
    if state.castFonts then
        for _, fs in ipairs(state.castFonts) do
            ns.SetFSFont(fs, db.castNameSize or 10, ns.GetNPOutline())
            local color = db.castNameColor or ns.defaults.castNameColor
            if color then fs:SetTextColor(color.r, color.g, color.b, 1) end
        end
    end
    if state.raidIcon then
        state.raidIcon:ClearAllPoints()
        state.raidIcon:SetPoint("BOTTOM", health, "TOP", 0, 15)
        state.raidIcon:SetWidth(18)
        state.raidIcon:SetHeight(18)
    end
    UpdateEmphasis(state, true)
end

local function RefreshValues(state)
    if not state.frame:IsShown() then return end
    -- The 3.3.5 engine can mutate native nameplate regions from C without
    -- passing through Lua method hooks.  Reassert suppression on each driver
    -- update so Blizzard's own white name/level text cannot reappear.
    for _, fs in ipairs(state.sourceFonts) do SuppressSourceFont(fs) end
    local minimum, maximum = state.health:GetMinMaxValues()
    local value = state.health:GetValue()
    if state.value ~= value or state.maximum ~= maximum then
        state.value, state.maximum = value, maximum
        local pct = maximum and maximum > 0 and math.floor(value / maximum * 100 + .5) or 0
        local suffix = state.healthElement == "healthPercentNoSign" and "" or "%"
        state.healthText:SetText(pct .. suffix)
    end
    local name = state.nameSource and state.nameSource:GetText() or ""
    if name ~= state.nameValue then state.nameValue = name; state.name:SetText(name) end
    local level = state.levelSource and state.levelSource:GetText() or ""
    if level ~= state.levelValue then state.levelValue = level; state.level:SetText(level) end
end

local function Skin(frame)
    if plates[frame] then return end
    local health, cast, nameSource, levelSource, raidIcon, fonts, hiddenArt, nativeHighlight = FindParts(frame)
    if not health then return end
    nextPlateSerial = nextPlateSerial + 1
    local state = { frame = frame, health = health, cast = cast, nameSource = nameSource,
        levelSource = levelSource, raidIcon = raidIcon, sourceFonts = fonts, hiddenArt = hiddenArt,
        nativeHighlight = nativeHighlight, serial = nextPlateSerial }
    state.nativeR, state.nativeG, state.nativeB = health:GetStatusBarColor()
    plates[frame] = state
    for _, fs in ipairs(fonts) do SuppressSourceFont(fs) end

    -- One carrier owns every replacement region. Its frame level is updated by
    -- the depth sorter without changing the native plate's click handling.
    state.visualFrame = CreateFrame("Frame", nil, frame)
    state.visualFrame:SetAllPoints(frame)
    state.bg = health:CreateTexture(nil, "BACKGROUND")
    state.bg:SetTexture(WHITE)
    state.bg:SetAllPoints(health)
    state.healthBorder = CreateBorder(health)
    -- Prime with a built-in FontObject as an additional legacy-client safety
    -- net; SetFSFont replaces it with the configured font when supported.
    state.name = state.visualFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    state.level = state.visualFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    state.healthText = state.visualFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- The native raid marker remains engine-driven, but follows our sorted
    -- visual layer so it cannot be buried by a farther plate.
    if raidIcon and raidIcon.SetParent then raidIcon:SetParent(state.visualFrame) end
    if cast then
        state.castBorder = CreateBorder(cast)
        state.castBg = cast:CreateTexture(nil, "BACKGROUND")
        state.castBg:SetTexture(WHITE)
        state.castBg:SetAllPoints(cast)
        state.castFonts = {}
        for i = 1, RegionCount(cast) do
            local region = select(i, cast:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                state.castFonts[#state.castFonts + 1] = region
            end
        end
    end

    hooksecurefunc(health, "SetStatusBarColor", function(_, r, g, b)
        if not state.applyingColor then
            state.nativeR, state.nativeG, state.nativeB = r, g, b
            ApplyReactionColor(state, r, g, b)
        end
    end)
    frame:HookScript("OnShow", function()
        -- If the SetStatusBarColor Lua hook has not fired for this plate show
        -- (Blizzard used a C-level colour update that bypassed Lua), nativeR/G/B
        -- is stale from the previous unit.  Read GetStatusBarColor() now: the
        -- C engine always sets the bar colour before firing OnShow on the parent
        -- frame, so this is authoritative for the current unit.
        if not state.nativeR then
            local r, g, b = state.health:GetStatusBarColor()
            state.nativeR, state.nativeG, state.nativeB = r, g, b
        end
        RefreshAppearance(state)
        RefreshValues(state)
    end)
    frame:HookScript("OnHide", function()
        -- Clear the cached native colour so it cannot leak into the next unit
        -- that reuses this plate frame.  The next OnShow will re-read it fresh.
        state.nativeR, state.nativeG, state.nativeB = nil, nil, nil
        state.isTarget, state.isFocus, state.isMouseover = false, false, false
        ClearDebuffs(state)
    end)

    RefreshAppearance(state)
    RefreshValues(state)
end

local function Discover()
    local count = ChildCount(WorldFrame)
    if count < lastWorldChildCount then lastWorldChildCount = 0 end
    if count == lastWorldChildCount then return end
    local children = { WorldFrame:GetChildren() }
    -- GetChildren order is not contractual. Rescan the list when its size
    -- changes and let the weak plate map make already-known frames O(1).
    for i = 1, count do
        local frame = children[i]
        if not plates[frame] and IsLegacyNameplate(frame) then Skin(frame) end
    end
    lastWorldChildCount = count
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < .05 then return end
    elapsed = 0
    Discover()
    ResolveSpecialOwners()
    local refreshEmphasis = EmphasisSettingsChanged()
    local now = GetTime()
    for _, state in pairs(plates) do
        RefreshValues(state)
        if state.frame:IsShown() then
            UpdateEmphasis(state, refreshEmphasis)
            RefreshDebuffs(state, now)
        end
    end
    UpdateDepthOrder()
end)
driver:Hide()

function ns.LegacyRefreshAll()
    ResolveSpecialOwners()
    for _, state in pairs(plates) do
        RefreshAppearance(state)
        RefreshValues(state)
    end
    UpdateDepthOrder()
end

function ns.LegacyEnable()
    if enabled then return end
    enabled = true
    -- These are real 3.3.5 CVars. Private-server variants differ, so isolate
    -- every optional write instead of allowing one absent CVar to abort setup.
    if SetCVar then
        pcall(SetCVar, "nameplateShowEnemies", 1)
        pcall(SetCVar, "nameplateShowAll", 1)
        pcall(SetCVar, "nameplateShowFriends", DB().showFriendlyPlayers == false and 0 or 1)
        pcall(SetCVar, "nameplateShowEnemyPets", DB().showEnemyPets == true and 1 or 0)
    end
    driver:Show()
    Discover()
end

function ns.ForceFriendlyPlayerCVarsOn()
    if SetCVar then pcall(SetCVar, "nameplateShowFriends", 1) end
end

function ns.UpdateFriendlyNameplateSystem()
    if SetCVar then
        pcall(SetCVar, "nameplateShowFriends", DB().showFriendlyPlayers == false and 0 or 1)
    end
    ns.LegacyRefreshAll()
end
