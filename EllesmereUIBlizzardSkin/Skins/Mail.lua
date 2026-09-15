local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local select, unpack = select, unpack

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

local function SkinWindow(frame, closeButton)
	if not frame then return end
	WSkin:StripTextures(frame, true)
	WSkin:CreateBackdrop(frame, "Transparent")
	if not frame.backdrop then return end
	frame.backdrop:ClearAllPoints()
	Point(frame.backdrop, "TOPLEFT", frame, "TOPLEFT", 11, -12)
	Point(frame.backdrop, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 76)
	WSkin:HandleCloseButton(closeButton, frame.backdrop)
	return frame.backdrop
end

local function SetQualityBorder(button, quality, isGM)
	local target = button and (button.backdrop or button)
	if not target or not target.SetBackdropBorderColor then return end
	if isGM then
		target:SetBackdropBorderColor(0, 0.56, 0.94)
	elseif quality and GetItemQualityColor then
		target:SetBackdropBorderColor(GetItemQualityColor(quality))
	else
		target:SetBackdropBorderColor(0.2, 0.2, 0.2)
	end
end

local function SkinMailItem(button, icon)
	if not button then return end
	local texture = icon and icon.GetTexture and icon:GetTexture()
	WSkin:StripTextures(button)
	WSkin:CreateBackdrop(button, "Default")
	WSkin:StyleButton(button)
	if icon then
		if texture then icon:SetTexture(texture) end
		icon:SetTexCoord(unpack(WSkin.TexCoords))
		WSkin:SetInside(icon, button.backdrop or button)
		if icon.SetDrawLayer then icon:SetDrawLayer("ARTWORK") end
	end
end

local function SkinMail()
	if not WSkin:IsSkinEnabled("mail") or not _G.MailFrame then return end

	local mailBackdrop = SkinWindow(_G.MailFrame, _G.InboxCloseButton)
	if not mailBackdrop then return end
	WSkin:SetUIPanelWindowInfo(_G.MailFrame, "width")
	WSkin:SetBackdropHitRect(_G.MailFrame)
	WSkin:SetBackdropHitRect(_G.SendMailFrame, mailBackdrop)

	if _G.MailFrame.EnableMouseWheel then
		_G.MailFrame:EnableMouseWheel(true)
		_G.MailFrame:HookScript("OnMouseWheel", function(_, delta)
			if delta > 0 then
				if _G.InboxPrevPageButton and _G.InboxPrevPageButton:IsEnabled() == 1 and _G.InboxPrevPage then _G.InboxPrevPage() end
			elseif _G.InboxNextPageButton and _G.InboxNextPageButton:IsEnabled() == 1 and _G.InboxNextPage then
				_G.InboxNextPage()
			end
		end)
	end

	local inboxCount = Count(_G.INBOXITEMS_TO_DISPLAY, 7)
	for i = 1, inboxCount do
		local mail = _G["MailItem" .. i]
		local button = _G["MailItem" .. i .. "Button"]
		local icon = _G["MailItem" .. i .. "ButtonIcon"]
		if mail then
			WSkin:StripTextures(mail)
			WSkin:CreateBackdrop(mail, "Transparent")
			if mail.backdrop then
				mail.backdrop:ClearAllPoints()
				if button then mail.backdrop:SetParent(button) end
				if mail.GetFrameLevel then mail.backdrop:SetFrameLevel(math.max(0, mail:GetFrameLevel() - 1)) end
				Point(mail.backdrop, "TOPLEFT", mail, "TOPLEFT", 44, -2)
				Point(mail.backdrop, "BOTTOMRIGHT", mail, "BOTTOMRIGHT", 3, 9)
			end
		end
		SkinMailItem(button, icon)
		Point(button, "TOPLEFT", mail, "TOPLEFT", 8, -3)
		if button then WSkin:Size(button, 32) end
	end

	if hooksecurefunc and type(_G.InboxFrame_Update) == "function" then
		hooksecurefunc("InboxFrame_Update", function()
			local total = _G.GetInboxNumItems and _G.GetInboxNumItems() or 0
			local index = (((_G.InboxFrame and _G.InboxFrame.pageNum) or 1) - 1) * inboxCount
			for i = 1, inboxCount do
				index = index + 1
				local button = _G["MailItem" .. i .. "Button"]
				if index <= total and _G.GetInboxHeaderInfo then
					local packageIcon, _, _, _, _, _, _, _, _, _, _, _, isGM = _G.GetInboxHeaderInfo(index)
					local link = packageIcon and not isGM and _G.GetInboxItemLink and _G.GetInboxItemLink(index, 1)
					local quality = link and _G.GetItemInfo and select(3, _G.GetItemInfo(link))
					SetQualityBorder(button, quality, isGM)
				else
					SetQualityBorder(button)
				end
			end
		end)
	end

	Point(_G.InboxTitleText, "CENTER", _G.MailFrame, "CENTER", 0, 231)
	Point(_G.SendMailTitleText, "CENTER", _G.MailFrame, "CENTER", 0, 231)
	WSkin:HandleNextPrevButton(_G.InboxPrevPageButton, "left", nil, true)
	WSkin:HandleNextPrevButton(_G.InboxNextPageButton, "right", nil, true)
	if _G.InboxPrevPageButton then WSkin:Size(_G.InboxPrevPageButton, 32) end
	if _G.InboxNextPageButton then WSkin:Size(_G.InboxNextPageButton, 32) end

	for i = 1, 2 do WSkin:HandleTab(_G["MailFrameTab" .. i]) end
	ClearPoints(_G.MailFrameTab1, _G.MailFrameTab2)
	Point(_G.MailItem1, "TOPLEFT", _G.InboxFrame, "TOPLEFT", 24, -80)
	Point(_G.MailFrameTab1, "BOTTOMLEFT", _G.MailFrame, "BOTTOMLEFT", 11, 46)
	Point(_G.MailFrameTab2, "LEFT", _G.MailFrameTab1, "RIGHT", -15, 0)

	WSkin:StripTextures(_G.SendMailFrame)
	WSkin:StripTextures(_G.SendMailScrollFrame, true)
	WSkin:CreateBackdrop(_G.SendMailScrollFrame, "Default")
	if _G.SendMailScrollFrame and _G.SendMailScrollFrame.backdrop then
		_G.SendMailScrollFrame.backdrop:ClearAllPoints()
		Point(_G.SendMailScrollFrame.backdrop, "TOPLEFT", _G.SendMailScrollFrame, "TOPLEFT", 0, 5)
		Point(_G.SendMailScrollFrame.backdrop, "BOTTOMRIGHT", _G.SendMailScrollFrame, "BOTTOMRIGHT", 0, -5)
	end
	WSkin:HandleScrollBar(_G.SendMailScrollFrameScrollBar)
	Each({
		"SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailMoneyGold",
		"SendMailMoneySilver", "SendMailMoneyCopper",
	}, WSkin.HandleEditBox)
	WSkin:HandleButton(_G.SendMailMailButton)
	WSkin:HandleButton(_G.SendMailCancelButton)

	local sendCount = Count(_G.ATTACHMENTS_MAX_SEND, 12)
	for i = 1, sendCount do
		local button = _G["SendMailAttachment" .. i]
		local icon = button and button.GetNormalTexture and button:GetNormalTexture()
		SkinMailItem(button, icon)
	end
	if hooksecurefunc and type(_G.SendMailFrame_Update) == "function" then
		hooksecurefunc("SendMailFrame_Update", function()
			for i = 1, sendCount do
				local button = _G["SendMailAttachment" .. i]
				local name = _G.GetSendMailItem and _G.GetSendMailItem(i)
				local quality = name and _G.GetItemInfo and select(3, _G.GetItemInfo(name))
				SetQualityBorder(button, quality)
			end
		end)
	end

	Point(_G.SendMailScrollFrameScrollBar, "TOPLEFT", _G.SendMailScrollFrame, "TOPRIGHT", 3, -14)
	Point(_G.SendMailScrollFrameScrollBar, "BOTTOMLEFT", _G.SendMailScrollFrame, "BOTTOMRIGHT", 3, 14)
	if _G.SendMailBodyEditBox then
		_G.SendMailBodyEditBox:SetTextColor(1, 1, 1)
		WSkin:Width(_G.SendMailBodyEditBox, 291)
	end
	Point(_G.SendMailBodyEditBox, "TOPLEFT", _G.SendMailScrollFrame, "TOPLEFT", 5, -5)
	if _G.SendMailScrollFrame then WSkin:Width(_G.SendMailScrollFrame, 304) end
	Point(_G.SendMailScrollFrame, "TOPLEFT", _G.SendMailFrame, "TOPLEFT", 19, -97)
	if _G.SendMailNameEditBox then WSkin:Height(_G.SendMailNameEditBox, 18) end
	Point(_G.SendMailNameEditBox, "TOPLEFT", _G.SendMailFrame, "TOPLEFT", 75, -43)
	if _G.SendMailSubjectEditBox then WSkin:Size(_G.SendMailSubjectEditBox, 247, 18) end
	Point(_G.SendMailSubjectEditBox, "TOPLEFT", _G.SendMailNameEditBox, "BOTTOMLEFT", 0, -5)
	ClearPoints(_G.SendMailMailButton, _G.SendMailCancelButton)
	Point(_G.SendMailCancelButton, "BOTTOMRIGHT", _G.SendMailFrame, "BOTTOMRIGHT", -40, 84)
	Point(_G.SendMailMailButton, "RIGHT", _G.SendMailCancelButton, "LEFT", -3, 0)

	if not _G.OpenMailFrame then return end
	SkinWindow(_G.OpenMailFrame, _G.OpenMailCloseButton)
	Point(_G.OpenMailFrame, "TOPLEFT", _G.InboxFrame, "TOPRIGHT", -44, 0)

	local receiveCount = Count(_G.ATTACHMENTS_MAX_RECEIVE, 16)
	for i = 1, receiveCount do
		local button = _G["OpenMailAttachmentButton" .. i]
		local icon = _G["OpenMailAttachmentButton" .. i .. "IconTexture"]
		local count = _G["OpenMailAttachmentButton" .. i .. "Count"]
		SkinMailItem(button, icon)
		if count and count.SetDrawLayer then count:SetDrawLayer("OVERLAY") end
	end
	if hooksecurefunc and type(_G.OpenMailFrame_UpdateButtonPositions) == "function" then
		hooksecurefunc("OpenMailFrame_UpdateButtonPositions", function()
			local mailID = _G.InboxFrame and _G.InboxFrame.openMailID
			for i = 1, receiveCount do
				local link = mailID and _G.GetInboxItemLink and _G.GetInboxItemLink(mailID, i)
				local quality = link and _G.GetItemInfo and select(3, _G.GetItemInfo(link))
				SetQualityBorder(_G["OpenMailAttachmentButton" .. i], quality)
			end
		end)
	end

	Each({
		"OpenMailReportSpamButton", "OpenMailReplyButton", "OpenMailDeleteButton", "OpenMailCancelButton",
	}, WSkin.HandleButton)
	WSkin:StripTextures(_G.OpenMailScrollFrame, true)
	WSkin:CreateBackdrop(_G.OpenMailScrollFrame, "Default")
	WSkin:HandleScrollBar(_G.OpenMailScrollFrameScrollBar)
	if _G.OpenMailScrollFrame and _G.OpenMailScrollFrame.backdrop then
		_G.OpenMailScrollFrame.backdrop:ClearAllPoints()
		Point(_G.OpenMailScrollFrame.backdrop, "TOPLEFT", _G.OpenMailScrollFrame, "TOPLEFT", -1, 3)
		Point(_G.OpenMailScrollFrame.backdrop, "BOTTOMRIGHT", _G.OpenMailScrollFrame, "BOTTOMRIGHT", 1, -2)
	end
	if _G.OpenMailBodyText then _G.OpenMailBodyText:SetTextColor(1, 1, 1) end
	if _G.OpenMailInvoiceBuyMode then _G.OpenMailInvoiceBuyMode:SetTextColor(1, 0.8, 0.1) end
	WSkin:Kill(_G.OpenMailArithmeticLine)
	SkinMailItem(_G.OpenMailLetterButton, _G.OpenMailLetterButtonIconTexture)
	SkinMailItem(_G.OpenMailMoneyButton, _G.OpenMailMoneyButtonIconTexture)
	if _G.OpenMailBodyText then WSkin:Width(_G.OpenMailBodyText, 288) end
	Point(_G.OpenMailBodyText, "TOPLEFT", _G.OpenMailScrollFrame, "TOPLEFT", 5, -3)
	if _G.OpenMailScrollFrame then WSkin:Width(_G.OpenMailScrollFrame, 302) end
	Point(_G.OpenMailScrollFrame, "TOPLEFT", _G.OpenMailFrame, "TOPLEFT", 20, -91)
	Point(_G.OpenMailScrollFrameScrollBar, "TOPLEFT", _G.OpenMailScrollFrame, "TOPRIGHT", 4, -16)
	Point(_G.OpenMailScrollFrameScrollBar, "BOTTOMLEFT", _G.OpenMailScrollFrame, "BOTTOMRIGHT", 4, 17)
	Point(_G.OpenMailReportSpamButton, "TOPRIGHT", _G.OpenMailFrame, "TOPRIGHT", -40, -43)
	ClearPoints(_G.OpenMailReplyButton, _G.OpenMailDeleteButton, _G.OpenMailCancelButton)
	Point(_G.OpenMailCancelButton, "BOTTOMRIGHT", _G.OpenMailFrame, "BOTTOMRIGHT", -40, 84)
	Point(_G.OpenMailDeleteButton, "RIGHT", _G.OpenMailCancelButton, "LEFT", -3, 0)
	Point(_G.OpenMailReplyButton, "RIGHT", _G.OpenMailDeleteButton, "LEFT", -3, 0)
end

WSkin:AddCallback("Skin_Mail", SkinMail, "mail")
