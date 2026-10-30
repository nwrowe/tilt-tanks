# Turn-based AI shot search extraction

`ModeRuntimeBridge.gd` previously owned the exhaustive angle, power and
movement candidate loops for the turn-based computer player. The new
`TurnAIShotPlanner` is a stateless `RefCounted` search policy.

The mode runtime still owns actual terrain height queries, ballistic scoring
and shot firing. It supplies the original `RandomNumberGenerator`, a ground
height callback, a scoring callback and its existing numeric constants.
The component preserves the candidate order, per-candidate random draw,
movement penalties, human-spacing rejection, and probability-based
stationary fallback, so gameplay RNG sequencing is unchanged.

The existing `_find_ai_plan` and `_find_ai_shot_from_position` methods
remain as short compatibility entry points. They use the common
`_turn_ai_search_config` built from the original constants. No
networking, weapon rules, projectile simulation or mode selection changed.

Tests exercise the candidate grid, exact minimum-score selection,
movement costs, spacing exclusion and no-move fallback without a scene.
Live-scene tests also check valid angle/power bounds, no premature movement,
and reproducible plans after reseeding the runtime RNG.

This is a composition extraction, not an inheritance removal. The active
chain remains 9 scripts. A subsequent step can extract ballistic shot
scoring and help shrink `ModeRuntimeBridge` further before its retirement.
