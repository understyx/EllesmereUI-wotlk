local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local ipairs = ipairs
local unpack = unpack

local skinned = setmetatable({}, { __mode = "k" })

local function Object(name)
	local object = type(name) == "string" and _G[name] or name
	local objectType = type(object)
	-- Some names resolve to strings or are absent on the 3.3.5 client.
	if objectType ~= "table" and objectType ~= "userdata" then return nil end
	return object
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
		-- These windows keep Blizzard's layout, which is anchored against the
		-- old artwork rect; the shared shell lives on that visible backdrop.
		WSkin:CreateRetailWindowShell(frame.backdrop, nil, nil, Object(closeButton), { content = false })
		local frameName = frame.GetName and frame:GetName()
		local title = frameName and (_G[frameName .. "TitleText"] or _G[frameName .. "HeaderText"])
		if title then WSkin:SetRetailPageTitle(frame.backdrop, nil, title) end
		WSkin:SetUIPanelWindowInfo(frame, "width")
		WSkin:SetBackdropHitRect(frame, frame.backdrop)
	end
	return frame
end

-- Tab owners whose retail tab state follows PanelTemplates_SetTab. Tabs stay
-- at Blizzard's anchors (several of these windows keep them along the top).
local tabOwners = {}
local function UpdateOwnerTabs(owner)
	local tabs = tabOwners[owner]
	if not tabs then return end
	local selected = type(_G.PanelTemplates_GetSelectedTab) == "function"
		and _G.PanelTemplates_GetSelectedTab(owner) or owner.selectedTab or 1
	for i, tab in ipairs(tabs) do WSkin:UpdateRetailTab(tab, i == selected) end
end

local function SkinTabs(prefix, count, owner)
	owner = Object(owner)
	local tabs = {}
	for i = 1, (count or 0) do
		local tab = _G[prefix .. i]
		if tab then
			WSkin:StyleRetailTab(tab)
			tab:SetHeight(WSkin.Retail.geometry.tabHeight)
			tab:SetHitRectInsets(0, 0, 0, 0)
			tabs[#tabs + 1] = tab
		end
	end
	if not owner then return end
	if not next(tabOwners) and hooksecurefunc then
		hooksecurefunc("PanelTemplates_SetTab", UpdateOwnerTabs)
	end
	tabOwners[owner] = tabs
	if owner.HookScript then owner:HookScript("OnShow", UpdateOwnerTabs) end
	UpdateOwnerTabs(owner)
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
		WSkin:ApplyRetailSurface(button, "input")
		WSkin:StyleButton(button)
		if texture then icon:SetTexture(texture) end
		icon:SetAlpha(1)
		icon:SetTexCoord(unpack(WSkin.TexCoords))
		WSkin:SetInside(icon, button)
	else
		WSkin:HandleItemButton(button, true)
		if button.backdrop then WSkin:ApplyRetailSurface(button.backdrop, "input") end
	end
end

local function Buttons(names, primary)
	Each(names, WSkin.HandleRetailButton, primary)
end

local function ScrollBars(names)
	Each(names, WSkin.HandleRetailScrollBar)
end

local function StyleInput(frame)
	if frame and frame.backdrop then WSkin:ApplyRetailSurface(frame.backdrop, "input") end
end

local function EditBoxes(names)
	for _, name in ipairs(names) do
		local box = Object(name)
		if box then
			WSkin:HandleEditBox(box)
			StyleInput(box)
		end
	end
end

local function DropDown(name, width)
	local frame = Object(name)
	if not frame then return end
	WSkin:HandleDropDownBox(frame, width)
	StyleInput(frame)
end

local function CheckBox(name)
	local frame = Object(name)
	if not frame then return end
	WSkin:HandleCheckBox(frame)
	StyleInput(frame)
end

local function Card(frame)
	frame = Object(frame)
	if not frame then return end
	if not frame.backdrop then WSkin:CreateBackdrop(frame, "Default") end
	if frame.backdrop then WSkin:ApplyRetailSurface(frame.backdrop, "card") end
end

-------------------------------------------------------------------------------
-- Dressing room
-------------------------------------------------------------------------------
local function SkinDressingRoom()
	if not WSkin:IsSkinEnabled("dressup") or not _G.DressUpFrame then return end
	SkinWindow("DressUpFrame", "DressUpFrameCloseButton")
	if _G.DressUpFramePortrait then WSkin:Kill(_G.DressUpFramePortrait) end
	Each({ "DressUpModelRotateLeftButton", "DressUpModelRotateRightButton" }, WSkin.HandleRotateButton)
	Buttons({ "DressUpFrameCancelButton", "DressUpFrameResetButton" })
	Card("DressUpModel")
end

-------------------------------------------------------------------------------
-- Macro editor
-------------------------------------------------------------------------------
local function SkinMacro()
	if not WSkin:IsSkinEnabled("macros") or not _G.MacroFrame then return end
	SkinWindow("MacroFrame", "MacroFrameCloseButton")
	Strip("MacroButtonScrollFrame")
	Strip("MacroFrameTextBackground")
	Card("MacroFrameTextBackground")
	ScrollBars({ "MacroButtonScrollFrameScrollBar", "MacroFrameScrollFrameScrollBar" })
	Buttons({ "MacroEditButton", "MacroDeleteButton", "MacroExitButton" })
	Buttons({ "MacroNewButton" }, true)
	SkinTabs("MacroFrameTab", 2, "MacroFrame")
	SkinItem("MacroFrameSelectedMacroButton", "MacroFrameSelectedMacroButtonIcon")
	for i = 1, (_G.MAX_ACCOUNT_MACROS or 36) do SkinItem("MacroButton" .. i) end

	if _G.MacroPopupFrame then
		WSkin:HandleIconSelectionFrame(_G.MacroPopupFrame, _G.NUM_MACRO_ICONS_SHOWN or 20, "MacroPopupButton", "MacroPopup")
		if _G.MacroPopupFrame.backdrop then
			WSkin:CreateRetailWindowShell(_G.MacroPopupFrame.backdrop, nil, nil, nil, { content = false })
		end
		Buttons({ "MacroPopupOkayButton", "MacroPopupCancelButton" })
		StyleInput(_G.MacroPopupEditBox)
		for i = 1, (_G.NUM_MACRO_ICONS_SHOWN or 20) do
			local button = _G["MacroPopupButton" .. i]
			if button then WSkin:ApplyRetailSurface(button, "input") end
		end
		WSkin:HandleRetailScrollBar(_G.MacroPopupScrollFrameScrollBar)
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
	DropDown("ClassTrainerFrameFilterDropDown")
	ScrollBars({ "ClassTrainerListScrollFrameScrollBar", "ClassTrainerDetailScrollFrameScrollBar" })
	WSkin:HandleCollapseExpandButton(_G.ClassTrainerCollapseAllButton, "+", nil, nil, 1)
	for i = 1, (_G.CLASS_TRAINER_SKILLS_DISPLAYED or 11) do
		WSkin:HandleCollapseExpandButton(_G["ClassTrainerSkill" .. i], "+", nil, nil, 1)
	end
	Buttons({ "ClassTrainerCancelButton" })
	Buttons({ "ClassTrainerTrainButton" }, true)
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
		StyleInput(_G.TradeSkillRankFrame)
		_G.TradeSkillRankFrame:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
		_G.TradeSkillRankFrame:SetStatusBarColor(WSkin:GetRetailAccent())
	end
	CheckBox("TradeSkillFrameAvailableFilterCheckButton")
	EditBoxes({ "TradeSkillFrameEditBox", "TradeSkillInputBox" })
	DropDown("TradeSkillInvSlotDropDown", 140)
	DropDown("TradeSkillSubClassDropDown", 140)
	WSkin:HandleCollapseExpandButton(_G.TradeSkillCollapseAllButton, "+")
	for i = 1, (_G.TRADE_SKILLS_DISPLAYED or 8) do
		WSkin:HandleCollapseExpandButton(_G["TradeSkillSkill" .. i], "+", nil, nil, 1)
	end
	ScrollBars({ "TradeSkillListScrollFrameScrollBar", "TradeSkillDetailScrollFrameScrollBar" })
	SkinItem("TradeSkillSkillIcon")
	for i = 1, (_G.MAX_TRADE_SKILL_REAGENTS or 8) do SkinItem("TradeSkillReagent" .. i) end
	WSkin:HandleNextPrevButton(_G.TradeSkillDecrementButton, "left")
	WSkin:HandleNextPrevButton(_G.TradeSkillIncrementButton, "right")
	Buttons({ "TradeSkillCancelButton", "TradeSkillCreateAllButton" })
	Buttons({ "TradeSkillCreateButton" }, true)
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
			WSkin:ApplyRetailSurface(button, "row")
			WSkin:StyleButton(button)
		end
	end
	Buttons({
		"CalendarCreateEventMassInviteButton", "CalendarCreateEventInviteButton",
		"CalendarCreateEventInviteListButton", "CalendarCreateEventRemoveInviteButton", "CalendarCreateEventCloseButton",
		"CalendarViewEventTentativeButton", "CalendarViewEventRemoveButton",
		"CalendarViewEventDeclineButton", "CalendarEventPickerCloseButton",
	})
	Buttons({ "CalendarCreateEventCreateButton", "CalendarViewEventAcceptButton" }, true)
	ScrollBars({
		"CalendarCreateEventDescriptionScrollFrameScrollBar", "CalendarCreateEventInviteListScrollFrameScrollBar",
		"CalendarEventPickerScrollBar",
	})
	EditBoxes({ "CalendarCreateEventTitleEdit", "CalendarCreateEventHourEdit", "CalendarCreateEventMinuteEdit" })
	for _, name in ipairs({
		"CalendarCreateEventTypeDropDown", "CalendarCreateEventHourDropDown", "CalendarCreateEventMinuteDropDown",
		"CalendarCreateEventAMPMDropDown", "CalendarCreateEventRepeatOptionDropDown",
	}) do DropDown(name) end
end

-------------------------------------------------------------------------------
-- Blizzard options and AddOn list
-------------------------------------------------------------------------------
local function SkinSettings()
	if not WSkin:IsSkinEnabled("settings") then return end
	if _G.InterfaceOptionsFrame then
		SkinWindow("InterfaceOptionsFrame", "InterfaceOptionsFrameCloseButton", 3, -7, -3, 3)
		SkinTabs("InterfaceOptionsFrameTab", 2, "InterfaceOptionsFrame")
		ScrollBars({ "InterfaceOptionsFrameCategoriesListScrollBar", "InterfaceOptionsFrameAddOnsListScrollBar" })
		Buttons({ "InterfaceOptionsFrameDefaults", "InterfaceOptionsFrameCancel" })
		Buttons({ "InterfaceOptionsFrameOkay" }, true)
	end
	if _G.VideoOptionsFrame then
		SkinWindow("VideoOptionsFrame", "VideoOptionsFrameCloseButton", 3, -7, -3, 3)
		Buttons({ "VideoOptionsFrameDefaults", "VideoOptionsFrameCancel" })
		Buttons({ "VideoOptionsFrameOkay" }, true)
	end
	if _G.AudioOptionsFrame then
		SkinWindow("AudioOptionsFrame", "AudioOptionsFrameCloseButton", 3, -7, -3, 3)
		Buttons({ "AudioOptionsFrameDefaults", "AudioOptionsFrameCancel" })
		Buttons({ "AudioOptionsFrameOkay" }, true)
	end
end

local function SkinAddonList()
	if not WSkin:IsSkinEnabled("addonlist") or not _G.AddonList then return end
	SkinWindow("AddonList", "AddonListCloseButton", 8, -12, -8, 8)
	WSkin:HandleRetailScrollBar(_G.AddonListScrollFrameScrollBar)
	DropDown("AddonCharacterDropDown")
	Buttons({ "AddonListEnableAllButton", "AddonListDisableAllButton", "AddonListCancelButton" })
	Buttons({ "AddonListOkayButton" }, true)
	for i = 1, (_G.MAX_ADDONS_DISPLAYED or 19) do CheckBox("AddonListEntry" .. i .. "Enabled") end
end

-------------------------------------------------------------------------------
-- Smaller Wrath windows which share the same retail window treatment
-------------------------------------------------------------------------------
local function SkinTrade()
	if not WSkin:IsSkinEnabled("misc") or not _G.TradeFrame then return end
	SkinWindow("TradeFrame", "TradeFrameCloseButton", 11, -12, -21, 49)
	EditBoxes({
		"TradePlayerInputMoneyFrameGold", "TradePlayerInputMoneyFrameSilver", "TradePlayerInputMoneyFrameCopper",
	})
	Buttons({ "TradeFrameCancelButton" })
	Buttons({ "TradeFrameTradeButton" }, true)
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
	Buttons({ "PetStableFramePetInfoCloseButton" })
	Buttons({ "PetStablePurchaseButton" }, true)
	SkinItem("PetStableCurrentPet")
	for i = 1, (_G.NUM_PET_STABLE_SLOTS or 4) do SkinItem("PetStableStabledPet" .. i) end
	Card("PetStableModel")
end

local function SkinTaxi()
	if not WSkin:IsSkinEnabled("worldmap") or not _G.TaxiFrame then return end
	SkinWindow("TaxiFrame", "TaxiCloseButton", 11, -12, -32, 76)
	if _G.TaxiPortrait then WSkin:Kill(_G.TaxiPortrait) end
	Card("TaxiRouteMap")
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
	}, WSkin.HandleRetailButton)
	ScrollBars({
		"HelpFrameOpenTicketScrollFrameScrollBar", "HelpFrameViewResponseIssueScrollFrameScrollBar",
		"HelpFrameViewResponseMessageScrollFrameScrollBar",
	})
	Each({
		"KnowledgeBaseFrameDivider", "KnowledgeBaseFrameDivider2",
		"HelpFrameOpenTicketDivider", "HelpFrameViewResponseDivider",
	}, WSkin.StripTextures)
end

local function SkinRaid()
	if not WSkin:IsSkinEnabled("misc") then return end
	if _G.RaidFrame then
		for i = 1, 8 do Strip("RaidGroup" .. i) end
		Buttons({ "RaidFrameRaidBrowserButton", "RaidFrameReadyCheckButton", "RaidFrameRaidInfoButton" })
		for i = 1, (_G.MAX_RAID_MEMBERS or 40) do
			local button = Strip("RaidGroupButton" .. i)
			if button then
				WSkin:UpdateRetailRow(button, false)
				WSkin:HandleButtonHighlight(button)
			end
		end
	end
end

local function SkinGuildUtilityWindows()
	if not WSkin:IsSkinEnabled("guild") then return end
	if _G.GuildRegistrarFrame then
		SkinWindow("GuildRegistrarFrame", "GuildRegistrarFrameCloseButton")
		Buttons({ "GuildRegistrarFrameCancelButton" })
		Buttons({ "GuildRegistrarFramePurchaseButton" }, true)
	end
	if _G.PetitionFrame then
		SkinWindow("PetitionFrame", "PetitionFrameCloseButton")
		Buttons({ "PetitionFrameRequestButton", "PetitionFrameRenameButton", "PetitionFrameCancelButton" })
		Buttons({ "PetitionFrameSignButton" }, true)
	end
	if _G.TabardFrame then
		SkinWindow("TabardFrame", "TabardFrameCloseButton")
		if _G.TabardFramePortrait then WSkin:Kill(_G.TabardFramePortrait) end
		Buttons({ "TabardFrameCancelButton" })
		Buttons({ "TabardFrameAcceptButton" }, true)
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
