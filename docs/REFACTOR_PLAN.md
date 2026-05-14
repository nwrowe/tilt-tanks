# Tilt Tanks Refactor Plan

## Current Situation

The prototype currently works, but much of the behavior is stacked through a long inheritance chain:

```text
Main.gd -> MainStable... -> MainWithMenus... -> MainHybridModes1 -> ... -> MainHybridModes19
```

That was useful for fast experimentation, but it is not a good long-term architecture.

## Stable Backup

The current working refactor state has been frozen as:

```text
backup/working-mode-facade-2026-05-13
```

Use this branch as the rollback point if a later cleanup step breaks gameplay.

## New Direction

The intended clean active entry point is:

```text
scripts/core/MainGame.gd
```

During the mode split, the scene may temporarily point at:

```text
scripts/modes/MainGameModes.gd
```

That file is a temporary mode facade used to test Hotseat and Realtime Single Player extraction before those overrides are folded back into `MainGame.gd`.

Future changes should be added by extracting systems into modules rather than creating more `MainHybridModesXX.gd` files.

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
    WaterManager.gd
    SnowManager.gd

  weapons/
    WeaponCatalog.gd
    WeaponManager.gd
    ProjectileManager.gd

  effects/
    ExplosionEffect.gd
    SmokeEffect.gd
    RecoilEffect.gd

  ui/
    UIManager.gd
    MainMenu.gd
    PauseMenu.gd
    WeaponSelectMenu.gd
    MobileControls.gd

  legacy/
    MainHybridModesXX.gd files, eventually archived here or deleted
```

## Migration Order

1. Route `Main.tscn` through `scripts/core/MainGame.gd`.
2. Add reusable modules for constants and data tables.
3. Move weapon data and weapon lookup into `WeaponCatalog.gd`.
4. Move projectile spawning/updating into `ProjectileManager.gd`.
5. Move terrain, water, and snow into terrain managers.
6. Move menu and mobile button handling into UI scripts.
7. Split Hotseat and Realtime Single Player into explicit mode scripts.
8. Fold temporary mode facade behavior back into `MainGame.gd` after testing.
9. Delete or archive old prototype wrapper files after parity is confirmed.

## Current Progress

Done:

```text
- Created clean core entry direction with MainGame.gd.
- Added WeaponCatalog, ProjectileFactory, and ProjectileManager.
- Added TerrainMath and WaterManager.
- Added UIManager.
- Added EffectsManager.
- Added HotseatMode and RealtimeSinglePlayerMode helpers.
- Added and tested temporary MainGameModes.gd mode facade.
- Created a stable backup branch.
```

Still pending:

```text
- Fold MainGameModes.gd overrides back into MainGame.gd.
- Move actual terrain ownership out of the legacy chain.
- Move actual menu/mobile-control construction out of the legacy chain.
- Fully separate Hotseat and Realtime Single Player runtime loops.
- Archive or delete MainHybridModesXX only after parity is confirmed.
```

## Rule Going Forward

Do not add another `MainHybridModes20.gd` unless it is an emergency rollback experiment. New work should happen in the organized modules or through `MainGame.gd` as the temporary facade.
