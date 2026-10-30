# Controller-owned radial damage

Radial blast damage now directly updates MatchController/MatchState instead of
subtracting tank health in the inherited weapon and base-game scripts and
mirroring the resulting array.

MatchDamagePolicy implements the original 1.35-power falloff. The two legacy
profiles are explicitly preserved: ordinary explosions have minimum splash
damage of six, while weapon-definition explosions have minimum splash damage
of four. Direct-hit and splash damage use the selected weapon's existing
registry values.

MatchRuntimeBridge remains the adapter for the legacy game:
- adopt the runtime health values before a blast, in case other systems
  modified them since the last state sync;
- ask MatchController to apply all tank damage and evaluate the winner once;
- copy the resulting health array back into the legacy UI/runtime field.

The damage math and resulting state transition are now controller-owned.
The UI, terrain deformation, effects and active projectile simulation remain
where they are. Multiplayer RPCs and wire data were not changed.

Regression tests verify the damage falloff, boundaries, direct hits, splash
minimums, simultaneous destruction, reset and actual weapon-specific damage
through the live game scene, alongside headless realtime and real ENet peers.
