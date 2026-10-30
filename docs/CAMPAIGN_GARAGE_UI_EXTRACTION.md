# Campaign map and garage UI extraction

The game scene still uses the existing inheritance chain, but these two
presentational responsibilities no longer live inside
`MainGameProgressionFacade.gd`.

## Campaign map

`scripts/ui/CampaignMapView.gd` extends `ScrollContainer` and owns:

- the wide fallback scenery, optional texture background, route segments and nodes;
- touch/mouse drag and wheel scrolling; and
- level button construction and visual styles.

The runtime creates the view and supplies a `Callable` to start a level. The
view itself has **no** knowledge of game modes, matchmaking or state saves.
The two small forwarding methods in the facade remain for compatibility with
existing callers and test hooks; they should be removed only after downstream
code and tests are updated.

## Tank garage

`scripts/ui/TankGarageView.gd` is a stateless view builder. It receives a
`TankBuildState` and the read-only definition dictionaries, formats the
summary and creates controls, and returns those controls for normal menu
cleanup. It receives a Back callback but never mutates credits, purchases or
gameplay state.

## Guarantees and limits

- No changes to match logic, weapon behavior, progression values or multiplayer.
- All existing screen coordinates, level labels and disabled upgrade buttons are
  preserved.
- The original menu registry still manages the lifetime of displayed controls.
- The 19-layer inheritance chain is not yet shorter; this is the first
  **composition-based extraction**, not the final root architecture.
- Campaign persistence, actual level mapping and upgrade purchases remain
  unimplemented, outside the scope of this refactor.

## Verification

CI exercises campaign navigation, map swiping, level launch, garage Back and
hotseat firing. Manual phone testing is still useful for touch feel and
presentation, especially different aspect ratios.
