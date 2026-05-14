# Tilt Tanks Refactor Plan

## Current Situation

The game is working and now routes active gameplay through:

```text
scenes/Main.tscn -> scripts/core/MainGame.gd
```

`MainGame.gd` remains the active facade while the older prototype inheritance chain is frozen as compatibility scaffolding. See:

```text
docs/ACTIVE_FACADE.md
```

The legacy chain is still present for behavior parity, but new gameplay work should happen in `MainGame.gd` or the organized helper/manager modules.

## Stable Backup

The current working refactor state has been frozen as:

```text
backup/working-mode-facade-2026-05-13
```

Use this branch as the rollback point if a later cleanup step breaks gameplay.

## Active Entry Direction

The active scene script is:

```text
scripts/core/MainGame.gd
```

Rules:

```text
- Do not create additional MainHybridModesXX.gd wrappers.
- Treat MainHybridModes1..19 as frozen compatibility scaffolding.
- Put new gameplay glue in MainGame.gd.
- Put extracted logic in scripts/terrain, scripts/weapons, scripts/modes, scripts/ui, or scripts/effects.
- Remove the legacy inheritance chain only in a later parity-tested hardening pass.
```

## Target Structure

```text
scripts/
  core/
    MainGame.gd
    GameController.gd
    CameraController.gd

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
    WeaponManager.gd
    ProjectileFactory.gd
    ProjectileManager.gd

  effects/
    EffectsManager.gd
    ExplosionEffect.gd
    SmokeEffect.gd
    RecoilEffect.gd

  ui/
    UIManager.gd
    MainMenu.gd
    PauseMenu.gd
    WeaponSelectMenu.gd
    MobileControls.gd
    EndPopup.gd

  legacy/
    MainHybridModesXX.gd files, eventually archived here or deleted
```

## Current Progress

Done:

```text
- Created clean core entry direction with MainGame.gd.
- Added ACTIVE_FACADE.md to document the active facade boundary and frozen legacy-chain rules.
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
- Created a stable backup branch.
```

Still pending for this closeout phase:

```text
- Freeze and document the legacy MainHybridModes chain as compatibility scaffolding.
- Add current architecture notes for future development.
- Close this refactor phase and list legacy-chain removal as a separate future hardening pass.
```

## Rule Going Forward

Do not add another `MainHybridModes20.gd`. New work should happen in organized modules or through `MainGame.gd` as the active facade.
