# EllesmereUI PallyPower module

This module adapts PallyPower Improved for EllesmereUI. It is installed and
enabled like the other EllesmereUI child modules, appears in the **QoL Addons**
group, and stores its settings, assignments, and presets in the active
EllesmereUI profile under `EllesmereUIPallyPower`.

## Edge flyout

The original movable drag handle is replaced by a compact `PP` tab docked to
the left, right, top, or bottom screen edge. Hovering the tab securely opens
all assigned class controls at once, including during combat. Individual-player
controls remain available from their class button. Left-click pins or unpins
the flyout; right-click opens the native EllesmereUI Assignments page. Edge,
position, and pinned state are configured on the module's Display page.

The tab is also exposed as a PallyPower mover in EllesmereUI Unlock Mode.
Dragging moves the complete flyout origin; saving docks it to the nearest
screen edge, while discarding restores the previous edge and position.

## EllesmereUI styling

The tab and blessing controls use EllesmereUI's active accent, pixel borders,
global or per-module font and outline, and the shared EUI bar-texture catalogue.
SharedMedia status-bar textures are appended to the same Display dropdown.

## Assignments

Blessing assignments are edited directly on the module's **Assignments** page.
Each detected Paladin gets one dropdown per class. Changes use PallyPower's
normal permission and synchronization rules and update the flyout immediately.
Both `/pp` and `/epp` open this native page.

## Shared API

Sibling modules should access the runtime through `EllesmereUI.PallyPower`.
The public integration methods are:

- `IsReady()`
- `IsPlayerPaladin()`
- `GetProfile()` and `GetOptions()`
- `GetFlavor()`
- `GetRoster()`
- `GetAssignments()`
- `GetAssignedBlessing(paladinName, classIDOrToken, playerName)`
- `GetAssignedBlessingForUnit(paladinName, unit)`
- `HasAssignmentsForPaladin(paladinName)`
- `HasBlessingAssignment(paladinName, blessingID)`
- `SetClassAssignment(paladinName, classIDOrToken, blessingID)`
- `GetAuraAssignment(paladinName)`
- `RequestRefresh()`
- `RefreshProfile()` and `ResetProfile()`

Consumers must tolerate the module being disabled, in which case
`EllesmereUI.PallyPower` is `nil`.

Aura/Buff Reminders uses this API on Paladins to scope Kings and Might checks
to the active class and individual assignments. If the module is unavailable
or the player has no assignments, reminders retain their normal behavior.
