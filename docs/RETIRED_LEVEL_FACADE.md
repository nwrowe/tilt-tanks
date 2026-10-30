# Retired level-definition inheritance facade

The active scene's former `MainGameLevelFacade.gd` layer defined
level-selection state, environment settings, terrain/water/snow overrides
and pre/post match-reset hooks. It was removed.

`LevelSession.gd` now owns the level registry, selected ID, active
LevelDefinition, restricted loadout creation, wind/width sampling and
level-specific pond/snow settings. It has no reference to the game scene,
rendering, weapons or network RPCs.

The existing `MainGameModeFacade.gd` handles the remaining engine-facing
terrain generation and snow drawing hooks. The reset sequence is preserved:
apply the selected level's loadout before the inherited match reset, then
apply its wind and synchronize MatchController after the reset.

`MainGameSpecialWeaponsFacade.gd` now inherits directly from
`MainGameModeFacade.gd`, reducing active inheritance depth **15 → 14**.

Live-scene CI tests all four level presets, Wide Hills' world-width range,
Snowy Ridge's snow line, Water Basin's pond-chance configuration, default
weapon availability, and a synthetic restricted-level weapon loadout.
All existing gameplay, realtime AI and two-peer ENet checks remain required.

This is a genuine ownership extraction for level definitions; however,
the parent mode runtime still contains engine-facing level rendering
hooks. The next refactor should move these into specialized collaborators
rather than allowing the mode file to accumulate unrelated game logic.
