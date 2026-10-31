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

## Removed redundant middle weapon overrides (PR #74)

The `MainGame.gd` ancestor no longer redeclares seven weapon hooks
that were either completely shadowed by active higher facades or
semantically identical to weapon-runtime ancestors:

- `_build_weapon_ui` (active: `MainGameModeFacade`)
- `_split_turn_cluster_projectile` (active: `MainGameModeFacade`)
- `_update_turn_weapon_projectiles` (active: `MainGameSpecialWeaponsFacade`)
- `_fire_realtime_projectile` (active: `MainGameSpecialWeaponsFacade`)
- `_spawn_realtime_cluster_children` (active: `MainGameModeFacade`)
- `_turn_shell_should_explode` (inherited: `WeaponRuntimeBridge`)
- `_realtime_projectile_should_explode` (inherited: `WeaponRuntimeBridge`)

The last two collision hooks have the same tank/water/terrain/world-boundary
tests as their deleted copies. No higher override calls `super` into any
of the five shadowed `MainGame` methods. The lower weapon-runtime
methods remain defined because their own hooks still call them.
The live-scene test checks collision decisions and refuses to regress
the deleted middle-method declarations.

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

## Bouncer weapon physics

- `WeaponBounceLogic` in `scripts/weapons/` now owns pure bounce-count
  eligibility, reflected velocity with averaged damping, minimum upward
  velocity and the in-place realtime shell ground-contact update.
- `MainGameSpecialWeaponsFacade` still owns projectile collision detection,
  terrain slope lookup, registry-backed Bouncer parameters, explosions and
  gameplay state. Both turn-based and realtime Bouncer modes call the same
  bounce-limit and reflection policy; realtime shell data is deliberately
  modified in place.
- Standalone and live-scene tests cover sloped reflection, upward clamp,
  maximum permitted bounces, mutation semantics and definition-backed
  damping. Physics calculations consume no random draws.

## Weapon metadata

- **Canonical owner:** `WeaponRuntimeBridge` now composes
  `WeaponDefinitionSession`. The session builds `WeaponRegistry`
  definitions from base `WeaponCatalog` data and extended special
  definitions. This is the **only** active runtime stat source.
- **Single getter implementation:** all seven `_weapon_*` stat getters and
  generic `_weapon_value` live in `WeaponRuntimeBridge` and route through
  its composed session. The duplicate higher-facade getters in
  `MainGameModeFacade` were removed.
- **Compatibility aliases:** `MainGame` still exposes
  `weapon_definitions` and `active_weapon_loadout` initialized from the
  same inherited session. Its loadout lifecycle remains unchanged.
- **Legacy catalog:** `WeaponCatalog` remains an immutable data input for
  base weapons and external compatibility code, **not** a second live
  weapon-stat lookup. Do not reintroduce catalog-backed runtime getters.
- Live-scene tests change each of seven `WeaponDefinition` attributes and
  a Bouncer-specific extension field and verify that the inherited runtime
  metadata getters immediately return the modified values.

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
  turn-based timing/aim contracts. The turn-based session now also
  interprets final shot angle, power and movement target, including
  fallback/clamp rules; the game bridge still applies world movement,
  UI/weapon power and the fire command. The shot plan is only cleared
  **after** those applications, preserving the previous lifecycle.

## Lifecycle and UI

- `_ready`, `_process`, `reset_match` and `_draw` use chained
  overrides; never delete a stage solely on duplicate method names.
- The former `ModeRuntimeBridge` lifecycle stages are explicitly
  preserved in `WorldRuntimeBridge` compatibility helpers pending
  separate UI/mode ownership extraction.
- `MainMenuNavigationSession` owns screen and selection state;
  `MainMenuView` owns controls and screen layout; game-mode callbacks
  remain on the active game.
- `DestroyedTankSmokeSession` owns destroyed smoke target/timer,
  puff dictionaries, seeded puff emission, aging and reset. `WeaponRuntimeBridge`
  retains a typed compatibility property for `destroyed_smoke_puffs`
  and drawing, but no longer owns or ages the collection itself.
  `EffectsManager` still owns generic puff arithmetic. The standalone
  steam effect intentionally mutates puff dictionaries in place, unlike
  generic rising-puff update code that copies them.

## Retired world compatibility helpers (PR #75)

Five stale helper declarations in `WorldRuntimeBridge` are no longer part
of the active game:

- `_find_ai_shot` and `_score_ai_shot` simply forwarded to the newer
  position-aware AI search/scoring methods but had no callers.
- `_prepare_realtime_ai_shot` was an unused legacy random-aim path.
  The runtime continues to use `RealtimeAIAimingSession` and
  `_choose_realtime_ai_visual_plan`; random-number draw ordering on
  the active path is unchanged.
- `_load_texture_if_exists` forwarded to the already-composed menu view
  without callers.
- `_draw_realtime_cooldown_widgets` was an empty function invoked from
  the world draw method. The empty invocation and function are removed.

Active mode, AI and menu transitions are covered by the live-scene
regression checks. Scene inheritance stays at eight layers.

## Retired duplicate world renderer (PR #76)

The original mode-runtime helper `_mode_runtime_draw` contained a
gameplay drawing branch duplicating the real `WorldRuntimeBridge._draw`.
However, `_draw` invoked that helper only when the menu was active.
Its gameplay branch could never run; the menu branch simply delegated
to `_draw_menu_background`. The extra method and dead rendering branch
have now been removed, with the active world menu path calling
`_draw_menu_background` directly. No drawing, terrain, wind, UI or
camera function in the active gameplay branch changed.

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

## Destroyed-tank smoke ownership (PR #77)

The existing composed `DestroyedTankSmokeSession` now owns the whole
smoke lifecycle: tank selection, spawn timer, puff list, RNG-based puff
generation and rising-puff updates. The game supplies its existing seeded
`rng` when requesting emission, so each puff still consumes exactly
three random draws in the prior horizontal-offset, vertical-offset and
drift order. The game continues to draw the puffs itself and exposes the
original `destroyed_smoke_puffs` field as a typed compatibility alias.

A standalone deterministic RNG-equivalence test and active-scene tests
cover initial burst, periodic emission, setter/getter forwarding, aging and
reset. No drawing code or inheritance parent changes.

## Turn AI shot-setting ownership (PR #78)

The turn AI visual session now exposes `shot_settings` to return the
already-chosen plan's movement target, clamped firing angle, and clamped
power percentage. It does not consume or mutate the plan. The
`WeaponRuntimeBridge._take_ai_shot` wrapper retains the original ordering
of movement, power calculation, slider updates, plan clearing, and actual
firing, but no longer interprets raw plan dictionary keys itself.

## Shared tank silhouette rendering (PR #79)

Both the legacy `Main._draw_tank` and active
`WeaponRuntimeBridge._draw_tank` previously repeated the exact
tread, hull, turret and wheels drawing sequence. Those methods now
delegate to `scripts/ui/TankVisualRenderer`, a single stateless
CanvasItem renderer with pure polygon and barrel geometry helpers.

The runtime wrappers still select the camera transform, tank facing,
player angle and whether a barrel is visible. Two historical barrel
variants remain explicit: the base renderer anchors at
`(6,-15)` with a 3-pixel line, while the active weapon runtime anchors
at the tank center with a 4-pixel line. Both variants preserve the
original draw order: tread, hull, turret, barrel, wheels. Unit tests
check both directions, silhouettes and muzzle geometry. No changes
to the `_draw` override chain or rendering order.

## Shared effect drawing (PR #80)

`EffectsManager` now owns the common CanvasItem drawing loops for
explosion visuals and rising smoke circles. Previously, `Main.gd`
and `WeaponRuntimeBridge.gd` duplicated the same expanding
explosion/ray drawing code. Likewise, destroyed-smoke and muzzle-smoke
drawing in the weapon bridge and `MainGame.gd` used the same
camera projection, lifetime fade and radius calculation.

The scene-facing draw hooks remain in their original positions in
the inherited `_draw` chain, but forward the existing values to
`EffectsManager.draw_explosion` and
`EffectsManager.draw_rising_puffs`. The callers retain their distinct
weapon-specific radii, smoke colors, alpha, lifetimes and sizes.
The helper performs exactly the prior draw calls in their original order.
Unit tests cover the shared camera transform and fade/radius geometry,
while live Godot scene and multiplayer smoke tests remain mandatory.

## Weapon startup and mobile layout ownership (PR #81)

The active `WeaponRuntimeBridge._ready` still chains through the
world runtime, resizes mobile action buttons, and constructs the active
weapon selector through the derived `MainGameModeFacade._build_weapon_ui`.
It no longer calls the former `_add_main_menu_controls` and
`_relabel_quit_buttons` methods: both were explicitly disabled by
no-op overrides in `MainGame`. The unused bridge implementations,
recursive legacy label helper, and no-op descendants have been deleted.

The active four-button positions/sizes now live in the existing
`MobileControls.layout_weapon_runtime_actions` component. The bridge's
`_resize_mobile_action_buttons` method is a thin scene-facing adapter,
which preserves dynamic dispatch from world `_ready` and both reset
lifecycle calls. The world runtime's legacy FIRE position remains
untouched as a lower fallback, while the active FIRE control remains
at (696,448), size (188,70). Regression tests assert the actual
scene's positions after startup and match reset.
