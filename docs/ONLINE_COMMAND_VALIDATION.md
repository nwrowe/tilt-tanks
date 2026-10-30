# Online host command validation

Godot's active game node retains its existing RPC annotations and performs
actual state changes, but now delegates command authorization and fire input
normalization to `OnlineDuelCommandValidator`.

The pure validator enforces:
- a nonzero, recognized connected guest peer;
- the expected guest player's turn;
- the Start Turn gate for start commands;
- no active shot, overlay or terminal state for fire commands;
- numeric and finite angle and power values within gameplay limits; and
- a weapon selected from the current allowed loadout.

The validated fire data is applied only after all checks succeed. Malformed
angle/power input is rejected rather than converting text or infinity into
unexpected state. Existing legitimate input is clamped to the same bounds
as before; unavailable weapons still fall back to the loadout default.

No RPC method has moved (Godot uses matching node paths/signatures to resolve
RPC calls), and the current ENet host/guest scenario remains unchanged.

Validation tests are in `tests/network_contracts.gd`. CI also starts two
real Godot processes to validate connection, state sync and firing.
