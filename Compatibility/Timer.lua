-- Timer.lua

-- 2. C_Timer Polyfill with OnUpdate Accumulator Pool
if not C_Timer then
    C_Timer = {}
    local timers = {}
    local newTimers = {}
    local iterating = false
    local tickerId = 0
    local timerFrame = CreateFrame("Frame")
    local timerIds = {}
    -- C_Timer.After never hands its timer to the caller, so those records can
    -- be recycled once they fire instead of becoming garbage every call.
    local pool = {}

    local TimerMethods = {}
    local TimerMeta = { __index = TimerMethods }

    function TimerMethods:Cancel()
        self.cancelled = true
        timers[self.id] = nil
        newTimers[self.id] = nil
    end

    function TimerMethods:IsCancelled()
        return self.cancelled
    end

    -- Lua 5.1 xpcall cannot forward arguments.  One shared zero-argument
    -- runner preserves C_Timer's callback(ticker) API without allocating a
    -- closure per ticker; tickers only run from the OnUpdate loop below, so
    -- the slot is never re-entered.
    local runningTicker
    local function RunTicker()
        return runningTicker.callback(runningTicker)
    end

    local function Release(t)
        if t.pooled then
            t.callback = nil
            pool[#pool + 1] = t
        end
    end

    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        iterating = true
        -- Lua 5.1's pairs()/next() traversal can fail with "invalid key to
        -- 'next'" when the current hash key is deleted.  Timer callbacks and
        -- the expiry path both remove entries, so traverse a stable ID snapshot.
        local n = 0
        for id in pairs(timers) do
            n = n + 1
            timerIds[n] = id
        end
        for i = n + 1, #timerIds do timerIds[i] = nil end
        for i = 1, n do
            local id = timerIds[i]
            local t = timers[id]
            -- An earlier callback may have cancelled a timer that appeared
            -- later in the snapshot.
            if t and not t.cancelled then
                t.remaining = t.remaining - elapsed
                if t.remaining <= 0 then
                    if t.isTicker then
                        t.iterations = t.iterations + 1
                        t.remaining = t.remaining + t.duration
                        if t.remaining <= 0 then
                            t.remaining = t.duration
                        end
                        -- xpcall invokes Blizzard's handler before the callback
                        -- stack unwinds.  The 3.3.5 DebugTools frame collects its
                        -- own stack/locals at that point; reporting a pcall error
                        -- afterwards leaves `locals` nil and the viewer itself
                        -- errors recursively while trying to format it.
                        runningTicker = t
                        xpcall(RunTicker, geterrorhandler())
                        runningTicker = nil
                        if t.cancelled then
                            timers[id] = nil
                        elseif t.maxIterations and t.iterations >= t.maxIterations then
                            t.cancelled = true
                            timers[id] = nil
                        end
                    else
                        t.cancelled = true
                        timers[id] = nil
                        xpcall(t.callback, geterrorhandler())
                        Release(t)
                    end
                end
            elseif t then
                timers[id] = nil
                Release(t)
            end
        end
        iterating = false

        if next(newTimers) then
            for id, t in pairs(newTimers) do
                timers[id] = t
            end
            wipe(newTimers)
        end

        if not next(timers) then
            self:Hide()
        end
    end)
    timerFrame:Hide()

    local function createTimer(duration, callback, isTicker, maxIterations, pooled)
        tickerId = tickerId + 1
        local id = tickerId
        local t
        if pooled and #pool > 0 then
            t = pool[#pool]
            pool[#pool] = nil
        else
            t = setmetatable({}, TimerMeta)
        end
        t.id = id
        t.duration = duration
        t.remaining = duration
        t.callback = callback
        t.isTicker = isTicker
        t.iterations = 0
        t.maxIterations = maxIterations
        t.cancelled = false
        t.pooled = pooled
        if iterating then
            newTimers[id] = t
        else
            timers[id] = t
        end
        timerFrame:Show()
        return t
    end

    function C_Timer.After(duration, callback)
        createTimer(duration, callback, false, nil, true)
    end

    function C_Timer.NewTimer(duration, callback)
        return createTimer(duration, callback, false)
    end

    function C_Timer.NewTicker(duration, callback, iterations)
        return createTimer(duration, callback, true, iterations)
    end
end
