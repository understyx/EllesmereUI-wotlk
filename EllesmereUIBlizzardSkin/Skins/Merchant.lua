local WSkin = _G.EllesmereUIBlizzardSkin
local _G = _G

--Lua functions
local _G = _G
local unpack = unpack
local floor = math.floor
--WoW API / Variables
local GetBuybackItemInfo = GetBuybackItemInfo
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor
local GetMerchantNumItems = GetMerchantNumItems

local function ResetBorder(frame)
	frame:SetBackdropBorderColor(unpack(WSkin.Retail.colors.border))
end

-- Icon buttons keep their artwork; give them the retail button surface
-- and hover/pushed overlays instead of stripping them like text buttons.
local function StyleIconButton(button)
	if not button then return end
	if button.SetNormalTexture then button:SetNormalTexture("") end
	if button.SetPushedTexture then button:SetPushedTexture("") end
	if button.SetHighlightTexture then button:SetHighlightTexture("") end
	WSkin:ApplyRetailSurface(button, "button")
	WSkin:StyleButton(button, nil, nil, true)
end

local laying = false
local function LayoutMerchantTabs()
	local frame = _G.MerchantFrame
	local shell = frame and frame.backdrop
	if not shell or laying then return end
	laying = true
	local tabs = { _G.MerchantFrameTab1, _G.MerchantFrameTab2 }
	WSkin:LayoutRetailTabRow(tabs, shell)
	local selected = type(_G.PanelTemplates_GetSelectedTab) == "function"
		and _G.PanelTemplates_GetSelectedTab(frame) or frame.selectedTab or 1
	for i, tab in ipairs(tabs) do WSkin:UpdateRetailTab(tab, i == selected) end
	laying = false
end

-------------------------------------------------------------------------------
--  Show As List (EllesmereUIDB.merchantShowAsList)
--  Replaces the paged 10-slot grid with one scrolling list of every vendor
--  item. Rows are built from MerchantItemTemplate so the item button keeps
--  Blizzard's buy / split-stack / tooltip / buyback scripts; they only read
--  self:GetID() and the button fields we fill below.
--  3.3.5 has no reliable child clipping, so this is a faux scroll: a fixed
--  set of rows that fits the window, re-filled from the scroll offset.
-------------------------------------------------------------------------------
local LIST_ROW_SPACING = 4
local LIST_TOP = -54
local LIST_LEFT = 21
local LIST_RIGHT = -58           -- leaves room for the scrollbar
local LIST_BOTTOM_MERCHANT = 167 -- just above the buyback slot
local LIST_BOTTOM_BUYBACK = 104  -- above the money display
local listScroll
local listRows = {}

local function ListRowHeight()
	return (EllesmereUIDB and EllesmereUIDB.merchantListRowHeight) or 32
end

local function IsListMode()
	return listScroll and EllesmereUIDB and EllesmereUIDB.merchantShowAsList
end

-- Blizzard keeps calling Show() on the grid and pager; parking them under a
-- hidden holder keeps them invisible without touching Blizzard's code paths.
local function HideNativeMerchantGrid()
	local holder = CreateFrame("Frame")
	holder:Hide()
	for i = 1, 12 do
		local item = _G["MerchantItem"..i]
		if item then item:SetParent(holder) end
	end
	for _, ctrl in ipairs({ _G.MerchantPrevPageButton, _G.MerchantNextPageButton, _G.MerchantPageText }) do
		ctrl:SetParent(holder)
	end
end

local function LayoutListRow(row, index)
	local height = ListRowHeight()
	local iconSize = height - 6
	local frame = _G.MerchantFrame
	row:SetHeight(height)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_LEFT, LIST_TOP - (index - 1) * (height + LIST_ROW_SPACING))
	row:SetPoint("RIGHT", frame, "RIGHT", LIST_RIGHT, 0)

	row.iconBorder:ClearAllPoints()
	row.iconBorder:SetPoint("LEFT", row, "LEFT", 3, 0)
	row.iconBorder:SetWidth(iconSize)
	row.iconBorder:SetHeight(iconSize)
	row.icon:ClearAllPoints()
	row.icon:SetPoint("TOPLEFT", row.iconBorder, "TOPLEFT", 1, -1)
	row.icon:SetPoint("BOTTOMRIGHT", row.iconBorder, "BOTTOMRIGHT", -1, 1)
end

local function CreateListRow(index)
	local frame = _G.MerchantFrame
	local name = "EUI_MerchantListItem"..index
	local row = CreateFrame("Frame", name, frame, "MerchantItemTemplate")
	local button = _G[name.."ItemButton"]
	row.button = button
	row.name = _G[name.."Name"]
	row.money = _G[name.."MoneyFrame"]
	row.icon = _G[name.."ItemButtonIconTexture"]
	row.count = _G[name.."ItemButtonCount"]
	row.stock = _G[name.."ItemButtonStock"]

	WSkin:StripTextures(row)
	_G[name.."NameFrame"]:Hide()
	_G[name.."SlotTexture"]:Hide()
	_G[name.."AltCurrencyFrame"]:Hide()
	_G[name.."AltCurrencyFrame"].Show = function() end
	WSkin:UpdateRetailRow(row, false, false, index % 2 == 0)

	-- The whole row is the buy button. Frame levels get flattened whenever
	-- the window is raised, so nothing may rely on sitting above the button:
	-- money coin buttons stop taking the mouse, the icon border is a texture.
	button:ClearAllPoints()
	button:SetAllPoints(row)
	button:SetNormalTexture("")
	button:SetPushedTexture("")
	button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	local hl = button:GetHighlightTexture()
	hl:SetVertexColor(1, 1, 1, 0.08)
	hl:SetAllPoints(row)
	for _, coin in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
		local b = _G[row.money:GetName()..coin]
		if b then b:EnableMouse(false) end
	end
	row.money:EnableMouse(false)

	-- Icon lives on BORDER; the quality border sits under it on BACKGROUND.
	row.iconBorder = button:CreateTexture(nil, "BACKGROUND")
	row.iconBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
	row.icon:SetDrawLayer("BORDER")
	row.icon:SetTexCoord(unpack(WSkin.TexCoords or {0.08, 0.92, 0.08, 0.92}))

	row.count:ClearAllPoints()
	row.count:SetPoint("BOTTOMRIGHT", row.iconBorder, "BOTTOMRIGHT", -1, 1)
	row.stock:ClearAllPoints()
	row.stock:SetPoint("TOPLEFT", row.iconBorder, "TOPLEFT", 1, -1)

	row.altCost = button:CreateFontString(nil, "OVERLAY")
	WSkin:ApplyRetailTypography(row.altCost, "secondary")
	row.altCost:SetPoint("RIGHT", row, "RIGHT", -6, 0)

	WSkin:ApplyRetailTypography(row.name, "row")
	row.name:SetJustifyH("LEFT")
	row.name:SetHeight(14)

	listRows[index] = row
	LayoutListRow(row, index)
	return row
end

-- Alternate costs (honor, arena points, tokens) rendered as "value |Ticon|t".
local function AltCostText(index)
	local honor, arena, itemCount = GetMerchantItemCostInfo(index)
	local parts = {}
	if honor and honor > 0 then
		local faction = UnitFactionGroup("player") or "Alliance"
		parts[#parts + 1] = honor.." |TInterface\\PVPFrame\\PVP-Currency-"..faction..":14:14|t"
	end
	if arena and arena > 0 then
		parts[#parts + 1] = arena.." |TInterface\\PVPFrame\\PVP-ArenaPoints-Icon:14:14|t"
	end
	for i = 1, (itemCount or 0) do
		local texture, value = GetMerchantItemCostItem(index, i)
		if texture then
			parts[#parts + 1] = (value or 0).." |T"..texture..":14:14|t"
		end
	end
	return table.concat(parts, "  ")
end

local function FillListRow(row, index, isBuyback)
	local button = row.button
	local name, texture, price, quantity, numAvailable, isUsable, extendedCost, link
	if isBuyback then
		name, texture, price, quantity, numAvailable, isUsable = GetBuybackItemInfo(index)
		link = GetBuybackItemLink and GetBuybackItemLink(index)
	else
		name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(index)
		link = GetMerchantItemLink(index)
	end

	button:SetID(index)
	button.link = link
	button.texture = texture
	button.hasItem = true
	button.price = (not extendedCost or (price or 0) > 0) and price or nil
	button.extendedCost = extendedCost or nil

	row.icon:SetTexture(texture)
	row.icon:Show()
	SetItemButtonCount(button, quantity)
	SetItemButtonStock(button, numAvailable)

	local quality = select(3, GetItemInfo(link or name or ""))
	if quality then
		local r, g, b = GetItemQualityColor(quality)
		row.name:SetTextColor(r, g, b)
		row.iconBorder:SetVertexColor(r, g, b, 1)
	else
		row.name:SetTextColor(1, 1, 1)
		row.iconBorder:SetVertexColor(unpack(WSkin.Retail.colors.border))
	end
	row.name:SetText(name)

	-- Cost: alt currency on the far right, gold to its left.
	local alt = extendedCost and AltCostText(index) or ""
	row.altCost:SetText(alt)
	row.money:ClearAllPoints()
	local costAnchor = row
	if alt ~= "" then
		row.altCost:Show()
		costAnchor = row.altCost
	else
		row.altCost:Hide()
	end
	if price and price > 0 then
		MoneyFrame_Update(row.money:GetName(), price)
		if costAnchor == row then
			row.money:SetPoint("RIGHT", row, "RIGHT", 4, 0)
		else
			row.money:SetPoint("RIGHT", costAnchor, "LEFT", 6, 0)
		end
		row.money:Show()
		costAnchor = row.money
	else
		row.money:Hide()
	end

	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.iconBorder, "RIGHT", 8, 0)
	if costAnchor == row then
		row.name:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	else
		row.name:SetPoint("RIGHT", costAnchor, "LEFT", -8, 0)
	end

	-- Same tints Blizzard applies to the grid tiles.
	if not isBuyback and numAvailable == 0 then
		if isUsable then row.icon:SetVertexColor(0.5, 0.5, 0.5) else row.icon:SetVertexColor(0.5, 0, 0) end
	elseif not isUsable then
		row.icon:SetVertexColor(1, 0, 0)
	else
		row.icon:SetVertexColor(1, 1, 1)
	end
end

local function UpdateMerchantList()
	if not IsListMode() then return end
	local frame = _G.MerchantFrame
	local isBuyback = frame.selectedTab == 2

	-- Fixed geometry: no measuring of the (now hidden) grid frames.
	local bottom = isBuyback and LIST_BOTTOM_BUYBACK or LIST_BOTTOM_MERCHANT
	listScroll:ClearAllPoints()
	listScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_LEFT, LIST_TOP)
	listScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", LIST_RIGHT, bottom)

	local step = ListRowHeight() + LIST_ROW_SPACING
	local available = frame:GetHeight() + LIST_TOP - bottom
	local numVisible = math.max(1, math.floor((available + LIST_ROW_SPACING) / step))
	local numItems = isBuyback and GetNumBuybackItems() or GetMerchantNumItems()

	FauxScrollFrame_Update(listScroll, numItems, numVisible, step)
	local offset = FauxScrollFrame_GetOffset(listScroll)

	for i = 1, numVisible do
		local row = listRows[i] or CreateListRow(i)
		local index = offset + i
		if index <= numItems then
			FillListRow(row, index, isBuyback)
			row:Show()
		else
			row.button.hasItem = nil
			row:Hide()
		end
	end
	for i = numVisible + 1, #listRows do
		listRows[i].button.hasItem = nil
		listRows[i]:Hide()
	end
end

local function SetupMerchantList()
	if listScroll then return end
	local frame = _G.MerchantFrame
	HideNativeMerchantGrid()

	listScroll = CreateFrame("ScrollFrame", "EUI_MerchantListScrollFrame", frame, "FauxScrollFrameTemplate")
	listScroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ListRowHeight() + LIST_ROW_SPACING, UpdateMerchantList)
	end)
	WSkin:HandleScrollBar(_G.EUI_MerchantListScrollFrameScrollBar)

	-- Wheel anywhere on the window scrolls the list instead of paging.
	frame:SetScript("OnMouseWheel", function(_, delta)
		local bar = _G.EUI_MerchantListScrollFrameScrollBar
		bar:SetValue(bar:GetValue() - delta * (ListRowHeight() + LIST_ROW_SPACING))
	end)

	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", UpdateMerchantList)
	hooksecurefunc("MerchantFrame_UpdateBuybackInfo", UpdateMerchantList)
	frame:HookScript("OnShow", function()
		_G.EUI_MerchantListScrollFrameScrollBar:SetValue(0)
	end)
	-- Tab switches reuse the scroll position otherwise.
	hooksecurefunc("PanelTemplates_SetTab", function(owner)
		if owner == frame then _G.EUI_MerchantListScrollFrameScrollBar:SetValue(0) end
	end)
end

-- Options slider entry point.
if EllesmereUI then
	EllesmereUI._Merchant_RefreshRowHeight = function()
		if not IsListMode() then return end
		for i, row in ipairs(listRows) do LayoutListRow(row, i) end
		if _G.MerchantFrame:IsVisible() then UpdateMerchantList() end
	end
end

WSkin:AddCallback("Skin_Merchant", function()
	if not WSkin:IsSkinEnabled("merchant") then return end

	local MerchantFrame = _G.MerchantFrame
	WSkin:SkinRetailWindow(MerchantFrame, {
		closeButton = MerchantFrameCloseButton,
		titleRegion = MerchantNameText,
	})

	WSkin:SetUIPanelWindowInfo(MerchantFrame, "width")

	MerchantFrame:EnableMouseWheel(true)
	MerchantFrame:SetScript("OnMouseWheel", function(_, value)
		if value > 0 then
			if MerchantPrevPageButton:IsShown() and MerchantPrevPageButton:IsEnabled() == 1 then
				MerchantPrevPageButton_OnClick()
			end
		else
			if MerchantNextPageButton:IsShown() and MerchantNextPageButton:IsEnabled() == 1 then
				MerchantNextPageButton_OnClick()
			end
		end
	end)


	local function skinMerchantButton(buttonName, buyback)
		local button = _G[buttonName]
		local itemButton = _G[buttonName.."ItemButton"]
		local icon = _G[buttonName.."ItemButtonIconTexture"]
		local name = _G[buttonName.."Name"]
		local nameFrame = _G[buttonName.."NameFrame"]
		local money = _G[buttonName.."MoneyFrame"]
		local slot = _G[buttonName.."SlotTexture"]

		WSkin:StripTextures(button, true)
		WSkin:CreateBackdrop(button, "Default")
		WSkin:UpdateRetailRow(button.backdrop, false)
		WSkin:Point(button.backdrop, "TOPLEFT", -2, 2)

		if buyback then
			WSkin:Point(button.backdrop, "BOTTOMRIGHT", 4, -13)
		else
			WSkin:Point(button.backdrop, "BOTTOMRIGHT", 4, -6)
		end

		WSkin:StripTextures(itemButton)
		WSkin:StyleButton(itemButton)
		WSkin:ApplyRetailSurface(itemButton, "input")
		WSkin:Size(itemButton, 40)
		WSkin:Point(itemButton, "TOPLEFT", 4, -4)

		icon:SetTexCoord(unpack(WSkin.TexCoords or {0.08, 0.92, 0.08, 0.92}))
		WSkin:SetInside(icon)

		WSkin:Point(name, "LEFT", slot, "RIGHT", -4, 5)
		WSkin:Point(nameFrame, "LEFT", slot, "RIGHT", -6, -17)

		money:ClearAllPoints()
		WSkin:Point(money, "BOTTOMLEFT", itemButton, "BOTTOMRIGHT", 3, 0)

		if not buyback then
			for j = 1, 2 do
				local currencyItem = _G[buttonName.."AltCurrencyFrameItem"..j]
				local currencyIcon = _G[buttonName.."AltCurrencyFrameItem"..j.."Texture"]

				currencyIcon.backdrop = CreateFrame("Frame", nil, currencyItem)
				WSkin:ApplyRetailSurface(currencyIcon.backdrop, "input")
				currencyIcon.backdrop:SetFrameLevel(currencyItem:GetFrameLevel())
				WSkin:SetOutside(currencyIcon.backdrop, currencyIcon)

				currencyIcon:SetTexCoord(unpack(WSkin.TexCoords or {0.08, 0.92, 0.08, 0.92}))
				currencyIcon:SetParent(currencyIcon.backdrop)
			end
		end
	end

	for i = 1, 12 do
		skinMerchantButton("MerchantItem"..i)

		if i % 2 == 0 then
			WSkin:Point(_G["MerchantItem"..i], "TOPLEFT", _G["MerchantItem"..i-1], "TOPRIGHT", 13, 0)
		end
	end

	skinMerchantButton("MerchantBuyBackItem", true)

	WSkin:HandleNextPrevButton(MerchantNextPageButton, nil, nil, true)
	WSkin:HandleNextPrevButton(MerchantPrevPageButton, nil, nil, true)

	StyleIconButton(MerchantRepairItemButton)
	-- texWidth, texHeight, cropWidth, cropHeight, offsetX, offsetY = 128, 64, 26, 26, 5, 6
	MerchantRepairItemButton:GetRegions():SetTexCoord(0.0390625, 0.2421875, 0.09375, 0.5)
	WSkin:SetInside((MerchantRepairItemButton:GetRegions()))

	StyleIconButton(MerchantRepairAllButton)
	-- texWidth, texHeight, cropWidth, cropHeight, offsetX, offsetY = 128, 64, 26, 26, 41, 6
	MerchantRepairAllIcon:SetTexCoord(0.3203125, 0.5234375, 0.09375, 0.5)
	WSkin:SetInside(MerchantRepairAllIcon)

	StyleIconButton(MerchantGuildBankRepairButton)
	-- texWidth, texHeight, cropWidth, cropHeight, offsetX, offsetY = 128, 64, 26, 26, 77, 6
	MerchantGuildBankRepairButtonIcon:SetTexCoord(0.6015625, 0.8046875, 0.09375, 0.5)
	WSkin:SetInside(MerchantGuildBankRepairButtonIcon)

	for _, tab in ipairs({ MerchantFrameTab1, MerchantFrameTab2 }) do
		WSkin:StyleRetailTab(tab)
		tab:SetHitRectInsets(0, 0, 0, 0)
		tab:HookScript("OnShow", LayoutMerchantTabs)
	end
	hooksecurefunc("PanelTemplates_SetTab", function(owner)
		if owner == MerchantFrame then LayoutMerchantTabs() end
	end)
	hooksecurefunc("PanelTemplates_TabResize", function(tab)
		if tab == MerchantFrameTab1 or tab == MerchantFrameTab2 then LayoutMerchantTabs() end
	end)
	MerchantFrame:HookScript("OnShow", LayoutMerchantTabs)

	WSkin:ApplyRetailTypography(MerchantPageText, "secondary")
	WSkin:ApplyRetailTypography(MerchantRepairText, "secondary")

	MerchantItem1:SetPoint("TOPLEFT", 21, -54)

	WSkin:Point(MerchantPrevPageButton, "CENTER", MerchantFrame, "BOTTOMLEFT", 37, 172)
	WSkin:Point(MerchantNextPageButton, "CENTER", MerchantFrame, "BOTTOMLEFT", 324, 172)

	WSkin:Point(MerchantPageText, "BOTTOM", -14, 166)

	WSkin:Point(MerchantBuyBackItem, "TOPLEFT", MerchantItem10, "BOTTOMLEFT", 0, -39)

	WSkin:Point(MerchantGuildBankRepairButton, "LEFT", MerchantRepairAllButton, "RIGHT", 5, 0)
	WSkin:Point(MerchantRepairItemButton, "RIGHT", MerchantRepairAllButton, "LEFT", -5, 0)
	MerchantRepairItemButton.SetPoint = function() end

	WSkin:Point(MerchantMoneyFrame, "BOTTOMRIGHT", -30, 86)

	LayoutMerchantTabs()

	hooksecurefunc(MerchantRepairAllButton, "Show", function(self)
		-- CanMerchantRepair && CanGuildBankRepair
		if floor(self:GetWidth() + 0.5) == 32 then
			MerchantRepairText:SetPoint("CENTER", MerchantFrame, "BOTTOMLEFT", 94, 151)
			WSkin:Point(MerchantRepairAllButton, "BOTTOMRIGHT", MerchantFrame, "BOTTOMLEFT", 111, 105)
		else
			MerchantRepairText:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 26, 125)
			WSkin:Point(MerchantRepairAllButton, "BOTTOMRIGHT", MerchantFrame, "BOTTOMLEFT", 172, 113)
		end
	end)

	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
		local numMerchantItems = GetMerchantNumItems()
		local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE
		local _, button, name, quality

		for i = 1, BUYBACK_ITEMS_PER_PAGE do
			index = index + 1

			if index <= numMerchantItems then
				button = _G["MerchantItem"..i.."ItemButton"]
				name = _G["MerchantItem"..i.."Name"]

				if button.link then
					_, _, quality = GetItemInfo(button.link)

					if quality then
						local r, g, b = GetItemQualityColor(quality)
						button:SetBackdropBorderColor(r, g, b)
						name:SetTextColor(r, g, b)
					else
						ResetBorder(button)
						name:SetTextColor(1, 1, 1)
					end
				else
					ResetBorder(button)
					name:SetTextColor(1, 1, 1)
				end
			end

			local itemName = GetBuybackItemInfo(GetNumBuybackItems())
			if itemName then
				_, _, quality = GetItemInfo(itemName)

				if quality then
					local r, g, b = GetItemQualityColor(quality)
					MerchantBuyBackItemItemButton:SetBackdropBorderColor(r, g, b)
					MerchantBuyBackItemName:SetTextColor(r, g, b)
				else
					ResetBorder(MerchantBuyBackItemItemButton)
					MerchantBuyBackItemName:SetTextColor(1, 1, 1)
				end
			else
				ResetBorder(MerchantBuyBackItemItemButton)
			end
		end

		MerchantItem3:SetPoint("TOPLEFT", "MerchantItem1", "BOTTOMLEFT", 0, -11)
		MerchantItem5:SetPoint("TOPLEFT", "MerchantItem3", "BOTTOMLEFT", 0, -11)
		MerchantItem7:SetPoint("TOPLEFT", "MerchantItem5", "BOTTOMLEFT", 0, -11)
		MerchantItem9:SetPoint("TOPLEFT", "MerchantItem7", "BOTTOMLEFT", 0, -11)
	end)

	hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
		local numBuybackItems = GetNumBuybackItems()
		local _, button, name, quality

		for i = 1, BUYBACK_ITEMS_PER_PAGE do
			if i <= numBuybackItems then
				local itemName = GetBuybackItemInfo(i)

				if itemName then
					button = _G["MerchantItem"..i.."ItemButton"]
					name = _G["MerchantItem"..i.."Name"]
					_, _, quality = GetItemInfo(itemName)

					if quality then
						local r, g, b = GetItemQualityColor(quality)
						button:SetBackdropBorderColor(r, g, b)
						name:SetTextColor(r, g, b)
					else
						ResetBorder(button)
						name:SetTextColor(1, 1, 1)
					end
				end
			end
		end

		MerchantItem3:SetPoint("TOPLEFT", "MerchantItem1", "BOTTOMLEFT", 0, -15)
		MerchantItem5:SetPoint("TOPLEFT", "MerchantItem3", "BOTTOMLEFT", 0, -15)
		MerchantItem7:SetPoint("TOPLEFT", "MerchantItem5", "BOTTOMLEFT", 0, -15)
		MerchantItem9:SetPoint("TOPLEFT", "MerchantItem7", "BOTTOMLEFT", 0, -15)
	end)

	if EllesmereUIDB and EllesmereUIDB.merchantShowAsList then
		SetupMerchantList()
	end
end, "merchant")
