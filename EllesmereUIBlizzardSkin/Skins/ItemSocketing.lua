local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local ipairs = ipairs
local select = select

local buttonState = setmetatable({}, { __mode = "k" })

local function HideTexture(texture)
	if not texture then return end
	texture:SetAlpha(0)
	texture:Hide()
end

local function HideNativeDecorations(owner, keepIcon, seen, keepSocketColor)
	if not owner or not owner.GetObjectType then return end
	seen = seen or {}
	if seen[owner] then return end
	seen[owner] = true
	if owner.GetRegions then
		for i = 1, owner:GetNumRegions() do
			local region = select(i, owner:GetRegions())
			if region and region.IsObjectType and region:IsObjectType("Texture")
				and region ~= keepIcon and region ~= keepSocketColor then
				HideTexture(region)
			end
		end
	end
	if owner.GetChildren then
		for i = 1, owner:GetNumChildren() do
			HideNativeDecorations(select(i, owner:GetChildren()), keepIcon, seen, keepSocketColor)
		end
	end
end

local function HideWindowArt(_, nativeTextures)
	for _, region in ipairs(nativeTextures) do HideTexture(region) end
end

local function LayoutSocketWindow(frame)
	local geometry = WSkin.Retail.geometry
	local inset = geometry.bodyInset
	local scroll = _G.ItemSocketingScrollFrame
	local scrollbar = _G.ItemSocketingScrollFrameScrollBar
	if scroll then
		WSkin:StripTextures(scroll)
		local width = math.max(0, frame:GetWidth() - inset * 2 - geometry.scrollbarWidth - 4)
		local height = math.max(0, frame:GetHeight() - 89 - 123)
		scroll:ClearAllPoints()
		WSkin:Size(scroll, width, height)
		WSkin:Point(scroll, "TOPLEFT", frame, "TOPLEFT", inset, -89)
		if scrollbar then
			WSkin:HandleRetailScrollBar(scrollbar)
			scrollbar:ClearAllPoints()
			WSkin:Point(scrollbar, "TOPLEFT", scroll, "TOPRIGHT", 4, -18)
			WSkin:Point(scrollbar, "BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 18)
		end
		if _G.ItemSocketingScrollChild then
			WSkin:Width(_G.ItemSocketingScrollChild, width)
		end
		if _G.ItemSocketingDescription and _G.ItemSocketingDescription.SetMinimumWidth then
			_G.ItemSocketingDescription:SetMinimumWidth(width, 1)
		end
	end

	local portrait = _G.ItemSocketingFramePortrait
	if portrait then
		portrait:ClearAllPoints()
		WSkin:Size(portrait, 44, 44)
		WSkin:Point(portrait, "TOPLEFT", frame, "TOPLEFT", inset, -8)
		WSkin:ApplyRetailIcon(portrait, frame, 44)
	end
end

local function StyleSocketButton(button)
	if not button then return end
	local state = buttonState[button]
	if not state then
		state = {}
		buttonState[button] = state
		if button.SetNormalTexture then button:SetNormalTexture("") end
		if button.SetPushedTexture then button:SetPushedTexture("") end
		if button.SetHighlightTexture then button:SetHighlightTexture("") end
		if button.SetDisabledTexture then button:SetDisabledTexture("") end
		WSkin:ApplyRetailSurface(button, "input")
		WSkin:StyleButton(button)
		state.highlight = button.GetHighlightTexture and button:GetHighlightTexture()
		state.pushed = button.GetPushedTexture and button:GetPushedTexture()
	end

	local name = button.GetName and button:GetName()
	local icon = button.IconTexture or (name and _G[name .. "IconTexture"])
	local socketColor = name and _G[name .. "Background"]
	state.icon = icon
	state.iconBorder = icon and WSkin:ApplyRetailIcon(icon, button, 34)
	-- Keep Blizzard's gem-color fill: it communicates the empty socket's
	-- required color. Strip only the surrounding metal/bracket decoration.
	HideNativeDecorations(button, icon, nil, socketColor)
	if state.highlight then state.highlight:Show() end
	if state.pushed then state.pushed:Show() end
	if state.iconBorder then state.iconBorder:Show() end
end

local function StyleSocketActionButton(button)
	if not button then return end
	local state = buttonState[button]
	if not state then
		state = {}
		buttonState[button] = state
		WSkin:HandleRetailButton(button, true)
		WSkin:StyleButton(button)
		state.highlight = button.GetHighlightTexture and button:GetHighlightTexture()
		state.pushed = button.GetPushedTexture and button:GetPushedTexture()
	end
	local name = button.GetName and button:GetName()
	for _, key in ipairs({ "Left", "Middle", "Right" }) do
		local region = button[key] or (name and _G[name .. key])
		if region then HideTexture(region) end
	end
	if state.highlight then state.highlight:Show() end
	if state.pushed then state.pushed:Show() end
	WSkin:ApplyRetailTypography(button.GetFontString and button:GetFontString(), "button")
end

local applyingSocketSkin = false

local function ApplySocketSkin()
	if applyingSocketSkin then return end
	local frame = _G.ItemSocketingFrame
	if not frame then return end
	applyingSocketSkin = true
	LayoutSocketWindow(frame)
	for i = 1, (_G.MAX_NUM_SOCKETS or 3) do
		StyleSocketButton(_G["ItemSocketingSocket" .. i])
	end
	StyleSocketActionButton(_G.ItemSocketingSocketButton)
	applyingSocketSkin = false
end

local function QueueSocketSkin()
	C_Timer.After(0, ApplySocketSkin)
end

local function SkinItemSocketing()
	local frame = _G.ItemSocketingFrame
	if not frame then return end
	local state = buttonState[frame]
	if not state then
		state = {}
		buttonState[frame] = state
		local nativeTextures = {}
		local portrait = _G.ItemSocketingFramePortrait
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if region and region.IsObjectType and region:IsObjectType("Texture") and region ~= portrait then
				nativeTextures[#nativeTextures + 1] = region
			end
		end
		local nativeTitle
		if _G.ITEM_SOCKETING then
			for i = 1, frame:GetNumRegions() do
				local region = select(i, frame:GetRegions())
				if region and region.IsObjectType and region:IsObjectType("FontString")
					and region:GetText() == _G.ITEM_SOCKETING then
					nativeTitle = region
					region:SetAlpha(0)
					break
				end
			end
		end
		local title = frame:CreateFontString(nil, "OVERLAY")
		WSkin:ApplyRetailTypography(title, "title")
		title:SetText(_G.ITEM_SOCKETING or "Socketing")
		local artRegions = {
			{ object = frame, action = function(_, owner) HideWindowArt(owner, nativeTextures) end },
		}
		if nativeTitle then artRegions[#artRegions + 1] = { object = nativeTitle, action = "hide" } end
		WSkin:SkinRetailWindow(frame, {
			shellOnFrame = true,
			strip = false,
			pageSurface = { top = 82, bottom = 48, inset = WSkin.Retail.geometry.bodyInset },
			headerBand = WSkin.Retail.geometry.twoLineHeaderHeight,
			titleRegion = title,
			titlePosition = { point = "TOP", y = -18 },
			closeButton = _G.ItemSocketingCloseButton,
			artRegions = artRegions,
			rehideOnShow = true,
			rehideHooks = { "ItemSocketingFrame_Update", "ItemSocketingSocketButton_OnScrollRangeChanged" },
		})
		state.title = title
		frame:HookScript("OnShow", ApplySocketSkin)
	end
	ApplySocketSkin()
	if type(_G.ItemSocketingFrame_Update) == "function" and not state.updateHooked then
		state.updateHooked = true
		hooksecurefunc("ItemSocketingFrame_Update", ApplySocketSkin)
	end
	if type(_G.ItemSocketingSocketButton_OnScrollRangeChanged) == "function" and not state.scrollHooked then
		state.scrollHooked = true
		hooksecurefunc("ItemSocketingSocketButton_OnScrollRangeChanged", QueueSocketSkin)
	end
end

-- This owns Blizzard's standalone ItemSocketingFrame. SocketPanel.lua only
-- skins the Character sheet's separate socket flyout and remains independent.
WSkin:AddCallbackForAddon("Blizzard_ItemSocketingUI", "Skin_ItemSocketing", SkinItemSocketing, "socket")
