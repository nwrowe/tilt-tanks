# Current architecture — October 30, 2026

The active Godot 4.6.3 scene is `res://scenes/Main.tscn`. It attaches
`res://scripts/core/MainGameOnlineHostWaitingFacade.gd`.

## Active inheritance: eight scripts

```text
MainGameOnlineHostWaitingFacade.gd
  -> MainGameProgressionFacade.gd
  -> MainGameSpecialWeaponsFacade.gd
  -> MainGameModeFacade.gd
  -> MainGame.gd
  -> WeaponRuntimeBridge.gd
  -> WorldRuntimeBridge.gd
  -> Main.gd (Node2D)
```

Do not add additional facade/inheritance layers. The CI depth guard enforces
**max-depth 8** against the actual scene script. The old
`ModeRuntimeBridge.gd` is retired; see
`docs/RETIRED_MODE_RUNTIME_BRIDGE.md`. Historical diagrams in earlier
documents describe previous stages, not the current runtime.

## Composed gameplay services

- Match: `MatchState`, `MatchController`,
  `MatchRuntimeSynchronizer`, and damage/weapon policies
- AI: `TurnAITurnSession`, `TurnAIVisualAimSession`,
  `TurnAIShotPlanner`, `TurnAIBallisticScorer`, `RealtimeAIMovementPlanner`,
  `RealtimeAIAimingSession`, and `RealtimeCooldownPolicy`
- Modes: `ModeControllerRegistry`, `ActiveModeState`, hotseat,
  realtime, campaign and network-mode controllers
- UI: `MainMenuView`, `MainMenuNavigationSession`,
  `MainMenuPresentation`, `CampaignMapView`, `TankGarageView`,
  `WeaponSelectMenu` and other UI builders
- World: `TerrainMath`, `TerrainManager`, `WaterManager` and
  `SnowManager`
- Effects: `EffectsManager`, `SteamPuffEffect`,
  `DestroyedTankSmokeSession` and `WindMeterPolicy`
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

1. Inheritance depth budget (eight scripts)
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

## Next architecture boundary

Extract remaining independent responsibilities from
`WeaponRuntimeBridge.gd` and its descendants before attempting to retire
that layer. Avoid replacing the old inheritance chain with a large new
monolith; the temporary compatibility methods in `WorldRuntimeBridge`
must be slimmed over subsequent iterations.
