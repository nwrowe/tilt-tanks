# Tilt Tanks

A quick Godot 4 prototype inspired by classic artillery/tank games.

## Current prototype

This first version is local pass-and-play:

- Two tanks on a simple 2D field
- Turn switching
- Projectile physics
- Basic hit detection and damage
- Keyboard fallback for desktop testing
- Mobile gravity sensor support for tilt aiming

## Controls

Desktop testing:

- Up/Down arrows: adjust cannon angle
- Power slider: adjust shot power
- Fire button: fire the shell
- R or Reset button: reset match

Phone testing:

- Tilt phone forward/back: adjust cannon angle
- Power slider: adjust shot power
- Fire button: fire the shell

## Godot setup

Open this folder in Godot 4.x. The main scene is:

```text
scenes/Main.tscn
```

The desktop editor generally returns zero sensor values, so use the keyboard fallback there.

## Next steps

Planned next prototype steps:

1. Tune phone tilt mapping on real devices.
2. Add terrain deformation/craters.
3. Add same-Wi-Fi multiplayer using Godot ENet.
4. Add phone-heading calibration so players can roughly point toward each other.
