# Shared online snapshot schema

`OnlineDuelSnapshotBuilder` now builds both reliable full-state packets and
lightweight motion-state packets from a common set of explicitly captured
runtime fields. The component owns wire packing, array copying and field
membership. It has no reference to the scene, multiplayer peer or RPCs.

`MainGameProgressionFacade.gd` captures common state and world-only fields
and delegates full packet construction. The active online host facade delegates
motion packet construction and keeps its existing sequence assignment and RPC
delivery logic. The 23 shared fields are consistent by construction, while the
full packet retains its world geometry/ponds and the motion packet retains the
turn-cluster camera position.

This change does not alter packet names, interpolation, host authority, turn
logic or the connection lifecycle. The goal is to centralize the contract before
extracting larger receive/apply responsibilities.

CI checks common-field equivalence and copies, the original per-mode gameplay
tests and a real two-process ENet host/guest duel.
