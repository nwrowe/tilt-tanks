# Match health and winner consolidation — phase 1

The active game runtime still owns its tank_health variable while legacy
damage and weapon code is migrated. MatchController now accepts the two
tank health values as one atomic snapshot through sync_health_values.

The controller validates array length, clamps health at zero and recomputes
winner/game-over only after every tank value has been installed.

Previously MatchRuntimeBridge copied health into MatchState and called
set_health separately for each player on each runtime update.
The new bridge calls sync_health_values once, then updates the legacy
game_over field from the controller. The redundant
_recompute_match_winner_from_runtime_health method is removed.

The controller is now the only writer of MatchState.tank_health on the
runtime synchronization path. Existing legacy damage routines still update
the gameplay runtime health values; retiring that mirror requires another
test-backed migration of projectile and damage ownership.

## Tests

- Controller: ordinary damage, simultaneous defeat/draw, healing/recovery,
  clamping, malformed frame lengths.
- Live scene: runtime-to-controller health agreement, winner changes, tied
  destruction and reset.
- Existing: hotseat, weapons, realtime AI/camera and live two-peer ENet duel.

No UI, wire protocol or other gameplay transitions are intentionally changed.
