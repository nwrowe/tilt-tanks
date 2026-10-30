# Turn-based AI ballistic scoring extraction

`TurnAIBallisticScorer` is a pure, scene-independent scorer that simulates
a candidate trajectory against the target and returns the minimum measured
distance. It uses the existing discrete integration order: gravity and
wind update velocity, then position advances; distance is updated before
boundary tests and terrain collision.

The mode runtime still chooses target jitter and launch power before invoking
the scorer, preserving the exact order and count of random-number draws.
It supplies the same constants, current wind/gravity, level width, floor
boundary and a terrain-height callback. No physics values or weapon
parameters have been changed.

This extraction complements the separate TurnAIShotPlanner search policy:
candidate generation and numerical trajectory scoring can now be tested
without loading the game scene, while the mode runtime coordinates
the player/AI mode and shot firing.

Standalone tests cover a known first-step hit, zero-time muzzle distance,
terrain contact and wind correction. Live-scene tests compare the
runtime wrapper to a direct scorer call using identical seeded target
jitter, and verify reproducibility.

No inheritance link is changed in this PR; the active depth remains nine.
