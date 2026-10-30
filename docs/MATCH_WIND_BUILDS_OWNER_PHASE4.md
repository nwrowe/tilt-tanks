# MatchState write ownership — level wind and tank builds

Following the player, health/winner and projectile synchronization changes,
two remaining direct gameplay writes to MatchState were found:

- The level facade wrote wind immediately after reset.
- Progression setup copied each player tank build directly into MatchState.

Both now use MatchController methods:
set_wind and sync_tank_builds. These preserve the existing values and
ordering of initialization without changing gameplay or build persistence.

This closes the known direct MatchState writes in active gameplay facades
outside MatchController. MatchState itself is still a passive data container
with mutating methods, and older gameplay values continue to be produced in
the active runtime. The next substantive architectural phase is migrating
actual turn/damage/projectile behavior rather than only its state mirror.

The Godot suites cover default and snowy level reset wind, player build
synchronization and reset, gameplay, realtime AI, and real ENet peers.
