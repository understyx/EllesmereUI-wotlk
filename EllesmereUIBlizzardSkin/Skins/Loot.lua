local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local CreateFrame = CreateFrame
local GetItemQualityColor = GetItemQualityColor
local GetLootRollItemInfo = GetLootRollItemInfo
local GetLootSlotInfo = GetLootSlotInfo
local hooksecurefunc = hooksecurefunc
local select = select
local type = type
local unpack = unpack

local ITEMS_TEXT = ITEMS or "Items"
local LOOT_TEXT = LOOT or "Loot"
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local QUEST_BORDER = "Interface\\ContainerFrame\\UI-Icon-QuestBorder"
local state = setmetatable({}, { __mode = "k" })

local function State(frame)
	local data = state[frame]
	if not data then
		data = {}
		state[frame] = data
	end
	return data
end

local function IsTexture(region)
	return region and region.IsObjectType and region:IsObjectType("Texture")
end

local function IsFontString(region)
	return region and region.IsObjectType and region:IsObjectType("FontString")
end

local function HideTexture(texture)
	if not texture then return end
	if texture.SetTexture then texture:SetTexture("") end
	if texture.SetAlpha then texture:SetAlpha(0) end
end

local function FontOnly(fontString, size)
	if not fontString or not fontString.SetFont then return end
	local font = (EllesmereUI and EllesmereUI.GetFontPath
		and EllesmereUI.GetFontPath("blizzardSkin")) or STANDARD_TEXT_FONT
	local outline = (EllesmereUI and EllesmereUI.GetFontOutlineFlag
		and EllesmereUI.GetFontOutlineFlag("blizzardSkin")) or ""
	fontString:SetFont(font, size or 11, outline)
	if outline == "" then
		fontString:SetShadowOffset(1, -1)
		fontString:SetShadowColor(0, 0, 0, 0.8)
	else
		fontString:SetShadowOffset(0, 0)
		fontString:SetShadowColor(0, 0, 0, 0)
	end
end

local function QualityColor(quality)
	if type(quality) == "number" and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(quality)
		if r then return r, g, b end
	end
	return 0.2, 0.2, 0.2
end

-------------------------------------------------------------------------------
-- Corpse and container loot window
-------------------------------------------------------------------------------
local function FindLootTitle(frame)
	local named = _G.LootFrameTitleText
	if named then return named end
	if not frame or not frame.GetRegions then return end

	local fallback
	for i = 1, select("#", frame:GetRegions()) do
		local region = select(i, frame:GetRegions())
		if IsFontString(region) then
			fallback = fallback or region
			if region:GetText() == ITEMS_TEXT then return region end
		end
	end
	return fallback
end

local function UpdateLootTitle(frame)
	local title = State(frame).title
	if not title then return end
	if IsFishingLoot and IsFishingLoot() then
		title:SetText((EllesmereUI and EllesmereUI.L and EllesmereUI.L("Fishy Loot")) or "Fishy Loot")
	elseif UnitIsFriend and UnitIsDead and UnitName
		and not UnitIsFriend("player", "target") and UnitIsDead("target") then
		title:SetText(UnitName("target") or LOOT_TEXT)
	else
		title:SetText(LOOT_TEXT)
	end
end

local function UpdateLootButton(index)
	local frame = _G.LootFrame
	local button = _G["LootButton" .. index]
	if not frame or not button or not button.backdrop then return end

	local data = State(button)
	local numLootItems = frame.numLootItems or 0
	local visibleButtons = _G.LOOTFRAME_NUMBUTTONS or 4
	if numLootItems > visibleButtons then visibleButtons = visibleButtons - 1 end
	local slot = (visibleButtons * ((frame.page or 1) - 1)) + index

	button.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2)
	if data.questTexture then data.questTexture:Hide() end
	if slot > numLootItems or index > visibleButtons or not GetLootSlotInfo then return end
	if LootSlotIsItem and LootSlotIsCoin
		and not (LootSlotIsItem(slot) or LootSlotIsCoin(slot)) then return end

	local texture, _, _, quality, _, isQuestItem, questId, isActive = GetLootSlotInfo(slot)
	if not texture then return end
	if questId and not isActive then
		button.backdrop:SetBackdropBorderColor(1, 1, 0)
		if data.questTexture then data.questTexture:Show() end
	elseif questId or isQuestItem then
		button.backdrop:SetBackdropBorderColor(1, 0.3, 0.3)
	elseif quality then
		button.backdrop:SetBackdropBorderColor(QualityColor(quality))
	end
end

local function SkinLootButton(index)
	local button = _G["LootButton" .. index]
	if not button then return end
	local data = State(button)

	if not data.skinned then
		data.skinned = true
		local icon = WSkin:HandleItemButton(button, true)
		local nameFrame = _G["LootButton" .. index .. "NameFrame"]
		if nameFrame then
			if IsTexture(nameFrame) then HideTexture(nameFrame) else nameFrame:Hide() end
		end

		data.nameBackground = CreateFrame("Frame", nil, button)
		WSkin:SetTemplate(data.nameBackground, "Default")
		data.nameBackground:SetPoint("TOPLEFT", button, "TOPLEFT", 40, 0)
		data.nameBackground:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 110, 0)
		data.nameBackground:SetFrameLevel(math.max(0, data.nameBackground:GetFrameLevel() - 1))

		data.questTexture = button:CreateTexture(nil, "OVERLAY")
		data.questTexture:SetTexture(QUEST_BORDER)
		if icon then
			data.questTexture:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
			data.questTexture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -4)
		else
			data.questTexture:SetAllPoints(button)
		end
		data.questTexture:Hide()

		if button.GetRegions then
			for i = 1, select("#", button:GetRegions()) do
				local region = select(i, button:GetRegions())
				if IsFontString(region) then FontOnly(region, 11) end
			end
		end
	end
	UpdateLootButton(index)
end

local function SkinLootFrame()
	local frame = _G.LootFrame
	if not frame then return end
	local data = State(frame)

	if not data.skinned then
		data.skinned = true
		WSkin:StripTextures(frame)
		HideTexture(_G.LootFramePortraitOverlay)
		HideTexture(_G.LootFrameBg)
		WSkin:CreateBackdrop(frame, "Transparent")
		frame.backdrop:ClearAllPoints()
		frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -54)
		frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -77, 8)
		WSkin:SetBackdropHitRect(frame, frame.backdrop, true)

		local close = _G.LootCloseButton or _G.LootFrameCloseButton
		if close then
			WSkin:HandleCloseButton(close)
			close:ClearAllPoints()
			close:SetPoint("CENTER", frame, "TOPRIGHT", -88, -65)
		end

		local up = _G.LootFrameUpButton
		local down = _G.LootFrameDownButton
		if up then
			WSkin:HandleNextPrevButton(up, "up")
			up:ClearAllPoints()
			up:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 25, 20)
			up:SetSize(24, 24)
		end
		if down then
			WSkin:HandleNextPrevButton(down, "down")
			down:ClearAllPoints()
			down:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 147, 21)
			down:SetSize(24, 24)
		end

		frame:EnableMouseWheel(true)
		frame:SetScript("OnMouseWheel", function(_, delta)
			if delta > 0 then
				if up and up:IsShown() and up:IsEnabled() == 1 and LootFrame_PageUp then LootFrame_PageUp() end
			elseif down and down:IsShown() and down:IsEnabled() == 1 and LootFrame_PageDown then
				LootFrame_PageDown()
			end
		end)

		data.title = FindLootTitle(frame)
		if data.title then
			FontOnly(data.title, 12)
			data.title:SetTextColor(1, 1, 1)
			data.title:ClearAllPoints()
			data.title:SetPoint("TOPLEFT", frame.backdrop, "TOPLEFT", 4, -4)
			data.title:SetWidth(142)
			data.title:SetJustifyH("LEFT")
			data.title:SetWordWrap(false)
		end

		for i = 1, (_G.LOOTFRAME_NUMBUTTONS or 4) do SkinLootButton(i) end
	end
	UpdateLootTitle(frame)
end

-------------------------------------------------------------------------------
-- Need, greed, disenchant, and pass roll panels
-------------------------------------------------------------------------------
local function UpdateGroupLootFrame(frame)
	if not frame then return end
	local frameName = frame.GetName and frame:GetName()
	if not frameName then return end
	local iconFrame = _G[frameName .. "IconFrame"]
	local timer = _G[frameName .. "Timer"]
	local quality
	if frame.rollID and GetLootRollItemInfo then
		local _, _, _, itemQuality = GetLootRollItemInfo(frame.rollID)
		quality = itemQuality
	end
	local r, g, b = QualityColor(quality)
	if iconFrame and iconFrame.SetBackdropBorderColor then iconFrame:SetBackdropBorderColor(r, g, b) end
	if timer then timer:SetStatusBarColor(r, g, b) end
end

local function SkinGroupLootFrame(frame, index)
	if not frame then return end
	local frameName = frame.GetName and frame:GetName()
	if not frameName then return end
	local data = State(frame)

	if not data.skinned then
		data.skinned = true
		local iconFrame = _G[frameName .. "IconFrame"]
		local icon = _G[frameName .. "IconFrameIcon"]
		local timer = _G[frameName .. "Timer"]
		local decoration = _G[frameName .. "Decoration"]
		local corner = _G[frameName .. "Corner"]

		frame:EnableMouse(true)
		WSkin:StripTextures(frame)
		WSkin:SetTemplate(frame, "Transparent")
		frame:SetBackdropColor(0, 0, 0, 0.78)

		if iconFrame then
			WSkin:SetTemplate(iconFrame, "Default")
			WSkin:StyleButton(iconFrame)
		end
		if icon and iconFrame then
			icon:ClearAllPoints()
			WSkin:SetInside(icon, iconFrame)
			icon:SetTexCoord(unpack(WSkin.TexCoords))
		end

		if timer then
			WSkin:StripTextures(timer)
			WSkin:CreateBackdrop(timer, "Default")
			timer:SetStatusBarTexture(WHITE_TEXTURE)
		end

		-- ElvUI's Wrath skin deliberately keeps the familiar gold dragon and
		-- Blizzard's native roll-choice positions instead of rebuilding the row.
		if decoration then
			decoration:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Dragon")
			decoration:SetAlpha(1)
			decoration:SetSize(130, 130)
			decoration:ClearAllPoints()
			decoration:SetPoint("TOPLEFT", frame, "TOPLEFT", -37, 20)
		end
		if corner then corner:Hide() end

		local name = _G[frameName .. "Name"]
		if name then FontOnly(name, 11) end
	end
	-- Blizzard may refresh the pass button's native art as a roll is reused.
	-- Reapply the close treatment on show without replacing any button methods.
	local pass = _G[frameName .. "PassButton"]
	if pass then WSkin:HandleCloseButton(pass, frame) end

	-- Leave the first frame's anchor to Blizzard or EllesmereUI's Loot Rolls
	-- mover. Only define the relationship between subsequent roll frames.
	if index and index > 1 then
		local previous = _G["GroupLootFrame" .. (index - 1)]
		if previous then
			frame:ClearAllPoints()
			frame:SetPoint("TOP", previous, "BOTTOM", 0, -4)
		end
	end
	UpdateGroupLootFrame(frame)
end

local function SkinAllGroupLootFrames()
	for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or 4) do
		SkinGroupLootFrame(_G["GroupLootFrame" .. i], i)
	end
end

WSkin:AddCallback("Skin_Loot", function()
	if not WSkin:IsSkinEnabled("loot") then return end

	SkinLootFrame()
	SkinAllGroupLootFrames()

	if hooksecurefunc and _G.LootFrame_UpdateButton then
		hooksecurefunc("LootFrame_UpdateButton", UpdateLootButton)
	end
	if _G.LootFrame then
		_G.LootFrame:HookScript("OnShow", SkinLootFrame)
	end
	for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or 4) do
		local frame = _G["GroupLootFrame" .. i]
		if frame then
			local index = i
			frame:HookScript("OnShow", function(self) SkinGroupLootFrame(self, index) end)
		end
	end
end, "loot")
