# Tilt Tanks

Tilt Tanks is a Godot 4 mobile-first artillery/tank game demonstrator inspired by classic 2D tank games.

This repo currently represents a stable, mostly-working demonstrator baseline. It is a good point to preserve before adding larger gameplay, multiplayer, campaign, or monetization features.

## Stable demonstrator baseline

Baseline status: **stable demonstrator / feature-freeze checkpoint**

The current build supports:

- Local hotseat/pass-and-play tank combat
- Realtime single-player mode against AI
- Mobile tilt aiming with desktop keyboard fallback
- Charge-and-release firing flow
- Terrain generation and crater deformation
- Water and snow terrain behavior
- Weapon selection and data-driven weapon definitions
- Standard, heavy, cluster, laser, tactical nuke, bouncer, ground bomb, and machine gun style weapon behavior
- Camera follow/hold polish for explosions and special weapon events
- Basic menu, pause, end popup, and mobile overlay UI

The active runtime entry point is:

```text
scenes/Main.tscn -> scripts/core/MainGameSpecialWeaponsFacade.gd
```

That facade intentionally sits on top of the current compatibility/refactor chain. See [`docs/STABLE_BASELINE.md`](docs/STABLE_BASELINE.md), [`docs/CURRENT_ARCHITECTURE.md`](docs/CURRENT_ARCHITECTURE.md), and [`docs/ACTIVE_FACADE.md`](docs/ACTIVE_FACADE.md) before making large changes.

## Current development rule

Before adding new features, keep the current demonstrator behavior stable:

1. Do not add another `MainHybridModesXX.gd` wrapper.
2. Do not add new features to the frozen legacy chain.
3. Prefer new feature work in organized modules under `scripts/core`, `scripts/modes`, `scripts/weapons`, `scripts/terrain`, `scripts/ui`, or `scripts/effects`.
4. Use the active facade chain only for compatibility glue, feature integration, or small behavior overrides that still need direct runtime access.
5. Test hotseat, realtime single-player, terrain deformation, special weapons, camera behavior, menus, and Android export after any substantial change.

## Controls

Desktop testing:

- Up/Down arrows: adjust cannon angle
- Fire button or mapped key flow: charge/release a shot, depending on mode
- Menu buttons: select mode, level, weapon, pause, reset, or quit

Phone testing:

- Tilt phone forward/back: adjust cannon angle
- On-screen controls: move/fire/menu interactions
- Fire button: charge/release or fire depending on active mode/weapon

The desktop editor generally returns zero sensor values, so use the keyboard fallback there.

## Godot setup

Open this folder in Godot 4.x. The main scene is:

```text
scenes/Main.tscn
```

The project is configured for a mobile-friendly compatibility renderer and enables accelerometer, gravity, and gyroscope sensor support.

## Pressing cleanup before new features

The biggest cleanup risk is architectural, not gameplay-breaking: the project still has a transitional facade/compatibility stack. That stack is documented and acceptable for the current stable demonstrator, but it should not grow further.

Recommended order:

1. Preserve this baseline with a tag or release branch.
2. Add small features only through the organized modules/facades described in the docs.
3. Save full legacy-chain removal for a dedicated hardening pass, not mixed with gameplay feature work.

## Future feature candidates

Possible next steps after the baseline is preserved:

- Same-Wi-Fi multiplayer using Godot ENet
- Phone-heading calibration so players can roughly point toward each other
- More levels and campaign structure
- Additional weapons and balance tuning
- Sound, haptics, and juice/polish pass
- Android release packaging cleanup
