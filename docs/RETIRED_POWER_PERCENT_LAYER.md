# Retired power-percent inheritance layer

`MainStablePowerPercent.gd` has been removed from the active gameplay
inheritance chain. `MainStableTweaks.gd` now extends `Main.gd` directly.

**Active depth: 12 → 11 scripts.**

## Extracted ownership

`PowerControlPolicy.gd` is a pure `RefCounted` utility for mapping clamped
0–100% shot power to the original launch force range 400–1200. The existing
`_power_from_percent` compatibility method delegates to it.

The former layer's fields `power_percent` and `player_power_percents`, plus
engine-facing callbacks `_ready`, `_process`, `_on_fire_pressed`,
`_end_turn_without_shot`, `_load_current_player_settings`, and `_update_ui`
now reside on the existing tweaks runtime. The original method bodies,
input ordering, reset and UI behavior remain unchanged.

`MainStableTweaks.gd` already implemented its own `reset_match`, so the
bypassed layer's reset override was not invoked by normal runtime dispatch;
it was intentionally not duplicated into the tweaks layer.

The result retires a compatibility ancestor without adding another
inheritance layer. Follow-on work should extract the remaining input,
terrain, movement and draw operations of `MainStableTweaks.gd` into
independent components rather than allowing the file to grow indefinitely.

## Verification

CI enforces a maximum of 11 active scripts, runs the strict Godot engine-error
scanner, and exercises smoke, live gameplay, realtime AI/camera, online
protocol and real two-peer ENet integration tests. Additional assertions
cover percentage/force boundary conversion, live turn handoff and reset.

Android sensor and touchscreen behavior still require eventual real-device
validation.
