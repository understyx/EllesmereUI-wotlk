local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local CreateFrame = CreateFrame
local GetItemQualityColor = GetItemQualityColor
local GetLootRollItemInfo = GetLootRollItemInfo
local GetLootSlotInfo = GetLootSlotInfo
local hooksecurefunc = hooksecurefunc
local max = math.max
local select = select
local type = type
local unpack = unpack

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
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

local function HideFrameTextures(frame, keep)
	if not frame or not frame.GetRegions then return end
	for i = 1, select("#", frame:GetRegions()) do
		local region = select(i, frame:GetRegions())
		if IsTexture(region) and (not keep or region ~= keep) then
			HideTexture(region)
		end
	end
end

-- Use the configured Blizzard-skin face without overwriting Blizzard's text
-- color. Loot item names use that color to communicate item quality.
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

local function FontFrameRegions(frame, size)
	if not frame or not frame.GetRegions then return end
	for i = 1, select("#", frame:GetRegions()) do
		local region = select(i, frame:GetRegions())
		if IsFontString(region) then FontOnly(region, size) end
	end
end

local function QualityColor(quality)
	if type(quality) == "number" and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(quality)
		if r then return r, g, b end
	end
	return 1, 1, 1
end

local function CreateInsetPanel(owner, topLeftX, topLeftY, bottomRightX, bottomRightY)
	local data = State(owner)
	if not data.panel then
		data.panel = CreateFrame("Frame", nil, owner)
		data.panel:EnableMouse(false)
	end
	local panel = data.panel
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", owner, "TOPLEFT", topLeftX, topLeftY)
	panel:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", bottomRightX, bottomRightY)
	panel:SetFrameLevel(max(0, owner:GetFrameLevel() - 1))
	WSkin:ApplyRetailSurface(panel, "body")
	panel:Show()
	return panel
end

-------------------------------------------------------------------------------
-- Corpse / container loot window
-------------------------------------------------------------------------------
local function SkinLootButton(index)
	local button = _G["LootButton" .. index]
	if not button then return end

	local data = State(button)
	local icon = _G["LootButton" .. index .. "IconTexture"]
	local nameFrame = _G["LootButton" .. index .. "NameFrame"]
	-- NameFrame is a Texture on the stock 3.3.5 template, but some clients
	-- expose it as a child frame. Cover both shapes.
	HideTexture(nameFrame)
	HideFrameTextures(nameFrame)
	HideFrameTextures(button, icon)

	WSkin:ApplyRetailSurface(button, "row")
	if icon then
		icon:SetAlpha(1)
		icon:SetTexCoord(unpack(WSkin.TexCoords or { 0.08, 0.92, 0.08, 0.92 }))
		if not data.iconBorder then
			data.iconBorder = button:CreateTexture(nil, "BACKGROUND", nil, 3)
			data.iconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
			data.iconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
		end
		data.iconBorder:SetTexture(1, 1, 1, 0.14)
		data.iconBorder:SetAlpha(1)
		data.iconBorder:Show()
	end

	FontFrameRegions(button, 11)
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then
		highlight:SetTexture(1, 1, 1, 0.08)
		highlight:SetAllPoints(button)
		highlight:SetAlpha(1)
	end

	local lootFrame = _G.LootFrame
	local numLootItems = lootFrame and lootFrame.numLootItems or 0
	local numVisible = _G.LOOTFRAME_NUMBUTTONS or 4
	if numLootItems > numVisible then numVisible = numVisible - 1 end
	local page = lootFrame and lootFrame.page or 1
	local slot = (numVisible * (page - 1)) + index
	if slot <= numLootItems and GetLootSlotInfo then
		local _, _, _, quality, _, isQuestItem, questId, isActive = GetLootSlotInfo(slot)
		local r, g, b
		if questId and not isActive then
			r, g, b = 1, 1, 0
		elseif questId or isQuestItem then
			r, g, b = 1, 0.3, 0.3
		else
			r, g, b = QualityColor(quality)
		end
		button:SetBackdropBorderColor(r, g, b, 0.65)
		if data.iconBorder then data.iconBorder:SetTexture(r, g, b, 0.85) end
	else
		button:SetBackdropBorderColor(1, 1, 1, 0.08)
	end
end

local function SkinLootFrame()
	local frame = _G.LootFrame
	if not frame then return end

	HideFrameTextures(frame)
	HideTexture(_G.LootFramePortraitOverlay)
	HideTexture(_G.LootFrameBg)
	CreateInsetPanel(frame, 16, -54, -77, 8)

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
		up:SetSize(22, 22)
	end
	if down then
		WSkin:HandleNextPrevButton(down, "down")
		down:ClearAllPoints()
		down:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 147, 20)
		down:SetSize(22, 22)
	end

	local title = _G.LootFrameTitleText
	if not title and frame.GetRegions then
		for i = 1, select("#", frame:GetRegions()) do
			local region = select(i, frame:GetRegions())
			if IsFontString(region) then
				title = region
				break
			end
		end
	end
	if title then
		FontOnly(title, 12)
		title:SetTextColor(1, 1, 1)
		title:ClearAllPoints()
		title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -58)
		title:SetWidth(140)
		title:SetJustifyH("LEFT")
		title:SetWordWrap(false)
	end

	for i = 1, (_G.LOOTFRAME_NUMBUTTONS or 4) do SkinLootButton(i) end
end

-------------------------------------------------------------------------------
-- Need / greed roll panels
-------------------------------------------------------------------------------
local ROLL_WIDTH = 365
local ROLL_HEIGHT = 28
local ROLL_BUTTON_SIZE = 22

local ROLL_BUTTON_TEXTURES = {
	need = {
		normal = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
		pushed = "Interface\\Buttons\\UI-GroupLoot-Dice-Down",
		highlight = "Interface\\Buttons\\UI-GroupLoot-Dice-Highlight",
	},
	greed = {
		normal = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
		pushed = "Interface\\Buttons\\UI-GroupLoot-Coin-Down",
		highlight = "Interface\\Buttons\\UI-GroupLoot-Coin-Highlight",
	},
	disenchant = {
		normal = "Interface\\Buttons\\UI-GroupLoot-DE-Up",
		pushed = "Interface\\Buttons\\UI-GroupLoot-DE-Down",
		highlight = "Interface\\Buttons\\UI-GroupLoot-DE-Highlight",
	},
	pass = {
		normal = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
		pushed = "Interface\\Buttons\\UI-GroupLoot-Pass-Down",
		highlight = "Interface\\Buttons\\UI-GroupLoot-Pass-Down",
	},
}

local function FillButtonTexture(texture, button)
	if not texture or not button then return end
	texture:ClearAllPoints()
	texture:SetAllPoints(button)
	texture:SetAlpha(1)
end

local function StyleRollChoice(button, rollType)
	if not button then return end
	local data = State(button)
	local textures = ROLL_BUTTON_TEXTURES[rollType]
	if not data.choiceStyled then
		data.choiceStyled = true
		button:SetBackdrop(nil)
	end
	button:SetSize(ROLL_BUTTON_SIZE, ROLL_BUTTON_SIZE)
	if textures then
		button:SetNormalTexture(textures.normal)
		button:SetPushedTexture(textures.pushed)
		button:SetHighlightTexture(textures.highlight)
		FillButtonTexture(button:GetNormalTexture(), button)
		FillButtonTexture(button:GetPushedTexture(), button)
		FillButtonTexture(button:GetHighlightTexture(), button)
	end
end

local function SkinGroupLootFrame(frame)
	if not frame then return end
	local frameName = frame.GetName and frame:GetName()
	if not frameName then return end

	local iconFrame = _G[frameName .. "IconFrame"]
	local icon = _G[frameName .. "IconFrameIcon"]
	local timer = _G[frameName .. "Timer"]
	local decoration = _G[frameName .. "Decoration"]
	local corner = _G[frameName .. "Corner"]
	local pass = frame.passButton or _G[frameName .. "PassButton"]
	local need = frame.needButton or _G[frameName .. "RollButton"] or _G[frameName .. "NeedButton"]
	local greed = frame.greedButton or _G[frameName .. "GreedButton"]
	local disenchant = frame.disenchantButton or _G[frameName .. "DisenchantButton"]
	local name = _G[frameName .. "Name"]
	local data = State(frame)

	HideFrameTextures(frame)
	HideTexture(decoration)
	HideTexture(corner)
	HideTexture(_G[frameName .. "SlotTexture"])
	HideTexture(_G[frameName .. "NameFrame"])
	frame:SetSize(ROLL_WIDTH, ROLL_HEIGHT)
	WSkin:ApplyRetailSurface(frame, "card")
	frame:SetBackdropColor(0.015, 0.020, 0.025, 0.68)
	frame:SetBackdropBorderColor(0, 0, 0, 0.80)

	if iconFrame then
		HideFrameTextures(iconFrame, icon)
		iconFrame:ClearAllPoints()
		iconFrame:SetPoint("RIGHT", frame, "LEFT", -4, 0)
		iconFrame:SetSize(ROLL_HEIGHT - 2, ROLL_HEIGHT - 2)
		WSkin:ApplyRetailSurface(iconFrame, "card")
	end
	if icon then
		icon:SetAlpha(1)
		icon:ClearAllPoints()
		icon:SetAllPoints(iconFrame)
		icon:SetTexCoord(unpack(WSkin.TexCoords or { 0.08, 0.92, 0.08, 0.92 }))
	end

	if timer then
		local statusTexture = timer.GetStatusBarTexture and timer:GetStatusBarTexture()
		HideFrameTextures(timer, statusTexture)
		timer:ClearAllPoints()
		timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
		timer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
		timer:SetHeight(6)
		timer:SetStatusBarTexture(WHITE_TEXTURE)
		WSkin:ApplyRetailSurface(timer, "input")
		timer:SetBackdropColor(0, 0, 0, 0.80)
		timer:SetBackdropBorderColor(0, 0, 0, 1)
	end

	StyleRollChoice(need, "need")
	StyleRollChoice(greed, "greed")
	StyleRollChoice(disenchant, "disenchant")
	StyleRollChoice(pass, "pass")

	-- The stock template arranges these buttons in two rows. The compact skin
	-- puts the choices in their familiar need/greed/disenchant/pass order.
	if pass then
		pass:ClearAllPoints()
		pass:SetPoint("RIGHT", frame, "RIGHT", -1, 3)
	end
	if disenchant and pass then
		disenchant:ClearAllPoints()
		disenchant:SetPoint("RIGHT", pass, "LEFT", -1, 0)
	end
	if greed and disenchant then
		greed:ClearAllPoints()
		greed:SetPoint("RIGHT", disenchant, "LEFT", -1, 0)
	end
	if need and greed then
		need:ClearAllPoints()
		need:SetPoint("RIGHT", greed, "LEFT", -1, 0)
	end

	if not data.bindText then
		data.bindText = frame:CreateFontString(nil, "OVERLAY")
		data.bindText:SetJustifyH("RIGHT")
	end
	FontOnly(data.bindText, 10)
	data.bindText:ClearAllPoints()
	if need then
		data.bindText:SetPoint("RIGHT", need, "LEFT", -4, 0)
	else
		data.bindText:SetPoint("RIGHT", frame, "RIGHT", -100, 3)
	end
	data.bindText:SetSize(28, 18)
	data.bindText:Show()

	if name then
		FontOnly(name, 11)
		name:ClearAllPoints()
		name:SetPoint("LEFT", frame, "LEFT", 4, 3)
		name:SetPoint("RIGHT", data.bindText, "LEFT", -5, 0)
		name:SetHeight(18)
		name:SetJustifyH("LEFT")
		name:SetWordWrap(false)
	end

	FontFrameRegions(frame, 11)
	if iconFrame then FontFrameRegions(iconFrame, 11) end

	local quality, bindOnPickUp
	if frame.rollID and GetLootRollItemInfo then
		local _, _, _, itemQuality, itemBinds = GetLootRollItemInfo(frame.rollID)
		quality = itemQuality
		bindOnPickUp = itemBinds
	end
	local r, g, b = QualityColor(quality)
	if iconFrame then iconFrame:SetBackdropBorderColor(r, g, b, 0.90) end
	-- The compact reference uses a consistent cool-blue countdown rather than
	-- duplicating the item's rarity color in both the name and the timer.
	if timer then timer:SetStatusBarColor(0.35, 0.40, 0.90, 0.92) end
	data.bindText:SetText(bindOnPickUp and "BoP" or "BoE")
	if bindOnPickUp then
		data.bindText:SetTextColor(1, 0.28, 0.12, 1)
	else
		data.bindText:SetTextColor(0.30, 1, 0.35, 1)
	end
end

local function SkinAllGroupLootFrames()
	for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or 4) do
		local frame = _G["GroupLootFrame" .. i]
		SkinGroupLootFrame(frame)
		if i > 1 and frame then
			local previous = _G["GroupLootFrame" .. (i - 1)]
			if previous then
				frame:ClearAllPoints()
				frame:SetPoint("BOTTOM", previous, "TOP", 0, 4)
			end
		end
	end
end

WSkin:AddCallback("Skin_Loot", function()
	if not WSkin:IsSkinEnabled("loot") then return end

	SkinLootFrame()
	SkinAllGroupLootFrames()

	if hooksecurefunc and _G.LootFrame_UpdateButton then
		hooksecurefunc("LootFrame_UpdateButton", SkinLootButton)
	end
	if _G.LootFrame then
		_G.LootFrame:HookScript("OnShow", SkinLootFrame)
	end
	for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or 4) do
		local frame = _G["GroupLootFrame" .. i]
		if frame then frame:HookScript("OnShow", SkinGroupLootFrame) end
	end
end, "loot")
