# Tilt Tanks Architecture Stabilization Plan

## Purpose

The current codebase is now much cleaner than the original prototype chain and is stable enough to play. The goal of this document is to define the remaining architecture work needed before adding large amounts of new content such as many bomb types, new level types, campaign progression, and networked multiplayer.

This is not a rewrite plan. It is a stabilization plan: preserve working behavior while converting the current named bridge layers into clearer systems.

## Current Stable State

Active scene entry:

```text
scenes/Main.tscn -> scripts/core/MainGame.gd
```

Current active inheritance chain:

```text
MainGame.gd
 -> scripts/weapons/WeaponRuntimeBridge.gd
 -> scripts/modes/RealtimeAIAimingBridge.gd
 -> scripts/modes/WorldRuntimeBridge.gd
 -> scripts/modes/ModeRuntimeBridge.gd
 -> scripts/MainWithMenus.gd
 -> scripts/MainStableTweaks.gd
 -> scripts/MainStablePowerPercent.gd
 -> scripts/Main.gd
```

Current organized folders:

```text
scripts/core/
scripts/modes/
scripts/weapons/
scripts/terrain/
scripts/ui/
scripts/effects/
```

The old numbered `MainHybridModesXX.gd`, `MainMask*.gd`, `MainMobile*.gd`, and obsolete AI/menu prototype scripts have been removed from `main`.

## Current Assessment

The current base is stable and dramatically cleaner than the prototype chain. It is suitable for small gameplay iteration and incremental refactoring.

It is not yet ideal for major expansion because several named bridge files still combine too many responsibilities:

```text
ModeRuntimeBridge.gd
  - menu mode routing
  - hotseat/single-player selection
  - AI planning
  - realtime movement/cooldowns
  - wind display helpers
  - steam effects

WorldRuntimeBridge.gd
  - terrain/water/snow constants
  - realtime fire charge state
  - in-game draw composition
  - water/snow queries
  - movement helpers

WeaponRuntimeBridge.gd
  - weapon menu state
  - active weapon selection
  - projectile runtime
  - cluster splitting
  - explosion/damage/crater application
  - destroyed tank smoke
```

These bridge files are acceptable as temporary compatibility layers, but new systems should not keep growing inside them.

## Architectural Goals

Before adding major content, the project should move toward these principles:

```text
1. MainGame.gd coordinates systems; it should not own all systems.
2. Match/session state should be explicit and reusable across modes.
3. Weapons should be data-driven and extensible.
4. Game modes should be explicit controllers, not branches inside one large script.
5. Level generation should be selectable by level definition/profile.
6. Networking should be planned around deterministic/shared match commands, not patched into local-only state.
7. Rendering helpers should be separate from simulation decisions where practical.
```

## Phase 1: Match / Session Controller

### Goal

Create a clear home for match-level state and transitions, so hotseat, single-player, campaign, and multiplayer all use the same match model.

### Proposed files

```text
scripts/core/MatchState.gd
scripts/core/MatchController.gd
```

### Responsibilities

`MatchState.gd` should hold plain state:

```text
- current player
- tank positions
- tank health
- player angles
- player powers
- wind
- active world width
- current game mode
- game over / winner state
- projectile state references or IDs
```

`MatchController.gd` should own state transitions:

```text
- start/reset match
- advance turn
- end turn without shot
- apply damage
- determine winner
- reset per-turn/per-shot state
```

### Migration strategy

```text
1. Create MatchState.gd as a lightweight RefCounted data object.
2. Create MatchController.gd with pure helper methods where possible.
3. Move reset_match setup in small sections.
4. Move _advance_turn / _end_turn_without_shot next.
5. Keep public compatibility methods in the bridge during transition.
6. Test hotseat and realtime after every step.
```

### Done when

```text
- reset_match is no longer duplicated across bridge layers.
- current_player, health, power/angle arrays, game-over status have one conceptual owner.
- new modes can request match transitions without touching terrain/weapons/UI internals.
```

## Phase 2: Data-Driven Weapons

### Goal

Make it easy to add many bomb types without adding large `if weapon == ...` blocks to runtime bridge files.

### Proposed files

```text
scripts/weapons/WeaponDefinition.gd
scripts/weapons/WeaponRegistry.gd
scripts/weapons/WeaponRuntime.gd
scripts/weapons/effects/WeaponEffect.gd       # optional later
```

### WeaponDefinition fields

Each weapon should eventually define:

```text
- id
- display name
- projectile scale
- projectile count / split behavior
- explosion radius
- direct hit radius
- direct damage
- splash damage
- crater radius
- crater depth
- fuse behavior
- visual effect id
- special behavior hook/type
```

### Migration strategy

```text
1. Keep WeaponCatalog.gd initially, but wrap entries into WeaponDefinition objects.
2. Move weapon stat access out of WeaponRuntimeBridge.gd into WeaponRegistry.
3. Move cluster split behavior into weapon definitions or a projectile behavior strategy.
4. Move damage/crater calculation into WeaponRuntime.gd.
5. Leave WeaponRuntimeBridge.gd as a thin adapter until it can be removed.
```

### Done when

```text
- Adding a normal explosive weapon requires only a WeaponDefinition entry.
- Adding a split weapon does not require editing the main bridge.
- Weapon menu options are generated from the registry instead of hardcoded buttons.
```

## Phase 3: Explicit Game Mode Controllers

### Goal

Prevent campaign, realtime, hotseat, AI, and future networked multiplayer from all living inside `ModeRuntimeBridge.gd`.

### Proposed files

```text
scripts/modes/ModeController.gd
scripts/modes/HotseatMode.gd
scripts/modes/TurnBasedAIMode.gd
scripts/modes/RealtimeSinglePlayerMode.gd
scripts/modes/CampaignMode.gd
scripts/modes/NetworkMultiplayerMode.gd
```

Some helper files already exist and should be reused where possible.

### Responsibilities per mode

Each mode controller should answer:

```text
- who controls each tank?
- when can a player move?
- when can a player fire?
- how is fire power chosen?
- how does the turn advance?
- how does camera focus behave?
- does the mode use local input, AI input, campaign scripting, or network commands?
```

### Migration strategy

```text
1. Create a base ModeController interface with methods like enter, exit, process, can_fire, on_fire_pressed.
2. Move hotseat-specific charge/release behavior first.
3. Move realtime single-player loop next.
4. Move AI planning into TurnBasedAIMode or an AI service.
5. Keep ModeRuntimeBridge.gd as a compatibility adapter until all modes are extracted.
```

### Done when

```text
- Adding CampaignMode does not require modifying realtime AI code.
- Adding NetworkMultiplayerMode does not require copying hotseat code.
- ModeRuntimeBridge.gd is either very small or deleted.
```

## Phase 4: Level Definitions and Level Generation

### Goal

Make new level types configurable rather than hardcoded into `WorldRuntimeBridge.gd` constants.

### Proposed files

```text
scripts/levels/LevelDefinition.gd
scripts/levels/LevelGenerator.gd
scripts/levels/LevelRegistry.gd
scripts/levels/biomes/GrasslandLevel.gd       # optional later
scripts/levels/biomes/SnowLevel.gd            # optional later
scripts/levels/biomes/WaterLevel.gd           # optional later
```

### LevelDefinition fields

```text
- world width range
- terrain height range
- terrain roughness
- spawn rules
- water chance/width/depth
- snow line and snow physics settings
- wind range
- background/theme id
- allowed weapons
- campaign metadata
```

### Migration strategy

```text
1. Create LevelDefinition with current default values.
2. Route terrain/water/snow constants through the active level definition.
3. Move pond generation and snow settings to WaterManager/SnowManager inputs.
4. Add named level presets only after the default level is stable.
```

### Done when

```text
- A new level type can be added by creating a LevelDefinition.
- Terrain/water/snow behavior is not controlled by scattered constants in bridge scripts.
```

## Phase 5: Networking Readiness

### Goal

Prepare for multiplayer without forcing a full networking rewrite later.

### Proposed files

```text
scripts/network/NetworkSession.gd
scripts/network/NetworkCommand.gd
scripts/network/CommandBuffer.gd
```

### Guiding rule

Network multiplayer should exchange player commands and deterministic match events, not arbitrary scene state.

### Command examples

```text
- start match
- set aim angle
- begin charge
- release fire
- move left/right
- select weapon
- apply turn result / confirmed shot
```

### Migration strategy

```text
1. Create command objects for local play first.
2. Make hotseat and realtime modes consume local commands.
3. Add network transport later.
4. Decide whether the game will be host-authoritative or deterministic lockstep before implementing online play.
```

### Done when

```text
- Local input and future network input can use the same command path.
- Multiplayer is not directly tied to keyboard/mobile input callbacks.
```

## Phase 6: UI / Menu Cleanup

### Goal

Clean up menu code without destabilizing the game.

### Current caution

A broad extraction of `MainWithMenus.gd` into a UI helper caused a regression and was rolled back. Do not repeat that extraction as a large all-at-once move.

### Proposed approach

```text
1. Keep MainWithMenus.gd stable for now.
2. Extract only one low-risk helper at a time.
3. Prefer pure helper methods with no class_name/global registration at first.
4. Test main menu, single-player menu, campaign placeholder, options, multiplayer, and quick game after every UI extraction.
```

### Future files

```text
scripts/ui/MainMenuBuilder.gd
scripts/ui/MenuAssets.gd
scripts/ui/MenuBackgroundRenderer.gd
```

### Done when

```text
- MainWithMenus.gd only owns menu state and callbacks.
- UI construction/rendering is handled by dedicated helpers.
```

## Recommended Order of Work

```text
1. Create MatchState / MatchController scaffolding.
2. Move reset/turn/win state into MatchController.
3. Create WeaponDefinition / WeaponRegistry scaffolding.
4. Convert Standard, Heavy, Cluster to definitions.
5. Create ModeController base and move hotseat mode first.
6. Move realtime single-player mode second.
7. Create LevelDefinition and route current terrain/water/snow constants through it.
8. Only then begin campaign and network planning in earnest.
```

## What Not To Do

```text
- Do not add new MainHybridModes-style wrapper files.
- Do not add more weapon special cases directly to MainGame.gd.
- Do not add campaign state into MainWithMenus.gd.
- Do not add network logic directly to mobile/keyboard input callbacks.
- Do not bulk-flatten MainWithMenus/MainStableTweaks/MainStablePowerPercent/Main.gd in one pass.
```

## Stability Checklist After Each Refactor Step

Test these after every architecture commit:

```text
- project loads with no parser errors
- main menu appears
- single-player quick game starts
- realtime AI aims and fires
- hotseat starts
- Standard weapon fires
- Heavy weapon fires
- Cluster weapon splits and camera follows correctly
- water collision works
- snow movement works
- pause/menu overlay opens and closes
- return to main menu works
- destroyed tank smoke appears
```

## Current Recommendation

The game is stable enough to continue development, but before adding lots of new content, complete at least these three stabilizing passes:

```text
1. MatchController / MatchState
2. WeaponDefinition / WeaponRegistry
3. ModeController extraction
```

After those are in place, new bombs, level types, campaign, and networked multiplayer will be much safer to add without recreating the large inherited-script problem.