# Tilt Tanks Refactor Plan

## Refactor Phase Status

The game is working and routes active gameplay through:

```text
scenes/Main.tscn -> scripts/core/MainGame.gd
```

This pass substantially flattened the prototype inheritance chain while preserving gameplay behavior after each tested step.

## Stable Backup

The original working pre-cleanup backup branch is:

```text
backup/working-mode-facade-2026-05-13
```

Use this branch as the rollback point if a later cleanup step breaks gameplay.

## Current Active Entry and Chain

The active scene script is:

```text
scripts/core/MainGame.gd
```

Current stable active inheritance chain:

```text
MainGame.gd
 -> MainHybridModes15.gd
 -> MainHybridModes12.gd
 -> MainHybridModes4.gd
 -> MainWithMenus.gd
 -> MainStableTweaks.gd
 -> MainStablePowerPercent.gd
 -> Main.gd
```

Current stable boundary:

```text
MainWithMenus.gd -> MainStableTweaks.gd
```

Attempts to flatten `MainWithMenus.gd` into `MainHybridModes4.gd`, and later `MainStableTweaks.gd` into `MainWithMenus.gd`, caused active-chain parse failures. Those changes were backed out. Do not retry those boundaries as a bulk move; split them into smaller, separately tested helper extraction steps.

## Rules Going Forward

```text
- Do not create additional MainHybridModesXX.gd wrappers.
- Keep MainGame.gd as the active gameplay facade.
- Put new gameplay glue in MainGame.gd only when it must coordinate multiple systems.
- Put extracted logic in scripts/terrain, scripts/weapons, scripts/modes, scripts/ui, or scripts/effects.
- Prefer small commits and gameplay testing after each inheritance-boundary change.
- Do not flatten MainWithMenus/MainStableTweaks in one pass.
```

## Completed Structure

```text
scripts/
  core/
    MainGame.gd

  modes/
    GameMode.gd
    HotseatMode.gd
    RealtimeSinglePlayerMode.gd

  terrain/
    TerrainManager.gd
    TerrainMath.gd
    WaterManager.gd
    SnowManager.gd

  weapons/
    WeaponCatalog.gd
    ProjectileFactory.gd
    ProjectileManager.gd

  effects/
    EffectsManager.gd

  ui/
    UIManager.gd
    PauseMenu.gd
    WeaponSelectMenu.gd
    MobileControls.gd
    EndPopup.gd
```

## Completed Work

```text
- Created clean core entry direction with MainGame.gd.
- Verified Main.tscn points to res://scripts/core/MainGame.gd.
- Added CURRENT_ARCHITECTURE.md to describe the post-refactor structure.
- Added ACTIVE_FACADE.md to document the active facade boundary and frozen legacy-chain rules.
- Added LEGACY_CHAIN.md to document the frozen legacy chain, where new work goes, and how to remove the chain later.
- Added WeaponCatalog, ProjectileFactory, and ProjectileManager.
- Added TerrainMath, TerrainManager, WaterManager, and SnowManager.
- Added UIManager, MobileControls, WeaponSelectMenu, PauseMenu, and EndPopup helpers.
- Added EffectsManager.
- Added HotseatMode and RealtimeSinglePlayerMode helpers.
- Added and tested temporary MainGameModes.gd mode facade.
- Folded MainGameModes.gd overrides back into MainGame.gd.
- Removed inactive temporary MainGameModes.gd facade.
- Routed active mobile/menu button construction and styling through UI helpers.
- Routed active weapon menu construction through WeaponSelectMenu.gd.
- Routed active overlay UI construction through MobileControls.gd and EndPopup.gd while keeping callbacks in the active game script.
- Routed active terrain utility methods, terrain generation, render geometry, and crater deformation through TerrainManager/TerrainMath.
- Routed active pond generation, pond reflow, water query helpers, water draw geometry, tank floating height, and water movement speed through WaterManager.gd.
- Routed active snow detection, slope, movement adjustment, and filled snow cap geometry through SnowManager.gd.
- Restored the newer filled-face snow visuals and uphill-slow snow behavior after a regression during extraction.
- Routed hotseat and realtime keyboard charge begin/release decisions through mode helpers.
- Fixed top-level crater deformation to explicitly reflow ponds after terrain changes.
- Flattened/skipped many inactive prototype wrappers: MainHybridModes19, 18, 17, 16, 14, 13, 11, 10, 9, 8, 7, 6, 5, 3, 2, MainHybridModes, MainWithAI2, MainWithAI, and MainWithMenus2.
- Removed inactive parser-only wrapper aliases for MainHybridModes13, 14, 16, 17, and 18.
- Preserved stable lower menu/terrain boundary after failed bulk flatten attempts.
```

## Remaining Hardening

The legacy chain is much shorter, but `MainGame.gd` still does not extend `Node2D` directly.

Remaining active legacy files:

```text
scripts/MainHybridModes15.gd
scripts/MainHybridModes12.gd
scripts/MainHybridModes4.gd
scripts/MainWithMenus.gd
scripts/MainStableTweaks.gd
scripts/MainStablePowerPercent.gd
scripts/Main.gd
```

Recommended next hardening pass:

```text
1. Keep the current working state as the test baseline.
2. Flatten MainHybridModes15 into MainGame.gd only after inventorying weapon behavior.
3. Then flatten MainHybridModes12 into MainGame.gd or a dedicated runtime/controller layer.
4. Treat MainHybridModes4 as the consolidated bridge for mode/menu/AI behavior until the smaller layers above it are gone.
5. Do not retry MainWithMenus/MainStableTweaks flattening as a bulk move.
6. Only after behavior parity is confirmed should MainGame.gd extend Node2D directly.
```

## Rule Going Forward

Do not add another `MainHybridModes20.gd`. New work should happen in organized modules or through `MainGame.gd` as the active facade.