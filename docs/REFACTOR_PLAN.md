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

The scene should remain pointed at `scripts/core/MainGame.gd`. Do not create additional `MainHybridModesXX.gd` wrappers for normal refactor work.

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
    TerrainMath.gd
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
    EndPopup.gd

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
- Folded MainGameModes.gd overrides back into MainGame.gd.
- Removed inactive temporary MainGameModes.gd facade.
- Removed stale MainGame.gd UI/terrain/water/snow facade overrides so the newer tested MainHybridModes19.gd helper-routed implementations are no longer shadowed.
- Added MobileControls.gd helper for behavior-identical mobile/menu button construction.
- Routed active mobile/menu button styling through MobileControls.gd.
- Routed generic active button construction through MobileControls.gd.
- Added WeaponSelectMenu.gd as a construction-only weapon selector helper.
- Routed active weapon menu construction through WeaponSelectMenu.gd.
- Added PauseMenu.gd as a construction-only pause/menu helper.
- Routed active pause menu add-on buttons through PauseMenu.gd.
- Added EndPopup.gd as a construction-only end popup helper.
- Routed active overlay UI construction through MobileControls.gd and EndPopup.gd while keeping callbacks in the active game script.
- Added TerrainManager.gd with stateless terrain helpers.
- Routed active terrain utility methods through TerrainMath.gd and TerrainManager.gd while keeping terrain state ownership in the active game script.
- Routed active terrain generation algorithm through TerrainManager.gd while keeping world assignment, ponds, line refresh, and tank settling in the active game script.
- Added TerrainManager.gd render-geometry helpers.
- Routed active terrain ground-fill and outline geometry through TerrainManager.gd while keeping actual draw calls in the active game script.
- Added WaterManager.gd reflow helper and routed active pond/water query helpers through WaterManager.gd.
- Added WaterManager.gd pond generation and draw-geometry helpers.
- Added WaterManager.gd tank-surface and water-speed helpers.
- Routed active tank floating height and water movement speed calculations through WaterManager.gd.
- Routed active pond generation and water draw geometry through WaterManager.gd while keeping actual drawing in the active game script.
- Added SnowManager.gd with stateless snow movement and segment helpers.
- Routed active snow detection, slope, movement adjustment, and snow cap geometry through SnowManager.gd while keeping drawing and tank state in the active game script.
- Restored the newer filled-face snow visuals and uphill-slow snow behavior after a regression during extraction.
- Added realtime charge input helper methods to RealtimeSinglePlayerMode.gd.
- Routed MainGame.gd realtime keyboard charge begin/release decisions through RealtimeSinglePlayerMode.gd.
- Fixed top-level crater deformation to explicitly reflow ponds after terrain changes.
- Created a stable backup branch.
```

Still pending:

```text
- Test realtime charge routing for keyboard hold/release, mobile FIRE hold/release, shell-in-flight blocking, and hotseat parity.
- Continue moving terrain/water/snow ownership out of the active legacy facade.
- Fully separate Hotseat and Realtime Single Player runtime loops.
- Archive or delete MainHybridModesXX only after parity is confirmed.
```

## Rule Going Forward

Do not add another `MainHybridModes20.gd` unless it is an emergency rollback experiment. New work should happen in the organized modules or through `MainGame.gd` as the temporary facade.
