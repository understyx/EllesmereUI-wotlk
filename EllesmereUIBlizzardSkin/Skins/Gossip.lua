local WSkin = _G.EllesmereUIBlizzardSkin
local _G = _G

--Lua functions
local _G = _G
local select = select
local find, gsub = string.find, string.gsub
--WoW API / Variables

WSkin:AddCallback("Skin_Gossip", function()
	if not WSkin:IsSkinEnabled("gossip") then return end

	-- Gossip
	WSkin:Kill(GossipFramePortrait)
	WSkin:StripTextures(GossipFrameGreetingPanel)

	WSkin:CreateBackdrop(GossipFrame, "Transparent")
	WSkin:Point(GossipFrame.backdrop, "TOPLEFT", 11, -12)
	WSkin:Point(GossipFrame.backdrop, "BOTTOMRIGHT", -32, 0)
	-- Shared window shell on the visible backdrop rect; Blizzard's content
	-- layout is anchored to the native frame and stays where it is.
	WSkin:CreateRetailWindowShell(GossipFrame.backdrop, nil, nil, GossipFrameCloseButton, { content = false })

	WSkin:SetUIPanelWindowInfo(GossipFrame, "width")
	WSkin:SetBackdropHitRect(GossipFrame)

	GossipGreetingText:SetTextColor(1, 1, 1)

	WSkin:HandleRetailScrollBar(GossipGreetingScrollFrameScrollBar)
	WSkin:HandleRetailButton(GossipFrameGreetingGoodbyeButton)

	for i = 1, NUMGOSSIPBUTTONS do
		local button = _G["GossipTitleButton"..i]
		WSkin:HandleButtonHighlight(button)
		select(3, button:GetRegions()):SetTextColor(1, 1, 1)
	end

	WSkin:SetRetailPageTitle(GossipFrame.backdrop, nil, GossipFrameNpcNameText)

	WSkin:Size(GossipGreetingScrollFrame, 304, 402)
	WSkin:Point(GossipGreetingScrollFrame, "TOPLEFT", GossipFrame, "TOPLEFT", 19, -73)

	WSkin:Point(GossipGreetingScrollFrameScrollBar, "TOPLEFT", GossipGreetingScrollFrame, "TOPRIGHT", 3, -19)
	WSkin:Point(GossipGreetingScrollFrameScrollBar, "BOTTOMLEFT", GossipGreetingScrollFrame, "BOTTOMRIGHT", 3, 19)

	WSkin:Point(GossipFrameGreetingGoodbyeButton, "BOTTOMRIGHT", -40, 8)

	hooksecurefunc("GossipFrameUpdate", function()
		for i = 1, GossipFrame.buttonIndex do
			local button = _G["GossipTitleButton"..i]

			if button:GetText() and find(button:GetText(), "|cff000000") then
				button:SetText(gsub(button:GetText(), "|cff000000", "|cffFFFF00"))
			end
		end
	end)

	-- ItemText
	WSkin:StripTextures(ItemTextScrollFrame)
	WSkin:StripTextures(ItemTextFrame, true)
	WSkin:CreateBackdrop(ItemTextFrame, "Transparent")
	WSkin:Point(ItemTextFrame.backdrop, "TOPLEFT", 11, -12)
	WSkin:Point(ItemTextFrame.backdrop, "BOTTOMRIGHT", -32, 76)
	WSkin:CreateRetailWindowShell(ItemTextFrame.backdrop, nil, nil, ItemTextCloseButton, { content = false })

	WSkin:SetUIPanelWindowInfo(ItemTextFrame, "width")
	WSkin:SetBackdropHitRect(ItemTextFrame)

	ItemTextPageText:SetTextColor(1, 1, 1)
	ItemTextPageText.SetTextColor = function() end

	WSkin:HandleNextPrevButton(ItemTextPrevPageButton)
	WSkin:HandleNextPrevButton(ItemTextNextPageButton)

	WSkin:HandleRetailScrollBar(ItemTextScrollFrameScrollBar)

	WSkin:SetRetailPageTitle(ItemTextFrame.backdrop, nil, ItemTextTitleText)
	WSkin:ApplyRetailTypography(ItemTextCurrentPage, "secondary")

	WSkin:Point(ItemTextCurrentPage, "TOP", -15, -52)

	WSkin:Point(ItemTextPrevPageButton, "CENTER", ItemTextFrame, "TOPLEFT", 100, -58)
	WSkin:Point(ItemTextNextPageButton, "CENTER", ItemTextFrame, "TOPRIGHT", -130, -58)

	WSkin:Point(ItemTextPrevPageButton:GetRegions(), "LEFT", ItemTextPrevPageButton, "RIGHT", 3, 0)
	WSkin:Point(ItemTextNextPageButton:GetRegions(), "RIGHT", ItemTextNextPageButton, "LEFT", -3, 0)

	WSkin:Width(ItemTextScrollFrame, 283)
	WSkin:Point(ItemTextScrollFrame, "TOPRIGHT", -61, -73)

	WSkin:Point(ItemTextScrollFrameScrollBar, "TOPLEFT", ItemTextScrollFrame, "TOPRIGHT", 3, -19)
	WSkin:Point(ItemTextScrollFrameScrollBar, "BOTTOMLEFT", ItemTextScrollFrame, "BOTTOMRIGHT", 3, 19)
end, "gossip")