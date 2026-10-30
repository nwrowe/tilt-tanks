# Multiplayer shared snapshot decoding

`OnlineDuelSnapshotDecoder.gd` is a pure, scene-independent inverse to the
common portion of `OnlineDuelSnapshotBuilder.gd`.

It decodes the 19 scalar/typed array/Vector2 fields shared between reliable
full-state packets and lightweight motion packets. Both receive paths now use
`_online_apply_shared_snapshot_fields` as a narrow compatibility seam in the
game facade. The decoder has no RPCs, gameplay references or side effects.

**Still on the active game node:** terrain/pond updates, tank interpolation,
projectile position/velocity transitions, child projectile arrays, visuals,
UI refresh, match-state mirroring, and Godot RPC endpoints. These side effects
must remain explicit until their own migration has sufficient tests.

Full packet construction, send cadence, transport ownership and peer authority
remain unchanged. This avoids changing network packet schema or making the
game's runtime state a remotely writable dynamic object.

CI additionally checks decoder agreement between full/motion packets,
strongly-typed health and aim arrays, fallback values and an actual guest's
application of a host health update over a live ENet connection.
