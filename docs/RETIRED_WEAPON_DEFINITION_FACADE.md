# Second inheritance-layer retirement — weapon definition facade

The active 18-script inheritance chain included
`MainGameDefinitionFacade.gd`. Most of its overrides duplicated the
definition-based methods in the deeper `WeaponDefinitionRuntimeBridge.gd`.

`MainGameModeFacade.gd` now extends `MainGameCameraHold.gd` directly, and
the redundant definition facade was deleted. **Active depth is now 17.**

## Preserved responsibilities

- `PlayerWeaponSelection.gd`, an independent `RefCounted` component,
  stores per-player selected weapons and resets them on a new match.
- The mode facade retains the existing per-player UI/menu and
  save/load hooks, now forwarding saved preferences to the component.
- Weapon damage, radius and projectile scale overrides remain in the mode
  facade, because the intervening `MainGame.gd` still contains older hardcoded
  definitions that would otherwise win method resolution.
- Cluster split handling retains definition-driven child creation and the
  special camera focus previously set by the deleted facade.

The class does not move game-state variables or RPC signatures. It removes
one inheritance link and the redundant weapon-definition overrides, while
maintaining compatibility for existing gameplay methods.

## Regression coverage

The live Godot scene tests hotseat weapon choices over multiple turns,
cluster spawning and camera focus, plus metadata-based damage values.
Additional unit assertions cover per-player selection persistence and reset.
Two-process ENet tests remain mandatory for all changes to the active game.
