# Retiring ModeRuntimeBridge: 9 → 8 active layers

The active game now inherits `WorldRuntimeBridge.gd` directly from
`Main.gd`, removing `ModeRuntimeBridge.gd` from the scene's active
inheritance chain. The explicit Godot headless CI budget is **8**.

## Migration and behavior preservation

The old mode ancestor held state shared by mode selection, online duel,
weapons and UI. Its declarations remain available on `WorldRuntimeBridge`
for compatibility, while its previously extracted behavior continues to live
in `MainMenuView`, `MainMenuNavigationSession`,
`TurnAITurnSession`, `TurnAIShotPlanner`, `TurnAIBallisticScorer`,
`RealtimeAIMovementPlanner`, `RealtimeCooldownPolicy`,
`SteamPuffEffect` and `WindMeterPolicy`.

Five mode-to-world `super` boundaries that were active in the old parent
have been converted into explicit local compatibility methods:

- `_mode_runtime_ready` preserves startup and menu construction
- `_mode_runtime_setup_realtime_single_player` preserves mode initialization
- `_mode_runtime_reset_match` preserves reset timing, physics and RNG draws
- `_mode_runtime_show_game_ui` preserves base UI visibility handling
- `_mode_runtime_draw` preserves fallback menu drawing

Methods already overridden in `WorldRuntimeBridge` that never called
their mode parent were discarded rather than migrated:
realtime movement, AI update, realtime cooldown widget drawing, and wind
widget drawing. Their active world implementations remain unchanged.

The mode ancestor's other compatibility methods were preserved at the
world boundary for existing descendants. In particular, legacy `super`
dispatch to `Main.gd` for turn advancement still works. Actual gameplay,
menu, input, and online behavior is governed by higher facades exactly as
before.

## Regression gates

Godot 4.6.3 headless import, smoke, live-scene, realtime/camera,
online contracts, host/guest ENet and scene startup are mandatory.
The live-scene tests assert the real script chain is exactly eight layers
and that the home and hotseat flows still work.

## Next target

The resulting `WorldRuntimeBridge.gd` retains compatibility hooks.
Subsequent changes should extract distinct responsibilities into small,
stateless or session-style components rather than creating another ancestor.
The next potentially removable inherited wrapper is
`WeaponRuntimeBridge.gd` after its remaining weapon, AI and effect
behavior is independently owned and tested.
