# Tilt Tanks Refactor Plan

## Current Situation

The prototype currently works, but much of the behavior is stacked through a long inheritance chain:

```text
Main.gd -> MainStable... -> MainWithMenus... -> MainHybridModes1 -> ... -> MainHybridModes19
```

That was useful for fast experimentation, but it is not a good long-term architecture.

## New Direction

The active scene should now point to:

```text
scripts/core/MainGame.gd
```

For the moment, `MainGame.gd` extends the latest working prototype so the game behavior remains stable. Future changes should be added by extracting systems into modules rather than creating more `MainHybridModesXX.gd` files.

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
8. Delete or archive old prototype wrapper files after parity is confirmed.

## Rule Going Forward

Do not add another `MainHybridModes20.gd` unless it is an emergency rollback experiment. New work should happen in the organized modules or through `MainGame.gd` as the temporary facade.
