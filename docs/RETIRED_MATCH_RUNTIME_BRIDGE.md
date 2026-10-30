# Retired MatchRuntimeBridge

The active scene no longer extends `MatchRuntimeBridge.gd`. The previous
171-line bridge has been deleted and `MainGame.gd` now inherits directly
from `WeaponDefinitionRuntimeBridge.gd`.

## Ownership

A new independent `MatchRuntimeSynchronizer` is the adapter between typed
legacy runtime values and the existing `MatchController` / `MatchState`.
It owns complete-frame synchronization, health/winner handoff, projectile
lifecycle handoff and applying controller-owned radial damage. It has no
scene, rendering, RPC or input dependencies.

`MainGame.gd` retains narrow engine-facing callbacks for match reset,
frame process, turn advancement, no-shot completion, explosions, damage and
legacy UI/input synchronization. That keeps existing Godot dynamic dispatch
and the `super` chain stable. In particular, the game's own projectile
physics override remains untouched.

The old initialization and frame synchronization are now invoked at the same
points after `super.reset_match()` and `super._process()` respectively.
Legacy gameplay still owns concrete physics and input values, while the
controller is the state authority.

## Verification

- Existing smoke, gameplay, realtime camera and online protocol tests.
- New standalone tests for composed adapter state/turn/projectile/health/damage.
- Live-scene test checks the adapter shares the same MatchController/MatchState.
- Real two-process ENet host/guest synchronization and strict engine log checks.

**Active scene inheritance is now 13 scripts (was 14).**
The depth budget in CI is reduced to 13.

The ultimate goal is a small game root with composed collaborators.
Remaining main-game callback methods are transitional and should be migrated
without building another inheritance facade.
