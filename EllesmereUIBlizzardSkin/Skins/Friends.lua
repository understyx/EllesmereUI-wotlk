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

local function Each(names, handler, ...)
	for _, name in ipairs(names) do
		local object = type(name) == "string" and _G[name] or name
		if object then handler(WSkin, object, ...) end
	end
end

local function SkinPanel(frame, closeButton, left, top, right, bottom)
	if not frame then return end
	WSkin:StripTextures(frame, true)
	WSkin:CreateBackdrop(frame, "Transparent")
	if not frame.backdrop then return end
	frame.backdrop:ClearAllPoints()
	Point(frame.backdrop, "TOPLEFT", frame, "TOPLEFT", left or 4, top or -6)
	Point(frame.backdrop, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", right or -2, bottom or 0)
	WSkin:SetBackdropHitRect(frame)
	WSkin:HandleCloseButton(closeButton, frame.backdrop)
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
	if #mainTabs > 0 then
		local width = frame:GetWidth() / #mainTabs
		for i, tab in ipairs(mainTabs) do
			tab:ClearAllPoints()
			tab:SetSize(width, WSkin.Retail.geometry.tabHeight)
			if i == 1 then
				tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
			else
				tab:SetPoint("LEFT", mainTabs[i - 1], "RIGHT", 0, 0)
			end
			WSkin:UpdateRetailTab(tab, tab:GetID() == selected)
		end
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
		local width = (frame:GetWidth() - 28) / #headerTabs
		for i, tab in ipairs(headerTabs) do
			tab:ClearAllPoints()
			tab:SetSize(width, WSkin.Retail.geometry.tabHeight)
			if i == 1 then
				tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -60)
			else
				tab:SetPoint("LEFT", headerTabs[i - 1], "RIGHT", 0, 0)
			end
			WSkin:UpdateRetailTab(tab, tab:GetID() == headerSelected)
		end
	end
end

local function RefreshSocialStyle()
	local frame = _G.FriendsFrame
	if not frame then return end
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
	WSkin:CreateRetailWindowShell(
		frame,
		nil,
		_G.FriendsFrameTitleText,
		_G.FriendsFrameCloseButton,
		{ content = false }
	)
	frame:SetHitRectInsets(0, 0, 0, 0)
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
	WSkin:SetBackdropHitRect(_G.WhoFrameDropDown)
	WSkin:HandleEditBox(_G.WhoFrameEditBox)
	StyleInput(_G.WhoFrameDropDown)
	StyleInput(_G.WhoFrameEditBox)
	for i = 1, 4 do
		local header = _G["WhoFrameColumnHeader" .. i]
		WSkin:StripTextures(header)
		WSkin:ApplyRetailSurface(header, "header")
		WSkin:ApplyRetailRegionTypography(header, "secondary")
	end
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

	SkinPanel(_G.GuildMemberDetailFrame, _G.GuildMemberDetailCloseButton, 0, 0, 0, 0)
	WSkin:HandleNextPrevButton(_G.GuildFramePromoteButton)
	WSkin:HandleNextPrevButton(_G.GuildFrameDemoteButton)
	WSkin:SetTemplate(_G.GuildMemberNoteBackground, "Default")
	WSkin:SetTemplate(_G.GuildMemberOfficerNoteBackground, "Default")
	WSkin:HandleButton(_G.GuildMemberRemoveButton)
	WSkin:HandleButton(_G.GuildMemberGroupInviteButton)

	SkinPanel(_G.GuildInfoFrame, _G.GuildInfoCloseButton)
	WSkin:SetTemplate(_G.GuildInfoTextBackground, "Default")
	WSkin:HandleScrollBar(_G.GuildInfoFrameScrollFrameScrollBar)
	Each({ "GuildInfoSaveButton", "GuildInfoCancelButton", "GuildInfoGuildEventButton" }, WSkin.HandleButton)

	SkinPanel(_G.GuildEventLogFrame, _G.GuildEventLogCloseButton)
	WSkin:SetTemplate(_G.GuildEventFrame, "Default")
	WSkin:HandleScrollBar(_G.GuildEventLogScrollFrameScrollBar)
	WSkin:HandleButton(_G.GuildEventLogCancelButton)

	SkinPanel(_G.GuildControlPopupFrame, nil, 4, -6, -27, 27)
	WSkin:HandleDropDownBox(_G.GuildControlPopupFrameDropDown, 185)
	WSkin:HandleEditBox(_G.GuildControlPopupFrameEditBox)
	WSkin:HandleEditBox(_G.GuildControlWithdrawGoldEditBox)
	WSkin:HandleEditBox(_G.GuildControlWithdrawItemsEditBox)
	for i = 1, 17 do WSkin:HandleCheckBox(_G["GuildControlPopupFrameCheckbox" .. i]) end
	Each({ "GuildControlPopupAcceptButton", "GuildControlPopupFrameCancelButton" }, WSkin.HandleButton)

	WSkin:HandleCheckBox(_G.ChannelFrameAutoJoinParty)
	WSkin:HandleCheckBox(_G.ChannelFrameAutoJoinBattleground)
	for i = 1, Count(_G.MAX_DISPLAY_CHANNEL_BUTTONS, 20) do WSkin:HandleButtonHighlight(_G["ChannelButton" .. i]) end
	for i = 1, 22 do WSkin:HandleButtonHighlight(_G["ChannelMemberButton" .. i]) end
	WSkin:StripTextures(_G.ChannelListScrollFrame)
	WSkin:StripTextures(_G.ChannelRosterScrollFrame)
	WSkin:HandleRetailScrollBar(_G.ChannelListScrollFrameScrollBar)
	WSkin:HandleRetailScrollBar(_G.ChannelRosterScrollFrameScrollBar)
	WSkin:HandleRetailButton(_G.ChannelFrameNewButton, true)

	if _G.ChannelFrameDaughterFrame then
		WSkin:StripTextures(_G.ChannelFrameDaughterFrame)
		WSkin:SetTemplate(_G.ChannelFrameDaughterFrame, "Transparent")
		WSkin:HandleCloseButton(_G.ChannelFrameDaughterFrameDetailCloseButton, _G.ChannelFrameDaughterFrame)
		WSkin:HandleEditBox(_G.ChannelFrameDaughterFrameChannelName)
		WSkin:HandleEditBox(_G.ChannelFrameDaughterFrameChannelPassword)
		WSkin:HandleButton(_G.ChannelFrameDaughterFrameOkayButton)
		WSkin:HandleButton(_G.ChannelFrameDaughterFrameCancelButton)
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
		hooksecurefunc("WhoList_Update", StyleSocialRows)
	end
	if type(_G.GuildStatus_Update) == "function" then
		hooksecurefunc("GuildStatus_Update", StyleSocialRows)
	end
	if type(_G.GuildRoster_Update) == "function" then
		hooksecurefunc("GuildRoster_Update", StyleSocialRows)
	end
	RefreshSocialStyle()
end

WSkin:AddCallback("Skin_FriendsGuild", SkinSocial, "guild")
