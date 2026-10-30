# Client interpolation extraction

`OnlineDuelInterpolation` is a small `RefCounted` component that now owns:

- whether the guest has received its first authoritative state;
- the authoritative per-tank positions used for client smoothing;
- the authoritative projectile target and prior projectile-active marker; and
- the existing linear interpolation operations and reset behavior.

The top-level `MainGameOnlineHostWaitingFacade.gd` still receives RPC updates
and performs effect/camera/UI handling, but delegates interpolation to this
composed object. The smoothing constants, packet schema, and host authority
have not changed.

Regression coverage includes deterministic unit checks for tank/projectile
smoothing, two real peers exchanging snapshots, and guest-side verification
that authoritative interpolation targets become populated.

This is an incremental extraction, not a completed removal of the online
facade. The long inheritance chain remains in use until all its behavior is
re-homed and regression-tested.
