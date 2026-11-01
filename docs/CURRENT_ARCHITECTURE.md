# Current architecture — November 1, 2026

The active Godot 4.6.3 scene is `res://scenes/Main.tscn`. It attaches
`res://scripts/core/MainGameOnlineHostWaitingFacade.gd`.

## Active inheritance: seven scripts

```text
MainGameOnlineHostWaitingFacade.gd
  -> MainGameProgressionFacade.gd
  -> MainGameSpecialWeaponsFacade.gd
  -> MainGameModeFacade.gd
  -> MainGame.gd
  -> WorldRuntimeBridge.gd
  -> Main.gd (Node2D)
```

`WeaponRuntimeBridge.gd` was retired in PR #94. The last scene-facing
weapon compatibility hooks were absorbed by `MainGame`, while actual
projectile physics, impact decisions, weapon definitions, splitting
logic and transient state remain in the existing grouped services.
This removes one real inheritance layer **without adding a service
or an additional horizontal wrapper**.

Do not add new facade/inheritance layers. The CI depth guard now enforces
**max-depth 7** against the actual scene script. The older
`ModeRuntimeBridge.gd` was retired earlier; see
`docs/RETIRED_MODE_RUNTIME_BRIDGE.md`. Older diagrams and PR
descriptions are historical rather than the current inheritance graph.

## Composed gameplay services

- Match: `MatchState`, `MatchController`,
  `MatchRuntimeSynchronizer`, and damage/weapon policies
- AI (`scripts/ai/`): `TurnAITurnSession`, `TurnAIVisualAimSession`,
  `TurnAIShotPlanner`, `TurnAIBallisticScorer`, `RealtimeAIMovementPlanner`,
  and `RealtimeAIAimingSession` (`RealtimeAIController` remains in
  `scripts/modes/` because it participates in the mode registry)
- Modes: `ModeControllerRegistry`, `ActiveModeState`, `RealtimeCooldownPolicy`, hotseat,
  realtime, campaign and network-mode controllers
- UI: `MainMenuView`, `MainMenuNavigationSession`, `WindMeterPolicy`,
  `MainMenuPresentation`, `CampaignMapView`, `TankGarageView`,
  `WeaponSelectMenu` and other UI builders
- World: `TerrainMath`, `TerrainManager`, `WaterManager` and
  `SnowManager`
- Effects: `EffectsManager`, `SteamPuffEffect`, and
  `DestroyedTankSmokeSession`
- Online duel: packet/command validation, snapshot encoding,
  synchronization, interpolation and sequenced events

The scene and remaining facades still own interaction with engine nodes and
compatibility methods. Pure calculations and independently testable session
state should continue moving to composed services. Retiring an ancestor
should not add a replacement inheritance layer.

## Active online multiplayer

Online Duel is implemented and guarded with packet/snapshot contract tests
and an actual two-process ENet host/guest test. Historical notes describing
Online as merely a placeholder are no longer accurate.

## Required verification for every architecture change

The `.github/workflows/godot-smoke.yml` pipeline runs:

1. Inheritance depth budget (seven scripts)
2. Godot 4.6.3 import and script-class registration
3. Standalone contracts and smoke tests
4. Active-scene gameplay and menu integration
5. Online command/snapshot contracts
6. Realtime AI and camera integration
7. Two independent headless Godot processes exercising ENet
8. Main scene startup

CI treats Godot runtime `SCRIPT ERROR` output as a failure even when the
engine returns status 0. Preserve consistent RNG draw ordering and inherited
lifecycle behavior in all follow-up extractions. Android export and on-device
behavior are separate validation targets and are not covered by this CI.

## Keep the architecture deep enough to be clear, not wide enough to be messy

Retiring the weapon bridge is **not** permission to put independent algorithms
in `MainGame.gd`. Its remaining compatibility functions are thin scene
adapters and must continue forwarding work to the existing domain owners:

- **Weapon data and loadout** — `scripts/weapons/WeaponDefinitionSession.gd`
  with `WeaponDefinition`, `WeaponRegistry`, `WeaponLoadout` and
  `WeaponSplitLogic`; avoid parallel registries
- **Projectiles** — `scripts/weapons/ProjectileManager.gd` for step/impact
  policy, `ProjectileFactory.gd` for geometry, and
  `TurnProjectileSession.gd` for active shell state
- **Effects** — `scripts/effects/DestroyedTankSmokeSession.gd` and
  `EffectsManager.gd` for smoke/effect state, aging, and drawing policy
- **AI** — the existing `scripts/ai/` planner, scorer and visual-aim
  sessions; the world runtime coordinates AI turn timing
- **UI, terrain and online play** — existing `scripts/ui/`,
  `scripts/terrain/`, and `scripts/network/` groupings

No new subclasses or one-method service wrappers should be introduced simply
to lower a file's line count. When refactoring `WorldRuntimeBridge.gd`
or `MainGame.gd`, first consolidate closely related methods within the
*existing* domain services. Preserve the online serialization and RNG order.
In particular, `MainGame` is still a large scene-facing orchestration script;
**the seven-layer collapse does not complete the remaining modularization**.

## Mode identity compatibility

The former unused `GameMode.gd` integer enum has been deleted. The active
runtime still uses `GAME_MODE_*` integer compatibility values in
`WorldRuntimeBridge.gd` and canonical string IDs in
`ModeControllerRegistry.gd`. `MainGameModeFacade.gd` owns their
conversion. This is a necessary transitional adapter, not a reason to add
a new third set of mode identifiers.

## Scene compatibility adapter organization (PR #95)

After bridge retirement, remaining `MainGame` hooks are grouped by the
scene interaction they coordinate: projectile contact directly after
firing, realtime and turn explosions together, crater updates beside
radial damage, and the legacy stat getters beside the definition/loadout
compatibility functions. These are **not** new independent services:
the existing `scripts/weapons/` managers retain calculations and
`scripts/effects/` retains puff/effect state. Grouping avoids recreating
the deleted inheritance layer as scattered one-method helper classes.
A source-level check protects this grouping in addition to the usual
behavioral integration tests.

## Pause-menu and weapon selector ownership (PR #96)

`PauseMenu` now constructs and lays out the active pause panel,
using the existing `UIManager` button-layout policy. `MainGame` only
owns the callbacks, panel visibility and engine lifecycle; there is no
second pause-panel geometry implementation in the game coordinator.
The obsolete three-choice weapon selector body in `MainGame` was
reduced to a virtual compile-time hook needed by inherited `_ready`:
the active, loadout-driven selector remains
`MainGameModeFacade._build_weapon_ui` backed by `WeaponSelectMenu`
and `WeaponDefinitionSession`. These changes do not create another
class, alter the seven-layer chain or change weapon availability.

## Fire-button presentation ownership (PR #97)

The hotseat/realtime fire-button charge gradient, unavailable colors and
theme application now live in the existing `MobileControls` module,
reusing `UIManager.style_button`. `WorldRuntimeBridge` retains only
its input/charge lifecycle and passes button + charge ratio to the UI.
The scene and mode overrides use the same UI owner, with no new class
or additional facade. Contract tests cover the gradient, clamping,
style geometry, pressed state and unavailable palette.

## Canonical launch geometry and world collision fallback (PR #98)

The world compatibility launcher and active standard/Heavy/Cluster turn
launcher now use the existing `ProjectileFactory.make_fired_shell`.
Both launch paths still own their input gating, weapon/owner selection,
projectile flags and effects; only the previously repeated muzzle and
velocity trigonometry was consolidated. No random draws or packet
formats were changed. The shadowed lower realtime collision fallback was retired instead of
reintroducing an identical implementation of the active
`MainGame._realtime_projectile_should_explode` hook. That active hook
uses `ProjectileManager.should_shell_explode`, preserving
tank/pond/terrain/out-of-world ordering. Live tests verify both turn
and realtime contact policy, as well as canonical turn, realtime and
special weapon launch geometry.

## Host frame scheduling ownership (PR #100)

`MainGameOnlineHostWaitingFacade._process` is the **sole** host sync
scheduler call site. The older `MainGameProgressionFacade._process`
previously also invoked the overridden scheduler after `super._process`,
causing two coordinator time advances in the same host frame. Removed
the duplicate call, shadowed lower implementation and obsolete lower
interval constant. The existing `OnlineDuelHostCoordinator` retains
the timer and safe-advance policy; the online facade retains distinct
active/idle cadence (0.033 s / 0.10 s). Gameplay, hotseat handoff and
client interpolation paths retain their original dispatch. Source
regression checks and real two-process ENet tests protect this boundary.

## Single owner for mode power labels (PR #101)

`MainGameModeFacade._update_ui` previously called
`MainGame._update_ui` and then recalculated the same hotseat/realtime
power label, producing two UI updates on each gameplay frame. The mode
controller's realtime label method delegates to the same
`RealtimeSinglePlayerMode.shell_status_label` policy already used by
`MainGame`, and `_is_active_mode` resolves realtime from the same
`game_mode` flag. The repeated override has been retired rather than
creating another UI policy or forwarding class. Active scene tests cover
hotseat idle/charging and realtime shell-in-flight/charging states.

## Composed match-reset state ownership (PR #102)

The seven-layer `reset_match` order is unchanged. `MainGame` now uses
its existing `_reset_hotseat_charge` hook and no longer clears the
world-owned turn-AI visual plan before its parent does so again:
`TurnAITurnSession.reset()` remains the sole owner of the turn timer
and visual-plan reset. `WorldRuntimeBridge` now uses its existing
`_reset_realtime_charge_state` for both match reset and realtime-mode
setup. Realtime shell activation remains separately reset by the world.
No new services or repeated state mirrors were introduced. Live
integration seeds stale AI, hotseat charge, realtime charge and button
appearance state before testing the real reset hierarchy.

## Online disconnect and match-reset cleanup (PR #103)

The online facade now calls `online_interpolation.reset()` and
`online_host_coordinator.clear_fallback()` directly where appropriate,
removing two redundant one-line reset wrappers. On disconnect,
`MainGameProgressionFacade._online_disconnect` already resets the
host coordinator (sync timer **and** fallback), so the online facade
no longer repeats these mutations; it only resets its own snapshot
sequencer, interpolation and waiting-room presentation. Match reset
retains its pre-parent interpolation/fallback clearing and does **not**
reset the host sync cadence. Live network contract tests seed stale
timers, interpolation and sequence state and verify both transitions.

## Single-publish progression build reset (PR #104)

`MainGameProgressionFacade._initialize_player_tank_builds` now only
constructs per-player build instances. At initial startup,
`_initialize_progression_state` publishes them once to the existing
`MatchController`. At match reset, the parent
`MatchController.start_match` replaces its built-in default builds,
then the progression facade publishes its instances **once afterward**.
The previous before-and-after pair of controller writes was redundant;
this change preserves creation and `super.reset_match()` order, avoids
a pre-parent state write, and adds live identity/default-value checks.

## Machine-gun camera focus ownership (PR #105)

`ProjectileManager.leading_shell_focus_for_weapon` now owns the shared
selected-weapon projectile average/leading-shell interpolation. The
special-weapons scene adapter only supplies weapon ID, owner direction,
bias and the camera destination; it retains the last focus when no
matching rounds remain. This moves the entire calculation to an
existing weapon/projectile owner, without adding a new class. The
`MainGameSpecialWeaponsFacade.reset_match` also stops clearing the
machine-gun camera twice: `_clear_machine_gun_burst` already owns
that state. Live and policy tests cover either firing direction,
mixed shell types, the empty-round sentinel, and match reset.

## Composed weapon burst session (PR #106)

`WeaponBurstSession` is one new, substantive state owner in the existing
`scripts/weapons/` domain. It owns the multi-round sequence: owner,
shot angle/power, realtime or turn mode, remaining rounds, cadence,
random jitter calculation and waiting-for-projectiles completion rule.
The special-weapons facade retains weapon metadata selection, actual
shell/FX spawning, camera view, damage and turn advancement. Only
`machine_gun_active` and `machine_gun_turn_waiting_for_shells` remain
as forwarding properties for the higher online/network facades; all
other burst state is directly read from the composed session. This
creates a reusable lifecycle for future burst-capable weapons without
adding an inheritance layer or a collection of one-method helpers.
Live scene and isolated policy tests assert per-round RNG order,
overshoot timing, metadata-driven shot counts, projectile creation
and match reset.

## Canonical turn-advance safety predicate (PR #107)

`WeaponFramePolicy.can_advance_turn` is now the sole stateless check
for game-over, live projectile, multi-shell, burst, burst-wait and
explosion/camera-hold clearance. The scene's pending hotseat turn
completion and its same-frame camera freeze delegate to that rule.
`OnlineDuelHostCoordinator.can_advance` preserves its public API but
forwards to the same gameplay policy instead of maintaining another
duplicate rule. Actual `_advance_turn`, camera changes, host fallback,
and authoritative RPCs remain in their owning scene/network code.
Regression tests exercise every blocking condition and a live
delayed hotseat turn switch. No new class or inheritance layer.

## Special-weapon terrain geometry ownership (PR #108)

Laser terrain cutting and Ground Bomb mound deformation now use
`TerrainManager` alongside the established crater calculation, with
nearest-segment geometry centralized in `TerrainMath`.
`MainGameSpecialWeaponsFacade` still chooses weapon metadata and owns
scene state, refresh, water reflow, FX and camera behavior. Laser reflow
still executes **after** terrain redraw; Ground Bomb still refreshes
only (no new water algorithm). No additional behavior class, scene
ancestor or weapon-specific service was created. Pure geometry and live
metadata override tests cover the cuts, mounds, endpoint and floor
bounds, and forward delegation.

## Laser direct-hit health authority (PR #109)

The Laser's nearest-segment direct-hit test still uses
`TerrainMath.point_to_segment_distance` and the live
`WeaponDefinition` damage/radius fields. On a hit it now calls
`MatchRuntimeSynchronizer.apply_direct_damage`, which uses the
existing `MatchController.apply_damage` and copies the resulting
health into the legacy scene. This is the same controller-owned
health/winner path as radial shell explosions, so a full online
snapshot produced in the same firing call contains authoritative
damage. Misses still do nothing; Laser still deals no splash
damage. Unit and live tests cover targeting, configurable damage,
copy isolation, overkill, winner assignment, and immediate network
packet consistency. No new state owner, class or inheritance layer.

## Behavior-driven Laser profile dispatch (PR #110)

Hotseat, charged realtime and direct realtime Laser calls now dispatch
on the existing `WeaponDefinition.behavior == "laser_cut"` rather than
the literal weapon ID. The selected weapon ID flows through the
existing Laser fire, terrain and direct-damage hooks so each profile
uses its **own** width, depth, direct radius and damage. Their old
signatures still default to `WeaponRegistry.WEAPON_LASER` for
existing compatibility calls. The rest of the scene still owns
input gating, camera, FX and gameplay turn advancement. A live
regression test registers a second temporary Laser profile into
the existing definition session and loadout, fires it in hotseat
and realtime modes, verifies metadata-specific damage and
network snapshots, and restores the original registry and loadout.
No class, abstract factory, second registry or inheritance expansion.
