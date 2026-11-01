## Unified realtime projectile stepping (PR #116)

Active owner: `MainGameModeFacade._update_all_realtime_projectiles`.
It integrates each realtime shell exactly once. Only the
`MainGameSpecialWeaponsFacade._realtime_special_shell_step` hook
implements Bouncer contact, while the special facade's realtime
override now performs post-frame burst availability and camera
focus only. Normal frames retain the earlier mode-level cluster
camera aggregate; special frames retain the owner-aware explosion
semantics and bypass the normal cluster camera aggregate. Do not
reintroduce a second simulation loop into the special facade.

# Active gameplay method ownership — updated November 1, 2026

This document identifies which implementations actually own selected
high-risk game methods across architecture refactor PRs.
**Current chain depth: seven layers.** Sections below from earlier PRs
describe historical dispatch before the bridge retirement; the newest
architecture section at the end overrides those historical descriptions.
It should be updated when a method is moved or an ancestor retired.
The source of truth remains the scene script and Godot's runtime dispatch.

## Projectile simulation

| Hook | Active owner/dispatch | Lower compatibility implementation |
|---|---|---|
| `_update_projectile` | `MainGameSpecialWeaponsFacade` handles Bouncer; ordinary turn shells go through `super` to `WeaponRuntimeBridge`, which calls `ProjectileManager`. | `Main.gd` has its earlier prototype update, shadowed in this scene. |
| `_update_all_realtime_projectiles` | `MainGameSpecialWeaponsFacade` handles special shells; for ordinary shells it calls `super` into `MainGameModeFacade`, which owns human/AI-aware cluster tracking, hit handling and camera focus. | The unreachable older simulation fallback in `WeaponRuntimeBridge` was removed in PR #84; `WorldRuntimeBridge` retains a no-op compatibility hook. |
| `_realtime_projectile_should_explode` | `WeaponRuntimeBridge` selects the realtime target and delegates ordered tank/pond/ground/world contact checks to `ProjectileManager.should_shell_explode`; the turn shell hook calls the same policy with its turn owner rule. | `WorldRuntimeBridge` retains the lower legacy fallback; the bridge hooks stay declared for inherited callers. |

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
- **Compatibility aliases:** `MainGame` now exposes
  `weapon_definitions` and `active_weapon_loadout` as typed forwarding
  properties on the composed session, with no separate references to sync.
  Assignment and reset of the loadout go through that sole owner.
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

## Weapon per-frame stage selection (PR #82)

The pure `WeaponFramePolicy` now determines which stage the inherited
`WeaponRuntimeBridge._process` should execute. The ordering is
**game over → weapon menu → turn shells → normal/world frame**,
only while in gameplay, with the turn-shell stage excluded in realtime
mode. The bridge keeps the original side effects and their order:
projectile stepping, explosion lifetime, camera/UI updates, smoke
aging, redraw, and the `super._process` call on the normal stage.
The special-weapons, mode and online facades still intercept frames
through their existing chained `_process` implementations.

The policy is free of scene nodes and random draws. Standalone stage
tests cover all priorities, menu state, turn shells and realtime mode;
active-scene checks verify hotseat and realtime mode interpretation.
The eight-level inheritance budget is not changed.

## Turn-projectile ownership and reset sequencing (PR #83)

`TurnProjectileSession` is the canonical owner of the typed turn-shell
array, the active turn-projectile weapon ID, and the split-completed flag.
`WeaponRuntimeBridge` retains compatible typed getters/setters for
`turn_projectiles`, `turn_projectile_weapon`, and
`turn_projectile_split_done`, so hotseat, special weapons, mode
controllers and online snapshot code continue to use their original
names. The session's `reset_for_match` clears the existing array **in
place**, preserving array handles held by other gameplay subsystems.
It then stores the weapon selected by the upper mode reset and clears
the split flag.

`WeaponRuntimeBridge.reset_match` preserves its critical call ordering:
first reset turn projectile state, explosion visual radius, smoke session,
and visual AI plan; next call `super.reset_match` to reset the world;
finally restore mobile action geometry and close the weapon menu.
The surrounding mode/level/progression/online reset stages remain
unchanged. Deterministic and live-scene regression tests verify legacy
property forwarding, retained array references, selected weapon and split
state, successive resets, and the post-parent UI layout.

## Safe realtime weapon-bridge fallbacks retired (PR #84)

Three shadowed lower realtime fallback implementations have been
removed from `WeaponRuntimeBridge`:
`_fire_realtime_projectile`,
`_update_all_realtime_projectiles`, and
`_spawn_realtime_cluster_children`.
The active firing handler is in `MainGameSpecialWeaponsFacade`;
the active realtime shell loop and cluster splitting are in
`MainGameModeFacade`. The special facade's realtime
`super._update_all_realtime_projectiles` call terminates at
`MainGameModeFacade`. The lower `WorldRuntimeBridge` declarations
remain available for inherited mode compatibility.

Godot requires ancestor script methods called from an ancestor to
retain declarations even when derived scripts override those methods
in the active scene. In particular, the following `WeaponRuntimeBridge`
fallbacks are **not** removable by deletion alone:
`_build_weapon_ui`, `_toggle_weapon_menu`,
`_split_turn_cluster_projectile`,
`_update_turn_weapon_projectiles`, and `_apply_weapon_damage`.
Those methods will need explicit replacement or ownership migration
before the entire bridge layer can be retired.

The new live-scene test checks both sides of this boundary. All active
physics, UI, turn shell, reset, effects, and network behavior remains
in the original dispatch path; eight inherited layers remain.

## Weapon menu presentation lifecycle (PR #85)

The existing `WeaponSelectMenu` view helper now owns opening and
closing the weapon selector panel, as well as releasing focus from the
three mobile action buttons when opening. The `WeaponRuntimeBridge`
still owns the gameplay flags `weapon_menu_open` and `overlay_open`,
mobile movement states, and inherited menu/return lifecycle. It calls
the view helper at the same points and in the same order as the
previous inline visibility/focus operations.

This consolidates the UI representation without creating another
gameplay service or changing mode, progression, online or weapon
selection callbacks. Standalone tests cover visibility and optional
controls; live-scene tests cover opening, closing, global overlay hide,
and returning to the main menu.

## Shared turn/realtime projectile impact policy (PR #86)

Both `WeaponRuntimeBridge._turn_shell_should_explode` and
`_realtime_projectile_should_explode` now select the appropriate enemy
tank and call `ProjectileManager.should_shell_explode`.
`ProjectileManager` owns the common impact policy: opposing tank,
pond, ground contact, then world bounds. The three environment
lookups are passed as lazy `Callable` objects so a collision early in
the sequence never evaluates later pond/terrain/floor queries. This
preserves the old performance and observation order while eliminating
duplicate collision logic from the active bridge.

The two bridge methods retain their original names and distinct
target-index selection for hotseat and realtime modes; the lower
world fallback remains for compatibility. Standalone tests assert
contact outcomes **and the exact short-circuit lookup order**.
Active-scene tests check both owners, airborne and ground contact,
world boundaries and delegation to the canonical policy. No
additional physics state, random draws or network changes.

## Canonical weapon metadata compatibility (PR #87)

`MainGame` formerly maintained its own `weapon_definitions` dictionary
reference and `active_weapon_loadout` object reference, with explicit
copy-back assignments in its loadout update/reset methods. These are now
forwarding properties of `WeaponDefinitionSession`. There is no second
mutable reference to become stale when a level or registry changes.
The loadout setter uses the session's existing null guard; registration
and gameplay/weapon stat APIs remain unchanged. A live-scene test
replaces the dictionary and loadout, validates read/write forwarding,
rejects null, resets the default loadout and restores prior state.

## Unified turn AI timing and visual state (PR #88)

`TurnAITurnSession` (created by `WorldRuntimeBridge`) now owns its
`TurnAIVisualAimSession` instance alongside pending/think-time state.
`WeaponRuntimeBridge.turn_ai_visual` is a forwarding property instead
of a separate instantiated session. Both timer and plan reset through
`TurnAITurnSession.reset()` in the world lifecycle, while the bridge
retains its prior pre-parent visual-plan clear to preserve reset timing.
`cancel()` retains the visual plan as before, since the final shot clears
it after applying the selected settings. All existing visual properties,
random draw order, gameplay, and external scene callbacks are unchanged.
Unit and active scene tests validate shared ownership and reset behavior.

## Weapon lifecycle override retirement (PR #89)

`WeaponRuntimeBridge` no longer defines `_ready`, `_process`, or
`reset_match`. These three deeply chained stages are consolidated into
the already-active `MainGame` lifecycle, with precisely the same order:

- Startup: run the world/legacy parent startup, apply the weapon mobile
  layout, build the active mode-facade weapon menu, then connect
  `MainGame`'s hotseat fire handlers and its remaining UI setup.
- Frame: run `MainGame`'s camera/input timer work, select the same
  `WeaponFramePolicy` stage and perform the same stage effects, enter
  `WorldRuntimeBridge._process` only for `NORMAL`, then synchronize
  match state and update muzzle effects.
- Reset: clear MainGame input/camera state, sanitize the selected weapon,
  reset the turn projectile, smoke and AI visual sessions before the world
  reset; then restore mobile control layout and close the selector before
  MainGame controller/UI synchronization.

The remaining `WeaponRuntimeBridge` is still inherited for active
AI, weapon, projectile and drawing hooks, compatibility properties,
and Godot ancestor compile-time method contracts. This intentionally
does **not** claim an eight-to-seven collapse yet. Live-scene tests
assert no locally declared lifecycle overrides, dispatch ordering and
the actual reset/UI result. Existing Godot import, camera, combat and
real two-process ENet gates protect end-to-end behavior.

## Turn-based AI ownership moved into WorldRuntimeBridge (PR #90)

The world runtime already owns the turn-based AI's pending phase/timer,
planning and movement. Its formerly dormant implementations of
`_begin_ai_turn`, `_process_ai_turn` and `_take_ai_shot` were replaced
with the previously active exact weapon-bridge implementations, including
visual-plan generation and barrel slew. The corresponding two other
methods (`_make_ai_visual_shot_plan`, `_update_ai_visual_aim`) and
turn visual compatibility properties also reside in the world runtime.
The weapon bridge no longer declares or owns those AI methods/properties.

Visual ownership remains in `TurnAITurnSession.visual`; its RNG
consumption and movement/firing order are unchanged. Existing tests
for seeded plan noise, firing and timing are supplemented by active
scene tests for the new method owner and animation/reset behavior.
This removes active AI behavior from a weapon-specific inheritance
ancestor without altering the eight-layer chain.

## Rendering and game-over camera ownership (PR #91)

The active `MainGame` now directly owns tank geometry rendering,
destroyed-smoke drawing, realtime projectile drawing and explosion
drawing (still delegating to the existing pure
`TankVisualRenderer` and `EffectsManager`). The weapon bridge no
longer implements `_draw`, `_draw_tank`,
`_draw_destroyed_smoke_puffs`, `_draw_realtime_projectiles` or
`_draw_explosion`.

`MainGame._draw` retains exact ordering after the world draw:
destroyed smoke, recoil barrels, muzzle smoke, and cluster shells.
The game-over destroyed-tank camera fallback formerly in the
weapon bridge now resides in `MainGame._camera_target_x` **after**
manual camera/cluster focus/hold precedence and **before**
`super._camera_target_x` (the unchanged world fallback).
This preserves both higher special-weapon camera overrides and
the original game-over focus behavior. Rendering tests assert
source ownership, draw order and an active-scene destroyed-tank
camera target. No new inheritance layer or rendering service.

## Weapon selector lifecycle ownership (PR #92)

The scene-level `MainGame` now directly owns the six active weapon
menu lifecycle hooks: `_resize_mobile_action_buttons`,
`_open_weapon_menu`, `_close_weapon_menu`, `_hide_overlays`,
`_quit_game`, and `_return_to_main_menu`. The identical hook bodies
were moved from `WeaponRuntimeBridge`. This places overlay flags,
mobile input release, selector presentation, quit navigation and
action-button layout next to the MainGame input/UI coordination that
already calls them.

`MainGame._hide_overlays` still chains to the same lower base
`Main._hide_overlays` logic and then hides the selector. The mode and
progression facades continue to own the active loadout menu build and
higher-level network/progression behavior. The original
`_build_weapon_ui` fallback and unused `_make_weapon_menu_button`
are also owned by `MainGame`; the shadowed `_toggle_weapon_menu`
implementation in the bridge was deleted. This co-locates all UI
compiler contracts with the scene UI lifecycle, while the mode facade
still overrides weapon-menu construction for the active game.
Tests verify source ownership and the active menu open/close,
movement release, global overlay hide, quit navigation and
mobile-control geometry.

The first import attempt demonstrated Godot's ancestor compilation
requirement: removing `_open_weapon_menu` and `_close_weapon_menu`
from the bridge while leaving its fallback builder there could not
compile. The corrected implementation moved the fallback builder to
`MainGame` as well and removed the bridge's now-unused shadowed
toggle. The active-mode builder remains unchanged.

## Destroyed-tank effect grouping (PR #93)

Destroyed-smoke constants, `DestroyedTankSmokeSession` ownership,
the legacy field aliases, game-over visual sequencing,
`_show_end_popup`, and the three smoke spawn/aging scene hooks now live
together in the existing `MainGame` effects area. They no longer
reside in the intermediate weapon bridge. Smoke generation, RNG draw
order, age updates and puff collection remain in the same composed
`scripts/effects/DestroyedTankSmokeSession.gd`; no additional classes
or service layers were created. Effect drawing had already moved
to `MainGame` in PR #91.

All existing external hook and property names are preserved.
Regression checks cover both source ownership and actual destroyed-tank
puff spawn/reset in the active scene; the smoke RNG parity test remains
unchanged. This consolidates **effects as a domain** without
proliferating helper wrappers.

## Weapon bridge retired — current seven-layer ownership (PR #94)

The active scene now inherits `MainGameOnlineHostWaitingFacade` →
`MainGameProgressionFacade` → `MainGameSpecialWeaponsFacade` →
`MainGameModeFacade` → `MainGame` → `WorldRuntimeBridge` →
`Main.gd`. The deleted `WeaponRuntimeBridge` is no longer a parent
or a source file. The CI guard enforces a maximum depth of **seven**.

No replacement class was created. Required weapon/turn projectile hooks,
properties, stat-getter compatibility, snow presentation constants and
realtime explosion adapters now live together in the existing
`MainGame` script, beside its other scene-facing scene callbacks.
The redundant lower fallback `_on_fire_pressed`,
`_explode_turn_weapon`, `_apply_weapon_damage` and no-op
`_unhandled_input` were **not** copied: the already-active
`MainGame` implementations remain, and realtime `super._on_fire_pressed`
still dispatches to `WorldRuntimeBridge`.
`MainGameSpecialWeaponsFacade._update_projectile` continues to call
`super` for ordinary shots, now entering the same moved method in
`MainGame`; mode and special projectile overrides are unchanged.

Domain owners remain grouped in existing folders, **not** flattened into
new horizontal service classes: weapon metadata/allowed loadouts through
`WeaponDefinitionSession`; projectile stepping, impact and split logic
through `ProjectileManager`, `ProjectileFactory`, and
`TurnProjectileSession`; smoke through `DestroyedTankSmokeSession`
and `EffectsManager`; AI through `scripts/ai/`.
The remaining `MainGame` wrappers are engine/lifecycle boundaries.
Regressions must exercise RNG, online packet shape, hotseat and realtime
shell behavior and actual ENet, not merely source ownership.
