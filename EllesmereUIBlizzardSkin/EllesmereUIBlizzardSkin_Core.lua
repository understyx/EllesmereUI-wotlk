local WSkin = _G.EllesmereUIBlizzardSkin
local EllesmereUI = _G.EllesmereUI
local type = type
local pairs = pairs
local pcall = pcall
local geterrorhandler = geterrorhandler
local IsAddOnLoaded = IsAddOnLoaded

if not C_Timer then
	C_Timer = {}
	local ticker = CreateFrame("Frame")
	local timers = {}
	ticker:SetScript("OnUpdate", function(self, elapsed)
		for i = #timers, 1, -1 do
			local t = timers[i]
			t.timeLeft = t.timeLeft - elapsed
			if t.timeLeft <= 0 then
				t.func()
				if t.isTicker then
					t.timeLeft = t.duration
				else
					table.remove(timers, i)
				end
			end
		end
	end)
	function C_Timer.After(duration, func)
		table.insert(timers, {duration = duration, timeLeft = duration, func = func})
	end
	function C_Timer.NewTimer(duration, func)
		local t = {duration = duration, timeLeft = duration, func = func}
		table.insert(timers, t)
		return {
			Cancel = function()
				for i, v in ipairs(timers) do
					if v == t then table.remove(timers, i); break end
				end
			end
		}
	end
	function C_Timer.NewTicker(duration, func)
		local t = {duration = duration, timeLeft = duration, func = func, isTicker = true}
		table.insert(timers, t)
		return {
			Cancel = function()
				for i, v in ipairs(timers) do
					if v == t then table.remove(timers, i); break end
				end
			end
		}
	end
end

-------------------------------------------------------------------------------
--  Window Enable Check & Callback System
-------------------------------------------------------------------------------
local SKIN_TO_WINDOW_KEY = {
	Skin_Character = "charsheet",
	Skin_Spellbook = "playerspells",
	Skin_Talent    = "playerspells",
	Skin_WorldMap  = "worldmap",
	Skin_Merchant  = "merchant",
	Skin_Gossip    = "gossip",
	Skin_Quest     = "quest",
}

function WSkin:IsSkinEnabled(winKey)
	if not winKey then return true end
	if EllesmereUI and EllesmereUI.BlizzWindowSkinsKilled and EllesmereUI.BlizzWindowSkinsKilled() then
		return false
	end
	if EllesmereUI and EllesmereUI.GetBlizzWindowStyle then
		return EllesmereUI.GetBlizzWindowStyle(winKey) ~= "off"
	end
	local keys = EllesmereUI and EllesmereUI.WINDOW_ENABLE_KEYS
	local ek = keys and keys[winKey]
	if ek and EllesmereUIDB and EllesmereUIDB[ek] == false then
		return false
	end
	return true
end

WSkin.callbacks = {}
WSkin.addonCallbacks = {}

local isPlayerLoggedIn = false

local function RunSkinCallback(entry)
	if not entry or entry.executed then return end
	local winKey = entry.winKey
	if winKey and not WSkin:IsSkinEnabled(winKey) then
		return
	end
	entry.executed = true
	local success, err = pcall(entry.func)
	if not success and err then
		geterrorhandler()(err)
	end
end

function WSkin:AddCallback(name, func, winKey)
	if type(func) ~= "function" then return end
	local entry = {
		name     = name,
		func     = func,
		winKey   = winKey or SKIN_TO_WINDOW_KEY[name],
		executed = false,
	}
	self.callbacks[name] = entry
	if isPlayerLoggedIn then
		RunSkinCallback(entry)
	end
end

function WSkin:AddCallbackForAddon(addonName, name, func, winKey)
	if not addonName or type(func) ~= "function" then return end
	if not self.addonCallbacks[addonName] then
		self.addonCallbacks[addonName] = {}
	end
	local entry = {
		name      = name,
		addonName = addonName,
		func      = func,
		winKey    = winKey or SKIN_TO_WINDOW_KEY[name],
		executed  = false,
	}
	self.addonCallbacks[addonName][name] = entry
	if isPlayerLoggedIn and IsAddOnLoaded(addonName) then
		RunSkinCallback(entry)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" then
		if addon and WSkin.addonCallbacks[addon] then
			for _, entry in pairs(WSkin.addonCallbacks[addon]) do
				RunSkinCallback(entry)
			end
		end
	elseif event == "PLAYER_LOGIN" then
		isPlayerLoggedIn = true
		for _, entry in pairs(WSkin.callbacks) do
			RunSkinCallback(entry)
		end
		for addonName, addonEntries in pairs(WSkin.addonCallbacks) do
			if IsAddOnLoaded(addonName) then
				for _, entry in pairs(addonEntries) do
					RunSkinCallback(entry)
				end
			end
		end
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)
