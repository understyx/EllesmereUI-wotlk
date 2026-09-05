local WSkin = {}
_G.EllesmereUIBlizzardSkin = WSkin
WSkin.TexCoords = { 0.08, 0.92, 0.08, 0.92 }

local _G = _G
local unpack, type, select, getmetatable = unpack, type, select, getmetatable
local CreateFrame = CreateFrame

-- Texture references
local blankTex = "Interface\\Buttons\\WHITE8X8"
local closeTex = "Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-close.tga"

local backdropr, backdropg, backdropb, backdropa, borderr, borderg, borderb = 0, 0, 0, 1, 0, 0, 0
local mult = 1

local function Scale(x) return x end

local function Size(frame, width, height)
	frame:SetSize(Scale(width), Scale(height or width))
end

local function Width(frame, width)
	frame:SetWidth(Scale(width))
end

local function Height(frame, height)
	frame:SetHeight(Scale(height))
end

local function Point(obj, arg1, arg2, arg3, arg4, arg5)
	if type(arg5) == "number" then
		arg5 = Scale(arg5)
		arg4 = Scale(arg4)
	elseif type(arg4) == "number" then
		arg4 = Scale(arg4)
		arg3 = Scale(arg3)
	elseif type(arg3) == "number" then
		arg3 = Scale(arg3)
		arg2 = Scale(arg2)
	end
	obj:SetPoint(arg1, arg2 or obj:GetParent(), arg3, arg4, arg5)
end

local function SetOutside(obj, anchor, xOffset, yOffset, anchor2)
	if type(anchor) == "number" then
		anchor2 = yOffset
		yOffset = xOffset
		xOffset = anchor
		anchor = nil
	end
	anchor = (type(anchor) == "table" or type(anchor) == "userdata") and anchor or (obj.GetParent and obj:GetParent())
	xOffset = type(xOffset) == "number" and xOffset or 1
	yOffset = type(yOffset) == "number" and yOffset or 1
	anchor2 = (type(anchor2) == "table" or type(anchor2) == "userdata") and anchor2 or nil

	if obj:GetPoint() then obj:ClearAllPoints() end
	Point(obj, "TOPLEFT", anchor, "TOPLEFT", -xOffset, yOffset)
	Point(obj, "BOTTOMRIGHT", anchor2 or anchor, "BOTTOMRIGHT", xOffset, -yOffset)
end

local function SetInside(obj, anchor, xOffset, yOffset, anchor2)
	if type(anchor) == "number" then
		anchor2 = yOffset
		yOffset = xOffset
		xOffset = anchor
		anchor = nil
	end
	anchor = (type(anchor) == "table" or type(anchor) == "userdata") and anchor or (obj.GetParent and obj:GetParent())
	xOffset = type(xOffset) == "number" and xOffset or 1
	yOffset = type(yOffset) == "number" and yOffset or 1
	anchor2 = (type(anchor2) == "table" or type(anchor2) == "userdata") and anchor2 or nil

	if obj:GetPoint() then obj:ClearAllPoints() end
	Point(obj, "TOPLEFT", anchor, "TOPLEFT", xOffset, -yOffset)
	Point(obj, "BOTTOMRIGHT", anchor2 or anchor, "BOTTOMRIGHT", -xOffset, yOffset)
end

local function SetTemplate(frame, template, glossTex, ignoreUpdates, forcePixelMode, isUnitFrameElement)
	borderr, borderg, borderb = 0.2, 0.2, 0.2
	if template == "Transparent" then
		backdropr, backdropg, backdropb, backdropa = 0, 0, 0, 0.8
	else
		backdropr, backdropg, backdropb, backdropa = 0.1, 0.1, 0.1, 1
	end

	frame:SetBackdrop({
		bgFile = blankTex,
		edgeFile = blankTex,
		tile = false, tileSize = 0, edgeSize = mult,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	})
	frame:SetBackdropColor(backdropr, backdropg, backdropb, backdropa)
	frame:SetBackdropBorderColor(borderr, borderg, borderb)
end

local function CreateBackdrop(frame, template, glossTex, ignoreUpdates, forcePixelMode, isUnitFrameElement)
	if not template then template = "Default" end
	local parent = (frame.IsObjectType and frame:IsObjectType("Texture") and frame:GetParent()) or frame
	local backdrop = frame.backdrop or CreateFrame("Frame", nil, parent)
	if not frame.backdrop then frame.backdrop = backdrop end

	SetOutside(backdrop, frame)
	SetTemplate(backdrop, template)

	local frameLevel = parent.GetFrameLevel and parent:GetFrameLevel()
	local frameLevelMinusOne = frameLevel and (frameLevel - 1)
	if frameLevelMinusOne and (frameLevelMinusOne >= 0) then
		backdrop:SetFrameLevel(frameLevelMinusOne)
	else
		backdrop:SetFrameLevel(0)
	end
end

local function Kill(object)
	if not object then return end
	if type(object) == "string" then object = _G[object] end
	if not object then return end
	if object.UnregisterAllEvents then
		object:UnregisterAllEvents()
		object:SetParent(CreateFrame("Frame"))
	else
		object.Show = function() end
	end
	if object.Hide then object:Hide() end
end

local function StripTextures(object, kill, alpha)
	if not object then return end
	if type(object) == "string" then object = _G[object] end
	if not object then return end
	if object.IsObjectType and object:IsObjectType("Texture") then
		if kill then
			Kill(object)
		elseif alpha then
			object:SetAlpha(0)
		else
			object:SetTexture()
		end
	else
		if object.GetNumRegions then
			for i = 1, object:GetNumRegions() do
				local region = select(i, object:GetRegions())
				if region and region.IsObjectType and region:IsObjectType("Texture") then
					if kill then
						Kill(region)
					elseif alpha then
						region:SetAlpha(0)
					else
						region:SetTexture()
					end
				end
			end
		end
	end
end

local function StyleButton(button, noHover, noPushed, noChecked)
	if button.SetHighlightTexture and not button.hover and not noHover then
		local hover = button:CreateTexture()
		SetInside(hover)
		hover:SetTexture(1, 1, 1, 0.3)
		button:SetHighlightTexture(hover)
		button.hover = hover
	end
	if button.SetPushedTexture and not button.pushed and not noPushed then
		local pushed = button:CreateTexture()
		SetInside(pushed)
		pushed:SetTexture(0.9, 0.8, 0.1, 0.3)
		button:SetPushedTexture(pushed)
		button.pushed = pushed
	end
	if button.SetCheckedTexture and not button.checked and not noChecked then
		local checked = button:CreateTexture()
		SetInside(checked)
		checked:SetTexture(1, 1, 1, 0.3)
		button:SetCheckedTexture(checked)
		button.checked = checked
	end
	local name = button.GetName and button:GetName()
	local cooldown = name and _G[name.."Cooldown"]
	if cooldown then
		cooldown:ClearAllPoints()
		SetInside(cooldown)
	end
end

local CreateCloseButton
do
	local CloseButtonOnClick = function(btn) btn:GetParent():Hide() end
	local CloseButtonOnEnter = function(btn) if btn.Texture then btn.Texture:SetVertexColor(1, 1, 1, 1) end end
	local CloseButtonOnLeave = function(btn) if btn.Texture then btn.Texture:SetVertexColor(1, 1, 1, 0.75) end end
	CreateCloseButton = function(frame, size, offset, texture, backdrop)
		if frame.CloseButton then return end
		local CloseButton = CreateFrame("Button", nil, frame)
		Size(CloseButton, size or 16)
		Point(CloseButton, "TOPRIGHT", offset or -6, offset or -6)
		if backdrop then CreateBackdrop(CloseButton, nil, true) end
		CloseButton.Texture = CloseButton:CreateTexture(nil, "OVERLAY")
		CloseButton.Texture:SetPoint("CENTER", 0, 0)
		CloseButton.Texture:SetSize(14, 14)
		CloseButton.Texture:SetTexture(texture or closeTex)
		CloseButton.Texture:SetVertexColor(1, 1, 1, 0.75)
		CloseButton:SetScript("OnClick", CloseButtonOnClick)
		CloseButton:SetScript("OnEnter", CloseButtonOnEnter)
		CloseButton:SetScript("OnLeave", CloseButtonOnLeave)
		frame.CloseButton = CloseButton
	end
end

local function FontTemplate(fs, font, fontSize, fontStyle)
	if not fs or not fs.SetFont then return end
	font = font or (EllesmereUI and EllesmereUI.GetFontPath and EllesmereUI.GetFontPath()) or "Fonts\\FRIZQT__.TTF"
	fontSize = fontSize or 12
	fontStyle = fontStyle or ""

	fs:SetFont(font, fontSize, fontStyle)

	if fontStyle == "NONE" or fontStyle == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
		fs:SetShadowColor(0, 0, 0, 0)
	end
end

-- Expose methods directly on WSkin to accept self (WSkin) as first argument
WSkin.Size = function(self, frame, ...) return Size(frame, ...) end
WSkin.Width = function(self, frame, ...) return Width(frame, ...) end
WSkin.Height = function(self, frame, ...) return Height(frame, ...) end
WSkin.Point = function(self, frame, ...) return Point(frame, ...) end
WSkin.SetOutside = function(self, frame, ...) return SetOutside(frame, ...) end
WSkin.SetInside = function(self, frame, ...) return SetInside(frame, ...) end
WSkin.SetTemplate = function(self, frame, ...) return SetTemplate(frame, ...) end
WSkin.CreateBackdrop = function(self, frame, ...) return CreateBackdrop(frame, ...) end
WSkin.Kill = function(self, frame, ...) return Kill(frame, ...) end
WSkin.StripTextures = function(self, frame, ...) return StripTextures(frame, ...) end
WSkin.StyleButton = function(self, frame, ...) return StyleButton(frame, ...) end
WSkin.CreateCloseButton = function(self, frame, ...) return CreateCloseButton(frame, ...) end
WSkin.FontTemplate = function(self, frame, ...)
	if type(self) == "table" and self == WSkin then
		return FontTemplate(frame, ...)
	else
		return FontTemplate(self, frame, ...)
	end
end

-------------------------------------------------------------------------------
-- Retail visual primitives
--
-- These helpers deliberately use only APIs available on the 3.3.5 client.
-- Keep their state outside Blizzard-owned frames so applying a visual style
-- does not add fields to protected UI objects.
-------------------------------------------------------------------------------
WSkin.Retail = {
	colors = {
		body      = { 0.015, 0.020, 0.025, 0.72 },
		card      = { 0.030, 0.043, 0.048, 0.78 },
		row       = { 0.030, 0.043, 0.048, 0.62 },
		rowAlt    = { 0.030, 0.043, 0.048, 0.80 },
		header    = { 0.055, 0.075, 0.080, 0.98 },
		input     = { 0.025, 0.035, 0.040, 1.00 },
		button    = { 0.070, 0.105, 0.115, 1.00 },
		tab       = { 0.055, 0.043, 0.039, 1.00 },
		border    = { 1.000, 1.000, 1.000, 0.10 },
		track     = { 1.000, 1.000, 1.000, 0.04 },
		thumb     = { 1.000, 1.000, 1.000, 0.42 },
	},
	geometry = {
		headerHeight = 48,
		bodyInset = 14,
		footerHeight = 45,
		tabHeight = 26,
		rowHeight = 28,
	},
	type = {
		title     = { size = 14, alpha = 1.00 },
		section   = { size = 11, alpha = 0.95 },
		row       = { size = 10, alpha = 0.84 },
		value     = { size = 10, alpha = 1.00 },
		secondary = { size = 9,  alpha = 0.58 },
		tab       = { size = 9,  alpha = 0.50 },
		button    = { size = 10, alpha = 0.92 },
	},
}

local retailState = setmetatable({}, { __mode = "k" })
local function RetailState(object)
	local state = retailState[object]
	if not state then
		state = {}
		retailState[object] = state
	end
	return state
end

local function RetailAccent()
	local accent = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
	return (accent and accent.r) or 0.05,
		(accent and accent.g) or 0.82,
		(accent and accent.b) or 0.62
end

local function RetailColor(kind)
	return WSkin.Retail.colors[kind] or WSkin.Retail.colors.card
end

local function SetTextureColor(texture, color)
	if texture and color then texture:SetTexture(unpack(color)) end
end

function WSkin:GetRetailAccent()
	return RetailAccent()
end

function WSkin:ApplyRetailTypography(fontString, tier, alpha)
	if not fontString or not fontString.SetFont then return end
	local style = WSkin.Retail.type[tier or "row"] or WSkin.Retail.type.row
	local font = (EllesmereUI and EllesmereUI.GetFontPath and EllesmereUI.GetFontPath("blizzardSkin"))
		or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	fontString:SetFont(font, style.size, "")
	fontString:SetTextColor(1, 1, 1, alpha or style.alpha)
	if fontString.SetShadowOffset then fontString:SetShadowOffset(1, -1) end
	if fontString.SetShadowColor then fontString:SetShadowColor(0, 0, 0, 0.75) end
end

function WSkin:ApplyRetailRegionTypography(frame, tier, alpha)
	if not frame or not frame.GetRegions then return end
	for i = 1, select("#", frame:GetRegions()) do
		local region = select(i, frame:GetRegions())
		if region and region.IsObjectType and region:IsObjectType("FontString") then
			self:ApplyRetailTypography(region, tier, alpha)
		end
	end
end

function WSkin:ApplyRetailSurface(frame, kind, r, g, b, a)
	if not frame or not frame.SetBackdrop then return end
	local color = RetailColor(kind or "card")
	frame:SetBackdrop({
		bgFile = blankTex,
		edgeFile = blankTex,
		tile = false,
		tileSize = 0,
		edgeSize = mult,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	frame:SetBackdropColor(r or color[1], g or color[2], b or color[3], a or color[4])
	local border = WSkin.Retail.colors.border
	frame:SetBackdropBorderColor(unpack(border))
	RetailState(frame).surface = true
	return frame
end

function WSkin:CreateRetailPageSurface(pane, top, bottom, inset)
	if not pane or not pane.CreateTexture then return end
	local state = RetailState(pane)
	local surface = state.pageSurface
	if not surface then
		surface = pane:CreateTexture(nil, "BACKGROUND", nil, -6)
		state.pageSurface = surface
		state.pageBorders = {}
		for i = 1, 4 do
			state.pageBorders[i] = pane:CreateTexture(nil, "BACKGROUND", nil, -5)
			state.pageBorders[i]:SetTexture(1, 1, 1, 0.10)
		end
	end
	local geometry = WSkin.Retail.geometry
	inset = inset or geometry.bodyInset
	surface:ClearAllPoints()
	surface:SetPoint("TOPLEFT", pane, "TOPLEFT", inset, -(top or geometry.headerHeight))
	surface:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -inset, bottom or geometry.footerHeight)
	SetTextureColor(surface, WSkin.Retail.colors.body)
	surface:Show()
	local borders = state.pageBorders
	if borders then
		for i = 1, 4 do borders[i]:ClearAllPoints() end
		borders[1]:SetHeight(1)
		borders[1]:SetPoint("TOPLEFT", surface, "TOPLEFT", 0, 0)
		borders[1]:SetPoint("TOPRIGHT", surface, "TOPRIGHT", 0, 0)
		borders[2]:SetHeight(1)
		borders[2]:SetPoint("BOTTOMLEFT", surface, "BOTTOMLEFT", 0, 0)
		borders[2]:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", 0, 0)
		borders[3]:SetWidth(1)
		borders[3]:SetPoint("TOPLEFT", surface, "TOPLEFT", 0, 0)
		borders[3]:SetPoint("BOTTOMLEFT", surface, "BOTTOMLEFT", 0, 0)
		borders[4]:SetWidth(1)
		borders[4]:SetPoint("TOPRIGHT", surface, "TOPRIGHT", 0, 0)
		borders[4]:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", 0, 0)
		for i = 1, 4 do borders[i]:Show() end
	end
	return surface
end

function WSkin:SetRetailPageTitle(frame, title, titleRegion)
	if not frame then return end
	titleRegion = titleRegion or frame.TitleText
	local frameName = frame.GetName and frame:GetName()
	if not titleRegion and frameName then titleRegion = _G[frameName .. "TitleText"] end
	if not titleRegion then return end
	if title ~= nil then titleRegion:SetText(title) end
	titleRegion:ClearAllPoints()
	titleRegion:SetPoint("TOP", frame, "TOP", 0, -6)
	titleRegion:SetJustifyH("CENTER")
	self:ApplyRetailTypography(titleRegion, "title")
	return titleRegion
end

function WSkin:UpdateRetailRow(frame, selected, isHeader, alternate)
	if not frame then return end
	local kind = isHeader and "header" or (alternate and "rowAlt" or "row")
	self:ApplyRetailSurface(frame, kind)
	local state = RetailState(frame)
	if not state.selectionEdge and frame.CreateTexture then
		state.selectionEdge = frame:CreateTexture(nil, "OVERLAY")
		state.selectionEdge:SetWidth(2)
		state.selectionEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		state.selectionEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		if EllesmereUI and EllesmereUI.RegAccent then
			EllesmereUI.RegAccent({ type = "solid", obj = state.selectionEdge, a = 1 })
		end
	end
	if state.selectionEdge then
		local ar, ag, ab = RetailAccent()
		state.selectionEdge:SetTexture(ar, ag, ab, 1)
		state.selectionEdge:SetShown(selected and true or false)
	end
	if selected then
		local ar, ag, ab = RetailAccent()
		frame:SetBackdropColor(ar * 0.18, ag * 0.18, ab * 0.18, 0.92)
		frame:SetBackdropBorderColor(ar, ag, ab, 0.55)
	else
		frame:SetBackdropBorderColor(1, 1, 1, isHeader and 0.14 or 0.06)
	end
end

function WSkin:UpdateRetailAccordionHeader(frame, glyph, expanded)
	if not frame then return end
	self:UpdateRetailRow(frame, false, true)
	if glyph then
		self:ApplyRetailTypography(glyph, "section")
		local ar, ag, ab = RetailAccent()
		glyph:SetTextColor(ar, ag, ab, 1)
		glyph:SetText(expanded and "-" or "+")
		glyph:Show()
	end
end

function WSkin:ApplyRetailIcon(icon, parent, size)
	if not icon then return end
	if size and icon.SetSize then icon:SetSize(size, size) end
	if icon.SetTexCoord then icon:SetTexCoord(unpack(WSkin.TexCoords)) end
	parent = parent or (icon.GetParent and icon:GetParent())
	if not parent or not parent.CreateTexture then return end
	local state = RetailState(icon)
	if not state.border then
		state.border = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
		state.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
		state.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	end
	state.border:SetTexture(1, 1, 1, 0.12)
	state.border:Show()
	return state.border
end

function WSkin:SetRetailIconShown(icon, shown)
	if not icon then return end
	icon:SetShown(shown and true or false)
	local state = RetailState(icon)
	if state.border then state.border:SetShown(shown and true or false) end
end

function WSkin:HandleRetailScrollBar(frame, horizontal)
	if not frame then return end
	local state = RetailState(frame)
	local frameName = frame.GetName and frame:GetName()
	local parent = frame.GetParent and frame:GetParent()
	local thumb = (frame.GetThumbTexture and frame:GetThumbTexture())
		or frame.thumbTexture
		or (frameName and _G[frameName .. "ThumbTexture"])

	StripTextures(frame)
	if horizontal then Height(frame, 8) else Width(frame, 8) end

	if not state.track then
		state.track = frame:CreateTexture(nil, "BACKGROUND")
		if horizontal then
			state.track:SetHeight(2)
			state.track:SetPoint("LEFT", frame, "LEFT", 0, 0)
			state.track:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
		else
			state.track:SetWidth(2)
			state.track:SetPoint("TOP", frame, "TOP", 0, 0)
			state.track:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
		end
	end
	SetTextureColor(state.track, WSkin.Retail.colors.track)
	state.track:Show()

	if thumb then
		if horizontal then
			thumb:SetSize(22, 4)
		else
			thumb:SetSize(4, 22)
		end
		SetTextureColor(thumb, WSkin.Retail.colors.thumb)
		thumb:Show()
		state.thumb = thumb
	end

	if not horizontal and frameName then
		local function HideArrow(arrow)
			if not arrow then return end
			arrow:SetAlpha(0)
			arrow:EnableMouse(false)
		end
		HideArrow(parent and parent.scrollUp)
		HideArrow(parent and parent.scrollDown)
		HideArrow(_G[frameName .. "ScrollUpButton"])
		HideArrow(_G[frameName .. "ScrollDownButton"])
		HideArrow(_G[frameName .. "UpButton"])
		HideArrow(_G[frameName .. "DownButton"])
		HideArrow(_G[frameName .. "ScrollUp"])
		HideArrow(_G[frameName .. "ScrollDown"])
	end
	state.retailScrollBar = true
	return frame
end

local function UpdateRetailButtonVisual(button)
	if not button then return end
	local state = RetailState(button)
	local enabled = true
	if button.IsEnabled then
		local value = button:IsEnabled()
		enabled = value == true or value == 1
	end
	local ar, ag, ab = RetailAccent()
	if state.primary and enabled then
		button:SetBackdropBorderColor(ar, ag, ab, state.hovered and 0.95 or 0.62)
	elseif enabled then
		button:SetBackdropBorderColor(1, 1, 1, state.hovered and 0.26 or 0.12)
	else
		button:SetBackdropBorderColor(1, 1, 1, 0.05)
	end
	local label = button.GetFontString and button:GetFontString()
	if label then
		if state.primary and enabled then
			label:SetTextColor(ar, ag, ab, 1)
		else
			label:SetTextColor(1, 1, 1, enabled and 0.88 or 0.32)
		end
	end
end

function WSkin:HandleRetailButton(button, primary)
	if not button then return end
	local state = RetailState(button)
	state.primary = primary and true or false
	if button.SetNormalTexture then button:SetNormalTexture("") end
	if button.SetHighlightTexture then button:SetHighlightTexture("") end
	if button.SetPushedTexture then button:SetPushedTexture("") end
	if button.SetDisabledTexture then button:SetDisabledTexture("") end
	StripTextures(button)
	self:ApplyRetailSurface(button, "button")
	self:ApplyRetailTypography(button.GetFontString and button:GetFontString(), "button")
	if not state.buttonHooks then
		state.buttonHooks = true
		button:HookScript("OnEnter", function(self)
			RetailState(self).hovered = true
			UpdateRetailButtonVisual(self)
		end)
		button:HookScript("OnLeave", function(self)
			RetailState(self).hovered = false
			UpdateRetailButtonVisual(self)
		end)
		button:HookScript("OnEnable", UpdateRetailButtonVisual)
		button:HookScript("OnDisable", UpdateRetailButtonVisual)
	end
	UpdateRetailButtonVisual(button)
	return button
end

function WSkin:StyleRetailTab(tab)
	if not tab then return end
	local state = RetailState(tab)
	for i = 1, select("#", tab:GetRegions()) do
		local region = select(i, tab:GetRegions())
		if region and region.IsObjectType and region:IsObjectType("Texture")
			and region ~= state.background and region ~= state.activeFill and region ~= state.underline then
			region:SetTexture("")
		end
	end
	for _, key in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
		if tab[key] then tab[key]:SetTexture("") end
	end
	if tab.SetHighlightTexture then tab:SetHighlightTexture("") end

	if not state.background then
		state.background = tab:CreateTexture(nil, "BACKGROUND")
		state.background:SetAllPoints(tab)
	end
	SetTextureColor(state.background, WSkin.Retail.colors.tab)
	state.background:Show()

	if not state.activeFill then
		state.activeFill = tab:CreateTexture(nil, "ARTWORK", nil, -6)
		state.activeFill:SetAllPoints(tab)
		state.activeFill:SetBlendMode("ADD")
	end
	state.activeFill:SetTexture(1, 1, 1, 0.025)

	local nativeLabel = tab.GetFontString and tab:GetFontString()
	local labelText = nativeLabel and nativeLabel:GetText()
	if nativeLabel then nativeLabel:SetTextColor(0, 0, 0, 0) end
	if tab.SetPushedTextOffset then tab:SetPushedTextOffset(0, 0) end
	if not state.label then
		state.label = tab:CreateFontString(nil, "OVERLAY")
		state.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
		state.label:SetJustifyH("CENTER")
		-- Unlike newer clients, 3.3.5 raises "Font not set" when SetText is
		-- called on an untemplated FontString before its first SetFont call.
		self:ApplyRetailTypography(state.label, "tab")
		state.label:SetText(labelText or "")
		if hooksecurefunc and tab.SetText then
			hooksecurefunc(tab, "SetText", function(_, text)
				if text then state.label:SetText(text) end
			end)
		end
	end
	self:ApplyRetailTypography(state.label, "tab")

	if not state.underline then
		state.underline = tab:CreateTexture(nil, "OVERLAY", nil, 6)
		state.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
		state.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
		if EllesmereUI and EllesmereUI.PanelPP and EllesmereUI.PanelPP.DisablePixelSnap then
			EllesmereUI.PanelPP.DisablePixelSnap(state.underline)
			state.underline:SetHeight(EllesmereUI.PanelPP.mult or 1)
		else
			state.underline:SetHeight(1)
		end
		if EllesmereUI and EllesmereUI.RegAccent then
			EllesmereUI.RegAccent({ type = "solid", obj = state.underline, a = 1 })
		end
	end
	local ar, ag, ab = RetailAccent()
	state.underline:SetTexture(ar, ag, ab, 1)
	self:UpdateRetailTab(tab, state.active)
	return tab
end

function WSkin:LayoutRetailTabRow(tabs, owner, tabWidth, gap)
	if not tabs or not owner then return 0 end
	local visible = {}
	for _, tab in ipairs(tabs) do
		if tab and (not tab.IsShown or tab:IsShown()) then
			visible[#visible + 1] = tab
		end
	end
	local count = #visible
	if count == 0 then return 0 end
	gap = gap or 0
	if not tabWidth then
		tabWidth = (owner:GetWidth() - ((count - 1) * gap)) / count
	end
	for i, tab in ipairs(visible) do
		tab:ClearAllPoints()
		tab:SetSize(tabWidth, WSkin.Retail.geometry.tabHeight)
		if i == 1 then
			tab:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
		else
			tab:SetPoint("LEFT", visible[i - 1], "RIGHT", gap, 0)
		end
	end
	return count, tabWidth
end

function WSkin:UpdateRetailTab(tab, active)
	if not tab then return end
	local state = RetailState(tab)
	state.active = active and true or false
	if state.background then state.background:Show() end
	if state.activeFill then state.activeFill:SetShown(state.active) end
	if state.underline then state.underline:SetShown(state.active) end
	if state.label then state.label:SetTextColor(1, 1, 1, state.active and 1 or 0.50) end
end

local fontString = CreateFrame("Frame"):CreateFontString()
local fontStringMt = getmetatable(fontString) and getmetatable(fontString).__index
if fontStringMt and not fontStringMt.FontTemplate then
	fontStringMt.FontTemplate = FontTemplate
end

-- Skins
function WSkin:SetModifiedBackdrop()
	if self.backdrop then self = self.backdrop end
	self:SetBackdropBorderColor(1, 0.82, 0)
end

function WSkin:SetOriginalBackdrop()
	if self.backdrop then self = self.backdrop end
	self:SetBackdropBorderColor(0.2, 0.2, 0.2)
end

function WSkin:HandleButton(button, strip, isDeclineButton, useCreateBackdrop, noSetTemplate)
	if button.isSkinned then return end

	if button.Left then button.Left:SetAlpha(0) end
	if button.Middle then button.Middle:SetAlpha(0) end
	if button.Right then button.Right:SetAlpha(0) end

	if button.SetNormalTexture then button:SetNormalTexture("") end
	if button.SetHighlightTexture then button:SetHighlightTexture("") end
	if button.SetPushedTexture then button:SetPushedTexture("") end
	if button.SetDisabledTexture then button:SetDisabledTexture("") end

	if strip then StripTextures(button) end

	if useCreateBackdrop then
		CreateBackdrop(button, nil, true)
	elseif not noSetTemplate then
		SetTemplate(button, nil, true)
	end

	button:HookScript("OnEnter", WSkin.SetModifiedBackdrop)
	button:HookScript("OnLeave", WSkin.SetOriginalBackdrop)

	button.isSkinned = true
end

function WSkin:HandleCloseButton(f, point)
	if not f then return end
	StripTextures(f)

	if f:GetNormalTexture() then f:SetNormalTexture("") f.SetNormalTexture = function() end end
	if f:GetPushedTexture() then f:SetPushedTexture("") f.SetPushedTexture = function() end end
	if f:GetHighlightTexture() then f:SetHighlightTexture("") f.SetHighlightTexture = function() end end
	if f:GetDisabledTexture() then f:SetDisabledTexture("") f.SetDisabledTexture = function() end end

	for i = 1, select("#", f:GetRegions()) do
		local region = select(i, f:GetRegions())
		if region and region:IsObjectType("Texture") and region ~= f.Texture then
			region:SetAlpha(0)
		end
	end

	if not f.Texture then
		f.Texture = f:CreateTexture(nil, "OVERLAY")
		Point(f.Texture, "CENTER", 0, 0)
		f.Texture:SetTexture(closeTex)
		Size(f.Texture, 14, 14)
		f.Texture:SetVertexColor(1, 1, 1, 0.75)
		f:HookScript("OnEnter", function(btn) if btn.Texture then btn.Texture:SetVertexColor(1, 1, 1, 1) end end)
		f:HookScript("OnLeave", function(btn) if btn.Texture then btn.Texture:SetVertexColor(1, 1, 1, 0.75) end end)
		f:SetHitRectInsets(4, 4, 4, 4)
	else
		f.Texture:SetTexture(closeTex)
		Size(f.Texture, 14, 14)
		f.Texture:SetVertexColor(1, 1, 1, 0.75)
	end

	if point then
		Point(f, "TOPRIGHT", point, "TOPRIGHT", 2, 3)
	end
end

function WSkin:HandleCheckBox(frame, noBackdrop, noReplaceTextures)
	if frame.isSkinned then return end
	StripTextures(frame)

	if noBackdrop then
		SetTemplate(frame)
		Size(frame, 16)
	else
		CreateBackdrop(frame)
		SetInside(frame.backdrop, nil, 4, 4)
	end

	if not noReplaceTextures then
		if frame.SetCheckedTexture then
			frame:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
			if noBackdrop then SetInside(frame:GetCheckedTexture(), nil, -4, -4) end
		end
		if frame.SetDisabledCheckedTexture then
			frame:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
			if noBackdrop then SetInside(frame:GetDisabledCheckedTexture(), nil, -4, -4) end
		end
		if frame.SetDisabledTexture then
			frame:SetDisabledTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
			if noBackdrop then SetInside(frame:GetDisabledTexture(), nil, -4, -4) end
		end

		frame:HookScript("OnDisable", function(checkbox)
			if not checkbox.SetDisabledTexture then return end
			if checkbox:GetChecked() then
				checkbox:SetDisabledTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
			else
				checkbox:SetDisabledTexture("")
			end
		end)

		hooksecurefunc(frame, "SetNormalTexture", function(checkbox, texPath)
			if texPath ~= "" then checkbox:SetNormalTexture("") end
		end)
		hooksecurefunc(frame, "SetPushedTexture", function(checkbox, texPath)
			if texPath ~= "" then checkbox:SetPushedTexture("") end
		end)
		hooksecurefunc(frame, "SetHighlightTexture", function(checkbox, texPath)
			if texPath ~= "" then checkbox:SetHighlightTexture("") end
		end)
	end
	frame.isSkinned = true
end

local tabs = {"LeftDisabled","MiddleDisabled","RightDisabled","Left","Middle","Right"}
function WSkin:HandleTab(tab, noBackdrop)
	if (not tab) or (tab.backdrop and not noBackdrop) then return end
	for _, object in ipairs(tabs) do
		local tex = _G[tab:GetName()..object]
		if tex then tex:SetTexture() end
	end
	local highlightTex = tab.GetHighlightTexture and tab:GetHighlightTexture()
	if highlightTex then highlightTex:SetTexture() else StripTextures(tab) end

	if not noBackdrop then
		CreateBackdrop(tab)
		Point(tab.backdrop, "TOPLEFT", 10, -3)
		Point(tab.backdrop, "BOTTOMRIGHT", -10, 3)
		tab:SetHitRectInsets(10, 10, 3, 3)
	end
end

WSkin.ArrowRotation = {
	["up"] = 0,
	["down"] = 3.14,
	["left"] = 1.57,
	["right"] = -1.57,
}

function WSkin:HandleNextPrevButton(btn, arrowDir, color, noBackdrop, stipTexts)
	if btn.isSkinned then return end

	if not arrowDir then
		arrowDir = "down"
		local name = btn:GetName() and string.lower(btn:GetName())
		if name then
			if string.find(name, "left") or string.find(name, "prev") or string.find(name, "decrement") then arrowDir = "left"
			elseif string.find(name, "right") or string.find(name, "next") or string.find(name, "increment") then arrowDir = "right"
			elseif string.find(name, "scrollup") or string.find(name, "upbutton") or string.find(name, "top") or string.find(name, "promote") then arrowDir = "up"
			end
		end
	end

	StripTextures(btn)
	if not noBackdrop then WSkin:HandleButton(btn) end

	if arrowDir == "up" then
		btn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
		btn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
		btn:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
	elseif arrowDir == "down" then
		btn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
		btn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
		btn:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
	else
		btn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
		btn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
		btn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
	end

	if noBackdrop then
		Size(btn, 20, 20)
	else
		Size(btn, 18, 18)
	end
	
	local Normal = btn:GetNormalTexture()
	local Pushed = btn:GetPushedTexture()
	local Disabled = btn:GetDisabledTexture()
	if Normal then SetInside(Normal) end
	if Pushed then SetInside(Pushed) end
	if Disabled then SetInside(Disabled) end

	btn.isSkinned = true
end

function WSkin:HandleScrollBar(frame, horizontal)
	if frame.backdrop then return end

	local parent = frame:GetParent()
	local frameName = frame:GetName()

	local scrollUpButton, scrollDownButton
	local thumb = frame.thumbTexture or frame.GetThumbTexture and frame:GetThumbTexture() or _G[string.format("%s%s", frameName, "ThumbTexture")]

	if frameName then
		if not horizontal then
			scrollUpButton = parent.scrollUp or _G[string.format("%s%s", frameName, "ScrollUpButton")] or _G[string.format("%s%s", frameName, "UpButton")] or _G[string.format("%s%s", frameName, "ScrollUp")]
			scrollDownButton = parent.scrollDown or _G[string.format("%s%s", frameName, "ScrollDownButton")] or _G[string.format("%s%s", frameName, "DownButton")] or _G[string.format("%s%s", frameName, "ScrollDown")]
		end
	end

	if not horizontal then Width(frame, 18) else Height(frame, 18) end

	local frameLevel = frame:GetFrameLevel()
	StripTextures(frame)
	CreateBackdrop(frame)
	frame.backdrop:SetAllPoints()
	frame.backdrop:SetFrameLevel(frameLevel)

	if scrollUpButton then
		if not horizontal then
			Point(scrollUpButton, "BOTTOM", frame, "TOP", 0, 1)
			WSkin:HandleNextPrevButton(scrollUpButton, "up")
		end
	end

	if scrollDownButton then
		if not horizontal then
			Point(scrollDownButton, "TOP", frame, "BOTTOM", 0, -1)
			WSkin:HandleNextPrevButton(scrollDownButton, "down")
		end
	end

	if thumb and not thumb.backdrop then
		if not horizontal then Size(thumb, 18, 22) else Size(thumb, 22, 18) end
		thumb:SetTexture()
		CreateBackdrop(thumb, nil, true, true)
		thumb.backdrop:SetFrameLevel(frameLevel + 1)
		thumb.backdrop:SetBackdropColor(0.6, 0.6, 0.6)
		Point(thumb.backdrop, "TOPLEFT", thumb, "TOPLEFT", 2, -2)
		Point(thumb.backdrop, "BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)
		if not frame.thumbTexture then frame.thumbTexture = thumb end
	end
end

function WSkin:SetUIPanelWindowInfo(frame, prop, val, offset)
end

function WSkin:SetBackdropHitRect(frame, backdrop)
	if not frame then return end
	if not backdrop then backdrop = frame.backdrop end
	if backdrop and frame then
		frame:SetHitRectInsets(backdrop:GetLeft() - frame:GetLeft(), frame:GetRight() - backdrop:GetRight(), backdrop:GetTop() - frame:GetTop(), frame:GetBottom() - backdrop:GetBottom())
	end
end

function WSkin:HandleDropDownBox(frame, width, direction)
	if frame.backdrop then return end

	local FrameName = frame.GetName and frame:GetName()
	local button = FrameName and _G[FrameName.."Button"]
	local text = FrameName and _G[FrameName.."Text"]

	StripTextures(frame)
	CreateBackdrop(frame)
	frame.backdrop:SetFrameLevel(frame:GetFrameLevel())
	Point(frame.backdrop, "TOPLEFT", 20, -3)
	Point(frame.backdrop, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)

	if not width then width = 155 end
	Width(frame, width)

	if text then
		text:ClearAllPoints()
		Point(text, "RIGHT", button, "LEFT", -2, 0)
	end

	if button then
		WSkin:HandleNextPrevButton(button, direction or "down")
		button:ClearAllPoints()
		Point(button, "RIGHT", frame, "RIGHT", -10, 3)
		Size(button, 16, 16)
	end
end

function WSkin:HandleRotateButton(btn)
	if btn.isSkinned then return end

	SetTemplate(btn)
	Size(btn, btn:GetWidth() - 14, btn:GetHeight() - 14)

	local normTex = btn:GetNormalTexture()
	local pushTex = btn:GetPushedTexture()
	local highlightTex = btn:GetHighlightTexture()

	if normTex then
		SetInside(normTex)
		normTex:SetTexCoord(0.3, 0.29, 0.3, 0.65, 0.69, 0.29, 0.69, 0.65)
	end

	if pushTex then
		pushTex:SetAllPoints(normTex)
		pushTex:SetTexCoord(0.3, 0.29, 0.3, 0.65, 0.69, 0.29, 0.69, 0.65)
	end

	if highlightTex then
		highlightTex:SetAllPoints(normTex)
		highlightTex:SetTexture(1, 1, 1, 0.3)
	end

	btn.isSkinned = true
end

function WSkin:HandleCollapseExpandButton(button, defaultState, useFontString, xOffset, yOffset)
	if button.isSkinned then return end

	button:SetNormalTexture("")
	button:SetPushedTexture("")
	button:SetHighlightTexture("")
	button:SetDisabledTexture("")

	button.SetPushedTexture = function() end
	button.SetHighlightTexture = function() end
	button.SetDisabledTexture = function() end

	if useFontString then
		button.collapseText = button:CreateFontString(nil, "OVERLAY")
		button.collapseText:SetFontObject("GameFontNormal")
		Point(button.collapseText, "LEFT", xOffset or 5, yOffset or 0)
		button.collapseText:SetText(defaultState or "")
		button.SetNormalTexture = function(self, tex)
			if type(tex) == "string" and tex ~= "" then
				if tex:find("MinusButton") or tex:find("ZoomOutButton") then
					self.collapseText:SetText("-")
				else
					self.collapseText:SetText("+")
				end
			end
		end
	else
		local normalTexture = button:GetNormalTexture()
		if normalTexture then
			Size(normalTexture, 16)
			normalTexture:ClearAllPoints()
			Point(normalTexture, "LEFT", xOffset or 3, yOffset or 0)
			normalTexture.SetPoint = function() end
		end

		local pushedTexture = button:GetPushedTexture()
		if pushedTexture then
			Size(pushedTexture, 16)
			pushedTexture:ClearAllPoints()
			Point(pushedTexture, "LEFT", xOffset or 3, yOffset or 0)
			pushedTexture.SetPoint = function() end
		end

		local disabledTexture = button:GetDisabledTexture()
		if disabledTexture then
			Size(disabledTexture, 16)
			disabledTexture:ClearAllPoints()
			Point(disabledTexture, "LEFT", xOffset or 3, yOffset or 0)
			disabledTexture.SetPoint = function() end
			disabledTexture:SetVertexColor(0.6, 0.6, 0.6)
		end
	end
	button.isSkinned = true
end

function WSkin:HandleEditBox(frame)
	if frame.backdrop then return end

	CreateBackdrop(frame)
	frame.backdrop:SetFrameLevel(frame:GetFrameLevel())

	local EditBoxName = frame.GetName and frame:GetName()
	if EditBoxName then
		if _G[EditBoxName.."Left"] then _G[EditBoxName.."Left"]:SetAlpha(0) end
		if _G[EditBoxName.."Middle"] then _G[EditBoxName.."Middle"]:SetAlpha(0) end
		if _G[EditBoxName.."Right"] then _G[EditBoxName.."Right"]:SetAlpha(0) end
		if _G[EditBoxName.."Mid"] then _G[EditBoxName.."Mid"]:SetAlpha(0) end
	end
end

function WSkin:HandleIcon(icon, parent)
	if not icon then return end

	parent = parent or (icon.GetParent and icon:GetParent())

	if icon.SetTexCoord then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	if parent then
		if not parent.backdrop then
			CreateBackdrop(parent, "Default")
		end
		if parent.backdrop then
			icon:SetParent(parent.backdrop)
		end
	end
end

function WSkin:HandleButtonHighlight(frame, r, g, b, a)
	if not frame then return end
	if not r then r = 0.9 end
	if not g then g = 0.9 end
	if not b then b = 0.9 end
	if not a then a = 0.35 end

	local highlightTexture

	if frame.SetHighlightTexture then
		highlightTexture = frame:GetHighlightTexture()
		if highlightTexture then
			highlightTexture:SetAllPoints(frame)
		end
	elseif frame.SetTexture then
		highlightTexture = frame
		if frame.GetParent and frame:GetParent() then
			frame:SetAllPoints(frame:GetParent())
		end
	elseif frame.HighlightTexture then
		highlightTexture = frame.HighlightTexture
	else
		highlightTexture = frame:CreateTexture(nil, "HIGHLIGHT")
		highlightTexture:SetAllPoints(frame)
		frame.HighlightTexture = highlightTexture
	end

	if highlightTexture then
		highlightTexture:SetTexture(1, 1, 1, a)
		highlightTexture:SetVertexColor(r, g, b, a)
	end
end
