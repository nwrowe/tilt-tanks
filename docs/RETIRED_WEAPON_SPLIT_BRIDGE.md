# First retired inheritance layer — cluster weapon split

The active game originally inherited from 19 scripts, including a 28-line
`WeaponSplitRuntimeBridge.gd` whose only responsibilities were split-weapon
decisions and creation of cluster child projectiles.

This change removes that script from the active inheritance chain entirely.
`MatchRuntimeBridge.gd` now inherits directly from
`WeaponDefinitionRuntimeBridge.gd`. The latter keeps compatibility entry
points called by existing weapon runtime code while delegating the actual
split decisions and child construction to the new, scene-independent
`WeaponSplitLogic.gd`.

The obsolete bridge file has been deleted. This reduces the **active script
inheritance depth from 19 to 18**. The new pure logic component is not an
inheritance ancestor of the game scene.

Godot CI checks that standard shells never split, cluster shells split on
descent only once, that definition metadata produces three child shells,
and that a live descending cluster projectile is replaced with three child
projectiles. All existing tests (including a live ENet host and guest) remain
mandatory.

This is a single-layer retirement, not a bulk flattening of the chain.
Other layers should be removed one at a time after their distinct behaviors
have suitable regression coverage.
