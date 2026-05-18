# Tilt Tanks Refactor Plan

## Refactor Phase Status

The game is working and routes active gameplay through:

```text
scenes/Main.tscn -> scripts/core/MainGame.gd
```

The numbered `MainHybridModesXX.gd` prototype wrappers have been removed from the active chain. Active behavior now runs through named bridge files in `scripts/modes/` and `scripts/weapons/`.

## Stable Backups

The original working pre-cleanup backup branch is:

```text
backup/working-mode-facade-2026-05-13
```

A newer backup before the weapon-runtime bridge move is:

```text
backup/pre-flatten-mainhybrid15-2026-05-15
```

Use these branches as rollback points if a later cleanup step breaks gameplay.

## Current Active Entry and Chain

The active scene script is:

```text
scripts/core/MainGame.gd
```

Current stable active inheritance chain:

```text
MainGame.gd
 -> scripts/weapons/WeaponRuntimeBridge.gd
 -> scripts/modes/RealtimeAIAimingBridge.gd
 -> scripts/modes/WorldRuntimeBridge.gd
 -> scripts/modes/ModeRuntimeBridge.gd
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
- Keep MainGame.gd as the active gameplay facade.
- Put new gameplay glue in MainGame.gd only when it must coordinate multiple systems.
- Put extracted logic in scripts/terrain, scripts/weapons, scripts/modes, scripts/ui, or scripts/effects.
- Prefer small commits and gameplay testing after each inheritance-boundary change.
- Do not flatten MainWithMenus/MainStableTweaks in one pass.
```

## Current Structure

```text
scripts/
  core/
    MainGame.gd

  modes/
    GameMode.gd
    HotseatMode.gd
    RealtimeSinglePlayerMode.gd
    RealtimeAIAimingBridge.gd
    WorldRuntimeBridge.gd
    ModeRuntimeBridge.gd

  terrain/
    TerrainManager.gd
    TerrainMath.gd
    WaterManager.gd
    SnowManager.gd

  weapons/
    WeaponCatalog.gd
    ProjectileFactory.gd
    ProjectileManager.gd
    WeaponRuntimeBridge.gd

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
- Moved active weapon runtime behavior into scripts/weapons/WeaponRuntimeBridge.gd.
- Added realtime AI turret smoothing in scripts/modes/RealtimeAIAimingBridge.gd.
- Moved active world/runtime behavior into scripts/modes/WorldRuntimeBridge.gd.
- Moved active mode/runtime behavior into scripts/modes/ModeRuntimeBridge.gd.
- Removed obsolete numbered MainHybridModes wrappers from the active chain.
- Preserved stable lower menu/terrain boundary after failed bulk flatten attempts.
```

## Remaining Hardening

The legacy chain is much shorter, but `MainGame.gd` still does not extend `Node2D` directly.

Remaining active legacy/base files:

```text
scripts/MainWithMenus.gd
scripts/MainStableTweaks.gd
scripts/MainStablePowerPercent.gd
scripts/Main.gd
```

Recommended next hardening pass:

```text
1. Keep the current working state as the test baseline.
2. Treat MainWithMenus.gd as the next rename/move candidate, but do not bulk-flatten it.
3. Prefer introducing a named UI/Menu bridge first, then rerouting inheritance, then moving body after testing.
4. Treat MainStableTweaks/MainStablePowerPercent/Main.gd as fragile lower base layers until behavior parity is confirmed.
5. Only after behavior parity is confirmed should MainGame.gd extend Node2D directly.
```

## Rule Going Forward

Do not add another `MainHybridModes20.gd`. New work should happen in organized modules or through `MainGame.gd` as the active facade.