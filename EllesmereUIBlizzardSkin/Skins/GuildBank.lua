local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local select, unpack = select, unpack
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

local function SetQualityBorder(button, quality)
	local target = button and (button.backdrop or button)
	if not target or not target.SetBackdropBorderColor then return end
	if quality and quality > 1 and GetItemQualityColor then
		target:SetBackdropBorderColor(GetItemQualityColor(quality))
	else
		target:SetBackdropBorderColor(0.2, 0.2, 0.2)
	end
end

local function SkinGuildBankItem(button, icon)
	if not button then return end
	local texture = icon and icon.GetTexture and icon:GetTexture()
	WSkin:StripTextures(button)
	WSkin:SetTemplate(button, "Default", true)
	WSkin:StyleButton(button)
	if icon then
		if texture then icon:SetTexture(texture) end
		WSkin:SetInside(icon, button)
		icon:SetTexCoord(unpack(WSkin.TexCoords))
		if icon.SetDrawLayer then icon:SetDrawLayer("ARTWORK") end
	end
end

local function SkinGuildBank()
	if not WSkin:IsSkinEnabled("guild") or not _G.GuildBankFrame then return end

	local frame = _G.GuildBankFrame
	WSkin:Width(frame, 639)
	WSkin:StripTextures(frame, true)
	WSkin:CreateBackdrop(frame, "Transparent")
	if not frame.backdrop then return end
	frame.backdrop:ClearAllPoints()
	Point(frame.backdrop, "TOPLEFT", frame, "TOPLEFT", 11, -12)
	Point(frame.backdrop, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 8)
	WSkin:SetUIPanelWindowInfo(frame, "width", nil, 35)
	WSkin:SetBackdropHitRect(frame)

	if not frame.inset then
		frame.inset = CreateFrame("Frame", nil, frame)
		WSkin:SetTemplate(frame.inset, "Default")
		Point(frame.inset, "TOPLEFT", frame, "TOPLEFT", 19, -64)
		Point(frame.inset, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 62)
	end

	WSkin:StripTextures(_G.GuildBankEmblemFrame, true)
	local close = _G.GuildBankFrameCloseButton
	if not close and frame.GetChildren then close = select(13, frame:GetChildren()) end
	WSkin:HandleCloseButton(close, frame.backdrop)

	Each({
		"GuildBankFrameDepositButton", "GuildBankFrameWithdrawButton",
		"GuildBankInfoSaveButton", "GuildBankFramePurchaseButton",
	}, WSkin.HandleButton)

	Each({ "GuildBankInfoScrollFrame", "GuildBankTransactionsScrollFrame" }, WSkin.StripTextures)
	WSkin:HandleScrollBar(_G.GuildBankInfoScrollFrameScrollBar)
	WSkin:HandleScrollBar(_G.GuildBankTransactionsScrollFrameScrollBar)

	for i = 1, 4 do WSkin:HandleTab(_G["GuildBankFrameTab" .. i]) end

	local bankTabs = Count(_G.MAX_GUILDBANK_TABS, 6)
	for i = 1, bankTabs do
		local tab = _G["GuildBankTab" .. i]
		local button = _G["GuildBankTab" .. i .. "Button"]
		local icon = _G["GuildBankTab" .. i .. "ButtonIconTexture"]
		WSkin:StripTextures(tab, true)
		SkinGuildBankItem(button, icon)
		local checked = button and button.GetCheckedTexture and button:GetCheckedTexture()
		if checked then
			checked:SetTexture(1, 1, 1, 0.3)
			WSkin:SetInside(checked, button)
		end
	end

	local buttonMap = {}
	local columns = Count(_G.NUM_GUILDBANK_COLUMNS, 7)
	local slotsPerColumn = Count(_G.NUM_SLOTS_PER_GUILDBANK_GROUP, 14)
	for column = 1, columns do
		WSkin:StripTextures(_G["GuildBankColumn" .. column])
		for index = 1, slotsPerColumn do
			local prefix = "GuildBankColumn" .. column .. "Button" .. index
			local button = _G[prefix]
			local icon = _G[prefix .. "IconTexture"]
			local normal = _G[prefix .. "NormalTexture"]
			local count = _G[prefix .. "Count"]
			if normal and normal.SetTexture then normal:SetTexture(nil) end
			SkinGuildBankItem(button, icon)
			if icon and icon.SetDrawLayer then icon:SetDrawLayer("OVERLAY") end
			if count and count.SetDrawLayer then count:SetDrawLayer("OVERLAY") end
			buttonMap[#buttonMap + 1] = button
		end
	end

	if hooksecurefunc and type(_G.GuildBankFrame_Update) == "function" then
		hooksecurefunc("GuildBankFrame_Update", function()
			if frame.mode ~= "bank" then
				Point(frame.inset, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -29, 62)
				return
			end
			Point(frame.inset, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 62)
			local tab = GetCurrentGuildBankTab and GetCurrentGuildBankTab()
			for i = 1, #buttonMap do
				local link = tab and GetGuildBankItemLink and GetGuildBankItemLink(tab, i)
				local quality = link and GetItemInfo and select(3, GetItemInfo(link))
				SetQualityBorder(buttonMap[i], quality)
			end
		end)
	end

	ClearPoints(_G.GuildBankFrameDepositButton, _G.GuildBankFrameWithdrawButton)
	Point(_G.GuildBankFrameDepositButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 36)
	Point(_G.GuildBankFrameWithdrawButton, "RIGHT", _G.GuildBankFrameDepositButton, "LEFT", -3, 0)
	for i = 1, 4 do ClearPoints(_G["GuildBankFrameTab" .. i]) end
	Point(_G.GuildBankFrameTab1, "BOTTOMLEFT", frame, "BOTTOMLEFT", 11, -22)
	for i = 2, 4 do
		Point(_G["GuildBankFrameTab" .. i], "LEFT", _G["GuildBankFrameTab" .. (i - 1)], "RIGHT", -15, 0)
	end

	Point(_G.GuildBankMessageFrame, "TOPLEFT", frame, "TOPLEFT", 27, -72)
	if _G.GuildBankMessageFrame then WSkin:Size(_G.GuildBankMessageFrame, 575, 302) end
	if _G.GuildBankTransactionsScrollFrame then WSkin:Size(_G.GuildBankTransactionsScrollFrame, 591, 318) end
	Point(_G.GuildBankTransactionsScrollFrame, "TOPRIGHT", frame, "TOPRIGHT", -29, -64)
	Point(_G.GuildBankTransactionsScrollFrameScrollBar, "TOPLEFT", _G.GuildBankTransactionsScrollFrame, "TOPRIGHT", 3, -19)
	Point(_G.GuildBankTransactionsScrollFrameScrollBar, "BOTTOMLEFT", _G.GuildBankTransactionsScrollFrame, "BOTTOMRIGHT", 3, 19)

	Point(_G.GuildBankInfo, "TOPLEFT", frame, "TOPLEFT", 26, -72)
	if _G.GuildBankInfoScrollFrame then WSkin:Size(_G.GuildBankInfoScrollFrame, 575, 302) end
	Point(_G.GuildBankInfoScrollFrameScrollBar, "TOPLEFT", _G.GuildBankInfoScrollFrame, "TOPRIGHT", 12, -11)
	Point(_G.GuildBankInfoScrollFrameScrollBar, "BOTTOMLEFT", _G.GuildBankInfoScrollFrame, "BOTTOMRIGHT", 12, 11)
	if _G.GuildBankTabInfoEditBox then WSkin:Width(_G.GuildBankTabInfoEditBox, 575) end
	Point(_G.GuildBankInfoSaveButton, "BOTTOMLEFT", frame, "BOTTOMLEFT", 19, 35)

	if _G.GuildBankPopupFrame then
		WSkin:HandleIconSelectionFrame(_G.GuildBankPopupFrame, Count(_G.NUM_GUILDBANK_ICONS_SHOWN, 20), "GuildBankPopupButton", "GuildBankPopup")
		WSkin:SetBackdropHitRect(_G.GuildBankPopupFrame)
		WSkin:HandleScrollBar(_G.GuildBankPopupScrollFrameScrollBar)
		Point(_G.GuildBankPopupFrame, "TOPLEFT", frame, "TOPRIGHT", 24, 0)
	end

	for i = 1, bankTabs do ClearPoints(_G["GuildBankTab" .. i]) end
	for i = 1, bankTabs do
		local tab = _G["GuildBankTab" .. i]
		if i == 1 then
			Point(tab, "TOPLEFT", frame, "TOPRIGHT", -1, -36)
		else
			Point(tab, "TOPLEFT", _G["GuildBankTab" .. (i - 1)], "BOTTOMLEFT", 0, 7)
		end
	end
	for column = 1, columns do ClearPoints(_G["GuildBankColumn" .. column]) end
	for column = 1, columns do
		local current = _G["GuildBankColumn" .. column]
		if column == 1 then
			Point(current, "TOPLEFT", frame, "TOPLEFT", 25, -70)
		else
			Point(current, "TOPLEFT", _G["GuildBankColumn" .. (column - 1)], "TOPRIGHT", -14, 0)
		end
		ClearPoints(_G["GuildBankColumn" .. column .. "Button8"])
		Point(_G["GuildBankColumn" .. column .. "Button8"], "TOPLEFT", _G["GuildBankColumn" .. column .. "Button1"], "TOPRIGHT", 6, 0)
	end
end

WSkin:AddCallbackForAddon("Blizzard_GuildBankUI", "Skin_GuildBank", SkinGuildBank, "guild")
