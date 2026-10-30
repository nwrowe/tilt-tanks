# Third retired inheritance layer — explosion camera hold

`MainGameCameraHold.gd` was a 94-line gameplay compatibility facade.
Its six overrides and the 0.5-second global hold constant now reside in
`MainGameModeFacade.gd`, which inherits directly from `MainGame.gd`.
The obsolete camera-hold file has been removed.

**Active script inheritance depth: 17 → 16.**

Unlike the earlier networking changes, this migration deliberately preserves
the camera methods verbatim, including calls to `super`, to avoid changing
behavior while relocating responsibilities. The existing realtime special
weapons layer still invokes the same inherited camera methods.

The camera behavior itself will be moved into a composed policy/controller
in a subsequent refactor. Removing a compatibility layer is not equivalent
to finishing the entire architecture migration.

CI now verifies a real Quick Game session, AI aiming initialization, projectile
launch, owner-aware human-vs-AI explosion focus, 0.5-second global hold clamp,
reset, regular weapon/hotseat gameplay, and two-process ENet multiplayer.
