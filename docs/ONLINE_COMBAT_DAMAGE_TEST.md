# Multiplayer combat regression

The two-process ENet test previously assigned a hard-coded health array
directly on the host to confirm deserialization. It now invokes the actual
weapon damage hook at the guest tank's position, using Heavy direct-hit
damage from the registry.

The test checks that:
- the host's controller and legacy gameplay health match after the hit;
- the guest receives the health change over the real ENet connection;
- the guest MatchState agrees with the authoritative snapshot result.

This exercises the new controller-owned combat execution path end to end,
not only a synthetic networked health value.

It intentionally simulates the impact location rather than waiting for
ballistic collision, because projectile flight, terrain and turn timing are
already covered by separate tests. Android network/latency behavior is not
validated by localhost ENet.
