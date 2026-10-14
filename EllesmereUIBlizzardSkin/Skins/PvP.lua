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
	-- Shared window shell on the visible backdrop rect; Blizzard's content
	-- layout stays anchored to the native frame.
	WSkin:CreateRetailWindowShell(frame.backdrop, nil, nil, closeButton, { content = false })
	WSkin:SetUIPanelWindowInfo(frame, "width")
	WSkin:SetBackdropHitRect(frame)
	return frame.backdrop
end

local function Buttons(names, primary)
	Each(names, WSkin.HandleRetailButton, primary)
end

local laying = false
local function LayoutParentTabs()
	local frame = _G.PVPParentFrame
	local shell = frame and frame.backdrop
	if not shell or laying then return end
	laying = true
	local tabs = { _G.PVPParentFrameTab1, _G.PVPParentFrameTab2 }
	WSkin:LayoutRetailTabRow(tabs, shell, 110, 0)
	local selected = type(_G.PanelTemplates_GetSelectedTab) == "function"
		and _G.PanelTemplates_GetSelectedTab(frame) or frame.selectedTab or 1
	for i, tab in ipairs(tabs) do WSkin:UpdateRetailTab(tab, i == selected) end
	laying = false
end

local function TeamHover(team, hovered)
	local backdrop = team and team.backdrop
	if not backdrop then return end
	if hovered then
		local ar, ag, ab = WSkin:GetRetailAccent()
		backdrop:SetBackdropBorderColor(ar, ag, ab, 0.55)
	else
		backdrop:SetBackdropBorderColor(1, 1, 1, 0.06)
	end
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
	for i = 1, 2 do
		local tab = _G["PVPParentFrameTab" .. i]
		if tab then
			WSkin:StyleRetailTab(tab)
			tab:SetHitRectInsets(0, 0, 0, 0)
			tab:HookScript("OnShow", LayoutParentTabs)
		end
	end
	hooksecurefunc("PanelTemplates_SetTab", function(owner)
		if owner == _G.PVPParentFrame then LayoutParentTabs() end
	end)
	hooksecurefunc("PanelTemplates_TabResize", function(tab)
		if tab == _G.PVPParentFrameTab1 or tab == _G.PVPParentFrameTab2 then LayoutParentTabs() end
	end)
	_G.PVPParentFrame:HookScript("OnShow", LayoutParentTabs)
	LayoutParentTabs()

	WSkin:StripTextures(_G.PVPFrame, true)
	for i = 1, Count(_G.MAX_ARENA_TEAMS, 3) do
		local team = _G["PVPTeam" .. i]
		if team then
			WSkin:StripTextures(team)
			WSkin:CreateBackdrop(team, "Default")
			if team.backdrop then
				WSkin:UpdateRetailRow(team.backdrop, false)
				team.backdrop:ClearAllPoints()
				Point(team.backdrop, "TOPLEFT", team, "TOPLEFT", 9, -4)
				Point(team.backdrop, "BOTTOMRIGHT", team, "BOTTOMRIGHT", -24, 3)
			end
			WSkin:SetBackdropHitRect(team)
			team:HookScript("OnEnter", function(self) TeamHover(self, true) end)
			team:HookScript("OnLeave", function(self) TeamHover(self, false) end)
		end
		WSkin:Kill(_G["PVPTeam" .. i .. "Highlight"])
	end

	if _G.PVPTeamDetails then
		WSkin:StripTextures(_G.PVPTeamDetails)
		WSkin:CreateRetailWindowShell(_G.PVPTeamDetails, nil, nil, _G.PVPTeamDetailsCloseButton, { content = false })
		Point(_G.PVPTeamDetails, "TOPLEFT", _G.PVPFrame, "TOPRIGHT", -33, -81)
		for i = 1, 5 do
			local header = _G["PVPTeamDetailsFrameColumnHeader" .. i]
			WSkin:StripTextures(header)
			WSkin:ApplyRetailSurface(header, "header")
			WSkin:ApplyRetailRegionTypography(header, "secondary")
		end
		for i = 1, Count(_G.MAX_ARENA_TEAM_MEMBERS, 10) do WSkin:HandleButtonHighlight(_G["PVPTeamDetailsButton" .. i]) end
		WSkin:HandleRetailButton(_G.PVPTeamDetailsAddTeamMember)
		WSkin:HandleNextPrevButton(_G.PVPTeamDetailsToggleButton)
		Point(_G.PVPTeamDetailsAddTeamMember, "TOPLEFT", _G.PVPTeamDetailsButton10, "BOTTOMLEFT", 5, -8)
		Point(_G.PVPTeamDetailsToggleButton, "BOTTOMRIGHT", _G.PVPTeamDetails, "BOTTOMRIGHT", -20, 25)
	end

	WSkin:StripTextures(_G.PVPBattlegroundFrame, true)
	WSkin:StripTextures(_G.PVPBattlegroundFrameTypeScrollFrame)
	WSkin:StripTextures(_G.PVPBattlegroundFrameInfoScrollFrame)
	WSkin:HandleRetailScrollBar(_G.PVPBattlegroundFrameTypeScrollFrameScrollBar)
	WSkin:HandleRetailScrollBar(_G.PVPBattlegroundFrameInfoScrollFrameScrollBar)
	Buttons({ "PVPBattlegroundFrameGroupJoinButton", "PVPBattlegroundFrameCancelButton" })
	Buttons({ "PVPBattlegroundFrameJoinButton" }, true)
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
		WSkin:ApplyRetailSurface(_G.WintergraspTimer, "input")
		Point(_G.WintergraspTimer, "RIGHT", _G.PVPBattlegroundFrame, "TOPRIGHT", -42, -58)
		if _G.WintergraspTimer.texture then
			_G.WintergraspTimer.texture:SetDrawLayer("ARTWORK")
			WSkin:SetInside(_G.WintergraspTimer.texture, _G.WintergraspTimer)
		end
	end

	if _G.BattlefieldFrame then
		SkinWindow(_G.BattlefieldFrame, _G.BattlefieldFrameCloseButton)
		WSkin:StripTextures(_G.BattlefieldListScrollFrame)
		WSkin:HandleRetailScrollBar(_G.BattlefieldListScrollFrameScrollBar)
		WSkin:HandleRetailScrollBar(_G.BattlefieldFrameInfoScrollFrameScrollBar)
		WhiteText(_G.BattlefieldFrameInfoScrollFrameChildFrameDescription)
		WhiteText(_G.BattlefieldFrameInfoScrollFrameChildFrameRewardsInfoDescription)
		Buttons({ "BattlefieldFrameGroupJoinButton", "BattlefieldFrameCancelButton" })
		Buttons({ "BattlefieldFrameJoinButton" }, true)
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
