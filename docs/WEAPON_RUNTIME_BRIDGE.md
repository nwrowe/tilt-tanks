# Weapon Runtime Bridge

The active weapon runtime behavior now lives in:

```text
scripts/weapons/WeaponRuntimeBridge.gd
```

`MainHybridModes15.gd` has been removed from the active chain and deleted.

Current active chain around weapons:

```text
scripts/core/MainGame.gd
 -> scripts/weapons/WeaponRuntimeBridge.gd
 -> scripts/modes/RealtimeAIAimingBridge.gd
 -> scripts/MainHybridModes12.gd
```

The game has been tested successfully after this move.

Weapon runtime responsibilities currently include:

```text
- weapon state declarations
- weapon menu open/close/build hooks
- turn projectile and cluster runtime
- realtime projectile and cluster runtime
- weapon explosion/damage/crater hooks
- destroyed tank smoke hooks
```

The weapon bridge delegates data/utility work to:

```text
- scripts/weapons/WeaponCatalog.gd
- scripts/weapons/ProjectileFactory.gd
- scripts/weapons/ProjectileManager.gd
- scripts/ui/WeaponSelectMenu.gd
- scripts/effects/EffectsManager.gd
```

Realtime AI turret smoothing now lives in:

```text
scripts/modes/RealtimeAIAimingBridge.gd
```

Do not add new `MainHybridModesXX.gd` files. New weapon behavior should go in `scripts/weapons/`.