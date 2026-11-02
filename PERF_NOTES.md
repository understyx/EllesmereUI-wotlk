# Performance notes

- `EllesmereUIRaidFrames`: Wrath `UNIT_AURA` builds one shared per-event HELPFUL/HARMFUL list (`ns._BeginUnitAuraScan`) for dispel/debuff/defensive/BM consumers. Health background anchors are cached on `d._hbg*` and invalidated by `UpdateButton`/reload paths. Range alpha skips unchanged writes (0.001 tolerance vs `GetAlpha`). Max-duration BM bars drain at 20 Hz.
- `EllesmereUIRaidFrames`: `ns._SyncPowerEvents` unregisters all 11 power events and re-registers the active ones for each tracker. `UpdatePowerEventRegistration()` without a unit runs this for every unit tracker on roster changes, and `RegisterUnitEventCompat` allocates a table per registration; candidate: skip trackers whose unit, power type, and enabled state are unchanged.
- `EllesmereUIActionBars`: cooldown walk memoizes `(action, start, duration, enable, desat, alpha)` per button in `btn._eabCdMemo*`; slot/page/bonus/stance/vehicle/override/PEW events and `ForceButtonRefresh` invalidate it. Verify stance/vehicle swaps and macro edits still refresh swipes.
- `EllesmereUICdmHooks` BuffTicker: Wrath `UNIT_AURA` has no payload, so `_UpdateLegacyPlayerAuraSnapshot` diffs player buffs and bumps `ns._acGen` only on removal.
- `EllesmereUIQoL_PaladinAuras`: aura events coalesce to one refresh per frame; row layout gated by cached inputs, `Apply`/growth invalidate.
