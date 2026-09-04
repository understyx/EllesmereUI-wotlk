local addonName, ns = ...

-- This file globally polyfills the Retail C_CooldownViewer API for WotLK 3.3.5a.
-- We do this to decouple the data layer from EllesmereUI's internal namespaces,
-- allowing standard Retail renderer code to work unchanged on older clients
-- and making this Cooldown logic reusable for other addons.
-- Note: Runtime behavior requires in-client verification.

_G.C_CooldownViewer = _G.C_CooldownViewer or {}

-- Internal Data Models
local definitions = {}      -- cooldownID -> definition schema
local availability = {}     -- cooldownID -> { isKnown = boolean, activeSpellID = number, activeAuraSpellID = number }
local runtimeState = {}     -- cooldownID -> cooldown state plus matched aura identity/duration/stacks
local categories = {}       -- categoryID -> array of cooldownIDs
local adapters = {}         -- cooldownID -> native adapter frame
local internalCooldownIDsByAura = {} -- proc aura spellID -> array of cooldownIDs
local auraTagsBySpellID = {} -- aura spellID -> normalized tag set

-- The renderer expects the objects returned by itemFramePool to be real,
-- anchorable frames.  A Lua table can expose GetSpellID/cooldownInfo, but it
-- cannot own textures or be placed on a CDM bar, so catalog entries would be
-- discovered without ever producing pixels on screen.
local viewerNamesByCategory = {
    [1] = "EssentialCooldownViewer",
    [2] = "UtilityCooldownViewer",
    [3] = "BuffIconCooldownViewer",
    [4] = "BuffBarCooldownViewer",
    [5] = "DebuffIconCooldownViewer",
}

-- Caching
local cachedPlayerAuras = {}
local cachedTargetDebuffs = {}
local cachedTargetDebuffsAnySource = {}
local cachedTargetDebuffsAnySourceByName = {}
local cachedAuraTime = 0

-- Event Tracker Frame
local tracker = CreateFrame("Frame")

local function ValidateDefinition(def)
    if not def.key then return false, "Missing key" end
    if not def.cooldownID then return false, "Missing cooldownID" end
    if definitions[def.cooldownID] then return false, "Duplicate cooldownID" end

    local keyExists = false
    for _, existing in pairs(definitions) do
        if existing.key == def.key then
            keyExists = true
            break
        end
    end
    if keyExists then return false, "Duplicate key" end

    if not def.category then return false, "Missing category" end
    if not def.trackingType then return false, "Missing trackingType" end
    if def.internalCooldown ~= nil
        and (type(def.internalCooldown) ~= "number" or def.internalCooldown < 0) then
        return false, "internalCooldown must be a non-negative number"
    end
    if def.auraTags ~= nil and type(def.auraTags) ~= "table" then
        return false, "auraTags must be a table"
    end

    if def.trackingType == "cooldown" and not def.spellID then return false, "Tracking type cooldown requires spellID" end
    if (def.trackingType == "aura" or def.trackingType == "debuff")
        and not (def.spellID or def.auraSpellID or def.auraSpellIDs) then
        return false, "Aura tracking requires spellID or auraSpellID"
    end

    return true
end

local function NormalizeAuraTags(tags)
    local normalized = {}
    for key, value in pairs(tags or {}) do
        local tag
        if type(key) == "number" then
            tag = value
        elseif value then
            tag = key
        end
        if type(tag) == "string" then
            normalized[string.lower(tag)] = true
        end
    end
    return normalized
end

local function AddTaggedSpellID(spellID, tags)
    if type(spellID) ~= "number" then return end
    local indexed = auraTagsBySpellID[spellID]
    if not indexed then
        indexed = {}
        auraTagsBySpellID[spellID] = indexed
    end
    for tag in pairs(tags) do indexed[tag] = true end
end

local function IndexDefinitionAuraTags(def)
    local tags = NormalizeAuraTags(def.auraTags)
    if not next(tags) then return end

    -- A unit aura can use the cast spell, a dedicated aura spell, a lower
    -- rank, or an equivalent effect ID. Index every identity carried by the
    -- CDM definition so the frame filters and CDM always share one catalog.
    AddTaggedSpellID(def.spellID, tags)
    AddTaggedSpellID(def.auraSpellID, tags)
    if def.spellIDs then
        for _, spellID in ipairs(def.spellIDs) do AddTaggedSpellID(spellID, tags) end
    end
    if def.auraSpellIDs then
        for _, spellID in ipairs(def.auraSpellIDs) do AddTaggedSpellID(spellID, tags) end
    end
    def.auraTags = tags
end

-- Adapter Prototype
local AdapterMixin = {}
function AdapterMixin:GetSpellID()
    local avail = availability[self.cooldownID]
    local def = definitions[self.cooldownID]
    if avail and avail.activeSpellID then return avail.activeSpellID end
    if def then return def.overrideSpellID or def.spellID end
    return nil
end

function AdapterMixin:GetAuraSpellID()
    local state = runtimeState[self.cooldownID]
    if state and state.auraActive and state.matchedAuraSpellID then
        return state.matchedAuraSpellID
    end
    local avail = availability[self.cooldownID]
    local def = definitions[self.cooldownID]
    if avail and avail.activeAuraSpellID then return avail.activeAuraSpellID end
    if def then return def.auraSpellID or def.spellID end
    return nil
end

function AdapterMixin:IsShown()
    return self._isShown ~= false
end

function AdapterMixin:IsVisible()
    return self:IsShown()
end

function AdapterMixin:Show()
    self._isShown = true
end

function AdapterMixin:Hide()
    self._isShown = false
end

function AdapterMixin:SetShown(show)
    self._isShown = show and true or false
end

function AdapterMixin:SetAlpha(a)
    self._alpha = a
end

function AdapterMixin:GetAlpha()
    return self._alpha or 1
end

function AdapterMixin:ClearAllPoints() end
function AdapterMixin:SetPoint() end
function AdapterMixin:GetScale()
    return 1
end

function AdapterMixin:GetObjectType()
    return "Frame"
end

function AdapterMixin:IsObjectType(t)
    return t == "Frame"
end

local DummyRegionMixin = {}
function DummyRegionMixin:SetTexture() end
function DummyRegionMixin:SetColorTexture() end
function DummyRegionMixin:SetVertexColor() end
function DummyRegionMixin:SetAlpha(a) self._alpha = a end
function DummyRegionMixin:GetAlpha() return self._alpha or 1 end
function DummyRegionMixin:SetAllPoints() end
function DummyRegionMixin:SetPoint() end
function DummyRegionMixin:ClearAllPoints() end
function DummyRegionMixin:Show() self._shown = true end
function DummyRegionMixin:Hide() self._shown = false end
function DummyRegionMixin:IsShown() return self._shown ~= false end
function DummyRegionMixin:SetShown(s) self._shown = s and true or false end
function DummyRegionMixin:SetDrawLayer() end
function DummyRegionMixin:SetDesaturated() end
function DummyRegionMixin:IsDesaturated() return false end
function DummyRegionMixin:SetFont() end
function DummyRegionMixin:SetText() end
function DummyRegionMixin:GetText() return "" end
function DummyRegionMixin:SetTextColor() end
function DummyRegionMixin:SetFrameLevel() end
function DummyRegionMixin:GetFrameLevel() return 1 end

local function CreateDummyRegion()
    local r = {}
    setmetatable(r, { __index = DummyRegionMixin })
    return r
end

function AdapterMixin:GetFrameLevel()
    return self._frameLevel or 1
end

function AdapterMixin:SetFrameLevel(lvl)
    self._frameLevel = lvl
end

function AdapterMixin:GetFrameStrata()
    return self._frameStrata or "MEDIUM"
end

function AdapterMixin:SetFrameStrata(strata)
    self._frameStrata = strata
end

function AdapterMixin:CreateTexture()
    return CreateDummyRegion()
end

function AdapterMixin:CreateFontString()
    return CreateDummyRegion()
end

function AdapterMixin:GetParent()
    return self._parent or UIParent
end

function AdapterMixin:SetParent(p)
    self._parent = p
end

function AdapterMixin:GetWidth()
    return self._width or 32
end

function AdapterMixin:GetHeight()
    return self._height or 32
end

function AdapterMixin:SetWidth(w)
    self._width = w
end

function AdapterMixin:SetHeight(h)
    self._height = h
end

function AdapterMixin:SetSize(w, h)
    self._width = w
    self._height = h
end

function AdapterMixin:GetName()
    return self._name or nil
end

function AdapterMixin:GetScript()
    return nil
end

function AdapterMixin:SetScript() end
function AdapterMixin:HookScript() end

function AdapterMixin:UpdateInfo()
    self.cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(self.cooldownID)
end

function AdapterMixin:GetCooldownInfo()
    return self.cooldownInfo
end

-- EllesmereUICdmHooks hooks this method on buff viewer children and queues a
-- re-layout after it runs.  The compatibility tracker calls it whenever an
-- aura-backed adapter changes active state.
function AdapterMixin:OnActiveStateChanged() end

local function CopyAdapterMethod(frame, method)
    frame[method] = AdapterMixin[method]
end

local function CreateAdapterFrame(cdID)
    local def = definitions[cdID]
    local viewer = def and _G[viewerNamesByCategory[def.category]] or UIParent
    local frame = CreateFrame("Button", nil, viewer or UIParent)
    if EUI and EUI.API and EUI.API.ApplyFrameCompat then
        EUI.API.ApplyFrameCompat(frame)
    end

    frame:SetSize(32, 32)
    frame:EnableMouse(false)
    frame.cooldownID = cdID
    frame.viewerFrame = viewer
    frame.layoutIndex = (def and def.order) or cdID
    frame._isCooldownViewerAdapter = true

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    frame.Icon = icon
    frame._tex = icon

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    if EUI and EUI.API and EUI.API.ApplyFrameCompat then
        EUI.API.ApplyFrameCompat(cooldown)
    end
    cooldown:SetAllPoints(frame)
    cooldown:EnableMouse(false)
    frame.Cooldown = cooldown
    frame._cooldown = cooldown

    -- Native buff/debuff frames expose an Applications child containing the
    -- aura stack FontString. Provide the same shape on compatibility adapters
    -- so the shared CDM appearance pass can style it normally.
    local applications = CreateFrame("Frame", nil, frame)
    if EUI and EUI.API and EUI.API.ApplyFrameCompat then
        EUI.API.ApplyFrameCompat(applications)
    end
    applications:SetAllPoints(frame)
    applications:EnableMouse(false)
    local applicationsText = applications:CreateFontString(nil, "OVERLAY")
    -- Wrath FontStrings cannot receive SetText before a font is assigned.
    -- The shared CDM appearance pass restyles this immediately once claimed.
    applicationsText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    applicationsText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2)
    applications.Applications = applicationsText
    applications:Hide()
    frame.Applications = applications

    -- Only the data/notification methods need to override native frame
    -- behavior.  Show/Hide/SetPoint/etc. must remain the engine methods.
    CopyAdapterMethod(frame, "GetSpellID")
    CopyAdapterMethod(frame, "GetAuraSpellID")
    CopyAdapterMethod(frame, "GetCooldownInfo")
    CopyAdapterMethod(frame, "UpdateInfo")
    CopyAdapterMethod(frame, "OnActiveStateChanged")

    frame:Hide()
    return frame
end

local function RefreshAdapterVisual(frame)
    if not frame then return end
    local cdID = frame.cooldownID
    local def = definitions[cdID]
    local avail = availability[cdID]
    local state = runtimeState[cdID]
    if not def then return end
    local wasShown = frame:IsShown()

    frame:UpdateInfo()

    local spellID = (avail and avail.activeSpellID)
        or def.iconSpellID or def.spellID or def.auraSpellID
    local matchedAuraID = state and state.auraActive and state.matchedAuraSpellID
    local iconSpellID = matchedAuraID or def.iconSpellID or spellID
    if frame.Icon then
        local texture = state and state.auraActive and state.matchedAuraIcon
        if not texture and iconSpellID and GetSpellTexture then
            texture = GetSpellTexture(iconSpellID)
        end
        if not texture and iconSpellID and C_Spell and C_Spell.GetSpellTexture then
            texture = C_Spell.GetSpellTexture(iconSpellID)
        end
        if texture then frame.Icon:SetTexture(texture) end
    end

    if frame.Applications and frame.Applications.Applications then
        local count = state and state.auraActive and state.auraStacks or 0
        if count and count > 1 then
            frame.Applications.Applications:SetText(tostring(count))
            frame.Applications:Show()
        else
            frame.Applications.Applications:SetText("")
            frame.Applications:Hide()
        end
    end

    -- IsUsableSpell includes both the normal execute threshold and proc-based
    -- exceptions such as Sudden Death, so do not duplicate those rules here.
    if frame.Icon and def.execute and spellID and IsUsableSpell then
        local usable = IsUsableSpell(spellID)
        frame.Icon:SetDesaturated(not usable)
    end

    local isKnown = avail and avail.isKnown or false
    local isAura = def.trackingType == "aura"
        or def.trackingType == "debuff"
        or def.trackingType == "cooldown_and_aura"
        or def.trackingType == "cooldown_and_debuff"
    -- Buff-viewer adapters represent aura presence only.  A trinket's ICD is
    -- still retained as cooldown metadata, but it must not keep the tracked-
    -- buff icon visible after the proc aura fades (or make the ICD swipe
    -- replace the buff-duration swipe).
    local isActive = isKnown and (not isAura or (state and state.auraActive))
    local wasActive = frame._adapterActive == true
    frame._adapterActive = isActive and true or false
    frame.wasSetFromAura = isAura and state and state.auraActive or false

    if isActive then frame:Show() else frame:Hide() end

    if frame.Cooldown then
        local start, duration = 0, 0
        if isAura and state and state.auraActive then
            duration = state.auraDuration or 0
            local expiration = state.auraExpiration or 0
            if duration > 0 and expiration > 0 then start = expiration - duration end
        elseif state then
            start = state.cooldownStart or 0
            duration = state.cooldownDuration or 0
        end
        CooldownFrame_Set(frame.Cooldown, start, duration,
            isActive and duration > 0 and 1 or 0)
    end

    if isAura and (wasActive ~= (isActive and true or false)
        or (isActive and not wasShown)) then
        -- Notify the viewer's pool so the hooks layer installs
        -- OnActiveStateChanged hooks on newly created adapters and queues a
        -- reanchor for layout. Fires on gain/fade, and also repairs an active
        -- adapter that another pool/layout pass unexpectedly hid, so a missed
        -- lifecycle callback cannot leave debuff tracking visually stopped.
        -- The bar re-lays out (closing gaps / adding the new icon) even if the hook
        -- was never installed on this particular adapter.
        local viewer = frame.viewerFrame
        if viewer and viewer.itemFramePool and viewer.itemFramePool.Acquire then
            viewer.itemFramePool.Acquire()
        end
        frame:OnActiveStateChanged(isActive)
    end
end

local function GetOrCreateAdapter(cdID)
    if not adapters[cdID] then
        adapters[cdID] = CreateAdapterFrame(cdID)
    end
    RefreshAdapterVisual(adapters[cdID])
    return adapters[cdID]
end

local function IsInternalCooldownActive(state, now)
    return state
        and state.internalCooldownExpiration
        and state.internalCooldownExpiration > now
end

local function StartInternalCooldown(cdID, startTime)
    local def = definitions[cdID]
    local duration = def and def.internalCooldown or 0
    if duration <= 0 then return end

    local state = runtimeState[cdID] or {}
    local start = startTime or GetTime()
    local expiration = start + duration
    state.cooldownStart = start
    state.cooldownDuration = duration
    state.cooldownEnabled = true
    state.internalCooldownExpiration = expiration
    runtimeState[cdID] = state

    if adapters[cdID] then RefreshAdapterVisual(adapters[cdID]) end

    if C_Timer and C_Timer.After then
        local delay = expiration - GetTime()
        if delay < 0 then delay = 0 end
        C_Timer.After(delay, function()
            local current = runtimeState[cdID]
            -- A refreshed proc replaces the expiration.  Its older timer must
            -- not clear the newer internal cooldown.
            if current and current.internalCooldownExpiration == expiration then
                current.cooldownStart = 0
                current.cooldownDuration = 0
                current.cooldownEnabled = false
                current.internalCooldownExpiration = nil
                if adapters[cdID] then RefreshAdapterVisual(adapters[cdID]) end
            end
        end)
    end
end

-- Registers a logical ability definition into the system.
-- The cooldownID MUST be globally unique across ALL classes and items.
-- It acts as a stable handle for UI components (like drag-and-drop or saves).
function C_CooldownViewer.RegisterDefinition(def)
    local ok, err = ValidateDefinition(def)
    if not ok then
        print("|cffff5555[CDM Polyfill Error]|r Definition rejected: " .. err .. " (" .. tostring(def.key) .. ")")
        return
    end

    definitions[def.cooldownID] = def
    IndexDefinitionAuraTags(def)

    if (def.internalCooldown or 0) > 0 then
        local auraSpellID = def.auraSpellID or def.spellID
        internalCooldownIDsByAura[auraSpellID] = internalCooldownIDsByAura[auraSpellID] or {}
        table.insert(internalCooldownIDsByAura[auraSpellID], def.cooldownID)
    end

    categories[def.category] = categories[def.category] or {}
    table.insert(categories[def.category], def.cooldownID)

    -- Ensure deterministic sorting using order, then cooldownID as tie-breaker
    table.sort(categories[def.category], function(a, b)
        local dA = definitions[a]
        local dB = definitions[b]
        local oA = dA and dA.order or 999
        local oB = dB and dB.order or 999
        if oA == oB then
            return a < b
        end
        return oA < oB
    end)
end

-- Shared classification API used by the WotLK unit-frame and raid-frame aura
-- filter polyfill. Tags live on CDM definitions so adding or correcting a
-- spell in the catalog automatically updates every consumer.
function C_CooldownViewer.IsAuraSpellTagged(spellID, tag)
    if type(tag) ~= "string" then return false end
    local tags = auraTagsBySpellID[spellID]
    return tags and tags[string.lower(tag)] == true or false
end

function C_CooldownViewer.GetAuraSpellTags(spellID)
    return auraTagsBySpellID[spellID]
end

function C_CooldownViewer.GetCooldownViewerCategorySet(category, includeUnknown)
    local results = {}
    local catIDs = categories[category] or {}

    for _, cdID in ipairs(catIDs) do
        local avail = availability[cdID]
        local isKnown = avail and avail.isKnown or false
        if includeUnknown or isKnown then
            table.insert(results, cdID)
        end
    end

    return results
end

function C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    local def = definitions[cooldownID]
    local avail = availability[cooldownID]
    local state = runtimeState[cooldownID]

    if not def then return nil end

    local activeSpellID = avail and avail.activeSpellID or def.spellID

    return {
        cooldownID = cooldownID,
        spellID = activeSpellID,
        overrideSpellID = def.overrideSpellID,
        linkedSpellIDs = def.linkedSpellIDs,
        iconSpellID = def.iconSpellID,
        auraSpellID = (state and state.auraActive and state.matchedAuraSpellID)
            or (avail and avail.activeAuraSpellID) or def.auraSpellID,
        matchedAuraSpellID = state and state.matchedAuraSpellID,
        matchedAuraIcon = state and state.matchedAuraIcon,
        matchedAuraName = state and state.matchedAuraName,
        auraSpellIDs = def.auraSpellIDs,
        anySourceDebuff = def.anySourceDebuff,
        debuffScope = def.debuffScope,
        hasAura = def.hasAura,
        selfAura = def.selfAura,
        auraUnit = def.auraUnit,
        execute = def.execute,
        class = def.class,
        isTrinketProc = def.isTrinketProc,
        auraTags = def.auraTags,
        isDefensive = def.auraTags and def.auraTags.defensive == true or false,
        isExternal = def.auraTags and def.auraTags.external == true or false,

        -- Runtime state fields expected by EllesmereUI adapters
        cooldownStart = state and state.cooldownStart or 0,
        cooldownDuration = state and state.cooldownDuration or 0,
        cooldownEnabled = state and state.cooldownEnabled or false,
        auraActive = state and state.auraActive or false,
        auraDuration = state and state.auraDuration or 0,
        auraExpiration = state and state.auraExpiration or 0,
        auraStacks = state and state.auraStacks or 0,
        internalCooldownDuration = def.internalCooldown,
    }
end

-- Aura Caching
local function UpdateAuraCache()
    wipe(cachedPlayerAuras)
    wipe(cachedTargetDebuffs)
    wipe(cachedTargetDebuffsAnySource)
    wipe(cachedTargetDebuffsAnySourceByName)
    for i = 1, 40 do
        local name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellID = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if spellID then
            cachedPlayerAuras[spellID] = { duration = duration or 0, expirationTime = expirationTime or 0, count = count or 0 }
        end
    end
    for i = 1, 40 do
        local name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellID = UnitAura("player", i, "HARMFUL")
        if not name then break end
        if spellID then
            cachedPlayerAuras[spellID] = { duration = duration or 0, expirationTime = expirationTime or 0, count = count or 0 }
        end
    end
    if UnitExists("target") then
        -- Raid-category cache: every harmful aura, regardless of caster.
        for i = 1, 40 do
            local name, rank, icon, count, debuffType, duration, expirationTime,
                source, isStealable, nameplateShowPersonal, spellID =
                UnitAura("target", i, "HARMFUL")
            if not name then break end
            if spellID or name then
                local aura = {
                    duration = duration or 0,
                    expirationTime = expirationTime or 0,
                    count = count or 0,
                    spellID = spellID,
                    icon = icon,
                    name = name,
                }
                if spellID then cachedTargetDebuffsAnySource[spellID] = aura end
                -- PLAYER-filtered UnitAura is unreliable on some 3.3.5 server
                -- cores. Trust an explicit player/pet caster from the complete
                -- scan, then merge the filtered scan below as a compatibility
                -- fallback for cores that omit caster tokens.
                local fromPlayer = source == "player" or source == "pet"
                    or (source and UnitIsUnit
                        and (UnitIsUnit(source, "player") or UnitIsUnit(source, "pet")))
                if spellID and fromPlayer then cachedTargetDebuffs[spellID] = aura end
                -- Some 3.3.5 servers expose a server-specific spellID for an
                -- otherwise standard aura. Raid equivalence groups also index
                -- localized spell names so Sunder/Expose-style effects still
                -- match without weakening Personal debuff ownership rules.
                if name then cachedTargetDebuffsAnySourceByName[name] = aura end
            end
        end
        -- Merge the server's PLAYER-filtered view. This remains useful when a
        -- core supplies nil caster tokens in the unfiltered result.
        for i = 1, 40 do
            local name, rank, icon, count, debuffType, duration, expirationTime,
                source, isStealable, nameplateShowPersonal, spellID =
                UnitAura("target", i, "HARMFUL|PLAYER")
            if not name then break end
            if spellID then
                cachedTargetDebuffs[spellID] = {
                    duration = duration or 0,
                    expirationTime = expirationTime or 0,
                    count = count or 0,
                    spellID = spellID,
                    icon = icon,
                    name = name,
                }
            end
        end
    end
    cachedAuraTime = GetTime()
end

local function GetCachedAura(spellID, unit, anySource)
    if not spellID then return nil end
    -- Fallback safety if accessed outside of normal flow
    if GetTime() > cachedAuraTime + 0.5 then
        UpdateAuraCache()
    end
    if unit == "target" then
        local cache = anySource and cachedTargetDebuffsAnySource or cachedTargetDebuffs
        local aura = cache[spellID]
        if not aura and anySource then
            local name
            if GetSpellInfo then name = GetSpellInfo(spellID) end
            if not name and C_Spell and C_Spell.GetSpellName then
                name = C_Spell.GetSpellName(spellID)
            end
            if name then aura = cachedTargetDebuffsAnySourceByName[name] end
        end
        return aura
    end
    return cachedPlayerAuras[spellID]
end

-- Refresh logic
local function ReevaluateAvailability()
    local _, playerClass = UnitClass("player")

    for cdID, def in pairs(definitions) do
        local allowed = true
        if def.class and def.class ~= playerClass then allowed = false end

        -- Resolvers support
        if allowed and def.resolvers and def.resolvers.requirements then
            allowed = def.resolvers.requirements(def)
        end

        local activeSpellID = nil
        local isKnown = false

        if allowed then
            if def.resolvers and def.resolvers.resolveSpellID then
                local resolved = def.resolvers.resolveSpellID(def)
                if resolved then
                    isKnown = true
                    activeSpellID = resolved
                end
            elseif def.spellIDs then
                for i = #def.spellIDs, 1, -1 do
                    local sID = def.spellIDs[i]
                    if IsSpellKnown and IsSpellKnown(sID) then
                        isKnown = true
                        activeSpellID = sID
                        break
                    end
                end
            elseif def.spellID then
                if IsSpellKnown and IsSpellKnown(def.spellID) then
                    isKnown = true
                    activeSpellID = def.spellID
                end
            end
        end

        availability[cdID] = {
            isKnown = isKnown,
            activeSpellID = activeSpellID or def.spellID,
            activeAuraSpellID = def.auraSpellID or activeSpellID or def.spellID
        }
    end
end

local function ReevaluateState()
    for cdID, def in pairs(definitions) do
        local avail = availability[cdID]
        local state = runtimeState[cdID] or {}

        if avail and avail.isKnown then
            local spellID = avail.activeSpellID
            if (def.trackingType == "cooldown" or def.trackingType == "cooldown_and_aura"
                or def.trackingType == "cooldown_and_debuff")
                and not def.internalCooldown then
                if spellID then
                    local start, duration, enabled = GetSpellCooldown(spellID)
                    state.cooldownStart = start or 0
                    state.cooldownDuration = duration or 0
                    state.cooldownEnabled = (enabled == 1)
                end
            end

            if def.internalCooldown and not IsInternalCooldownActive(state, GetTime()) then
                state.cooldownStart = 0
                state.cooldownDuration = 0
                state.cooldownEnabled = false
                state.internalCooldownExpiration = nil
            end

            if def.trackingType == "aura" or def.trackingType == "debuff"
                or def.trackingType == "cooldown_and_aura"
                or def.trackingType == "cooldown_and_debuff" then
                local auraIDs = def.auraSpellIDs
                local auraID = avail.activeAuraSpellID
                if auraID or auraIDs then
                    local wasAuraActive = state.auraActive == true
                    local auraUnit = (def.trackingType == "debuff"
                        or def.trackingType == "cooldown_and_debuff")
                        and "target" or (def.auraUnit or "player")
                    local aura = auraID and GetCachedAura(auraID, auraUnit, def.anySourceDebuff)
                    if not aura and auraIDs then
                        for _, equivalentID in ipairs(auraIDs) do
                            aura = GetCachedAura(equivalentID, auraUnit, def.anySourceDebuff)
                            if aura then break end
                        end
                    end
                    if aura then
                        state.auraActive = true
                        state.auraDuration = aura.duration
                        state.auraExpiration = aura.expirationTime
                        state.auraStacks = aura.count
                        state.matchedAuraSpellID = aura.spellID
                        state.matchedAuraIcon = aura.icon
                        state.matchedAuraName = aura.name
                        -- CLEU normally starts ICDs at the exact proc event.
                        -- This fallback recovers a proc already active at login
                        -- or after an event gap, using the aura's start time.
                        if def.internalCooldown and def.internalCooldown > 0
                            and not wasAuraActive
                            and not IsInternalCooldownActive(state, GetTime()) then
                            local auraStart = GetTime()
                            if aura.duration > 0 and aura.expirationTime > 0 then
                                auraStart = aura.expirationTime - aura.duration
                            end
                            StartInternalCooldown(cdID, auraStart)
                        end
                    else
                        state.auraActive = false
                        state.auraDuration = 0
                        state.auraExpiration = 0
                        state.auraStacks = 0
                        state.matchedAuraSpellID = nil
                        state.matchedAuraIcon = nil
                        state.matchedAuraName = nil
                    end
                end
            end
        else
            -- Unknown or inactive
            state.cooldownStart = 0
            state.cooldownDuration = 0
            state.cooldownEnabled = false
            state.auraActive = false
            state.auraStacks = 0
            state.matchedAuraSpellID = nil
            state.matchedAuraIcon = nil
            state.matchedAuraName = nil
            state.internalCooldownExpiration = nil
        end

        runtimeState[cdID] = state

        -- Update persistent adapter
        if adapters[cdID] then
            RefreshAdapterVisual(adapters[cdID])
        end
    end
end

-- The parent framework's PLAYER_LOGIN frame is created before this child
-- addon loads.  Once the compatibility layer moved into the child addon, that
-- framework frame could run the CDM's OnEnable before this tracker's own
-- PLAYER_LOGIN callback, leaving the first bar build with an empty availability
-- map.  Expose an explicit synchronous refresh so CDM initialization and
-- equipment rebuilds never depend on event-frame dispatch order.
function ns.RefreshCooldownViewerCompatibility()
    UpdateAuraCache()
    ReevaluateAvailability()
    ReevaluateState()
end

-- Coalesce UNIT_AURA and combat-log notifications into one refresh on the next
-- rendered frame. Some private-server cores occasionally omit a target
-- UNIT_AURA; the combat-log path below supplies a second authoritative wakeup
-- without adding a permanent polling ticker.
local auraRefreshQueued = false
local auraRefreshFrame = CreateFrame("Frame")
auraRefreshFrame:Hide()
auraRefreshFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    if not auraRefreshQueued then return end
    auraRefreshQueued = false
    UpdateAuraCache()
    ReevaluateState()
end)

local function QueueAuraRefresh()
    auraRefreshQueued = true
    auraRefreshFrame:Show()
end

local function IsAuraCombatLogEvent(subEvent)
    return subEvent == "SPELL_AURA_APPLIED"
        or subEvent == "SPELL_AURA_REMOVED"
        or subEvent == "SPELL_AURA_REFRESH"
        or subEvent == "SPELL_AURA_APPLIED_DOSE"
        or subEvent == "SPELL_AURA_REMOVED_DOSE"
        or subEvent == "SPELL_AURA_BROKEN"
        or subEvent == "SPELL_AURA_BROKEN_SPELL"
end

-- Event Handling
tracker:RegisterEvent("PLAYER_LOGIN")
tracker:RegisterEvent("SPELLS_CHANGED")
tracker:RegisterEvent("PLAYER_TALENT_UPDATE")
tracker:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
tracker:RegisterUnitEvent("UNIT_AURA", "player", "target")
tracker:RegisterEvent("SPELL_UPDATE_COOLDOWN")
tracker:RegisterEvent("SPELL_UPDATE_USABLE")
tracker:RegisterEvent("PLAYER_TARGET_CHANGED")
tracker:RegisterUnitEvent("UNIT_HEALTH", "target")
tracker:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

tracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
        ns.RefreshCooldownViewerCompatibility()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.RefreshCooldownViewerCompatibility()
    elseif event == "UNIT_AURA" then
        local unit = ...
        if not unit or unit == "player" or unit == "target"
            or (UnitIsUnit and (UnitIsUnit(unit, "player") or UnitIsUnit(unit, "target"))) then
            QueueAuraRefresh()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        QueueAuraRefresh()
    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit == "target" or (unit and UnitIsUnit and UnitIsUnit(unit, "target")) then
            ReevaluateState()
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
        ReevaluateState()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, _, _, destinationGUID, _, _, spellID = ...
        if IsAuraCombatLogEvent(subEvent) then
            local targetGUID = UnitGUID("target")
            if targetGUID and destinationGUID == targetGUID then
                QueueAuraRefresh()
            end
        end
        if destinationGUID == UnitGUID("player")
            and (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH") then
            local cooldownIDs = internalCooldownIDsByAura[spellID]
            if cooldownIDs then
                local now = GetTime()
                for _, cooldownID in ipairs(cooldownIDs) do
                    local avail = availability[cooldownID]
                    if avail and avail.isKnown then
                        StartInternalCooldown(cooldownID, now)
                    end
                end
                QueueAuraRefresh()
            end
        end
    end
end)

-- Global Viewer Pools (Mocking Retail UI Frames)
local function CreateMockPool(categoryID)
    return {
        EnumerateActive = function()
            -- A Retail itemFramePool contains frames for displayed/known
            -- abilities, not every definition for every class.  Unknown entries
            -- remain available through GetCooldownViewerCategorySet(..., true)
            -- for pickers and reconciliation.
            --
            -- On Retail, aura-only entries (trinket procs) only acquire a pool
            -- frame while the proc aura is active.  Returning inactive aura
            -- adapters here caused the hooks layer to process hidden frames,
            -- producing empty layout slots and icon overlaps when procs fired
            -- or faded.  Filter them out so only genuinely active adapters
            -- enter the collection/layout pass.
            local entries = C_CooldownViewer.GetCooldownViewerCategorySet(categoryID, false)
            local i = 0
            return function()
                while true do
                    i = i + 1
                    local cdID = entries[i]
                    if not cdID then return nil end
                    local adapter = GetOrCreateAdapter(cdID)
                    -- Skip aura-only adapters whose proc is not currently active.
                    -- Their frame is hidden by RefreshAdapterVisual and should not
                    -- participate in the bar layout.
                    -- Exception: If the aura is explicitly tracked by a bar that might
                    -- want to show an inactive placeholder (Always Show Buffs / hosted
                    -- on a CD bar), we must yield it so the hooks layer can inject one.
                    -- Debuff definitions are a small, class-scoped catalog and
                    -- must remain enumerable while their aura is missing.  The
                    -- hooks layer decides whether an entry was explicitly picked
                    -- and whether to draw its desaturated/hidden placeholder.
                    -- Do not gate this on _divertedSpellsDebuff[sid]: grouped Raid
                    -- debuffs can be picked under one rank/effect while the
                    -- definition's canonical spellID is another, which made the
                    -- inactive adapter disappear before Visibility When Missing
                    -- could be applied.
                    local forceYield = (categoryID == 5)
                    if adapter._adapterActive == false then
                        local def = definitions[cdID]
                        if def then
                            local sid = def.spellID or def.auraSpellID or def.iconSpellID
                            if categoryID == 3 or categoryID == 4 then
                                if ns._divertedSpellsBuff and ns._divertedSpellsBuff[sid] then
                                    forceYield = true
                                end
                                if ns._divertedBuffCdIDs and ns._divertedBuffCdIDs[cdID] then
                                    forceYield = true
                                end
                            end
                        end
                    end
                    if adapter._adapterActive ~= false or forceYield then
                        return adapter
                    end
                end
            end
        end,
        Acquire = function() end,
        Release = function() end,
        ReleaseAll = function() end,
    }
end

local function InitMockViewer(globalName, categoryID)
    local frame = _G[globalName]
    if not frame then
        if CreateFrame then
            frame = CreateFrame("Frame", globalName, UIParent)
        else
            frame = {}
            _G[globalName] = frame
        end
    end
    if not frame.SetAlpha then frame.SetAlpha = function(self, a) self._alpha = a end end
    if not frame.GetAlpha then frame.GetAlpha = function(self) return self._alpha or 1 end end
    if not frame.ClearAllPoints then frame.ClearAllPoints = function() end end
    if not frame.SetPoint then frame.SetPoint = function() end end
    if not frame.GetScale then frame.GetScale = function() return 1 end end
    if not frame.Layout then frame.Layout = function() end end
    frame.itemFramePool = CreateMockPool(categoryID)
    return frame
end

InitMockViewer("EssentialCooldownViewer", 1)
InitMockViewer("UtilityCooldownViewer", 2)
InitMockViewer("BuffIconCooldownViewer", 3)
InitMockViewer("BuffBarCooldownViewer", 4)
InitMockViewer("DebuffIconCooldownViewer", 5)
