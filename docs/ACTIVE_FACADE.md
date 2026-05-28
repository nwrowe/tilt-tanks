# Active Game Facade

`scenes/Main.tscn` currently points to:

```text
res://scripts/core/MainGameSpecialWeaponsFacade.gd
```

`MainGameSpecialWeaponsFacade.gd` is the current top entry point for gameplay work. It extends the stabilized facade chain:

```text
MainGameSpecialWeaponsFacade.gd
 -> MainGameLevelFacade.gd
 -> MainGameModeFacade.gd
 -> MainGameDefinitionFacade.gd
 -> MainGameCameraHold.gd
 -> MainGame.gd
```

Below that, the chain still extends the frozen compatibility/runtime bridge stack that preserves working gameplay while the remaining legacy chain is retired in a later hardening pass.

## What belongs in the active facade

Use the active facade only for glue that truly needs direct runtime access:

- special weapon behavior that cannot be represented as weapon data alone
- camera/turn coordination around special weapon events
- small compatibility overrides that preserve stable gameplay
- bridge methods that call managers/helpers

Do not add new `MainHybridModesXX.gd` files.

Do not let `MainGameSpecialWeaponsFacade.gd` become a general feature dumping ground. If a feature can live in a manager, registry, definition, controller, or UI helper, put it there first.

## Extracted systems

New logic should go into the organized modules first:

```text
scripts/terrain/TerrainManager.gd
scripts/terrain/TerrainMath.gd
scripts/terrain/WaterManager.gd
scripts/terrain/SnowManager.gd
scripts/weapons/WeaponDefinition.gd
scripts/weapons/WeaponRegistry.gd
scripts/weapons/WeaponLoadout.gd
scripts/weapons/WeaponCatalog.gd
scripts/weapons/ProjectileFactory.gd
scripts/weapons/ProjectileManager.gd
scripts/levels/LevelDefinition.gd
scripts/levels/LevelRegistry.gd
scripts/modes/ModeController.gd
scripts/modes/HotseatModeController.gd
scripts/modes/RealtimeSinglePlayerModeController.gd
scripts/modes/RealtimeAIController.gd
scripts/modes/CampaignModeController.gd
scripts/modes/NetworkMultiplayerModeController.gd
scripts/network/NetworkCommand.gd
scripts/network/CommandBuffer.gd
scripts/effects/EffectsManager.gd
scripts/ui/MobileControls.gd
scripts/ui/WeaponSelectMenu.gd
scripts/ui/PauseMenu.gd
scripts/ui/EndPopup.gd
scripts/ui/UIManager.gd
```

## Frozen compatibility layer

The old `MainHybridModesXX.gd` files are compatibility scaffolding. They should stay stable until the full legacy-chain removal pass.

Rules:

- Do not create `MainHybridModes20.gd`.
- Do not add new gameplay features to the legacy chain.
- If a behavior fix needs to override legacy behavior, prefer the active facade or an extracted manager/helper.
- Only delete or move legacy files after the active facade no longer depends on them and parity has been tested.

## Current refactor phase status

This phase is now considered complete enough for gameplay work to continue.

The separate future hardening pass is to reduce or remove the legacy/facade inheritance chain entirely, but that should happen on a dedicated branch after the stable demonstrator baseline is preserved.
