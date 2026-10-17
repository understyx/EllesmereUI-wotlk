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
	WSkin:StripTextures(GossipFrameGreetingPanel)
	-- Gossip's 3.3.5 panel has no reserved footer margin in its visible art rect.
	WSkin:SkinRetailWindow(GossipFrame, {
		closeButton = GossipFrameCloseButton,
		titleRegion = GossipFrameNpcNameText,
		insets = { left = 11, top = -12, right = -32, bottom = 0 },
		artRegions = { { object = GossipFramePortrait, action = "kill" } },
	})

	WSkin:SetUIPanelWindowInfo(GossipFrame, "width")

	GossipGreetingText:SetTextColor(1, 1, 1)

	WSkin:HandleRetailScrollBar(GossipGreetingScrollFrameScrollBar)
	WSkin:HandleRetailButton(GossipFrameGreetingGoodbyeButton)

	for i = 1, NUMGOSSIPBUTTONS do
		local button = _G["GossipTitleButton"..i]
		WSkin:HandleButtonHighlight(button)
		select(3, button:GetRegions()):SetTextColor(1, 1, 1)
	end

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
	WSkin:SkinRetailWindow(ItemTextFrame, {
		closeButton = ItemTextCloseButton,
		titleRegion = ItemTextTitleText,
	})

	WSkin:SetUIPanelWindowInfo(ItemTextFrame, "width")

	ItemTextPageText:SetTextColor(1, 1, 1)
	ItemTextPageText.SetTextColor = function() end

	WSkin:HandleNextPrevButton(ItemTextPrevPageButton)
	WSkin:HandleNextPrevButton(ItemTextNextPageButton)

	WSkin:HandleRetailScrollBar(ItemTextScrollFrameScrollBar)

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
