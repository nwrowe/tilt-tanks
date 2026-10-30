# Host synchronization coordinator

The new `OnlineDuelHostCoordinator` component owns update cadence and delayed
turn-advance fallback timers. It has no dependency on Godot nodes, UI, ENet
peers or RPC methods.

The runtime retains responsibility for deciding whether the host is connected,
whether projectiles/weapon effects are active, and for actually advancing a
turn or sending a snapshot. The component answers when a sync is due and
whether the fallback timer has elapsed while the game is safe to advance.

The interval values (active 33 ms, idle 100 ms), 1.25-second fallback
delay, and explosion/projectile guards are unchanged. An explicit
`force_next_sync` replaces direct mutation of an inherited timer.

A single `can_advance` decision is now shared by the delayed fallback path
and the normal pending turn-advance path, reducing the chance they diverge.

Network contracts cover cadence, fallback delay, owner-switch cancellation,
single firing, and blocking game-over/projectiles/explosions. CI also starts
two real Godot instances and tests a live host/guest duel.
