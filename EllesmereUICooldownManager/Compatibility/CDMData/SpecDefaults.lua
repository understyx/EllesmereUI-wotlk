local addonName, ns = ...

if not C_CooldownViewer or not C_CooldownViewer.RegisterDefinition then return end

-- Curated starting layout for a newly-created or restored spec, keyed by CDM
-- layout ID (Compatibility/Spec.lua): the spec ID, or a role layout ID for the
-- other role of a tree that can tank or deal damage (Blood DPS = 12502).
-- Contents follow the community WeakAuras packs by Iqui (3.3.5a, 5.19).
-- Entries are definition keys in display order, grouped by the default bar
-- set (ns.CDM_DEFAULT_BAR_SET):
--   cooldowns -- Core: static rotation, DoTs and maintained buffs only. Every
--                entry keeps its slot while inactive, so the bar never
--                resizes in combat.
--   highlight -- procs and damage windows that change what to press next.
--   procs     -- Buffs: periodic, semi-predictable procs. Equipment procs are
--                added for every spec.
--   utility   -- defensives, interrupts, crowd control and movement. The
--                character's racial is added for every spec.
--   snapshot  -- Core debuffs that show snapshot strength.
--   missingOnly -- hosted buffs shown only while MISSING (a buff that should
--                always be up, e.g. Divine Plea with Guarded by the Light).
-- Out-of-combat upkeep (presences, aspects, shields, flasks) belongs to Aura
-- Buff Reminders; resource-style timers (Eclipse, Arcane Blast) belong to
-- Resource Bars.
-- Each entry is placed by its catalog family (cooldown, hosted buff, or hosted
-- target debuff); everything else in the class catalog starts hidden and stays
-- available in the picker. Entries not yet learned appear once trained.

-- Shared lists, copied into each spec that uses them.
local WARLOCK_UTILITY = {
    "warlock.summon_infernal", "warlock.summon_doomguard", "warlock.soulshatter",
    "warlock.death_coil", "warlock.howl_of_terror", "warlock.fear",
    "warlock.demonic_circle_teleport", "warlock.shadow_ward", "warlock.spell_lock",
    "warlock.devour_magic", "warlock.sacrifice", "warlock.fel_domination",
    "warlock.shadowflame",
}
local MAGE_UTILITY = {
    "mage.evocation", "mage.counterspell", "mage.ice_block", "mage.blink",
    "mage.frost_nova", "mage.invisibility", "mage.fire_ward", "mage.frost_ward",
}
local SHAMAN_UTILITY = {
    "shaman.bloodlust", "shaman.heroism", "shaman.wind_shear",
    "shaman.grounding_totem", "shaman.hex", "shaman.earth_elemental_totem",
    "shaman.earthbind_totem", "shaman.stoneclaw_totem",
}
local DK_UTILITY = {
    "deathknight.icebound_fortitude", "deathknight.anti_magic_shell",
    "deathknight.mind_freeze", "deathknight.strangulate", "deathknight.death_grip",
    "deathknight.blood_tap", "deathknight.raise_dead", "deathknight.death_pact",
    "deathknight.army_of_the_dead",
}
local HUNTER_UTILITY = {
    "hunter.misdirection", "hunter.disengage", "hunter.deterrence",
    "hunter.feign_death", "hunter.freezing_trap", "hunter.frost_trap",
    "hunter.explosive_trap", "hunter.masters_call", "hunter.tranquilizing_shot",
}
local ROGUE_UTILITY = {
    "rogue.vanish", "rogue.kick", "rogue.evasion", "rogue.cloak_of_shadows",
    "rogue.feint", "rogue.sprint", "rogue.blind", "rogue.kidney_shot",
    "rogue.dismantle", "rogue.debuff.expose_armor",
}
local PALADIN_HANDS = {
    "paladin.hand_of_freedom", "paladin.hand_of_protection",
    "paladin.hand_of_sacrifice", "paladin.hand_of_salvation",
}

local function Join(...)
    local out = {}
    for i = 1, select("#", ...) do
        for _, key in ipairs((select(i, ...))) do out[#out + 1] = key end
    end
    return out
end

-- Appended to every spec's Buffs bar after its own procs: Bloodlust/Heroism
-- and the consumables the packs track for every spec. Each shows only while
-- its buff is up.
ns.CDM_DEFAULT_SHARED_PROCS = {
    "buff.bloodlust", "consumable.potion_of_speed", "consumable.potion_of_wild_magic",
    "consumable.indestructible_potion", "consumable.flame_cap",
    "consumable.oil_of_immolation",
}

ns.CDM_SPEC_DEFAULT_SPELLS = {
    -- Warrior
    [71] = { -- Arms
        cooldowns = {
            "warrior.debuff.rend", "raid.debuff.major_armor", "warrior.mortal_strike",
            "warrior.overpower", "warrior.execute", "warrior.bladestorm",
        },
        highlight = {
            "talent_proc.warrior.taste_for_blood", "talent_proc.warrior.sudden_death",
            "external_buff.hysteria",
        },
        procs = {
            "talent_proc.warrior.juggernaut", "talent_proc.warrior.wrecking_crew",
            "item_set_proc.warrior.t10_damage_2p", "item_set_proc.warrior.t8_damage_2p",
            "item_set_proc.warrior.t7_damage_4p",
        },
        utility = {
            "warrior.recklessness", "warrior.sweeping_strikes", "warrior.retaliation",
            "warrior.shattering_throw", "warrior.thunder_clap", "warrior.charge",
            "warrior.intercept", "warrior.intervene", "warrior.pummel",
            "warrior.spell_reflection", "warrior.berserker_rage", "warrior.bloodrage",
            "warrior.heroic_throw", "warrior.shield_wall", "warrior.enraged_regeneration",
        },
    },
    [72] = { -- Fury
        cooldowns = {
            "warrior.bloodthirst", "warrior.whirlwind", "warrior.execute",
            "raid.debuff.major_armor",
        },
        highlight = { "warrior.bloodsurge", "external_buff.hysteria" },
        procs = {
            "item_set_proc.warrior.t10_damage_2p", "item_set_proc.warrior.t8_damage_2p",
            "item_set_proc.warrior.t7_damage_4p",
        },
        utility = {
            "warrior.death_wish", "warrior.recklessness", "warrior.shattering_throw",
            "warrior.heroic_fury", "warrior.intercept", "warrior.pummel",
            "warrior.berserker_rage", "warrior.bloodrage", "warrior.heroic_throw",
            "warrior.enraged_regeneration", "warrior.shield_wall",
            "warrior.intimidating_shout",
        },
    },
    [73] = { -- Protection
        cooldowns = {
            "warrior.shield_slam", "warrior.revenge", "warrior.thunder_clap",
            "warrior.shockwave", "raid.debuff.major_armor", "warrior.shield_block",
            "warrior.taunt",
        },
        highlight = { "talent_proc.warrior.sword_and_board" },
        procs = { "item_set_proc.warrior.t10_tank_4p" },
        utility = {
            "warrior.shield_wall", "warrior.last_stand", "warrior.enraged_regeneration",
            "warrior.spell_reflection", "warrior.concussion_blow", "warrior.mocking_blow",
            "warrior.challenging_shout", "warrior.shield_bash", "warrior.pummel",
            "warrior.charge", "warrior.intercept", "warrior.intervene", "warrior.disarm",
            "warrior.heroic_throw", "warrior.berserker_rage", "warrior.bloodrage",
        },
    },

    -- Paladin
    [65] = { -- Holy
        cooldowns = {
            "paladin.holy_shock", "paladin.judgement_of_light",
            "paladin.buff.judgements_of_the_pure", "paladin.divine_favor",
            "paladin.divine_illumination", "paladin.divine_plea_cooldown",
            "paladin.avenging_wrath",
        },
        highlight = { "paladin.infusion_of_light", "external_buff.power_infusion" },
        procs = { "paladin.buff.lights_grace", "item_set_proc.paladin.t10_healing_4p" },
        utility = Join({
            "paladin.lay_on_hands", "paladin.aura_mastery", "paladin.divine_sacrifice",
            "paladin.divine_shield", "paladin.divine_protection",
            "paladin.hammer_of_justice", "paladin.cleanse",
        }, PALADIN_HANDS),
    },
    [66] = { -- Protection
        cooldowns = {
            "paladin.hammer_of_the_righteous", "paladin.shield_of_righteousness",
            "paladin.holy_shield_cooldown", "paladin.judgement_of_wisdom",
            "paladin.consecration", "paladin.avengers_shield",
            "paladin.debuff.holy_vengeance", "paladin.debuff.blood_corruption",
            "paladin.hammer_of_wrath", "paladin.hand_of_reckoning",
        },
        highlight = { "paladin.buff.divine_plea_guarded", "paladin.holy_shield" },
        missingOnly = { "paladin.buff.divine_plea_guarded", "paladin.holy_shield" },
        procs = {
            "paladin.buff.increased_block", "paladin.buff.sacred_shield",
            "paladin.buff.redoubt", "item_set_proc.paladin.t10_tank_4p",
            "item_set_proc.paladin.t8_tank_4p",
        },
        utility = Join({
            "paladin.divine_protection", "paladin.divine_plea_cooldown",
            "paladin.avenging_wrath", "paladin.holy_wrath", "paladin.righteous_defense",
            "paladin.divine_sacrifice", "paladin.lay_on_hands", "paladin.divine_shield",
            "paladin.hammer_of_justice",
        }, PALADIN_HANDS),
    },
    [70] = { -- Retribution
        cooldowns = {
            "paladin.crusader_strike", "paladin.judgement_of_wisdom",
            "paladin.divine_storm", "paladin.consecration", "paladin.exorcism",
            "paladin.hammer_of_wrath", "paladin.debuff.holy_vengeance",
            "paladin.debuff.blood_corruption",
        },
        highlight = { "paladin.the_art_of_war", "external_buff.hysteria" },
        procs = {},
        utility = Join({
            "paladin.avenging_wrath", "paladin.divine_plea_cooldown",
            "paladin.holy_wrath", "paladin.divine_protection", "paladin.aura_mastery",
            "paladin.divine_shield", "paladin.lay_on_hands", "paladin.hammer_of_justice",
            "paladin.repentance", "paladin.hand_of_reckoning", "paladin.cleanse",
        }, PALADIN_HANDS),
    },

    -- Hunter
    [253] = { -- Beast Mastery
        cooldowns = {
            "hunter.debuff.serpent_sting", "hunter.debuff.hunters_mark",
            "hunter.kill_shot", "hunter.arcane_shot", "hunter.multi_shot",
            "hunter.bestial_wrath", "hunter.rapid_fire",
        },
        highlight = {
            "talent_proc.hunter.the_beast_within", "talent_proc.hunter.rapid_killing",
            "external_buff.hysteria",
        },
        procs = {
            "hunter.kill_command", "talent_proc.hunter.culling_the_herd",
            "talent_proc.hunter.furious_howl", "talent_proc.hunter.quick_shots",
            "item_set_proc.hunter.t10_2p", "item_set_proc.hunter.t10_4p",
            "item_set_proc.hunter.t8_4p",
        },
        utility = Join({ "hunter.intimidation", "hunter.call_of_the_wild" }, HUNTER_UTILITY),
    },
    [254] = { -- Marksmanship
        cooldowns = {
            "hunter.debuff.serpent_sting", "hunter.debuff.hunters_mark",
            "hunter.chimera_shot", "hunter.aimed_shot", "hunter.kill_shot",
            "hunter.multi_shot", "hunter.rapid_fire", "hunter.readiness",
        },
        highlight = {
            "hunter.improved_steady_shot", "talent_proc.hunter.rapid_killing",
            "external_buff.hysteria",
        },
        procs = {
            "talent_proc.hunter.master_tactician", "talent_proc.hunter.quick_shots",
            "talent_proc.hunter.furious_howl", "item_set_proc.hunter.t10_2p",
            "item_set_proc.hunter.t10_4p", "item_set_proc.hunter.t8_4p",
        },
        utility = Join({
            "hunter.silencing_shot", "hunter.scatter_shot", "hunter.call_of_the_wild",
        }, HUNTER_UTILITY),
        snapshot = { "hunter.debuff.serpent_sting" },
    },
    [255] = { -- Survival
        cooldowns = {
            "hunter.debuff.serpent_sting", "hunter.debuff.hunters_mark",
            "hunter.explosive_shot", "hunter.black_arrow", "hunter.kill_shot",
            "hunter.aimed_shot", "hunter.multi_shot", "hunter.rapid_fire",
        },
        highlight = {
            "hunter.lock_and_load", "talent_proc.hunter.sniper_training",
            "external_buff.hysteria",
        },
        procs = {
            "talent_proc.hunter.expose_weakness", "talent_proc.hunter.master_tactician",
            "talent_proc.hunter.quick_shots", "talent_proc.hunter.furious_howl",
            "item_set_proc.hunter.t10_2p", "item_set_proc.hunter.t10_4p",
            "item_set_proc.hunter.t8_4p",
        },
        utility = Join({
            "hunter.wyvern_sting", "hunter.counterattack", "hunter.call_of_the_wild",
        }, HUNTER_UTILITY),
    },

    -- Rogue
    [259] = { -- Assassination
        cooldowns = {
            "rogue.slice_and_dice", "rogue.hunger_for_blood_buff", "rogue.envenom",
            "rogue.debuff.deadly_poison", "rogue.cold_blood",
            "rogue.tricks_of_the_trade",
        },
        highlight = { "rogue.overkill", "external_buff.hysteria" },
        procs = { "item_set_proc.rogue.t9_2p" },
        utility = Join(ROGUE_UTILITY, { "rogue.fan_of_knives" }),
    },
    [260] = { -- Combat
        cooldowns = {
            "rogue.slice_and_dice", "rogue.debuff.rupture", "rogue.debuff.deadly_poison",
            "rogue.blade_flurry_cooldown", "rogue.adrenaline_rush",
            "rogue.killing_spree", "rogue.tricks_of_the_trade",
        },
        highlight = { "external_buff.hysteria" },
        procs = { "item_set_proc.rogue.t9_2p" },
        utility = Join(ROGUE_UTILITY, { "rogue.gouge", "rogue.riposte" }),
    },
    [261] = { -- Subtlety (no pack; previous curation)
        cooldowns = {
            "rogue.slice_and_dice", "rogue.debuff.rupture", "rogue.debuff.hemorrhage",
            "rogue.shadow_dance", "rogue.premeditation", "rogue.preparation",
            "rogue.tricks_of_the_trade",
        },
        highlight = { "rogue.master_of_subtlety", "external_buff.hysteria" },
        procs = { "item_set_proc.rogue.t9_2p" },
        utility = Join(ROGUE_UTILITY, { "rogue.shadowstep", "rogue.gouge" }),
    },

    -- Priest
    [256] = { -- Discipline
        cooldowns = {
            "priest.penance", "priest.prayer_of_mending", "priest.pain_suppression",
            "priest.power_infusion", "priest.divine_hymn", "priest.hymn_of_hope",
        },
        highlight = { "priest.borrowed_time" },
        procs = { "item_set_proc.priest.t8_healing_4p" },
        utility = {
            "priest.shadowfiend", "priest.inner_focus", "priest.fear_ward",
            "priest.desperate_prayer", "priest.mass_dispel", "priest.psychic_scream",
            "priest.fade",
        },
    },
    [257] = { -- Holy
        cooldowns = {
            "priest.circle_of_healing", "priest.prayer_of_mending",
            "priest.guardian_spirit", "priest.divine_hymn", "priest.hymn_of_hope",
            "talent_proc.priest.serendipity",
        },
        highlight = { "priest.surge_of_light" },
        procs = {
            "talent_proc.priest.holy_concentration", "item_set_proc.priest.t8_healing_4p",
        },
        utility = {
            "priest.shadowfiend", "priest.inner_focus", "priest.lightwell",
            "priest.fear_ward", "priest.desperate_prayer", "priest.mass_dispel",
            "priest.psychic_scream", "priest.fade",
        },
    },
    [258] = { -- Shadow
        cooldowns = {
            "priest.debuff.vampiric_touch", "priest.debuff.devouring_plague",
            "priest.debuff.shadow_word_pain", "priest.shadow_weaving",
            "priest.mind_blast", "priest.shadowfiend", "priest.inner_focus",
        },
        highlight = { "external_buff.power_infusion" },
        procs = {
            "talent_proc.priest.improved_spirit_tap", "item_set_proc.priest.t8_shadow_4p",
            "external_buff.focus_magic",
        },
        utility = {
            "priest.shadow_word_death", "priest.dispersion", "priest.silence",
            "priest.psychic_horror", "priest.psychic_scream", "priest.fade",
            "priest.fear_ward", "priest.mass_dispel", "priest.hymn_of_hope",
        },
        snapshot = { "priest.debuff.shadow_word_pain" },
    },

    -- Death Knight. Every tree has a Tank and a DPS layout.
    [250] = { -- Blood (Tank)
        cooldowns = {
            "deathknight.debuff.frost_fever", "deathknight.debuff.blood_plague",
            "deathknight.dancing_rune_weapon", "deathknight.death_and_decay",
            "deathknight.dark_command", "deathknight.empower_rune_weapon",
        },
        highlight = { "deathknight.horn_of_winter" },
        missingOnly = { "deathknight.horn_of_winter" },
        procs = {
            "talent_proc.deathknight.blade_barrier", "talent_proc.deathknight.scent_of_blood",
            "item_set_proc.deathknight.t10_tank_4p",
        },
        utility = Join({
            "deathknight.vampiric_blood", "deathknight.rune_tap",
            "deathknight.mark_of_blood", "deathknight.hysteria",
        }, DK_UTILITY),
    },
    [12502] = { -- Blood (DPS)
        cooldowns = {
            "deathknight.debuff.frost_fever", "deathknight.debuff.blood_plague",
            "deathknight.dancing_rune_weapon", "deathknight.hysteria",
            "deathknight.death_and_decay",
        },
        highlight = { "deathknight.horn_of_winter" },
        missingOnly = { "deathknight.horn_of_winter" },
        procs = {
            "talent_proc.deathknight.bloody_vengeance",
            "item_set_proc.deathknight.t9_damage_2p",
            "item_set_proc.deathknight.t10_damage_4p",
        },
        utility = Join({
            "deathknight.empower_rune_weapon", "deathknight.vampiric_blood",
            "deathknight.rune_tap",
        }, DK_UTILITY),
    },
    [251] = { -- Frost (DPS)
        cooldowns = {
            "deathknight.debuff.frost_fever", "deathknight.debuff.blood_plague",
            "deathknight.howling_blast", "deathknight.unbreakable_armor",
            "deathknight.deathchill", "deathknight.death_and_decay",
            "deathknight.empower_rune_weapon",
        },
        highlight = {
            "deathknight.killing_machine", "deathknight.rime",
            "deathknight.horn_of_winter", "external_buff.hysteria",
        },
        missingOnly = { "deathknight.horn_of_winter" },
        procs = {
            "item_set_proc.deathknight.t9_damage_2p",
            "item_set_proc.deathknight.t10_damage_4p",
        },
        utility = Join({ "deathknight.lichborne", "deathknight.hungering_cold" }, DK_UTILITY),
    },
    [12511] = { -- Frost (Tank)
        cooldowns = {
            "deathknight.debuff.frost_fever", "deathknight.debuff.blood_plague",
            "deathknight.howling_blast", "deathknight.death_and_decay",
            "deathknight.dark_command", "deathknight.unbreakable_armor",
        },
        highlight = {
            "deathknight.horn_of_winter", "deathknight.killing_machine",
            "deathknight.rime",
        },
        missingOnly = { "deathknight.horn_of_winter" },
        procs = { "item_set_proc.deathknight.t10_tank_4p" },
        utility = Join({
            "deathknight.empower_rune_weapon", "deathknight.lichborne",
            "deathknight.hungering_cold", "deathknight.chains_of_ice",
        }, DK_UTILITY),
    },
    [252] = { -- Unholy (DPS)
        cooldowns = {
            "deathknight.debuff.frost_fever", "deathknight.debuff.blood_plague",
            "deathknight.death_and_decay", "deathknight.summon_gargoyle",
            "deathknight.ghoul_frenzy", "deathknight.empower_rune_weapon",
        },
        highlight = {
            "talent_proc.deathknight.sudden_doom", "deathknight.desolation",
            "deathknight.horn_of_winter", "external_buff.hysteria",
        },
        missingOnly = { "deathknight.horn_of_winter" },
        procs = {
            "deathknight.bone_shield_buff", "item_set_proc.deathknight.t9_damage_2p",
            "item_set_proc.deathknight.t10_damage_4p",
        },
        utility = Join({ "deathknight.anti_magic_zone" }, DK_UTILITY),
    },
    [12521] = { -- Unholy (Tank)
        cooldowns = {
            "deathknight.debuff.frost_fever", "deathknight.debuff.blood_plague",
            "deathknight.death_and_decay", "deathknight.dark_command",
            "deathknight.bone_shield", "deathknight.ghoul_frenzy",
        },
        highlight = {
            "deathknight.horn_of_winter", "deathknight.bone_shield_buff",
            "talent_proc.deathknight.sudden_doom",
        },
        missingOnly = { "deathknight.horn_of_winter", "deathknight.bone_shield_buff" },
        procs = { "item_set_proc.deathknight.t10_tank_4p" },
        utility = Join({
            "deathknight.empower_rune_weapon", "deathknight.anti_magic_zone",
        }, DK_UTILITY),
    },

    -- Shaman
    [262] = { -- Elemental
        cooldowns = {
            "shaman.debuff.flame_shock", "shaman.lava_burst", "shaman.chain_lightning",
            "shaman.thunderstorm", "shaman.fire_nova",
        },
        highlight = { "shaman.clearcasting", "external_buff.power_infusion" },
        procs = { "external_buff.focus_magic" },
        utility = Join({
            "shaman.elemental_mastery", "shaman.fire_elemental_totem",
        }, SHAMAN_UTILITY),
    },
    [263] = { -- Enhancement
        cooldowns = {
            "shaman.stormstrike", "shaman.lava_lash", "shaman.earth_shock",
            "shaman.debuff.flame_shock", "shaman.chain_lightning", "shaman.fire_nova",
            "shaman.feral_spirit",
        },
        highlight = {
            "shaman.maelstrom_weapon", "shaman.clearcasting", "external_buff.hysteria",
        },
        procs = {
            "talent_proc.shaman.elemental_devastation",
            "item_set_proc.shaman.t10_enhancement_2p",
            "item_set_proc.shaman.t10_enhancement_4p",
        },
        utility = Join({
            "shaman.shamanistic_rage", "shaman.fire_elemental_totem",
        }, SHAMAN_UTILITY),
    },
    [264] = { -- Restoration
        cooldowns = {
            "shaman.riptide", "shaman.nature_swiftness", "shaman.tidal_force",
            "shaman.mana_tide_totem",
        },
        highlight = { "shaman.tidal_waves" },
        procs = { "item_set_proc.shaman.t10_restoration_2p" },
        utility = Join({ "shaman.fire_elemental_totem" }, SHAMAN_UTILITY),
    },

    -- Mage
    [62] = { -- Arcane
        cooldowns = {
            "mage.arcane_barrage", "mage.arcane_power", "mage.presence_of_mind",
            "mage.icy_veins", "mage.mirror_image",
        },
        highlight = {
            "mage.missile_barrage", "talent_proc.mage.clearcasting",
            "external_buff.power_infusion",
        },
        procs = {
            "talent_proc.mage.arcane_potency", "item_set_proc.mage.t10_2p",
            "item_set_proc.mage.t10_4p", "item_set_proc.mage.t8_2p",
            "item_set_proc.mage.t7_2p",
        },
        utility = Join(MAGE_UTILITY, { "mage.cone_of_cold" }),
    },
    [63] = { -- Fire
        cooldowns = {
            "mage.debuff.living_bomb", "mage.debuff.pyroblast", "raid.debuff.spell_crit",
            "mage.combustion", "mage.mirror_image",
        },
        highlight = {
            "mage.hot_streak", "talent_proc.mage.firestarter",
            "talent_proc.mage.impact", "external_buff.power_infusion",
        },
        procs = {
            "item_set_proc.mage.t10_2p", "item_set_proc.mage.t10_4p",
            "item_set_proc.mage.t8_2p", "item_set_proc.mage.t7_2p",
        },
        utility = Join(MAGE_UTILITY, {
            "mage.fire_blast", "mage.dragons_breath", "mage.blast_wave",
        }),
    },
    [64] = { -- Frost
        cooldowns = {
            "mage.deep_freeze", "mage.icy_veins", "mage.cold_snap",
            "mage.summon_water_elemental", "mage.mirror_image", "mage.ice_barrier",
        },
        highlight = {
            "mage.fingers_of_frost", "mage.brain_freeze", "external_buff.power_infusion",
        },
        procs = {
            "item_set_proc.mage.t10_2p", "item_set_proc.mage.t10_4p",
            "item_set_proc.mage.t8_2p", "item_set_proc.mage.t7_2p",
        },
        utility = Join(MAGE_UTILITY, { "mage.cone_of_cold" }),
    },

    -- Warlock
    [265] = { -- Affliction
        cooldowns = {
            "warlock.debuff.improved_shadow_bolt", "warlock.debuff.corruption",
            "warlock.debuff.curse_of_agony", "warlock.debuff.unstable_affliction",
            "warlock.haunt", "warlock.debuff.shadow_embrace", "warlock.drain_soul",
            "warlock.life_tap_glyph",
        },
        highlight = {
            "warlock.nightfall", "talent_proc.warlock.eradication",
            "item_set_proc.warlock.t10_4p", "external_buff.power_infusion",
            "external_buff.tricks_of_the_trade",
        },
        procs = {
            "external_buff.spell_power", "item_set_proc.warlock.t7_2p",
            "item_set_proc.warlock.t7_4p", "external_buff.focus_magic",
        },
        utility = WARLOCK_UTILITY,
        snapshot = { "warlock.debuff.corruption" },
    },
    [266] = { -- Demonology
        cooldowns = {
            "warlock.debuff.improved_shadow_bolt", "warlock.debuff.immolate",
            "warlock.debuff.corruption", "warlock.debuff.curse_of_agony",
            "warlock.metamorphosis", "warlock.life_tap_glyph",
            "external_buff.spell_power",
        },
        highlight = {
            "warlock.molten_core", "warlock.decimation", "warlock.nightfall",
            "talent_proc.warlock.immolation_aura", "item_set_proc.warlock.t10_4p",
            "external_buff.power_infusion", "external_buff.tricks_of_the_trade",
        },
        procs = {
            "item_set_proc.warlock.t7_2p", "item_set_proc.warlock.t7_4p",
            "external_buff.focus_magic",
        },
        utility = Join({ "warlock.demonic_empowerment", "warlock.intercept" }, WARLOCK_UTILITY),
        snapshot = { "warlock.debuff.corruption" },
    },
    [267] = { -- Destruction (no pack; previous curation)
        cooldowns = {
            "warlock.debuff.immolate", "warlock.conflagrate", "warlock.chaos_bolt",
            "warlock.shadowburn", "warlock.debuff.curse_of_agony",
            "warlock.life_tap_glyph",
        },
        highlight = {
            "warlock.backdraft", "warlock.backlash", "talent_proc.warlock.empowered_imp",
            "item_set_proc.warlock.t10_4p", "external_buff.power_infusion",
            "external_buff.tricks_of_the_trade",
        },
        procs = {
            "talent_proc.warlock.pyroclasm", "item_set_proc.warlock.t7_2p",
            "item_set_proc.warlock.t7_4p", "external_buff.focus_magic",
        },
        utility = Join({ "warlock.shadowfury" }, WARLOCK_UTILITY),
    },

    -- Druid
    [102] = { -- Balance
        cooldowns = {
            "druid.debuff.moonfire", "druid.debuff.insect_swarm",
            "druid.debuff.faerie_fire", "druid.starfall", "druid.force_of_nature",
            "druid.typhoon",
        },
        highlight = {
            "druid.eclipse_solar", "druid.eclipse_lunar",
            "talent_proc.druid.owlkin_frenzy", "external_buff.power_infusion",
        },
        procs = {
            "talent_proc.druid.natures_grace", "druid.omen_of_clarity",
            "item_set_proc.druid.t8_balance_4p", "item_set_proc.druid.t10_balance_2p",
            "external_buff.focus_magic",
        },
        utility = {
            "druid.innervate", "druid.barkskin", "druid.rebirth", "druid.natures_grasp",
            "druid.tranquility",
        },
    },
    [103] = { -- Feral (DPS): cat
        cooldowns = {
            "druid.savage_roar", "druid.debuff.rip", "druid.debuff.rake",
            "druid.debuff.mangle", "druid.debuff.faerie_fire_feral",
            "druid.tigers_fury", "druid.berserk",
        },
        highlight = { "druid.omen_of_clarity", "external_buff.hysteria" },
        procs = { "item_set_proc.druid.t10_feral_4p" },
        utility = {
            "druid.survival_instincts", "druid.barkskin", "druid.faerie_fire_feral",
            "druid.dash", "druid.feral_charge_cat", "druid.feral_charge_bear",
            "druid.maim", "druid.bash", "druid.frenzied_regeneration",
            "druid.innervate", "druid.rebirth",
        },
    },
    [11031] = { -- Feral (Tank): bear
        cooldowns = {
            "druid.debuff.lacerate", "druid.mangle_bear", "druid.faerie_fire_feral",
            "druid.debuff.demoralizing_roar", "druid.growl", "druid.berserk",
        },
        highlight = { "druid.omen_of_clarity" },
        procs = { "item_set_proc.druid.t10_feral_4p" },
        utility = {
            "druid.survival_instincts", "druid.barkskin", "druid.frenzied_regeneration",
            "druid.enrage", "druid.challenging_roar", "druid.bash",
            "druid.feral_charge_bear", "druid.dash", "druid.innervate", "druid.rebirth",
        },
    },
    [105] = { -- Restoration
        cooldowns = {
            "druid.swiftmend", "druid.wild_growth", "druid.natures_swiftness",
            "druid.tranquility", "druid.innervate",
        },
        highlight = { "druid.omen_of_clarity" },
        procs = {},
        utility = { "druid.barkskin", "druid.rebirth", "druid.natures_grasp", "druid.dash" },
    },
}
