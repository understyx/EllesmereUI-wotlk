-------------------------------------------------------------------------------
--  EUI_PallyPower_Style.lua
--  EllesmereUI-native presentation for the imported PallyPower engine.
-------------------------------------------------------------------------------

local EllesmereUI = _G.EllesmereUI
if not EllesmereUI or not PallyPower then return end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TEXTURE_BASE = "Interface\\AddOns\\EllesmereUI\\media\\textures\\"

local textures = {
	["none"] = WHITE,
	["melli"] = TEXTURE_BASE .. "melli.tga",
	["atrocity"] = TEXTURE_BASE .. "atrocity.tga",
	["fade"] = TEXTURE_BASE .. "fade.tga",
	["fade-right"] = TEXTURE_BASE .. "fade-right.tga",
	["thin-line-top"] = TEXTURE_BASE .. "thin-line-top.tga",
	["thin-line-bottom"] = TEXTURE_BASE .. "thin-line-bottom.tga",
	["beautiful"] = TEXTURE_BASE .. "beautiful.tga",
	["plating"] = TEXTURE_BASE .. "plating.tga",
	["divide"] = TEXTURE_BASE .. "divide.tga",
	["glass"] = TEXTURE_BASE .. "glass.tga",
	["gradient-lr"] = TEXTURE_BASE .. "gradient-lr.tga",
	["gradient-rl"] = TEXTURE_BASE .. "gradient-rl.tga",
	["gradient-bt"] = TEXTURE_BASE .. "gradient-bt.tga",
	["gradient-tb"] = TEXTURE_BASE .. "gradient-tb.tga",
	["matte"] = TEXTURE_BASE .. "matte.tga",
	["sheer"] = TEXTURE_BASE .. "sheer.tga",
	["blinkii-diamonds"] = TEXTURE_BASE .. "blinkii-diamonds.tga",
	["kringel-window"] = TEXTURE_BASE .. "kringel-window.tga",
}

local textureOrder = {
	"none", "melli", "atrocity",
	"fade", "fade-right",
	"thin-line-top", "thin-line-bottom",
	"beautiful", "plating", "divide", "glass",
	"gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
	"matte", "sheer", "blinkii-diamonds", "kringel-window",
}

local textureNames = {
	["none"] = "Flat",
	["melli"] = "Melli (ElvUI)",
	["atrocity"] = "Atrocity",
	["fade"] = "Fade",
	["fade-right"] = "Fade Right",
	["thin-line-top"] = "Thin Line Top",
	["thin-line-bottom"] = "Thin Line Bottom",
	["beautiful"] = "Beautiful",
	["plating"] = "Plating",
	["divide"] = "Divide",
	["glass"] = "Glass",
	["gradient-lr"] = "Gradient Right",
	["gradient-rl"] = "Gradient Left",
	["gradient-bt"] = "Gradient Up",
	["gradient-tb"] = "Gradient Down",
	["matte"] = "Matte",
	["sheer"] = "Sheer",
	["blinkii-diamonds"] = "Blinkii Diamonds",
	["kringel-window"] = "Kringel Window",
}

PallyPower.EUIBarTextures = textures
PallyPower.EUIBarTextureOrder = textureOrder
PallyPower.EUIBarTextureNames = textureNames

if EllesmereUI.AppendSharedMediaTextures then
	EllesmereUI.AppendSharedMediaTextures(textureNames, textureOrder, nil, textures)
end

local function BuildStyleCache(addon)
	if addon._euiStyleButtons then return end
	local buttons = { addon.autoButton, addon.rfButton, addon.auraButton }
	for i = 1, PALLYPOWER_MAXCLASSES do
		buttons[#buttons + 1] = addon.classButtons[i]
		for j = 1, PALLYPOWER_MAXPERCLASS do
			buttons[#buttons + 1] = addon.playerButtons[i][j]
		end
	end

	local fontStrings = {}
	for _, button in ipairs(buttons) do
		if button then
			local regions = { button:GetRegions() }
			for _, region in ipairs(regions) do
				if region and region.IsObjectType and region:IsObjectType("FontString") then
					fontStrings[#fontStrings + 1] = region
				end
			end
		end
	end
	addon._euiStyleButtons = buttons
	addon._euiFontStrings = fontStrings
end

local function StyleFont(fontString, path, outline, useShadow)
	if not fontString then return end
	local _, size = fontString:GetFont()
	size = tonumber(size) or 10
	if EllesmereUI.PrimeFontShadow then
		EllesmereUI.PrimeFontShadow(fontString, useShadow)
	end
	fontString:SetFont(path, size, outline)
end

function PallyPower:ApplyEUIStyle()
	if InCombatLockdown and InCombatLockdown() then
		self._euiStylePending = true
		return
	end
	if not self.autoButton or not self.opt or not self.opt.display then return end
	self._euiStylePending = nil
	BuildStyleCache(self)

	local display = self.opt.display
	local textureKey = display.barTexture or "melli"
	local texture = EllesmereUI.ResolveTexturePath
		and EllesmereUI.ResolveTexturePath(textures, textureKey, WHITE)
		or textures[textureKey] or WHITE
	local fontPath = EllesmereUI.GetFontPath
		and EllesmereUI.GetFontPath("pallyPower") or STANDARD_TEXT_FONT
	local outline = EllesmereUI.GetFontOutlineFlag
		and EllesmereUI.GetFontOutlineFlag("pallyPower") or ""
	local useShadow = EllesmereUI.GetFontUseShadow
		and EllesmereUI.GetFontUseShadow("pallyPower") or false
	local pixel = EllesmereUI.PP
	local accent = EllesmereUI.ELLESMERE_GREEN or { r = 0.05, g = 0.82, b = 0.62 }
	local textureChanged = self._euiAppliedTexture ~= texture

	for _, button in ipairs(self._euiStyleButtons) do
		if button then
			if textureChanged then
				button:SetBackdrop({ bgFile = texture, tile = false,
					insets = { left = 0, right = 0, top = 0, bottom = 0 } })
			end
			button:SetHighlightTexture(WHITE)
			local highlight = button:GetHighlightTexture()
			if highlight then
				highlight:SetAllPoints(button)
				highlight:SetVertexColor(accent.r, accent.g, accent.b, 0.14)
			end
			if pixel then
				if not pixel.GetBorders(button) then
					pixel.CreateBorder(button, 0, 0, 0, 0.92, 1, "OVERLAY", 7)
				end
				if display.edges then
					pixel.UpdateBorder(button, 1, 0, 0, 0, 0.92)
					pixel.ShowBorder(button)
				else
					pixel.HideBorder(button)
				end
			end
		end
	end
	self._euiAppliedTexture = texture

	for _, fontString in ipairs(self._euiFontStrings) do
		StyleFont(fontString, fontPath, outline, useShadow)
	end

	local tab = self.edgeTab or _G.PallyPowerAnchor
	if tab then
		tab:SetBackdrop({ bgFile = WHITE, tile = false })
		tab:SetBackdropColor(0.025, 0.035, 0.045, 0.96)
		if pixel then
			if not pixel.GetBorders(tab) then
				pixel.CreateBorder(tab, accent.r, accent.g, accent.b, 0.95, 1, "OVERLAY", 7)
			else
				pixel.UpdateBorder(tab, 1, accent.r, accent.g, accent.b, 0.95)
				pixel.ShowBorder(tab)
			end
		end
		local highlight = tab:GetHighlightTexture()
		if highlight then highlight:SetVertexColor(accent.r, accent.g, accent.b, 0.22) end
		if tab.label then
			if EllesmereUI.PrimeFontShadow then EllesmereUI.PrimeFontShadow(tab.label, useShadow) end
			tab.label:SetFont(fontPath, 11, outline)
			tab.label:SetTextColor(accent.r, accent.g, accent.b, 1)
		end
	end
end

_G._EPP_ApplyStyle = function()
	if PallyPower and PallyPower.ApplyEUIStyle then PallyPower:ApplyEUIStyle() end
end

if EllesmereUI.RegAccent then
	EllesmereUI.RegAccent({ type = "callback", fn = _G._EPP_ApplyStyle })
end
