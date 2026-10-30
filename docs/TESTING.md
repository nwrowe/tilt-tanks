# Headless gameplay integration tests

Tests run under Godot **4.6.3** in GitHub Actions for pull requests and pushes
to `main`. The first CI workflow and pure-data tests live in `tests/smoke.gd`;
these new checks exercise the actual active scene.

Locally, with Godot in your PATH:

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/runtime_integration.gd
godot --headless --path . --script res://tests/network_contracts.gd
godot --headless --path . --quit-after 3
```

## What these tests actually cover

- `runtime_integration.gd`: loads and enters the real 19-layer game scene,
  navigates single player > campaign > garage > campaign, checks level nodes,
  sends a screen-drag event to the campaign map, launches Level 1, then enters
  hotseat, alternates turns, verifies each player's selected weapon, passes the
  Start Turn gate, fires a Heavy projectile and steps live projectile physics.
- `network_contracts.gd`: checks pack/unpack of vectors, snapshot field
  contracts and monotonic snapshot/fire-event ordering with the active online
  facade methods, without opening sockets.
- `smoke.gd`: class/registry/controller contracts independent of the active
  scene.

These tests use live scene construction and real methods, but disable automatic
per-frame processing after scene initialization to avoid nondeterministic timers
and input during assertions.

## Explicit gaps

- Full projectile impact/crater/end-of-match flow, advanced special weapons,
  realtime AI, actual touchscreen hardware, and visual appearance are **not**
  verified by the suite yet.
- Snapshot contract tests are not two-peer multiplayer tests; add separate
  localhost ENet and rendered screenshot tests as the next test layers.
- Android sensor and packaging checks still need emulator/device coverage.
- Test failures should block a refactor PR until fixed; avoid weakening an
  assertion merely to obtain a green build.
