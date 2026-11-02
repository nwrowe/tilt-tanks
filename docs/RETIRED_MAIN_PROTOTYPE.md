# Retired prototype root: scripts/Main.gd

The active Main.tscn now has **six script layers**. Its previous bottom
ancestor, scripts/Main.gd, was a standalone early prototype. All of its
classic input, movement, terrain, rendering and turn implementations were
shadowed by higher layers; retaining them created a false second source of
truth for gameplay behavior.

This change **does not inline the prototype**. Only its shared scene node
bindings and state declarations were moved to WorldRuntimeBridge.gd.
The only unique actively invoked prototype helpers, _update_camera and
_world_to_screen, also live there. Two short terrain operations formerly
shadowed in MainGame, _ground_y_at_x and _settle_tanks_on_terrain, are
now centrally owned by WorldRuntimeBridge. Its other required callbacks
are declared as explicit virtual contracts without duplicating old algorithms. The original Main._advance_turn,
Main._explode, Main._show_end_popup and Main._hide_overlays bodies were
preserved at their actual dispatch callers. This keeps the super handoffs
and explosion/turn/overlay ordering intact without retaining a redundant
inheritance layer.

Keep terrain, water, weapons, effects, AI, UI and online algorithms in the
existing domain managers/sessions. Do not reintroduce a generic prototype
base class, copy old simulation paths, or widen the architecture into tiny
forwarding classes. The depth guard and live integration tests now require
six layers. Godot 4.6.3 tests remain the behavioral acceptance criterion.
