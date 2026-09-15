local WSkin = _G.EllesmereUIBlizzardSkin
local _G = _G

--Lua functions
local select, unpack = select, unpack

local function Count(value, fallback)
	return type(value) == "number" and value or fallback
end

-- Standard icon tex coordinates to crop the default icon border
local TEXCOORDS = { 0.08, 0.92, 0.08, 0.92 }

local function SkinTalents()
	if not WSkin:IsSkinEnabled("playerspells") then return end
	if not PlayerTalentFrame then return end

	WSkin:StripTextures(PlayerTalentFrame, true)
	WSkin:CreateBackdrop(PlayerTalentFrame, "Transparent")
	PlayerTalentFrame.backdrop:ClearAllPoints()
	WSkin:Point(PlayerTalentFrame.backdrop, "TOPLEFT", 11, -12)
	WSkin:Point(PlayerTalentFrame.backdrop, "BOTTOMRIGHT", -32, 76)

	WSkin:SetBackdropHitRect(PlayerTalentFrame)

	do
		local offset

		local talentGroups = type(GetNumTalentGroups) == "function" and GetNumTalentGroups(false, false) or 1
		local petTalentGroups = type(GetNumTalentGroups) == "function" and GetNumTalentGroups(false, true) or 0

		if talentGroups + petTalentGroups > 1 then
			WSkin:SetUIPanelWindowInfo(PlayerTalentFrame, "width", nil, 31)
			offset = true
		else
			WSkin:SetUIPanelWindowInfo(PlayerTalentFrame, "width")
		end

		if type(PlayerTalentFrame_UpdateSpecs) == "function" then hooksecurefunc("PlayerTalentFrame_UpdateSpecs", function(_, numTalentGroups, _, numPetTalentGroups)
			if offset and numTalentGroups + numPetTalentGroups <= 1 then
				WSkin:SetUIPanelWindowInfo(PlayerTalentFrame, "width")
				offset = nil
			elseif not offset and numTalentGroups + numPetTalentGroups > 1 then
				WSkin:SetUIPanelWindowInfo(PlayerTalentFrame, "width", nil, 31)
				offset = true
			end
		end) end
	end

	WSkin:HandleCloseButton(PlayerTalentFrameCloseButton, PlayerTalentFrame.backdrop)

	local function glyphFrameOnShow(self)
		if GlyphFrame and GlyphFrame:IsShown() then
			self:Hide()
		end
	end

	PlayerTalentFrameStatusFrame:HookScript("OnShow", glyphFrameOnShow)
	PlayerTalentFrameActivateButton:HookScript("OnShow", glyphFrameOnShow)

	WSkin:StripTextures(PlayerTalentFrameStatusFrame)
	WSkin:StripTextures(PlayerTalentFramePointsBar)
	WSkin:StripTextures(PlayerTalentFramePreviewBar)

	WSkin:HandleButton(PlayerTalentFrameActivateButton)
	WSkin:HandleButton(PlayerTalentFrameResetButton)
	WSkin:HandleButton(PlayerTalentFrameLearnButton)

	WSkin:StripTextures(PlayerTalentFramePreviewBarFiller)

	WSkin:StripTextures(PlayerTalentFrameScrollFrame)
	WSkin:CreateBackdrop(PlayerTalentFrameScrollFrame, "Default")
	WSkin:HandleScrollBar(PlayerTalentFrameScrollFrameScrollBar)

	local talentButtonsSkinned = {}
	local function UpdateTalentButtons()
		local tabIndex = PlayerTalentFrame.selectedTab or 1
		for i = 1, Count(MAX_NUM_TALENTS, 80) do
			local talent = _G["PlayerTalentFrameTalent" .. i]
			local icon = _G["PlayerTalentFrameTalent" .. i .. "IconTexture"]
			local rank = _G["PlayerTalentFrameTalent" .. i .. "Rank"]
			if talent then
				local currentTexture = icon and icon.GetTexture and icon:GetTexture()
				local iconTexturePath
				if type(GetTalentInfo) == "function" then iconTexturePath = select(2, GetTalentInfo(tabIndex, i)) end
				if not talentButtonsSkinned[talent] then
					talentButtonsSkinned[talent] = true
					WSkin:StripTextures(talent)
					WSkin:SetTemplate(talent, "Default")
					WSkin:StyleButton(talent)
					local parent = talent.GetParent and talent:GetParent()
					if parent and parent.GetFrameLevel then talent:SetFrameLevel(parent:GetFrameLevel() + 2) end
				end
				if icon then
					if iconTexturePath or currentTexture then icon:SetTexture(iconTexturePath or currentTexture) end
					WSkin:SetInside(icon, talent)
					icon:SetTexCoord(unpack(TEXCOORDS))
					if icon.SetDrawLayer then icon:SetDrawLayer("ARTWORK") end
				end
				WSkin:FontTemplate(rank, nil, 12, "OUTLINE")
			end
		end
	end

	UpdateTalentButtons()
	if type(PlayerTalentFrame_Update) == "function" then hooksecurefunc("PlayerTalentFrame_Update", UpdateTalentButtons) end


	for i = 1, 4 do
		WSkin:HandleTab(_G["PlayerTalentFrameTab"..i])
	end

	if MAX_TALENT_TABS then
		for i = 1, Count(MAX_TALENT_TABS, 2) do
			local tab = _G["PlayerSpecTab"..i]
			if tab then
				local border = tab.GetRegions and tab:GetRegions()
				if border and border.Hide then border:Hide() end
				WSkin:SetTemplate(tab, "Default")
				WSkin:StyleButton(tab, nil, true)
				local norm = tab:GetNormalTexture()
				if norm then
					WSkin:SetInside(norm, tab)
					norm:SetTexCoord(unpack(TEXCOORDS))
				end
			end
		end
	end

	WSkin:Point(PlayerTalentFrameStatusFrame, "TOPLEFT", 57, -40)
	WSkin:Point(PlayerTalentFrameActivateButton, "TOP", 0, -40)

	WSkin:Width(PlayerTalentFrameScrollFrame, 302)
	WSkin:Point(PlayerTalentFrameScrollFrame, "TOPRIGHT", PlayerTalentFrame, "TOPRIGHT", -62, -77)
	PlayerTalentFrameScrollFrame:SetPoint("BOTTOM", PlayerTalentFramePointsBar, "TOP", 0, 0)

	WSkin:Point(PlayerTalentFrameScrollFrameScrollBar, "TOPLEFT", PlayerTalentFrameScrollFrame, "TOPRIGHT", 4, -18)
	WSkin:Point(PlayerTalentFrameScrollFrameScrollBar, "BOTTOMLEFT", PlayerTalentFrameScrollFrame, "BOTTOMRIGHT", 4, 18)

	PlayerTalentFrameResetButton:ClearAllPoints()
	PlayerTalentFrameLearnButton:ClearAllPoints()
	WSkin:Point(PlayerTalentFrameResetButton, "RIGHT", -4, 1)
	WSkin:Point(PlayerTalentFrameLearnButton, "RIGHT", PlayerTalentFrameResetButton, "LEFT", -3, 0)

	if PlayerSpecTab1 then
		WSkin:Point(PlayerSpecTab1, "TOPLEFT", PlayerTalentFrame, "TOPRIGHT", -33, -65)
		PlayerSpecTab1.ClearAllPoints = function() end
		PlayerSpecTab1.SetPoint = function() end
	end

	WSkin:Point(PlayerTalentFrameTab1, "BOTTOMLEFT", 11, 46)
end

WSkin:AddCallbackForAddon("Blizzard_TalentUI", "Skin_Talent", SkinTalents, "playerspells")
