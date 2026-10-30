# Main menu presentation extraction

The main-menu compatibility layer formerly combined menu state/navigation
with layout calculations, responsive logo sizing, and procedural fallback
background drawing.

A new `MainMenuPresentation.gd` RefCounted collaborator owns:
- viewport-relative button/label anchoring;
- landscape/portrait logo rectangle geometry;
- fallback mountain and hill polygons;
- drawing the existing fallback gradient, sun and scenery.

`MainWithMenus.gd` now delegates these responsibilities while retaining
navigation callbacks, texture loading and scene control creation. It has
no new inheritance classes, and the active depth remains **10 scripts**.

The pure layout calculations can be validated without a rendering surface.
Godot smoke tests cover both viewport orientations, logo aspect and
background geometry; the live-scene integration tests confirm that menu
controls and navigation still work after the extraction.

This prepares for a future separation of menu navigation and UI creation
from the inherited game scene. The current change is deliberately not a
full retirement of `MainWithMenus.gd` because it also owns essential
base `_ready`, `_process`, and `_draw` callbacks that would otherwise
fall through to outdated base-game behavior. Those hooks need separate
regression coverage before moving them to an orchestration component.
