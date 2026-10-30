# Match player frame consolidation — phase 3

All remaining player-facing fields in the active MatchRuntimeBridge now flow
through one typed MatchController.sync_runtime_player_frame call instead of
direct writes into MatchState. The controller captures:

- current player, tank positions, per-player angles/powers/percentages;
- wind, turn timer, game mode and world width.

The typed input arrays are copied on adoption to avoid aliasing mutable
gameplay data and MatchState. Weapon-specific state, projectile lifecycle,
health/winner state and campaign tank builds remain handled separately.

The legacy runtime is still the producer of player motion/input values.
The controller is now the only writer into MatchState across player-frame,
health/winner and projectile lifecycle synchronization. This is a clear
intermediate ownership boundary, not yet removal of all runtime mirrors.

Tests assert controller adoption, isolation of mutable arrays, and live scene
agreement and reset. Godot CI still covers hotseat, weapons, realtime AI,
camera and a two-process ENet host/guest duel.
