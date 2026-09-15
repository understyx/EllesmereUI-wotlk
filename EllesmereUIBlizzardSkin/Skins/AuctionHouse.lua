local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local ipairs, pairs, select, unpack = ipairs, pairs, select, unpack
local CreateFrame = CreateFrame

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

local function SkinItem(button, icon)
	if not button then return end
	local texture = icon and icon.GetTexture and icon:GetTexture()
	WSkin:StripTextures(button)
	WSkin:SetTemplate(button, "Default", true)
	WSkin:StyleButton(button)
	if icon then
		if texture then icon:SetTexture(texture) end
		icon:SetTexCoord(unpack(WSkin.TexCoords))
		WSkin:SetInside(icon, button)
	end
end

local function CreatePanel(parent, key, topLeftX, topLeftY, bottomRightX, bottomRightY)
	if not parent then return end
	local panel = parent[key]
	if not panel then
		panel = CreateFrame("Frame", nil, parent)
		parent[key] = panel
		WSkin:SetTemplate(panel, "Transparent")
		if parent.GetFrameLevel then panel:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1)) end
	end
	Point(panel, "TOPLEFT", parent, "TOPLEFT", topLeftX, topLeftY)
	Point(panel, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", bottomRightX, bottomRightY)
	return panel
end

local function SkinAuctionHouse()
	if not WSkin:IsSkinEnabled("auctionhouse") or not _G.AuctionFrame then return end

	local frame = _G.AuctionFrame
	WSkin:StripTextures(frame, true)
	WSkin:CreateBackdrop(frame, "Transparent")
	if not frame.backdrop then return end
	frame.backdrop:ClearAllPoints()
	Point(frame.backdrop, "TOPLEFT", frame, "TOPLEFT", 11, 0)
	Point(frame.backdrop, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 23)
	WSkin:SetUIPanelWindowInfo(frame, "xoffset", 0, nil, true)
	WSkin:SetUIPanelWindowInfo(frame, "yoffset", -12, nil, true)
	WSkin:SetUIPanelWindowInfo(frame, "width")
	WSkin:SetBackdropHitRect(frame)
	WSkin:HandleCloseButton(_G.AuctionFrameCloseButton, frame.backdrop)

	Each({
		"BrowseSearchButton", "BrowseResetButton", "BrowseBidButton", "BrowseBuyoutButton", "BrowseCloseButton",
		"BidBidButton", "BidBuyoutButton", "BidCloseButton", "AuctionsCreateAuctionButton",
		"AuctionsCancelAuctionButton", "AuctionsStackSizeMaxButton", "AuctionsNumStacksMaxButton",
		"AuctionsCloseButton",
	}, WSkin.HandleButton, true)

	WSkin:HandleCheckBox(_G.IsUsableCheckButton)
	WSkin:HandleCheckBox(_G.ShowOnPlayerCheckButton)
	for _, name in ipairs({
		"BrowseName", "BrowseMinLevel", "BrowseMaxLevel",
		"BrowseBidPriceGold", "BrowseBidPriceSilver", "BrowseBidPriceCopper",
		"BidBidPriceGold", "BidBidPriceSilver", "BidBidPriceCopper",
		"AuctionsStackSizeEntry", "AuctionsNumStacksEntry",
		"StartPriceGold", "StartPriceSilver", "StartPriceCopper",
		"BuyoutPriceGold", "BuyoutPriceSilver", "BuyoutPriceCopper",
	}) do
		local editBox = _G[name]
		WSkin:HandleEditBox(editBox)
		if editBox and editBox.SetTextInsets then editBox:SetTextInsets(1, 1, -1, 1) end
	end

	for _, name in ipairs({
		"BrowseQualitySort", "BrowseLevelSort", "BrowseDurationSort", "BrowseHighBidderSort", "BrowseCurrentBidSort",
		"BidQualitySort", "BidLevelSort", "BidDurationSort", "BidBuyoutSort", "BidStatusSort", "BidBidSort",
		"AuctionsQualitySort", "AuctionsDurationSort", "AuctionsHighBidderSort", "AuctionsBidSort",
	}) do
		local tab = _G[name]
		if tab then
			WSkin:StripTextures(tab)
			if tab.SetNormalTexture then tab:SetNormalTexture("Interface\\Buttons\\UI-SortArrow") end
			WSkin:StyleButton(tab)
		end
	end

	local tabCount = Count(frame.numTabs, 3)
	for i = 1, tabCount do ClearPoints(_G["AuctionFrameTab" .. i]) end
	for i = 1, tabCount do
		local tab = _G["AuctionFrameTab" .. i]
		WSkin:HandleTab(tab)
		if i == 1 then
			Point(tab, "TOPLEFT", frame, "BOTTOMLEFT", 12, 25)
		else
			Point(tab, "TOPLEFT", _G["AuctionFrameTab" .. (i - 1)], "TOPRIGHT", -15, 0)
		end
	end

	for i = 1, Count(_G.NUM_FILTERS_TO_DISPLAY, 15) do
		local filter = _G["AuctionFilterButton" .. i]
		WSkin:StripTextures(filter)
		WSkin:HandleButtonHighlight(filter)
	end

	local rows = {
		Browse = Count(_G.NUM_BROWSE_TO_DISPLAY, 8),
		Auctions = Count(_G.NUM_AUCTIONS_TO_DISPLAY, 9),
		Bid = Count(_G.NUM_BIDS_TO_DISPLAY, 9),
	}
	for prefix, count in pairs(rows) do
		for i = 1, count do
			local row = _G[prefix .. "Button" .. i]
			local item = _G[prefix .. "Button" .. i .. "Item"]
			local icon = _G[prefix .. "Button" .. i .. "ItemIconTexture"]
			WSkin:StripTextures(row)
			WSkin:HandleButtonHighlight(row)
			SkinItem(item, icon)
			Point(item, "TOPLEFT", row, "TOPLEFT", 0, -1)
			if item then WSkin:Size(item, 34) end
		end
	end

	CreatePanel(_G.AuctionFrameBrowse, "LeftBackground", 19, -86, -574, 60)
	CreatePanel(_G.AuctionFrameBrowse, "RightBackground", 187, -86, 66, 60)
	CreatePanel(_G.AuctionFrameBid, "Background", 19, -49, 66, 60)
	CreatePanel(_G.AuctionFrameAuctions, "LeftBackground", 19, -49, -546, 60)
	CreatePanel(_G.AuctionFrameAuctions, "RightBackground", 215, -49, 66, 60)

	Point(_G.AuctionFrameMoneyFrame, "BOTTOMRIGHT", frame, "BOTTOMLEFT", 181, 37)
	if _G.BrowseTitle and _G.BrowseTitle.ClearAllPoints then _G.BrowseTitle:ClearAllPoints() end
	Point(_G.BrowseTitle, "TOP", frame, "TOP", 0, -5)
	Point(_G.BrowseNameText, "TOPLEFT", _G.AuctionFrameBrowse, "TOPLEFT", 25, -19)
	if _G.BrowseName then WSkin:Size(_G.BrowseName, 163, 18) end
	Point(_G.BrowseName, "TOPLEFT", _G.BrowseNameText, "BOTTOMLEFT", -5, -4)
	Point(_G.BrowseResetButton, "TOPLEFT", _G.AuctionFrameBrowse, "TOPLEFT", 104, -59)
	Point(_G.BrowseLevelText, "BOTTOMLEFT", _G.AuctionFrameBrowse, "TOPLEFT", 233, -31)
	Point(_G.BrowseMinLevel, "TOPLEFT", _G.BrowseLevelText, "BOTTOMLEFT", 0, -6)
	Point(_G.BrowseLevelHyphen, "LEFT", _G.BrowseMinLevel, "RIGHT", 2, 1)
	Point(_G.BrowseMaxLevel, "LEFT", _G.BrowseMinLevel, "RIGHT", 12, 0)
	WSkin:HandleDropDownBox(_G.BrowseDropDown, 155)
	Point(_G.BrowseSearchButton, "TOPRIGHT", _G.AuctionFrameBrowse, "TOPRIGHT", 15, -34)

	WSkin:HandleNextPrevButton(_G.BrowsePrevPageButton, "left", nil, true)
	WSkin:HandleNextPrevButton(_G.BrowseNextPageButton, "right", nil, true)
	if _G.BrowsePrevPageButton then WSkin:Size(_G.BrowsePrevPageButton, 32) end
	if _G.BrowseNextPageButton then WSkin:Size(_G.BrowseNextPageButton, 32) end
	Point(_G.BrowsePrevPageButton, "TOPLEFT", _G.AuctionFrameBrowse, "TOPLEFT", 636, -28)
	Point(_G.BrowseNextPageButton, "TOPRIGHT", _G.AuctionFrameBrowse, "TOPRIGHT", 72, -28)

	WSkin:StripTextures(_G.BrowseFilterScrollFrame)
	if _G.BrowseFilterScrollFrame then WSkin:Size(_G.BrowseFilterScrollFrame, 144, 301) end
	Point(_G.BrowseFilterScrollFrame, "TOPRIGHT", _G.AuctionFrameBrowse, "TOPLEFT", 163, -86)
	Point(_G.AuctionFilterButton1, "TOPLEFT", _G.AuctionFrameBrowse, "TOPLEFT", 23, -87)
	WSkin:HandleScrollBar(_G.BrowseFilterScrollFrameScrollBar)
	Point(_G.BrowseFilterScrollFrameScrollBar, "TOPLEFT", _G.BrowseFilterScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.BrowseFilterScrollFrameScrollBar, "BOTTOMLEFT", _G.BrowseFilterScrollFrame, "BOTTOMRIGHT", 3, 19)

	WSkin:StripTextures(_G.BrowseScrollFrame)
	if _G.BrowseScrollFrame then WSkin:Size(_G.BrowseScrollFrame, 616, 301) end
	Point(_G.BrowseScrollFrame, "TOPRIGHT", _G.AuctionFrameBrowse, "TOPRIGHT", 45, -86)
	Point(_G.BrowseButton1, "TOPLEFT", _G.AuctionFrameBrowse, "TOPLEFT", 191, -89)
	WSkin:HandleScrollBar(_G.BrowseScrollFrameScrollBar)
	Point(_G.BrowseScrollFrameScrollBar, "TOPLEFT", _G.BrowseScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.BrowseScrollFrameScrollBar, "BOTTOMLEFT", _G.BrowseScrollFrame, "BOTTOMRIGHT", 3, 19)
	ClearPoints(_G.BrowseBidButton, _G.BrowseBuyoutButton, _G.BrowseCloseButton)
	Point(_G.BrowseCloseButton, "BOTTOMRIGHT", _G.AuctionFrameBrowse, "BOTTOMRIGHT", 66, 31)
	Point(_G.BrowseBuyoutButton, "RIGHT", _G.BrowseCloseButton, "LEFT", -5, 0)
	Point(_G.BrowseBidButton, "RIGHT", _G.BrowseBuyoutButton, "LEFT", -5, 0)

	if _G.BidTitle and _G.BidTitle.ClearAllPoints then _G.BidTitle:ClearAllPoints() end
	Point(_G.BidTitle, "TOP", frame, "TOP", 0, -5)
	WSkin:StripTextures(_G.BidScrollFrame)
	if _G.BidScrollFrame then WSkin:Size(_G.BidScrollFrame, 784, 338) end
	Point(_G.BidScrollFrame, "TOPRIGHT", _G.AuctionFrameBid, "TOPRIGHT", 45, -49)
	Point(_G.BidButton1, "TOPLEFT", _G.AuctionFrameBid, "TOPLEFT", 23, -52)
	WSkin:HandleScrollBar(_G.BidScrollFrameScrollBar)
	Point(_G.BidScrollFrameScrollBar, "TOPLEFT", _G.BidScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.BidScrollFrameScrollBar, "BOTTOMLEFT", _G.BidScrollFrame, "BOTTOMRIGHT", 3, 19)
	ClearPoints(_G.BidBidButton, _G.BidBuyoutButton, _G.BidCloseButton)
	Point(_G.BidCloseButton, "BOTTOMRIGHT", _G.AuctionFrameBid, "BOTTOMRIGHT", 66, 31)
	Point(_G.BidBuyoutButton, "RIGHT", _G.BidCloseButton, "LEFT", -5, 0)
	Point(_G.BidBidButton, "RIGHT", _G.BidBuyoutButton, "LEFT", -5, 0)

	if _G.AuctionsTitle and _G.AuctionsTitle.ClearAllPoints then _G.AuctionsTitle:ClearAllPoints() end
	Point(_G.AuctionsTitle, "TOP", frame, "TOP", 0, -5)
	if _G.AuctionsBlockFrame then WSkin:Size(_G.AuctionsBlockFrame, 191, 336) end
	Point(_G.AuctionsBlockFrame, "TOPLEFT", _G.AuctionFrameAuctions, "TOPLEFT", 20, -50)
	SkinItem(_G.AuctionsItemButton, _G.AuctionsItemButton and _G.AuctionsItemButton:GetNormalTexture())
	Point(_G.AuctionsItemButton, "TOPLEFT", _G.AuctionFrameAuctions, "TOPLEFT", 30, -71)
	WSkin:HandleDropDownBox(_G.PriceDropDown)
	WSkin:HandleDropDownBox(_G.DurationDropDown)
	WSkin:StripTextures(_G.AuctionsScrollFrame)
	if _G.AuctionsScrollFrame then WSkin:Size(_G.AuctionsScrollFrame, 588, 338) end
	Point(_G.AuctionsScrollFrame, "TOPRIGHT", _G.AuctionFrameAuctions, "TOPRIGHT", 45, -49)
	Point(_G.AuctionsButton1, "TOPLEFT", _G.AuctionFrameAuctions, "TOPLEFT", 219, -52)
	WSkin:HandleScrollBar(_G.AuctionsScrollFrameScrollBar)
	Point(_G.AuctionsScrollFrameScrollBar, "TOPLEFT", _G.AuctionsScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.AuctionsScrollFrameScrollBar, "BOTTOMLEFT", _G.AuctionsScrollFrame, "BOTTOMRIGHT", 3, 19)
	ClearPoints(_G.AuctionsCancelAuctionButton, _G.AuctionsCloseButton)
	Point(_G.AuctionsCloseButton, "BOTTOMRIGHT", _G.AuctionFrameAuctions, "BOTTOMRIGHT", 66, 31)
	Point(_G.AuctionsCancelAuctionButton, "RIGHT", _G.AuctionsCloseButton, "LEFT", -5, 0)

	if _G.AuctionDressUpFrame then
		WSkin:StripTextures(_G.AuctionDressUpFrame)
		WSkin:SetTemplate(_G.AuctionDressUpFrame, "Transparent")
		WSkin:HandleCloseButton(_G.AuctionDressUpFrameCloseButton, _G.AuctionDressUpFrame)
		WSkin:CreateBackdrop(_G.AuctionDressUpModel, "Default")
		WSkin:HandleRotateButton(_G.AuctionDressUpModelRotateLeftButton)
		WSkin:HandleRotateButton(_G.AuctionDressUpModelRotateRightButton)
		WSkin:HandleButton(_G.AuctionDressUpFrameResetButton)
		WSkin:Size(_G.AuctionDressUpFrame, 189, 401)
		Point(_G.AuctionDressUpFrame, "TOPLEFT", frame, "TOPRIGHT", -1, 0)
		if _G.AuctionDressUpModel then WSkin:Size(_G.AuctionDressUpModel, 171, 365) end
		Point(_G.AuctionDressUpModel, "BOTTOM", _G.AuctionDressUpFrame, "BOTTOM", 0, 9)
	end

	if _G.AuctionProgressFrame then
		WSkin:StripTextures(_G.AuctionProgressFrame)
		WSkin:SetTemplate(_G.AuctionProgressFrame, "Transparent")
		WSkin:HandleStatusBar(_G.AuctionProgressBar, { 1, 0.7, 0 })
		if _G.AuctionProgressBar then WSkin:Size(_G.AuctionProgressBar, 190, 18) end
		Point(_G.AuctionProgressBar, "CENTER", _G.AuctionProgressFrame, "CENTER", 5, 0)
		WSkin:HandleCloseButton(_G.AuctionProgressFrameCancelButton)
		Point(_G.AuctionProgressFrameCancelButton, "LEFT", _G.AuctionProgressBar, "RIGHT", 8, 0)
		if _G.AuctionProgressBarIcon then
			WSkin:CreateBackdrop(_G.AuctionProgressBarIcon, "Default")
			WSkin:Size(_G.AuctionProgressBarIcon, 38)
			Point(_G.AuctionProgressBarIcon, "RIGHT", _G.AuctionProgressBar, "LEFT", -9, 0)
			_G.AuctionProgressBarIcon:SetTexCoord(unpack(WSkin.TexCoords))
		end
	end
end

WSkin:AddCallbackForAddon("Blizzard_AuctionUI", "Skin_AuctionHouse", SkinAuctionHouse, "auctionhouse")
