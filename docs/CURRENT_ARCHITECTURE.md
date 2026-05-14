# Current Architecture

This document captures the post-refactor working architecture for Tilt Tanks.

## Active scene and script

The active scene is:

```text
scenes/Main.tscn
```

It should point to:

```text
res://scripts/core/MainGame.gd
```

`MainGame.gd` is the active gameplay facade. It currently extends the frozen compatibility chain:

```gdscript
extends "res://scripts/MainHybridModes19.gd"
```

That inheritance is intentionally preserved until the later legacy-chain removal pass.

## Development rule

New gameplay work should not create new prototype wrapper files.

Do not create:

```text
MainHybridModes20.gd
MainHybridModes21.gd
...
```

New work should go into `MainGame.gd` or one of the organized helper/manager modules.

## MainGame.gd responsibilities

`MainGame.gd` is responsible for active gameplay glue that still needs direct access to game state:

- hotseat charge/release coordination
- realtime single-player charge/release coordination
- bridge methods into weapon/projectile helpers
- bridge methods into effect helpers
- active overrides that intentionally replace legacy behavior

It should remain relatively thin. Large logic blocks should be extracted into managers/helpers.

## Terrain stack

Terrain-related logic is now split across:

```text
scripts/terrain/TerrainMath.gd
scripts/terrain/TerrainManager.gd
scripts/terrain/WaterManager.gd
scripts/terrain/SnowManager.gd
```

Responsibilities:

- `TerrainMath.gd`: ground lookup, slope, floor, deepest-index helpers
- `TerrainManager.gd`: terrain generation, flattening, crater deformation, terrain render geometry
- `WaterManager.gd`: pond generation, pond lookup, reflow, draw geometry, tank floating, water slowdown
- `SnowManager.gd`: snow detection, snow slope behavior, snow cap geometry

The active game still owns terrain/water/snow state for now, but most calculations are helper-routed.

## Weapon and projectile stack

Weapon and projectile logic is routed through:

```text
scripts/weapons/WeaponCatalog.gd
scripts/weapons/ProjectileFactory.gd
scripts/weapons/ProjectileManager.gd
```

Responsibilities:

- `WeaponCatalog.gd`: weapon stats and lookup values
- `ProjectileFactory.gd`: projectile dictionary creation, especially cluster children
- `ProjectileManager.gd`: projectile stepping, hit/out-of-world helpers, shell ownership checks

`MainGame.gd` still coordinates side effects such as explosions, camera focus, turn advancement, and game-over behavior.

## Mode stack

Mode decisions are routed through:

```text
scripts/modes/HotseatMode.gd
scripts/modes/RealtimeSinglePlayerMode.gd
```

Responsibilities:

- hotseat active checks
- hotseat charge begin/release decisions
- hotseat charge percent and turn label helpers
- realtime fire availability
- realtime charge begin/release decisions
- realtime charge status label helpers

Full mode-loop ownership is still a future hardening target.

## UI stack

UI construction is routed through:

```text
scripts/ui/MobileControls.gd
scripts/ui/WeaponSelectMenu.gd
scripts/ui/PauseMenu.gd
scripts/ui/EndPopup.gd
scripts/ui/UIManager.gd
```

These helpers construct and style controls. `MainGame.gd` / the active facade still owns callbacks and gameplay side effects.

## Effects stack

Effect helper logic is routed through:

```text
scripts/effects/EffectsManager.gd
```

It handles reusable effect math and puff updates. The active game still owns when effects are spawned and drawn.

## Frozen legacy chain

The old prototype inheritance chain remains in the repo as frozen compatibility scaffolding.

See:

```text
docs/LEGACY_CHAIN.md
```

Do not modify the legacy chain for normal gameplay work. Do not add a new wrapper layer.

## Future hardening pass

The next architecture step, when ready, is to eliminate the legacy inheritance chain entirely:

1. Create a backup branch.
2. Inventory remaining inherited state and methods required by `MainGame.gd`.
3. Move required state into `MainGame.gd` or dedicated controllers/managers.
4. Change `MainGame.gd` to extend `Node2D` directly.
5. Test hotseat, realtime, terrain, water, snow, UI, weapons, and effects.
6. Archive or delete legacy scripts only after parity is confirmed.

Until then, this refactor phase is complete and gameplay work can continue in the new structure.