# Tilt Tanks Refactor Plan

## Refactor Phase Status

This refactor phase is complete.

The game is working and routes active gameplay through:

```text
scenes/Main.tscn -> scripts/core/MainGame.gd
```

Current architecture and follow-on rules are documented in:

```text
docs/CURRENT_ARCHITECTURE.md
docs/ACTIVE_FACADE.md
docs/LEGACY_CHAIN.md
```

## Stable Backup

The working pre-closeout backup branch is:

```text
backup/working-mode-facade-2026-05-13
```

Use this branch as the rollback point if a later cleanup step breaks gameplay.

## Active Entry Direction

The active scene script is:

```text
scripts/core/MainGame.gd
```

Rules going forward:

```text
- Do not create additional MainHybridModesXX.gd wrappers.
- Treat MainHybridModes1..19 as frozen compatibility scaffolding.
- Put new gameplay glue in MainGame.gd.
- Put extracted logic in scripts/terrain, scripts/weapons, scripts/modes, scripts/ui, or scripts/effects.
- Remove the legacy inheritance chain only in a later parity-tested hardening pass.
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
- Removed stale MainGame.gd UI/terrain/water/snow facade overrides so the newer tested MainHybridModes19.gd helper-routed implementations are no longer shadowed.
- Routed active mobile/menu button construction and styling through UI helpers.
- Routed active weapon menu construction through WeaponSelectMenu.gd.
- Routed active overlay UI construction through MobileControls.gd and EndPopup.gd while keeping callbacks in the active game script.
- Routed active terrain utility methods, terrain generation, render geometry, and crater deformation through TerrainManager/TerrainMath.
- Routed active pond generation, pond reflow, water query helpers, water draw geometry, tank floating height, and water movement speed through WaterManager.gd.
- Routed active snow detection, slope, movement adjustment, and filled snow cap geometry through SnowManager.gd.
- Restored the newer filled-face snow visuals and uphill-slow snow behavior after a regression during extraction.
- Routed hotseat and realtime keyboard charge begin/release decisions through mode helpers.
- Fixed top-level crater deformation to explicitly reflow ponds after terrain changes.
- Documented the frozen legacy chain as compatibility scaffolding.
- Closed this refactor phase so normal gameplay development can resume.
```

## Deferred Future Hardening

The legacy inheritance chain still exists and `MainGame.gd` still extends:

```gdscript
extends "res://scripts/MainHybridModes19.gd"
```

That dependency is intentionally deferred. Removing it is the next hardening pass, not part of this completed refactor phase.

Future legacy-removal pass:

```text
1. Create a backup branch.
2. Inventory remaining inherited state and lifecycle methods required by MainGame.gd.
3. Move required state into MainGame.gd or dedicated controllers/managers.
4. Change MainGame.gd to extend Node2D directly.
5. Test hotseat, realtime, terrain, water, snow, UI, weapons, projectiles, and effects.
6. Only then archive or delete the old prototype files.
```

## Rule Going Forward

Do not add another `MainHybridModes20.gd`. New work should happen in organized modules or through `MainGame.gd` as the active facade.
