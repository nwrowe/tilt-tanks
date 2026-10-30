# Legacy aiming, movement and camera policy extraction

The lowest compatibility layer `MainStableTweaks.gd` previously computed
tilt-derived aiming angle, keyboard incremental aim, tank horizontal movement
bounds/separation and camera target centering while also reading Godot Input
and performing terrain/camera side effects.

`LegacyInputMotionPolicy` is a pure, scene-independent RefCounted class
for those numeric decisions. The tweaks layer retains the Input reads and
scene mutations, but delegates the calculations. The active world runtime's
movement override now uses the same bounds and minimum tank separation rules.

This does **not** remove another inheritance layer yet: `MainStableTweaks`
still owns terrain generation, crater deformation, drawing, input callbacks
and older reset logic. The next stage should extract those responsibilities
into world and presentation components rather than merely moving 300+ lines
into `MainWithMenus.gd`.

CI adds deterministic cases for keyboard and gravity aim, inverse player
tilt directions, 45-unit world margins, 90-unit tank separation and
projectile/explosion camera focus priority. The live-scene integration
also drives the active world movement callback.

No changes to camera scaling, mobile input sources, physics constants,
terrain or network protocol are intended.
