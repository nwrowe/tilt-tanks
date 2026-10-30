# MainMenuView composition

`MainMenuView` is an independent `RefCounted` that owns the menu CanvasLayer,
its active controls, texture assets, button styling and background drawing.
`MainWithMenus` continues to own navigation, game modes and engine lifecycle
callbacks but now delegates all UI construction and presentation to this view.

The existing fields `menu_layer` and `menu_buttons` remain shared
compatibility references: campaign map, garage and online duel callers still
access them through the active game root. Clearing controls mutates the same
array rather than replacing it. External controls added to that array remain
eligible for cleanup by the view.

This prepares retiring `MainWithMenus.gd` next. No gameplay inheritance
layer is removed in this PR; the active chain remains 10 scripts.
Headless live-game checks verify view ownership and home/single-player menu
navigation. Full Godot and real ENet testing remains mandatory.
