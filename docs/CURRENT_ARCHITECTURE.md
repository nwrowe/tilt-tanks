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
