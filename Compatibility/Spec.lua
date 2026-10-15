local _G = _G or getfenv(0)
local EllesmereUI = _G.EllesmereUI or {}

_G.EllesmereUI = EllesmereUI
EUI = EUI or {}
EUI.Spec = EUI.Spec or {}

local Spec = EUI.Spec

local CLASS_SPECS = {
    WARRIOR = {
        { id = 71, name = "Arms",        fileName = "WarriorArms",        role = "DAMAGER", icon = [[Interface\Icons\Ability_Warrior_SavageBlow]] },
        { id = 72, name = "Fury",        fileName = "WarriorFury",        role = "DAMAGER", icon = [[Interface\Icons\Ability_Warrior_InnerRage]] },
        { id = 73, name = "Protection", fileName = "WarriorProtection", role = "TANK", icon = [[Interface\Icons\Ability_Warrior_DefensiveStance]] },
    },
    PALADIN = {
        { id = 65, name = "Holy",        fileName = "PaladinHoly",        role = "HEALER", icon = [[Interface\Icons\Spell_Holy_HolyBolt]] },
        { id = 66, name = "Protection", fileName = "PaladinProtection", role = "TANK", icon = [[Interface\Icons\Spell_Holy_DevotionAura]] },
        { id = 70, name = "Retribution", fileName = "PaladinRetribution", role = "DAMAGER", icon = [[Interface\Icons\Spell_Holy_AuraOfLight]] },
    },
    HUNTER = {
        { id = 253, name = "Beast Mastery", fileName = "HunterBeastMastery", role = "DAMAGER", icon = [[Interface\Icons\Ability_Hunter_BeastTaming]] },
        { id = 254, name = "Marksmanship",  fileName = "HunterMarksmanship",  role = "DAMAGER", icon = [[Interface\Icons\Ability_Marksmanship]] },
        { id = 255, name = "Survival",      fileName = "HunterSurvival",      role = "DAMAGER", icon = [[Interface\Icons\Ability_Hunter_SwiftStrike]] },
    },
    ROGUE = {
        { id = 259, name = "Assassination", fileName = "RogueAssassination", role = "DAMAGER", icon = [[Interface\Icons\Ability_Rogue_Eviscerate]] },
        { id = 260, name = "Combat",        fileName = "RogueCombat",        role = "DAMAGER", icon = [[Interface\Icons\Ability_BackStab]] },
        { id = 261, name = "Subtlety",      fileName = "RogueSubtlety",      role = "DAMAGER", icon = [[Interface\Icons\Ability_Stealth]] },
    },
    PRIEST = {
        { id = 256, name = "Discipline", fileName = "PriestDiscipline", role = "HEALER", icon = [[Interface\Icons\Spell_Holy_PowerWordShield]] },
        { id = 257, name = "Holy",       fileName = "PriestHoly",       role = "HEALER", icon = [[Interface\Icons\Spell_Holy_GuardianSpirit]] },
        { id = 258, name = "Shadow",     fileName = "PriestShadow",     role = "DAMAGER", icon = [[Interface\Icons\Spell_Shadow_ShadowWordPain]] },
    },
    DEATHKNIGHT = {
        { id = 250, name = "Blood",  fileName = "DeathKnightBlood",  role = "TANK",    roles = { "TANK", "DAMAGER" }, icon = [[Interface\Icons\Spell_Deathknight_BloodPresence]] },
        { id = 251, name = "Frost",  fileName = "DeathKnightFrost",  role = "DAMAGER", roles = { "TANK", "DAMAGER" }, icon = [[Interface\Icons\Spell_Deathknight_FrostPresence]] },
        { id = 252, name = "Unholy", fileName = "DeathKnightUnholy", role = "DAMAGER", roles = { "TANK", "DAMAGER" }, icon = [[Interface\Icons\Spell_Deathknight_UnholyPresence]] },
    },
    SHAMAN = {
        { id = 262, name = "Elemental",   fileName = "ShamanElemental",   role = "DAMAGER", icon = [[Interface\Icons\Spell_Nature_Lightning]] },
        { id = 263, name = "Enhancement", fileName = "ShamanEnhancement", role = "DAMAGER", icon = [[Interface\Icons\Spell_Nature_LightningShield]] },
        { id = 264, name = "Restoration", fileName = "ShamanRestoration", role = "HEALER", icon = [[Interface\Icons\Spell_Nature_MagicImmunity]] },
    },
    MAGE = {
        { id = 62, name = "Arcane", fileName = "MageArcane", role = "DAMAGER", icon = [[Interface\Icons\Spell_Holy_MagicalSentry]] },
        { id = 63, name = "Fire",   fileName = "MageFire",   role = "DAMAGER", icon = [[Interface\Icons\Spell_Fire_FireBolt02]] },
        { id = 64, name = "Frost",  fileName = "MageFrost",  role = "DAMAGER", icon = [[Interface\Icons\Spell_Frost_FrostBolt02]] },
    },
    WARLOCK = {
        { id = 265, name = "Affliction",  fileName = "WarlockAffliction",  role = "DAMAGER", icon = [[Interface\Icons\Spell_Shadow_DeathCoil]] },
        { id = 266, name = "Demonology",  fileName = "WarlockDemonology",  role = "DAMAGER", icon = [[Interface\Icons\Spell_Shadow_Metamorphosis]] },
        { id = 267, name = "Destruction", fileName = "WarlockDestruction", role = "DAMAGER", icon = [[Interface\Icons\Spell_Shadow_RainOfFire]] },
    },
    DRUID = {
        { id = 102, name = "Balance",    fileName = "DruidBalance",    role = "DAMAGER", icon = [[Interface\Icons\Spell_Nature_StarFall]] },
        { id = 103, name = "Feral",      fileName = "DruidFeralCombat", role = "DAMAGER", roles = { "DAMAGER", "TANK" }, icon = [[Interface\Icons\Ability_Racial_BearForm]] },
        { id = 105, name = "Restoration", fileName = "DruidRestoration", role = "HEALER", icon = [[Interface\Icons\Spell_Nature_HealingTouch]] },
    },
}

local CLASS_IDS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}


local BY_ID = {}
for classToken, specs in pairs(CLASS_SPECS) do
    for index, info in ipairs(specs) do
        info.index = index
        info.classToken = classToken
        BY_ID[info.id] = info
    end
end

local function PlayerClass()
    if not UnitClass then return nil end
    return select(2, UnitClass("player"))
end

local function ActiveTalentGroup()
    return (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
end

local function TalentTabInfo(index, group)
    if not GetTalentTabInfo then return end
    return GetTalentTabInfo(index, false, false, group)
end

-- Index of the tree holding the most points in a talent group (the player's
-- spec on legacy clients), or nil before any point is spent.
local function ActiveIndex(classToken, group)
    local specs = CLASS_SPECS[classToken]
    if not specs or not GetTalentTabInfo then return end
    local bestIndex, bestPoints = nil, 0
    for index = 1, #specs do
        local _, _, points = TalentTabInfo(index, group)
        points = tonumber(points) or 0
        if points > bestPoints then
            bestIndex, bestPoints = index, points
        end
    end
    return bestIndex
end

-- Tank-only talents inside trees that also field DPS builds. Same markers and
-- threshold LibGroupTalents uses for other group members, read synchronously
-- here because the library fills in the player's data asynchronously.
local TANK_TALENTS = {
    DEATHKNIGHT = { need = 2, 49182, 49042, 55129 }, -- Blade Barrier, Toughness, Anticipation
    DRUID       = { need = 2, 33853, 57873 },        -- Survival of the Fittest, Protector of the Pack
}

local function HasTankTalents(classToken, group)
    local def = TANK_TALENTS[classToken]
    if not def or not GetTalentInfo or not GetNumTalentTabs or not GetSpellInfo then
        return false
    end
    local wanted = {}
    for i = 1, #def do
        local name = GetSpellInfo(def[i])
        if name then wanted[name] = true end
    end
    local count = 0
    for tab = 1, GetNumTalentTabs(false, false) do
        for index = 1, GetNumTalents(tab, false, false) do
            local name, _, _, _, rank = GetTalentInfo(tab, index, false, false, group)
            if name and wanted[name] and (rank or 0) > 0 then count = count + 1 end
        end
    end
    return count >= def.need
end

-- Role of the player's ACTIVE spec in a tree that can tank or deal damage
-- (every Death Knight tree, Feral). A manual role override or a Dungeon Finder
-- assignment wins when the spec allows it; otherwise tank talents decide.
-- Presence and form are deliberately not inputs: a tank in the wrong presence
-- must stay a tank so reminders can flag the presence. Inactive specs and the
-- inactive talent group keep their template role.
local function LiveRoleCheck(classToken, index, group, template)
    if classToken ~= PlayerClass() or group ~= ActiveTalentGroup()
       or index ~= ActiveIndex(classToken, group) then
        return nil
    end
    local allowed = {}
    for _, role in ipairs(template.roles or { template.role }) do allowed[role] = true end
    local detector = _G.EllesmereUI and _G.EllesmereUI.RoleDetector
    if detector then
        local chosen = detector:GetOverride("player")
            or (detector.GetAssignedRole and detector:GetAssignedRole("player"))
        if chosen and allowed[chosen] then return chosen end
    end
    return HasTankTalents(classToken, group) and "TANK" or "DAMAGER"
end

Spec.RoleChecks = Spec.RoleChecks or {
    DEATHKNIGHT = { [1] = LiveRoleCheck, [2] = LiveRoleCheck, [3] = LiveRoleCheck },
    DRUID = { [2] = LiveRoleCheck },
}

local function ResolveRole(template, classToken, index, group)
    local checks = Spec.RoleChecks[classToken]
    local check = checks and checks[index]
    local role = check and check(classToken, index, group, template)
    return role or template.role
end

local function LegacyInfo(classToken, index, group)
    local template = CLASS_SPECS[classToken] and CLASS_SPECS[classToken][index]
    if not template then return end

    local name, icon, points, fileName = TalentTabInfo(index, group)
    return {
        id = template.id,
        index = index,
        name = name or template.name,
        icon = icon or template.icon,
        role = ResolveRole(template, classToken, index, group),
        roles = template.roles,
        fileName = fileName or template.fileName,
        classToken = classToken,
        group = group,
        points = tonumber(points) or 0,
    }
end

local function CurrentLegacy()
    local classToken = PlayerClass()
    local specs = CLASS_SPECS[classToken]
    if not specs or not GetTalentTabInfo then return end

    local group = ActiveTalentGroup()
    local bestIndex = ActiveIndex(classToken, group)
    if not bestIndex then return end
    return LegacyInfo(classToken, bestIndex, group)
end

function Spec:GetCurrent()
    return CurrentLegacy()
end

function Spec:GetCurrentID()
    local info = self:GetCurrent()
    return info and info.id
end

function Spec:GetCurrentIndex()
    local info = self:GetCurrent()
    return info and info.index
end

function Spec:GetInfo(index)
    local classToken = PlayerClass()
    return LegacyInfo(classToken, index, ActiveTalentGroup())
end

function Spec:GetInfoByID(id)
    id = tonumber(id) or id
    local info = BY_ID[id]
    if not info then
        -- Role layout IDs resolve to their layout info (see GetLayoutInfo).
        if self.GetLayoutInfo and type(id) == "number" and id > 10000 then
            return self:GetLayoutInfo(id)
        end
        return
    end
    if info.classToken == PlayerClass() then
        return LegacyInfo(info.classToken, info.index, ActiveTalentGroup())
    end
    return info
end

function Spec:GetInfoForClassID(classID, index)
    for classToken, id in pairs(CLASS_IDS) do
        if id == classID then
            if classToken == PlayerClass() then
                return LegacyInfo(classToken, index, ActiveTalentGroup())
            end
            local info = CLASS_SPECS[classToken] and CLASS_SPECS[classToken][index]
            return info
        end
    end
end

function Spec:GetList()
    local classToken = PlayerClass()
    local result = {}
    for index = 1, #(CLASS_SPECS[classToken] or {}) do
        result[#result + 1] = LegacyInfo(classToken, index, ActiveTalentGroup())
    end
    return result
end

function Spec:GetNum()
    return #self:GetList()
end

-------------------------------------------------------------------------------
-- Role layouts. A tree that can both tank and deal damage (every Death Knight
-- tree, Feral) keeps its spec ID for its usual role and gets a stable layout
-- ID for the other one, so per-spec data (cooldown layouts) can hold one copy
-- per role. Layout IDs never replace the spec ID used by profiles, spec
-- overrides or anything else that means "the talent tree".
--   layoutID = 10000 + specID * 10 + role code   (Blood DPS = 12502)
-------------------------------------------------------------------------------
local ROLE_CODES = { TANK = 1, DAMAGER = 2, HEALER = 3 }
local ROLE_LABELS = { TANK = "Tank", DAMAGER = "DPS", HEALER = "Healer" }
local ROLE_LAYOUTS = {} -- layoutID -> { spec = template, role = role }

for _, specs in pairs(CLASS_SPECS) do
    for _, template in ipairs(specs) do
        for _, role in ipairs(template.roles or {}) do
            if role ~= template.role and ROLE_CODES[role] then
                ROLE_LAYOUTS[10000 + template.id * 10 + ROLE_CODES[role]] =
                    { spec = template, role = role }
            end
        end
    end
end

local function IsMultiRole(template)
    return template and template.roles and #template.roles > 1
end

-- Layout ID for a spec info table (as returned by GetCurrent/GetInfo).
function Spec:GetLayoutID(info)
    if not info or not info.id then return nil end
    local template = BY_ID[info.id]
    if not IsMultiRole(template) or info.role == template.role then return info.id end
    local code = ROLE_CODES[info.role]
    local layoutID = code and (10000 + info.id * 10 + code)
    return (layoutID and ROLE_LAYOUTS[layoutID]) and layoutID or info.id
end

-- Layout ID for the player's active spec and current role.
function Spec:GetCurrentLayoutID()
    return self:GetLayoutID(self:GetCurrent())
end

-- Spec info for a layout ID: the spec's own info for a plain spec ID, or a
-- copy carrying the layout's role and ID for a role layout. Name includes the
-- role for any multi-role tree ("Blood (Tank)", "Blood (DPS)").
function Spec:GetLayoutInfo(layoutID)
    layoutID = tonumber(layoutID) or layoutID
    local variant = ROLE_LAYOUTS[layoutID]
    local template = variant and variant.spec or BY_ID[layoutID]
    if not template then return nil end
    local base = self:GetInfoByID(template.id) or template
    local role = variant and variant.role or template.role
    local info = {}
    for k, v in pairs(base) do info[k] = v end
    info.id = layoutID
    info.specID = template.id
    info.role = role
    if IsMultiRole(template) then
        info.name = (base.name or template.name) .. " (" .. ROLE_LABELS[role] .. ")"
    end
    return info
end

-- Every layout for the player's class: each spec, plus the other role of a
-- multi-role tree, in tree order.
function Spec:GetLayoutList()
    return self:GetLayoutListForClass(PlayerClass())
end

-- Every class token that has specs on this client, in class-ID order.
function Spec:GetClassTokens()
    local result = {}
    for classToken in pairs(CLASS_SPECS) do result[#result + 1] = classToken end
    table.sort(result, function(a, b) return (CLASS_IDS[a] or 99) < (CLASS_IDS[b] or 99) end)
    return result
end

-- Every talent tree for a class, in tree order: { id, name } per spec.
function Spec:GetSpecListForClass(classToken)
    local result = {}
    for _, template in ipairs(CLASS_SPECS[classToken] or {}) do
        result[#result + 1] = { id = template.id, name = template.name }
    end
    return result
end

-- Every layout for a class, in tree order (see GetLayoutList).
function Spec:GetLayoutListForClass(classToken)
    local result = {}
    for _, template in ipairs(CLASS_SPECS[classToken] or {}) do
        result[#result + 1] = self:GetLayoutInfo(template.id)
        for _, role in ipairs(template.roles or {}) do
            local code = ROLE_CODES[role]
            local layoutID = code and (10000 + template.id * 10 + code)
            if layoutID and ROLE_LAYOUTS[layoutID] then
                result[#result + 1] = self:GetLayoutInfo(layoutID)
            end
        end
    end
    return result
end

EllesmereUI.Spec = Spec
