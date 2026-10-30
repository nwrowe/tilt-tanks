# Retired MainStableTweaks inheritance layer

The active gameplay scene no longer inherits `MainStableTweaks.gd`.
`MainWithMenus.gd` inherits directly from `Main.gd`, reducing the
active chain **11 → 10 scripts**.

The former 319-line tweaks layer contained many overrides that have
already been superseded without `super` calls by later controllers.
Those are **removed, not copied**: terrain generation/crater deformation
are provided by the existing `TerrainManager` in `MainGame.gd`,
movement is supplied by `WorldRuntimeBridge`, projectile stepping by
the game runtime and reset by `ModeRuntimeBridge`.

The still-active base callbacks (`_ready`, `_process`, and `_draw`)
are folded into the existing `MainWithMenus` overrides at the exact
points where they formerly called `super`, preserving menu and gameplay
state gating. Only needed compatibility methods remain for engine input,
camera focus, power mapping, firing, saved charge, and UI labels.

The old mountain backdrop drawing is delegated to the independent
`LegacyBackdropRenderer`, with a deterministic polygon generator
that can be tested without rendering. Aiming/movement calculations
already use `LegacyInputMotionPolicy`; power conversion uses
`PowerControlPolicy`.

The retirement therefore does **not** transfer all of the obsolete
layer's 319 lines into the menus runtime or create a replacement
inheritance facade. There are still transitional scene callbacks in
`MainWithMenus`; those can be moved to more specialized UI and input
collaborators once covered by further live tests.

The CI inheritance limit is lowered to **10**. Verification includes
the existing strict Godot boot/gameplay/protocol/realtime suites, a
two-process ENet duel, backdrop geometry tests, and live UI/slider and
terrain initialization assertions.
