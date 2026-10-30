# Architecture hardening baseline — 2026-10-29

This document describes the actual scene entry point on `main` at the start of
the hardening effort, not the older entry point still mentioned in parts of the
README and original refactor notes. No architectural migration is claimed here.

## Active scene and inheritance

`project.godot` -> `scenes/Main.tscn` ->
`scripts/core/MainGameOnlineHostWaitingFacade.gd`

The scene's script extends the following files, in order:

1. `scripts/core/MainGameOnlineHostWaitingFacade.gd`
2. `scripts/core/MainGameProgressionFacade.gd`
3. `scripts/core/MainGameSpecialWeaponsFacade.gd`
4. `scripts/core/MainGameLevelFacade.gd`
5. `scripts/core/MainGameModeFacade.gd`
6. `scripts/core/MainGameDefinitionFacade.gd`
7. `scripts/core/MainGameCameraHold.gd`
8. `scripts/core/MainGame.gd`
9. `scripts/core/MatchRuntimeBridge.gd`
10. `scripts/weapons/WeaponSplitRuntimeBridge.gd`
11. `scripts/weapons/WeaponDefinitionRuntimeBridge.gd`
12. `scripts/weapons/WeaponRuntimeBridge.gd`
13. `scripts/modes/RealtimeAIAimingBridge.gd`
14. `scripts/modes/WorldRuntimeBridge.gd`
15. `scripts/modes/ModeRuntimeBridge.gd`
16. `scripts/MainWithMenus.gd`
17. `scripts/MainStableTweaks.gd`
18. `scripts/MainStablePowerPercent.gd`
19. `scripts/Main.gd` (extends `Node2D`)

The 19-file script chain contains around 7,000 lines. Behavior is often
overridden in several levels; `_process`, `reset_match`, `_on_fire_pressed`,
`_advance_turn`, and weapon/camera hooks merit special regression checks.

## Existing reusable boundaries

- `MatchState` / `MatchController`: intended owner of match transitions; the
  active runtime still mirrors several state fields.
- `WeaponRegistry`, `WeaponLoadout`, projectile helpers: reusable data
  definitions and physics helpers.
- `TerrainManager`, `WaterManager`, `SnowManager`: reusable world math.
- `LevelRegistry` / `LevelDefinition`: level/environment configuration.
- `TankBuildState` / `TankProgressionRegistry`: tank data and upgrade stats;
  purchases, persistence and combat-stat application are not complete.
- Mode controllers: useful policy seams; runtime logic is not yet migrated.
- Network code: host-authoritative online duel is implemented in the active
  inheritance chain, not as an independent online session/controller.

## Refactor sequence (small PRs)

1. **Safety net:** add a headless project import, scene smoke check, and
   dependency-free contract tests. Do not mistake them for full gameplay tests.
2. **UI seams:** move campaign map construction and garage presentation into
   independent UI scripts; retain small integration callbacks on the root.
3. **Single source of state:** migrate turns, health, projectiles and selected
   player settings from mirrored runtime fields to `MatchState` and
   `MatchController`, one behavior at a time.
4. **Networking:** extract ENet session/snapshot logic into an independent
   controller with explicit inbound commands and authoritative snapshots.
5. **Inheritance collapse:** retire one tested compatibility layer at a time
   only after the behavior it provides has a new owner.
6. **Campaign completion:** wire level IDs, unlocked progression, credits,
   upgrade purchasing, combat effects, and persistent campaign saves.

## Manual regression matrix

Run on the Godot editor and, for motion/sensors, an Android device:

- Local hotseat: handoff gate, per-player weapon/aim, charge/release and turn timer.
- Single-player realtime/quick game: AI aim, fire and cooldowns.
- Weapons: standard, heavy, cluster, laser, nuke, bouncer, ground bomb, machine gun.
- Terrain: craters, ponds, snow, tank settling and camera hold/follow.
- Campaign: horizontal drag, level launch, garage and return/back navigation.
- Online duel: host wait/cancel, guest join, start turn, projectile arc,
  explosion/crater, turn sync, disconnect and replay.
- Reset, rematch, menu navigation and Android export.

### Limits of the CI suite

The smoke checks validate project import, active scene load and a handful of
pure-data/controller contracts. They do **not** verify touch/swipe gestures,
sensor input, rendered effects, network latency, actual firing sequences or
Android export. Those need further integration tests and device passes.

## Baseline

A branch `backup/pre-architecture-hardening-2026-10-29` was created before
making refactor changes. Make each behavior change on a new branch; PRs should
describe their expected effect, manual test path and known limitations.
