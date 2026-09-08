# EllesmereUI PallyPower module

This module adapts PallyPower Improved for EllesmereUI. It is installed and
enabled like the other EllesmereUI child modules, appears in the **QoL Addons**
group, and stores its settings, assignments, and presets in the active
EllesmereUI profile under `EllesmereUIPallyPower`.

## Bar layout

PallyPower is exposed directly as a mover in EllesmereUI Unlock Mode. Dragging
moves the complete bar freely and saves its exact position; it is not docked or
snapped back to a screen edge. The Display page can arrange all primary and
class controls as a vertical or horizontal bar. Individual-player controls
remain available from their class button.

## EllesmereUI styling

The blessing controls use EllesmereUI's active accent, pixel borders,
global or per-module font and outline, and the shared EUI bar-texture catalogue.
SharedMedia status-bar textures are appended to the same Display dropdown.

## Assignments

Blessing assignments are edited directly on the module's **Assignments** page.
Detected Paladins are rows and classes are columns. Scroll a cell to cycle its
blessing, or hold Shift while scrolling to change the entire Paladin row.
Assignments can be changed for your own row, for every row while you are group
leader/assistant, or for a Paladin who enabled Free Assignment. Changes use
PallyPower's synchronization rules and update the bar immediately. Both
`/pp` and `/epp` open this native page.

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
- `SetFreeAssignment(enabled)`
- `GetAuraAssignment(paladinName)`
- `RequestRefresh()`
- `RefreshProfile()` and `ResetProfile()`

Consumers must tolerate the module being disabled, in which case
`EllesmereUI.PallyPower` is `nil`.

Aura/Buff Reminders uses this API on Paladins to scope Kings and Might checks
to the active class and individual assignments. If the module is unavailable
or the player has no assignments, reminders retain their normal behavior.
