-- Texture.lua

-- ColorMixin & CreateColor
if not ColorMixin then
    ColorMixin = {}
    -- Keep this as a function rather than pointing __index back at ColorMixin.
    -- WeakAuras deep-copies selected globals with the legacy, non-cycle-aware
    -- CopyTable implementation; a self-reference here causes a stack overflow.
    ColorMixin.__index = function(_, key)
        return ColorMixin[key]
    end

    function ColorMixin:SetRGBA(r, g, b, a)
        self.r = r
        self.g = g
        self.b = b
        self.a = a or 1
    end

    function ColorMixin:GetRGB()
        return self.r, self.g, self.b
    end

    function ColorMixin:GetRGBA()
        return self.r, self.g, self.b, self.a
    end

    function ColorMixin:GenerateHexColor()
        local r = math.floor(self.r * 255 + 0.5)
        local g = math.floor(self.g * 255 + 0.5)
        local b = math.floor(self.b * 255 + 0.5)
        local a = math.floor((self.a or 1) * 255 + 0.5)
        return string.format("%.2x%.2x%.2x%.2x", a, r, g, b)
    end

    function ColorMixin:GenerateHexColorMarkup()
        return "|c" .. self:GenerateHexColor()
    end

    function ColorMixin:WrapTextInColorCode(text)
        return self:GenerateHexColorMarkup() .. text .. "|r"
    end

    function ColorMixin:IsEqualTo(other)
        if not other then return false end
        return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a
    end

    function ColorMixin:Clone()
        return CreateColor(self.r, self.g, self.b, self.a)
    end
end

if not CreateColor then
    function CreateColor(r, g, b, a)
        local color = setmetatable({}, ColorMixin)
        color:SetRGBA(r or 1, g or 1, b or 1, a or 1)
        return color
    end
end

-- Retail replaced Texture:SetGradientAlpha with Texture:SetGradient, whose
-- endpoints are ColorMixin objects. WotLK only has the former API. Install the
-- modern method on the shared texture metatable so every addon texture (including
-- textures created after this file loads) can use the same gradient code.
do
    local probe = UIParent and UIParent:CreateTexture(nil, "BACKGROUND")
    if probe and probe.SetGradientAlpha then
        local textureMethods = getmetatable(probe)
        textureMethods = textureMethods and textureMethods.__index
        if type(textureMethods) == "table" then
            local origSetGradient = textureMethods.SetGradient
            function textureMethods:SetGradient(orientation, minColor, maxColor, ...)
                if type(minColor) == "table" and minColor.GetRGBA then
                    local minR, minG, minB, minA = minColor:GetRGBA()
                    local maxR, maxG, maxB, maxA = maxColor:GetRGBA()

                    -- These extended direction names are used by EllesmereUI's
                    -- options. The legacy API reverses a gradient by swapping its
                    -- endpoints.
                    if orientation == "HORIZONTAL_REV" then
                        orientation = "HORIZONTAL"
                        minR, minG, minB, minA, maxR, maxG, maxB, maxA =
                            maxR, maxG, maxB, maxA, minR, minG, minB, minA
                    elseif orientation == "VERTICAL_REV" then
                        orientation = "VERTICAL"
                        minR, minG, minB, minA, maxR, maxG, maxB, maxA =
                            maxR, maxG, maxB, maxA, minR, minG, minB, minA
                    end

                    return self:SetGradientAlpha(
                        orientation,
                        minR, minG, minB, minA,
                        maxR, maxG, maxB, maxA
                    )
                elseif origSetGradient then
                    return origSetGradient(self, orientation, minColor, maxColor, ...)
                end
            end
        end
    end
end

-- WotLK refuses to load any texture file whose width or height is not a power
-- of two (retail has no such limit). The failure is silent: SetTexture returns
-- nil, and a StatusBar given such a path never creates its fill texture, so
-- GetStatusBarTexture() returns nil and the next method call on it raises.
-- Paths reach us from retail profile imports and LibSharedMedia, so check
-- them before use. A probe load is cheap, but cache per path anyway.
do
    local probe = UIParent and UIParent:CreateTexture(nil, "BACKGROUND")
    if probe then probe:Hide() end
    local cache = {}
    -- If the client does not report load success, we cannot tell a bad file
    -- from a good one: trust every path rather than reject them all.
    local reliable = probe and probe:SetTexture("Interface\\Buttons\\WHITE8X8") and true

    function EllesmereUI.IsTextureLoadable(path)
        if type(path) ~= "string" or not reliable then return true end
        local ok = cache[path]
        if ok == nil then
            ok = probe:SetTexture(path) and true or false
            probe:SetTexture(nil)
            cache[path] = ok
        end
        return ok
    end
end
