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
	return unpack(WSkin.Retail.colors.border)
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

	button.backdrop:SetBackdropBorderColor(unpack(WSkin.Retail.colors.border))
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
		if button.backdrop then WSkin:ApplyRetailSurface(button.backdrop, "input") end
		local nameFrame = _G["LootButton" .. index .. "NameFrame"]
		if nameFrame then
			if IsTexture(nameFrame) then HideTexture(nameFrame) else nameFrame:Hide() end
		end

		data.nameBackground = CreateFrame("Frame", nil, button)
		WSkin:UpdateRetailRow(data.nameBackground, false)
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
		local close = _G.LootCloseButton or _G.LootFrameCloseButton
		local title = FindLootTitle(frame)
		-- LootFrame has transparent margins around its visible native window art.
		WSkin:SkinRetailWindow(frame, {
			closeButton = close,
			titleRegion = title,
			titlePosition = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 8, y = -6, justify = "LEFT" },
			insets = { left = 16, top = -54, right = -77, bottom = 8 },
			hitRect = { clamp = true },
			artRegions = {
				{ object = _G.LootFramePortraitOverlay, action = "stripFade" },
				{ object = _G.LootFrameBg, action = "stripFade" },
			},
		})

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

		data.title = title
		if data.title then
			WSkin:ApplyRetailTypography(data.title, "title")
			data.title:SetWidth(130)
			data.title:SetJustifyH("LEFT")
			data.title:SetWordWrap(false)
		end

		for i = 1, (_G.LOOTFRAME_NUMBUTTONS or 4) do SkinLootButton(i) end
	end
	UpdateLootTitle(frame)
end

-------------------------------------------------------------------------------
-- Need, greed, disenchant, and pass roll panels
--
-- Retail-style roll cards: the shared window shell (modern_blizz art + 1px
-- border, no title row), a squared icon with a rarity-colored frame, the item
-- name in its quality color over an item-level / type line, Blizzard's own
-- dice/coin/disenchant glyphs in a right-hand row, and a flat accent timer
-- along the bottom edge.
--
-- GroupLootFrame_OnShow calls SetBackdrop (gold border for bind-on-pickup) on
-- every roll, so all per-roll visuals re-assert from an OnShow post-hook
-- instead of being applied once.
--
-- The stack is EUI-owned: GroupLootFrame1 pins to an anchor frame that has a
-- real Unlock Mode mover ("Loot Rolls", Blizzard Windows). Visible frames
-- reflow in index order, so a finished roll in slot 1 no longer leaves a gap.
-------------------------------------------------------------------------------
local ROLL_W, ROLL_H = 328, 52
local ROLL_ICON = 38
local ROLL_BUTTON = 26
local ROLL_PASS = 22
local ROLL_GAP = 4
local ROLL_TIMER_H = 3
local ROLL_DEFAULT_POS = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 340 }
local BOP_TEXT = ITEM_BIND_ON_PICKUP or "Bind on Pickup"
local ITEM_LEVEL_FORMAT = "%d \194\183 %s"

local rollAnchor
local rollLayoutGuard = false

local function NumRollFrames()
	return _G.NUM_GROUP_LOOT_FRAMES or 4
end

local function RollScale()
	local scale = EllesmereUIDB and EllesmereUIDB.lootRollScale
	if type(scale) ~= "number" or scale <= 0 then return 1 end
	return scale
end

local function RollGrowUp()
	return EllesmereUIDB and EllesmereUIDB.lootRollGrowUp == true
end

local function ActiveProfile()
	return EllesmereUI and EllesmereUI.GetActiveProfileData and EllesmereUI.GetActiveProfileData()
end

-- Per-profile like the other Unlock Mode positions. A profile without one
-- adopts the Shifter's old "Loot Rolls" spot once, so taking over the stack
-- does not move it for users who had already placed it there.
local function GetRollPos()
	local prof = ActiveProfile()
	if not prof then return ROLL_DEFAULT_POS end
	-- false = explicitly reset to the default; never re-adopt the legacy spot.
	if prof.lootRollPos == nil then
		local legacy = EllesmereUIDB and EllesmereUIDB.shifterLootPositions
		legacy = legacy and legacy.GroupLootContainer
		if legacy and legacy.point then
			prof.lootRollPos = {
				point = legacy.point, relPoint = legacy.relPoint or legacy.point,
				x = legacy.x or 0, y = legacy.y or 0,
			}
		end
	end
	return prof.lootRollPos or ROLL_DEFAULT_POS
end

local function EnsureRollAnchor()
	if rollAnchor then return rollAnchor end
	rollAnchor = CreateFrame("Frame", "EllesmereUI_LootRollAnchor", UIParent)
	rollAnchor:EnableMouse(false)
	rollAnchor:SetSize(ROLL_W, ROLL_H)
	rollAnchor:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, ROLL_DEFAULT_POS.y)
	return rollAnchor
end

local function PositionRollAnchor()
	local anchor = EnsureRollAnchor()
	local scale = RollScale()
	anchor:SetSize(ROLL_W * scale, ROLL_H * scale)
	-- An open Unlock Mode session owns the anchor while it is dragged.
	if EllesmereUI and EllesmereUI._unlockActive then return end
	local pos = GetRollPos()
	anchor:ClearAllPoints()
	anchor:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
end

-- Pin the first visible roll to the anchor and chain the rest off it. Hidden
-- frames park on the anchor so a later Show lands in the right place before
-- the next reflow runs.
local function LayoutRollStack()
	if rollLayoutGuard then return end
	rollLayoutGuard = true
	local anchor = EnsureRollAnchor()
	local up = RollGrowUp()
	local edge = up and "BOTTOM" or "TOP"
	local scale = RollScale()
	local previous
	for i = 1, NumRollFrames() do
		local frame = _G["GroupLootFrame" .. i]
		if frame then
			if math.abs(frame:GetScale() - scale) > 0.001 then frame:SetScale(scale) end
			frame:ClearAllPoints()
			if previous and frame:IsShown() then
				if up then
					frame:SetPoint("BOTTOM", previous, "TOP", 0, ROLL_GAP)
				else
					frame:SetPoint("TOP", previous, "BOTTOM", 0, -ROLL_GAP)
				end
			else
				frame:SetPoint(edge, anchor, edge, 0, 0)
			end
			if frame:IsShown() then previous = frame end
		end
	end
	rollLayoutGuard = false
end

local function QualityChroma(quality)
	local r, g, b = QualityColor(quality)
	-- Poor and common items have no hue to read; give them the neutral
	-- border instead of a grey or white ring (same rule as Retail).
	if type(quality) ~= "number" or (math.max(r, g, b) - math.min(r, g, b)) <= 0.1 then
		return nil
	end
	return r, g, b
end

local function FindRollButtons(frame, frameName, iconFrame)
	local need = _G[frameName .. "RollButton"] or _G[frameName .. "NeedButton"]
	local greed = _G[frameName .. "GreedButton"]
	local disenchant = _G[frameName .. "DisenchantButton"]
	local pass = _G[frameName .. "PassButton"]
	if need and greed and pass then return need, greed, disenchant, pass end
	-- Fall back to the RollOnLoot ids the template assigns to each button.
	for i = 1, select("#", frame:GetChildren()) do
		local child = select(i, frame:GetChildren())
		if child ~= iconFrame and child.IsObjectType and child:IsObjectType("Button") then
			local id = child:GetID()
			if id == 1 then need = need or child
			elseif id == 2 then greed = greed or child
			elseif id == 3 then disenchant = disenchant or child
			elseif id == 0 then pass = pass or child end
		end
	end
	return need, greed, disenchant, pass
end

local function BuildRollFrame(frame, frameName)
	local data = State(frame)
	local iconFrame = _G[frameName .. "IconFrame"]
	local icon = _G[frameName .. "IconFrameIcon"]
	local count = _G[frameName .. "IconFrameCount"]
	local name = _G[frameName .. "Name"]
	local timer = _G[frameName .. "Timer"]
	local need, greed, disenchant, pass = FindRollButtons(frame, frameName, iconFrame)
	data.iconFrame, data.icon, data.name, data.timer, data.pass = iconFrame, icon, name, timer, pass
	data.decoration = _G[frameName .. "Decoration"]
	data.corner = _G[frameName .. "Corner"]

	WSkin:StripTextures(frame)
	frame:SetSize(ROLL_W, ROLL_H)
	frame:EnableMouse(true)

	-- Rarity cues the flat shell would otherwise lose: a 2px strip down the
	-- left edge and a short wash fading out behind the icon.
	data.wash = frame:CreateTexture(nil, "BORDER")
	data.wash:SetTexture(WHITE_TEXTURE)
	data.wash:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	data.wash:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	data.wash:SetWidth(ROLL_W * 0.55)
	data.strip = frame:CreateTexture(nil, "ARTWORK")
	data.strip:SetTexture(WHITE_TEXTURE)
	data.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	data.strip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	data.strip:SetWidth(2)

	if iconFrame then
		WSkin:StripTextures(iconFrame)
		iconFrame:ClearAllPoints()
		iconFrame:SetPoint("LEFT", frame, "LEFT", 10, 1)
		iconFrame:SetSize(ROLL_ICON, ROLL_ICON)
		WSkin:ApplyRetailSurface(iconFrame, "input")
		WSkin:StyleButton(iconFrame)
		if icon then
			icon:ClearAllPoints()
			WSkin:SetInside(icon, iconFrame)
			icon:SetTexCoord(unpack(WSkin.TexCoords))
		end
		if count then
			count:ClearAllPoints()
			count:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
			FontOnly(count, 11)
		end
	end

	-- Right-hand button row, pass outermost. Blizzard's glyphs stay: they read
	-- faster than any flat replacement and carry the native disabled state.
	if pass then
		pass:ClearAllPoints()
		pass:SetPoint("RIGHT", frame, "RIGHT", -6, 1)
		pass:SetSize(ROLL_PASS, ROLL_PASS)
	end
	local rightOf = pass
	-- Numeric walk: ipairs would stop at a missing disenchant button.
	local row = { disenchant, greed, need }
	for i = 1, 3 do
		local button = row[i]
		if button then
			button:ClearAllPoints()
			if rightOf then
				button:SetPoint("RIGHT", rightOf, "LEFT", rightOf == pass and -6 or -2, 0)
			else
				button:SetPoint("RIGHT", frame, "RIGHT", -8, 1)
			end
			button:SetSize(ROLL_BUTTON, ROLL_BUTTON)
			rightOf = button
		end
	end
	data.firstButton = rightOf

	if name then
		name:ClearAllPoints()
		if iconFrame then
			name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 9, -3)
		else
			name:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -9)
		end
		name:SetPoint("RIGHT", rightOf or frame, rightOf and "LEFT" or "RIGHT", -8, 0)
		name:SetJustifyH("LEFT")
		name:SetHeight(14)
		if name.SetWordWrap then name:SetWordWrap(false) end
	end
	data.info = frame:CreateFontString(nil, "OVERLAY")
	if name then
		data.info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
		data.info:SetPoint("RIGHT", name, "RIGHT", 0, 0)
	else
		data.info:SetPoint("LEFT", frame, "LEFT", 58, 0)
	end
	data.info:SetJustifyH("LEFT")
	data.info:SetHeight(12)
	if data.info.SetWordWrap then data.info:SetWordWrap(false) end

	if timer then
		WSkin:StripTextures(timer)
		timer:ClearAllPoints()
		timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
		timer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
		timer:SetHeight(ROLL_TIMER_H)
		timer:SetStatusBarTexture(WHITE_TEXTURE)
		-- Blizzard parks the timer below the window level so its art framed
		-- the bar; under the shell it would vanish.
		timer:SetFrameLevel(frame:GetFrameLevel() + 1)
		data.timerTrack = timer:CreateTexture(nil, "BACKGROUND")
		data.timerTrack:SetAllPoints(timer)
		data.timerTrack:SetTexture(0, 0, 0, 0.55)
		local function SetTimerColor(r, g, b) timer:SetStatusBarColor(r, g, b, 0.9) end
		SetTimerColor(WSkin:GetRetailAccent())
		if EllesmereUI and EllesmereUI.RegAccent then
			EllesmereUI.RegAccent({ type = "callback", obj = timer, fn = SetTimerColor })
		end
	end
end

local function UpdateRollFrame(frame)
	local data = State(frame)
	local _, _, _, quality, bindOnPickUp
	if frame.rollID and GetLootRollItemInfo then
		_, _, _, quality, bindOnPickUp = GetLootRollItemInfo(frame.rollID)
	end

	-- Undo GroupLootFrame_OnShow's per-roll art, then repaint the shell.
	if data.decoration then data.decoration:SetAlpha(0) end
	if data.corner then data.corner:Hide() end
	WSkin:CreateRetailWindowShell(frame, nil, nil, nil, { content = false, headerBand = 0 })
	-- Blizzard may refresh the pass button's native art as a roll is reused.
	if data.pass then WSkin:HandleCloseButton(data.pass) end

	local qr, qg, qb = QualityChroma(quality)
	if data.iconFrame and data.iconFrame.SetBackdropBorderColor then
		if qr then data.iconFrame:SetBackdropBorderColor(qr, qg, qb, 1)
		else data.iconFrame:SetBackdropBorderColor(unpack(WSkin.Retail.colors.border)) end
	end
	if qr then
		data.strip:SetVertexColor(qr, qg, qb, 1)
		data.strip:Show()
		data.wash:SetGradientAlpha("HORIZONTAL", qr, qg, qb, 0.16, qr, qg, qb, 0)
		data.wash:Show()
	else
		data.strip:Hide()
		data.wash:Hide()
	end

	if data.name then
		WSkin:ApplyRetailTypography(data.name, "value", 1)
		local r, g, b = QualityColor(quality)
		-- Blizzard tints the name through SetVertexColor; reset it so the
		-- quality color is not applied twice.
		data.name:SetVertexColor(1, 1, 1, 1)
		data.name:SetTextColor(r, g, b, 1)
	end

	local info = data.info
	WSkin:ApplyRetailTypography(info, "secondary")
	local link = frame.rollID and GetLootRollItemLink and GetLootRollItemLink(frame.rollID)
	local itemLevel, itemType, itemSubType
	if link and GetItemInfo then
		local _
		_, _, _, itemLevel, _, itemType, itemSubType = GetItemInfo(link)
	end
	local detail = itemSubType or itemType
	if detail and itemLevel and itemLevel > 1 then
		detail = ITEM_LEVEL_FORMAT:format(itemLevel, detail)
	end
	if bindOnPickUp then
		info:SetText(detail and (BOP_TEXT .. "  " .. detail) or BOP_TEXT)
		info:SetTextColor(1, 0.82, 0.25, 0.9)
	else
		info:SetText(detail or "")
	end
end

local function SkinGroupLootFrame(frame)
	if not frame then return end
	local frameName = frame.GetName and frame:GetName()
	if not frameName then return end
	local data = State(frame)
	if not data.skinned then
		data.skinned = true
		BuildRollFrame(frame, frameName)
	end
	UpdateRollFrame(frame)
end

local function SkinAllGroupLootFrames()
	for i = 1, NumRollFrames() do
		SkinGroupLootFrame(_G["GroupLootFrame" .. i])
	end
end

-- Options / profile-switch entry point: re-park the anchor at the active
-- profile's spot and re-apply scale and growth to the live stack.
function EllesmereUI._LootRolls_Refresh()
	if not EllesmereUI._lootRollsOwned then return end
	PositionRollAnchor()
	LayoutRollStack()
end

local function RegisterRollUnlock()
	if not (EllesmereUI and EllesmereUI.RegisterUnlockElements and EllesmereUI.MakeUnlockElement) then return end
	local MK = EllesmereUI.MakeUnlockElement
	EllesmereUI:RegisterUnlockElements({
		MK({
			key      = "EUI_LootRolls",
			label    = "Loot Rolls",
			group    = "Blizzard Windows",
			order    = 651,
			subtitle = "Need / Greed",
			noResize          = true,
			noAnchorTarget    = true,
			noAnchorTo        = true,
			noSizeMatchTarget = true,
			getFrame = function()
				-- Side-effect-free: Unlock Mode calls this from its drag loop.
				return EnsureRollAnchor()
			end,
			getSize = function()
				local scale = RollScale()
				return ROLL_W * scale, ROLL_H * scale
			end,
			savePos = function(_, point, relPoint, x, y)
				local prof = ActiveProfile()
				if not prof then return end
				prof.lootRollPos = { point = point, relPoint = relPoint or point, x = x, y = y }
				local anchor = EnsureRollAnchor()
				anchor:ClearAllPoints()
				anchor:SetPoint(point, UIParent, relPoint or point, x, y)
				LayoutRollStack()
			end,
			loadPos = function()
				local pos = GetRollPos()
				return { point = pos.point, relPoint = pos.relPoint or pos.point, x = pos.x or 0, y = pos.y or 0 }
			end,
			clearPos = function()
				local prof = ActiveProfile()
				if prof then prof.lootRollPos = false end
				local anchor = EnsureRollAnchor()
				anchor:ClearAllPoints()
				anchor:SetPoint(ROLL_DEFAULT_POS.point, UIParent, ROLL_DEFAULT_POS.relPoint,
					ROLL_DEFAULT_POS.x, ROLL_DEFAULT_POS.y)
				LayoutRollStack()
			end,
			applyPos = function()
				PositionRollAnchor()
				LayoutRollStack()
			end,
		}),
	})
end

local function InstallGroupLoot()
	-- Tells the Shifter to drop its hidden-proxy "Loot Rolls" mover: this
	-- anchor owns GroupLootFrame1 while the skin is on.
	EllesmereUI._lootRollsOwned = true
	EnsureRollAnchor()
	PositionRollAnchor()
	SkinAllGroupLootFrames()

	for i = 1, NumRollFrames() do
		local frame = _G["GroupLootFrame" .. i]
		if frame then
			frame:HookScript("OnShow", function(self)
				-- Re-read the position live so profile switches need no wiring.
				PositionRollAnchor()
				SkinGroupLootFrame(self)
				LayoutRollStack()
			end)
			frame:HookScript("OnHide", LayoutRollStack)
			-- UIParent_ManageFramePositions re-seats GroupLootFrame1 on every
			-- managed-layout pass; put it back on the anchor.
			hooksecurefunc(frame, "SetPoint", LayoutRollStack)
		end
	end
	LayoutRollStack()
	RegisterRollUnlock()
end

WSkin:AddCallback("Skin_Loot", function()
	if not WSkin:IsSkinEnabled("loot") then return end

	SkinLootFrame()
	InstallGroupLoot()

	if hooksecurefunc and _G.LootFrame_UpdateButton then
		hooksecurefunc("LootFrame_UpdateButton", UpdateLootButton)
	end
	if _G.LootFrame then
		_G.LootFrame:HookScript("OnShow", SkinLootFrame)
	end
end, "loot")
