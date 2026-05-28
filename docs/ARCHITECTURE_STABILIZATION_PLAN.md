# Tilt Tanks Architecture Stabilization Plan

## Status

Architecture stabilization has reached a good checkpoint. The codebase is now stable enough to stop refactoring-first work and return to building gameplay features.

This document remains as a roadmap, but the remaining architecture work should now happen only when it directly supports a concrete feature such as a new weapon, level type, campaign level, or multiplayer prototype.

## Current Active Entry

```text
scenes/Main.tscn -> scripts/core/MainGameSpecialWeaponsFacade.gd
```

## Current Active Facade Chain

```text
MainGameSpecialWeaponsFacade.gd
 -> MainGameLevelFacade.gd
 -> MainGameModeFacade.gd
 -> MainGameDefinitionFacade.gd
 -> MainGameCameraHold.gd
 -> MainGame.gd
 -> MatchRuntimeBridge.gd
 -> WeaponSplitRuntimeBridge.gd
 -> WeaponDefinitionRuntimeBridge.gd
 -> WeaponRuntimeBridge.gd
 -> RealtimeAIAimingBridge.gd
 -> WorldRuntimeBridge.gd
 -> ModeRuntimeBridge.gd
 -> MainWithMenus.gd
 -> MainStableTweaks.gd
 -> MainStablePowerPercent.gd
 -> Main.gd
```

This is still a long inheritance chain, but it now has clear named layers instead of numbered prototype files. The next goal is not to keep splitting forever; the next goal is to use these seams to add game content safely.

`MainGameSpecialWeaponsFacade.gd` is the current top runtime facade. It contains special weapon behavior and camera/turn glue added after the data-driven weapon pass. It should not become another general dumping ground; new feature work should prefer the organized module seams below.

## Completed Stabilization Work

### Match / Session Layer

Added:

```text
scripts/core/MatchState.gd
scripts/core/MatchController.gd
scripts/core/MatchRuntimeBridge.gd
```

Current status:

```text
- Match state exists and stays synchronized.
- Turn advancement routes through MatchController.
- No-shot turn ending routes through MatchController.
- Projectile lifecycle mirrors through MatchController.
- Health and winner state mirror through MatchController.
```

Deferred:

```text
- Full reset ownership can move into MatchController later if needed.
- Full projectile simulation ownership can move later if needed.
```

### Data-Driven Weapons

Added:

```text
scripts/weapons/WeaponDefinition.gd
scripts/weapons/WeaponRegistry.gd
scripts/weapons/WeaponLoadout.gd
scripts/weapons/WeaponDefinitionRuntimeBridge.gd
scripts/weapons/WeaponSplitRuntimeBridge.gd
scripts/core/MainGameDefinitionFacade.gd
```

Current status:

```text
- Weapon stats route through WeaponDefinition / WeaponRegistry.
- Weapon menu builds from the active loadout.
- Standard, Heavy, Cluster, and Cluster Fragment are definition-backed.
- Cluster child count is definition-driven.
- Loadout restrictions are available for future levels/campaign/modes.
```

Deferred:

```text
- Add new weapons by adding definitions first.
- Only create new behavior scripts when a weapon cannot be represented by data.
```

### Mode Controllers

Added:

```text
scripts/modes/ModeController.gd
scripts/modes/HotseatModeController.gd
scripts/modes/RealtimeSinglePlayerModeController.gd
scripts/modes/RealtimeAIController.gd
scripts/modes/ActiveModeState.gd
scripts/modes/ModeControllerRegistry.gd
scripts/modes/CampaignModeController.gd
scripts/modes/NetworkMultiplayerModeController.gd
scripts/core/MainGameModeFacade.gd
```

Current status:

```text
- Hotseat policy routes through HotseatModeController.
- Realtime player fire policy routes through RealtimeSinglePlayerModeController.
- Realtime AI aim/cooldown policy routes through RealtimeAIController.
- Active mode names are tracked through ActiveModeState.
- Campaign and network controller slots exist as placeholders.
```

Deferred:

```text
- Campaign implementation.
- Network multiplayer implementation.
- Full removal of old mode helper calls from deeper bridge files.
```

### Level / World Definitions

Added:

```text
scripts/levels/LevelDefinition.gd
scripts/levels/LevelRegistry.gd
scripts/core/MainGameLevelFacade.gd
```

Current status:

```text
- Active level definition exists.
- Default level mirrors current runtime constants.
- Level definitions can control world width, terrain range, start height range, wind max, pond chance, snow line, and weapon loadout.
- Placeholder level IDs exist for wide hills, snowy ridge, and water basin.
```

Deferred:

```text
- Level selection UI.
- Campaign level progression.
- Background/theme swapping.
- Fine-grained terrain generation profiles.
```

### Network Readiness

Added:

```text
scripts/network/NetworkCommand.gd
scripts/network/CommandBuffer.gd
```

Current status:

```text
- Passive network/replay/campaign command objects exist.
- Command buffering exists.
- No active networking is implemented yet.
```

Deferred:

```text
- Host-authoritative session layer.
- Local-input-to-command routing.
- Online transport.
```

### Gameplay Polish Completed During Stabilization

Added:

```text
scripts/core/MainGameCameraHold.gd
scripts/core/MainGameSpecialWeaponsFacade.gd
```

Current status:

```text
- Camera holds briefly after player-relevant explosions.
- Realtime AI explosions do not pull the camera away from the human player.
- Special weapon behaviors are integrated above the stabilized level/mode/weapon facade chain.
```

## Recommendation Going Forward

Stop doing broad architecture work for now.

Use the new seams only when they support a concrete feature:

```text
New bomb type      -> WeaponDefinition / WeaponRegistry first.
New level type     -> LevelDefinition / LevelRegistry first.
Campaign feature   -> CampaignModeController + LevelDefinition + WeaponLoadout.
Multiplayer work   -> NetworkCommand / CommandBuffer / NetworkMultiplayerModeController.
Mode behavior      -> ModeController facade first, not MainGame.gd.
Special weapon     -> WeaponDefinition first, then the smallest behavior hook needed in the active facade or a dedicated weapon behavior helper.
```

## Short-Term Feature Roadmap

Recommended next gameplay work:

```text
1. Preserve the current baseline with a tag or release branch.
2. Add one new weapon using WeaponDefinition.
3. Add a level-select menu with the placeholder level IDs.
4. Add campaign level 1 as a simple scripted level/loadout.
5. Add more visual polish: explosion effects, tank hit feedback, UI sounds.
6. Only after local gameplay feels strong, begin network multiplayer prototype.
```

## Stability Checklist

After each feature commit, test:

```text
- project loads with no parser errors
- main menu appears
- hotseat starts
- realtime single-player starts
- Standard weapon fires
- Heavy weapon fires
- Cluster weapon splits
- Laser weapon resolves
- Tactical Nuke resolves
- Bouncer weapon resolves
- Ground Bomb resolves
- Machine Gun burst resolves
- player explosion camera hold works
- realtime AI explosions do not steal camera
- water collision works
- snow movement works
- pause/menu overlay works
- rematch works
- return to main menu works
- Android export still completes
```
