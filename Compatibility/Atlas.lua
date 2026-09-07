_G.EUI_AtlasMap = {
    ["uitools-icon-close"] = "Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-close.tga",
    ["Azerite-PointingArrow"] = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
    ["shop-card-wide-frame-default"] = "Interface\\DialogFrame\\UI-DialogBox-Background",
    ["shop-card-wide-frame-hover"] = "Interface\\DialogFrame\\UI-DialogBox-Background",
    ["lootroll-animreveal-a"] = "Interface\\TargetingFrame\\UI-StatusBar",

    ["Ui-Dialog-New-Background"] = "Interface\\DialogFrame\\UI-DialogBox-Background",
    ["UI-QuestTrackerButton-Secondary-Collapse"] = "Interface\\Buttons\\UI-MinusButton-Up",
    ["UI-QuestTrackerButton-Secondary-Expand"] = "Interface\\Buttons\\UI-PlusButton-Up",
    ["QuestLog-main-background"] = "Interface\\QuestFrame\\UI-QuestLog-Background",
    ["UI-RefreshButton"] = "Interface\\Buttons\\UI-RotationLeft-Button-Up",
    ["characterupdate_background"] = "Interface\\DialogFrame\\UI-DialogBox-Background",
    ["VAS-icon-checkmark-glw"] = "Interface\\RAIDFRAME\\ReadyCheck-Ready",
    ["charactercreate-icon-dice"] = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    ["bag-main"] = "Interface\\Buttons\\Button-Backpack-Up",
    ["Crosshair_Quest_64"] = "Interface\\Icons\\INV_Misc_QuestionMark",
    ["UI-HUD-RotationHelper-Inactive-2x"] = "Interface\\Buttons\\UI-Quickslot-Depress",
    ["UI-HUD-ActionBar-IconFrame-Slot"] = "Interface\\Buttons\\UI-EmptySlot",
    ["common-icon-sound"] = "Interface\\OptionsFrame\\VoiceChat-Play",
    ["common-icon-sound-pressed"] = "Interface\\OptionsFrame\\VoiceChat-Down",
    ["Interface\\AnimaChannelingDevice\\AnimaChannelingDeviceLineVerticalMask"] = "Interface\\AddOns\\EllesmereUI\\media\\textures\\soft-line",

    -- Minimap replacements use retail atlas names.  Wrath has no atlas API,
    -- so point those names at artwork that is present in the 3.3.5 client
    -- instead of letting GetAtlasPath fall back to INV_Misc_QuestionMark.
    ["Map-Filter-Button"] = "Interface\\WorldMap\\UI-World-Icon",
    ["Map-Filter-Button-down"] = "Interface\\WorldMap\\UI-World-Icon",
    ["AdventureMap-combatally-ring"] = "Interface\\Buttons\\UI-Quickslot2",
    ["wowlabs_minimapvoid-ring-single"] = "Interface\\AddOns\\EllesmereUI\\media\\basics\\ring_normal.tga",
    ["UI-HUD-Minimap-Tracking-Up"] = "Interface\\Icons\\Ability_Tracking",
    ["UI-HUD-Minimap-Tracking-Mouseover"] = "Interface\\Icons\\Ability_Tracking",
    ["UI-HUD-Minimap-Tracking-Down"] = "Interface\\Icons\\Ability_Tracking",
    ["UI-HUD-Minimap-Mail-Up"] = "Interface\\Icons\\INV_Letter_15",
    ["UI-HUD-Minimap-Mail-Mouseover"] = "Interface\\Icons\\INV_Letter_15",
    ["housefinder_neighborhood-friends-icon"] = "Interface\\Icons\\INV_Misc_GroupLooking",
}

-- The retail calendar publishes one atlas per day and button state.  The
-- legacy calendar uses a single texture, which is still preferable to thirty
-- one question-mark icons and preserves the custom button's click behavior.
for day = 1, 31 do
    local prefix = "UI-HUD-Calendar-" .. day
    _G.EUI_AtlasMap[prefix .. "-Up"] = "Interface\\Calendar\\UI-Calendar-Button"
    _G.EUI_AtlasMap[prefix .. "-Mouseover"] = "Interface\\Calendar\\UI-Calendar-Button"
    _G.EUI_AtlasMap[prefix .. "-Down"] = "Interface\\Calendar\\UI-Calendar-Button"
end
