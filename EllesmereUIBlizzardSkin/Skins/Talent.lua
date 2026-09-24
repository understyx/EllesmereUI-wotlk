local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end
local EllesmereUI = _G.EllesmereUI

local _G = _G
local type, unpack = type, unpack
local TEXCOORDS = WSkin.TexCoords or { 0.08, 0.92, 0.08, 0.92 }

local FRAME_HEIGHT = 450
local TAB_HEIGHT = WSkin.Retail.geometry.tabHeight
local CONTROL_LEFT = 24
local CONTROL_BOTTOM = TAB_HEIGHT + 4
local TALENT_INSET = 1
local TALENT_STATUS_TOP = 21
local TALENT_TREE_TOP = 50
local TALENT_INITIAL_X = 48
local TALENT_INITIAL_Y = 18
local TALENT_SPACING_X = 80
local TALENT_SPACING_Y = 68
local NATIVE_TALENT_INITIAL_X = 35
local NATIVE_TALENT_INITIAL_Y = 20
local NATIVE_TALENT_SPACING = 63
local SPEC_TAB_SIZE = 36
local SPEC_TAB_X = 4
local SPEC_TAB_TOP = 48
local SPEC_TAB_GAP = 12

-- Keep skin state off Blizzard-owned frames. Besides avoiding taint, this lets
-- both load-on-demand addons (TalentUI and GlyphUI) safely call the same setup.
local FFD = setmetatable({}, { __mode = "k" })
local function Data(frame)
	local data = FFD[frame]
	if not data then
		data = {}
		FFD[frame] = data
	end
	return data
end

local function Count(value, fallback)
	return type(value) == "number" and value or fallback
end

local function SetFont(region, tier, alpha)
	if region then WSkin:ApplyRetailTypography(region, tier, alpha) end
end

local talentArtwork = {
	{ "PlayerTalentFrameBackgroundTopLeft", 0, 1, 0, 1 },
	{ "PlayerTalentFrameBackgroundTopRight", 0, 0.6875, 0, 1 },
	{ "PlayerTalentFrameBackgroundBottomLeft", 0, 1, 0, 0.5859375 },
	{ "PlayerTalentFrameBackgroundBottomRight", 0, 0.6875, 0, 0.5859375 },
}

local function StyleTalentArtwork()
	local scroll = _G.PlayerTalentFrameScrollFrame
	if not scroll then return end
	if scroll.SetBackdrop then scroll:SetBackdrop(nil) end

	-- Preserve the native class tree artwork, but remove the old ornamental
	-- scrollbar gutter that clashes with the compact retail scrollbar.
	for _, info in ipairs(talentArtwork) do
		local texture = _G[info[1]]
		if texture then
			texture:SetTexCoord(info[2], info[3], info[4], info[5])
			texture:SetAlpha(0.92)
			texture:Show()
		end
	end
	for _, name in ipairs({
		"PlayerTalentFrameScrollFrameBackgroundTop",
		"PlayerTalentFrameScrollFrameBackgroundBottom",
	}) do
		local texture = _G[name]
		if texture then
			texture:SetTexture(nil)
			texture:Hide()
		end
	end
end

local function LayoutBottomTabs()
	local frame = _G.PlayerTalentFrame
	if not frame then return end
	local width = frame:GetWidth() / 4
	for i = 1, 4 do
		local tab = _G["PlayerTalentFrameTab" .. i]
		if tab then
			WSkin:StyleRetailTab(tab)
			tab:SetHitRectInsets(0, 0, 0, 0)
			tab:ClearAllPoints()
			tab:SetSize(width, TAB_HEIGHT)
			if i == 1 then
				tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
			else
				tab:SetPoint("LEFT", _G["PlayerTalentFrameTab" .. (i - 1)], "RIGHT", 0, 0)
			end
		end
	end
end

local function ResetTalentScroll()
	local scroll = _G.PlayerTalentFrameScrollFrame
	if scroll and scroll.SetVerticalScroll then
		scroll:SetVerticalScroll(0)
	end
end

local function LayoutTalentFrame()
	local frame = _G.PlayerTalentFrame
	if not frame then return end

	frame:SetHeight(FRAME_HEIGHT)
	frame:SetHitRectInsets(0, 0, 0, 0)

	local status = _G.PlayerTalentFrameStatusFrame
	if status then
		status:ClearAllPoints()
		status:SetPoint("TOPLEFT", frame, "TOPLEFT", TALENT_INSET, -TALENT_STATUS_TOP)
		status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -TALENT_INSET, -TALENT_STATUS_TOP)
		status:SetHeight(20)
	end

	local activate = _G.PlayerTalentFrameActivateButton
	if activate then
		activate:ClearAllPoints()
		activate:SetPoint("TOP", frame, "TOP", 0, -TALENT_STATUS_TOP)
	end

	local preview = _G.PlayerTalentFramePreviewBar
	if preview then
		preview:ClearAllPoints()
		preview:SetPoint("LEFT", frame, "LEFT", TALENT_INSET, 0)
		preview:SetPoint("RIGHT", frame, "RIGHT", -TALENT_INSET, 0)
		preview:SetPoint("BOTTOM", frame, "BOTTOM", 0, CONTROL_BOTTOM)
	end

	local points = _G.PlayerTalentFramePointsBar
	if points then
		points:ClearAllPoints()
		points:SetPoint("LEFT", frame, "LEFT", TALENT_INSET, 0)
		points:SetPoint("RIGHT", frame, "RIGHT", -TALENT_INSET, 0)
		if preview and preview:IsShown() then
			points:SetPoint("BOTTOM", preview, "TOP", 0, -4)
		else
			points:SetPoint("BOTTOM", frame, "BOTTOM", 0, CONTROL_BOTTOM)
		end
	end

	local scroll = _G.PlayerTalentFrameScrollFrame
	if scroll and points then
		scroll:ClearAllPoints()
		scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", TALENT_INSET, -TALENT_TREE_TOP)
		scroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -TALENT_INSET, -TALENT_TREE_TOP)
		scroll:SetPoint("BOTTOM", points, "TOP", 0, 0)

		local scrollChild = scroll.GetScrollChild and scroll:GetScrollChild()
		if scrollChild then
			scrollChild:SetWidth(frame:GetWidth() - (TALENT_INSET * 2))
		end

		-- The stock scrollbar reserves space for arrow buttons. Those buttons
		-- are removed by the retail skin, so place the track inside the expanded
		-- canvas and let it use the complete talent viewport.
		local scrollbar = _G.PlayerTalentFrameScrollFrameScrollBar
		if scrollbar then
			scrollbar:ClearAllPoints()
			scrollbar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -3, 0)
			scrollbar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -3, 0)
		end
	end
	StyleTalentArtwork()

	LayoutBottomTabs()
end

local function UpdateBottomTabs()
	local frame = _G.PlayerTalentFrame
	if not frame then return end
	local selected = (_G.GlyphFrame and _G.GlyphFrame:IsShown()) and 4
	if not selected and type(_G.PanelTemplates_GetSelectedTab) == "function" then
		selected = _G.PanelTemplates_GetSelectedTab(frame)
	end
	selected = selected or frame.selectedTab or 1
	for i = 1, 4 do
		WSkin:UpdateRetailTab(_G["PlayerTalentFrameTab" .. i], selected == i)
	end
end

local function StyleSpecTabs()
	local previous
	for i = 1, 3 do
		local tab = _G["PlayerSpecTab" .. i]
		if tab then
			local data = Data(tab)
			local normal = tab.GetNormalTexture and tab:GetNormalTexture()
			local texture = normal and normal.GetTexture and normal:GetTexture()
			if not data.skinned then
				data.skinned = true
				WSkin:StripTextures(tab)
				WSkin:StyleButton(tab, nil, true)
				tab:HookScript("OnClick", ResetTalentScroll)
			end
			WSkin:ApplyRetailSurface(tab, "card")
			if normal then
				if texture then normal:SetTexture(texture) end
				normal:SetTexCoord(unpack(TEXCOORDS))
				normal:ClearAllPoints()
				normal:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -3)
				normal:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 3)
				normal:Show()
				WSkin:ApplyRetailIcon(normal, tab)
			end
			local ar, ag, ab = WSkin:GetRetailAccent()
			local checked = tab.GetChecked and tab:GetChecked()
			tab:SetBackdropBorderColor(ar, ag, ab, checked and 0.85 or 0.20)

			if tab:IsShown() then
				tab:ClearAllPoints()
				tab:SetSize(SPEC_TAB_SIZE, SPEC_TAB_SIZE)
				if previous then
					tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -SPEC_TAB_GAP)
				else
					tab:SetPoint("TOPLEFT", _G.PlayerTalentFrame, "TOPRIGHT", SPEC_TAB_X, -SPEC_TAB_TOP)
				end
				previous = tab
			end
		end
	end
end

local talentButtonsSkinned = setmetatable({}, { __mode = "k" })
local function UpdateTalentButtons()
	local frame = _G.PlayerTalentFrame
	if not frame then return end
	local tabIndex = type(_G.PanelTemplates_GetSelectedTab) == "function"
		and _G.PanelTemplates_GetSelectedTab(frame) or frame.selectedTab or 1
	for i = 1, Count(_G.MAX_NUM_TALENTS, 80) do
		local talent = _G["PlayerTalentFrameTalent" .. i]
		local icon = _G["PlayerTalentFrameTalent" .. i .. "IconTexture"]
		local rank = _G["PlayerTalentFrameTalent" .. i .. "Rank"]
		if talent then
			local currentTexture = icon and icon.GetTexture and icon:GetTexture()
			local talentName, apiTexture, tier, column
			if type(_G.GetTalentInfo) == "function" then
				talentName, apiTexture, tier, column = _G.GetTalentInfo(
					tabIndex,
					i,
					frame.inspect,
					frame.pet,
					frame.talentGroup
				)
			end
			local iconTexture = currentTexture or apiTexture
			if talentName and tier and column then
				talent:ClearAllPoints()
				talent:SetPoint(
					"TOPLEFT",
					talent:GetParent(),
					"TOPLEFT",
					TALENT_INITIAL_X + ((column - 1) * TALENT_SPACING_X),
					-TALENT_INITIAL_Y - ((tier - 1) * TALENT_SPACING_Y)
				)
			end
			if not talentButtonsSkinned[talent] then
				talentButtonsSkinned[talent] = true
				WSkin:StripTextures(talent)
				WSkin:ApplyRetailSurface(talent, "card")
				-- Keep Blizzard's 37px hit target/branch alignment, but make the
				-- visible tile lighter and smaller than the original talent socket.
				talent:SetBackdropColor(0.015, 0.020, 0.022, 0.35)
				talent:SetBackdropBorderColor(1, 1, 1, 0.08)
				WSkin:StyleButton(talent)
				local parent = talent.GetParent and talent:GetParent()
				if parent and parent.GetFrameLevel then talent:SetFrameLevel(parent:GetFrameLevel() + 2) end
			end
			if icon then
				if iconTexture then icon:SetTexture(iconTexture) end
				icon:ClearAllPoints()
				icon:SetPoint("TOPLEFT", talent, "TOPLEFT", 4, -4)
				icon:SetPoint("BOTTOMRIGHT", talent, "BOTTOMRIGHT", -4, 4)
				icon:SetTexCoord(unpack(TEXCOORDS))
				icon:SetDrawLayer("ARTWORK")
				icon:Show()
				WSkin:ApplyRetailIcon(icon, talent)
			end
			SetFont(rank, "value")
		end
	end
end

local function RemapTalentConnector(region, resize)
	if not region or not region:IsShown() then return end
	local point, relativeTo, relativePoint, x, y = region:GetPoint(1)
	if type(x) ~= "number" or type(y) ~= "number" then return end

	local xScale = TALENT_SPACING_X / NATIVE_TALENT_SPACING
	local yScale = TALENT_SPACING_Y / NATIVE_TALENT_SPACING
	local mappedX = TALENT_INITIAL_X + ((x - NATIVE_TALENT_INITIAL_X) * xScale)
	local mappedY = -TALENT_INITIAL_Y + ((y + NATIVE_TALENT_INITIAL_Y) * yScale)
	region:ClearAllPoints()
	region:SetPoint(point, relativeTo, relativePoint, mappedX, mappedY)

	if resize then
		local data = Data(region)
		if not data.nativeWidth then
			data.nativeWidth = region:GetWidth()
			data.nativeHeight = region:GetHeight()
		end
		region:SetSize(data.nativeWidth * xScale, data.nativeHeight * yScale)
	end
end

local function LayoutTalentConnectors()
	for i = 1, Count(_G.MAX_NUM_BRANCH_TEXTURES, 30) do
		RemapTalentConnector(_G["PlayerTalentFrameBranch" .. i], true)
	end
	for i = 1, Count(_G.MAX_NUM_ARROW_TEXTURES, 30) do
		RemapTalentConnector(_G["PlayerTalentFrameArrow" .. i], false)
	end
end

local talentUpdateHooked
local glyphHooked, glyphAnimationHooked, glyphTitleHooked
local GLYPH_TYPE_MAJOR = 1
local GLYPH_TYPE_MINOR = 2
local GLYPH_MINOR_LEFT = 202
local GLYPH_ROW_TOP = -82
local GLYPH_ROW_SPACING = 94

-- Socket IDs are ordered by unlock level, not by glyph type. These are the
-- stock Wrath types and only serve as a fallback while the API is unavailable.
local glyphTypeFallback = {
	[1] = GLYPH_TYPE_MAJOR,
	[2] = GLYPH_TYPE_MINOR,
	[3] = GLYPH_TYPE_MINOR,
	[4] = GLYPH_TYPE_MAJOR,
	[5] = GLYPH_TYPE_MINOR,
	[6] = GLYPH_TYPE_MAJOR,
}

local function GetGlyphSlotInfo(slot, id)
	id = id or (slot and slot.GetID and slot:GetID())
	local talentGroup = _G.PlayerTalentFrame and _G.PlayerTalentFrame.talentGroup
	local enabled, glyphType, glyphSpell
	if id and type(_G.GetGlyphSocketInfo) == "function" then
		enabled, glyphType, glyphSpell = _G.GetGlyphSocketInfo(id, talentGroup)
	end
	glyphType = glyphType or (slot and slot.glyphType) or glyphTypeFallback[id] or GLYPH_TYPE_MAJOR
	return enabled, glyphType, glyphSpell
end

local function LayoutGlyphFrame()
	local glyphFrame = _G.GlyphFrame
	if not glyphFrame then return end
	local data = Data(glyphFrame)
	local ar, ag, ab = WSkin:GetRetailAccent()

	if not data.majorHeader then
		data.majorHeader = glyphFrame:CreateFontString(nil, "OVERLAY")
		WSkin:ApplyRetailTypography(data.majorHeader, "section")
		data.majorHeader:SetText(EllesmereUI.L("MAJOR GLYPHS"))
		data.majorHeader:SetJustifyH("LEFT")
		data.majorHeader:SetPoint("TOPLEFT", glyphFrame, "TOPLEFT", CONTROL_LEFT, -54)
		data.majorHeader:SetWidth(158)

		data.minorHeader = glyphFrame:CreateFontString(nil, "OVERLAY")
		WSkin:ApplyRetailTypography(data.minorHeader, "section")
		data.minorHeader:SetText(EllesmereUI.L("MINOR GLYPHS"))
		data.minorHeader:SetJustifyH("LEFT")
		data.minorHeader:SetPoint("TOPLEFT", glyphFrame, "TOPLEFT", 202, -54)
		data.minorHeader:SetWidth(158)

		data.majorRule = glyphFrame:CreateTexture(nil, "ARTWORK")
		data.majorRule:SetPoint("TOPLEFT", glyphFrame, "TOPLEFT", CONTROL_LEFT, -72)
		data.majorRule:SetSize(158, 1)

		data.minorRule = glyphFrame:CreateTexture(nil, "ARTWORK")
		data.minorRule:SetPoint("TOPLEFT", glyphFrame, "TOPLEFT", 202, -72)
		data.minorRule:SetSize(158, 1)
	end

	data.majorHeader:SetTextColor(ar, ag, ab, 0.95)
	data.minorHeader:SetTextColor(0.52, 0.70, 1.00, 0.90)
	data.majorRule:SetTexture(ar, ag, ab, 0.48)
	data.minorRule:SetTexture(0.35, 0.58, 1.00, 0.42)

	local rows = { [GLYPH_TYPE_MAJOR] = 0, [GLYPH_TYPE_MINOR] = 0 }
	for id = 1, Count(_G.NUM_GLYPH_SLOTS, 6) do
		local slot = _G["GlyphFrameGlyph" .. id]
		if slot then
			local _, glyphType = GetGlyphSlotInfo(slot, id)
			glyphType = glyphType == GLYPH_TYPE_MINOR and GLYPH_TYPE_MINOR or GLYPH_TYPE_MAJOR
			rows[glyphType] = rows[glyphType] + 1
			local x = glyphType == GLYPH_TYPE_MINOR and GLYPH_MINOR_LEFT or CONTROL_LEFT
			local y = GLYPH_ROW_TOP - ((rows[glyphType] - 1) * GLYPH_ROW_SPACING)
			slot:ClearAllPoints()
			slot:SetPoint("TOPLEFT", glyphFrame, "TOPLEFT", x, y)
			slot:SetSize(158, 68)
			slot:SetHitRectInsets(0, 0, 0, 0)
		end
		local sparkle = _G["GlyphFrameSparkle" .. id]
		if sparkle then sparkle:SetAlpha(0) end
	end
end

local function StyleGlyphSlot(slot)
	if not slot then return end
	local data = Data(slot)
	if not data.surface then
		WSkin:ApplyRetailSurface(slot, "row")
		data.surface = true

		data.iconBorder = slot:CreateTexture(nil, "BACKGROUND", nil, 1)
		data.iconBorder:SetSize(48, 48)
		data.iconBorder:SetPoint("LEFT", slot, "LEFT", 11, 0)

		data.iconWell = slot:CreateTexture(nil, "BACKGROUND", nil, 2)
		data.iconWell:SetSize(46, 46)
		data.iconWell:SetPoint("CENTER", data.iconBorder, "CENTER", 0, 0)
		data.iconWell:SetTexture(0.012, 0.018, 0.021, 0.96)

		data.emptyMark = slot:CreateFontString(nil, "OVERLAY")
		data.emptyMark:SetPoint("CENTER", data.iconBorder, "CENTER", 0, 0)
		WSkin:ApplyRetailTypography(data.emptyMark, "section", 0.42)

		data.nameLabel = slot:CreateFontString(nil, "OVERLAY")
		data.nameLabel:SetPoint("TOPLEFT", slot, "TOPLEFT", 68, -13)
		data.nameLabel:SetSize(82, 27)
		data.nameLabel:SetJustifyH("LEFT")
		data.nameLabel:SetJustifyV("TOP")
		WSkin:ApplyRetailTypography(data.nameLabel, "row", 0.92)

		data.typeLabel = slot:CreateFontString(nil, "OVERLAY")
		WSkin:ApplyRetailTypography(data.typeLabel, "secondary", 0.90)
		data.typeLabel:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 68, 12)
		data.typeLabel:SetSize(82, 12)
		data.typeLabel:SetJustifyH("LEFT")
	end

	local enabled, glyphType, glyphSpell = GetGlyphSlotInfo(slot)

	-- Blizzard still owns the glyph data, tooltips, drag/drop, animation timing,
	-- and the actual icon. Only the ornamental rune plate is replaced.
	for _, texture in ipairs({ slot.setting, slot.background, slot.ring, slot.shine }) do
		if texture and texture.SetTexture then
			-- SetTexture(nil), rather than an empty path, reliably clears these
			-- regions on 3.3.5 clients. Their shown state remains Blizzard-owned
			-- because its glyph targeting code reads background:IsShown().
			texture:SetTexture(nil)
		end
	end
	if slot.highlight then
		slot.highlight:SetTexture(1, 1, 1, 0.10)
		slot.highlight:ClearAllPoints()
		slot.highlight:SetAllPoints(slot)
	end
	if slot.glyph then
		slot.glyph:ClearAllPoints()
		slot.glyph:SetPoint("CENTER", data.iconBorder, "CENTER", 0, 0)
		slot.glyph:SetSize(44, 44)
		slot.glyph:SetTexCoord(unpack(TEXCOORDS))
		if glyphSpell then WSkin:ApplyRetailIcon(slot.glyph, slot, 44) end
		WSkin:SetRetailIconShown(slot.glyph, glyphSpell and true or false)
	end

	local ar, ag, ab = WSkin:GetRetailAccent()
	local minor = glyphType == GLYPH_TYPE_MINOR
	local glyphName
	if glyphSpell and type(_G.GetSpellInfo) == "function" then
		glyphName = _G.GetSpellInfo(glyphSpell)
	end

	data.iconBorder:SetTexture(1, 1, 1, glyphSpell and 0.16 or 0.08)
	data.typeLabel:SetText(minor and EllesmereUI.L("MINOR GLYPH") or EllesmereUI.L("MAJOR GLYPH"))
	data.typeLabel:SetTextColor(minor and 0.52 or ar, minor and 0.70 or ag, minor and 1.00 or ab, 0.90)

	if not enabled then
		slot:SetBackdropBorderColor(1, 1, 1, 0.05)
		slot:SetBackdropColor(0.020, 0.026, 0.030, 0.42)
		data.nameLabel:SetText(EllesmereUI.L("Locked slot"))
		data.nameLabel:SetTextColor(1, 1, 1, 0.34)
		data.emptyMark:SetText("-")
		data.emptyMark:SetTextColor(1, 1, 1, 0.28)
		data.emptyMark:Show()
	elseif minor then
		slot:SetBackdropBorderColor(0.35, 0.58, 1.00, 0.42)
		slot:SetBackdropColor(0.030, 0.043, 0.048, glyphSpell and 0.82 or 0.60)
		data.nameLabel:SetText(glyphName or EllesmereUI.L("Empty slot"))
		data.nameLabel:SetTextColor(1, 1, 1, glyphSpell and 0.92 or 0.58)
		data.emptyMark:SetText("+")
		data.emptyMark:SetTextColor(0.52, 0.70, 1.00, 0.70)
		if glyphSpell then data.emptyMark:Hide() else data.emptyMark:Show() end
	else
		slot:SetBackdropBorderColor(ar, ag, ab, 0.55)
		slot:SetBackdropColor(0.030, 0.043, 0.048, glyphSpell and 0.82 or 0.60)
		data.nameLabel:SetText(glyphName or EllesmereUI.L("Empty slot"))
		data.nameLabel:SetTextColor(1, 1, 1, glyphSpell and 0.92 or 0.58)
		data.emptyMark:SetText("+")
		data.emptyMark:SetTextColor(ar, ag, ab, 0.72)
		if glyphSpell then data.emptyMark:Hide() else data.emptyMark:Show() end
	end
end

local function SyncGlyphTitle()
	local glyphTitle = _G.GlyphFrameTitleText
	if glyphTitle then
		glyphTitle:SetAlpha(0)
		glyphTitle:Hide()
	end

	local parentTitle = _G.PlayerTalentFrameTitleText
	if not parentTitle then return end
	parentTitle:SetAlpha(1)
	parentTitle:Show()
	if _G.GlyphFrame and _G.GlyphFrame:IsShown() then
		local text = glyphTitle and glyphTitle:GetText()
		parentTitle:SetText((text and text ~= "") and text or (_G.GLYPHS or EllesmereUI.L("Glyphs")))
	end
end

local function HideTalentControlsForGlyph()
	local glyphFrame = _G.GlyphFrame
	if not glyphFrame or not glyphFrame:IsShown() then return end
	for _, control in ipairs({
		_G.PlayerTalentFrameStatusFrame,
		_G.PlayerTalentFrameActivateButton,
		_G.PlayerTalentFramePointsBar,
		_G.PlayerTalentFramePreviewBar,
		_G.PlayerTalentFrameScrollFrame,
		_G.PlayerTalentFrameActiveTalentGroupFrame,
	}) do
		if control then control:Hide() end
	end
end

local function RestoreTalentControlsAfterGlyph()
	-- These two frames are not explicitly shown by Blizzard's talent refresh;
	-- the stock glyph artwork merely covers them. Restore them before the
	-- native refresh decides which of the conditional controls should appear.
	if _G.PlayerTalentFramePointsBar then _G.PlayerTalentFramePointsBar:Show() end
	if _G.PlayerTalentFrameScrollFrame then _G.PlayerTalentFrameScrollFrame:Show() end
end

local function SkinGlyphs()
	local glyphFrame = _G.GlyphFrame
	if not glyphFrame then return end
	local data = Data(glyphFrame)
	if not data.skinned then
		data.skinned = true
		-- Kill the stock circular page and pulse glow before creating our rows.
		-- This also prevents GlyphFrame_PulseGlow from reviving the old art.
		WSkin:StripTextures(glyphFrame, true)
		SyncGlyphTitle()
		LayoutGlyphFrame()

		for i = 1, Count(_G.NUM_GLYPH_SLOTS, 6) do
			StyleGlyphSlot(_G["GlyphFrameGlyph" .. i])
		end

		glyphFrame:HookScript("OnShow", function()
			SyncGlyphTitle()
			LayoutGlyphFrame()
			for i = 1, Count(_G.NUM_GLYPH_SLOTS, 6) do
				StyleGlyphSlot(_G["GlyphFrameGlyph" .. i])
			end
			HideTalentControlsForGlyph()
			UpdateBottomTabs()
		end)
		glyphFrame:HookScript("OnHide", function()
			SyncGlyphTitle()
			RestoreTalentControlsAfterGlyph()
			UpdateBottomTabs()
		end)
	end

	if not glyphHooked and type(_G.GlyphFrameGlyph_UpdateSlot) == "function" then
		glyphHooked = true
		hooksecurefunc("GlyphFrameGlyph_UpdateSlot", StyleGlyphSlot)
	end
	if not glyphTitleHooked and type(_G.PlayerTalentFrame_ShowGlyphFrame) == "function" then
		glyphTitleHooked = true
		hooksecurefunc("PlayerTalentFrame_ShowGlyphFrame", SyncGlyphTitle)
	end
	if not glyphAnimationHooked and type(_G.GlyphFrame_StartSlotAnimation) == "function" then
		glyphAnimationHooked = true
		hooksecurefunc("GlyphFrame_StartSlotAnimation", function(slotID)
			-- The stock sparkle paths are hard-coded for the old circular rune
			-- layout. Keep their timing alive but suppress the misplaced art.
			local sparkle = _G["GlyphFrameSparkle" .. slotID]
			if sparkle then sparkle:SetAlpha(0) end
		end)
	end
	LayoutGlyphFrame()
	for i = 1, Count(_G.NUM_GLYPH_SLOTS, 6) do
		StyleGlyphSlot(_G["GlyphFrameGlyph" .. i])
	end
	SyncGlyphTitle()
	HideTalentControlsForGlyph()
end

local function SkinTalents()
	if not WSkin:IsSkinEnabled("playerspells") then return end
	local frame = _G.PlayerTalentFrame
	if not frame then return end

	frame:SetHeight(FRAME_HEIGHT)
	WSkin:StripTextures(frame, true)
	WSkin:CreateRetailWindowShell(
		frame,
		_G.TALENTS or "Talents",
		_G.PlayerTalentFrameTitleText,
		_G.PlayerTalentFrameCloseButton,
		{ content = false }
	)
	LayoutTalentFrame()
	WSkin:SetUIPanelWindowInfo(frame, "width", frame:GetWidth())

	for _, panel in ipairs({
		_G.PlayerTalentFrameStatusFrame,
		_G.PlayerTalentFramePointsBar,
		_G.PlayerTalentFramePreviewBar,
	}) do
		if panel then
			WSkin:StripTextures(panel)
			WSkin:ApplyRetailSurface(panel, panel == _G.PlayerTalentFrameStatusFrame and "input" or "header")
		end
	end
	WSkin:StripTextures(_G.PlayerTalentFramePreviewBarFiller)
	SetFont(_G.PlayerTalentFrameStatusText, "row")
	SetFont(_G.PlayerTalentFrameSpentPointsText, "secondary")
	SetFont(_G.PlayerTalentFrameTalentPointsText, "value")

	WSkin:HandleRetailButton(_G.PlayerTalentFrameActivateButton, true)
	WSkin:HandleRetailButton(_G.PlayerTalentFrameResetButton)
	WSkin:HandleRetailButton(_G.PlayerTalentFrameLearnButton, true)

	StyleTalentArtwork()
	WSkin:HandleRetailScrollBar(_G.PlayerTalentFrameScrollFrameScrollBar)
	if _G.PlayerTalentFrameActiveTalentGroupFrame and _G.PlayerTalentFrameActiveTalentGroupFrame.SetBackdrop then
		_G.PlayerTalentFrameActiveTalentGroupFrame:SetBackdrop(nil)
	end

	LayoutTalentFrame()
	UpdateBottomTabs()
	StyleSpecTabs()
	UpdateTalentButtons()
	LayoutTalentConnectors()

	for i = 1, 4 do
		local tab = _G["PlayerTalentFrameTab" .. i]
		if tab then
			local tabIndex = i
			tab:HookScript("OnClick", function()
				UpdateBottomTabs()
				if tabIndex < 4 then ResetTalentScroll() end
			end)
		end
	end
	frame:HookScript("OnShow", function()
		LayoutTalentFrame()
		ResetTalentScroll()
		UpdateBottomTabs()
		StyleSpecTabs()
		UpdateTalentButtons()
		SkinGlyphs()
		HideTalentControlsForGlyph()
	end)

	if type(_G.PlayerTalentFrame_Update) == "function" then
		hooksecurefunc("PlayerTalentFrame_Update", function()
			LayoutTalentFrame()
			StyleTalentArtwork()
			UpdateTalentButtons()
			StyleSpecTabs()
			UpdateBottomTabs()
			SyncGlyphTitle()
			HideTalentControlsForGlyph()
		end)
	end
	-- PlayerTalentFrame_UpdateControls owns the stock points-bar anchor and can
	-- also be called directly. Reapply the compact footer after it runs so its
	-- original 81px bottom offset cannot collapse the talent viewport again.
	if type(_G.PlayerTalentFrame_UpdateControls) == "function" then
		hooksecurefunc("PlayerTalentFrame_UpdateControls", LayoutTalentFrame)
	end
	if type(_G.PlayerTalentFrame_UpdateSpecs) == "function" then
		hooksecurefunc("PlayerTalentFrame_UpdateSpecs", StyleSpecTabs)
	end
	-- Wrath's generic talent updater hard-codes the original 63px grid after
	-- PlayerTalentFrame_Update has finished. Post-process that completed layout
	-- so buttons, branch lines, and arrows all share the expanded canvas grid.
	if not talentUpdateHooked and type(_G.TalentFrame_Update) == "function" then
		talentUpdateHooked = true
		hooksecurefunc("TalentFrame_Update", function(updatedFrame)
			if updatedFrame ~= frame then return end
			UpdateTalentButtons()
			LayoutTalentConnectors()
			StyleTalentArtwork()
		end)
	end

	-- Rebuild the already-visible tree once so the widened geometry is applied
	-- immediately; the generic post-hook keeps later refreshes on that grid.
	if type(_G.PlayerTalentFrame_Refresh) == "function" then
		_G.PlayerTalentFrame_Refresh()
	elseif type(_G.TalentFrame_Update) == "function" then
		_G.TalentFrame_Update(frame)
	end

	SkinGlyphs()
	if _G.C_Timer and _G.C_Timer.After then _G.C_Timer.After(0, SkinGlyphs) end
end

WSkin:AddCallbackForAddon("Blizzard_TalentUI", "Skin_Talent", SkinTalents, "playerspells")
WSkin:AddCallbackForAddon("Blizzard_GlyphUI", "Skin_Glyphs", function()
	if WSkin:IsSkinEnabled("playerspells") then SkinGlyphs() end
end, "playerspells")
