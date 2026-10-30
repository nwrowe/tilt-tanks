# Retired realtime AI aiming bridge

The active Godot scene previously traversed a standalone 76-line
`RealtimeAIAimingBridge.gd`, situated between the world runtime and
weapon runtime, to maintain AI visual aiming state and override realtime
AI update/setup/reset methods.

This refactor removes that inheritance layer. The weapon runtime now
extends `WorldRuntimeBridge.gd` directly, reducing the active
inheritance chain from **16 to 15 scripts**.

A new scene-independent `RealtimeAIAimingSession` owns the visual target
angle, power percentage, plan validity, and the existing
`RealtimeAIController` smoothing/noise and cooldown policies. The world
runtime retains the necessary gameplay hooks, which query the composed
session when selecting targets, moving the AI, and firing projectiles.

The previous order of reset, game setup, AI movement, aiming and firing is
preserved. The existing public runtime AI methods remain callable. The
former public `rt_ai_visual_*` variables have moved into
`realtime_ai_aim`, which is used by the live-scene tests.

The Godot suite checks AI planning and re-planning, realtime projectile
launch, owner-aware camera behavior, hotseat gameplay, weapon logic, and
the actual two-process ENet duel. This is a structural extraction, not
a change to AI difficulty, aiming speed or fire cooldown.
