EUI = EUI or {}
EUI.API = EUI.API or {}

function EUI.API.SetSecureAttr(frame, name, value)
    if not frame then return end
    if frame.SetAttributeNoHandler then
        frame:SetAttributeNoHandler(name, value)
    elseif frame.SetAttribute then
        frame:SetAttribute(name, EUI.API.FixSecureSnippet and type(value) == "string" and EUI.API.FixSecureSnippet(value) or value)
    end
end

-- OnCooldownDone does not exist on the 3.3.5 Cooldown widget.  Keep one shared
-- driver for all compatibility cooldowns instead of putting an OnUpdate script
-- (or a separate timer) on every icon.  Entries are added by the SetCooldown
-- wrapper below and removed when the cooldown is cleared, replaced, or expires.
local cooldownDoneWatch = setmetatable({}, { __mode = "k" })
local cooldownTextWatch = setmetatable({}, { __mode = "k" })
local cooldownDoneSnapshot = {}
local cooldownDoneDriver = CreateFrame("Frame")
cooldownDoneDriver:Hide()

local function ReportCooldownDoneError(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function RunCooldownDoneCallback(callback, cooldown)
    local ok, err = pcall(callback, cooldown)
    if not ok then ReportCooldownDoneError(err) end
end

local function HasCooldownDoneHandler(cooldown)
    local hooks = cooldown._euiOnCooldownDoneHooks
    return cooldown._euiOnCooldownDone ~= nil or (hooks and #hooks > 0)
end

local function CooldownNumbersEnabled(cooldown)
    if cooldown._euiHideCountdownNumbers then return false end
    return not GetCVarBool or GetCVarBool("countdownForCooldowns")
end

local function FormatCooldownRemaining(remaining)
    if remaining >= 86400 then return math.ceil(remaining / 86400) .. "d" end
    if remaining >= 3600 then return math.ceil(remaining / 3600) .. "h" end
    if remaining >= 60 then return math.ceil(remaining / 60) .. "m" end
    if remaining >= 10 then return tostring(math.ceil(remaining)) end
    return string.format("%.1f", remaining)
end

local function EnsureCooldownText(cooldown)
    if cooldown._euiCooldownText or not cooldown.CreateFontString then
        return cooldown._euiCooldownText
    end
    local text = cooldown:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    text:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:Hide()
    cooldown._euiCooldownText = text
    return text
end

local function RefreshCooldownText(cooldown, now)
    local text = cooldown._euiCooldownText
    local finish = cooldown._euiCooldownFinish
    local remaining = finish and (finish - now) or 0
    -- Match the modern widget's useful behavior: do not put countdown numbers
    -- over the global cooldown, and obey both the widget flag and Blizzard CVar.
    if text and remaining > 1.5 and CooldownNumbersEnabled(cooldown) then
        text:SetText(FormatCooldownRemaining(remaining))
        text:Show()
        return true
    end
    if text then text:Hide() end
    return remaining > 0
end

cooldownDoneDriver:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local count = 0

    -- Callbacks can clear/restart cooldowns and therefore mutate the watch table.
    -- Traverse a stable snapshot so Lua 5.1's next() cannot be invalidated.
    for cooldown in pairs(cooldownDoneWatch) do
        count = count + 1
        cooldownDoneSnapshot[count] = cooldown
    end
    for i = count + 1, #cooldownDoneSnapshot do
        cooldownDoneSnapshot[i] = nil
    end

    for i = 1, count do
        local cooldown = cooldownDoneSnapshot[i]
        cooldownDoneSnapshot[i] = nil
        local finish = cooldownDoneWatch[cooldown]
        if finish and now >= finish then
            -- Remove first: a callback that starts a new cooldown must be able to
            -- register its new finish time without this pass erasing it afterward.
            cooldownDoneWatch[cooldown] = nil
            cooldown._euiCooldownFinish = nil
            local callback = cooldown._euiOnCooldownDone
            if callback then RunCooldownDoneCallback(callback, cooldown) end
            local hooks = cooldown._euiOnCooldownDoneHooks
            if hooks then
                -- HookScript callbacks are persistent and run in registration order.
                for hookIndex = 1, #hooks do
                    RunCooldownDoneCallback(hooks[hookIndex], cooldown)
                end
            end
        end
    end

    for cooldown in pairs(cooldownTextWatch) do
        if not RefreshCooldownText(cooldown, now) then
            cooldownTextWatch[cooldown] = nil
        end
    end

    if not next(cooldownDoneWatch) and not next(cooldownTextWatch) then self:Hide() end
end)

local function ApplyCooldownCompat(target)
    if not target then return end

    -- Emulate the retail Cooldown widget's completion script with real expiry
    -- tracking.  SetScript/HookScript are intercepted only for OnCooldownDone;
    -- every script supported by the legacy widget still goes to the native API.
    if not target._euiCooldownDoneCompat then
        target._euiCooldownDoneCompat = true
        local nativeSetCooldown = target.SetCooldown
        local nativeSetScript = target.SetScript
        local nativeHookScript = target.HookScript
        local nativeGetScript = target.GetScript
        local nativeHasScript = target.HasScript

        if nativeSetCooldown then
            target.SetCooldown = function(self, start, duration, ...)
                nativeSetCooldown(self, start, duration, ...)
                start = tonumber(start) or 0
                duration = tonumber(duration) or 0
                if start > 0 and duration > 0 then
                    EnsureCooldownText(self)
                    local modRate = tonumber((...)) or 1
                    if modRate <= 0 then modRate = 1 end
                    self._euiCooldownFinish = start + (duration / modRate)
                    cooldownTextWatch[self] = self._euiCooldownFinish
                    RefreshCooldownText(self, GetTime())
                    cooldownDoneDriver:Show()
                    if HasCooldownDoneHandler(self)
                       and self._euiCooldownFinish > GetTime() then
                        cooldownDoneWatch[self] = self._euiCooldownFinish
                        cooldownDoneDriver:Show()
                    else
                        cooldownDoneWatch[self] = nil
                    end
                else
                    self._euiCooldownFinish = nil
                    cooldownDoneWatch[self] = nil
                    cooldownTextWatch[self] = nil
                    if self._euiCooldownText then self._euiCooldownText:Hide() end
                    if not next(cooldownDoneWatch) and not next(cooldownTextWatch) then cooldownDoneDriver:Hide() end
                end
            end
        end

        target.SetScript = function(self, scriptName, callback)
            if scriptName == "OnCooldownDone" then
                if callback ~= nil and type(callback) ~= "function" then
                    error("Usage: SetScript(\"OnCooldownDone\", function or nil)", 2)
                end
                self._euiOnCooldownDone = callback
                local finish = self._euiCooldownFinish
                if HasCooldownDoneHandler(self) and finish and finish > GetTime() then
                    cooldownDoneWatch[self] = finish
                    cooldownDoneDriver:Show()
                elseif not HasCooldownDoneHandler(self) then
                    cooldownDoneWatch[self] = nil
                    if not next(cooldownDoneWatch) and not next(cooldownTextWatch) then cooldownDoneDriver:Hide() end
                end
                return
            end
            return nativeSetScript(self, scriptName, callback)
        end

        target.HookScript = function(self, scriptName, callback)
            if scriptName == "OnCooldownDone" then
                if type(callback) ~= "function" then
                    error("Usage: HookScript(\"OnCooldownDone\", function)", 2)
                end
                local hooks = self._euiOnCooldownDoneHooks
                if not hooks then
                    hooks = {}
                    self._euiOnCooldownDoneHooks = hooks
                end
                hooks[#hooks + 1] = callback
                local finish = self._euiCooldownFinish
                if finish and finish > GetTime() then
                    cooldownDoneWatch[self] = finish
                    cooldownDoneDriver:Show()
                end
                return
            end
            return nativeHookScript(self, scriptName, callback)
        end

        if nativeGetScript then
            target.GetScript = function(self, scriptName)
                if scriptName == "OnCooldownDone" then
                    return self._euiOnCooldownDone
                end
                return nativeGetScript(self, scriptName)
            end
        end
        if nativeHasScript then
            target.HasScript = function(self, scriptName)
                if scriptName == "OnCooldownDone" then return true end
                return nativeHasScript(self, scriptName)
            end
        end
    end

    if not target.SetCooldownFromDurationObject then
        target.SetCooldownFromDurationObject = function(self, durObj)
            if not durObj then
                if self.SetCooldown then self:SetCooldown(0, 0) end
                self:Hide()
                return
            end
            local start = durObj.startTime
            local duration = durObj.duration
            if (not start or start == 0) and durObj.expirationTime and durObj.expirationTime > 0 then
                start = durObj.expirationTime - (duration or 0)
            end
            start = start or 0
            duration = duration or 0
            if CooldownFrame_Set then
                CooldownFrame_Set(self, start, duration)
            elseif start > 0 and duration > 0 then
                self:Hide()
                if self.SetCooldown then self:SetCooldown(start, duration) end
                self:Show()
            else
                if self.SetCooldown then self:SetCooldown(0, 0) end
                self:Hide()
            end
        end
    end
    if not target.Clear then
        target.Clear = function(self)
            if self.SetCooldown then self:SetCooldown(0, 0) end
            self:Hide()
        end
    end
    if not target.SetDrawBling then target.SetDrawBling = function(self, draw) self._euiDrawBling = draw and true or false end end
    if not target.GetDrawBling then target.GetDrawBling = function(self) return self._euiDrawBling == true end end
    if not target.SetDrawEdge then target.SetDrawEdge = function(self, draw) self._euiDrawEdge = draw and true or false end end
    if not target.GetDrawEdge then target.GetDrawEdge = function(self) return self._euiDrawEdge ~= false end end
    if not target.SetDrawSwipe then target.SetDrawSwipe = function(self, draw) self._euiDrawSwipe = draw and true or false end end
    if not target.GetDrawSwipe then target.GetDrawSwipe = function(self) return self._euiDrawSwipe ~= false end end
    if not target.SetHideCountdownNumbers then
        target.SetHideCountdownNumbers = function(self, hide)
            self._euiHideCountdownNumbers = hide and true or false
            if self._euiCooldownFinish and self._euiCooldownFinish > GetTime() then
                EnsureCooldownText(self)
                cooldownTextWatch[self] = self._euiCooldownFinish
                RefreshCooldownText(self, GetTime())
                cooldownDoneDriver:Show()
            elseif self._euiCooldownText then
                self._euiCooldownText:Hide()
            end
        end
    end
    if not target.GetHideCountdownNumbers then target.GetHideCountdownNumbers = function(self) return self._euiHideCountdownNumbers == true end end
    if not target.SetBlingTexture then target.SetBlingTexture = function(self, tex) self._euiBlingTexture = tex end end
    if not target.SetEdgeTexture then target.SetEdgeTexture = function(self, tex) self._euiEdgeTexture = tex end end
    if not target.SetSwipeTexture then target.SetSwipeTexture = function(self, tex) self._euiSwipeTexture = tex end end
    if not target.SetSwipeColor then target.SetSwipeColor = function(self, r, g, b, a) self._euiSwipeColor = { r, g, b, a } end end
    if not target.SetEdgeScale then target.SetEdgeScale = function(self, scale) self._euiEdgeScale = scale end end
    if not target.GetEdgeScale then target.GetEdgeScale = function(self) return self._euiEdgeScale or 1 end end
    if not target.SetCooldownUNIX then target.SetCooldownUNIX = function(self, start, duration) if self.SetCooldown then self:SetCooldown(start or 0, duration or 0) end end end
    if not target.GetReverse then target.GetReverse = function(self) return self._euiReverse == true end end
end

local function GetAtlasPath(atlas)
    if not atlas or atlas == "" then return nil end
    local path = EUI_AtlasMap and EUI_AtlasMap[atlas]
    if not path then
        path = "Interface\\Icons\\INV_Misc_QuestionMark"
        if EUI_AtlasMap then EUI_AtlasMap[atlas] = path end
    end
    return path
end

local function ParseLinePointArgs(point, arg1, arg2, arg3)
    local rel, x, y
    if type(arg1) == "table" or type(arg1) == "userdata" or (type(arg1) == "string" and _G[arg1]) then
        rel = (type(arg1) == "string") and _G[arg1] or arg1
        x = tonumber(arg2) or 0
        y = tonumber(arg3) or 0
    elseif type(arg1) == "number" then
        rel = nil
        x = arg1
        y = tonumber(arg2) or 0
    else
        rel = nil
        x = 0
        y = 0
    end
    return point or "BOTTOMLEFT", rel, x, y
end

local function GetPointScreenCoord(point, rel, offX, offY)
    local f = rel or UIParent
    local left = (f.GetLeft and f:GetLeft()) or 0
    local right = (f.GetRight and f:GetRight()) or left
    local bottom = (f.GetBottom and f:GetBottom()) or 0
    local top = (f.GetTop and f:GetTop()) or bottom
    local cx = (left + right) * 0.5
    local cy = (bottom + top) * 0.5

    offX = offX or 0
    offY = offY or 0

    if point == "BOTTOMLEFT" then
        return left + offX, bottom + offY
    elseif point == "BOTTOM" then
        return cx + offX, bottom + offY
    elseif point == "BOTTOMRIGHT" then
        return right + offX, bottom + offY
    elseif point == "TOPLEFT" then
        return left + offX, top + offY
    elseif point == "TOP" then
        return cx + offX, top + offY
    elseif point == "TOPRIGHT" then
        return right + offX, top + offY
    elseif point == "LEFT" then
        return left + offX, cy + offY
    elseif point == "RIGHT" then
        return right + offX, cy + offY
    elseif point == "CENTER" then
        return cx + offX, cy + offY
    else
        return left + offX, bottom + offY
    end
end

local function UpdateLineGeometry(line)
    if not line or not line.ClearAllPoints or not line.SetPoint then return end

    local startPoint = line._startPoint or "BOTTOMLEFT"
    local startRel = line._startRel
    local startX = line._startX or 0
    local startY = line._startY or 0

    local endPoint = line._endPoint or "BOTTOMLEFT"
    local endRel = line._endRel
    local endX = line._endX or 0
    local endY = line._endY or 0

    local x1, y1 = GetPointScreenCoord(startPoint, startRel, startX, startY)
    local x2, y2 = GetPointScreenCoord(endPoint, endRel, endX, endY)

    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    local thickness = line._thickness or 1
    if thickness <= 0 then thickness = 1 end

    local midX = (x1 + x2) * 0.5
    local midY = (y1 + y2) * 0.5

    line:ClearAllPoints()
    if length <= 0.001 then
        line:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x1, y1)
        line:SetWidth(0.001)
        line:SetHeight(thickness)
        if line.SetRotation then line:SetRotation(0) end
    else
        line:SetPoint("CENTER", UIParent, "BOTTOMLEFT", midX, midY)
        line:SetWidth(length)
        line:SetHeight(thickness)
        if line.SetRotation then
            line:SetRotation(math.atan2(dy, dx))
        end
    end
end

local function Line_SetThickness(self, thickness)
    self._thickness = tonumber(thickness) or 1
    if self._startPoint and self._endPoint then
        UpdateLineGeometry(self)
    end
end

local function Line_GetThickness(self)
    return self._thickness or 1
end

local function Line_SetStartPoint(self, point, arg1, arg2, arg3)
    local pt, rel, x, y = ParseLinePointArgs(point, arg1, arg2, arg3)
    self._startPoint = pt
    self._startRel = rel
    self._startX = x
    self._startY = y
    if self._endPoint then
        UpdateLineGeometry(self)
    end
end

local function Line_SetEndPoint(self, point, arg1, arg2, arg3)
    local pt, rel, x, y = ParseLinePointArgs(point, arg1, arg2, arg3)
    self._endPoint = pt
    self._endRel = rel
    self._endX = x
    self._endY = y
    if self._startPoint then
        UpdateLineGeometry(self)
    end
end

local function Line_GetStartPoint(self)
    return self._startPoint or "BOTTOMLEFT", self._startRel, self._startX or 0, self._startY or 0
end

local function Line_GetEndPoint(self)
    return self._endPoint or "BOTTOMLEFT", self._endRel, self._endX or 0, self._endY or 0
end

local function Line_SetVertices(self, x1, y1, x2, y2)
    self._startPoint = "BOTTOMLEFT"
    self._startRel = nil
    self._startX = x1 or 0
    self._startY = y1 or 0
    self._endPoint = "BOTTOMLEFT"
    self._endRel = nil
    self._endX = x2 or 0
    self._endY = y2 or 0
    UpdateLineGeometry(self)
end

local function LineCompat(line)
    if not line then return line end
    line._thickness = line._thickness or 1
    if not line.SetThickness then line.SetThickness = Line_SetThickness end
    if not line.GetThickness then line.GetThickness = Line_GetThickness end
    if not line.SetStartPoint then line.SetStartPoint = Line_SetStartPoint end
    if not line.SetEndPoint then line.SetEndPoint = Line_SetEndPoint end
    if not line.GetStartPoint then line.GetStartPoint = Line_GetStartPoint end
    if not line.GetEndPoint then line.GetEndPoint = Line_GetEndPoint end
    if not line.SetSnapToPixelGrid then line.SetSnapToPixelGrid = function(self, snap) end end
    if not line.GetSnapToPixelGrid then line.GetSnapToPixelGrid = function(self) return false end end
    if not line.SetTexelSnappingBias then line.SetTexelSnappingBias = function(self, bias) end end
    if not line.GetTexelSnappingBias then line.GetTexelSnappingBias = function(self) return 0 end end
    if not line.SetStartAlpha then line.SetStartAlpha = function(self, alpha) end end
    if not line.SetEndAlpha then line.SetEndAlpha = function(self, alpha) end end
    if not line.SetVertices then line.SetVertices = Line_SetVertices end
    return line
end

-- Synthetic event registry for retail/custom events not recognized by the 3.3.5 client engine
local syntheticEventRegistry = {}
local function RegisterSyntheticEvent(frame, event)
    if not syntheticEventRegistry[event] then
        syntheticEventRegistry[event] = setmetatable({}, { __mode = "k" })
    end
    syntheticEventRegistry[event][frame] = true
end

local function UnregisterSyntheticEvent(frame, event)
    if syntheticEventRegistry[event] then
        syntheticEventRegistry[event][frame] = nil
    end
end

-------------------------------------------------------------------------------
-- Central RegisterUnitEvent compatibility
--
-- Wrath has no native RegisterUnitEvent.  The old compatibility method simply
-- called RegisterEvent, so every nominally unit-filtered frame received every
-- matching event.  That is especially expensive for raid frames and
-- nameplates: one UNIT_AURA could enter dozens of identical handlers.
--
-- Keep one native registration per event here and route it only to frames that
-- subscribed to the event's first (unit) argument.  Frames still own their
-- OnEvent scripts and can freely mix broad and unit registrations.  The
-- per-frame wrappers below make RegisterEvent, UnregisterEvent,
-- UnregisterAllEvents and IsEventRegistered retain Blizzard-compatible
-- behavior without requiring feature modules to know about this dispatcher.
-------------------------------------------------------------------------------
local unitEventRegistry = {}
local frameUnitEvents = setmetatable({}, { __mode = "k" })
local unitEventDispatchSnapshots = {}
local unitEventDispatchDepth = 0
local unitEventDispatcher = CreateFrame("Frame")

local function ReportUnitEventError(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function StopUnitEvent(event, entry)
    unitEventRegistry[event] = nil
    pcall(unitEventDispatcher.UnregisterEvent, unitEventDispatcher, event)
    UnregisterSyntheticEvent(unitEventDispatcher, event)
end

local function UnregisterCentralUnitEvent(frame, event)
    local registered = frameUnitEvents[frame]
    local units = registered and registered[event]
    if not units then return false end

    registered[event] = nil
    if not next(registered) then frameUnitEvents[frame] = nil end

    local entry = unitEventRegistry[event]
    if entry then
        for unit in pairs(units) do
            local subscribers = entry.byUnit[unit]
            if subscribers then
                subscribers[frame] = nil
                if not next(subscribers) then entry.byUnit[unit] = nil end
            end
        end
        entry.count = entry.count - 1
        if entry.count <= 0 then StopUnitEvent(event, entry) end
    end
    return true
end

local function UnregisterAllCentralUnitEvents(frame)
    local registered = frameUnitEvents[frame]
    if not registered then return end

    -- UnregisterCentralUnitEvent mutates registered, so collect event names
    -- first rather than invalidating a Lua 5.1 next() traversal.
    local events = {}
    for event in pairs(registered) do events[#events + 1] = event end
    for i = 1, #events do UnregisterCentralUnitEvent(frame, events[i]) end
end

local function EnsureUnitEventFrameWrappers(frame)
    if frame._euiUnitEventWrapped then return end
    frame._euiUnitEventWrapped = true

    local originalRegisterEvent = frame.RegisterEvent
    local originalUnregisterEvent = frame.UnregisterEvent
    local originalUnregisterAllEvents = frame.UnregisterAllEvents
    local originalIsEventRegistered = frame.IsEventRegistered

    if originalRegisterEvent then
        frame.RegisterEvent = function(self, event, ...)
            -- A broad registration replaces a unit-filtered registration for
            -- the same frame/event, matching the native event API.
            UnregisterCentralUnitEvent(self, event)
            return originalRegisterEvent(self, event, ...)
        end
    end
    if originalUnregisterEvent then
        frame.UnregisterEvent = function(self, event, ...)
            UnregisterCentralUnitEvent(self, event)
            return originalUnregisterEvent(self, event, ...)
        end
    end
    if originalUnregisterAllEvents then
        frame.UnregisterAllEvents = function(self, ...)
            UnregisterAllCentralUnitEvents(self)
            return originalUnregisterAllEvents(self, ...)
        end
    end
    if originalIsEventRegistered then
        frame.IsEventRegistered = function(self, event, ...)
            local registered = frameUnitEvents[self]
            if registered and registered[event] then return true end
            return originalIsEventRegistered(self, event, ...)
        end
    end
end

local function RegisterUnitEventCompat(frame, event, ...)
    if type(event) ~= "string" then
        error("Usage: RegisterUnitEvent(\"event\", \"unit\" [, \"unit2\"])", 2)
    end

    local unitCount = select("#", ...)
    if unitCount < 1 or unitCount > 2 then
        error("Usage: RegisterUnitEvent(\"event\", \"unit\" [, \"unit2\"])", 2)
    end

    local units = {}
    for i = 1, unitCount do
        local unit = select(i, ...)
        if type(unit) ~= "string" then
            error("Usage: RegisterUnitEvent(\"event\", \"unit\" [, \"unit2\"])", 2)
        end
        units[unit] = true
    end

    EnsureUnitEventFrameWrappers(frame)

    -- Remove either an earlier unit registration or a native broad
    -- registration before installing the new filtered route.
    frame:UnregisterEvent(event)

    local entry = unitEventRegistry[event]
    if not entry then
        entry = {
            byUnit = {},
            count = 0,
        }
        unitEventRegistry[event] = entry

        -- Some retail-only unit events are synthetic on Wrath.  Register them
        -- with the existing synthetic bus when the native client rejects the
        -- event name, so both paths use the same filtered dispatcher.
        local ok = pcall(unitEventDispatcher.RegisterEvent, unitEventDispatcher, event)
        if not ok then RegisterSyntheticEvent(unitEventDispatcher, event) end
    end

    local registered = frameUnitEvents[frame]
    if not registered then
        registered = {}
        frameUnitEvents[frame] = registered
    end
    registered[event] = units
    for unit in pairs(units) do
        local subscribers = entry.byUnit[unit]
        if not subscribers then
            subscribers = setmetatable({}, { __mode = "k" })
            entry.byUnit[unit] = subscribers
        end
        subscribers[frame] = true
    end
    entry.count = entry.count + 1
    return true
end

unitEventDispatcher:SetScript("OnEvent", function(_, event, unit, ...)
    local entry = unitEventRegistry[event]
    if not entry or type(unit) ~= "string" then return end
    local subscribers = entry.byUnit[unit]
    if not subscribers then return end

    unitEventDispatchDepth = unitEventDispatchDepth + 1
    local snapshot = unitEventDispatchSnapshots[unitEventDispatchDepth]
    if not snapshot then
        snapshot = {}
        unitEventDispatchSnapshots[unitEventDispatchDepth] = snapshot
    end
    local count = 0
    for frame in pairs(subscribers) do
        count = count + 1
        snapshot[count] = frame
    end
    for i = count + 1, #snapshot do
        snapshot[i] = nil
    end

    -- A handler may unregister itself or another subscriber.  Traverse the
    -- stable snapshot and re-check membership before entering each callback.
    for i = 1, count do
        local frame = snapshot[i]
        snapshot[i] = nil
        if subscribers[frame] then
            local onEvent = frame.GetScript and frame:GetScript("OnEvent")
            if onEvent then
                local ok, err = pcall(onEvent, frame, event, unit, ...)
                if not ok then ReportUnitEventError(err) end
            end
        end
    end
    unitEventDispatchDepth = unitEventDispatchDepth - 1
end)

-- Lightweight diagnostics for profiling/debug commands without exposing the
-- mutable registry itself.
function EUI.API.GetUnitEventReactorStats()
    local events, subscribers = 0, 0
    for _, entry in pairs(unitEventRegistry) do
        events = events + 1
        subscribers = subscribers + entry.count
    end
    return events, subscribers
end

function EUI.API.FireEvent(event, ...)
    local listeners = syntheticEventRegistry[event]
    if not listeners then return end
    for frame in pairs(listeners) do
        local onEvent = frame.GetScript and frame:GetScript("OnEvent")
        if onEvent then
            local ok, err = pcall(onEvent, frame, event, ...)
            if not ok and geterrorhandler then
                geterrorhandler()(err)
            end
        end
    end
end

function EUI.API.ApplyFrameCompat(frame)
    if not frame then return frame end

    if not frame.CreateLine then
        frame.CreateLine = function(self, name, layer, inheritsFrom, subLayer)
            local line = self:CreateTexture(name, layer, inheritsFrom, subLayer)
            if line then
                LineCompat(line)
            end
            return line
        end
    end

    -- Reverse-fill was added after the 3.3.5 StatusBar API.  Keep the setting
    -- readable on legacy clients so retail-era unit-frame code can use the
    -- same creation and layout paths without faulting.  The old renderer
    -- continues to draw the bar in its native direction.
    if frame.GetObjectType and frame:GetObjectType() == "StatusBar" then
        if not frame.SetReverseFill then
            frame.SetReverseFill = function(self, reverse)
                self._euiReverseFill = reverse and true or false
            end
        end
        if not frame.GetReverseFill then
            frame.GetReverseFill = function(self)
                return self._euiReverseFill == true
            end
        end
    end

    if not frame.SetShown then
        frame.SetShown = function(self, show)
            if show then self:Show() else self:Hide() end
        end
    end

    -- SetEnabled(boolean) is the modern equivalent of the legacy Button
    -- Enable()/Disable() pair used by the 3.3.5 client.
    if not frame.SetEnabled and frame.Enable and frame.Disable then
        frame.SetEnabled = function(self, enabled)
            if enabled then self:Enable() else self:Disable() end
        end
    end

    -- Wrap RegisterEvent/UnregisterEvent to safely intercept synthetic custom events
    local origRegisterEvent = frame.RegisterEvent
    local origUnregisterEvent = frame.UnregisterEvent
    local origUnregisterAllEvents = frame.UnregisterAllEvents
    if origRegisterEvent and not frame._euiEventCompatWrapped then
        frame._euiEventCompatWrapped = true
        frame.RegisterEvent = function(self, event)
            local ok = pcall(origRegisterEvent, self, event)
            if not ok then
                RegisterSyntheticEvent(self, event)
            end
            return ok
        end
        if origUnregisterEvent then
            frame.UnregisterEvent = function(self, event)
                pcall(origUnregisterEvent, self, event)
                UnregisterSyntheticEvent(self, event)
            end
        end
        if origUnregisterAllEvents then
            frame.UnregisterAllEvents = function(self)
                pcall(origUnregisterAllEvents, self)
                for _, listeners in pairs(syntheticEventRegistry) do
                    listeners[self] = nil
                end
            end
        end
    end

    -- RegisterUnitEvent was added after WotLK. Route it through one shared
    -- dispatcher so legacy frames receive only their requested unit(s).
    if not frame.RegisterUnitEvent then
        frame.RegisterUnitEvent = RegisterUnitEventCompat
    end

    if not frame.SetColorTexture then
        frame.SetColorTexture = function(self, r, g, b, a)
            -- values. Give it real texture data, then tint that texture.
            self:SetTexture("Interface\\Buttons\\WHITE8X8")
            self:SetVertexColor(r, g, b, a or 1)
        end
    end

    if not frame.SetAtlas then
        frame.SetAtlas = function(self, atlas, useAtlasSize)
            local path = GetAtlasPath(atlas)
            if self.SetTexture then self:SetTexture(path) end
        end
    end

    if not frame.SetNormalAtlas then
        frame.SetNormalAtlas = function(self, atlas, useAtlasSize)
            local path = GetAtlasPath(atlas)
            if self.SetNormalTexture then self:SetNormalTexture(path) end
        end
    end

    if not frame.SetPushedAtlas then
        frame.SetPushedAtlas = function(self, atlas, useAtlasSize)
            local path = GetAtlasPath(atlas)
            if self.SetPushedTexture then self:SetPushedTexture(path) end
        end
    end

    if not frame.SetDisabledAtlas then
        frame.SetDisabledAtlas = function(self, atlas, useAtlasSize)
            local path = GetAtlasPath(atlas)
            if self.SetDisabledTexture then self:SetDisabledTexture(path) end
        end
    end

    if not frame.SetHighlightAtlas then
        frame.SetHighlightAtlas = function(self, atlas, useAtlasSize)
            local path = GetAtlasPath(atlas)
            if self.SetHighlightTexture then self:SetHighlightTexture(path) end
        end
    end

    if not frame.SetSnapToPixelGrid then frame.SetSnapToPixelGrid = function(self, snap) end end
    if not frame.SetPixelSnapDisabled then frame.SetPixelSnapDisabled = function(self, disable) end end
    if not frame.IsForbidden then frame.IsForbidden = function(self) return false end end
    if not frame.SetTexelSnappingBias then frame.SetTexelSnappingBias = function(self, bias) end end
    if not frame.PixelSnap then frame.PixelSnap = function(self, val) return val end end
    if not frame.SetClipsChildren then frame.SetClipsChildren = function(self, clip) end end
    if not frame.SetPortraitZoom then
        frame.SetPortraitZoom = function(self, zoom)
            if self.SetCamDistanceScale and type(zoom) == "number" then
                pcall(self.SetCamDistanceScale, self, 1 + zoom * 0.5)
            end
        end
    end

    if not frame.SetAlphaFromBoolean then
        frame.SetAlphaFromBoolean = function(self, value, trueAlpha, falseAlpha)
            if trueAlpha == nil then trueAlpha = 1 end
            if falseAlpha == nil then falseAlpha = 0 end
            if value then
                self:SetAlpha(trueAlpha)
            else
                self:SetAlpha(falseAlpha)
            end
        end
    end

    if not frame.SetIgnoreParentAlpha then frame.SetIgnoreParentAlpha = function(self, ignore) end end
    if not frame.SetMouseClickEnabled then
        frame.SetMouseClickEnabled = function(self, enabled)
            if self.EnableMouse then self:EnableMouse(enabled) end
        end
    end
    if not frame.SetMouseMotionEnabled then
        frame.SetMouseMotionEnabled = function(self, enabled)
            if self.EnableMouse then self:EnableMouse(enabled) end
        end
    end
    -- Retail can let selected mouse buttons fall through a mouse-enabled
    -- region.  Wrath has no equivalent API, so retain the requested buttons
    -- for introspection and otherwise degrade safely.
    if not frame.SetPassThroughButtons then
        frame.SetPassThroughButtons = function(self, ...)
            self._euiPassThroughButtons = {...}
        end
    end
    if not frame.SetScaleToFit then frame.SetScaleToFit = function(self) end end
    if not frame.GetScaledRect then frame.GetScaledRect = function(self) return self:GetRect() end end
    if not frame.SetIgnoreParentScale then frame.SetIgnoreParentScale = function(self, ignore) end end
    if not frame.GetLayoutChildren then frame.GetLayoutChildren = function(self) return {self:GetChildren()} end end
    if not frame.MarkDirty then frame.MarkDirty = function(self) end end
    if not frame.SetPadding then frame.SetPadding = function(self, padding) end end
    if not frame.SetSpacing then frame.SetSpacing = function(self, spacing) end end
    if not frame.GetLayoutIndex then frame.GetLayoutIndex = function(self) return self.layoutIndex or 1 end end
    if not frame.SetFrameStrataFromParent then frame.SetFrameStrataFromParent = function(self) end end
    if not frame.SetFixedFrameStrata then frame.SetFixedFrameStrata = function(self, fixed) end end
    if not frame.SetPropagateKeyboardInput then
        frame.SetPropagateKeyboardInput = function(self, propagate)
            if self.EnableKeyboard then
                self:EnableKeyboard(not propagate)
            end
        end
    end

    if frame.GetObjectType and frame:GetObjectType() == "Cooldown" then
        ApplyCooldownCompat(frame)
    end

    if frame.CreateFontString and not frame._fsHooked then
        frame._fsHooked = true
        local origCreateFontString = frame.CreateFontString
        frame.CreateFontString = function(self, ...)
            local fs = origCreateFontString(self, ...)
            if fs and not fs.SetMaxLines then
                fs.SetMaxLines = function(self, limit) end
            end
            return fs
        end
    end

    if frame.CreateAnimationGroup and not frame._animHooked then
        frame._animHooked = true
        local origCreateAnimationGroup = frame.CreateAnimationGroup
        frame.CreateAnimationGroup = function(self, ...)
            local group = origCreateAnimationGroup(self, ...)
            if group then
                if not group.Restart then
                    group.Restart = function(g)
                        g:Stop()
                        g:Play()
                    end
                end
                local origCreateAnimation = group.CreateAnimation
                group.CreateAnimation = function(g, animType, ...)
                    local anim = origCreateAnimation(g, animType, ...)
                    if anim and animType == "Alpha" then
                        if not anim.SetFromAlpha then
                            anim.SetFromAlpha = function(a, alpha)
                                a._fromAlpha = alpha
                                if a._toAlpha and a.SetChange then
                                    a:SetChange(a._toAlpha - alpha)
                                end
                            end
                        end
                        if not anim.SetToAlpha then
                            anim.SetToAlpha = function(a, alpha)
                                a._toAlpha = alpha
                                if a.SetChange then
                                    local from = a._fromAlpha or 0
                                    a:SetChange(alpha - from)
                                end
                            end
                        end
                    end
                    return anim
                end
            end
            return group
        end
    end

    return frame
end

function EllesmereUI.StripRetailTemplates(template)
    if not template then return template end
    if type(template) == "string" then
        template = template:gsub("BackdropTemplate", "")
        template = template:gsub("BankPanelPurchaseButtonScriptTemplate", "")
        template = template:gsub(",%s*,", ",")
        template = template:gsub("^%s*,", "")
        template = template:gsub(",%s*$", "")
        if template == "" then template = nil end

        if template then
            if template == "MainMenuFrameButtonTemplate" then
                template = "GameMenuButtonTemplate"
            elseif template:find("MainMenuFrameButtonTemplate") then
                template = template:gsub("MainMenuFrameButtonTemplate", "GameMenuButtonTemplate")
            end
        end
    end
    return template
end

local function IsRealUIFrame(obj)
    if not obj then return false end
    local t = type(obj)
    if t == "userdata" then return true end
    if t == "table" and rawget(obj, 0) ~= nil then return true end
    return false
end

function EllesmereUI.SafeCreateFrame(frameType, name, parent, template)
    if type(frameType) == "string" and frameType:lower() == "itembutton" then
        frameType = "Button"
    end
    local sanitizedTemplate = EllesmereUI.StripRetailTemplates(template)
    local realParent = parent
    if parent ~= nil and not IsRealUIFrame(parent) then
        realParent = UIParent
    end
    local f = CreateFrame(frameType, name, realParent, sanitizedTemplate)

    if f then
        EUI.API.ApplyFrameCompat(f)

        if type(frameType) == "string" and frameType:lower() == "editbox" then
            if f.SetAutoFocus then f:SetAutoFocus(false) end
            if f.ClearFocus then f:ClearFocus() end
        end
    end
    return f
end

if not GetPhysicalScreenSize then
    _G.GetPhysicalScreenSize = function()
        local resIndex = GetCurrentResolution()
        local resString = resIndex and select(resIndex, GetScreenResolutions())
        if resString then
            local w, h = string.match(resString, "(%d+)x(%d+)")
            if w and h then
                return tonumber(w), tonumber(h)
            end
        end
        local w = UIParent:GetWidth() or 1920
        local h = UIParent:GetHeight() or 1080
        return w, h
    end
end

local function PolyfillSetGradient(region)
    if not region
        or not region.SetGradientAlpha
        or region._SetGradientHooked
    then
        return
    end

    region._SetGradientHooked = true

    local origSetGradient = region.SetGradient

    region.SetGradient = function(self, orientation, minColor, maxColor, ...)
        if type(minColor) == "table"
            and minColor.GetRGBA
            and type(maxColor) == "table"
            and maxColor.GetRGBA
        then
            local minR, minG, minB, minA = minColor:GetRGBA()
            local maxR, maxG, maxB, maxA = maxColor:GetRGBA()

            if orientation == "HORIZONTAL_REV" then
                orientation = "HORIZONTAL"
                minR, minG, minB, minA,
                maxR, maxG, maxB, maxA =
                    maxR, maxG, maxB, maxA,
                    minR, minG, minB, minA

            elseif orientation == "VERTICAL_REV" then
                orientation = "VERTICAL"
                minR, minG, minB, minA,
                maxR, maxG, maxB, maxA =
                    maxR, maxG, maxB, maxA,
                    minR, minG, minB, minA
            end

            return self:SetGradientAlpha(
                orientation,
                minR, minG, minB, minA,
                maxR, maxG, maxB, maxA
            )
        end

        if origSetGradient then
            return origSetGradient(
                self,
                orientation,
                minColor,
                maxColor,
                ...
            )
        end
    end
end

-- Global metatable patching for WoW 3.3.5 frame compatibility methods.
-- In WoW 3.3.5 all widget instances of the same type share a single C metatable
-- whose __index is a plain Lua table.  Inserting here fixes EVERY instance of
-- that type globally, so we never need per-frame ApplyFrameCompat for these stubs.
local function PatchWidgetMetatable(obj)
    if not obj then return end
    local meta = getmetatable(obj)
    local idx = meta and meta.__index
    local isStatusBar = obj.GetObjectType and obj:GetObjectType() == "StatusBar"
    if type(idx) == "table" then
        -- Shared metatable table -- patch it once, covers all instances.
        if isStatusBar then
            if not idx.SetReverseFill then
                idx.SetReverseFill = function(self, reverse)
                    self._euiReverseFill = reverse and true or false
                end
            end
            if not idx.GetReverseFill then
                idx.GetReverseFill = function(self)
                    return self._euiReverseFill == true
                end
            end
        end
        if not idx.SetFromAlpha then
            idx.SetFromAlpha = function(self, alpha)
                self._fromAlpha = alpha
                if self._toAlpha and self.SetChange then
                    self:SetChange(self._toAlpha - alpha)
                end
            end
        end
        if not idx.SetToAlpha then
            idx.SetToAlpha = function(self, alpha)
                self._toAlpha = alpha
                if self.SetChange then
                    local from = self._fromAlpha or 0
                    self:SetChange(alpha - from)
                end
            end
        end
        if not idx.Restart then
            idx.Restart = function(self)
                self:Stop()
                self:Play()
            end
        end
        if idx.CreateAnimationGroup and not idx._animGroupHooked then
            idx._animGroupHooked = true
            local origCreateAnimationGroup = idx.CreateAnimationGroup
            idx.CreateAnimationGroup = function(self, ...)
                local group = origCreateAnimationGroup(self, ...)
                if group then
                    if not group.Restart then
                        group.Restart = function(g)
                            g:Stop()
                            g:Play()
                        end
                    end
                    if not group._animHooked then
                        group._animHooked = true
                        local origCreateAnimation = group.CreateAnimation
                        if origCreateAnimation then
                            group.CreateAnimation = function(g, animType, ...)
                                local anim = origCreateAnimation(g, animType, ...)
                                if anim and animType == "Alpha" then
                                    if not anim.SetFromAlpha then
                                        anim.SetFromAlpha = function(a, alpha)
                                            a._fromAlpha = alpha
                                            if a._toAlpha and a.SetChange then
                                                a:SetChange(a._toAlpha - alpha)
                                            end
                                        end
                                    end
                                    if not anim.SetToAlpha then
                                        anim.SetToAlpha = function(a, alpha)
                                            a._toAlpha = alpha
                                            if a.SetChange then
                                                local from = a._fromAlpha or 0
                                                a:SetChange(alpha - from)
                                            end
                                        end
                                    end
                                end
                                return anim
                            end
                        end
                    end
                end
                return group
            end
        end
        if not idx.IsForbidden         then idx.IsForbidden         = function(self) return false end end
        if not idx.SetSnapToPixelGrid  then idx.SetSnapToPixelGrid  = function(self) end end
        if not idx.SetPixelSnapDisabled then idx.SetPixelSnapDisabled = function(self) end end
        if not idx.SetTexelSnappingBias then idx.SetTexelSnappingBias = function(self) end end
        if not idx.PixelSnap           then idx.PixelSnap           = function(self, v) return v end end
        if not idx.SetClipsChildren    then idx.SetClipsChildren    = function(self) end end
        if not idx.SetPortraitZoom     then
            idx.SetPortraitZoom     = function(self, zoom)
                if self.SetCamDistanceScale and type(zoom) == "number" then
                    pcall(self.SetCamDistanceScale, self, 1 + zoom * 0.5)
                end
            end
        end
        if not idx.SetShown then
            idx.SetShown = function(self, show)
                if show then self:Show() else self:Hide() end
            end
        end
        if not idx.SetAlphaFromBoolean then
            idx.SetAlphaFromBoolean = function(self, value, trueAlpha, falseAlpha)
                if trueAlpha == nil then trueAlpha = 1 end
                if falseAlpha == nil then falseAlpha = 0 end
                if value then
                    self:SetAlpha(trueAlpha)
                else
                    self:SetAlpha(falseAlpha)
                end
            end
        end
        if not idx.RegisterUnitEvent then
            idx.RegisterUnitEvent = RegisterUnitEventCompat
        end
        if not idx.SetPassThroughButtons then
            idx.SetPassThroughButtons = function(self, ...)
                self._euiPassThroughButtons = {...}
            end
        end
        if not idx.SetColorTexture then
            idx.SetColorTexture = function(self, r, g, b, a)
                self:SetTexture("Interface\\Buttons\\WHITE8X8")
                self:SetVertexColor(r, g, b, a or 1)
            end
        end
        PolyfillSetGradient(idx)
        if not idx.SetAtlas then
            idx.SetAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetTexture then self:SetTexture(path) end
            end
        end
        if not idx.SetNormalAtlas then
            idx.SetNormalAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetNormalTexture then self:SetNormalTexture(path) end
            end
        end
        if not idx.SetPushedAtlas then
            idx.SetPushedAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetPushedTexture then self:SetPushedTexture(path) end
            end
        end
        if not idx.SetDisabledAtlas then
            idx.SetDisabledAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetDisabledTexture then self:SetDisabledTexture(path) end
            end
        end
        if not idx.SetHighlightAtlas then
            idx.SetHighlightAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetHighlightTexture then self:SetHighlightTexture(path) end
            end
        end
        if not idx.CreateLine then
            idx.CreateLine = function(self, name, layer, inheritsFrom, subLayer)
                local line = self:CreateTexture(name, layer, inheritsFrom, subLayer)
                if line then
                    LineCompat(line)
                end
                return line
            end
        end
        if not idx.SetThickness then idx.SetThickness = Line_SetThickness end
        if not idx.GetThickness then idx.GetThickness = Line_GetThickness end
        if not idx.SetStartPoint then idx.SetStartPoint = Line_SetStartPoint end
        if not idx.SetEndPoint then idx.SetEndPoint = Line_SetEndPoint end
        if not idx.GetStartPoint then idx.GetStartPoint = Line_GetStartPoint end
        if not idx.GetEndPoint then idx.GetEndPoint = Line_GetEndPoint end
        if not idx.SetSnapToPixelGrid then idx.SetSnapToPixelGrid = function(self, snap) end end
        if not idx.GetSnapToPixelGrid then idx.GetSnapToPixelGrid = function(self) return false end end
        if not idx.SetTexelSnappingBias then idx.SetTexelSnappingBias = function(self, bias) end end
        if not idx.GetTexelSnappingBias then idx.GetTexelSnappingBias = function(self) return 0 end end
        if not idx.SetStartAlpha then idx.SetStartAlpha = function(self, alpha) end end
        if not idx.SetEndAlpha then idx.SetEndAlpha = function(self, alpha) end end
        if not idx.SetVertices then idx.SetVertices = Line_SetVertices end
        local isCooldown = obj.GetObjectType and obj:GetObjectType() == "Cooldown"
        if isCooldown or idx.SetCooldown then
            ApplyCooldownCompat(idx)
        end
    else
        -- Fallback: __index is a function or absent; patch the object directly.
        -- This is less efficient but safe.
        if isStatusBar then
            if not obj.SetReverseFill then
                obj.SetReverseFill = function(self, reverse)
                    self._euiReverseFill = reverse and true or false
                end
            end
            if not obj.GetReverseFill then
                obj.GetReverseFill = function(self)
                    return self._euiReverseFill == true
                end
            end
        end
        if not obj.SetFromAlpha then
            obj.SetFromAlpha = function(self, alpha)
                self._fromAlpha = alpha
                if self._toAlpha and self.SetChange then
                    self:SetChange(self._toAlpha - alpha)
                end
            end
        end
        if not obj.SetToAlpha then
            obj.SetToAlpha = function(self, alpha)
                self._toAlpha = alpha
                if self.SetChange then
                    local from = self._fromAlpha or 0
                    self:SetChange(alpha - from)
                end
            end
        end
        if not obj.Restart then
            obj.Restart = function(self)
                self:Stop()
                self:Play()
            end
        end
        if not obj.IsForbidden         then obj.IsForbidden         = function(self) return false end end
        if not obj.SetSnapToPixelGrid  then obj.SetSnapToPixelGrid  = function(self) end end
        if not obj.SetPixelSnapDisabled then obj.SetPixelSnapDisabled = function(self) end end
        if not obj.SetTexelSnappingBias then obj.SetTexelSnappingBias = function(self) end end
        if not obj.PixelSnap           then obj.PixelSnap           = function(self, v) return v end end
        if not obj.SetClipsChildren    then obj.SetClipsChildren    = function(self) end end
        if not obj.SetPortraitZoom     then
            obj.SetPortraitZoom     = function(self, zoom)
                if self.SetCamDistanceScale and type(zoom) == "number" then
                    pcall(self.SetCamDistanceScale, self, 1 + zoom * 0.5)
                end
            end
        end
        if not obj.SetShown then
            obj.SetShown = function(self, show)
                if show then self:Show() else self:Hide() end
            end
        end
        if not obj.SetAlphaFromBoolean then
            obj.SetAlphaFromBoolean = function(self, value, trueAlpha, falseAlpha)
                if trueAlpha == nil then trueAlpha = 1 end
                if falseAlpha == nil then falseAlpha = 0 end
                if value then
                    self:SetAlpha(trueAlpha)
                else
                    self:SetAlpha(falseAlpha)
                end
            end
        end
        if not obj.RegisterUnitEvent then
            obj.RegisterUnitEvent = RegisterUnitEventCompat
        end
        if not obj.SetColorTexture then
            obj.SetColorTexture = function(self, r, g, b, a)
                self:SetTexture("Interface\\Buttons\\WHITE8X8")
                self:SetVertexColor(r, g, b, a or 1)
            end
        end
        PolyfillSetGradient(obj)
        if not obj.SetAtlas then
            obj.SetAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetTexture then self:SetTexture(path) end
            end
        end
        if not obj.SetNormalAtlas then
            obj.SetNormalAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetNormalTexture then self:SetNormalTexture(path) end
            end
        end
        if not obj.SetPushedAtlas then
            obj.SetPushedAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetPushedTexture then self:SetPushedTexture(path) end
            end
        end
        if not obj.SetDisabledAtlas then
            obj.SetDisabledAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetDisabledTexture then self:SetDisabledTexture(path) end
            end
        end
        if not obj.SetHighlightAtlas then
            obj.SetHighlightAtlas = function(self, atlas, useAtlasSize)
                local path = GetAtlasPath(atlas)
                if self.SetHighlightTexture then self:SetHighlightTexture(path) end
            end
        end
        if not obj.CreateLine then
            obj.CreateLine = function(self, name, layer, inheritsFrom, subLayer)
                local line = self:CreateTexture(name, layer, inheritsFrom, subLayer)
                if line then
                    LineCompat(line)
                end
                return line
            end
        end
        if not obj.SetThickness then obj.SetThickness = Line_SetThickness end
        if not obj.GetThickness then obj.GetThickness = Line_GetThickness end
        if not obj.SetStartPoint then obj.SetStartPoint = Line_SetStartPoint end
        if not obj.SetEndPoint then obj.SetEndPoint = Line_SetEndPoint end
        if not obj.GetStartPoint then obj.GetStartPoint = Line_GetStartPoint end
        if not obj.GetEndPoint then obj.GetEndPoint = Line_GetEndPoint end
        if not obj.SetSnapToPixelGrid then obj.SetSnapToPixelGrid = function(self, snap) end end
        if not obj.GetSnapToPixelGrid then obj.GetSnapToPixelGrid = function(self) return false end end
        if not obj.SetTexelSnappingBias then obj.SetTexelSnappingBias = function(self, bias) end end
        if not obj.GetTexelSnappingBias then obj.GetTexelSnappingBias = function(self) return 0 end end
        if not obj.SetStartAlpha then obj.SetStartAlpha = function(self, alpha) end end
        if not obj.SetEndAlpha then obj.SetEndAlpha = function(self, alpha) end end
        if not obj.SetVertices then obj.SetVertices = Line_SetVertices end
        local isCooldown = obj.GetObjectType and obj:GetObjectType() == "Cooldown"
        if isCooldown or obj.SetCooldown then
            ApplyCooldownCompat(obj)
        end
    end
end

do
    local dummy = CreateFrame("Frame")
    if dummy then
        PatchWidgetMetatable(dummy)
        local tex = dummy:CreateTexture()
        if tex then PatchWidgetMetatable(tex) end
        local fs = dummy:CreateFontString()
        if fs then PatchWidgetMetatable(fs) end
        if dummy.CreateAnimationGroup then
            local ag = dummy:CreateAnimationGroup()
            if ag then
                PatchWidgetMetatable(ag)
                if ag.CreateAnimation then
                    local anim = ag:CreateAnimation("Alpha")
                    if anim then PatchWidgetMetatable(anim) end
                end
            end
        end
        dummy:Hide()
    end
    -- Each frame type shares a single C metatable across all instances.
    -- Patching __index on one instance's metatable fixes ALL instances of that type.
    local types = { "Button", "CheckButton", "Cooldown", "Slider", "EditBox",
                    "ScrollFrame", "SimpleHTML", "MessageFrame", "Model", "PlayerModel", "DressUpModel", "StatusBar" }
    for _, t in ipairs(types) do
        local ok, f = pcall(CreateFrame, t)
        if ok and f then
            PatchWidgetMetatable(f)
            f:Hide()
        end
    end
end
