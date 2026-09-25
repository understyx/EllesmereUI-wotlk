local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G

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

local function SkinWindow(frame, closeButton, stripFrame)
	if not frame then return end
	if stripFrame ~= false then WSkin:StripTextures(frame, true) end
	WSkin:CreateBackdrop(frame, "Transparent")
	if not frame.backdrop then return end
	frame.backdrop:ClearAllPoints()
	Point(frame.backdrop, "TOPLEFT", frame, "TOPLEFT", 11, -12)
	Point(frame.backdrop, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 76)
	WSkin:SetUIPanelWindowInfo(frame, "width")
	WSkin:SetBackdropHitRect(frame)
	WSkin:HandleCloseButton(closeButton, frame.backdrop)
	return frame.backdrop
end

local function WhiteText(region)
	if region and region.SetTextColor then region:SetTextColor(1, 1, 1) end
end

local function SkinPvP()
	if not WSkin:IsSkinEnabled("misc") or not _G.PVPParentFrame then return end
	-- EllesmereUIBlizzardSkin_GroupFinder.lua owns the modern Wrath PvP shell
	-- whenever that skin is enabled. Running this legacy callback as well would
	-- insert a separate 80%-black backdrop below the same controls.
	if _G.EllesmereUI and _G.EllesmereUI._GroupFinderOwnsLegacyPvP
		and (not EllesmereUIDB or EllesmereUIDB.reskinLFGMenu ~= false) then
		return
	end

	local parentBackdrop = SkinWindow(_G.PVPParentFrame, _G.PVPParentFrameCloseButton, false)
	if not parentBackdrop then return end
	WSkin:SetBackdropHitRect(_G.PVPFrame, parentBackdrop)
	WSkin:SetBackdropHitRect(_G.PVPBattlegroundFrame, parentBackdrop)
	for i = 1, 2 do WSkin:HandleTab(_G["PVPParentFrameTab" .. i]) end
	ClearPoints(_G.PVPParentFrameTab1, _G.PVPParentFrameTab2)
	Point(_G.PVPParentFrameTab1, "BOTTOMLEFT", _G.PVPParentFrame, "BOTTOMLEFT", 11, 46)
	Point(_G.PVPParentFrameTab2, "LEFT", _G.PVPParentFrameTab1, "RIGHT", -15, 0)

	WSkin:StripTextures(_G.PVPFrame, true)
	for i = 1, Count(_G.MAX_ARENA_TEAMS, 3) do
		local team = _G["PVPTeam" .. i]
		if team then
			WSkin:StripTextures(team)
			WSkin:CreateBackdrop(team, "Default")
			if team.backdrop then
				team.backdrop:ClearAllPoints()
				Point(team.backdrop, "TOPLEFT", team, "TOPLEFT", 9, -4)
				Point(team.backdrop, "BOTTOMRIGHT", team, "BOTTOMRIGHT", -24, 3)
			end
			WSkin:SetBackdropHitRect(team)
			team:HookScript("OnEnter", WSkin.SetModifiedBackdrop)
			team:HookScript("OnLeave", WSkin.SetOriginalBackdrop)
		end
		WSkin:Kill(_G["PVPTeam" .. i .. "Highlight"])
	end

	if _G.PVPTeamDetails then
		WSkin:StripTextures(_G.PVPTeamDetails)
		WSkin:SetTemplate(_G.PVPTeamDetails, "Transparent")
		Point(_G.PVPTeamDetails, "TOPLEFT", _G.PVPFrame, "TOPRIGHT", -33, -81)
		WSkin:HandleCloseButton(_G.PVPTeamDetailsCloseButton, _G.PVPTeamDetails)
		for i = 1, 5 do WSkin:StripTextures(_G["PVPTeamDetailsFrameColumnHeader" .. i]) end
		for i = 1, Count(_G.MAX_ARENA_TEAM_MEMBERS, 10) do WSkin:HandleButtonHighlight(_G["PVPTeamDetailsButton" .. i]) end
		WSkin:HandleButton(_G.PVPTeamDetailsAddTeamMember)
		WSkin:HandleNextPrevButton(_G.PVPTeamDetailsToggleButton)
		Point(_G.PVPTeamDetailsAddTeamMember, "TOPLEFT", _G.PVPTeamDetailsButton10, "BOTTOMLEFT", 5, -8)
		Point(_G.PVPTeamDetailsToggleButton, "BOTTOMRIGHT", _G.PVPTeamDetails, "BOTTOMRIGHT", -20, 25)
	end

	WSkin:StripTextures(_G.PVPBattlegroundFrame, true)
	WSkin:StripTextures(_G.PVPBattlegroundFrameTypeScrollFrame)
	WSkin:StripTextures(_G.PVPBattlegroundFrameInfoScrollFrame)
	WSkin:HandleScrollBar(_G.PVPBattlegroundFrameTypeScrollFrameScrollBar)
	WSkin:HandleScrollBar(_G.PVPBattlegroundFrameInfoScrollFrameScrollBar)
	Each({
		"PVPBattlegroundFrameGroupJoinButton", "PVPBattlegroundFrameJoinButton", "PVPBattlegroundFrameCancelButton",
	}, WSkin.HandleButton)
	for i = 1, 5 do WSkin:HandleButtonHighlight(_G["BattlegroundType" .. i]) end
	WhiteText(_G.PVPBattlegroundFrameInfoScrollFrameChildFrameDescription)
	local rewards = _G.PVPBattlegroundFrameInfoScrollFrameChildFrameRewardsInfo
	WhiteText(rewards and rewards.description)
	Point(_G.PVPBattlegroundFrameTypeScrollFrameScrollBar, "TOPLEFT", _G.PVPBattlegroundFrameTypeScrollFrame, "TOPRIGHT", 6, -19)
	Point(_G.PVPBattlegroundFrameTypeScrollFrameScrollBar, "BOTTOMLEFT", _G.PVPBattlegroundFrameTypeScrollFrame, "BOTTOMRIGHT", 6, 19)
	Point(_G.PVPBattlegroundFrameInfoScrollFrame, "BOTTOMLEFT", _G.PVPBattlegroundFrame, "BOTTOMLEFT", 19, 114)
	Point(_G.PVPBattlegroundFrameInfoScrollFrameScrollBar, "TOPLEFT", _G.PVPBattlegroundFrameInfoScrollFrame, "TOPRIGHT", 7, -24)
	Point(_G.PVPBattlegroundFrameInfoScrollFrameScrollBar, "BOTTOMLEFT", _G.PVPBattlegroundFrameInfoScrollFrame, "BOTTOMRIGHT", 7, 19)
	if _G.PVPBattlegroundFrameGroupJoinButton then WSkin:Width(_G.PVPBattlegroundFrameGroupJoinButton, 127) end
	ClearPoints(_G.PVPBattlegroundFrameGroupJoinButton, _G.PVPBattlegroundFrameJoinButton, _G.PVPBattlegroundFrameCancelButton)
	Point(_G.PVPBattlegroundFrameCancelButton, "CENTER", _G.PVPBattlegroundFrame, "TOPLEFT", 300, -416)
	Point(_G.PVPBattlegroundFrameJoinButton, "RIGHT", _G.PVPBattlegroundFrameCancelButton, "LEFT", -3, 0)
	Point(_G.PVPBattlegroundFrameGroupJoinButton, "RIGHT", _G.PVPBattlegroundFrameJoinButton, "LEFT", -3, 0)

	if _G.WintergraspTimer then
		WSkin:Size(_G.WintergraspTimer, 24)
		WSkin:SetTemplate(_G.WintergraspTimer, "Default")
		Point(_G.WintergraspTimer, "RIGHT", _G.PVPBattlegroundFrame, "TOPRIGHT", -42, -58)
		if _G.WintergraspTimer.texture then
			_G.WintergraspTimer.texture:SetDrawLayer("ARTWORK")
			WSkin:SetInside(_G.WintergraspTimer.texture, _G.WintergraspTimer)
		end
	end

	if _G.BattlefieldFrame then
		SkinWindow(_G.BattlefieldFrame, _G.BattlefieldFrameCloseButton)
		WSkin:StripTextures(_G.BattlefieldListScrollFrame)
		WSkin:HandleScrollBar(_G.BattlefieldListScrollFrameScrollBar)
		WSkin:HandleScrollBar(_G.BattlefieldFrameInfoScrollFrameScrollBar)
		WhiteText(_G.BattlefieldFrameInfoScrollFrameChildFrameDescription)
		WhiteText(_G.BattlefieldFrameInfoScrollFrameChildFrameRewardsInfoDescription)
		Each({
			"BattlefieldFrameGroupJoinButton", "BattlefieldFrameJoinButton", "BattlefieldFrameCancelButton",
		}, WSkin.HandleButton)
		for i = 1, Count(_G.BATTLEFIELD_ZONES_DISPLAYED, 5) do WSkin:HandleButtonHighlight(_G["BattlefieldZone" .. i]) end
		Point(_G.BattlefieldFrameNameHeader, "TOPLEFT", _G.BattlefieldFrame, "TOPLEFT", 73, -57)
		Point(_G.BattlefieldZone1, "TOPLEFT", _G.BattlefieldFrame, "TOPLEFT", 25, -80)
		Point(_G.BattlefieldListScrollFrameScrollBar, "TOPLEFT", _G.BattlefieldListScrollFrame, "TOPRIGHT", 9, -23)
		Point(_G.BattlefieldListScrollFrameScrollBar, "BOTTOMLEFT", _G.BattlefieldListScrollFrame, "BOTTOMRIGHT", 9, 23)
		Point(_G.BattlefieldFrameInfoScrollFrame, "BOTTOMLEFT", _G.BattlefieldFrame, "BOTTOMLEFT", 21, 113)
		Point(_G.BattlefieldFrameInfoScrollFrameScrollBar, "TOPLEFT", _G.BattlefieldFrameInfoScrollFrame, "TOPRIGHT", 7, -20)
		Point(_G.BattlefieldFrameInfoScrollFrameScrollBar, "BOTTOMLEFT", _G.BattlefieldFrameInfoScrollFrame, "BOTTOMRIGHT", 7, 19)
		if _G.BattlefieldFrameGroupJoinButton then WSkin:Width(_G.BattlefieldFrameGroupJoinButton, 127) end
		ClearPoints(_G.BattlefieldFrameGroupJoinButton, _G.BattlefieldFrameJoinButton, _G.BattlefieldFrameCancelButton)
		Point(_G.BattlefieldFrameCancelButton, "CENTER", _G.BattlefieldFrame, "TOPLEFT", 302, -417)
		Point(_G.BattlefieldFrameJoinButton, "RIGHT", _G.BattlefieldFrameCancelButton, "LEFT", -3, 0)
		Point(_G.BattlefieldFrameGroupJoinButton, "RIGHT", _G.BattlefieldFrameJoinButton, "LEFT", -3, 0)
	end
end

WSkin:AddCallback("Skin_PvP", SkinPvP, "misc")
