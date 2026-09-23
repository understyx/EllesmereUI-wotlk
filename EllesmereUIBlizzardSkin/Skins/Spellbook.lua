local WSkin = _G.EllesmereUIBlizzardSkin
if not WSkin then return end

local _G = _G
local type, unpack = type, unpack
local TEXCOORDS = WSkin.TexCoords or { 0.08, 0.92, 0.08, 0.92 }
local FRAME_WIDTH, FRAME_HEIGHT = 360, 395
local SPELL_SIZE, SPELL_STEP = 30, 45

local FFD = setmetatable({}, { __mode = "k" })
local function Data(frame)
	local data = FFD[frame]
	if not data then
		data = {}
		FFD[frame] = data
	end
	return data
end

local function LayoutNavigation(hasTabRow)
	local frame = _G.SpellBookFrame
	if not frame then return end
	local footer = hasTabRow and 35 or 14
	local previous = _G.SpellBookPrevPageButton
	local nextPage = _G.SpellBookNextPageButton
	local page = _G.SpellBookPageText
	if previous then
		previous:ClearAllPoints()
		previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, footer)
		previous:SetSize(20, 20)
	end
	if nextPage then
		nextPage:ClearAllPoints()
		nextPage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, footer)
		nextPage:SetSize(20, 20)
	end
	if page then
		page:ClearAllPoints()
		page:SetPoint("BOTTOM", frame, "BOTTOM", 0, footer + 4)
		page:SetWidth(90)
	end
end

local function StyleBookTabs()
	local frame = _G.SpellBookFrame
	if not frame then return end
	local visible = {}
	for i = 1, 3 do
		local tab = _G["SpellBookFrameTabButton" .. i]
		if tab then
			WSkin:StyleRetailTab(tab)
			tab:SetHitRectInsets(0, 0, 0, 0)
			tab:SetAlpha(1)
			tab:EnableMouse(true)
			if tab:IsShown() then visible[#visible + 1] = tab end
		end
	end
	if #visible == 0 then
		LayoutNavigation(false)
		return
	end
	-- A single "Spellbook" tab merely repeats the window title. Keep the
	-- native button alive for Blizzard, but remove the redundant footer label.
	if #visible == 1 then
		visible[1]:SetAlpha(0)
		visible[1]:EnableMouse(false)
		LayoutNavigation(false)
		return
	end
	local width = frame:GetWidth() / #visible
	for i, tab in ipairs(visible) do
		tab:ClearAllPoints()
		tab:SetSize(width, WSkin.Retail.geometry.tabHeight)
		if i == 1 then
			tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		else
			tab:SetPoint("LEFT", visible[i - 1], "RIGHT", 0, 0)
		end
		local active = tab.bookType and tab.bookType == frame.bookType
		if not tab.bookType and tab.IsEnabled then active = not tab:IsEnabled() end
		WSkin:UpdateRetailTab(tab, active and true or false)
	end
	LayoutNavigation(true)
end

local function StyleSkillLineTabs()
	local selected = _G.SpellBookFrame and _G.SpellBookFrame.selectedSkillLine
	for i = 1, (_G.MAX_SKILLLINE_TABS or 8) do
		local tab = _G["SpellBookSkillLineTab" .. i]
		if tab then
			local data = Data(tab)
			local icon = tab.GetNormalTexture and tab:GetNormalTexture()
			local texture = icon and icon.GetTexture and icon:GetTexture()
			if not data.skinned then
				data.skinned = true
				WSkin:StripTextures(tab)
				WSkin:ApplyRetailSurface(tab, "card")
				WSkin:StyleButton(tab, nil, true)
			end
			tab:ClearAllPoints()
			tab:SetSize(26, 26)
			if i == 1 then
				tab:SetPoint("TOPRIGHT", _G.SpellBookFrame, "TOPRIGHT", -5, -57)
			else
				tab:SetPoint("TOP", _G["SpellBookSkillLineTab" .. (i - 1)], "BOTTOM", 0, -6)
			end
			if icon then
				if texture then icon:SetTexture(texture) end
				icon:ClearAllPoints()
				icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -3)
				icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 3)
				icon:SetTexCoord(unpack(TEXCOORDS))
				icon:Show()
				WSkin:ApplyRetailIcon(icon, tab)
			end
			local ar, ag, ab = WSkin:GetRetailAccent()
			tab:SetBackdropBorderColor(ar, ag, ab, selected == i and 0.85 or 0.20)
		end
	end
end

local function StyleSpellButton(button, alternate, index)
	if not button then return end
	local data = Data(button)
	if alternate ~= nil then data.alternate = alternate end
	if index ~= nil then data.index = index end
	local name = button:GetName()
	local icon = _G[name .. "IconTexture"]
	local spellName = _G[name .. "SpellName"]
	local subSpellName = _G[name .. "SubSpellName"]
	local background = _G[name .. "Background"]
	local highlight = _G[name .. "Highlight"]

	if not data.skinned then
		data.skinned = true
		if background then background:SetAlpha(0) end
		if button.SetNormalTexture then button:SetNormalTexture("") end
		if button.SetPushedTexture then button:SetPushedTexture("") end
		if button.SetCheckedTexture then button:SetCheckedTexture("") end

		local row = button:CreateTexture(nil, "BACKGROUND", nil, -3)
		row:SetPoint("TOPLEFT", button, "TOPLEFT", -5, 5)
		row:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 116, -5)
		data.row = row

		local edge = button:CreateTexture(nil, "BACKGROUND", nil, -2)
		edge:SetWidth(1)
		edge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		local ar, ag, ab = WSkin:GetRetailAccent()
		edge:SetTexture(ar, ag, ab, 0.38)
		data.edge = edge
		if _G.EllesmereUI and _G.EllesmereUI.RegAccent then
			_G.EllesmereUI.RegAccent({ type = "solid", obj = edge, a = 0.38 })
		end
	end
	if not data.laidOut and data.index then
		data.laidOut = true
		local column = (data.index - 1) % 2
		local row = math.floor((data.index - 1) / 2)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", _G.SpellBookFrame, "TOPLEFT", 20 + column * 161, -66 - row * SPELL_STEP)
		button:SetSize(SPELL_SIZE, SPELL_SIZE)
	end

	-- SpellButton_UpdateButton re-adds its stock LEFT anchor every time a spell
	-- changes. Reassert the compact text geometry in the post-hook while keeping
	-- the secure button itself as a one-time layout operation.
	if data.index then
		local column = (data.index - 1) % 2
		local textWidth = column == 0 and 113 or 103
		if spellName then
			spellName:ClearAllPoints()
			spellName:SetPoint("TOPLEFT", button, "TOPRIGHT", 6, -1)
			spellName:SetSize(textWidth, 14)
			spellName:SetJustifyH("LEFT")
		end
		if subSpellName then
			subSpellName:ClearAllPoints()
			subSpellName:SetPoint("TOPLEFT", spellName or button, spellName and "BOTTOMLEFT" or "TOPRIGHT", spellName and 0 or 6, spellName and 1 or -15)
			subSpellName:SetSize(textWidth, 12)
			subSpellName:SetJustifyH("LEFT")
		end
		local cooldown = _G[name .. "Cooldown"]
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(button)
		end
		local autoCastable = _G[name .. "AutoCastable"]
		if autoCastable then
			autoCastable:ClearAllPoints()
			autoCastable:SetPoint("CENTER", button, "CENTER", 0, 0)
			autoCastable:SetSize(SPELL_SIZE + 6, SPELL_SIZE + 6)
		end
	end

	local checked = button.GetChecked and button:GetChecked()
	checked = checked == true or checked == 1
	if checked then
		local ar, ag, ab = WSkin:GetRetailAccent()
		data.row:SetTexture(ar, ag, ab, 0.10)
	else
		data.row:SetTexture(1, 1, 1, data.alternate and 0.018 or 0.010)
	end
	if background then background:SetAlpha(0) end
	if highlight then
		highlight:SetTexture(1, 1, 1, 0.06)
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", data.row, "TOPLEFT", 0, 0)
		highlight:SetPoint("BOTTOMRIGHT", data.row, "BOTTOMRIGHT", 0, 0)
	end

	local populated = icon and icon:IsShown()
	data.row:SetShown(populated and true or false)
	data.edge:SetShown(populated and checked and true or false)
	if icon then
		icon:SetTexCoord(unpack(TEXCOORDS))
		WSkin:ApplyRetailIcon(icon, button, SPELL_SIZE)
		WSkin:SetRetailIconShown(icon, populated and true or false)
	end
	WSkin:ApplyRetailTypography(spellName, "row")
	WSkin:ApplyRetailTypography(subSpellName, "secondary")
end

local function StyleSpellRows()
	for i = 1, (_G.SPELLS_PER_PAGE or 12) do
		StyleSpellButton(_G["SpellButton" .. i], math.floor((i - 1) / 2) % 2 == 1, i)
	end
end

local function RefreshSpellbook()
	local frame = _G.SpellBookFrame
	if not frame then return end
	WSkin:SetRetailPageTitle(frame, nil, _G.SpellBookTitleText)
	StyleBookTabs()
	StyleSkillLineTabs()
	StyleSpellRows()
	WSkin:ApplyRetailTypography(_G.SpellBookPageText, "secondary")
	WSkin:ApplyRetailTypography(_G.ShowAllSpellRanksCheckBoxText, "secondary")
end

WSkin:AddCallback("Skin_Spellbook", function()
	if not WSkin:IsSkinEnabled("playerspells") then return end
	local frame = _G.SpellBookFrame
	if not frame then return end

	WSkin:StripTextures(frame, true)
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	WSkin:CreateRetailWindowShell(
		frame,
		_G.SPELLBOOK or "Spellbook",
		_G.SpellBookTitleText,
		_G.SpellBookCloseButton,
		{ content = false }
	)
	frame:SetHitRectInsets(0, 0, 0, 0)
	WSkin:SetUIPanelWindowInfo(frame, "width", frame:GetWidth())

	WSkin:HandleCheckBox(_G.ShowAllSpellRanksCheckBox)
	if _G.ShowAllSpellRanksCheckBox and _G.ShowAllSpellRanksCheckBox.backdrop then
		WSkin:ApplyRetailSurface(_G.ShowAllSpellRanksCheckBox.backdrop, "input")
	end
	if _G.ShowAllSpellRanksCheckBox then
		_G.ShowAllSpellRanksCheckBox:ClearAllPoints()
		_G.ShowAllSpellRanksCheckBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -34)
	end
	WSkin:HandleNextPrevButton(_G.SpellBookPrevPageButton, "left", nil, true)
	WSkin:HandleNextPrevButton(_G.SpellBookNextPageButton, "right", nil, true)
	WSkin:ApplyRetailRegionTypography(_G.SpellBookPrevPageButton, "secondary")
	WSkin:ApplyRetailRegionTypography(_G.SpellBookNextPageButton, "secondary")

	for i = 1, 3 do
		local tab = _G["SpellBookFrameTabButton" .. i]
		if tab then tab:HookScript("OnClick", StyleBookTabs) end
	end
	for i = 1, (_G.MAX_SKILLLINE_TABS or 8) do
		local tab = _G["SpellBookSkillLineTab" .. i]
		if tab then tab:HookScript("OnClick", StyleSkillLineTabs) end
	end

	frame:HookScript("OnShow", RefreshSpellbook)
	if type(_G.SpellBookFrame_Update) == "function" then
		hooksecurefunc("SpellBookFrame_Update", RefreshSpellbook)
	end
	if type(_G.SpellButton_UpdateButton) == "function" then
		hooksecurefunc("SpellButton_UpdateButton", StyleSpellButton)
	end
	if type(_G.SpellButton_UpdateSelection) == "function" then
		hooksecurefunc("SpellButton_UpdateSelection", StyleSpellButton)
	end
	RefreshSpellbook()
end)
