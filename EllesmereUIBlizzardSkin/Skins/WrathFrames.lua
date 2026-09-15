local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local ipairs = ipairs
local unpack = unpack

local skinned = setmetatable({}, { __mode = "k" })

local function Object(name)
	return type(name) == "string" and _G[name] or name
end

local function Each(names, handler, ...)
	for _, name in ipairs(names) do
		local object = Object(name)
		if object then handler(WSkin, object, ...) end
	end
end

local function Strip(name, kill)
	local object = Object(name)
	if object then WSkin:StripTextures(object, kill) end
	return object
end

local function SkinWindow(frame, closeButton, topLeftX, topLeftY, bottomRightX, bottomRightY)
	frame = Object(frame)
	if not frame then return end
	if not skinned[frame] then
		skinned[frame] = true
		WSkin:StripTextures(frame)
		WSkin:CreateBackdrop(frame, "Transparent")
		frame.backdrop:ClearAllPoints()
		frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", topLeftX or 11, topLeftY or -12)
		frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", bottomRightX or -32, bottomRightY or 76)
		WSkin:SetUIPanelWindowInfo(frame, "width")
		WSkin:SetBackdropHitRect(frame, frame.backdrop)
		WSkin:HandleCloseButton(Object(closeButton), frame.backdrop)
	end
	return frame
end

local function SkinTabs(prefix, count)
	for i = 1, (count or 0) do
		local tab = _G[prefix .. i]
		if tab then WSkin:HandleTab(tab) end
	end
end

local function SkinHighlights(prefix, count)
	for i = 1, (count or 0) do
		local button = _G[prefix .. i]
		if button then WSkin:HandleButtonHighlight(button) end
	end
end

local function SkinItem(button, icon)
	button = Object(button)
	icon = Object(icon)
	if not button then return end
	if icon and not button.icon and not button.IconTexture and not button.iconTexture then
		if skinned[button] then return end
		skinned[button] = true
		-- HandleItemButton also resolves the standard named Icon/IconTexture
		-- globals. Non-standard buttons are handled inline below.
		local texture = icon.GetTexture and icon:GetTexture()
		WSkin:StripTextures(button)
		WSkin:SetTemplate(button, "Default")
		WSkin:StyleButton(button)
		if texture then icon:SetTexture(texture) end
		icon:SetAlpha(1)
		icon:SetTexCoord(unpack(WSkin.TexCoords))
		WSkin:SetInside(icon, button)
	else
		WSkin:HandleItemButton(button, true)
	end
end

-------------------------------------------------------------------------------
-- Mail
-------------------------------------------------------------------------------
local function SkinMail()
	if not WSkin:IsSkinEnabled("mail") or not _G.MailFrame then return end
	SkinWindow("MailFrame", "InboxCloseButton")
	Strip("InboxFrame")
	Strip("SendMailFrame")
	SkinTabs("MailFrameTab", 2)

	WSkin:HandleNextPrevButton(_G.InboxPrevPageButton, "left", nil, true)
	WSkin:HandleNextPrevButton(_G.InboxNextPageButton, "right", nil, true)
	Each({
		"SendMailMailButton", "SendMailCancelButton", "OpenMailReportSpamButton",
		"OpenMailReplyButton", "OpenMailDeleteButton", "OpenMailCancelButton",
	}, WSkin.HandleButton)
	Each({
		"SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailMoneyGold",
		"SendMailMoneySilver", "SendMailMoneyCopper",
	}, WSkin.HandleEditBox)
	Each({ "SendMailScrollFrameScrollBar", "OpenMailScrollFrameScrollBar" }, WSkin.HandleScrollBar)

	for i = 1, (_G.INBOXITEMS_TO_DISPLAY or 7) do
		local row = Strip("MailItem" .. i)
		if row and not skinned[row] then
			skinned[row] = true
			WSkin:CreateBackdrop(row, "Transparent")
		end
		SkinItem("MailItem" .. i .. "Button", "MailItem" .. i .. "ButtonIcon")
	end
	for i = 1, (_G.ATTACHMENTS_MAX_SEND or 12) do SkinItem("SendMailAttachment" .. i) end

	if _G.OpenMailFrame then
		SkinWindow("OpenMailFrame", "OpenMailCloseButton")
		Strip("OpenMailScrollFrame")
		for i = 1, (_G.ATTACHMENTS_MAX_RECEIVE or 16) do
			SkinItem("OpenMailAttachmentButton" .. i)
		end
		SkinItem("OpenMailLetterButton")
		SkinItem("OpenMailMoneyButton")
	end
end

-------------------------------------------------------------------------------
-- Dressing room
-------------------------------------------------------------------------------
local function SkinDressingRoom()
	if not WSkin:IsSkinEnabled("dressup") or not _G.DressUpFrame then return end
	SkinWindow("DressUpFrame", "DressUpFrameCloseButton")
	if _G.DressUpFramePortrait then WSkin:Kill(_G.DressUpFramePortrait) end
	Each({ "DressUpModelRotateLeftButton", "DressUpModelRotateRightButton" }, WSkin.HandleRotateButton)
	Each({ "DressUpFrameCancelButton", "DressUpFrameResetButton" }, WSkin.HandleButton)
	if _G.DressUpModel and not _G.DressUpModel.backdrop then WSkin:CreateBackdrop(_G.DressUpModel, "Default") end
end

-------------------------------------------------------------------------------
-- Macro editor
-------------------------------------------------------------------------------
local function SkinMacro()
	if not WSkin:IsSkinEnabled("macros") or not _G.MacroFrame then return end
	SkinWindow("MacroFrame", "MacroFrameCloseButton")
	Strip("MacroButtonScrollFrame")
	Strip("MacroFrameTextBackground")
	Each({ "MacroButtonScrollFrameScrollBar", "MacroFrameScrollFrameScrollBar" }, WSkin.HandleScrollBar)
	Each({ "MacroEditButton", "MacroDeleteButton", "MacroExitButton", "MacroNewButton" }, WSkin.HandleButton)
	SkinTabs("MacroFrameTab", 2)
	SkinItem("MacroFrameSelectedMacroButton", "MacroFrameSelectedMacroButtonIcon")
	for i = 1, (_G.MAX_ACCOUNT_MACROS or 36) do SkinItem("MacroButton" .. i) end

	if _G.MacroPopupFrame then
		WSkin:HandleIconSelectionFrame(_G.MacroPopupFrame, _G.NUM_MACRO_ICONS_SHOWN or 20, "MacroPopupButton", "MacroPopup")
		WSkin:HandleScrollBar(_G.MacroPopupScrollFrameScrollBar)
	end
end

-------------------------------------------------------------------------------
-- Trainers and profession crafting
-------------------------------------------------------------------------------
local function SkinTrainer()
	if not WSkin:IsSkinEnabled("trainer") or not _G.ClassTrainerFrame then return end
	SkinWindow("ClassTrainerFrame", "ClassTrainerFrameCloseButton")
	Each({
		"ClassTrainerListScrollFrame", "ClassTrainerDetailScrollFrame",
		"ClassTrainerExpandButtonFrame", "ClassTrainerDetailScrollChildFrame",
	}, WSkin.StripTextures)
	WSkin:HandleDropDownBox(_G.ClassTrainerFrameFilterDropDown)
	Each({ "ClassTrainerListScrollFrameScrollBar", "ClassTrainerDetailScrollFrameScrollBar" }, WSkin.HandleScrollBar)
	WSkin:HandleCollapseExpandButton(_G.ClassTrainerCollapseAllButton, "+", nil, nil, 1)
	for i = 1, (_G.CLASS_TRAINER_SKILLS_DISPLAYED or 11) do
		WSkin:HandleCollapseExpandButton(_G["ClassTrainerSkill" .. i], "+", nil, nil, 1)
	end
	Each({ "ClassTrainerCancelButton", "ClassTrainerTrainButton" }, WSkin.HandleButton)
	SkinItem("ClassTrainerSkillIcon")
end

local function SkinTradeSkill()
	if not (WSkin:IsSkinEnabled("professions") or WSkin:IsSkinEnabled("professionsbook"))
		or not _G.TradeSkillFrame then return end
	SkinWindow("TradeSkillFrame", "TradeSkillFrameCloseButton")
	Each({
		"TradeSkillRankFrame", "TradeSkillExpandButtonFrame", "TradeSkillListScrollFrame",
		"TradeSkillDetailScrollFrame", "TradeSkillDetailScrollChildFrame",
	}, WSkin.StripTextures)
	if _G.TradeSkillRankFrame then
		WSkin:CreateBackdrop(_G.TradeSkillRankFrame, "Default")
		_G.TradeSkillRankFrame:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
		_G.TradeSkillRankFrame:SetStatusBarColor(0.22, 0.39, 0.84)
	end
	WSkin:HandleCheckBox(_G.TradeSkillFrameAvailableFilterCheckButton)
	Each({ "TradeSkillFrameEditBox", "TradeSkillInputBox" }, WSkin.HandleEditBox)
	WSkin:HandleDropDownBox(_G.TradeSkillInvSlotDropDown, 140)
	WSkin:HandleDropDownBox(_G.TradeSkillSubClassDropDown, 140)
	WSkin:HandleCollapseExpandButton(_G.TradeSkillCollapseAllButton, "+")
	for i = 1, (_G.TRADE_SKILLS_DISPLAYED or 8) do
		WSkin:HandleCollapseExpandButton(_G["TradeSkillSkill" .. i], "+", nil, nil, 1)
	end
	Each({ "TradeSkillListScrollFrameScrollBar", "TradeSkillDetailScrollFrameScrollBar" }, WSkin.HandleScrollBar)
	SkinItem("TradeSkillSkillIcon")
	for i = 1, (_G.MAX_TRADE_SKILL_REAGENTS or 8) do SkinItem("TradeSkillReagent" .. i) end
	WSkin:HandleNextPrevButton(_G.TradeSkillDecrementButton, "left")
	WSkin:HandleNextPrevButton(_G.TradeSkillIncrementButton, "right")
	Each({ "TradeSkillCancelButton", "TradeSkillCreateButton", "TradeSkillCreateAllButton" }, WSkin.HandleButton)
end

-------------------------------------------------------------------------------
-- Auction house
-------------------------------------------------------------------------------
local function SkinAuctionHouse()
	if not WSkin:IsSkinEnabled("auctionhouse") or not _G.AuctionFrame then return end
	SkinWindow("AuctionFrame", "AuctionFrameCloseButton", 11, 0, 0, 23)
	Each({
		"BrowseSearchButton", "BrowseResetButton", "BrowseBidButton", "BrowseBuyoutButton", "BrowseCloseButton",
		"BidBidButton", "BidBuyoutButton", "BidCloseButton", "AuctionsCreateAuctionButton",
		"AuctionsCancelAuctionButton", "AuctionsStackSizeMaxButton", "AuctionsNumStacksMaxButton", "AuctionsCloseButton",
	}, WSkin.HandleButton)
	Each({ "IsUsableCheckButton", "ShowOnPlayerCheckButton" }, WSkin.HandleCheckBox)
	Each({
		"BrowseName", "BrowseMinLevel", "BrowseMaxLevel", "BrowseBidPriceGold", "BrowseBidPriceSilver",
		"BrowseBidPriceCopper", "BidBidPriceGold", "BidBidPriceSilver", "BidBidPriceCopper",
		"AuctionsStackSizeEntry", "AuctionsNumStacksEntry", "StartPriceGold", "StartPriceSilver",
		"StartPriceCopper", "BuyoutPriceGold", "BuyoutPriceSilver", "BuyoutPriceCopper",
	}, WSkin.HandleEditBox)
	WSkin:HandleDropDownBox(_G.BrowseDropDown, 155)
	WSkin:HandleDropDownBox(_G.PriceDropDown)
	WSkin:HandleDropDownBox(_G.DurationDropDown)
	Each({
		"BrowseFilterScrollFrameScrollBar", "BrowseScrollFrameScrollBar", "BidScrollFrameScrollBar",
		"AuctionsScrollFrameScrollBar",
	}, WSkin.HandleScrollBar)
	WSkin:HandleNextPrevButton(_G.BrowsePrevPageButton, "left", nil, true)
	WSkin:HandleNextPrevButton(_G.BrowseNextPageButton, "right", nil, true)
	SkinTabs("AuctionFrameTab", _G.AuctionFrame.numTabs or 3)
	SkinHighlights("AuctionFilterButton", _G.NUM_FILTERS_TO_DISPLAY or 15)
	for _, prefix in ipairs({ "Browse", "Bid", "Auctions" }) do
		local count = prefix == "Browse" and (_G.NUM_BROWSE_TO_DISPLAY or 8) or 9
		for i = 1, count do
			WSkin:HandleButtonHighlight(_G[prefix .. "Button" .. i])
			SkinItem(prefix .. "Button" .. i .. "Item")
		end
	end
	SkinItem("AuctionsItemButton")
	if _G.AuctionProgressFrame then
		WSkin:StripTextures(_G.AuctionProgressFrame)
		WSkin:SetTemplate(_G.AuctionProgressFrame, "Transparent")
		WSkin:HandleStatusBar(_G.AuctionProgressBar, { 1, 0.7, 0 })
		WSkin:HandleCloseButton(_G.AuctionProgressFrameCancelButton)
	end
end

-------------------------------------------------------------------------------
-- Friends, Who, and Guild roster
-------------------------------------------------------------------------------
local function SkinFriendsAndGuild()
	if not WSkin:IsSkinEnabled("guild") or not _G.FriendsFrame then return end
	SkinWindow("FriendsFrame", "FriendsFrameCloseButton")
	WSkin:HandleDropDownBox(_G.FriendsFrameStatusDropDown, 70)
	WSkin:HandleDropDownBox(_G.WhoFrameDropDown)
	WSkin:HandleEditBox(_G.FriendsFrameBroadcastInput)
	WSkin:HandleEditBox(_G.WhoFrameEditBox)
	SkinTabs("FriendsFrameTab", 5)
	Each({
		"FriendsFrameFriendsScrollFrameScrollBar", "FriendsFrameIgnoreScrollFrameScrollBar",
		"WhoListScrollFrameScrollBar", "GuildListScrollFrameScrollBar",
	}, WSkin.HandleScrollBar)
	Each({
		"FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton", "FriendsFrameIgnorePlayerButton",
		"FriendsFrameUnsquelchButton", "WhoFrameWhoButton", "WhoFrameAddFriendButton", "WhoFrameGroupInviteButton",
		"GuildFrameGuildInformationButton", "GuildFrameAddMemberButton", "GuildFrameControlButton",
	}, WSkin.HandleButton)
	SkinHighlights("FriendsFrameIgnoreButton", _G.IGNORES_TO_DISPLAY or 19)
	SkinHighlights("WhoFrameButton", _G.WHOS_TO_DISPLAY or 17)
	SkinHighlights("GuildFrameButton", _G.GUILDMEMBERS_TO_DISPLAY or 14)
	if _G.GuildFrameLFGButton then WSkin:HandleCheckBox(_G.GuildFrameLFGButton) end
end

-------------------------------------------------------------------------------
-- Calendar
-------------------------------------------------------------------------------
local function SkinCalendar()
	if not WSkin:IsSkinEnabled("calendar") or not _G.CalendarFrame then return end
	SkinWindow("CalendarFrame", "CalendarCloseButton", 3, -7, -2, -4)
	WSkin:HandleNextPrevButton(_G.CalendarPrevMonthButton, "left")
	WSkin:HandleNextPrevButton(_G.CalendarNextMonthButton, "right")
	WSkin:HandleNextPrevButton(_G.CalendarFilterButton, "down")
	for i = 1, 42 do
		local button = _G["CalendarDayButton" .. i]
		if button and not skinned[button] then
			skinned[button] = true
			WSkin:SetTemplate(button, "Default")
			WSkin:StyleButton(button)
		end
	end
	Each({
		"CalendarCreateEventCreateButton", "CalendarCreateEventMassInviteButton", "CalendarCreateEventInviteButton",
		"CalendarCreateEventInviteListButton", "CalendarCreateEventRemoveInviteButton", "CalendarCreateEventCloseButton",
		"CalendarViewEventAcceptButton", "CalendarViewEventTentativeButton", "CalendarViewEventRemoveButton",
		"CalendarViewEventDeclineButton", "CalendarEventPickerCloseButton",
	}, WSkin.HandleButton)
	Each({
		"CalendarCreateEventDescriptionScrollFrameScrollBar", "CalendarCreateEventInviteListScrollFrameScrollBar",
		"CalendarEventPickerScrollBar",
	}, WSkin.HandleScrollBar)
	Each({ "CalendarCreateEventTitleEdit", "CalendarCreateEventHourEdit", "CalendarCreateEventMinuteEdit" }, WSkin.HandleEditBox)
	Each({
		"CalendarCreateEventTypeDropDown", "CalendarCreateEventHourDropDown", "CalendarCreateEventMinuteDropDown",
		"CalendarCreateEventAMPMDropDown", "CalendarCreateEventRepeatOptionDropDown",
	}, WSkin.HandleDropDownBox)
end

-------------------------------------------------------------------------------
-- Blizzard options and AddOn list
-------------------------------------------------------------------------------
local function SkinSettings()
	if not WSkin:IsSkinEnabled("settings") then return end
	if _G.InterfaceOptionsFrame then
		SkinWindow("InterfaceOptionsFrame", "InterfaceOptionsFrameCloseButton", 3, -7, -3, 3)
		SkinTabs("InterfaceOptionsFrameTab", 2)
		Each({ "InterfaceOptionsFrameCategoriesListScrollBar", "InterfaceOptionsFrameAddOnsListScrollBar" }, WSkin.HandleScrollBar)
		Each({ "InterfaceOptionsFrameDefaults", "InterfaceOptionsFrameOkay", "InterfaceOptionsFrameCancel" }, WSkin.HandleButton)
	end
	if _G.VideoOptionsFrame then
		SkinWindow("VideoOptionsFrame", "VideoOptionsFrameCloseButton", 3, -7, -3, 3)
		Each({ "VideoOptionsFrameDefaults", "VideoOptionsFrameOkay", "VideoOptionsFrameCancel" }, WSkin.HandleButton)
	end
	if _G.AudioOptionsFrame then
		SkinWindow("AudioOptionsFrame", "AudioOptionsFrameCloseButton", 3, -7, -3, 3)
		Each({ "AudioOptionsFrameDefaults", "AudioOptionsFrameOkay", "AudioOptionsFrameCancel" }, WSkin.HandleButton)
	end
end

local function SkinAddonList()
	if not WSkin:IsSkinEnabled("addonlist") or not _G.AddonList then return end
	SkinWindow("AddonList", "AddonListCloseButton", 8, -12, -8, 8)
	WSkin:HandleScrollBar(_G.AddonListScrollFrameScrollBar)
	WSkin:HandleDropDownBox(_G.AddonCharacterDropDown)
	Each({ "AddonListEnableAllButton", "AddonListDisableAllButton", "AddonListOkayButton", "AddonListCancelButton" }, WSkin.HandleButton)
	for i = 1, (_G.MAX_ADDONS_DISPLAYED or 19) do WSkin:HandleCheckBox(_G["AddonListEntry" .. i .. "Enabled"]) end
end

-------------------------------------------------------------------------------
-- Smaller Wrath windows which share the same ElvUI-style frame treatment
-------------------------------------------------------------------------------
local function SkinTrade()
	if not WSkin:IsSkinEnabled("misc") or not _G.TradeFrame then return end
	SkinWindow("TradeFrame", "TradeFrameCloseButton", 11, -12, -21, 49)
	Each({
		"TradePlayerInputMoneyFrameGold", "TradePlayerInputMoneyFrameSilver", "TradePlayerInputMoneyFrameCopper",
	}, WSkin.HandleEditBox)
	Each({ "TradeFrameTradeButton", "TradeFrameCancelButton" }, WSkin.HandleButton)
	for i = 1, (_G.MAX_TRADE_ITEMS or 7) do
		Strip("TradePlayerItem" .. i)
		Strip("TradeRecipientItem" .. i)
		SkinItem("TradePlayerItem" .. i .. "ItemButton")
		SkinItem("TradeRecipientItem" .. i .. "ItemButton")
	end
end

local function SkinStable()
	if not WSkin:IsSkinEnabled("collections") or not _G.PetStableFrame then return end
	SkinWindow("PetStableFrame", "PetStableFrameCloseButton")
	Each({ "PetStableModelRotateLeftButton", "PetStableModelRotateRightButton" }, WSkin.HandleRotateButton)
	Each({ "PetStablePurchaseButton", "PetStableFramePetInfoCloseButton" }, WSkin.HandleButton)
	SkinItem("PetStableCurrentPet")
	for i = 1, (_G.NUM_PET_STABLE_SLOTS or 4) do SkinItem("PetStableStabledPet" .. i) end
	if _G.PetStableModel and not _G.PetStableModel.backdrop then WSkin:CreateBackdrop(_G.PetStableModel, "Default") end
end

local function SkinTaxi()
	if not WSkin:IsSkinEnabled("worldmap") or not _G.TaxiFrame then return end
	SkinWindow("TaxiFrame", "TaxiCloseButton", 11, -12, -32, 76)
	if _G.TaxiPortrait then WSkin:Kill(_G.TaxiPortrait) end
	if _G.TaxiRouteMap and not _G.TaxiRouteMap.backdrop then WSkin:CreateBackdrop(_G.TaxiRouteMap, "Default") end
end

local function SkinHelp()
	if not WSkin:IsSkinEnabled("misc") or not _G.HelpFrame then return end
	SkinWindow("HelpFrame", "HelpFrameCloseButton", 6, 0, -45, 14)
	Each({
		"HelpFrameGMTalkOpenTicket", "HelpFrameGMTalkCancel",
		"HelpFrameReportIssueOpenTicket", "HelpFrameReportIssueCancel",
		"HelpFrameLagLoot", "HelpFrameLagAuctionHouse", "HelpFrameLagMail", "HelpFrameLagChat",
		"HelpFrameLagMovement", "HelpFrameLagSpell", "HelpFrameLagCancel",
		"HelpFrameStuckStuck", "HelpFrameStuckOpenTicket", "HelpFrameStuckCancel",
		"HelpFrameOpenTicketCancel", "HelpFrameOpenTicketSubmit",
		"HelpFrameViewResponseCancel", "HelpFrameViewResponseMoreHelp", "HelpFrameViewResponseIssueResolved",
		"HelpFrameWelcomeGMTalk", "HelpFrameWelcomeReportIssue", "HelpFrameWelcomeStuck", "HelpFrameWelcomeCancel",
	}, WSkin.HandleButton)
	Each({
		"HelpFrameOpenTicketScrollFrameScrollBar", "HelpFrameViewResponseIssueScrollFrameScrollBar",
		"HelpFrameViewResponseMessageScrollFrameScrollBar",
	}, WSkin.HandleScrollBar)
	Each({
		"KnowledgeBaseFrameDivider", "KnowledgeBaseFrameDivider2",
		"HelpFrameOpenTicketDivider", "HelpFrameViewResponseDivider",
	}, WSkin.StripTextures)
end

local function SkinPvP()
	if not WSkin:IsSkinEnabled("misc") then return end
	if _G.PVPParentFrame then
		SkinWindow("PVPParentFrame", "PVPParentFrameCloseButton")
		SkinTabs("PVPParentFrameTab", 2)
		Strip("PVPFrame")
		Strip("PVPBattlegroundFrame")
		Each({
			"PVPTeamDetailsAddTeamMember", "PVPBattlegroundFrameGroupJoinButton",
			"PVPBattlegroundFrameJoinButton", "PVPBattlegroundFrameCancelButton",
		}, WSkin.HandleButton)
		Each({
			"PVPBattlegroundFrameTypeScrollFrameScrollBar", "PVPBattlegroundFrameInfoScrollFrameScrollBar",
		}, WSkin.HandleScrollBar)
		SkinHighlights("BattlegroundType", 5)
	end
end

local function SkinRaid()
	if not WSkin:IsSkinEnabled("misc") then return end
	if _G.RaidFrame then
		for i = 1, 8 do Strip("RaidGroup" .. i) end
		Each({ "RaidFrameRaidBrowserButton", "RaidFrameReadyCheckButton", "RaidFrameRaidInfoButton" }, WSkin.HandleButton)
		for i = 1, (_G.MAX_RAID_MEMBERS or 40) do WSkin:HandleButton(_G["RaidGroupButton" .. i], true) end
	end
end

local function SkinGuildUtilityWindows()
	if not WSkin:IsSkinEnabled("guild") then return end
	if _G.GuildRegistrarFrame then
		SkinWindow("GuildRegistrarFrame", "GuildRegistrarFrameCloseButton")
		Each({ "GuildRegistrarFramePurchaseButton", "GuildRegistrarFrameCancelButton" }, WSkin.HandleButton)
	end
	if _G.PetitionFrame then
		SkinWindow("PetitionFrame", "PetitionFrameCloseButton")
		Each({ "PetitionFrameSignButton", "PetitionFrameRequestButton", "PetitionFrameRenameButton", "PetitionFrameCancelButton" }, WSkin.HandleButton)
	end
	if _G.TabardFrame then
		SkinWindow("TabardFrame", "TabardFrameCloseButton")
		if _G.TabardFramePortrait then WSkin:Kill(_G.TabardFramePortrait) end
		Each({ "TabardFrameAcceptButton", "TabardFrameCancelButton" }, WSkin.HandleButton)
		Each({ "TabardCharacterModelRotateLeftButton", "TabardCharacterModelRotateRightButton" }, WSkin.HandleRotateButton)
		for i = 1, 5 do
			Strip("TabardFrameCustomization" .. i)
			WSkin:HandleNextPrevButton(_G["TabardFrameCustomization" .. i .. "LeftButton"], "left")
			WSkin:HandleNextPrevButton(_G["TabardFrameCustomization" .. i .. "RightButton"], "right")
		end
	end
end

WSkin:AddCallback("Skin_DressingRoom", SkinDressingRoom, "dressup")
WSkin:AddCallback("Skin_Settings", SkinSettings, "settings")
WSkin:AddCallback("Skin_AddonList", SkinAddonList, "addonlist")
WSkin:AddCallback("Skin_Trade", SkinTrade, "misc")
WSkin:AddCallback("Skin_Stable", SkinStable, "collections")
WSkin:AddCallback("Skin_Taxi", SkinTaxi, "worldmap")
WSkin:AddCallback("Skin_Help", SkinHelp, "misc")
WSkin:AddCallback("Skin_GuildUtility", SkinGuildUtilityWindows, "guild")

WSkin:AddCallbackForAddon("Blizzard_MacroUI", "Skin_Macro", SkinMacro, "macros")
WSkin:AddCallbackForAddon("Blizzard_TrainerUI", "Skin_Trainer", SkinTrainer, "trainer")
WSkin:AddCallbackForAddon("Blizzard_TradeSkillUI", "Skin_TradeSkill", SkinTradeSkill, "misc")
WSkin:AddCallbackForAddon("Blizzard_Calendar", "Skin_Calendar", SkinCalendar, "calendar")
WSkin:AddCallbackForAddon("Blizzard_RaidUI", "Skin_Raid", SkinRaid, "misc")
