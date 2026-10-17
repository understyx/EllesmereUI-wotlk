# Performance notes

- `EllesmereUIDBMSkin/EllesmereUIDBMSkin.lua`: DBM calls each bar's `Update` frequently. The secure post-hook only enforces the hidden alpha and marks its color dirty; icon sorting, layout, and timer text updates are throttled to a shared 0.1-second driver. Recheck hook overhead in-game with a full set of 15 active DBM bars.
- `EllesmereUIRaidFrames`: Wrath `UNIT_AURA` builds one shared per-event HELPFUL/HARMFUL list (`ns._BeginUnitAuraScan`) for dispel/debuff/defensive/BM consumers. Health background anchors are cached on `d._hbg*` and invalidated by `UpdateButton`/reload paths. Range alpha skips unchanged writes (0.001 tolerance vs `GetAlpha`). Max-duration BM bars drain at 20 Hz.
- `EllesmereUIActionBars`: cooldown walk memoizes `(action, start, duration, enable, desat, alpha)` per button in `btn._eabCdMemo*`; slot/page/bonus/stance/vehicle/override/PEW events and `ForceButtonRefresh` invalidate it. Verify stance/vehicle swaps and macro edits still refresh swipes.
- `EllesmereUICdmHooks` BuffTicker: Wrath `UNIT_AURA` has no payload, so `_UpdateLegacyPlayerAuraSnapshot` diffs player buffs and bumps `ns._acGen` only on removal.
- `EllesmereUIQoL_PaladinAuras`: aura events coalesce to one refresh per frame; row layout gated by cached inputs, `Apply`/growth invalidate.
