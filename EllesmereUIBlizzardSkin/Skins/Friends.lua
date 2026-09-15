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

local function SkinSocial()
	if not WSkin:IsSkinEnabled("guild") or not _G.FriendsFrame then return end

	local frame = _G.FriendsFrame
	WSkin:StripTextures(frame, true)
	WSkin:CreateBackdrop(frame, "Transparent")
	if not frame.backdrop then return end
	frame.backdrop:ClearAllPoints()
	Point(frame.backdrop, "TOPLEFT", frame, "TOPLEFT", 11, -12)
	Point(frame.backdrop, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 76)
	WSkin:SetUIPanelWindowInfo(frame, "width")
	WSkin:SetBackdropHitRect(frame)
	WSkin:HandleCloseButton(_G.FriendsFrameCloseButton, frame.backdrop)

	WSkin:HandleDropDownBox(_G.FriendsFrameStatusDropDown, 70)
	WSkin:HandleEditBox(_G.FriendsFrameBroadcastInput)
	for i = 1, 2 do
		local tab = _G["FriendsTabHeaderTab" .. i]
		if tab then
			WSkin:StripTextures(tab)
			WSkin:CreateBackdrop(tab, "Default")
			if tab.backdrop then
				tab.backdrop:ClearAllPoints()
				Point(tab.backdrop, "TOPLEFT", tab, "TOPLEFT", 3, -7)
				Point(tab.backdrop, "BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, -1)
			end
			tab:HookScript("OnEnter", WSkin.SetModifiedBackdrop)
			tab:HookScript("OnLeave", WSkin.SetOriginalBackdrop)
		end
	end
	for i = 1, 5 do WSkin:HandleTab(_G["FriendsFrameTab" .. i]) end
	for i = 1, 5 do ClearPoints(_G["FriendsFrameTab" .. i]) end
	Point(_G.FriendsFrameTab1, "BOTTOMLEFT", frame, "BOTTOMLEFT", 11, 46)
	for i = 2, 5 do Point(_G["FriendsFrameTab" .. i], "LEFT", _G["FriendsFrameTab" .. (i - 1)], "RIGHT", -15, 0) end

	ClearPoints(_G.FriendsTabHeaderTab1, _G.FriendsTabHeaderTab2)
	Point(_G.FriendsFrameStatusDropDown, "TOPLEFT", _G.FriendsListFrame, "TOPLEFT", 0, -37)
	if _G.FriendsFrameBroadcastInput then WSkin:Width(_G.FriendsFrameBroadcastInput, 241) end
	Point(_G.FriendsFrameBroadcastInput, "TOPLEFT", _G.FriendsFrameStatusDropDown, "TOPRIGHT", 11, -3)
	Point(_G.FriendsTabHeaderTab1, "TOPLEFT", frame, "TOPLEFT", 30, -60)
	Point(_G.FriendsTabHeaderTab2, "LEFT", _G.FriendsTabHeaderTab1, "RIGHT", 1, 0)

	for i = 1, Count(_G.FRIENDS_FRIENDS_TO_DISPLAY, 12) do
		local summon = _G["FriendsFrameFriendsScrollFrameButton" .. i .. "SummonButton"]
		local icon = _G["FriendsFrameFriendsScrollFrameButton" .. i .. "SummonButtonIcon"]
		WSkin:StyleButton(summon)
		if icon then icon:SetTexCoord(unpack(WSkin.TexCoords)) end
	end
	WSkin:HandleScrollBar(_G.FriendsFrameFriendsScrollFrameScrollBar)
	WSkin:HandleButton(_G.FriendsFrameAddFriendButton, true)
	WSkin:HandleButton(_G.FriendsFrameSendMessageButton, true)
	ClearPoints(_G.FriendsFrameAddFriendButton, _G.FriendsFrameSendMessageButton)
	if _G.FriendsFrameFriendsScrollFrame then WSkin:Width(_G.FriendsFrameFriendsScrollFrame, 304) end
	Point(_G.FriendsFrameFriendsScrollFrame, "TOPLEFT", frame, "TOPLEFT", 19, -92)
	Point(_G.FriendsFrameFriendsScrollFrameScrollBar, "TOPRIGHT", frame, "TOPRIGHT", -40, -111)
	Point(_G.FriendsFrameFriendsScrollFrameScrollBar, "BOTTOMLEFT", _G.FriendsFrameFriendsScrollFrame, "BOTTOMRIGHT", 3, 19)
	Point(_G.FriendsFrameAddFriendButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", 19, 84)
	Point(_G.FriendsFrameSendMessageButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 84)

	WSkin:HandleScrollBar(_G.FriendsFrameIgnoreScrollFrameScrollBar)
	WSkin:HandleButton(_G.FriendsFrameIgnorePlayerButton, true)
	WSkin:HandleButton(_G.FriendsFrameUnsquelchButton, true)
	ClearPoints(_G.FriendsFrameIgnorePlayerButton, _G.FriendsFrameUnsquelchButton)
	for i = 1, Count(_G.IGNORES_TO_DISPLAY, 19) do WSkin:HandleButtonHighlight(_G["FriendsFrameIgnoreButton" .. i]) end
	Point(_G.FriendsFrameIgnoreButton1, "TOPLEFT", frame, "TOPLEFT", 22, -95)
	if _G.FriendsFrameIgnoreScrollFrame then WSkin:Width(_G.FriendsFrameIgnoreScrollFrame, 304) end
	Point(_G.FriendsFrameIgnoreScrollFrame, "TOPRIGHT", frame, "TOPRIGHT", -61, -92)
	Point(_G.FriendsFrameIgnoreScrollFrameScrollBar, "TOPLEFT", _G.FriendsFrameIgnoreScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.FriendsFrameIgnoreScrollFrameScrollBar, "BOTTOMLEFT", _G.FriendsFrameIgnoreScrollFrame, "BOTTOMRIGHT", 3, 21)
	Point(_G.FriendsFrameIgnorePlayerButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", 19, 84)
	Point(_G.FriendsFrameUnsquelchButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 84)

	WSkin:HandleDropDownBox(_G.WhoFrameDropDown)
	WSkin:SetBackdropHitRect(_G.WhoFrameDropDown)
	WSkin:HandleEditBox(_G.WhoFrameEditBox)
	for i = 1, 4 do
		local header = _G["WhoFrameColumnHeader" .. i]
		WSkin:StripTextures(header)
		WSkin:SetTemplate(header, "Default")
		WSkin:StyleButton(header)
	end
	for i = 1, Count(_G.WHOS_TO_DISPLAY, 17) do WSkin:HandleButtonHighlight(_G["WhoFrameButton" .. i]) end
	WSkin:StripTextures(_G.WhoListScrollFrame)
	WSkin:HandleScrollBar(_G.WhoListScrollFrameScrollBar)
	Each({ "WhoFrameWhoButton", "WhoFrameAddFriendButton", "WhoFrameGroupInviteButton" }, WSkin.HandleButton)
	Point(_G.WhoFrameButton1, "TOPLEFT", _G.WhoFrame, "TOPLEFT", 17, -75)
	if _G.WhoListScrollFrame then WSkin:Size(_G.WhoListScrollFrame, 304, 284) end
	Point(_G.WhoListScrollFrame, "TOPRIGHT", frame, "TOPRIGHT", -61, -71)
	Point(_G.WhoListScrollFrameScrollBar, "TOPLEFT", _G.WhoListScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.WhoListScrollFrameScrollBar, "BOTTOMLEFT", _G.WhoListScrollFrame, "BOTTOMRIGHT", 3, 19)
	if _G.WhoFrameEditBox then WSkin:Size(_G.WhoFrameEditBox, 323, 18) end
	Point(_G.WhoFrameEditBox, "BOTTOM", _G.WhoFrame, "BOTTOM", -11, 114)
	ClearPoints(_G.WhoFrameWhoButton, _G.WhoFrameAddFriendButton, _G.WhoFrameGroupInviteButton)
	Point(_G.WhoFrameGroupInviteButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 84)
	Point(_G.WhoFrameAddFriendButton, "RIGHT", _G.WhoFrameGroupInviteButton, "LEFT", -3, 0)
	Point(_G.WhoFrameWhoButton, "RIGHT", _G.WhoFrameAddFriendButton, "LEFT", -3, 0)

	WSkin:HandleCheckBox(_G.GuildFrameLFGButton)
	WSkin:StripTextures(_G.GuildFrameLFGFrame)
	WSkin:SetTemplate(_G.GuildFrameLFGFrame, "Default")
	WSkin:StripTextures(_G.GuildListScrollFrame)
	WSkin:HandleScrollBar(_G.GuildListScrollFrameScrollBar)
	WSkin:HandleNextPrevButton(_G.GuildFrameGuildListToggleButton)
	Each({
		"GuildFrameGuildInformationButton", "GuildFrameAddMemberButton", "GuildFrameControlButton",
	}, WSkin.HandleButton)
	for i = 1, Count(_G.GUILDMEMBERS_TO_DISPLAY, 14) do
		WSkin:HandleButtonHighlight(_G["GuildFrameButton" .. i])
		WSkin:HandleButtonHighlight(_G["GuildFrameGuildStatusButton" .. i])
	end
	for i = 1, 4 do
		for _, prefix in ipairs({ "GuildFrameColumnHeader", "GuildFrameGuildStatusColumnHeader" }) do
			local header = _G[prefix .. i]
			WSkin:StripTextures(header)
			WSkin:SetTemplate(header, "Default")
			WSkin:StyleButton(header)
		end
	end
	Point(_G.GuildFrameButton1, "TOPLEFT", _G.GuildFrame, "TOPLEFT", 17, -93)
	Point(_G.GuildFrameGuildStatusButton1, "TOPLEFT", _G.GuildFrame, "TOPLEFT", 17, -93)
	if _G.GuildListScrollFrame then WSkin:Size(_G.GuildListScrollFrame, 304, 220) end
	Point(_G.GuildListScrollFrame, "TOPRIGHT", _G.GuildFrame, "TOPRIGHT", -61, -89)
	Point(_G.GuildListScrollFrameScrollBar, "TOPLEFT", _G.GuildListScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.GuildListScrollFrameScrollBar, "BOTTOMLEFT", _G.GuildListScrollFrame, "BOTTOMRIGHT", 3, 19)
	Point(_G.GuildFrameGuildListToggleButton, "LEFT", _G.GuildFrame, "LEFT", 305, -69)
	ClearPoints(_G.GuildFrameGuildInformationButton, _G.GuildFrameAddMemberButton, _G.GuildFrameControlButton)
	Point(_G.GuildFrameControlButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 84)
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
	WSkin:HandleScrollBar(_G.ChannelListScrollFrameScrollBar)
	WSkin:HandleScrollBar(_G.ChannelRosterScrollFrameScrollBar)
	WSkin:HandleButton(_G.ChannelFrameNewButton)

	if _G.ChannelFrameDaughterFrame then
		WSkin:StripTextures(_G.ChannelFrameDaughterFrame)
		WSkin:SetTemplate(_G.ChannelFrameDaughterFrame, "Transparent")
		WSkin:HandleCloseButton(_G.ChannelFrameDaughterFrameDetailCloseButton, _G.ChannelFrameDaughterFrame)
		WSkin:HandleEditBox(_G.ChannelFrameDaughterFrameChannelName)
		WSkin:HandleEditBox(_G.ChannelFrameDaughterFrameChannelPassword)
		WSkin:HandleButton(_G.ChannelFrameDaughterFrameOkayButton)
		WSkin:HandleButton(_G.ChannelFrameDaughterFrameCancelButton)
	end
end

WSkin:AddCallback("Skin_FriendsGuild", SkinSocial, "guild")
