# Stable Demonstrator Baseline

This document marks the current Tilt Tanks repo as a stable demonstrator checkpoint before larger feature work resumes.

## Baseline intent

The current build is not a finished game. It is a stable, mostly-working demonstrator that should be preserved before adding larger gameplay, multiplayer, campaign, release, or monetization features.

The main goal for this checkpoint is simple: keep known-good local gameplay working while future work moves through cleaner seams.

## Active runtime entry

```text
scenes/Main.tscn -> scripts/core/MainGameSpecialWeaponsFacade.gd
```

The project config also points Godot at `res://scenes/Main.tscn` as the main scene.

## Current feature baseline

The demonstrator currently includes:

- Local hotseat/pass-and-play tank combat
- Realtime single-player mode against AI
- Mobile tilt aiming with desktop keyboard fallback
- Charge-and-release firing flow
- Terrain generation and crater deformation
- Water and snow terrain behavior
- Weapon selection and data-driven weapon definitions
- Standard, Heavy, Cluster, Laser, Tactical Nuke, Bouncer, Ground Bomb, and Machine Gun style weapons
- Camera follow/hold polish for explosions and special weapon events
- Basic menu, pause, end popup, and mobile overlay UI

## What should be preserved

Before adding substantial new features, preserve this state with a Git tag or release branch.

Recommended tag name:

```text
stable-demonstrator-2026-05-28
```

Recommended release-branch name:

```text
release/stable-demonstrator
```

## Current known cleanup risk

The biggest cleanup risk is architectural growth in the active facade chain.

The current chain is acceptable for this checkpoint, but it should not grow casually. In particular:

- Do not add another numbered `MainHybridModesXX.gd` wrapper.
- Do not add new feature logic to frozen legacy layers unless there is no safe alternative.
- Do not use the active facade as a general dumping ground.
- Prefer `scripts/weapons`, `scripts/levels`, `scripts/modes`, `scripts/terrain`, `scripts/ui`, `scripts/effects`, and `scripts/network` for new work.

## Stability checklist

Run this checklist after any substantial change:

- Project opens in Godot with no parser errors
- Main menu appears
- Hotseat starts
- Realtime single-player starts
- Desktop aiming fallback works
- Mobile tilt aiming still works on device
- Standard weapon fires
- Heavy weapon fires
- Cluster weapon splits
- Laser resolves
- Tactical Nuke resolves
- Bouncer resolves
- Ground Bomb resolves
- Machine Gun burst resolves
- Terrain deformation works
- Water collision works
- Snow movement behavior works
- Camera follows/holds correctly during player-relevant explosions
- Realtime AI explosions do not steal the camera from the human player
- Pause/menu overlay works
- Rematch works
- Return to main menu works
- Android export still completes

## Next-feature rule

New features should be added through the narrowest existing seam:

```text
New weapon data       -> WeaponDefinition / WeaponRegistry
New special behavior  -> smallest dedicated behavior hook needed
New level             -> LevelDefinition / LevelRegistry
New game mode policy  -> ModeController facade
Campaign work         -> CampaignModeController + level/loadout data
Multiplayer prototype -> NetworkCommand / CommandBuffer / NetworkMultiplayerModeController
UI polish             -> scripts/ui where possible
Effects polish        -> scripts/effects where possible
```

If a feature requires changing the active facade directly, keep the change small and document why that direct runtime hook was needed.
