# Online Duel protocol extraction (phase 1)

## New independent components

- `OnlineDuelCodec` owns lossless vector packing/unpacking, numeric-array
  conversion and validation of requested weapons against the active loadout.
- `OnlineSnapshotSequencer` owns outgoing sequence numbers and ordering
  decisions for full snapshots, motion snapshots and fire events.

Both extend `RefCounted` and are independent of the scene and ENet. The
authoritative host and network transport still live in the two active game
facades; RPC annotations and packet fields have not changed.

The old private functions on the main facade have been replaced by direct
`OnlineDuelCodec` calls. The top-level online facade keeps tiny delegation
methods for sequence acceptance and next-sequence allocation to preserve
existing call sites. Its counters now belong to the sequencer object.

## Weapon request hardening

Previously the host accepted an arbitrary string from a guest's `weapon`
request. The host now validates the submitted ID against the current allowed
loadout, falling back to its default shell for unknown or non-selectable IDs.
This is a narrowly scoped robustness correction, not an intended balance
change. Host identity, turn checks, and projectile-blocking checks remain in
place as before.

## Follow-up work

The next network refactor should extract ENet peer creation, lifecycle and
multiplayer connection signals into a separate session object, while keeping
RPC-decorated entry points on the active game node until compatibility has
been demonstrated with two-process tests.

CI verifies the existing game, codec, guest weapon filtering and packet
ordering. Those checks are not equivalent to two-device multiplayer testing.
