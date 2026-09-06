# TODO

- [ ] Consolidate Cooldown Manager event ownership. Expose compatibility-layer
  event callbacks through the shared namespace and route the main CDM,
  CooldownViewer compatibility, and Snapshot Tracker through one CDM-wide
  dispatcher. Preserve the compatibility layer's early initialization and
  central `RegisterUnitEvent` filtering while eliminating duplicate
  `COMBAT_LOG_EVENT_UNFILTERED` registrations. Do not route this through the
  current Lite event API until it supports multiple subscribers per event.
