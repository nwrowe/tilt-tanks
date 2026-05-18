# Weapon Runtime Bridge

The active weapon runtime behavior has been moved out of the legacy `scripts/MainHybridModes15.gd` file and into:

```text
scripts/weapons/WeaponRuntimeBridge.gd
```

`MainHybridModes15.gd` is now only a compatibility alias:

```gdscript
extends "res://scripts/weapons/WeaponRuntimeBridge.gd"
```

Current active chain around weapons:

```text
scripts/core/MainGame.gd
 -> scripts/MainHybridModes15.gd          # alias only
 -> scripts/weapons/WeaponRuntimeBridge.gd
 -> scripts/MainHybridModes12.gd
```

The game has been tested successfully after this move.

Next safe cleanup, using a patch-capable edit:

```text
1. Change the first line of scripts/core/MainGame.gd from:
   extends "res://scripts/MainHybridModes15.gd"

   to:
   extends "res://scripts/weapons/WeaponRuntimeBridge.gd"

2. Test startup, weapon menu, Standard, Heavy, Cluster, hotseat firing, realtime firing, cluster camera follow, and destroyed-tank smoke.

3. Delete scripts/MainHybridModes15.gd after the direct parent change is verified.
```

Do not add new `MainHybridModesXX.gd` files. New weapon behavior should go in `scripts/weapons/`.