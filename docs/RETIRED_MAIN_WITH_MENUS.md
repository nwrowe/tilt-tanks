# Retired MainWithMenus inheritance layer

The active game no longer inherits `MainWithMenus.gd`. The former
`ModeRuntimeBridge.gd` now extends `Main.gd` directly, lowering
active scene script inheritance **10 → 9**.

## Ownership

The independent `MainMenuView` owns the CanvasLayer, control instances,
textures, styling and menu background drawing. Pure responsive geometry
lives in `MainMenuPresentation`.

`ModeRuntimeBridge` coordinates navigation and keeps the legacy
`menu_state`, `single_player_mode`, `menu_layer`, and `menu_buttons`
compatibility fields required by campaign, garage and online duel code.
The latter two continue referencing the component's layer and control
array, so independently added campaign and online controls are cleaned
up by the same view.

The former base `_ready` setup is preserved in the mode runtime's
`_ready`. The base `_process` body is called from the existing mode
dispatcher only in ordinary gameplay; realtime and AI paths retain their
existing special-case routing. The base `_draw` callback remains
available to the world runtime's menu rendering fall-through.

The prior `super._start_game` behavior is inlined at the same point
before realtime setup. Legacy UI label refresh and camera centering
are delegated through explicit compatibility methods rather than relying
on a removed ancestor. The remaining low-level firing, power, terrain
floor and trajectory callbacks are preserved for Godot script resolution.

This retirement does move transitional engine compatibility callbacks
onto `ModeRuntimeBridge`, but it does not move UI ownership there or
introduce another inherited layer. A later refactor should split the
large ModeRuntimeBridge into input, AI and mode coordinators rather than
continually appending functionality.

## Verification

CI enforces at most 9 active inheritance scripts. The live-scene
regressions exercise main/single-player/multiplayer/options navigation
and hotseat startup, alongside gameplay, realtime camera, online
snapshot contracts, real ENet peers and strict engine-error scanning.
