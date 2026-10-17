local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local ipairs = ipairs

local function Count(value, fallback)
	return type(value) == "number" and value or fallback
end

local function Point(frame, ...)
	if frame and frame.SetPoint then WSkin:Point(frame, ...) end
end

local function ClearPoints(...)
	for i = 1, select("#", ...) do
		local frame = select(i, ...)
		if frame and frame.ClearAllPoints then frame:ClearAllPoints() end
	end
end

local columnWidths = setmetatable({}, { __mode = "k" })

local function BodyWidth(frame)
	return math.max(0, frame:GetWidth() - (2 * WSkin.Retail.geometry.bodyInset))
end

local function ScrollContentWidth(frame)
	local geometry = WSkin.Retail.geometry
	return math.max(0, BodyWidth(frame) - geometry.scrollbarWidth - 4)
end

local function PlaceScroll(scroll, scrollbar, frame, left, top, width, height)
	if not scroll then return end
	ClearPoints(scroll, scrollbar)
	WSkin:Size(scroll, width, height or scroll:GetHeight())
	Point(scroll, "TOPLEFT", frame, "TOPLEFT", left, -top)
	if scrollbar then
		Point(scrollbar, "TOPLEFT", scroll, "TOPRIGHT", 4, -19)
		Point(scrollbar, "BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 19)
	end
end

local function LayoutColumns(frame, prefixes, count, left, top, width)
	for _, prefix in ipairs(prefixes) do
		local headers, total = {}, 0
		for i = 1, count do
			local header = _G[prefix .. i]
			if header then
				headers[#headers + 1] = header
				local original = columnWidths[header]
				if not original then
					original = math.max(1, header:GetWidth())
					columnWidths[header] = original
				end
				total = total + original
			end
		end
		local previous
		for _, header in ipairs(headers) do
			local headerWidth = width * columnWidths[header] / math.max(1, total)
			header:ClearAllPoints()
			WSkin:Width(header, headerWidth)
			if previous then
				Point(header, "LEFT", previous, "RIGHT", 0, 0)
			else
				Point(header, "TOPLEFT", frame, "TOPLEFT", left, -top)
			end
			previous = header
		end
	end
end

local function LayoutFooterTabs(tabs, owner)
	if not tabs or #tabs == 0 then return end
	local geometry = WSkin.Retail.geometry
	local gap = geometry.tabGap or 1
	local usableWidth = owner:GetWidth() - gap * (#tabs - 1)
	local tabWidth = usableWidth / #tabs
	for index, tab in ipairs(tabs) do
		tab:ClearAllPoints()
		WSkin:Size(tab, tabWidth, geometry.tabHeight)
		Point(tab, "TOPLEFT", owner, "BOTTOMLEFT",
			(index - 1) * (tabWidth + gap), geometry.tabHeight)
	end
end

local function Each(names, handler, ...)
	for _, name in ipairs(names) do
		local object = type(name) == "string" and _G[name] or name
		if object then handler(WSkin, object, ...) end
	end
end

local function SkinPanel(frame, closeButton, left, top, right, bottom)
	if not frame then return end
	local insets
	if left ~= nil or top ~= nil or right ~= nil or bottom ~= nil then
		insets = {
			left = left or 0, top = top or 0,
			right = right or 0, bottom = bottom or 0,
		}
	end
	WSkin:SkinRetailWindow(frame, { closeButton = closeButton, insets = insets })
end

local function Card(frame, kind)
	if not frame then return end
	WSkin:ApplyRetailSurface(frame, kind or "input")
end

local function StyleInput(frame)
	if not frame then return end
	if frame.backdrop then WSkin:ApplyRetailSurface(frame.backdrop, "input") end
	WSkin:ApplyRetailRegionTypography(frame, "row")
end

local function StyleSocialRows()
	local groups = {
		{ "FriendsFrameFriendsScrollFrameButton", Count(_G.FRIENDS_FRIENDS_TO_DISPLAY, 12) },
		{ "FriendsFrameIgnoreButton", Count(_G.IGNORES_TO_DISPLAY, 19) },
		{ "WhoFrameButton", Count(_G.WHOS_TO_DISPLAY, 17) },
		{ "GuildFrameButton", Count(_G.GUILDMEMBERS_TO_DISPLAY, 14) },
		{ "GuildFrameGuildStatusButton", Count(_G.GUILDMEMBERS_TO_DISPLAY, 14) },
	}
	for _, group in ipairs(groups) do
		for i = 1, group[2] do
			local row = _G[group[1] .. i]
			if row then WSkin:UpdateRetailRow(row, false, false, i % 2 == 0) end
		end
	end
end

-- ChannelList_Update reuses each button as either a group header (Group,
-- World, Custom) or a channel entry and recolours its label every pass.
local function StyleChannelRows()
	local ar, ag, ab = WSkin:GetRetailAccent()
	for i = 1, Count(_G.MAX_DISPLAY_CHANNEL_BUTTONS, 20) do
		local button = _G["ChannelButton" .. i]
		local text = _G["ChannelButton" .. i .. "Text"]
		if button then
			WSkin:UpdateRetailRow(button, false, button.header and true or false)
			if text then
				if button.header then
					WSkin:ApplyRetailTypography(text, "section")
				else
					-- Keep Blizzard's active/inactive channel colour.
					local r, g, b = text:GetTextColor()
					WSkin:ApplyRetailTypography(text, "row")
					text:SetTextColor(r, g, b, 1)
				end
			end
			local collapsed = _G["ChannelButton" .. i .. "Collapsed"]
			if collapsed then collapsed:SetTextColor(ar, ag, ab, 1) end
		end
	end
end

local function StyleSocialTabs()
	local frame = _G.FriendsFrame
	if not frame then return end

	local mainTabs = {}
	for i = 1, 5 do
		local tab = _G["FriendsFrameTab" .. i]
		if tab then
			WSkin:StyleRetailTab(tab)
			tab:SetHitRectInsets(0, 0, 0, 0)
			if tab:IsShown() then mainTabs[#mainTabs + 1] = tab end
		end
	end
	local selected = type(_G.PanelTemplates_GetSelectedTab) == "function"
		and _G.PanelTemplates_GetSelectedTab(frame) or frame.selectedTab or 1
	LayoutFooterTabs(mainTabs, frame)
	for _, tab in ipairs(mainTabs) do
		WSkin:UpdateRetailTab(tab, tab:GetID() == selected)
	end

	local header = _G.FriendsTabHeader
	local headerTabs = {}
	for i = 1, 3 do
		local tab = _G["FriendsTabHeaderTab" .. i]
		if tab then
			WSkin:StyleRetailTab(tab)
			tab:SetHitRectInsets(0, 0, 0, 0)
			if tab:IsShown() then headerTabs[#headerTabs + 1] = tab end
		end
	end
	local headerSelected = header and type(_G.PanelTemplates_GetSelectedTab) == "function"
		and _G.PanelTemplates_GetSelectedTab(header) or (header and header.selectedTab) or 1
	if #headerTabs > 0 then
		local width = BodyWidth(frame) / #headerTabs
		for i, tab in ipairs(headerTabs) do
			tab:ClearAllPoints()
			WSkin:Size(tab, width, WSkin.Retail.geometry.tabHeight)
			if i == 1 then
				WSkin:Point(tab, "TOPLEFT", frame, "TOPLEFT", WSkin.Retail.geometry.bodyInset, -60)
			else
				WSkin:Point(tab, "LEFT", headerTabs[i - 1], "RIGHT", 0, 0)
			end
			WSkin:UpdateRetailTab(tab, tab:GetID() == headerSelected)
		end
	end
end

local function LayoutFriendsContent(frame)
	local geometry = WSkin.Retail.geometry
	local left = geometry.bodyInset
	local width = ScrollContentWidth(frame)
	local friendsScroll = _G.FriendsFrameFriendsScrollFrame
	local ignoreScroll = _G.FriendsFrameIgnoreScrollFrame
	PlaceScroll(friendsScroll, _G.FriendsFrameFriendsScrollFrameScrollBar, frame,
		left, 92, width, friendsScroll and friendsScroll:GetHeight() or 307)
	PlaceScroll(ignoreScroll, _G.FriendsFrameIgnoreScrollFrameScrollBar, frame,
		left, 92, width, ignoreScroll and ignoreScroll:GetHeight() or 307)

	for i = 1, Count(_G.FRIENDS_FRIENDS_TO_DISPLAY, 12) do
		local button = _G["FriendsFrameFriendsScrollFrameButton" .. i]
		if button then WSkin:Width(button, width) end
	end
	for i = 1, Count(_G.IGNORES_TO_DISPLAY, 19) do
		local button = _G["FriendsFrameIgnoreButton" .. i]
		if button then WSkin:Width(button, width) end
	end
	ClearPoints(_G.FriendsFrameIgnoreButton1)
	Point(_G.FriendsFrameIgnoreButton1, "TOPLEFT", frame, "TOPLEFT", left, -95)

	local status = _G.FriendsFrameStatusDropDown
	if status and status.GetTop and frame.GetTop then
		local frameTop, statusTop = frame:GetTop(), status:GetTop()
		if frameTop and statusTop then
			status:ClearAllPoints()
			Point(status, "TOPLEFT", frame, "TOPLEFT", left, -(frameTop - statusTop))
		end
	end
	if _G.FriendsFrameBroadcastInput then
		WSkin:Width(_G.FriendsFrameBroadcastInput,
			math.max(120, BodyWidth(frame) - 70 - 11))
	end

	ClearPoints(_G.FriendsFrameAddFriendButton, _G.FriendsFrameSendMessageButton,
		_G.FriendsFrameIgnorePlayerButton, _G.FriendsFrameUnsquelchButton)
	Point(_G.FriendsFrameAddFriendButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", left, 34)
	Point(_G.FriendsFrameSendMessageButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -left, 34)
	Point(_G.FriendsFrameIgnorePlayerButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", left, 34)
	Point(_G.FriendsFrameUnsquelchButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -left, 34)
end

local function LayoutWhoContent(frame)
	local geometry = WSkin.Retail.geometry
	local left = geometry.bodyInset
	local width = ScrollContentWidth(frame)
	LayoutColumns(_G.WhoFrame, { "WhoFrameColumnHeader" }, 4, left, 70, width)
	PlaceScroll(_G.WhoListScrollFrame, _G.WhoListScrollFrameScrollBar, frame,
		left, 71, width, 284)
	for i = 1, Count(_G.WHOS_TO_DISPLAY, 17) do
		local button = _G["WhoFrameButton" .. i]
		if button then WSkin:Width(button, width) end
	end
	ClearPoints(_G.WhoFrameButton1)
	Point(_G.WhoFrameButton1, "TOPLEFT", _G.WhoFrame or frame, "TOPLEFT", left, -75)
	if _G.WhoFrameEditBox then
		WSkin:Size(_G.WhoFrameEditBox, BodyWidth(frame), 18)
		ClearPoints(_G.WhoFrameEditBox)
		Point(_G.WhoFrameEditBox, "BOTTOM", _G.WhoFrame or frame, "BOTTOM", 0, 64)
	end
	if _G.WhoFrameTotals then
		WSkin:Width(_G.WhoFrameTotals, BodyWidth(frame))
		ClearPoints(_G.WhoFrameTotals)
		Point(_G.WhoFrameTotals, "TOPLEFT", _G.WhoFrame or frame, "TOPLEFT", left, -320)
	end
end

local function LayoutGuildContent(frame)
	local geometry = WSkin.Retail.geometry
	local left = geometry.bodyInset
	local width = ScrollContentWidth(frame)
	LayoutColumns(_G.GuildFrame, { "GuildFrameColumnHeader", "GuildFrameGuildStatusColumnHeader" },
		4, left, 70, width)
	PlaceScroll(_G.GuildListScrollFrame, _G.GuildListScrollFrameScrollBar, frame,
		left, 89, width, 220)
	for i = 1, Count(_G.GUILDMEMBERS_TO_DISPLAY, 14) do
		local member = _G["GuildFrameButton" .. i]
		local status = _G["GuildFrameGuildStatusButton" .. i]
		if member then WSkin:Width(member, width) end
		if status then WSkin:Width(status, width) end
	end
	ClearPoints(_G.GuildFrameButton1, _G.GuildFrameGuildStatusButton1)
	Point(_G.GuildFrameButton1, "TOPLEFT", _G.GuildFrame or frame, "TOPLEFT", left, -93)
	Point(_G.GuildFrameGuildStatusButton1, "TOPLEFT", _G.GuildFrame or frame, "TOPLEFT", left, -93)
	if _G.GuildFrameGuildListToggleButton then
		ClearPoints(_G.GuildFrameGuildListToggleButton)
		Point(_G.GuildFrameGuildListToggleButton, "TOPRIGHT", frame, "TOPRIGHT", -left, -69)
	end
	if _G.GuildFrameTotals then
		ClearPoints(_G.GuildFrameTotals)
		Point(_G.GuildFrameTotals, "TOPLEFT", frame, "TOPLEFT", left, -320)
		WSkin:Width(_G.GuildFrameTotals, BodyWidth(frame))
	end
	ClearPoints(_G.GuildFrameControlButton, _G.GuildFrameAddMemberButton,
		_G.GuildFrameGuildInformationButton)
	Point(_G.GuildFrameControlButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -left, 34)
	Point(_G.GuildFrameAddMemberButton, "RIGHT", _G.GuildFrameControlButton, "LEFT", -3, 0)
	Point(_G.GuildFrameGuildInformationButton, "RIGHT", _G.GuildFrameAddMemberButton, "LEFT", -3, 0)
end

local function LayoutChannelContent(frame)
	local geometry = WSkin.Retail.geometry
	local left = geometry.bodyInset
	local available = BodyWidth(frame) - (2 * (geometry.scrollbarWidth + 4)) - 8
	local channelList, roster = _G.ChannelListScrollFrame, _G.ChannelRosterScrollFrame
	if not channelList or not roster then return end
	local listWidth = math.max(100, channelList:GetWidth())
	local rosterWidth = math.max(80, roster:GetWidth())
	local ratio = listWidth / (listWidth + rosterWidth)
	local newListWidth = available * ratio
	local newRosterWidth = available - newListWidth
	local channelHeight = channelList:GetHeight()
	local rosterHeight = roster:GetHeight()
	local paneGap = 8
	local rightLeft = left + newListWidth + geometry.scrollbarWidth + 4 + paneGap
	PlaceScroll(channelList, _G.ChannelListScrollFrameScrollBar, frame,
		left, 92, newListWidth, channelHeight)
	PlaceScroll(roster, _G.ChannelRosterScrollFrameScrollBar, frame,
		rightLeft, 92, newRosterWidth, rosterHeight)
	for i = 1, Count(_G.MAX_DISPLAY_CHANNEL_BUTTONS, 20) do
		local button = _G["ChannelButton" .. i]
		if button then WSkin:Width(button, newListWidth) end
	end
	for i = 1, 22 do
		local button = _G["ChannelMemberButton" .. i]
		if button then WSkin:Width(button, newRosterWidth) end
	end
	if _G.ChannelFrameNewButton then
		ClearPoints(_G.ChannelFrameNewButton)
		Point(_G.ChannelFrameNewButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", left, 34)
	end
end

local function LayoutRaidContent(frame)
	local left = WSkin.Retail.geometry.bodyInset
	ClearPoints(_G.RaidFrameConvertToRaidButton, _G.RaidFrameRaidInfoButton)
	Point(_G.RaidFrameConvertToRaidButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", left, 34)
	Point(_G.RaidFrameRaidInfoButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -left, 34)
	if _G.RaidFrameNotInRaidRaidBrowserButton then
		ClearPoints(_G.RaidFrameNotInRaidRaidBrowserButton)
		Point(_G.RaidFrameNotInRaidRaidBrowserButton, "BOTTOM", frame, "BOTTOM", 0, 34)
	end
end

local function LayoutSocialContent(frame)
	LayoutFriendsContent(frame)
	LayoutWhoContent(frame)
	LayoutGuildContent(frame)
	LayoutChannelContent(frame)
	LayoutRaidContent(frame)
end

local function RefreshSocialStyle()
	local frame = _G.FriendsFrame
	if not frame then return end
	LayoutSocialContent(frame)
	WSkin:SetRetailPageTitle(frame, nil, _G.FriendsFrameTitleText)
	StyleSocialTabs()
	StyleSocialRows()
end

local function SkinSocial()
	if not WSkin:IsSkinEnabled("guild") or not _G.FriendsFrame then return end

	local frame = _G.FriendsFrame
	WSkin:StripTextures(frame, true)
	-- The native frame reserves 45px below its visible panel for the old raised
	-- tab artwork.  Our tabs are a real footer, so remove that invisible tail
	-- before building the shell and keep all of Blizzard's top-based content in
	-- exactly the same place.
	WSkin:Height(frame, 467)
	WSkin:SkinRetailWindow(frame, {
		shellOnFrame = true,
		titleRegion = _G.FriendsFrameTitleText,
		closeButton = _G.FriendsFrameCloseButton,
		hitRect = "full",
	})
	WSkin:SetUIPanelWindowInfo(frame, "width", frame:GetWidth())

	WSkin:HandleDropDownBox(_G.FriendsFrameStatusDropDown, 70)
	WSkin:HandleEditBox(_G.FriendsFrameBroadcastInput)
	StyleInput(_G.FriendsFrameStatusDropDown)
	StyleInput(_G.FriendsFrameBroadcastInput)
	StyleSocialTabs()

	Point(_G.FriendsFrameStatusDropDown, "TOPLEFT", _G.FriendsListFrame, "TOPLEFT", 0, -37)
	if _G.FriendsFrameBroadcastInput then WSkin:Width(_G.FriendsFrameBroadcastInput, 241) end
	Point(_G.FriendsFrameBroadcastInput, "TOPLEFT", _G.FriendsFrameStatusDropDown, "TOPRIGHT", 11, -3)

	for i = 1, Count(_G.FRIENDS_FRIENDS_TO_DISPLAY, 12) do
		local summon = _G["FriendsFrameFriendsScrollFrameButton" .. i .. "SummonButton"]
		local icon = _G["FriendsFrameFriendsScrollFrameButton" .. i .. "SummonButtonIcon"]
		WSkin:StyleButton(summon)
		if icon then icon:SetTexCoord(unpack(WSkin.TexCoords)) end
	end
	WSkin:HandleRetailScrollBar(_G.FriendsFrameFriendsScrollFrameScrollBar)
	WSkin:HandleRetailButton(_G.FriendsFrameAddFriendButton, true)
	WSkin:HandleRetailButton(_G.FriendsFrameSendMessageButton)
	ClearPoints(_G.FriendsFrameAddFriendButton, _G.FriendsFrameSendMessageButton)
	if _G.FriendsFrameFriendsScrollFrame then WSkin:Width(_G.FriendsFrameFriendsScrollFrame, 304) end
	Point(_G.FriendsFrameFriendsScrollFrame, "TOPLEFT", frame, "TOPLEFT", 19, -92)
	Point(_G.FriendsFrameFriendsScrollFrameScrollBar, "TOPRIGHT", frame, "TOPRIGHT", -40, -111)
	Point(_G.FriendsFrameFriendsScrollFrameScrollBar, "BOTTOMLEFT", _G.FriendsFrameFriendsScrollFrame, "BOTTOMRIGHT", 3, 19)
	Point(_G.FriendsFrameAddFriendButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", 19, 34)
	Point(_G.FriendsFrameSendMessageButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 34)

	WSkin:HandleRetailScrollBar(_G.FriendsFrameIgnoreScrollFrameScrollBar)
	WSkin:HandleRetailButton(_G.FriendsFrameIgnorePlayerButton, true)
	WSkin:HandleRetailButton(_G.FriendsFrameUnsquelchButton)
	ClearPoints(_G.FriendsFrameIgnorePlayerButton, _G.FriendsFrameUnsquelchButton)
	for i = 1, Count(_G.IGNORES_TO_DISPLAY, 19) do WSkin:HandleButtonHighlight(_G["FriendsFrameIgnoreButton" .. i]) end
	Point(_G.FriendsFrameIgnoreButton1, "TOPLEFT", frame, "TOPLEFT", 22, -95)
	if _G.FriendsFrameIgnoreScrollFrame then WSkin:Width(_G.FriendsFrameIgnoreScrollFrame, 304) end
	Point(_G.FriendsFrameIgnoreScrollFrame, "TOPRIGHT", frame, "TOPRIGHT", -61, -92)
	Point(_G.FriendsFrameIgnoreScrollFrameScrollBar, "TOPLEFT", _G.FriendsFrameIgnoreScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.FriendsFrameIgnoreScrollFrameScrollBar, "BOTTOMLEFT", _G.FriendsFrameIgnoreScrollFrame, "BOTTOMRIGHT", 3, 21)
	Point(_G.FriendsFrameIgnorePlayerButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", 19, 34)
	Point(_G.FriendsFrameUnsquelchButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 34)

	WSkin:HandleDropDownBox(_G.WhoFrameDropDown)
	WSkin:HandleEditBox(_G.WhoFrameEditBox)
	StyleInput(_G.WhoFrameEditBox)
	for i = 1, 4 do
		local header = _G["WhoFrameColumnHeader" .. i]
		WSkin:StripTextures(header)
		WSkin:ApplyRetailSurface(header, "header")
		WSkin:ApplyRetailRegionTypography(header, "secondary")
	end
	-- The Zone/Guild/Race selector lives inside column header 2. Its own
	-- dropdown box is taller than the header row and overlapped it, so draw
	-- the selector as part of the header instead of as a separate input.
	local whoDrop, whoHeader = _G.WhoFrameDropDown, _G.WhoFrameColumnHeader2
	local whoDropButton, whoDropText = _G.WhoFrameDropDownButton, _G.WhoFrameDropDownText
	if whoDrop and whoHeader then
		if whoDrop.backdrop then
			whoDrop.backdrop:ClearAllPoints()
			whoDrop.backdrop:SetAllPoints(whoHeader)
			whoDrop.backdrop:SetBackdrop(nil)
		end
		if whoDropButton then
			whoDropButton:ClearAllPoints()
			whoDropButton:SetPoint("RIGHT", whoHeader, "RIGHT", -4, 0)
		end
		if whoDropText then
			whoDropText:ClearAllPoints()
			whoDropText:SetPoint("LEFT", whoHeader, "LEFT", 8, 0)
			if whoDropButton then whoDropText:SetPoint("RIGHT", whoDropButton, "LEFT", -2, 0) end
			whoDropText:SetJustifyH("LEFT")
			WSkin:ApplyRetailTypography(whoDropText, "secondary")
		end
	end
	WSkin:ApplyRetailTypography(_G.WhoFrameTotals, "secondary")
	for i = 1, Count(_G.WHOS_TO_DISPLAY, 17) do WSkin:HandleButtonHighlight(_G["WhoFrameButton" .. i]) end
	WSkin:StripTextures(_G.WhoListScrollFrame)
	WSkin:HandleRetailScrollBar(_G.WhoListScrollFrameScrollBar)
	Each({ "WhoFrameWhoButton", "WhoFrameAddFriendButton", "WhoFrameGroupInviteButton" }, WSkin.HandleRetailButton)
	Point(_G.WhoFrameButton1, "TOPLEFT", _G.WhoFrame, "TOPLEFT", 17, -75)
	if _G.WhoListScrollFrame then WSkin:Size(_G.WhoListScrollFrame, 304, 284) end
	Point(_G.WhoListScrollFrame, "TOPRIGHT", frame, "TOPRIGHT", -61, -71)
	Point(_G.WhoListScrollFrameScrollBar, "TOPLEFT", _G.WhoListScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.WhoListScrollFrameScrollBar, "BOTTOMLEFT", _G.WhoListScrollFrame, "BOTTOMRIGHT", 3, 19)
	if _G.WhoFrameEditBox then WSkin:Size(_G.WhoFrameEditBox, 323, 18) end
	Point(_G.WhoFrameEditBox, "BOTTOM", _G.WhoFrame, "BOTTOM", -11, 64)
	ClearPoints(_G.WhoFrameWhoButton, _G.WhoFrameAddFriendButton, _G.WhoFrameGroupInviteButton)
	Point(_G.WhoFrameGroupInviteButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 34)
	Point(_G.WhoFrameAddFriendButton, "RIGHT", _G.WhoFrameGroupInviteButton, "LEFT", -3, 0)
	Point(_G.WhoFrameWhoButton, "RIGHT", _G.WhoFrameAddFriendButton, "LEFT", -3, 0)

	WSkin:HandleCheckBox(_G.GuildFrameLFGButton)
	WSkin:StripTextures(_G.GuildFrameLFGFrame)
	WSkin:ApplyRetailSurface(_G.GuildFrameLFGFrame, "card")
	WSkin:StripTextures(_G.GuildListScrollFrame)
	WSkin:HandleRetailScrollBar(_G.GuildListScrollFrameScrollBar)
	WSkin:HandleNextPrevButton(_G.GuildFrameGuildListToggleButton)
	Each({
		"GuildFrameGuildInformationButton", "GuildFrameAddMemberButton", "GuildFrameControlButton",
	}, WSkin.HandleRetailButton)
	for i = 1, Count(_G.GUILDMEMBERS_TO_DISPLAY, 14) do
		WSkin:HandleButtonHighlight(_G["GuildFrameButton" .. i])
		WSkin:HandleButtonHighlight(_G["GuildFrameGuildStatusButton" .. i])
	end
	for i = 1, 4 do
		for _, prefix in ipairs({ "GuildFrameColumnHeader", "GuildFrameGuildStatusColumnHeader" }) do
			local header = _G[prefix .. i]
			WSkin:StripTextures(header)
			WSkin:ApplyRetailSurface(header, "header")
			WSkin:ApplyRetailRegionTypography(header, "secondary")
		end
	end
	Point(_G.GuildFrameButton1, "TOPLEFT", _G.GuildFrame, "TOPLEFT", 17, -93)
	Point(_G.GuildFrameGuildStatusButton1, "TOPLEFT", _G.GuildFrame, "TOPLEFT", 17, -93)
	if _G.GuildListScrollFrame then WSkin:Size(_G.GuildListScrollFrame, 304, 220) end
	Point(_G.GuildListScrollFrame, "TOPRIGHT", _G.GuildFrame, "TOPRIGHT", -61, -89)
	Point(_G.GuildListScrollFrameScrollBar, "TOPLEFT", _G.GuildListScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.GuildListScrollFrameScrollBar, "BOTTOMLEFT", _G.GuildListScrollFrame, "BOTTOMRIGHT", 3, 19)
	Point(_G.GuildFrameGuildListToggleButton, "LEFT", _G.GuildFrame, "LEFT", 305, -69)
	-- GuildFrameTotals was anchored against the vertical centre of the native
	-- 512px frame. Re-anchor it below the compact roster so shortening the
	-- outer window cannot pull it into the final member row.
	ClearPoints(_G.GuildFrameTotals)
	Point(_G.GuildFrameTotals, "TOPLEFT", _G.GuildFrame, "TOPLEFT", 35, -320)
	ClearPoints(_G.GuildFrameGuildInformationButton, _G.GuildFrameAddMemberButton, _G.GuildFrameControlButton)
	Point(_G.GuildFrameControlButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 34)
	Point(_G.GuildFrameAddMemberButton, "RIGHT", _G.GuildFrameControlButton, "LEFT", -3, 0)
	Point(_G.GuildFrameGuildInformationButton, "RIGHT", _G.GuildFrameAddMemberButton, "LEFT", -3, 0)

	-- GuildMemberDetail is a text-only dialog whose visible native rect fills the frame.
	SkinPanel(_G.GuildMemberDetailFrame, _G.GuildMemberDetailCloseButton, 0, 0, 0, 0)
	WSkin:HandleNextPrevButton(_G.GuildFramePromoteButton)
	WSkin:HandleNextPrevButton(_G.GuildFrameDemoteButton)
	Card(_G.GuildMemberNoteBackground)
	Card(_G.GuildMemberOfficerNoteBackground)
	WSkin:HandleRetailButton(_G.GuildMemberRemoveButton)
	WSkin:HandleRetailButton(_G.GuildMemberGroupInviteButton, true)

	SkinPanel(_G.GuildInfoFrame, _G.GuildInfoCloseButton)
	Card(_G.GuildInfoTextBackground)
	WSkin:HandleRetailScrollBar(_G.GuildInfoFrameScrollFrameScrollBar)
	Each({ "GuildInfoCancelButton", "GuildInfoGuildEventButton" }, WSkin.HandleRetailButton)
	WSkin:HandleRetailButton(_G.GuildInfoSaveButton, true)

	SkinPanel(_G.GuildEventLogFrame, _G.GuildEventLogCloseButton)
	Card(_G.GuildEventFrame, "card")
	WSkin:HandleRetailScrollBar(_G.GuildEventLogScrollFrameScrollBar)
	WSkin:HandleRetailButton(_G.GuildEventLogCancelButton)

	-- This popup's 3.3.5 visible content window ends before the native form footer.
	SkinPanel(_G.GuildControlPopupFrame, nil, 4, -6, -27, 27)
	WSkin:HandleDropDownBox(_G.GuildControlPopupFrameDropDown, 185)
	StyleInput(_G.GuildControlPopupFrameDropDown)
	for _, name in ipairs({
		"GuildControlPopupFrameEditBox", "GuildControlWithdrawGoldEditBox", "GuildControlWithdrawItemsEditBox",
	}) do
		WSkin:HandleEditBox(_G[name])
		StyleInput(_G[name])
	end
	for i = 1, 17 do
		local check = _G["GuildControlPopupFrameCheckbox" .. i]
		WSkin:HandleCheckBox(check)
		if check and check.backdrop then WSkin:ApplyRetailSurface(check.backdrop, "input") end
	end
	WSkin:HandleRetailButton(_G.GuildControlPopupFrameCancelButton)
	WSkin:HandleRetailButton(_G.GuildControlPopupAcceptButton, true)

	for _, name in ipairs({ "ChannelFrameAutoJoinParty", "ChannelFrameAutoJoinBattleground" }) do
		local check = _G[name]
		WSkin:HandleCheckBox(check)
		if check and check.backdrop then WSkin:ApplyRetailSurface(check.backdrop, "input") end
	end
	WSkin:Kill(_G.ChannelFrameVerticalBar)
	for i = 1, Count(_G.MAX_DISPLAY_CHANNEL_BUTTONS, 20) do
		local button = _G["ChannelButton" .. i]
		if button then
			-- The stock group headers carry gold-bordered stone art.
			WSkin:StripTextures(button)
			if button.SetNormalTexture then button:SetNormalTexture("") end
			WSkin:HandleButtonHighlight(button, 1, 1, 1, 0.06)
		end
	end
	for i = 1, 22 do WSkin:HandleButtonHighlight(_G["ChannelMemberButton" .. i]) end
	WSkin:StripTextures(_G.ChannelListScrollFrame)
	WSkin:StripTextures(_G.ChannelRosterScrollFrame)
	WSkin:HandleRetailScrollBar(_G.ChannelListScrollFrameScrollBar)
	WSkin:HandleRetailScrollBar(_G.ChannelRosterScrollFrameScrollBar)
	WSkin:HandleRetailButton(_G.ChannelFrameNewButton, true)

	if _G.ChannelFrameDaughterFrame then
		WSkin:SkinRetailWindow(_G.ChannelFrameDaughterFrame, {
			shellOnFrame = true,
			titleRegion = _G.ChannelFrameDaughterFrameTitle,
			closeButton = _G.ChannelFrameDaughterFrameDetailCloseButton,
		})
		for _, name in ipairs({ "ChannelFrameDaughterFrameChannelName", "ChannelFrameDaughterFrameChannelPassword" }) do
			WSkin:HandleEditBox(_G[name])
			StyleInput(_G[name])
		end
		WSkin:HandleRetailButton(_G.ChannelFrameDaughterFrameCancelButton)
		WSkin:HandleRetailButton(_G.ChannelFrameDaughterFrameOkayButton, true)
	end

	-- RaidFrame and its not-in-raid controls are core FrameXML. Only the group
	-- grid comes from Blizzard_RaidUI, which loads once the player joins a
	-- raid, so these are skinned with the rest of Social.
	Each({ "RaidFrameConvertToRaidButton", "RaidFrameRaidInfoButton" }, WSkin.HandleRetailButton)
	WSkin:HandleRetailButton(_G.RaidFrameNotInRaidRaidBrowserButton, true)
	WSkin:ApplyRetailRegionTypography(_G.RaidFrame, "row")
	WSkin:ApplyRetailRegionTypography(_G.RaidFrameNotInRaid, "row")

	if _G.RaidInfoFrame then
		-- RaidInfo is a text-only dialog; its visible 3.3.5 rect fills the frame.
		SkinPanel(_G.RaidInfoFrame, _G.RaidInfoCloseButton, 0, 0, 0, 0)
		WSkin:StripTextures(_G.RaidInfoInstanceLabel)
		WSkin:StripTextures(_G.RaidInfoIDLabel)
		WSkin:ApplyRetailRegionTypography(_G.RaidInfoInstanceLabel, "secondary")
		WSkin:ApplyRetailRegionTypography(_G.RaidInfoIDLabel, "secondary")
		WSkin:HandleRetailScrollBar(_G.RaidInfoScrollFrameScrollBar)
		WSkin:HandleRetailButton(_G.RaidInfoExtendButton)
		WSkin:HandleRetailButton(_G.RaidInfoCancelButton)
		local buttons = _G.RaidInfoScrollFrame and _G.RaidInfoScrollFrame.buttons
		if buttons then
			for _, button in ipairs(buttons) do
				WSkin:HandleButtonHighlight(button, 1, 1, 1, 0.06)
			end
		end
	end

	for i = 1, 5 do
		local tab = _G["FriendsFrameTab" .. i]
		if tab then tab:HookScript("OnClick", RefreshSocialStyle) end
	end
	for i = 1, 3 do
		local tab = _G["FriendsTabHeaderTab" .. i]
		if tab then tab:HookScript("OnClick", RefreshSocialStyle) end
	end
	frame:HookScript("OnShow", RefreshSocialStyle)
	if type(_G.FriendsFrame_Update) == "function" then
		hooksecurefunc("FriendsFrame_Update", RefreshSocialStyle)
	end
	if type(_G.WhoList_Update) == "function" then
		hooksecurefunc("WhoList_Update", function()
			LayoutWhoContent(frame)
			StyleSocialRows()
		end)
	end
	if type(_G.GuildStatus_Update) == "function" then
		hooksecurefunc("GuildStatus_Update", function()
			LayoutGuildContent(frame)
			StyleSocialRows()
		end)
	end
	if type(_G.GuildRoster_Update) == "function" then
		hooksecurefunc("GuildRoster_Update", function()
			LayoutGuildContent(frame)
			StyleSocialRows()
		end)
	end
	if type(_G.ChannelList_Update) == "function" then
		hooksecurefunc("ChannelList_Update", function()
			LayoutChannelContent(frame)
			StyleChannelRows()
		end)
	end
	StyleChannelRows()
	RefreshSocialStyle()
end

WSkin:AddCallback("Skin_FriendsGuild", SkinSocial, "guild")
