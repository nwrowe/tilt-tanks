# Frozen Legacy Chain

Tilt Tanks still contains the original prototype inheritance chain:

```text
scripts/Main.gd
scripts/MainStable.gd and related prototype files
scripts/MainHybridModes1.gd
...
scripts/MainHybridModes19.gd
```

This chain is kept for compatibility while the active game behavior is routed through:

```text
scenes/Main.tscn -> scripts/core/MainGame.gd
```

## Status

The legacy chain is frozen compatibility scaffolding.

That means:

- Do not create `MainHybridModes20.gd`.
- Do not add new features to `MainHybridModesXX.gd` files.
- Do not refactor by adding another wrapper layer.
- Do not move or delete these files until `MainGame.gd` no longer extends them and gameplay parity has been tested.

## Where new work goes

Use these locations instead:

```text
scripts/core/MainGame.gd              active gameplay facade/glue
scripts/terrain/*.gd                  terrain, water, snow logic
scripts/weapons/*.gd                  weapon and projectile logic
scripts/modes/*.gd                    hotseat/realtime mode decisions
scripts/ui/*.gd                       menu, mobile, overlay UI construction
scripts/effects/*.gd                  smoke/recoil/effect helpers
```

## Why the chain still exists

`MainGame.gd` currently extends:

```gdscript
extends "res://scripts/MainHybridModes19.gd"
```

This preserves behavior while the project transitions from prototype inheritance to manager/helper modules. Many systems have already been extracted, but some state ownership and lifecycle behavior still comes from the legacy chain.

## Future hardening pass

The next major architecture task, after gameplay work can resume, is to remove the legacy inheritance dependency entirely.

That future pass should:

1. Create a backup branch.
2. Inventory all inherited state and lifecycle methods still used by `MainGame.gd`.
3. Move required state into `MainGame.gd` or dedicated controllers/managers.
4. Change `MainGame.gd` to extend `Node2D` directly.
5. Test hotseat, realtime, terrain, water, snow, weapons, UI, and effects.
6. Only then archive or delete the old prototype files.

Until then, these files should remain stable and untouched except for emergency compatibility fixes.