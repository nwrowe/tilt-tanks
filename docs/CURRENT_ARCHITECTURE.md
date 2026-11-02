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

## Metadata-driven Bouncer profiles (PR #111)

The Bouncer's turn-based and realtime projectile dispatch now uses
the canonical `WeaponDefinition.behavior == "bounce"`, not a literal
weapon ID. Bounce limits and reflection damping are resolved from the
actual turn projectile or realtime shell weapon ID. The existing
`WeaponBounceLogic` remains the sole reflection and mutable shell
contact policy; terrain/water collision and scene explosion/FX remain
on the scene. The old reflect hook retains its default Bouncer
argument for source compatibility. Its upward-speed constant is now
named for Bouncer physics rather than an unrelated camera subsystem.
Live integration creates an additional temporary Bouncer definition,
exercises turn bounce then max-bounce detonation and realtime rebound,
and restores the default definitions/loadout. No new class or layer.

## Metadata-driven burst profile routing (PR #112)

Machine Gun firing in hotseat, charged realtime and AI/realtime routes
now dispatches on the existing `behavior == "machine_gun"` metadata,
not a literal parent ID. The current `WeaponBurstSession` owns the
source profile ID and configured child-round ID alongside its prior
cadence, owner and completion state. Actual counts/interval/jitter
resolve from the selected profile; round spawning, camera tracking,
special-projectile routing and per-round explosion hold suppression
use the active child ID. Default round compatibility is retained.
The old scene and session burst hooks retain optional parameter defaults
for existing callers. Live tests add a temporary second burst profile
and distinct child definition, exercise hotseat and charged realtime
firing, timing, camera focus and session reset, then restore the registry.
No new type, duplicated registry or inheritance layer was introduced.

## Burst child realtime capacity consistency (PR #113)

Realtime shell insertion previously exempted only the literal
`machine_gun_round` from the active projectile cap. It now uses the
same session-backed `_is_burst_round` predicate as camera and
explosion processing, so alternative burst child IDs retain their
no-eviction behavior even after the burst's last round is emitted.
Live regression fills the realtime shell pool, checks that an
alternate child round preserves existing shells, and verifies that
an ordinary shell still evicts the oldest when the pool is full.
No new component, state, or inheritance layer.

## Non-mutating realtime camera target (PR #114)

The special-weapons camera override no longer temporarily overwrites
`explosion_timer` and `explosion_pos` to suppress AI explosion
camera focus. The inherited `MainGame` and `WorldRuntimeBridge`
realtime camera already choose a human projectile, human tank or
explicit camera-hold target independent of those two fields. The
scene now calls `super._camera_target_x()` directly, preserving
the explosion's state while computing the same camera destination.
Live camera regression checks the target with and without AI
explosion metadata and verifies no mutation or temporary-field
logic. No new class, hook or inheritance layer.

## Shared special-weapon impact lifecycle (PR #115)

`MainGameSpecialWeaponsFacade._apply_weapon_impact` is now the
single scene-facing sequence for weapon explosion position and
duration, radius, crater and damage, and tank settlement. Turn and
realtime callers retain their original projectile flag, camera owner,
per-round camera hold, winner popup and delayed turn advance steps.
No new helper class or cross-domain service; only a cohesive shared
method in the existing scene owner. A live regression restores identical
terrain, tank positions, health and impact in turn/realtime modes and
compares resulting terrain, settled tanks, controller health and FX
while verifying owner-sensitive camera behavior.

## One realtime projectile simulation owner (PR #116)

`MainGameModeFacade._update_all_realtime_projectiles` now owns
one projectile update loop for both ordinary and special shells.
The special-weapons facade no longer reimplements stepping,
collision/split dispatch and array replacement: its remaining
override calls `super`, then maintains active burst availability
and Machine Gun camera focus. A narrow
`_realtime_special_shell_step` hook delegates Bouncer-only terrain
contact to the already-existing special-weapon physics logic. The
mode facade's default hook is a no-op for ordinary shells and its
special-active gate preserves the previous behavior of suppressing
ordinary cluster camera aggregation while special rounds are active.
Special explosions still receive the actual owner; ordinary
explosions still use the existing mode-owned camera aggregate.
Live camera tests exercise mixed Bouncer/human/AI shells and protect
the single-loop source ownership; full ENet regression remains required.
No new class or inheritance layer.

## Shared online guest frame stages (PR #117)

`MainGameProgressionFacade` owns the single online-client local input
gate and the camera/UI/muzzle/redraw completion stage. Its non-network
override composes those two existing frame responsibilities;
`MainGameOnlineHostWaitingFacade` adds only the authoritative motion
interpolation and guest explosion visual aging between them. The
original order **interpolation → input/charge → explosion expiry →
camera/UI/effects** is retained. Only the online guest processes
network-authoritative state; offline gameplay still follows its normal
simulation. Source-level protocol tests protect ownership/order, while
the real two-process ENet smoke test covers guest gameplay rendering.
No additional class or scene ancestor.

## Shared full/motion snapshot state application (PR #118)

Full and motion online receivers still deliberately differ in terrain
replacement and interpolation. Their duplicated turn-projectile
clear/deep-copy loop and the final guest aim/charge/UI/MatchState sync
have one scene owner in `MainGameProgressionFacade`:
`_online_apply_turn_shell_snapshot` and
`_online_finish_received_snapshot`. Both receiver paths invoke them
in their original relative order, retaining typed shell-array identity,
filtered/deep-copied packet shells and local-current-player settings.
Tests cover both call sites, deep-copy isolation and MatchState sync.
The full/motion wire formats, sequencing, UI, interpolation and host
authority are unchanged.

## Single online turn-transition snapshot authority (PR #119)

Turn progression previously sent a full snapshot from
`MainGameProgressionFacade._advance_turn`, a second from
`MainGameOnlineHostWaitingFacade._advance_turn`, and a third from
the upper explosion-hold/fallback wrapper. The online-host
`_advance_turn` override is now the sole publisher for a completed
turn, after it clears the fallback coordinator and requests the next
host sync. The redundant upper
`_maybe_advance_after_explosion_hold` method is retired; regular
and fallback advances still invoke the same virtual
`_advance_turn` path. Fire/impact snapshots and explicit remote
commands remain distinct reliable events. Source-level contracts
protect the ownership and ordering; full ENet integration verifies
the active host/guest transport behavior.

## Two-process ENet complete-turn regression (PR #120)

The two independent Godot ENet peers now test an actual heavy weapon
impact through `_explode_turn_weapon`, physics/FX clearance,
host-authoritative turn advancement to the guest, guest start-turn
RPC approval, and a guest-originated standard shot accepted and
simulated by the host. Both peers assert authoritative player/health
and shell state, including the guest's wait-for-authority gate.
This extends the former fire-plus-manually-injected-damage test
without introducing a second game simulation or protocol.

## Single authoritative shot publication (PR #121)

The previous online `_on_fire_pressed` override retransmitted a
second full snapshot after the progression-level snapshot, while
guest-originated shots bypassed that top override and therefore had
no matching projectile launch event. Both accepted fire routes now
use `_online_publish_authoritative_shot`: the online facade emits
one physical launch event first, then the progression facade sends
one reliable authoritative state snapshot. Instant Laser and burst
shots still send one snapshot without a fictitious standalone shell
event. A blocked or unreleased local charge sends no shot snapshot;
remote command validation also respects pending turn and burst state.
The live two-process ENet test asserts the exact event+snapshot
sequence increment for a host fire and exercises guest-originated fire.

## Removed shadowed mode explosion hooks (PR #122)

Both `MainGameModeFacade._explode_turn_weapon` and
`MainGameModeFacade._explode_realtime_weapon` were fully shadowed
by the existing special-weapons facade and were never reached through
`super`. Their extra camera/forwarding behaviors were inactive.
These stale implementations are deleted rather than moved into
another class. The live scene still calls the existing special
explosion hooks, common impact lifecycle, and the separate mode
`_explode` camera adapter. Live tests and actual ENet preserve
the active launch/impact/turn behavior.

## Shared turn and realtime shell contact scene adapter (PR #123)

`MainGame._turn_shell_should_explode` and
`_realtime_projectile_should_explode` remain as compatibility hooks,
but both call one `_shell_should_explode` scene implementation.
For two-player gameplay, the target is always the opposing tank.
The sole `ProjectileManager.should_shell_explode` invocation
preserves tank, water, terrain and world-boundary test order.
This does not conflate Bouncer ground contact, Cluster splitting,
camera focus or online host authority. Live-scene tests verify
both owners and contact types and enforce only one scene adapter.

## Shared Bouncer contact in turn and realtime (PR #124)

`MainGameSpecialWeaponsFacade._step_bouncer_shell` now owns
tank/pond/boundary checks, bounce-limit evaluation, reflection and
ground-position adjustment for both modes. Turn gameplay converts
its legacy scalar `projectile_pos`, `projectile_vel` and
`turn_bouncer_bounce_count` into a short-lived shell dictionary,
calls the same routine, then copies results back. No second mutable
session or per-mode bounce algorithm exists. A terminal ground
contact returns its snapped impact position for legacy turn
explosions; realtime shells retain their pre-existing raw-stepped
explosion position and dictionary mutation semantics. Live tests
compare the modes at first/terminal contacts, enemy ownership and
metadata behavior.

## Legacy turn projectile shares canonical impact resolution (PR #125)

`ProjectileManager.impact_position` now owns the same lazy contact
sequence for the legacy single turn projectile, spawned turn-shell
collections and realtime shells: opponent tank, pond, terrain, then
out-of-world bounds. It returns `Vector2.INF` for no impact. Only
the legacy turn call requests a ground-snapped impact position;
ordinary shell impact retains its raw stepped coordinate. The
existing `should_shell_explode` boolean API delegates to the
same numerical policy, and `MainGame` invokes it through its
single scene adapter. Cluster splitting still runs before contact;
Bouncer still uses its separate ground-rebound rule. Standalone
and live-scene tests check collision order, lazy geometry, ground
position, active turn explosion and parity across both modes.

## One scalar/dictionary projectile motion integrator (PR #126)

`ProjectileManager.step_legacy_projectile` now owns the sole
Euler gravity/wind/position calculation. `step_shell` continues
to deep-copy an input shell (including nested metadata), then
applies that scalar calculation to its position and velocity.
Hotseat, realtime and special Bouncer movement therefore share the
same numerical integration, while retaining their existing
dictionary/scalar state representations and collision/event
ordering. Smoke tests check multi-frame equivalence, ownership,
nested data isolation and default shell fields; live-scene tests
protect turn-step execution.
