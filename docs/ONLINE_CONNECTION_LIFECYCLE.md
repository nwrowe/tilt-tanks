# Online Duel connection lifecycle extraction

The `OnlineDuelConnection` object now owns creation and teardown of the ENet
peer for host and guest, and connection of `MultiplayerAPI` signals to the
existing game callbacks.

## Responsibilities

**Connection component**

- Create ENet server or client, handling immediate creation errors
- Install that peer on the game node's `MultiplayerAPI`
- Close the active peer and clear its reference on disconnect
- Connect Godot peer/connection signals once (without duplicate connections)

**Game node, unchanged**

- Own RPC endpoints (Godot resolves these by node path and `@rpc`)
- Enforce host authority and player turn ownership
- Maintain gameplay state and UI/navigation transitions
- Handle peer join/leave notifications and connection status messages

The `online_peer` field on the game remains a compatibility alias to the
component-owned peer. The component is the creator/closer; the root no longer
constructs or closes ENetMultiplayerPeer directly. Removing that alias is
later work once all uses are migrated.

## Verification

CI runs two real Godot instances across localhost ENet. The test checks
creation and ownership of both peers, host waiting/guest join, authoritative
state reception, Heavy weapon fire updates, and transport cleanup on
disconnect. Engine SCRIPT ERROR messages cause CI failure.

This is transport *lifecycle* composition, not yet a full replacement of
the current online gameplay and snapshot synchronization facades.
