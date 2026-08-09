-- Minimal standalone services used by SpecializedAbsorbs-1.0.
--
-- The original library embeds AceComm, AceTimer, and AceSerializer.  EUI does
-- not otherwise use Ace3, so carrying those three libraries just for absorbs
-- is unnecessary.  This adapter implements only the methods
-- SpecializedAbsorbs calls, while retaining AceSerializer/AceComm wire
-- compatibility with other clients running the original library.

local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()

timerFrame:SetScript("OnUpdate", function(self, elapsed)
    local due = {}
    for handle, timer in pairs(timers) do
        if not timer.cancelled then
            timer.left = timer.left - elapsed
            if timer.left <= 0 then due[#due + 1] = handle end
        end
    end
    for i = 1, #due do
        local handle = due[i]
        local timer = timers[handle]
        if timer and not timer.cancelled then
            if timer.repeating then
                timer.left = timer.delay
            else
                timers[handle] = nil
            end
            local callback = timer.callback
            local isMethod = type(callback) == "string"
            if isMethod then callback = timer.owner[callback] end
            if callback then
                local ok, err
                if isMethod then
                    ok, err = pcall(callback, timer.owner, timer.arg)
                else
                    ok, err = pcall(callback, timer.arg)
                end
                if not ok then geterrorhandler()(err) end
            end
        end
    end
    if not next(timers) then self:Hide() end
end)

local serializeBuffer = { "^1" }
local serNaN, serInf, serNegInf = tostring(0/0), tostring(1/0), tostring(-1/0)

local function EscapeChar(ch)
    local n = string.byte(ch)
    if n == 30 then return "~z" end
    if n <= 32 then return "~" .. string.char(n + 64) end
    if n == 94 then return "~}" end
    if n == 126 then return "~|" end
    if n == 127 then return "~{" end
end

local function SerializeValue(value, out, n)
    local kind = type(value)
    if kind == "string" then
        out[n + 1] = "^S"
        out[n + 2] = string.gsub(value, "[%c \94\126\127]", EscapeChar)
        return n + 2
    elseif kind == "number" then
        local str = tostring(value)
        if tonumber(str) == value or str == serNaN or str == serInf or str == serNegInf then
            out[n + 1], out[n + 2] = "^N", str
            return n + 2
        end
        local mantissa, exponent = math.frexp(value)
        out[n + 1], out[n + 2] = "^F", string.format("%.0f", mantissa * 2^53)
        out[n + 3], out[n + 4] = "^f", tostring(exponent - 53)
        return n + 4
    elseif kind == "table" then
        n = n + 1
        out[n] = "^T"
        for key, child in pairs(value) do
            n = SerializeValue(key, out, n)
            n = SerializeValue(child, out, n)
        end
        out[n + 1] = "^t"
        return n + 1
    elseif kind == "boolean" then
        out[n + 1] = value and "^B" or "^b"
        return n + 1
    elseif kind == "nil" then
        out[n + 1] = "^Z"
        return n + 1
    end
    error("SpecializedAbsorbs cannot serialize " .. kind)
end

local function UnescapeString(escape)
    if escape < "~z" then return string.char(string.byte(escape, 2) - 64) end
    if escape == "~z" then return "\030" end
    if escape == "~{" then return "\127" end
    if escape == "~|" then return "\126" end
    if escape == "~}" then return "\94" end
    error("Invalid serialized escape")
end

local function DeserializeNumber(value)
    if value == serNaN then return 0/0 end
    if value == serNegInf then return -1/0 end
    if value == serInf then return 1/0 end
    return tonumber(value)
end

local function DeserializeValue(iter, single, control, data)
    if not single then control, data = iter() end
    if not control then error("Missing serialization terminator") end
    if control == "^^" then return end

    local result
    if control == "^S" then
        result = string.gsub(data, "~.", UnescapeString)
    elseif control == "^N" then
        result = DeserializeNumber(data)
        if result == nil then error("Invalid serialized number") end
    elseif control == "^F" then
        local nextControl, exponent = iter()
        if nextControl ~= "^f" then error("Invalid serialized float") end
        result = assert(tonumber(data)) * 2^assert(tonumber(exponent))
    elseif control == "^B" then
        result = true
    elseif control == "^b" then
        result = false
    elseif control == "^Z" then
        result = nil
    elseif control == "^T" then
        result = {}
        while true do
            control, data = iter()
            if control == "^t" then break end
            local key = DeserializeValue(iter, true, control, data)
            control, data = iter()
            result[key] = DeserializeValue(iter, true, control, data)
        end
    else
        error("Invalid serialization control code")
    end

    if single then return result end
    return result, DeserializeValue(iter)
end

local commOwners = {}
local commSpool = {}
local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(_, _, prefix, message, distribution, sender)
    local suffix = string.byte(prefix, #prefix)
    local basePrefix = prefix
    if suffix and suffix >= 1 and suffix <= 3 then
        basePrefix = string.sub(prefix, 1, -2)
        local key = basePrefix .. "\t" .. distribution .. "\t" .. sender
        if suffix == 1 then
            commSpool[key] = { message }
            return
        elseif suffix == 2 then
            local spool = commSpool[key]
            if spool then spool[#spool + 1] = message end
            return
        else
            local spool = commSpool[key]
            if not spool then return end
            spool[#spool + 1] = message
            message = table.concat(spool)
            commSpool[key] = nil
        end
    end

    for owner, registrations in pairs(commOwners) do
        local callback = registrations[basePrefix]
        if callback then
            local isMethod = type(callback) == "string"
            if isMethod then callback = owner[callback] end
            local ok, err
            if isMethod then
                ok, err = pcall(callback, owner, basePrefix, message, distribution, sender)
            else
                ok, err = pcall(callback, basePrefix, message, distribution, sender)
            end
            if not ok then geterrorhandler()(err) end
        end
    end
end)

local function SendAddon(prefix, message, distribution, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(prefix, message, distribution, target)
    end
    return SendAddonMessage(prefix, message, distribution, target)
end

local function RegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(prefix)
    end
end

function SpecializedAbsorbs_EmbedStandalone(target)
    function target:ScheduleTimer(callback, delay, arg)
        local handle = {}
        timers[handle] = { owner = self, callback = callback, delay = delay, left = delay, arg = arg }
        timerFrame:Show()
        return handle
    end

    function target:ScheduleRepeatingTimer(callback, delay, arg)
        local handle = {}
        timers[handle] = { owner = self, callback = callback, delay = delay, left = delay, arg = arg, repeating = true }
        timerFrame:Show()
        return handle
    end

    function target:CancelTimer(handle)
        if timers[handle] then timers[handle].cancelled = true; timers[handle] = nil end
    end

    function target:CancelAllTimers()
        for handle, timer in pairs(timers) do
            if timer.owner == self then timers[handle] = nil end
        end
    end

    function target:Serialize(...)
        local n = 1
        for i = 1, select("#", ...) do n = SerializeValue(select(i, ...), serializeBuffer, n) end
        serializeBuffer[n + 1] = "^^"
        return table.concat(serializeBuffer, "", 1, n + 1)
    end

    function target:Deserialize(value)
        value = string.gsub(value, "[%c ]", "")
        local iter = string.gmatch(value, "(^.)([^^]*)")
        local control = iter()
        if control ~= "^1" then return false, "Not serialized data" end
        return pcall(DeserializeValue, iter)
    end

    function target:RegisterComm(prefix, callback)
        local registrations = commOwners[self]
        if not registrations then registrations = {}; commOwners[self] = registrations end
        registrations[prefix] = callback or "OnCommReceived"
        RegisterPrefix(prefix)
        -- AceComm reserves these suffixes for multipart messages.  Older
        -- Wrath clients register full prefixes rather than accepting all
        -- traffic automatically, so register the wire variants as well.
        RegisterPrefix(prefix .. "\001")
        RegisterPrefix(prefix .. "\002")
        RegisterPrefix(prefix .. "\003")
    end

    function target:UnregisterAllComm()
        commOwners[self] = nil
    end

    function target:SendCommMessage(prefix, message, distribution, destination)
        local chunkSize = 254 - #prefix
        if #message <= chunkSize then
            SendAddon(prefix, message, distribution, destination)
            return
        end
        chunkSize = chunkSize - 1
        SendAddon(prefix .. "\001", string.sub(message, 1, chunkSize), distribution, destination)
        local position = chunkSize + 1
        while position + chunkSize <= #message do
            SendAddon(prefix .. "\002", string.sub(message, position, position + chunkSize - 1), distribution, destination)
            position = position + chunkSize
        end
        SendAddon(prefix .. "\003", string.sub(message, position), distribution, destination)
    end
end
