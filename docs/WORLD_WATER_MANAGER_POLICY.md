# World water policy ownership (updated October 30, 2026)

`WaterManager.gd` is the single numerical authority for pond lookup,
submersion, float geometry, water volume, surface height and **pond reflow**.

## Compatibility calls retained in the runtime

`WorldRuntimeBridge.gd` still provides these engine/game-facing method
names for descendant scripts:

- `_pond_at_x`, `_is_in_pond`
- `_tank_y_for_surface`, `_movement_speed_mult_at_x`
- `_water_volume_for_range`, `_solve_water_level_for_volume`
- `_reflow_single_pond`, `_reflow_water_after_terrain_change`

All listed numerical operations delegate to `WaterManager`. The old
changed-X-biased reflow search loop has been removed. Previously, the active
`MainGame.gd` override **already** used
`WaterManager.reflow_single_pond`; its redundant override was removed
as well. Consequently active gameplay keeps the same connected-basin
algorithm while the inherited compatibility fallback now agrees with it.

`_reflow_water_after_terrain_change(changed_x)` retains its scene-facing
signature and pond collection/update lifecycle. The called
`_reflow_single_pond` accepts the changed X coordinate for compatibility,
but the canonical connected-basin algorithm does not use it.

## Verification

A deterministic live-scene test compares the inherited game call against
`WaterManager.reflow_single_pond` for a modified basin, checks independence
of `changed_x`, verifies stored and integrated water volume, and exercises
the terrain reflow loop. Full Godot 4.6.3, hotseat, realtime/camera and
two-process ENet regression gates still apply.

This supersedes the older section claiming the two reflow methods must
remain separate. No active inheritance layer was added or removed.
