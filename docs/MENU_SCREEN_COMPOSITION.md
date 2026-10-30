# Menu screen composition

The active menu navigation state belongs to `MainMenuNavigationSession`.
The `MainMenuView` owns the CanvasLayer, actual controls, textures and
the concrete layout for home, single-player, multiplayer and placeholder
screens. `ModeRuntimeBridge` retains the scene's navigation callbacks,
gameplay entry points and overridable UI clear/hide hooks, but delegates
screen-specific button and label creation to `MainMenuView`.

This change keeps all screen captions, viewport-relative anchors, sizes,
texture paths and pressed callbacks unchanged. The compatibility online fallback still points back to multiplayer, but
active Online Duel navigation has replaced that placeholder with real hosting
and connection controls. Options/campaign fallbacks continue to return home. The caller clears controls before repopulating
them, preserving the existing inherited clear-disconnect behavior.

Active-scene tests cover positions and callback-driven screen transitions
with the existing shared `menu_buttons` array. Complete strict Godot import,
gameplay, realtime and two-peer ENet regression checks are required.
The active inheritance budget remains **9**; the goal is to remove
rendering/layout responsibilities before retiring the mode bridge.
