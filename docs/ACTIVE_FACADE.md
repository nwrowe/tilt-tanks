# Active Game Facade — November 1, 2026

`scenes/Main.tscn` attaches
`res://scripts/core/MainGameOnlineHostWaitingFacade.gd`.

The active inheritance chain is **seven scripts**:

```text
scripts/core/MainGameOnlineHostWaitingFacade.gd
 -> scripts/core/MainGameProgressionFacade.gd
 -> scripts/core/MainGameSpecialWeaponsFacade.gd
 -> scripts/core/MainGameModeFacade.gd
 -> scripts/core/MainGame.gd
 -> scripts/modes/WorldRuntimeBridge.gd
 -> scripts/Main.gd (Node2D)
```

`WeaponRuntimeBridge.gd`, the old `ModeRuntimeBridge.gd` and
`MainHybridModesXX.gd` are no longer part of the active chain.
The depth guard in CI is now **seven**. Refer to
[`CURRENT_ARCHITECTURE.md`](CURRENT_ARCHITECTURE.md) for the full
ownership map and test requirements.

## Domain boundaries: avoid a new wide architecture

The facades are scene/mode/online coordinators, not independent algorithm
classes. Do **not** add another `MainHybridModesXX` or generic
`*Bridge` ancestor, or create one-method forwarding services to make
source files look shorter.

| Domain | Existing owner(s) | Scene responsibility |
|---|---|---|
| Weapon definitions, loadout, splitting | `scripts/weapons/WeaponDefinitionSession`, `WeaponRegistry`, `WeaponSplitLogic` | expose compatibility metadata/hooks |
| Projectile motion and impact | `scripts/weapons/ProjectileManager`, `ProjectileFactory`, `TurnProjectileSession` | apply impacts, turn progression and node state |
| Turn/realtime AI | `scripts/ai/` planning and visual-aim sessions | input, camera and firing dispatch |
| Terrain and water | `scripts/terrain/` managers and policies | world state, rendering callbacks |
| Smoke and explosions | `scripts/effects/DestroyedTankSmokeSession`, `EffectsManager` | CanvasItem draw and life-cycle coordination |
| UI | `scripts/ui/` widgets and menu/presentation policies | signals, overlays and focus |
| Online multiplayer | `scripts/network/` codec, coordinator, snapshots | host/guest orchestration in the upper facade |

The former weapon bridge's legacy compatibility methods now sit with
`MainGame`'s other scene-facing callbacks. That reduces inheritance
without introducing an unrelated class collection, but `MainGame`
is still sizeable and should not absorb future algorithms. Prefer
extending a coherent **existing** domain owner when adding logic.

## Safe follow-up work

Maintain the full Godot 4.6.3 test matrix: import, static depth/duplicate
checks, smoke, active hotseat/campaign, realtime/camera, packet and
snapshot contracts, actual two-process ENet, and startup. Keep method
dispatch, random draw ordering, packet shapes and effect/camera sequencing
unchanged during architecture work. For the earlier historical baseline
see `STABLE_BASELINE.md`; older refactor documents may describe retired
ancestors and are not current dispatch references.
