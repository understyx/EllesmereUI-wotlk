local EllesmereUI = _G.EllesmereUI
if not EllesmereUI or not PallyPower then return end

local EDGE_ALIGNMENT = {
	LEFT = "Top Right",
	RIGHT = "Top Left",
	TOP = "Bottom Right",
	BOTTOM = "Top Right",
}

local EDGE_LABEL = {
	LEFT = "PP >",
	RIGHT = "< PP",
	TOP = "v PP",
	BOTTOM = "^ PP",
}

local UNLOCK_KEY = "EPP_Flyout"

local function Clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

-- Unlock Mode stores positions as a frame centre relative to UIParent's centre,
-- while PallyPower intentionally persists an edge + a percentage along it.
-- These two helpers are the lossless bridge between those models.
local function EdgeToCenter(edge, position)
	local frame = _G.PallyPowerFrame
	local scale = 1
	if frame and frame.GetEffectiveScale and UIParent.GetEffectiveScale then
		scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	end
	local width = ((edge == "TOP" or edge == "BOTTOM") and 44 or 42) * scale
	local height = 22 * scale
	local uiWidth, uiHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local vertical = edge == "LEFT" or edge == "RIGHT"
	local limit = math.max(0, ((vertical and uiHeight or uiWidth) - (vertical and height or width)) / 2)
	local along = (Clamp(tonumber(position) or 50, 0, 100) - 50) * limit / 50

	if edge == "LEFT" then return -uiWidth / 2 + width / 2, along end
	if edge == "TOP" then return along, uiHeight / 2 - height / 2 end
	if edge == "BOTTOM" then return along, -uiHeight / 2 + height / 2 end
	return uiWidth / 2 - width / 2, along
end

local function CenterToEdge(x, y)
	local frame = _G.PallyPowerFrame
	local scale = 1
	if frame and frame.GetEffectiveScale and UIParent.GetEffectiveScale then
		scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	end
	local uiWidth, uiHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local horizontalWidth = 44 * scale
	local height = 22 * scale
	local currentWidth = ((frame and frame:GetWidth()) or 42) * scale
	local currentHeight = ((frame and frame:GetHeight()) or 22) * scale
	local distances = {
		LEFT = x + uiWidth / 2 - currentWidth / 2,
		RIGHT = uiWidth / 2 - x - currentWidth / 2,
		TOP = uiHeight / 2 - y - currentHeight / 2,
		BOTTOM = y + uiHeight / 2 - currentHeight / 2,
	}
	local edge, nearest = "RIGHT", distances.RIGHT
	for _, candidate in ipairs({ "LEFT", "RIGHT", "TOP", "BOTTOM" }) do
		if distances[candidate] < nearest then
			edge, nearest = candidate, distances[candidate]
		end
	end

	local vertical = edge == "LEFT" or edge == "RIGHT"
	local length = vertical and height or horizontalWidth
	local limit = math.max(0, ((vertical and uiHeight or uiWidth) - length) / 2)
	local along = vertical and y or x
	local position = limit > 0 and (50 + Clamp(along, -limit, limit) * 50 / limit) or 50
	return edge, Clamp(position, 0, 100)
end

local function IsMouseOverFrame(frame)
	return frame and frame:IsShown() and MouseIsOver(frame)
end

function PallyPower:GetEdgeFlyoutAlignment()
	local edge = self.opt and self.opt.display and self.opt.display.flyoutEdge or "RIGHT"
	return EDGE_ALIGNMENT[edge] or EDGE_ALIGNMENT.RIGHT
end

function PallyPower:GetEdgeFlyoutPlayerAlignment()
	local edge = self.opt and self.opt.display and self.opt.display.flyoutEdge or "RIGHT"
	return edge == "RIGHT" and "compact-left" or "compact-right"
end

function PallyPower:CreateEdgeFlyout()
	if self.edgeTabReady then return end
	local tab = _G.PallyPowerAnchor
	if not tab then return end

	self.edgeTab = tab
	self.edgeFlyoutChildren = { self.autoButton, self.rfButton, self.auraButton }
	for i = 1, PALLYPOWER_MAXCLASSES do
		self.edgeFlyoutChildren[#self.edgeFlyoutChildren + 1] = self.classButtons[i]
	end

	tab:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", tile = false })
	tab:SetBackdropColor(0.025, 0.035, 0.045, 0.96)
	tab:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	local highlight = tab:GetHighlightTexture()
	if highlight then
		local accent = EllesmereUI.ELLESMERE_GREEN or { r = 0.05, g = 0.82, b = 0.62 }
		highlight:SetVertexColor(accent.r, accent.g, accent.b, 0.22)
		highlight:SetAllPoints(tab)
	end

	local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER", tab, "CENTER", 0, 0)
	tab.label = label

	SecureHandlerExecute(tab, [[flyoutChildren = table.new()]])
	for i, child in ipairs(self.edgeFlyoutChildren) do
		SecureHandlerSetFrameRef(tab, "flyoutChild", child)
		SecureHandlerExecute(tab, [[
			local child = self:GetFrameRef("flyoutChild")
			flyoutChildren[#flyoutChildren + 1] = child
		]])
	end
	tab:SetAttribute("_onenter", [[
		local lead = self:GetFrameRef("flyoutLead")
		local pinned = self:GetAttribute("EUIFlyoutPinned") == 1
		if lead and lead:GetAttribute("EUIFlyoutDisplay") == 1 then
			lead:Show()
			if not pinned then
				lead:RegisterAutoHide(1.25)
				lead:AddToAutoHide(self)
			end
		else
			lead = nil
		end
		for _, child in ipairs(flyoutChildren) do
			if child:GetAttribute("EUIFlyoutDisplay") == 1 then
				child:Show()
				if lead and not pinned and child ~= lead then lead:AddToAutoHide(child) end
			end
		end
	]])
	SecureHandlerSetFrameRef(tab, "flyoutLead", self.autoButton)

	self.edgeTabReady = true
	if self.ApplyEUIStyle then self:ApplyEUIStyle() end
	if self.RegisterEdgeUnlock then self:RegisterEdgeUnlock() end
end

function PallyPower:CollapseEdgeFlyout()
	if InCombatLockdown() or not self.edgeFlyoutChildren then return end
	for _, child in ipairs(self.edgeFlyoutChildren) do child:Hide() end
	for _, buttons in pairs(self.playerButtons or {}) do
		for _, button in pairs(buttons) do button:Hide() end
	end
end

function PallyPower:UpdateEdgeFlyout()
	if InCombatLockdown() then
		self._profileRefreshPending = true
		return
	end
	if not self.edgeTabReady then self:CreateEdgeFlyout() end
	local tab = self.edgeTab
	local display = self.opt and self.opt.display
	if not tab or not display then return end

	local edge = display.flyoutEdge or "RIGHT"
	if not EDGE_ALIGNMENT[edge] then edge = "RIGHT" end
	local position = tonumber(display.flyoutPosition) or 50
	if position < 0 then position = 0 elseif position > 100 then position = 100 end
	local vertical = edge == "LEFT" or edge == "RIGHT"
	local span = vertical and UIParent:GetHeight() or UIParent:GetWidth()
	local tabWidth = vertical and 42 or 44
	local tabHeight = 22
	local tabLength = (vertical and tabHeight or tabWidth) * (PallyPowerFrame:GetScale() or 1)
	local limit = math.max(0, (span - tabLength) / 2)
	local offset = (position - 50) * limit / 50

	PallyPowerFrame:SetMovable(false)
	PallyPowerFrame:SetSize(tabWidth, tabHeight)
	PallyPowerFrame:ClearAllPoints()
	PallyPowerFrame:SetPoint(edge, UIParent, edge, vertical and 0 or offset, vertical and offset or 0)

	tab:ClearAllPoints()
	tab:SetAllPoints(PallyPowerFrame)

	-- The controls originate at the tab's inward edge, so the EUI-styled tab is
	-- a true handle beside the bars rather than an overlay covering their end.
	local header = self.Header
	if header and header ~= PallyPowerFrame then
		header:ClearAllPoints()
		if edge == "LEFT" then
			header:SetPoint("LEFT", PallyPowerFrame, "RIGHT", 0, 0)
		elseif edge == "RIGHT" then
			header:SetPoint("RIGHT", PallyPowerFrame, "LEFT", 0, 0)
		elseif edge == "TOP" then
			header:SetPoint("TOP", PallyPowerFrame, "BOTTOM", 0, 0)
		else
			header:SetPoint("BOTTOM", PallyPowerFrame, "TOP", 0, 0)
		end
	end
	if tab.label then tab.label:SetText(EDGE_LABEL[edge]) end

	local primary = { self.autoButton, self.rfButton, self.auraButton }
	if edge == "TOP" or edge == "BOTTOM" then
		local step = (display.buttonHeight or 34) + (display.gapping or -1)
		local primaryOffset = 0
		local anchorPoint = edge == "TOP" and "TOPRIGHT" or "BOTTOMRIGHT"
		local direction = edge == "TOP" and -1 or 1
		for _, child in ipairs(primary) do
			if child:IsShown() then
				child:ClearAllPoints()
				child:SetPoint(anchorPoint, self.Header, "CENTER", 0, primaryOffset)
				primaryOffset = primaryOffset + direction * step
			end
		end
	end
	for _, child in ipairs(primary) do
		child:SetAttribute("EUIFlyoutDisplay", child:IsShown() and 1 or 0)
	end
	for _, child in ipairs(self.classButtons or {}) do
		local enabled = child:GetAttribute("Display") == 1
		child:SetAttribute("EUIFlyoutDisplay", enabled and 1 or 0)
	end

	if not self:IsPlayerPaladin() then
		tab:Hide()
		self:CollapseEdgeFlyout()
		return
	end
	tab:Show()
	tab:SetAttribute("EUIFlyoutPinned", display.flyoutPinned and 1 or 0)
	if display.flyoutPinned then
		for _, child in ipairs(self.edgeFlyoutChildren) do
			if child:GetAttribute("EUIFlyoutDisplay") == 1 then child:Show() else child:Hide() end
		end
	else
		self:CollapseEdgeFlyout()
	end
end

function PallyPower:UpdateAnchor()
	self:UpdateEdgeFlyout()
end

function PallyPower:ClickEdgeTab(_, mouseButton)
	if mouseButton == "RightButton" then
		if not InCombatLockdown() then
			EllesmereUI:ShowModule("EllesmereUIPallyPower")
			EllesmereUI:SelectPage("Assignments")
		end
		return
	end
	if InCombatLockdown() then return end
	self.opt.display.flyoutPinned = not self.opt.display.flyoutPinned
	self:UpdateLayout()
end

function PallyPower:EdgeTabEnter(tab)
	local edge = self.opt.display.flyoutEdge or "RIGHT"
	local anchor = edge == "RIGHT" and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
	GameTooltip:SetOwner(tab, anchor)
	GameTooltip:SetText("PallyPower")
	GameTooltip:AddLine("Hover to open the blessing controls.", 1, 1, 1)
	GameTooltip:AddLine("Left-click to keep the flyout open.", 0.75, 0.75, 0.75)
	GameTooltip:AddLine("Right-click for EUI assignments.", 0.75, 0.75, 0.75)
	GameTooltip:Show()
end

function PallyPower:EdgeTabLeave()
	GameTooltip:Hide()
	if self.opt.display.flyoutPinned or InCombatLockdown() then return end
	self:ScheduleEvent("EllesmereUIPallyPowerFlyoutClose", function()
		if self.opt.display.flyoutPinned then return end
		if IsMouseOverFrame(self.edgeTab) then return end
		for _, child in ipairs(self.edgeFlyoutChildren or {}) do
			if IsMouseOverFrame(child) then return end
		end
		self:CollapseEdgeFlyout()
	end, 0.2)
end

function PallyPower:RegisterEdgeUnlock()
	if not EllesmereUI.RegisterUnlockElements or not EllesmereUI.MakeUnlockElement then return end
	local addon = self
	if EllesmereUI.RegisterUnlockModeListener and not self._edgeUnlockListener then
		self._edgeUnlockListener = true
		EllesmereUI:RegisterUnlockModeListener("EllesmereUIPallyPower", function(active)
			-- The generic discard path restores a mover with CENTER coordinates.
			-- Reassert the module-owned edge anchor after the transaction closes.
			if not active and addon.opt then addon:UpdateEdgeFlyout() end
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
			noInitHook = true,
			subtitle = "Snaps to the nearest screen edge",
			isHidden = function() return not addon:IsPlayerPaladin() end,
			getFrame = function() return _G.PallyPowerFrame end,
			getSize = function()
				local edge = addon.opt and addon.opt.display and addon.opt.display.flyoutEdge or "RIGHT"
				return (edge == "TOP" or edge == "BOTTOM") and 44 or 42, 22
			end,
			loadPos = function()
				local display = addon.opt and addon.opt.display
				if not display then return nil end
				local x, y = EdgeToCenter(display.flyoutEdge or "RIGHT", display.flyoutPosition or 50)
				return { point = "CENTER", relPoint = "CENTER", x = x, y = y }
			end,
			savePos = function(_, _, _, x, y)
				local display = addon.opt and addon.opt.display
				if not display then return end
				display.flyoutEdge, display.flyoutPosition = CenterToEdge(x or 0, y or 0)
				addon:UpdateEdgeFlyout()
			end,
			clearPos = function()
				local display = addon.opt and addon.opt.display
				if not display then return end
				display.flyoutEdge, display.flyoutPosition = "RIGHT", 50
				addon:UpdateEdgeFlyout()
			end,
			applyPos = function() addon:UpdateEdgeFlyout() end,
		}),
	}, "EllesmereUIPallyPower")
end

_G._EPP_RegisterUnlock = function()
	if PallyPower and PallyPower.RegisterEdgeUnlock then PallyPower:RegisterEdgeUnlock() end
end
