# Active Game Facade

`scenes/Main.tscn` points to:

```text
res://scripts/core/MainGame.gd
```

`MainGame.gd` is the active entry point for gameplay work. It currently extends the frozen prototype compatibility chain through:

```gdscript
extends "res://scripts/MainHybridModes19.gd"
```

That inheritance is intentional for now. It preserves working gameplay while the remaining legacy chain is retired in a later hardening pass.

## What belongs in MainGame.gd

Use `MainGame.gd` for active glue that coordinates extracted systems:

- mode-specific charge/release behavior
- safe facade methods that call managers/helpers
- projectile side effects that still need direct game state access
- active gameplay fixes that must override old prototype behavior

Do not add new `MainHybridModesXX.gd` files.

## Extracted systems

New logic should go into the organized modules first:

```text
scripts/terrain/TerrainManager.gd
scripts/terrain/TerrainMath.gd
scripts/terrain/WaterManager.gd
scripts/terrain/SnowManager.gd
scripts/weapons/WeaponCatalog.gd
scripts/weapons/ProjectileFactory.gd
scripts/weapons/ProjectileManager.gd
scripts/effects/EffectsManager.gd
scripts/modes/HotseatMode.gd
scripts/modes/RealtimeSinglePlayerMode.gd
scripts/ui/MobileControls.gd
scripts/ui/WeaponSelectMenu.gd
scripts/ui/PauseMenu.gd
scripts/ui/EndPopup.gd
```

## Frozen compatibility layer

The old `MainHybridModesXX.gd` files are compatibility scaffolding. They should stay stable until the full legacy-chain removal pass.

Rules:

- Do not create `MainHybridModes20.gd`.
- Do not add new gameplay features to the legacy chain.
- If a behavior fix needs to override legacy behavior, prefer `MainGame.gd` or an extracted manager/helper.
- Only delete or move legacy files after `MainGame.gd` no longer extends them and parity has been tested.

## Completion target for this refactor phase

This phase is considered complete when:

- `Main.tscn` uses `MainGame.gd`.
- Active behavior is routed through the extracted managers/helpers where practical.
- The legacy chain is documented and treated as frozen compatibility scaffolding.
- Further gameplay work happens in `MainGame.gd` or organized modules, not new wrappers.

The separate future hardening pass is to remove the `MainHybridModes19.gd` inheritance entirely.