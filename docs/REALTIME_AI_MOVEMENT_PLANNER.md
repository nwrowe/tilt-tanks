# Realtime AI movement-target planner

`RealtimeAIMovementPlanner` owns the realtime computer opponent's candidate
movement-target search. It is a scene-independent `RefCounted` with no world
state of its own. The active `ModeRuntimeBridge` compatibility hook delegates
to it, while `WorldRuntimeBridge` retains scheduling, visual aiming and motion.

The planner takes the existing game RNG, world width, both tank positions,
ground-height callback and the existing turn AI shot-search callback.
It preserves the exact five candidate offsets, probability gate,
safe-distance and edge exclusions, penalty, tie behavior and random draws.
Importantly, every candidate's expensive shot search is still performed in the
same order; no new caching or altered trajectories are introduced.

Standalone smoke tests verify candidate selection, the no-move branch,
blocked movement and seeded random stream reproducibility. Live-scene
integration compares the composed helper to the runtime method with identical
RNG seeds, including the next random value, and verifies no tank position
changes during planning.

The active inheritance budget stays **9** scripts. This extraction is a step
toward retiring `ModeRuntimeBridge`, not a layer removal itself. Every merge
still requires strict Godot 4.6.3 import, smoke tests, active game tests,
realtime/camera tests, online contracts and the real two-peer ENet test.
