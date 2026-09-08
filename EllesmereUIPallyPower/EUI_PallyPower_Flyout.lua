-------------------------------------------------------------------------------
--  EUI_PallyPower_Flyout.lua
--  Direct PallyPower bar placement and EllesmereUI Unlock Mode integration.
-------------------------------------------------------------------------------

local EllesmereUI = _G.EllesmereUI
if not EllesmereUI or not PallyPower then return end

-- Keep the original registration key so existing Unlock Mode metadata does not
-- leave behind a second, stale PallyPower entry. Position storage is now owned
-- directly by the PallyPower profile and is no longer converted to a screen edge.
local UNLOCK_KEY = "EPP_Flyout"

local function Orientation(addon)
	local value = addon.opt and addon.opt.display and addon.opt.display.orientation
	return value == "HORIZONTAL" and "HORIZONTAL" or "VERTICAL"
end

local function ApplySavedPosition(addon)
	local frame = _G.PallyPowerFrame
	local display = addon.opt and addon.opt.display
	if not frame or not display then return end
	if EllesmereUI.IsUnlockModeActive and EllesmereUI:IsUnlockModeActive() then
		if EllesmereUI.RefreshUnlockElement then
			EllesmereUI.RefreshUnlockElement(UNLOCK_KEY)
		end
		return
	end

	local pos = display.position
	if pos and (pos.point or "CENTER") == "CENTER"
		and (pos.relPoint or pos.point or "CENTER") == "CENTER" then
		-- Unlock Mode stores the visual center in UIParent space. PallyPower
		-- scales its root frame directly, so SetPoint offsets must be converted
		-- back into that frame's local space or the saved offset is scaled twice.
		local frameScale = frame:GetEffectiveScale()
		local parentScale = UIParent:GetEffectiveScale()
		local ratio = frameScale > 0 and parentScale / frameScale or 1
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER",
			(pos.x or 0) * ratio, (pos.y or 0) * ratio)
		return
	end

	frame:ClearAllPoints()
	if pos then
		frame:SetPoint(pos.point or "CENTER", UIParent,
			pos.relPoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

-- The legacy layout pass still prepares secure attributes before this module's
-- final placement pass. These alignments keep that preparation predictable;
-- LayoutEUIBar below is the sole authority for the visible bar geometry.
function PallyPower:GetEUILayoutAlignment()
	return Orientation(self) == "HORIZONTAL" and "Top Right" or "Bottom Right"
end

function PallyPower:GetEUIPlayerAlignment()
	return Orientation(self) == "HORIZONTAL" and "bottom" or "right"
end

function PallyPower:LayoutEUIBar()
	if InCombatLockdown() then
		self._profileRefreshPending = true
		return
	end
	if not self.autoButton or not self.Header or not self.opt or not self.opt.display then return end

	local display = self.opt.display
	local horizontal = Orientation(self) == "HORIZONTAL"
	local buttonWidth = tonumber(display.buttonWidth) or 100
	local buttonHeight = tonumber(display.buttonHeight) or 34
	local gap = tonumber(display.gapping) or -1
	local stepX = buttonWidth + gap
	local stepY = buttonHeight + gap
	local enabled = self:IsPlayerPaladin() and self:GetNumUnits() > 0 and not self.opt.disabled
	local visible = {}

	-- The old edge tab needed these handlers to reveal and collapse the bar.
	-- With a direct bar they would hide class buttons again after auto-hide fires.
	self.autoButton:SetAttribute("_onenter", nil)

	local showAuto = enabled and self.opt.autobuff and self.opt.autobuff.autobutton
	if showAuto then
		self.autoButton:Show()
		visible[#visible + 1] = self.autoButton
	else
		self.autoButton:Hide()
	end

	if enabled and self.opt.rfbuff then
		self.rfButton:Show()
		visible[#visible + 1] = self.rfButton
	else
		self.rfButton:Hide()
	end

	if enabled and self.opt.auras then
		self.auraButton:Show()
		visible[#visible + 1] = self.auraButton
	else
		self.auraButton:Hide()
	end

	for index, classButton in ipairs(self.classButtons or {}) do
		classButton:SetAttribute("_onhide", nil)
		if enabled and classButton:GetAttribute("Display") == 1 then
			classButton:Show()
			visible[#visible + 1] = classButton
		else
			classButton:Hide()
		end

		-- Individual-player buttons remain the class button's secure hover popup.
		-- Their opening direction follows the selected main-bar orientation.
		for playerIndex, playerButton in ipairs((self.playerButtons or {})[index] or {}) do
			playerButton:ClearAllPoints()
			if horizontal then
				playerButton:SetPoint("TOP", classButton, "BOTTOM", 0,
					-(gap + (playerIndex - 1) * stepY))
			else
				playerButton:SetPoint("LEFT", classButton, "RIGHT",
					gap + (playerIndex - 1) * stepX, 0)
			end
			playerButton:Hide()
		end
	end

	local count = #visible
	local width = horizontal and math.max(buttonWidth, count * buttonWidth + math.max(0, count - 1) * gap)
		or buttonWidth
	local height = horizontal and buttonHeight
		or math.max(buttonHeight, count * buttonHeight + math.max(0, count - 1) * gap)
	local firstX = horizontal and (-width / 2 + buttonWidth / 2) or 0
	local firstY = horizontal and 0 or (height / 2 - buttonHeight / 2)

	for index, button in ipairs(visible) do
		button:ClearAllPoints()
		if horizontal then
			button:SetPoint("CENTER", self.Header, "CENTER", firstX + (index - 1) * stepX, 0)
		else
			button:SetPoint("CENTER", self.Header, "CENTER", 0, firstY - (index - 1) * stepY)
		end
	end

	local frame = _G.PallyPowerFrame
	if frame then
		frame:SetSize(width, height)
		ApplySavedPosition(self)
	end
end

function PallyPower:UpdateAnchor()
	self:LayoutEUIBar()
end

function PallyPower:RegisterPallyPowerUnlock()
	if self._euiUnlockRegistered then return end
	if not EllesmereUI.RegisterUnlockElements or not EllesmereUI.MakeUnlockElement then return end
	self._euiUnlockRegistered = true
	local addon = self

	if EllesmereUI.RegisterUnlockModeListener and not self._euiUnlockListener then
		self._euiUnlockListener = true
		EllesmereUI:RegisterUnlockModeListener("EllesmereUIPallyPower", function(active)
			if not active and addon.opt then addon:LayoutEUIBar() end
		end)
	end

	EllesmereUI:RegisterUnlockElements({
		EllesmereUI.MakeUnlockElement({
			key = UNLOCK_KEY,
			label = "PallyPower",
			group = "Quality of Life",
			order = 610,
			noResize = true,
			noAnchorTarget = true,
			noAnchorTo = true,
			-- The generic position pass assumes the element root uses UIParent's
			-- scale. PallyPower owns a scaled root and applies its saved center above.
			noInitHook = true,
			subtitle = "Drag the complete bar anywhere",
			isHidden = function() return not addon:IsPlayerPaladin() end,
			getFrame = function() return _G.PallyPowerFrame end,
			getSize = function()
				local frame = _G.PallyPowerFrame
				return frame and frame:GetWidth() or 100, frame and frame:GetHeight() or 34
			end,
			loadPos = function()
				return addon.opt and addon.opt.display and addon.opt.display.position
			end,
			savePos = function(_, point, relPoint, x, y)
				local display = addon.opt and addon.opt.display
				if not display then return end
				display.position = {
					point = point or "CENTER",
					relPoint = relPoint or point or "CENTER",
					x = x or 0,
					y = y or 0,
				}
			end,
			clearPos = function()
				local display = addon.opt and addon.opt.display
				if display then display.position = nil end
			end,
			applyPos = function()
				ApplySavedPosition(addon)
			end,
		}),
	}, "EllesmereUIPallyPower")
end

_G._EPP_RegisterUnlock = function()
	if PallyPower and PallyPower.RegisterPallyPowerUnlock then
		PallyPower:RegisterPallyPowerUnlock()
	end
end
