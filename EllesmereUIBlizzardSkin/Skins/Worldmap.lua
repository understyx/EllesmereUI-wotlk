local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local type = type

local function Point(frame, ...)
	if not frame then return end
	frame:ClearAllPoints()
	WSkin:Point(frame, ...)
end

local function StyleDropDown(frame, width)
	if not frame then return end
	WSkin:HandleDropDownBox(frame, width)
	if frame.backdrop then WSkin:ApplyRetailSurface(frame.backdrop, "input") end
	WSkin:ApplyRetailRegionTypography(frame, "row")
end

local function StyleMapTypography()
	local font = _G.EllesmereUI and _G.EllesmereUI.GetFontPath
		and _G.EllesmereUI.GetFontPath("blizzardSkin") or _G.STANDARD_TEXT_FONT
	local function Font(region, size, alpha)
		if not region then return end
		region:SetFont(font, size, "OUTLINE")
		region:SetTextColor(1, 1, 1, alpha or 1)
		region:SetShadowOffset(1, -1)
		region:SetShadowColor(0, 0, 0, 0.90)
	end
	Font(_G.WorldMapFrameAreaLabel, 30, 1)
	Font(_G.WorldMapFrameAreaDescription, 16, 0.82)
	Font(_G.WorldMapZoneInfo, 13, 0.78)
	Font(_G.MapFramerateLabel, 10, 0.58)
	Font(_G.MapFramerateText, 10, 0.84)
	WSkin:ApplyRetailTypography(_G.WorldMapTrackQuestText, "row", 0.82)
	WSkin:ApplyRetailTypography(_G.WorldMapQuestShowObjectivesText, "row", 0.82)
	WSkin:ApplyRetailRegionTypography(_G.WorldMapQuestScrollChildFrame, "row")
	WSkin:ApplyRetailRegionTypography(_G.WorldMapQuestDetailScrollChildFrame, "row")
	WSkin:ApplyRetailRegionTypography(_G.WorldMapQuestRewardScrollChildFrame, "row")
end

WSkin:AddCallback("Skin_WorldMap", function()
	if not WSkin:IsSkinEnabled("worldmap") then return end
	local frame = _G.WorldMapFrame
	if not frame then return end

	-- Strip only the map window's own ornamental border. The actual map tiles
	-- live on child frames and remain completely Blizzard-controlled.
	WSkin:StripTextures(frame, true)
	local shellState = WSkin:CreateRetailWindowShell(
		frame,
		nil,
		_G.WorldMapFrameTitle,
		_G.WorldMapFrameCloseButton,
		{ content = false }
	)
	frame:SetClampRectInsets(3, 0, 2, 1)

	-- WorldMapFrame is a full-screen frame in the large views and a 593x437
	-- functional frame in mini mode.  Neither rectangle is the mini map's
	-- actual visible panel: the map is a scaled WorldMapDetailFrame and its
	-- footer controls deliberately sit below it.  Keep the Blizzard frame
	-- untouched and make the decorative shell follow the visible rectangle.
	local pixel = _G.EllesmereUI and (_G.EllesmereUI.PanelPP or _G.EllesmereUI.PP)
	if pixel and pixel.HideBorder then pixel.HideBorder(frame) end
	local shellBorder = _G.CreateFrame("Frame", nil, frame)
	if pixel and pixel.CreateBorder then
		pixel.CreateBorder(shellBorder, 0.2, 0.2, 0.2, 1, 1, "OVERLAY", 7)
	end

	local function SetRect(object, topLeft, topLeftPoint, x1, y1, bottomRight, bottomRightPoint, x2, y2)
		if not object then return end
		object:ClearAllPoints()
		object:SetPoint("TOPLEFT", topLeft, topLeftPoint, x1, y1)
		object:SetPoint("BOTTOMRIGHT", bottomRight, bottomRightPoint, x2, y2)
	end

	local function SetSmallShellBounds()
		local detail = _G.WorldMapDetailFrame
		if not detail then return end
		SetRect(shellState and shellState.windowBackground, detail, "TOPLEFT", -6, 34, detail, "BOTTOMRIGHT", 6, -32)
		SetRect(shellState and shellState.windowOverlay, detail, "TOPLEFT", -6, 34, detail, "BOTTOMRIGHT", 6, -32)
		SetRect(shellBorder, detail, "TOPLEFT", -6, 34, detail, "BOTTOMRIGHT", 6, -32)
		if shellState and shellState.windowTopBar then
			shellState.windowTopBar:ClearAllPoints()
			shellState.windowTopBar:SetPoint("TOPLEFT", detail, "TOPLEFT", -6, 34)
			shellState.windowTopBar:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 6, 34)
			shellState.windowTopBar:SetHeight(34)
		end
		shellBorder:SetFrameLevel(frame:GetFrameLevel() + 1)
		if shellState and shellState.updateWindowTexCoords then shellState.updateWindowTexCoords() end
	end

	local function SetFullShellBounds()
		if shellState and shellState.windowBackground then
			shellState.windowBackground:ClearAllPoints()
			shellState.windowBackground:SetAllPoints(frame)
		end
		if shellState and shellState.windowOverlay then
			shellState.windowOverlay:ClearAllPoints()
			shellState.windowOverlay:SetAllPoints(frame)
		end
		if shellState and shellState.windowTopBar then
			shellState.windowTopBar:ClearAllPoints()
			shellState.windowTopBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
			shellState.windowTopBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
			shellState.windowTopBar:SetHeight(25)
		end
		shellBorder:ClearAllPoints()
		shellBorder:SetAllPoints(frame)
		shellBorder:SetFrameLevel(frame:GetFrameLevel() + 1)
		-- SetAllPoints changes WorldMapFrame's effective size without calling
		-- SetWidth/SetHeight, so refresh the cover crop explicitly.
		if shellState and shellState.updateWindowTexCoords then shellState.updateWindowTexCoords() end
	end

	if _G.WorldMapTitleButton then
		_G.WorldMapTitleButton:SetAlpha(0)
		_G.WorldMapTitleButton:Show()
	end

	if _G.WorldMapDetailFrame then
		WSkin:ApplyRetailSurface(_G.WorldMapDetailFrame, "body")
		_G.WorldMapDetailFrame:SetBackdropBorderColor(1, 1, 1, 0.12)
	end

	local questDetail = _G.WorldMapQuestDetailScrollFrame
	local questReward = _G.WorldMapQuestRewardScrollFrame
	local questList = _G.WorldMapQuestScrollFrame
	if questDetail then
		WSkin:Width(questDetail, 348)
		WSkin:Point(questDetail, "BOTTOMLEFT", _G.WorldMapDetailFrame, "BOTTOMLEFT", -25, -207)
		WSkin:StripTextures(questDetail)
		WSkin:ApplyRetailSurface(questDetail, "card")
		questDetail:SetHitRectInsets(24, -23, 0, -2)
	end
	if _G.WorldMapQuestDetailScrollChildFrame then _G.WorldMapQuestDetailScrollChildFrame:SetScale(1) end
	WSkin:Kill(_G.WorldMapQuestDetailScrollFrameTrack)

	if questReward then
		WSkin:Width(questReward, 340)
		WSkin:Point(questReward, "LEFT", questDetail, "RIGHT", 8, 0)
		WSkin:StripTextures(questReward)
		WSkin:ApplyRetailSurface(questReward, "card")
		questReward:SetHitRectInsets(20, -22, 0, -2)
	end
	if _G.WorldMapQuestRewardScrollChildFrame then _G.WorldMapQuestRewardScrollChildFrame:SetScale(1) end
	if _G.WorldMapQuestRewardScrollFrameTrack then _G.WorldMapQuestRewardScrollFrameTrack:SetTexture("") end

	if questList then
		WSkin:Point(questList, "TOPLEFT", _G.WorldMapDetailFrame, "TOPRIGHT", 6, -1)
		WSkin:StripTextures(questList)
		WSkin:ApplyRetailSurface(questList, "card")
	end

	local ar, ag, ab = WSkin:GetRetailAccent()
	if _G.WorldMapQuestSelectBar then
		_G.WorldMapQuestSelectBar:SetTexture(ar, ag, ab, 0.26)
	end
	if _G.WorldMapQuestHighlightBar then
		_G.WorldMapQuestHighlightBar:SetTexture(1, 1, 1, 0.08)
	end

	WSkin:HandleRetailScrollBar(_G.WorldMapQuestScrollFrameScrollBar)
	WSkin:HandleRetailScrollBar(_G.WorldMapQuestDetailScrollFrameScrollBar)
	WSkin:HandleRetailScrollBar(_G.WorldMapQuestRewardScrollFrameScrollBar)
	if _G.WorldMapQuestScrollFrameScrollBar then
		Point(_G.WorldMapQuestScrollFrameScrollBar, "TOPLEFT", questList, "TOPRIGHT", 5, -2)
		_G.WorldMapQuestScrollFrameScrollBar:SetPoint("BOTTOMLEFT", questList, "BOTTOMRIGHT", 5, 2)
	end
	if _G.WorldMapQuestDetailScrollFrameScrollBar then
		Point(_G.WorldMapQuestDetailScrollFrameScrollBar, "TOPLEFT", questDetail, "TOPRIGHT", 3, -2)
		_G.WorldMapQuestDetailScrollFrameScrollBar:SetPoint("BOTTOMLEFT", questDetail, "BOTTOMRIGHT", 3, 2)
	end
	if _G.WorldMapQuestRewardScrollFrameScrollBar then
		Point(_G.WorldMapQuestRewardScrollFrameScrollBar, "TOPLEFT", questReward, "TOPRIGHT", 2, -2)
		_G.WorldMapQuestRewardScrollFrameScrollBar:SetPoint("BOTTOMLEFT", questReward, "BOTTOMRIGHT", 2, 2)
	end

	if _G.WorldMapFrameSizeDownButton then
		_G.WorldMapFrameSizeDownButton:ClearAllPoints()
		_G.WorldMapFrameSizeDownButton:SetPoint("RIGHT", _G.WorldMapFrameCloseButton, "LEFT", 0, 0)
		WSkin:HandleNextPrevButton(_G.WorldMapFrameSizeDownButton, "down", nil, true)
		WSkin:Size(_G.WorldMapFrameSizeDownButton, 24)
	end
	if _G.WorldMapFrameSizeUpButton then
		WSkin:HandleNextPrevButton(_G.WorldMapFrameSizeUpButton, "up", nil, true)
		WSkin:Size(_G.WorldMapFrameSizeUpButton, 24)
	end

	StyleDropDown(_G.WorldMapLevelDropDown)
	StyleDropDown(_G.WorldMapZoneMinimapDropDown)
	StyleDropDown(_G.WorldMapContinentDropDown)
	StyleDropDown(_G.WorldMapZoneDropDown)
	WSkin:HandleNextPrevButton(_G.WorldMapLevelUpButton, "up")
	WSkin:HandleNextPrevButton(_G.WorldMapLevelDownButton, "down")
	if _G.WorldMapLevelUpButton and _G.WorldMapLevelDropDown then
		Point(_G.WorldMapLevelUpButton, "TOPLEFT", _G.WorldMapLevelDropDown, "TOPRIGHT", -6, 4)
	end
	if _G.WorldMapLevelDownButton and _G.WorldMapLevelDropDown then
		Point(_G.WorldMapLevelDownButton, "BOTTOMLEFT", _G.WorldMapLevelDropDown, "BOTTOMRIGHT", -6, 0)
	end

	WSkin:HandleRetailButton(_G.WorldMapZoomOutButton, true)
	if _G.WorldMapZoomOutButton and _G.WorldMapZoneDropDown then
		Point(_G.WorldMapZoomOutButton, "LEFT", _G.WorldMapZoneDropDown, "RIGHT", 0, 3)
	end
	WSkin:HandleCheckBox(_G.WorldMapTrackQuest)
	WSkin:HandleCheckBox(_G.WorldMapQuestShowObjectives)
	StyleMapTypography()

	local function LayoutWindowControls(mode)
		local detail = _G.WorldMapDetailFrame
		local guide = _G.WorldMapPositioningGuide
		local close = _G.WorldMapFrameCloseButton
		local sizeDown = _G.WorldMapFrameSizeDownButton
		local sizeUp = _G.WorldMapFrameSizeUpButton
		local title = _G.WorldMapFrameTitle
		local titleButton = _G.WorldMapTitleButton
		local objectiveText = _G.WorldMapQuestShowObjectivesText
		local textWidth = objectiveText and objectiveText.GetStringWidth
			and objectiveText:GetStringWidth()
		if not textWidth or textWidth < 1 then textWidth = 145 end

		if mode == "small" or mode == "small-advanced" then
			SetSmallShellBounds()
			if title then
				title:ClearAllPoints()
				title:SetPoint("TOP", detail, "TOP", 0, 27)
			end
			if close then
				close:ClearAllPoints()
				close:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 5, 31)
			end
			local sizeButton = sizeUp and sizeUp:IsShown() and sizeUp or sizeDown
			if sizeButton and close then
				sizeButton:ClearAllPoints()
				sizeButton:SetPoint("RIGHT", close, "LEFT", 0, 0)
			end
			if titleButton then
				titleButton:ClearAllPoints()
				titleButton:SetPoint("TOPLEFT", detail, "TOPLEFT", -6, 34)
				titleButton:SetPoint("BOTTOMRIGHT", detail, "TOPRIGHT", 6, 0)
				titleButton:Show()
			end

			-- Put both options on a dedicated footer row inside the shell.  The
			-- stock anchors place their text below the 437px mini frame.
			Point(_G.WorldMapTrackQuest, "TOPLEFT", detail, "BOTTOMLEFT", 6, -4)
			Point(_G.WorldMapQuestShowObjectives, "TOPRIGHT", detail, "BOTTOMRIGHT", -8 - textWidth, -4)
		else
			SetFullShellBounds()
			if titleButton then titleButton:Hide() end
			if close then
				close:ClearAllPoints()
				close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
			end
			if sizeDown and close then
				sizeDown:ClearAllPoints()
				sizeDown:SetPoint("RIGHT", close, "LEFT", 0, 0)
			end
			-- Mini mode uses TOP anchors to place these controls in its enclosed
			-- footer. Clear those anchors when returning to either large view so
			-- Blizzard's full-map footer cannot become over-constrained.
			if guide then
				Point(_G.WorldMapTrackQuest, "BOTTOMLEFT", guide, "BOTTOMLEFT", 16, 4)
				Point(_G.WorldMapQuestShowObjectives, "BOTTOMRIGHT", guide, "BOTTOMRIGHT", -15 - textWidth, 4)
			end
		end
	end
	local function RefreshMapShell(mode)
		if _G.WorldMapDetailFrame then
			WSkin:ApplyRetailSurface(_G.WorldMapDetailFrame, "body")
			_G.WorldMapDetailFrame:SetBackdropBorderColor(1, 1, 1, 0.12)
		end
		WSkin:SetRetailPageTitle(frame, nil, _G.WorldMapFrameTitle)
		StyleMapTypography()
		LayoutWindowControls(mode)
	end

	local function SmallSkin()
		local advanced = _G.WORLDMAP_SETTINGS and _G.WORLDMAP_SETTINGS.advanced
		RefreshMapShell(advanced and "small-advanced" or "small")
		if _G.WorldMapLevelDropDown and _G.WorldMapPositioningGuide then
			Point(_G.WorldMapLevelDropDown, "TOPRIGHT", _G.WorldMapPositioningGuide, "TOPRIGHT",
				advanced and -419 or -439, advanced and -24 or -38)
		end
	end

	local function LargeSkin()
		RefreshMapShell("large")
		if _G.WorldMapLevelDropDown and _G.WorldMapPositioningGuide then
			Point(_G.WorldMapLevelDropDown, "TOPRIGHT", _G.WorldMapPositioningGuide, "TOPRIGHT", -50, -35)
		end
	end

	local function QuestSkin()
		RefreshMapShell("quest")
		if _G.WorldMapLevelDropDown and _G.WorldMapPositioningGuide then
			Point(_G.WorldMapLevelDropDown, "TOPRIGHT", _G.WorldMapPositioningGuide, "TOPRIGHT", -50, -35)
		end
	end

	local function FixSkin()
		local settings = _G.WORLDMAP_SETTINGS
		if not settings then return end
		if settings.size == _G.WORLDMAP_FULLMAP_SIZE then
			LargeSkin()
		elseif settings.size == _G.WORLDMAP_QUESTLIST_SIZE then
			QuestSkin()
		else
			SmallSkin()
		end
	end

	frame:HookScript("OnShow", FixSkin)
	FixSkin()
	WSkin:SetUIPanelWindowInfo(frame, "width", 594)

	if type(_G.WorldMapFrame_SetQuestMapView) == "function" then
		hooksecurefunc("WorldMapFrame_SetQuestMapView", QuestSkin)
	end
	if type(_G.WorldMapFrame_SetFullMapView) == "function" then
		hooksecurefunc("WorldMapFrame_SetFullMapView", LargeSkin)
	end
	if type(_G.WorldMapFrame_SetMiniMode) == "function" then
		hooksecurefunc("WorldMapFrame_SetMiniMode", SmallSkin)
	end
	if type(_G.WorldMap_ToggleSizeDown) == "function" then
		hooksecurefunc("WorldMap_ToggleSizeDown", SmallSkin)
	end
	if type(_G.WorldMap_ToggleSizeUp) == "function" then
		hooksecurefunc("WorldMap_ToggleSizeUp", FixSkin)
	end
	if type(_G.WorldMapQuestShowObjectives_AdjustPosition) == "function" then
		hooksecurefunc("WorldMapQuestShowObjectives_AdjustPosition", function()
			local settings = _G.WORLDMAP_SETTINGS
			if settings and settings.size == _G.WORLDMAP_WINDOWED_SIZE then SmallSkin() end
		end)
	end
	if type(_G.ToggleMapFramerate) == "function" then hooksecurefunc("ToggleMapFramerate", FixSkin) end
	if type(_G.WorldMapFrame_ToggleAdvanced) == "function" then
		hooksecurefunc("WorldMapFrame_ToggleAdvanced", FixSkin)
	end
end, "worldmap")
