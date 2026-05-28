# Current Architecture

This document captures the current stable demonstrator architecture for Tilt Tanks.

## Active scene and script

The project config points Godot at:

```text
res://scenes/Main.tscn
```

The active scene attaches:

```text
res://scripts/core/MainGameSpecialWeaponsFacade.gd
```

Current runtime entry:

```text
project.godot
 -> scenes/Main.tscn
 -> scripts/core/MainGameSpecialWeaponsFacade.gd
```

## Active facade chain

```text
MainGameSpecialWeaponsFacade.gd
 -> MainGameLevelFacade.gd
 -> MainGameModeFacade.gd
 -> MainGameDefinitionFacade.gd
 -> MainGameCameraHold.gd
 -> MainGame.gd
 -> MatchRuntimeBridge.gd
 -> WeaponSplitRuntimeBridge.gd
 -> WeaponDefinitionRuntimeBridge.gd
 -> WeaponRuntimeBridge.gd
 -> RealtimeAIAimingBridge.gd
 -> WorldRuntimeBridge.gd
 -> ModeRuntimeBridge.gd
 -> MainWithMenus.gd
 -> MainStableTweaks.gd
 -> MainStablePowerPercent.gd
 -> Main.gd
```

This inheritance chain is transitional but stable for the current demonstrator. The goal is not to keep adding facade layers. The goal is to use the existing seams for feature work while preserving the working gameplay baseline.

## Development rule

New gameplay work should not create new prototype wrapper files.

Do not create:

```text
MainHybridModes20.gd
MainHybridModes21.gd
...
```

Also avoid creating another top-level facade unless there is a clear, temporary compatibility reason. Prefer the organized modules below.

## Active facade responsibilities

`MainGameSpecialWeaponsFacade.gd` is the current top gameplay facade. It owns special weapon behavior and camera/turn glue that still needs direct runtime access.

It should remain relatively thin. Large logic blocks should be extracted into managers/helpers, and new feature work should start from the narrowest existing seam.

## Terrain stack

Terrain-related logic is split across:

```text
scripts/terrain/TerrainMath.gd
scripts/terrain/TerrainManager.gd
scripts/terrain/WaterManager.gd
scripts/terrain/SnowManager.gd
```

Responsibilities:

- `TerrainMath.gd`: ground lookup, slope, floor, deepest-index helpers
- `TerrainManager.gd`: terrain generation, flattening, crater deformation, terrain render geometry
- `WaterManager.gd`: pond generation, pond lookup, reflow, draw geometry, tank floating, water slowdown
- `SnowManager.gd`: snow detection, snow slope behavior, snow cap geometry

The active game still owns terrain/water/snow state for now, but most calculations are helper-routed.

## Weapon and projectile stack

Weapon and projectile logic is routed through:

```text
scripts/weapons/WeaponDefinition.gd
scripts/weapons/WeaponRegistry.gd
scripts/weapons/WeaponLoadout.gd
scripts/weapons/WeaponCatalog.gd
scripts/weapons/ProjectileFactory.gd
scripts/weapons/ProjectileManager.gd
```

Responsibilities:

- `WeaponDefinition.gd`: data model for weapon stats and behavior flags
- `WeaponRegistry.gd`: canonical weapon IDs and default definitions
- `WeaponLoadout.gd`: active loadout and default weapon selection
- `WeaponCatalog.gd`: compatibility lookup values for older paths
- `ProjectileFactory.gd`: projectile dictionary creation, especially cluster children
- `ProjectileManager.gd`: projectile stepping, hit/out-of-world helpers, shell ownership checks

Add weapon data first. Add special behavior code only when the weapon cannot be represented through definitions and existing projectile helpers.

## Mode stack

Mode decisions are routed through:

```text
scripts/modes/ModeController.gd
scripts/modes/HotseatModeController.gd
scripts/modes/RealtimeSinglePlayerModeController.gd
scripts/modes/RealtimeAIController.gd
scripts/modes/ActiveModeState.gd
scripts/modes/ModeControllerRegistry.gd
scripts/modes/CampaignModeController.gd
scripts/modes/NetworkMultiplayerModeController.gd
```

Responsibilities:

- hotseat active checks and charge/release policy
- realtime single-player fire and charge/release policy
- realtime AI aim/cooldown policy
- active mode naming/state
- placeholder seams for campaign and network multiplayer

Full mode-loop ownership is still a future hardening target.

## Level stack

Level/world data is routed through:

```text
scripts/levels/LevelDefinition.gd
scripts/levels/LevelRegistry.gd
scripts/core/MainGameLevelFacade.gd
```

Responsibilities:

- level IDs and definitions
- world width ranges
- terrain height ranges
- tank start height ranges
- wind limits
- pond chance
- snow line
- optional weapon loadout restrictions

Level selection UI and campaign progression are still future work.

## Network readiness

Network/replay readiness is represented by:

```text
scripts/network/NetworkCommand.gd
scripts/network/CommandBuffer.gd
```

These are passive command objects/buffers. They are not an active multiplayer implementation yet.

## UI stack

UI construction is routed through:

```text
scripts/ui/MobileControls.gd
scripts/ui/WeaponSelectMenu.gd
scripts/ui/PauseMenu.gd
scripts/ui/EndPopup.gd
scripts/ui/UIManager.gd
```

These helpers construct and style controls. The active facade still owns callbacks and gameplay side effects.

## Effects stack

Effect helper logic is routed through:

```text
scripts/effects/EffectsManager.gd
```

It handles reusable effect math and puff updates. The active game still owns when effects are spawned and drawn.

## Frozen legacy chain

The old prototype inheritance chain remains in the repo as frozen compatibility scaffolding.

See:

```text
docs/LEGACY_CHAIN.md
```

Do not modify the legacy chain for normal gameplay work. Do not add a new wrapper layer.

## Future hardening pass

The next architecture step, when ready, is to eliminate the legacy inheritance chain entirely:

1. Create a backup branch.
2. Inventory remaining inherited state and methods required by the active facade chain.
3. Move required state into `scripts/core` or dedicated controllers/managers.
4. Reduce the active facade chain, ideally toward a direct `Node2D` runtime root.
5. Test hotseat, realtime, terrain, water, snow, UI, weapons, effects, and Android export.
6. Archive or delete legacy scripts only after parity is confirmed.

Until then, this refactor phase is complete and gameplay work can continue through the new structure.
