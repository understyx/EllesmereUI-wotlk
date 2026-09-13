-------------------------------------------------------------------------------
--  EllesmereUISwingBars.lua
--  Main-hand, off-hand, and Hunter Auto Shot swing timers.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local ESB = EllesmereUI.Lite.NewAddon(ADDON_NAME)
ns.ESB = ESB

local DEFAULT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local TEX_BASE = "Interface\\AddOns\\EllesmereUI\\media\\textures\\"

ns.BAR_TEXTURES = {
    blizzard            = DEFAULT_TEXTURE,
    flat                = "Interface\\Buttons\\WHITE8x8",
    melli               = TEX_BASE .. "melli.tga",
    atrocity            = TEX_BASE .. "atrocity.tga",
    fade                = TEX_BASE .. "fade.tga",
    ["fade-right"]      = TEX_BASE .. "fade-right.tga",
    beautiful           = TEX_BASE .. "beautiful.tga",
    plating             = TEX_BASE .. "plating.tga",
    divide              = TEX_BASE .. "divide.tga",
    glass               = TEX_BASE .. "glass.tga",
    ["gradient-lr"]     = TEX_BASE .. "gradient-lr.tga",
    ["gradient-rl"]     = TEX_BASE .. "gradient-rl.tga",
    matte               = TEX_BASE .. "matte.tga",
    sheer               = TEX_BASE .. "sheer.tga",
}
ns.BAR_TEXTURE_NAMES = {
    blizzard        = "Blizzard",
    flat            = "Flat",
    melli           = "Melli (ElvUI)",
    atrocity        = "Atrocity",
    fade            = "Fade",
    ["fade-right"]  = "Fade Right",
    beautiful       = "Beautiful",
    plating         = "Plating",
    divide          = "Divide",
    glass           = "Glass",
    ["gradient-lr"] = "Gradient Right",
    ["gradient-rl"] = "Gradient Left",
    matte           = "Matte",
    sheer           = "Sheer",
}
ns.BAR_TEXTURE_ORDER = {
    "blizzard", "flat", "melli", "atrocity", "fade", "fade-right",
    "beautiful", "plating", "divide", "glass", "gradient-lr",
    "gradient-rl", "matte", "sheer",
}

if EllesmereUI.AppendSharedMediaTextures then
    EllesmereUI.AppendSharedMediaTextures(
        ns.BAR_TEXTURE_NAMES, ns.BAR_TEXTURE_ORDER, nil, ns.BAR_TEXTURES)
end

local defaults = {
    profile = {
        enabled         = true,
        width           = 200,
        barHeight       = 12,
        barSpacing      = 2,
        barTexture      = "blizzard",
        showLabels      = true,
        fontSize        = 10,
        showBorder      = true,
        hunterMeleeDoesNotResetRanged = true,
        mainHandColor   = { r = 0.40, g = 0.60, b = 1.00, a = 1 },
        offHandColor    = { r = 1.00, g = 0.50, b = 0.20, a = 1 },
        rangedColor     = { r = 0.30, g = 1.00, b = 0.50, a = 1 },
        backgroundColor = { r = 0.04, g = 0.05, b = 0.06, a = 0.80 },
        borderColor     = { r = 0, g = 0, b = 0, a = 1 },
        position        = { point = "CENTER", relPoint = "CENTER", x = 0, y = -100 },
    },
}
ns.defaults = defaults

-- Mirrors WeakAuras-WotLK's swing reset lists. Spell names are resolved at
-- runtime so every rank and client locale follows the same path.
local RESET_SWING_SPELL_IDS = {
    57755,  -- Heroic Throw
    64382,  -- Shattering Throw
    78,     -- Heroic Strike
    845,    -- Cleave
    2973,   -- Raptor Strike
    6807,   -- Maul
    20549,  -- War Stomp
    56815,  -- Rune Strike
    5384,   -- Feign Death
    2764,   -- Throw
    5019,   -- Shoot
}
local NEXT_SWING_SPELL_IDS = {
    78,     -- Heroic Strike
    845,    -- Cleave
    2973,   -- Raptor Strike
    6807,   -- Maul
    56815,  -- Rune Strike
}
local RESET_RANGED_SWING_SPELL_IDS = {
    2764,   -- Throw
    5019,   -- Shoot
    75,     -- Auto Shot
    5384,   -- Feign Death
}
local PAUSE_SWING_SPELL_IDS = {
    1464,   -- Slam
}
local NO_RESET_ON_CAST_START_IDS = {
    23063, 4054, 4064, 4061, 8331, 4065, 4066, 4062, 4067, 4068,
    23000, 12421, 4069, 12562, 12543, 19769, 19784, 30216, 19821,
    39965, 30461, 30217, 35476, 35475, 35477, 35478,
    34120,  -- Steady Shot
    19434,  -- Aimed Shot
    1464,   -- Slam
}

local db
local container
local bars = {}
local activeBars = {}
local activeOrder = {}
local playerClass
local playerGUID
local resetSwingSpells = {}
local nextSwingSpells = {}
local resetRangedSwingSpells = {}
local pauseSwingSpells = {}
local noResetOnCastStart = {}
local casting = false
local isAttacking = false
local isShooting = false
local skipNextAttackTime
local skipNextAttackCount = 0
local mainResetQueued = false
local pauseSwingTime
local pausedSwingMain, pausedSwingOff
local plannedSwingMain, plannedSwingOff = 0, 0
local offSwingOffset = false
local mainSpeed, offSpeed, rangedSpeed
local timingGeneration = 0
local eventsActive = false

local function Profile()
    return db and db.profile
end
ns.GetProfile = Profile

local function GetTexturePath(key)
    if EllesmereUI.ResolveTexturePath then
        return EllesmereUI.ResolveTexturePath(ns.BAR_TEXTURES, key, DEFAULT_TEXTURE)
    end
    return ns.BAR_TEXTURES[key] or DEFAULT_TEXTURE
end

local function ApplyPosition()
    local p = Profile()
    if not p or not container then return end
    local pos = p.position or defaults.profile.position
    container:ClearAllPoints()
    container:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or pos.point or "CENTER", pos.x or 0, pos.y or -100)
end
ns.ApplyPosition = ApplyPosition

local function CreateBar(id)
    local bar = EllesmereUI.SafeCreateFrame("StatusBar", nil, container)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.id = id

    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetAllPoints()
    bar.background:SetTexture("Interface\\Buttons\\WHITE8x8")

    bar.border = EllesmereUI.MakeBorder(bar, 0, 0, 0, 1)
    bar.text = EllesmereUI.MakeFont(bar, 10, nil, 1, 1, 1, 0.95)
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)

    bars[id] = bar
    return bar
end

local function EnsureFrames()
    if container then return end
    container = EllesmereUI.SafeCreateFrame("Frame", "EllesmereUISwingBarsFrame", UIParent)
    container:SetClampedToScreen(true)
    container:Hide()
    CreateBar("MH")
    CreateBar("OH")
    CreateBar("RANGED")
    ApplyPosition()
end

local function SetBarStyle(bar, label, color)
    local p = Profile()
    bar:SetStatusBarTexture(GetTexturePath(p.barTexture))
    bar:SetStatusBarColor(color.r or 1, color.g or 1, color.b or 1)
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetAlpha(color.a or 1) end
    bar:SetSize(p.width, p.barHeight)
    bar.background:SetTexture("Interface\\Buttons\\WHITE8x8")
    local bg = p.backgroundColor
    bar.background:SetVertexColor(bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 0.8)
    local bc = p.borderColor
    bar.border:SetColor(bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)
    if p.showBorder then bar.border._frame:Show() else bar.border._frame:Hide() end
    local font = EllesmereUI.GetFontPath and EllesmereUI.GetFontPath("swingBars")
        or EllesmereUI._font or "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.ttf"
    local outline = EllesmereUI.GetFontOutlineFlag and EllesmereUI.GetFontOutlineFlag("swingBars") or "OUTLINE"
    bar.text:SetFont(font, p.fontSize, outline)
    bar.text:SetText(EllesmereUI.L(label))
    if p.showLabels then bar.text:Show() else bar.text:Hide() end
end

local function ResetAnimation(bar)
    bar.restartToken = (bar.restartToken or 0) + 1
    bar.pendingRestart = false
    bar.pendingRestartSeen = false
    bar.pendingSpeed = nil
    bar.pendingStartTime = nil
    bar.lastEventTime = nil
    bar.isAnimating = false
    bar.paused = false
    bar.startTime = nil
    bar.duration = nil
    bar.lastTick = nil
    bar:SetValue(0)
end

local function ResetTimingState()
    timingGeneration = timingGeneration + 1
    casting = false
    mainResetQueued = false
    pauseSwingTime = nil
    pausedSwingMain = nil
    pausedSwingOff = nil
    plannedSwingMain = 0
    plannedSwingOff = 0
    offSwingOffset = false
    skipNextAttackTime = nil
    skipNextAttackCount = 0
end

local function LayoutBars()
    EnsureFrames()
    local p = Profile()
    ResetTimingState()
    wipe(activeBars)
    wipe(activeOrder)

    for _, bar in pairs(bars) do
        ResetAnimation(bar)
        bar:Hide()
        bar:ClearAllPoints()
    end

    if not p or not p.enabled then
        container:SetScript("OnUpdate", nil)
        container:Hide()
        return
    end

    mainSpeed, offSpeed = UnitAttackSpeed("player")
    offSpeed = offSpeed or 0
    rangedSpeed = UnitRangedDamage("player")
    if mainSpeed and mainSpeed > 0 then activeOrder[#activeOrder + 1] = "MH" end
    if offSpeed > 0 then activeOrder[#activeOrder + 1] = "OH" end
    if playerClass == "HUNTER" and GetInventoryItemLink("player", INVSLOT_RANGED) then
        activeOrder[#activeOrder + 1] = "RANGED"
    end

    local colors = {
        MH = p.mainHandColor,
        OH = p.offHandColor,
        RANGED = p.rangedColor,
    }
    local labels = { MH = "Main Hand", OH = "Off Hand", RANGED = "Ranged" }
    for i, id in ipairs(activeOrder) do
        local bar = bars[id]
        SetBarStyle(bar, labels[id], colors[id])
        if i == 1 then
            bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        else
            bar:SetPoint("TOPLEFT", bars[activeOrder[i - 1]], "BOTTOMLEFT", 0, -p.barSpacing)
        end
        bar:Show()
        activeBars[id] = bar
    end

    local count = #activeOrder
    local totalHeight = count > 0 and (count * p.barHeight + (count - 1) * p.barSpacing) or p.barHeight
    container:SetSize(p.width, totalHeight)
    ApplyPosition()
    if count > 0 then container:Show() else container:Hide() end
end
ns.LayoutBars = LayoutBars

local function AnyBarUpdating()
    for _, bar in pairs(activeBars) do
        if bar.pendingRestart or (bar.isAnimating and not bar.paused) then return true end
    end
    return false
end

local function ClampProgress(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local OnUpdate
local function BeginSwing(bar, speed, startTime)
    local now = GetTime()
    bar.pendingRestart = false
    bar.pendingRestartSeen = false
    bar.pendingSpeed = nil
    bar.pendingStartTime = nil
    bar.startTime = startTime or now
    bar.duration = speed
    bar.paused = false
    local progress = ClampProgress((now - bar.startTime) / speed)
    bar:SetValue(progress)
    bar.isAnimating = progress < 1
    if bar.isAnimating then container:SetScript("OnUpdate", OnUpdate) end
end

OnUpdate = function()
    local now = GetTime()
    for _, bar in pairs(activeBars) do
        if bar.pendingRestart then
            -- The first update leaves the bar at 100%, guaranteeing that the
            -- completed swing is actually rendered. The second starts the new
            -- cycle at its original event time, so no timing is lost.
            if bar.pendingRestartSeen then
                BeginSwing(bar, bar.pendingSpeed, bar.pendingStartTime)
            else
                bar.pendingRestartSeen = true
            end
        elseif bar.isAnimating and not bar.paused then
            local progress = ClampProgress((now - bar.startTime) / bar.duration)
            bar:SetValue(progress)
            if progress >= 1 then bar.isAnimating = false end
        end
    end

    if not AnyBarUpdating() then container:SetScript("OnUpdate", nil) end
end

-- Each physical attack has one authoritative event path. This small guard is
-- only a final safety net for clients that emit the same notification twice.
local DUPLICATE_EVENT_WINDOW = 0.10
local function DisplaySwing(id, speed, effectiveStartTime, eventTime, seamless)
    local bar = activeBars[id]
    if not bar or not speed or speed <= 0 then return end
    local now = eventTime or GetTime()
    effectiveStartTime = effectiveStartTime or now

    if not seamless then
        if bar.pendingRestart then return end
        if bar.lastEventTime then
            local difference = now - bar.lastEventTime
            if difference >= 0 and difference < DUPLICATE_EVENT_WINDOW then return end
        end
    end
    bar.lastEventTime = now

    if seamless then
        bar.restartToken = (bar.restartToken or 0) + 1
        BeginSwing(bar, speed, effectiveStartTime)
    elseif bar.isAnimating or bar.paused then
        bar:SetValue(1)
        bar.isAnimating = false
        bar.paused = false
        bar.pendingRestart = true
        bar.pendingRestartSeen = false
        bar.pendingSpeed = speed
        bar.pendingStartTime = effectiveStartTime
        container:SetScript("OnUpdate", OnUpdate)
    else
        BeginSwing(bar, speed, effectiveStartTime)
    end
end

local function SwingStart(hand, currentTime, expirationTime, seamless)
    currentTime = currentTime or GetTime()
    mainSpeed, offSpeed = UnitAttackSpeed("player")
    offSpeed = offSpeed or 0
    rangedSpeed = UnitRangedDamage("player")

    if hand == "main" and mainSpeed and mainSpeed > 0 then
        plannedSwingMain = expirationTime or (currentTime + mainSpeed)
        DisplaySwing("MH", mainSpeed, plannedSwingMain - mainSpeed, currentTime, seamless)
    elseif hand == "off" and offSpeed > 0 then
        plannedSwingOff = expirationTime or (currentTime + offSpeed)
        DisplaySwing("OH", offSpeed, plannedSwingOff - offSpeed, currentTime, seamless)
    elseif hand == "ranged" and rangedSpeed and rangedSpeed > 0 then
        DisplaySwing("RANGED", rangedSpeed, currentTime, currentTime, seamless)
    end
end
ns.StartSwing = function(id, speed, startTime, force)
    DisplaySwing(id, speed, startTime, startTime, force)
end

local function StopSwing(id)
    local bar = activeBars[id]
    if bar then ResetAnimation(bar) end
    if id == "MH" then
        plannedSwingMain = 0
        pausedSwingMain = nil
    elseif id == "OH" then
        plannedSwingOff = 0
        pausedSwingOff = nil
    end
end

local function QueueMeleeSwingReset(eventTime)
    if mainResetQueued then return end
    mainResetQueued = true
    local generation = timingGeneration
    C_Timer.After(0, function()
        if generation ~= timingGeneration then return end
        mainResetQueued = false
        local p = Profile()
        if not p or not p.enabled or not isAttacking then return end
        offSwingOffset = false
        SwingStart("main", eventTime)
        SwingStart("off", eventTime)
    end)
end

local function FreezeBar(bar, remaining)
    if not bar or not remaining or remaining <= 0 then return end
    bar.restartToken = (bar.restartToken or 0) + 1
    bar.pendingRestart = false
    bar.pendingRestartSeen = false
    bar.paused = true
    bar.isAnimating = true
    if bar.duration and bar.duration > 0 then
        bar:SetValue(ClampProgress(1 - remaining / bar.duration))
    end
end

local function PauseMeleeSwings(now)
    pauseSwingTime = now
    pausedSwingMain = plannedSwingMain > now and (plannedSwingMain - now) or nil
    pausedSwingOff = plannedSwingOff > now and (plannedSwingOff - now) or nil
    FreezeBar(activeBars.MH, pausedSwingMain)
    FreezeBar(activeBars.OH, pausedSwingOff)
    plannedSwingMain = 0
    plannedSwingOff = 0
    if not AnyBarUpdating() then container:SetScript("OnUpdate", nil) end
end

local function ResumePausedSwings(success)
    if not pauseSwingTime then return end
    local now = GetTime()
    local currentMain, currentOff = UnitAttackSpeed("player")
    currentOff = currentOff or 0

    local function Resume(hand, remaining, speed)
        if not remaining or not speed or speed <= 0 then
            StopSwing(hand == "main" and "MH" or "OH")
            return
        end
        local expiration = success and (now + remaining) or (pauseSwingTime + remaining)
        if not success and isAttacking then
            while expiration <= now do expiration = expiration + speed end
        end
        if expiration > now then
            SwingStart(hand, now, expiration, true)
        else
            StopSwing(hand == "main" and "MH" or "OH")
        end
    end

    Resume("main", pausedSwingMain, currentMain)
    Resume("off", pausedSwingOff, currentOff)
    pauseSwingTime = nil
    pausedSwingMain = nil
    pausedSwingOff = nil
end

local function RescaleActiveSwing(id, oldSpeed, newSpeed)
    local bar = activeBars[id]
    if not bar or not oldSpeed or oldSpeed <= 0 or not newSpeed or newSpeed <= 0 then return end
    local now = GetTime()
    local planned = id == "MH" and plannedSwingMain
        or id == "OH" and plannedSwingOff
        or (bar.startTime and bar.duration and bar.startTime + bar.duration)
    if not planned or planned <= now then return end

    local expiration = now + (planned - now) * newSpeed / oldSpeed
    if id == "MH" then plannedSwingMain = expiration
    elseif id == "OH" then plannedSwingOff = expiration end
    DisplaySwing(id, newSpeed, expiration - newSpeed, now, true)
end

local function RefreshEventRegistration()
    local enabled = Profile() and Profile().enabled
    if enabled and not eventsActive then
        eventsActive = true
        ESB:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        ESB:RegisterEvent("PLAYER_ENTER_COMBAT")
        ESB:RegisterEvent("PLAYER_LEAVE_COMBAT")
        ESB:RegisterEvent("UNIT_SPELLCAST_START")
        ESB:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        ESB:RegisterEvent("UNIT_SPELLCAST_FAILED")
        ESB:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        ESB:RegisterEvent("UNIT_ATTACK_SPEED")
        ESB:RegisterEvent("UNIT_RANGEDDAMAGE")
        ESB:RegisterEvent("START_AUTOREPEAT_SPELL")
        ESB:RegisterEvent("STOP_AUTOREPEAT_SPELL")
        ESB:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        ESB:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif not enabled and eventsActive then
        eventsActive = false
        casting = false
        isAttacking = false
        isShooting = false
        ResetTimingState()
        ESB:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        ESB:UnregisterEvent("PLAYER_ENTER_COMBAT")
        ESB:UnregisterEvent("PLAYER_LEAVE_COMBAT")
        ESB:UnregisterEvent("UNIT_SPELLCAST_START")
        ESB:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        ESB:UnregisterEvent("UNIT_SPELLCAST_FAILED")
        ESB:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        ESB:UnregisterEvent("UNIT_ATTACK_SPEED")
        ESB:UnregisterEvent("UNIT_RANGEDDAMAGE")
        ESB:UnregisterEvent("START_AUTOREPEAT_SPELL")
        ESB:UnregisterEvent("STOP_AUTOREPEAT_SPELL")
        ESB:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        ESB:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

local function Apply()
    EnsureFrames()
    RefreshEventRegistration()
    LayoutBars()
end
ns.Apply = Apply
_G._ESB_Apply = Apply

function ns.Reset()
    if not db then return end
    db:ResetProfile()
    Apply()
end

local function EventSpellName(arg2, arg3)
    if type(arg2) == "string" and not arg2:match("^Cast%-") then return arg2 end
    if type(arg3) == "number" then return GetSpellInfo(arg3) end
end

function ESB:UNIT_SPELLCAST_START(_, unit, arg2, arg3)
    if unit ~= "player" then return end
    local spellName = EventSpellName(arg2, arg3)
    if spellName and pauseSwingSpells[spellName] then
        casting = false
        PauseMeleeSwings(GetTime())
    elseif spellName and not noResetOnCastStart[spellName] then
        casting = true
        StopSwing("MH")
        StopSwing("OH")
        offSwingOffset = false
    end
end

function ESB:UNIT_SPELLCAST_SUCCEEDED(_, unit, arg2, arg3)
    if unit ~= "player" then return end
    local spellName = EventSpellName(arg2, arg3)
    local eventTime = GetTime()

    if spellName and pauseSwingSpells[spellName] and pauseSwingTime then
        ResumePausedSwings(true)
    elseif spellName and nextSwingSpells[spellName] then
        mainSpeed, offSpeed = UnitAttackSpeed("player")
        offSpeed = offSpeed or 0
        if offSpeed > 0 and plannedSwingMain > eventTime
            and plannedSwingOff > plannedSwingMain then
            SwingStart("off", eventTime, plannedSwingMain)
        end
        SwingStart("main", eventTime)
    elseif casting or (spellName and resetSwingSpells[spellName]) then
        casting = false
        QueueMeleeSwingReset(eventTime)
    end
    if spellName and resetRangedSwingSpells[spellName] then
        SwingStart("ranged", eventTime)
    end
end

function ESB:UNIT_SPELLCAST_FAILED(_, unit)
    if unit ~= "player" then return end
    if pauseSwingTime then ResumePausedSwings(false) end
    casting = false
end

function ESB:UNIT_SPELLCAST_INTERRUPTED(_, unit)
    if unit ~= "player" then return end
    if pauseSwingTime then ResumePausedSwings(false) end
    casting = false
end

function ESB:PLAYER_ENTER_COMBAT()
    isAttacking = true
end

function ESB:PLAYER_LEAVE_COMBAT()
    isAttacking = false
end

function ESB:UNIT_ATTACK_SPEED(_, unit)
    if unit and unit ~= "player" then return end
    local newMain, newOff = UnitAttackSpeed("player")
    newOff = newOff or 0
    if pausedSwingMain and mainSpeed and newMain and mainSpeed > 0 then
        pausedSwingMain = pausedSwingMain * newMain / mainSpeed
        if activeBars.MH then
            activeBars.MH.duration = newMain
            activeBars.MH:SetValue(ClampProgress(1 - pausedSwingMain / newMain))
        end
    else
        RescaleActiveSwing("MH", mainSpeed, newMain)
    end
    if pausedSwingOff and offSpeed and offSpeed > 0 and newOff > 0 then
        pausedSwingOff = pausedSwingOff * newOff / offSpeed
        if activeBars.OH then
            activeBars.OH.duration = newOff
            activeBars.OH:SetValue(ClampProgress(1 - pausedSwingOff / newOff))
        end
    else
        RescaleActiveSwing("OH", offSpeed, newOff)
    end
    mainSpeed, offSpeed = newMain, newOff
end

function ESB:UNIT_RANGEDDAMAGE(_, unit)
    if unit and unit ~= "player" then return end
    local newSpeed = UnitRangedDamage("player")
    RescaleActiveSwing("RANGED", rangedSpeed, newSpeed)
    rangedSpeed = newSpeed
end

function ESB:START_AUTOREPEAT_SPELL()
    isShooting = true
end

function ESB:STOP_AUTOREPEAT_SPELL()
    isShooting = false
    -- Warmane stops Auto Shot when the player enters melee range. That only
    -- disables future shots; it does not reset the ranged swing that is
    -- already in progress, so leave the bar to finish naturally.
end

local function ApplyParryHaste()
    local bar = activeBars.MH
    local duration = (bar and bar.duration) or mainSpeed
    if not bar or not duration or duration <= 0 then return end
    local now = GetTime()
    local timeLeft = pausedSwingMain or (plannedSwingMain > now and plannedSwingMain - now)
    if not timeLeft or timeLeft <= 0.2 * duration then return end

    local offset = 0.4 * duration
    if timeLeft - offset < 0.2 * duration then
        offset = timeLeft - 0.2 * duration
    end
    if pausedSwingMain then
        pausedSwingMain = timeLeft - offset
        bar:SetValue(ClampProgress(1 - pausedSwingMain / duration))
    else
        plannedSwingMain = plannedSwingMain - offset
        DisplaySwing("MH", duration, plannedSwingMain - duration, now, true)
    end
end

function ESB:COMBAT_LOG_EVENT_UNFILTERED(_, ...)
    local timestamp, subEvent, sourceGUID, _, _, destGUID = ...
    local selfGUID = playerGUID or UnitGUID("player")

    if sourceGUID == selfGUID then
        if subEvent == "SPELL_EXTRA_ATTACKS" then
            skipNextAttackTime = timestamp
            skipNextAttackCount = tonumber(select(12, ...)) or 0
            return
        end

        if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" then
            if tonumber(skipNextAttackTime) and tonumber(timestamp)
                and timestamp - skipNextAttackTime < 0.04 and skipNextAttackCount > 0 then
                skipNextAttackCount = skipNextAttackCount - 1
                return
            end

            local now = GetTime()
            mainSpeed, offSpeed = UnitAttackSpeed("player")
            offSpeed = offSpeed or 0
            local differenceMain = math.abs(now - plannedSwingMain)
            local differenceOff = math.abs(now - plannedSwingOff)

            if plannedSwingMain + 0.15 < now and plannedSwingOff + 0.15 < now then
                SwingStart("main", now)
                if offSpeed > 0 and offSpeed ~= mainSpeed then
                    offSwingOffset = true
                    SwingStart("off", now, now + 0.2)
                end
            elseif offSpeed == 0
                or (differenceMain <= differenceOff and differenceMain < 0.15)
                or plannedSwingMain <= plannedSwingOff then
                SwingStart("main", now)
            else
                SwingStart("off", now, now + offSpeed - (offSwingOffset and 0.2 or 0))
                offSwingOffset = false
            end

            local p = Profile()
            if playerClass == "HUNTER" and p
                and not p.hunterMeleeDoesNotResetRanged then
                SwingStart("ranged", now)
            end
        end
    elseif destGUID == selfGUID then
        local missType = select(9, ...)
        local spellMissType = select(12, ...)
        if missType == "PARRY" or spellMissType == "PARRY" then ApplyParryHaste() end
    end
end

function ESB:PLAYER_EQUIPMENT_CHANGED(_, slotID)
    local mainSlot = INVSLOT_MAINHAND or 16
    local offSlot = INVSLOT_OFFHAND or 17
    local rangeSlot = INVSLOT_RANGED or 18
    if slotID and slotID ~= mainSlot and slotID ~= offSlot and slotID ~= rangeSlot then return end
    C_Timer.After(0, function()
        LayoutBars()
        local now = GetTime()
        if isAttacking then
            SwingStart("main", now)
            SwingStart("off", now)
        end
        if isShooting then SwingStart("ranged", now) end
    end)
end

function ESB:PLAYER_ENTERING_WORLD()
    playerGUID = UnitGUID("player")
    isAttacking = false
    isShooting = false
    LayoutBars()
end

function ESB:OnInitialize()
    db = EllesmereUI.Lite.NewDB("EllesmereUISwingBarsDB", defaults)
    _, playerClass = UnitClass("player")

    local function BuildSpellLookup(target, spellIDs)
        for _, spellID in ipairs(spellIDs) do
            local spellName = GetSpellInfo(spellID)
            if spellName then target[spellName] = true end
        end
    end
    BuildSpellLookup(resetSwingSpells, RESET_SWING_SPELL_IDS)
    BuildSpellLookup(nextSwingSpells, NEXT_SWING_SPELL_IDS)
    BuildSpellLookup(resetRangedSwingSpells, RESET_RANGED_SWING_SPELL_IDS)
    BuildSpellLookup(pauseSwingSpells, PAUSE_SWING_SPELL_IDS)
    BuildSpellLookup(noResetOnCastStart, NO_RESET_ON_CAST_START_IDS)
end

function ESB:OnEnable()
    playerGUID = UnitGUID("player")
    Apply()

    if EllesmereUI.RegisterUnlockElements and EllesmereUI.MakeUnlockElement then
        EllesmereUI._ELEMENT_SETTINGS_MAP = EllesmereUI._ELEMENT_SETTINGS_MAP or {}
        EllesmereUI._ELEMENT_SETTINGS_MAP.EUI_SwingBars = {
            module = "EllesmereUISwingBars", page = "Swingbars",
        }
        EllesmereUI:RegisterUnlockElements({
            EllesmereUI.MakeUnlockElement({
                key = "EUI_SwingBars",
                label = "Swingbars",
                group = "Swingbars",
                order = 790,
                getFrame = function() return container end,
                getSize = function()
                    if not container then return 200, 12 end
                    return container:GetWidth(), container:GetHeight()
                end,
                setWidth = function(_, width)
                    local p = Profile()
                    p.width = math.min(500, math.max(50, math.floor((width or 50) + 0.5)))
                    LayoutBars()
                end,
                setHeight = function(_, height)
                    local p = Profile()
                    local count = math.max(#activeOrder, 1)
                    p.barHeight = math.min(40, math.max(4,
                        math.floor(((height or 4) - (count - 1) * p.barSpacing) / count + 0.5)))
                    LayoutBars()
                end,
                isHidden = function() return not (Profile() and Profile().enabled) end,
                savePos = function(_, point, relPoint, x, y)
                    Profile().position = { point = point, relPoint = relPoint or point, x = x, y = y }
                    ApplyPosition()
                end,
                loadPos = function() return Profile().position end,
                clearPos = function()
                    Profile().position = { point = "CENTER", relPoint = "CENTER", x = 0, y = -100 }
                    ApplyPosition()
                end,
                applyPos = ApplyPosition,
                allowMatchSource = true,
            }),
        }, "EllesmereUISwingBars")
    end
end

function ns.Preview()
    if not Profile() or not Profile().enabled then return end
    local mhSpeed, ohSpeed = UnitAttackSpeed("player")
    local now = GetTime()
    DisplaySwing("MH", mhSpeed or 2, now, now, true)
    if activeBars.OH then DisplaySwing("OH", ohSpeed or 2.5, now, now, true) end
    if activeBars.RANGED then
        DisplaySwing("RANGED", UnitRangedDamage("player") or 2.8, now, now, true)
    end
end
