# Active gameplay method ownership — October 30, 2026

This document identifies which implementations actually own selected
high-risk game methods in the **eight-layer** `Main.tscn` inheritance chain.
It should be updated when a method is moved or an ancestor retired.
The source of truth remains the scene script and Godot's runtime dispatch.

## Projectile simulation

| Hook | Active owner/dispatch | Lower compatibility implementation |
|---|---|---|
| `_update_projectile` | `MainGameSpecialWeaponsFacade` handles Bouncer; ordinary turn shells go through `super` to `WeaponRuntimeBridge`, which calls `ProjectileManager`. | `Main.gd` has its earlier prototype update, shadowed in this scene. |
| `_update_all_realtime_projectiles` | `MainGameSpecialWeaponsFacade` handles special shells; for ordinary shells it calls `super` into `MainGameModeFacade`, which owns human/AI-aware cluster tracking, hit handling and camera focus. | `WeaponRuntimeBridge` has the older simple simulation fallback; `WorldRuntimeBridge` retains a no-op compatibility hook. Neither is reached by the current normal/special scene path. |
| `_realtime_projectile_should_explode` | The most-derived `MainGame` implementation in the active chain handles terrain and pond checks; `WeaponRuntimeBridge` and `WorldRuntimeBridge` retain fallback methods. | Do not remove fallback signatures without checking callers and `super` references. |

The old `MainGame._update_all_realtime_projectiles` loop was shadowed
by `MainGameModeFacade` and was removed in PR #70. The same exact active
logic was already running before that deletion. A live realtime test
checks AI-only and human-owned shell availability after dispatch.

## Projectile launch geometry

- `ProjectileFactory.make_fired_shell` owns the shared muzzle-offset and
  initial velocity calculation used by both ordinary realtime shell fire and
  `MainGameSpecialWeaponsFacade._spawn_special_shell`. This removes duplicate
  trigonometry without introducing another service class.
- The calling facade still chooses owner, shot angle, force, weapon and
  whether a projectile goes to the realtime or turn-based collection.
  It also retains cap enforcement, muzzle effects, fire-state updates,
  and any special weapon behavior.
- Unit tests cover both facing signs and the exact shell dictionary contract;
  real-scene tests cover standard and Bouncer launch geometry.

## Weapon metadata

- **Active**: `MainGameModeFacade._weapon_*` getters call
  `_weapon_value`, implemented by `MainGame` using
  `WeaponDefinitionSession` / `WeaponRegistry`.
- **Fallback**: `WeaponRuntimeBridge._weapon_*` getters use
  `WeaponCatalog` legacy defaults; their current active-scene
  counterparts are overridden by the mode facade.
- **Data bootstrap**: `WeaponRegistry.build_default_definitions()`
  reads the four legacy `WeaponCatalog` entries and registers
  special weapon definitions. The catalog is not a second active mutable
  weapon-stat store.
- A regression test modifies a `WeaponDefinition` instance and verifies
  the active `_weapon_direct_damage` getter observes the change.

Preserve `WeaponCatalog` until the weapon bridge is retired or all
standalone compatibility consumers are migrated. Avoid adding further
catalog-only active getters.

## Terrain and water

- `WaterManager` is the numerical authority for pond generation,
  lookup, volume integration, water levels and connected-basin reflow.
- `WorldRuntimeBridge._reflow_single_pond` delegates to `WaterManager`.
  The redundant `MainGame` override and the old changed-X-biased
  fallback algorithm are removed (PR #69).
- Scene-facing `_reflow_water_after_terrain_change` keeps pond array
  lifecycle and its public changed-X argument.

## Mode state and controllers

- `WorldRuntimeBridge` keeps `GAME_MODE_*` integer compatibility
  constants; `ModeControllerRegistry` owns string mode IDs.
  `MainGameModeFacade` contains the explicit adapter between them.
  The unused third `GameMode` enum was deleted in PR #68.
- `HotseatMode` and `RealtimeSinglePlayerMode` are **static policies**,
  needed by lower base scripts. The corresponding
  `*ModeController` objects are the **mode-registry interfaces**,
  so thin forwarding exists intentionally until those lower direct
  calls are migrated safely.
- `RealtimeAIAimingSession` and `TurnAIVisualAimSession` live
  in `scripts/ai`. They intentionally have different real-time versus
  turn-based timing/aim contracts.

## Lifecycle and UI

- `_ready`, `_process`, `reset_match` and `_draw` use chained
  overrides; never delete a stage solely on duplicate method names.
- The former `ModeRuntimeBridge` lifecycle stages are explicitly
  preserved in `WorldRuntimeBridge` compatibility helpers pending
  separate UI/mode ownership extraction.
- `MainMenuNavigationSession` owns screen and selection state;
  `MainMenuView` owns controls and screen layout; game-mode callbacks
  remain on the active game.
- `DestroyedTankSmokeSession` owns destroyed smoke target/timer;
  `EffectsManager` owns generic puff arithmetic. The standalone
  steam effect intentionally mutates puff dictionaries in place, unlike
  generic rising-puff update code that copies them.

## Remaining cleanup priorities

1. Prove the special-weapon and online branches of realtime projectile
   simulation can share a smaller simulation primitive **without
   changing owner-sensitive camera and explosion behavior**.
2. Eventually migrate `WeaponRuntimeBridge` fallback catalog getters
   when the source-of-truth definition session is available at their
   future owner.
3. Narrow the `WorldRuntimeBridge` compatibility surface before any
   attempt to retire `WeaponRuntimeBridge` (8 → 7).
4. Keep the separate Godot/import, smoke, live gameplay, realtime/camera,
   packet contracts and actual two-process ENet gates green.
