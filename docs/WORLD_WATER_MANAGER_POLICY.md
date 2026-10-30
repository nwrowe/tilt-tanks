# World water policy reuse

`WorldRuntimeBridge.gd` already used the independent `WaterManager`
for some water and pond operations, but still duplicated other numerical
water policies.

The world runtime now delegates the following methods to `WaterManager`:
- `_pond_at_x`, `_is_in_pond`;
- `_tank_y_for_surface`, `_movement_speed_mult_at_x`;
- `_water_volume_for_range`, `_solve_water_level_for_volume`.

The active scene retains these public hook names so gameplay, AI,
projectiles, and visual interactions remain compatible. The same
terrain points, pond arrays and numerical constants are supplied to
the existing manager.

**Deliberately not migrated:** `_reflow_single_pond` and
`_reflow_water_after_terrain_change`. Their current live-game search
window differs from the alternative connected-basin algorithm in
`WaterManager`; replacing them without targeted conservation and
terrain-impact tests could change gameplay.

Standalone water tests and real-scene calls verify exact pond volume,
water level, submersion, floating tank, and movement slowdown. Full
headless gameplay, realtime and real ENet tests remain mandatory.
No inheritance layer is removed in this preparatory PR (depth remains 9).
