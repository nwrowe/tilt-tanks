# Tilt Tanks Refactor Plan

## Refactor Phase Status

The game is working and now routes active gameplay through:

```text
scenes/Main.tscn -> scripts/core/MainGameSpecialWeaponsFacade.gd
```

The numbered `MainHybridModesXX.gd` prototype wrappers have been removed from the active top-level workflow. Active behavior now runs through named bridge/facade files and organized modules under `scripts/`.

This refactor phase is complete enough for gameplay work to continue. Remaining architecture cleanup should be treated as future hardening, not a prerequisite for every new feature.

## Stable Backups

The original working pre-cleanup backup branch is:

```text
backup/working-mode-facade-2026-05-13
```

A newer backup before the weapon-runtime bridge move is:

```text
backup/pre-flatten-mainhybrid15-2026-05-15
```

The current demonstrator should also be preserved with a new tag or release branch before larger feature work resumes.

Recommended tag name:

```text
stable-demonstrator-2026-05-28
```

## Current Active Entry and Chain

The active scene script is:

```text
scripts/core/MainGameSpecialWeaponsFacade.gd
```

Current stable active inheritance chain:

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

Current stable lower boundary:

```text
MainWithMenus.gd -> MainStableTweaks.gd
```

Earlier attempts to bulk-flatten `MainWithMenus.gd` into the mode bridge, and later `MainStableTweaks.gd` into `MainWithMenus.gd`, caused active-chain parse failures and were backed out. Do not retry those boundaries as a bulk move; split them into smaller, separately tested helper extraction steps.

## Rules Going Forward

```text
- Do not create additional MainHybridModesXX.gd wrappers.
- Treat MainGameSpecialWeaponsFacade.gd as the active gameplay facade.
- Do not add broad new feature logic to the frozen legacy chain.
- Put new gameplay glue in the active facade only when it must coordinate multiple systems.
- Put extracted logic in scripts/core, scripts/terrain, scripts/weapons, scripts/levels, scripts/modes, scripts/ui, scripts/effects, or scripts/network.
- Prefer small commits and gameplay testing after each inheritance-boundary change.
- Do not flatten MainWithMenus/MainStableTweaks in one pass.
```

## Current Structure

```text
scripts/
  core/
    MainGameSpecialWeaponsFacade.gd
    MainGameLevelFacade.gd
    MainGameModeFacade.gd
    MainGameDefinitionFacade.gd
    MainGameCameraHold.gd
    MainGame.gd
    MatchController.gd
    MatchState.gd
    MatchRuntimeBridge.gd

  modes/
    ModeController.gd
    HotseatModeController.gd
    RealtimeSinglePlayerModeController.gd
    RealtimeAIController.gd
    ActiveModeState.gd
    ModeControllerRegistry.gd
    CampaignModeController.gd
    NetworkMultiplayerModeController.gd
    RealtimeAIAimingBridge.gd
    WorldRuntimeBridge.gd
    ModeRuntimeBridge.gd

  levels/
    LevelDefinition.gd
    LevelRegistry.gd

  terrain/
    TerrainManager.gd
    TerrainMath.gd
    WaterManager.gd
    SnowManager.gd

  weapons/
    WeaponDefinition.gd
    WeaponRegistry.gd
    WeaponLoadout.gd
    WeaponCatalog.gd
    ProjectileFactory.gd
    ProjectileManager.gd
    WeaponRuntimeBridge.gd
    WeaponDefinitionRuntimeBridge.gd
    WeaponSplitRuntimeBridge.gd

  effects/
    EffectsManager.gd

  ui/
    UIManager.gd
    PauseMenu.gd
    WeaponSelectMenu.gd
    MobileControls.gd
    EndPopup.gd

  network/
    NetworkCommand.gd
    CommandBuffer.gd
```

## Completed Work

```text
- Created clean core entry direction with named facades.
- Verified Main.tscn points to res://scripts/core/MainGameSpecialWeaponsFacade.gd.
- Added CURRENT_ARCHITECTURE.md to describe the current stable demonstrator structure.
- Added ACTIVE_FACADE.md to document the active facade boundary and frozen legacy-chain rules.
- Added STABLE_BASELINE.md to mark the stable demonstrator checkpoint.
- Added LEGACY_CHAIN.md to document the frozen legacy chain, where new work goes, and how to remove the chain later.
- Added WeaponCatalog, WeaponDefinition, WeaponRegistry, WeaponLoadout, ProjectileFactory, and ProjectileManager.
- Added TerrainMath, TerrainManager, WaterManager, and SnowManager.
- Added UIManager, MobileControls, WeaponSelectMenu, PauseMenu, and EndPopup helpers.
- Added EffectsManager.
- Added mode controllers and passive network/campaign seams.
- Added level definitions and level registry.
- Added special weapon behavior through the active special-weapons facade.
```
