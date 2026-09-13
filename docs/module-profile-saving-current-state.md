# Module profile saving: current implementation

This document describes the profile system as it exists in this checkout. It is a code-path analysis, not a proposed design.

## Executive summary

EllesmereUI does **not** currently save each module's active settings in that module's `...DB` SavedVariable. Almost every profile-aware module calls `EllesmereUI.Lite.NewDB(...)`, which redirects its `db.profile` directly into one central account-wide table:

```lua
EllesmereUIDB = {
    activeProfile = "Default",
    profileOrder = { "Default", ... },
    specProfiles = { [specID] = "profile name" },
    profiles = {
        ["profile name"] = {
            addons = {
                EllesmereUIActionBars = { ... },
                EllesmereUIUnitFrames = { ... },
                -- one table per managed module
            },
            fonts = { ... },
            customColors = { ... },
            darkMode = { ... },
            euiAccent = { ... },
            unlockLayout = { ... },
            specOverrides = { ... },
            condOverrides = { ... },
            -- related override group/layout stores
        },
    },

    -- important data outside profiles
    spellAssignments = { profiles = { [profileName] = { specProfiles = { ... } } } },
    syncedModules = { [moduleFolder] = { [profileName] = true } },
    fonts = { ... },
    unlockAnchors = { ... },
    unlockWidthMatch = { ... },
    unlockHeightMatch = { ... },
    -- many account-wide feature settings and caches
}
```

There are therefore four distinct persistence classes:

1. Ordinary module settings stored directly in `profiles[name].addons[folder]`.
2. Profile-level shared settings such as dark mode, accent, layout, and override stores.
3. Profile-related data stored outside the profile blob, most notably Cooldown Manager spell/spec content.
4. Account-wide or per-character data that does not switch with profiles.

The physical write to disk is still performed by WoW only on `/reload`, logout, or client exit. “Saved immediately” below means that a setting already lives in the central in-memory table WoW will later serialize.

## The normal module path

`Lite.NewDB(svName, defaults)` is the central entry point ([`EllesmereUI_Lite.lua:240`](../EllesmereUI_Lite.lua#L240)). It:

1. Derives a module folder key by removing the trailing `DB` from the requested SavedVariable name.
2. Reads `EllesmereUIDB.activeProfile`, defaulting to `Default`.
3. Creates `EllesmereUIDB.profiles[profileName].addons[folder]` if necessary.
4. Points the returned `db.profile` at that exact table.
5. Merges missing defaults into the live table.
6. Registers the database handle in `EllesmereUI.Lite._dbRegistry` for later profile repointing and logout cleanup.
7. Wipes the module's nominal SavedVariable table, such as `EllesmereUIActionBarsDB`.

As a result, a normal option setter such as `db.profile.someSetting = value` writes directly to the active central profile. `AutoSaveActiveProfile()` is intentionally a no-op because there is no separate live module DB to snapshot ([`EllesmereUI_Profiles.lua:3603`](../EllesmereUI_Profiles.lua#L3603)).

The per-module `## SavedVariables: EllesmereUI...DB` declarations remain in the child TOCs, but for modules using `NewDB` those globals are vestigial and are normally serialized as empty tables. The only authoritative suite profile file is the parent addon's `EllesmereUIDB`, declared in [`EllesmereUI.toc:6`](../EllesmereUI.toc#L6).

## Module-by-module storage

| Module | Main profile storage | Initialization | Additional or exceptional storage |
|---|---|---|---|
| Action Bars | `profiles[name].addons.EllesmereUIActionBars` | `OnInitialize` | One-time capture flag `_capturedOnce_EAB` is account-wide. Layout relationships also live in the profile's shared `unlockLayout`. |
| Nameplates | `profiles[name].addons.EllesmereUINameplates` | `OnInitialize` | Standard central profile behavior. |
| Unit Frames | `profiles[name].addons.EllesmereUIUnitFrames` | `OnInitialize` | Standard central profile behavior; shared layout and override layers can also affect it. |
| Cooldown Manager | `profiles[name].addons.EllesmereUICooldownManager` for bar definitions, styling, and positions | `OnInitialize` | Spell assignments, per-icon settings, tracked bars, glows, and related spec-owned content live separately at `EllesmereUIDB.spellAssignments.profiles[name].specProfiles[specKey]`. Cached visible bar sizes are account/character/spec data. See the dedicated section below. |
| Resource Bars | `profiles[name].addons.EllesmereUIResourceBars` | `OnInitialize` | Standard central profile plus shared override/layout stores. |
| Raid Frames | `profiles[name].addons.EllesmereUIRaidFrames` | `OnInitialize` | Buff Manager spec/condition layout forks live at the profile root in `specBmOverrides` / `condBmOverrides`. `_capturedOnce_RF` is account-wide. |
| AuraBuff Reminders | `profiles[name].addons.EllesmereUIAuraBuffReminders` | `OnInitialize` | Standard central profile behavior. |
| Quality of Life | `profiles[name].addons.EllesmereUIQoL` for selected slices | Mixed: file scope, `OnInitialize`, lazy, and `PLAYER_LOGIN` | Cursor, Bloodlust, Movement Alert, Secondary Stats, and FPS use the shared module blob. Many other QoL settings are top-level account-wide keys and do not switch with profiles. See the dedicated section below. |
| PallyPower | `profiles[name].addons.EllesmereUIPallyPower` | `OnInitialize` | `settings`, flavor-specific assignments, normal/aura assignments, and saved presets all live in this module blob. Runtime aliases are refreshed by `ActivateProfile()`. |
| Bags | `profiles[name].addons.EllesmereUIBags` | File scope in the options file | Category presentation and most bag settings are profiled. Item-to-category assignments, pins, seeding/warning state, and some caches remain account-wide. Bags is automatically placed in a sync group when the second profile is created. |
| Friends | `profiles[name].addons.EllesmereUIFriends` | `OnInitialize` | Standard central profile behavior. |
| Mythic+ Timer | Registry entry exists | No module exists in this checkout | It is ignored by loaded-module checks and has no live DB handle here. Old stored data may remain in profiles. |
| Quest Tracker | `profiles[name].addons.EllesmereUIQuestTracker` | Lazy `EnsureDB()` after `PLAYER_LOGIN`/tracker readiness | Stored under a nested `questTracker` table. |
| Minimap | `profiles[name].addons.EllesmereUIMinimap` | `OnInitialize` | Settings are nested under `minimap`; its first-capture flag is per profile. |
| Damage Meters | `profiles[name].addons.EllesmereUIDamageMeters` | Lazy `EnsureDB()` at `PLAYER_LOGIN` | Settings are nested under `dm`. Runtime combat/session data is not part of the profile blob. |
| Chat | `profiles[name].addons.EllesmereUIChat` | Lazy `EnsureDB()` at `PLAYER_LOGIN` | Settings are nested under `chat`. `EllesmereUIChatScrollDB` is declared per character, but the session-history file currently returns immediately, so this store is inactive. |
| DataBars | `profiles[name].addons.EllesmereUIDataBars` | `OnInitialize` | Bar definitions/settings are profiled. The cross-character gold ledger is account-wide at `EllesmereUIDB.dataBarsGold` and is explicitly removed from shared exports. |
| Swingbars | `profiles[name].addons.EllesmereUISwingBars` | `OnInitialize` | Appearance and enable state are profiled. Position and size are retained per profile when sync groups mirror other settings. |
| Quickdraw | `profiles[name].addons.EllesmereUIQuickdraw` | `OnInitialize` | Standard central profile behavior with first-touch legacy conversion. |
| Blizz UI Enhanced | No `addons[...]` module DB | Direct reads/writes to `EllesmereUIDB` | Most Window/Tooltip/Menu settings are account-wide. `disableWindowSkins` and `tooltipFixedPos` are stored on the active profile root. A special opt-in `blizzSkinGlobals` bundle is used for regular profile export/import. |
| Basics (legacy) | No managed profile data | Migration shim only | Its declared `EllesmereUIBasicsDB` is not connected to the central profile registry. |

The managed module list is hard-coded in [`EllesmereUI_Profiles.lua:54`](../EllesmereUI_Profiles.lua#L54). A module can use `NewDB` but still contain data outside its module blob; registration alone does not mean every setting in that addon is profile-scoped.

## Profile switching

`SwitchProfile(name)` is implemented in [`EllesmereUI_Profiles.lua:3493`](../EllesmereUI_Profiles.lua#L3493). The important behavior is:

1. Close/discard an open unlock session and close any “editing as” override sessions.
2. Harvest current spec-override values into the outgoing profile.
3. Copy the live global font table and baseline unlock layout into the outgoing profile.
4. If module sync is active, push the outgoing module blob to the other members of its sync group.
5. Change `EllesmereUIDB.activeProfile`.
6. Repoint every registered `db.profile` handle to the incoming profile's corresponding `addons[folder]` table.
7. Merge each handle's defaults into the incoming table.
8. Restore the incoming profile's layout, fonts, accent/dark-mode behavior, and override layers.

Ordinary module tables are not copied during a switch. Repointing is the switch.

`SwitchProfile()` itself does not call `RefreshAllAddons()`. The in-game dropdown, profile keybind path, and spec-change path call the refresh separately. The Wago-compatible `SetProfile(profileKey)` wrapper only calls `SwitchProfile()` ([`EllesmereUI_Profiles.lua:4827`](../EllesmereUI_Profiles.lua#L4827)), so that API path changes storage pointers without itself rebuilding all visible module state.

## Spec-assigned profiles versus Spec Overrides

These are two different systems:

- `EllesmereUIDB.specProfiles[specID] = profileName` selects an entire profile for a specialization.
- The Spec Overrides system stores selected setting values inside one profile so different specs or conditions can overlay only those settings.

Before child `OnEnable` handlers run, `PreSeedSpecProfile()` resolves the cached/live spec, changes `activeProfile`, and repoints all DBs ([`EllesmereUI_Profiles.lua:949`](../EllesmereUI_Profiles.lua#L949)). Modules whose DB is created later at `PLAYER_LOGIN` read the already-correct `activeProfile` when they call `NewDB`.

Spec and conditional override data lives at the profile root rather than inside individual module blobs. The main stores are:

- `specOverrides`, `specOverrideGroups`, `specOverrideNextId`
- `condOverrides`, `condOverrideGroups`, `condOverrideNextId`
- `specUnlockOverrides`, `condUnlockOverrides`
- `specBmOverrides`, `condBmOverrides`

An override entry identifies a module and a path inside that module's profile table, then stores a default value and spec/group-specific values. Applying an override writes the selected value into the live module table; the separate override store remains the ownership record.

Cooldown Manager is excluded from generic setting overrides because it has its own native profile/spec split. Bags, QoL, AuraBuff Reminders, Friends, Damage Meters, Mythic+ Timer, and Quest Tracker are also excluded. Minimap and Chat remain eligible except for selected engine-coupled paths. The current blacklist is in [`EllesmereUI_SpecOverrides.lua:55`](../EllesmereUI_SpecOverrides.lua#L55).

## Cooldown Manager's split storage

Cooldown Manager has two persistence locations:

```text
profiles[name].addons.EllesmereUICooldownManager
  -> profile-wide bar structure, style, and positions

spellAssignments.profiles[name].specProfiles[specKey]
  -> specialization-owned spell routing, per-icon settings,
     custom active states, Tracking Bars, and glows
```

The accessor is resolved live from `activeProfile`, so no `db.profile` repoint is needed for the external spell bucket ([`EllesmereUICooldownManager.lua:596`](../EllesmereUICooldownManager/EllesmereUICooldownManager.lua#L596)).

Because this bucket is outside `profiles[name]`, profile lifecycle operations contain explicit compensating code:

- Save As deep-copies the source bucket.
- Delete removes the bucket.
- Rename moves the bucket.
- Normal profile export converts selected spec buckets to payload field `cdmSpecs`.
- Import reconstructs the destination bucket from `cdmSpecs`.
- Module sync does **not** copy this content; it only operates on `profile.addons[folder]`.
- A CDM pre-logout callback synchronizes unlock links and cached bar sizes before default stripping.

This split is a major place where a new profile operation can look correct for all other modules but lose or retain stale CDM data if it forgets the explicit companion operation.

## Quality of Life's split storage

The QoL addon is not one uniform profile database.

Profile-scoped slices currently share `profiles[name].addons.EllesmereUIQoL`, including:

- `cursor`
- `bloodlust` (plus retained legacy `battleRes` appearance data)
- `movementAlert`
- Secondary Stats/FPS-related fields handled by `QoLExtrasGet/Set`

Several separate `NewDB("EllesmereUIQoLDB", partialDefaults)` calls point at this same root table. They do not own independent databases; they are multiple handles with different default subsets.

At the same time, a large portion of the QoL feature set reads and writes `EllesmereUIDB` directly. Examples include auto logging, teleport/keystone prompts, auto repair/sell, Shifter positions/scales, combat/group-death alerts, macros, range text, and many convenience toggles. These are account-wide. They:

- do not change when a profile changes;
- are not copied by Save As;
- are not included in a normal profile export merely because QoL is selected;
- only travel through a full-account export.

This mixed scope is likely to be perceived as inconsistent profile saving from the UI because settings presented under one module do not all follow the same profile.

## Fonts, colors, dark mode, accent, and layout

These settings are not ordinary module blobs:

- **Fonts** have a live account-root table at `EllesmereUIDB.fonts`, plus snapshots at `profiles[name].fonts`. They are copied to the outgoing profile on switch and to the active profile on logout/export, then restored from the incoming profile.
- **Custom colors** are stored on profiles, but `GetCustomColorsDB()` can redirect all profiles to one source profile when “Apply to All Profiles” is enabled. In per-profile mode it returns the active profile's table.
- **Dark mode** is always the active profile's `darkMode` table.
- **UI accent** is `profiles[name].euiAccent`, with legacy account-root values as fallback.
- **Unlock layout** uses live root tables (`unlockAnchors`, `unlockWidthMatch`, `unlockHeightMatch`, `phantomBounds`) plus `profiles[name].unlockLayout` snapshots. Snapshotting deliberately resolves the baseline rather than blindly copying a currently active spec/condition layout fork.

Because fonts and unlock data have both a live root representation and a profile snapshot, they are saved at explicit boundaries rather than on every edit. The boundaries are switch-away, export, Save As, import handling, and the pre-logout callback.

## Module sync

Sync groups are stored at:

```lua
EllesmereUIDB.syncedModules[moduleFolder][profileName] = true
```

A group is a two-way membership set. Whichever member is active can push its module data to the other members on initial sync, logout, or a settings-changed profile switch. The copy operates only on `profiles[name].addons[moduleFolder]`.

Geometry and position fields are excluded per module, and any field owned by a spec/conditional override is dynamically excluded. Cooldown Manager's external spec bucket is not synchronized. Bags is exceptional: when a second profile is created, Bags is automatically grouped, and later copies of a grouped profile join that group.

The exclusion lists are in [`EllesmereUI.lua:842`](../EllesmereUI.lua#L842).

## Logout and actual disk persistence

The Lite logout handler is in [`EllesmereUI_Lite.lua:331`](../EllesmereUI_Lite.lua#L331).

On `PLAYER_LOGOUT` it first runs registered callbacks. In the current registration flow these cover:

- profile-root fonts, custom colors, dark mode, unlock layout, and last non-spec profile tracking;
- Cooldown Manager's active-spec link/cache synchronization;
- module sync pushes.

It then iterates all registered DB handles. For each one it deep-copies `db.profile`, removes values equal to that handle's defaults, and writes the sparse result to:

```lua
EllesmereUIDB.profiles[activeProfile].addons[db.folder]
```

Only the active profile is compacted by this final pass. The live `db.profile` tables are deliberately left intact while the serialized central table receives replacement sparse copies.

WoW then serializes `EllesmereUIDB` to the parent addon's SavedVariables file. A crash or forced process termination before a normal logout/reload can therefore lose in-memory changes even though the central profile table was updated immediately.

## Copy, rename, delete, import, and export

### Save As

`SaveCurrentAsProfile(name)` deep-copies the entire active profile root, refreshes fonts/colors/dark mode/layout, explicitly copies the external CDM bucket, inserts the new name, handles Bags auto-sync membership, and switches to the copy ([`EllesmereUI_Profiles.lua:3337`](../EllesmereUI_Profiles.lua#L3337)).

### Rename and delete

Both modify the central profile table and also explicitly maintain:

- spec-to-profile assignments;
- CDM's external profile-name-keyed bucket;
- module sync memberships;
- profile keybinds.

### Regular export/import

Regular exports copy module blobs only for modules considered loaded. Addon folder keys are canonicalized so suite and standalone builds can exchange strings. Optional/global payload fields include layout, profile appearance, override stores, UI scale, the CDM `cdmSpecs` companion payload, spec assignment metadata, and the Blizz UI Enhanced global bundle.

Private/account data such as the DataBars character gold ledger is stripped in both directions.

Import starts from a copy of the current profile and replaces only the included module blobs. This preserves modules absent from a partial/standalone export. It separately installs CDM spec data, optional account-wide UI scale/window-skin data, override stores, and merged layout relationships.

### Full-account export/import

The full-account path includes almost all top-level `EllesmereUIDB` state plus the active profile, while retaining the recipient's other named profiles on import. It explicitly excludes the DataBars gold ledger. This path is the only general export that carries account-wide QoL and other miscellaneous root settings.

## Current risk areas and likely failure modes

### 1. A Movement Alert reset clears the entire shared QoL profile blob

`EllesmereUIQoL_MovementAlert.lua` creates a `NewDB` handle whose `profile` is the whole `EllesmereUIQoL` module table. Its reset calls the generic `db:ResetProfile()` ([`EllesmereUIQoL_MovementAlert.lua:226`](../EllesmereUIQoL/EllesmereUIQoL_MovementAlert.lua#L226)). Generic reset wipes the entire `db.profile`, then merges only that handle's Movement Alert defaults.

That means resetting Movement Alert can remove Cursor, Bloodlust, and QoL Extras data from the active profile. Cursor already avoids this pattern by exposing a narrowed dynamic view and implementing a slice-only reset ([`EllesmereUIQoL_Cursor.lua:1187`](../EllesmereUIQoL/EllesmereUIQoL_Cursor.lua#L1187)).

### 2. Multiple QoL DB handles make default restoration order-dependent

Every QoL handle shares the same folder but carries only part of the module defaults. `RepointAllDBs()` is safe because it visits every handle and merges every subset. `ApplyProfileData()`, however, builds a `folder -> db` map, so later QoL handles overwrite earlier ones, and it merges defaults only from whichever handle won that map ([`EllesmereUI_Profiles.lua:1117`](../EllesmereUI_Profiles.lua#L1117)).

An imported sparse QoL blob can therefore be incompletely default-filled until a later repoint or reload. Which subset is filled can depend on which lazy QoL handles have been created and their registration order.

### 3. Global-color mode can overwrite dormant per-profile palettes at save/export boundaries

When “Apply to All Profiles” is on, `GetCustomColorsDB()` returns the selected source profile's palette, not necessarily the active profile's palette ([`EllesmereUI.lua:3441`](../EllesmereUI.lua#L3441)). The pre-logout callback assigns a deep copy of that resolved table to `activeProfile.customColors` ([`EllesmereUI_Profiles.lua:4230`](../EllesmereUI_Profiles.lua#L4230)); exporting an active profile similarly updates its stored `customColors` first.

Consequently, merely logging out or exporting while viewing a non-source profile can replace that profile's dormant per-profile palette with the shared source palette. If the user later disables global-color mode, the old palette for that profile may already be gone.

### 4. Legacy child SavedVariables are discarded, not read by `NewDB`

Despite an older header comment saying the Lite DB “reads existing AceDB SavedVariables format,” `NewDB` does not import `EllesmereUIActionBarsDB.profiles`, `EllesmereUIUnitFramesDB.profiles`, and similar child data. It wipes the child global and uses only the central store.

This is fine after the one-time centralization migration has already happened, but it is a destructive upgrade boundary for any install that still has authoritative settings only in a child SavedVariables file. Blizz UI Enhanced and Basics do not call `NewDB`, so their declared child globals are instead left loaded but ignored.

### 5. Only the active profile is default-stripped on logout

Any inactive profile visited during the session had defaults merged into it by `RepointAllDBs()`, but the final stripping loop writes only to `profiles[activeProfile]`. Inactive visited profiles can therefore remain fully expanded while the active profile becomes sparse. Sync pushes can likewise leave expanded copies in inactive profiles.

This should not normally change behavior because missing values are re-filled on activation, but it creates inconsistent stored representations, larger SavedVariables, and more difficult diffs/debugging.

### 6. The nominal child DB tables create a misleading debugging surface

Most TOCs still declare a module DB, but `NewDB` empties it. Inspecting `EllesmereUIActionBarsDB` at runtime or in its WTF file will suggest the module has no saved settings even when its real data exists under `EllesmereUIDB.profiles`. Blizz UI Enhanced and Basics behave differently again because their declared module DBs are not cleared by `NewDB`.

### 7. Profile lifecycle code must remember out-of-blob companions

CDM data, layout live tables, fonts, account-wide Blizz skin settings, and various module caches do not live solely inside `profiles[name]`. The existing Save As/delete/rename/import/export flows contain explicit special cases for them. Any new profile duplication, replacement, or rename path that only copies `profiles[name]` will be incomplete.

## Practical debugging checklist

When a setting appears not to save, first classify it:

1. Is the setter writing to a registered module's current `db.profile`?
2. Is it writing directly to `EllesmereUIDB` and therefore intentionally account-wide?
3. Is it in CDM's external `spellAssignments` store?
4. Is it a live layout/font value waiting for a snapshot boundary?
5. Is a spec or conditional override rewriting the visible module value after load?
6. Is module sync copying another profile's value over it at switch/logout?
7. Did a shared QoL reset wipe sibling slices?
8. Was the client terminated without a normal logout or reload?
9. Is the developer inspecting the empty vestigial child DB instead of `EllesmereUIDB.profiles`?

The authoritative first inspection point for ordinary settings is:

```lua
EllesmereUIDB.profiles[EllesmereUIDB.activeProfile].addons
```

For CDM spell/spec contents, inspect:

```lua
EllesmereUIDB.spellAssignments.profiles[EllesmereUIDB.activeProfile].specProfiles
```
