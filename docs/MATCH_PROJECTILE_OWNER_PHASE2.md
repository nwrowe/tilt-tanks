# Match projectile lifecycle consolidation — phase 2

MatchController now owns the branching decision for adopting one projectile
frame from the existing gameplay runtime. The new sync_projectile_frame
operation handles:

- Active flight: copy position and velocity, clear previous explosion state.
- Impact: clear the projectile and set the authoritative explosion position
  and remaining duration.
- Inactive and expired: clear projectile and remove expired explosion state.

MatchRuntimeBridge now forwards the five runtime values rather than
duplicating transition logic. This preserves existing projectile priority,
impact/hold timing and cleanup while establishing a single controller-owned
update path into MatchState.

The active gameplay runtime still calculates projectile physics, collision,
weapon effects and rendering. MatchState is not yet the physics source of
truth. Subsequent migration should move those responsibilities separately
with dedicated weapon, camera and network regression tests.

Tests verify the full active/impact/clear/reset lifecycle both in the
standalone controller and through the real scene. All previous gameplay,
online and realtime test suites remain mandatory.
