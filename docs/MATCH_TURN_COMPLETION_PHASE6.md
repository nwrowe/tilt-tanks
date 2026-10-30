# Controller-owned no-shot turn completion

This phase gives MatchController one operation that saves the outgoing
player's aim/power/charge and then advances the turn and resets the timer.

The legacy MatchRuntimeBridge still invokes its save-settings hook first
so the mode facade can preserve per-player weapon selection. That hook
continues to update the outgoing runtime arrays but no longer writes
MatchState directly; MatchController performs the state save and turn
transition in complete_turn_without_shot.

Normal shot-triggered turn advance already uses MatchController.advance_turn
and is intentionally unchanged. The actual player-input UI, hotseat
handoff gate, AI turn setup and network synchronization remain in their
respective runtime layers.

Controller and live-scene tests verify two-player roundtrips, power/angle
persistence, timer reset, legacy/MatchState agreement and weapon selection.
Godot CI also exercises real gameplay and both ENet peers.

This is another incremental turn-ownership boundary, not yet removal of
MatchRuntimeBridge or the active 16-script inheritance chain.
