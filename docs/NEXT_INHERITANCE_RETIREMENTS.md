# Active refactoring roadmap — seven-layer baseline (November 1, 2026)

This document replaces the outdated 14-layer retirement plan. The latest
source of truth is `scenes/Main.tscn`, the actual `extends` declarations,
`docs/CURRENT_ARCHITECTURE.md`, and the Godot tests. Historical phase plans
may describe already-retired bridges and should not drive new work.

## Current scene hierarchy

```text
MainGameOnlineHostWaitingFacade.gd
  -> MainGameProgressionFacade.gd
  -> MainGameSpecialWeaponsFacade.gd
  -> MainGameModeFacade.gd
  -> MainGame.gd
  -> WorldRuntimeBridge.gd
  -> Main.gd (Node2D)
```

The CI depth budget is **7**. This is a ceiling, not a target to reach at
any cost. As of PRs #97–#98, `WorldRuntimeBridge.gd` has 1,248 lines and
`MainGame.gd` has 1,377 lines. Neither should become the dumping ground
for behavior retired from another ancestor.

## Design objectives

- Make it straightforward to add **game modes, weapons, effects, levels and
  features** without editing many inheritance layers for one feature.
- Use exactly one authoritative owner for each piece of mutable state,
  policy and numerical algorithm. Do not hide duplicate copies behind
  getter/setter aliases or facade forwards.
- Prefer extending a cohesive **existing** component over adding a tiny
  wrapper. A new class is justified when it owns a substantial, separately
  testable lifecycle or capability, not merely to reduce a line count.
- Preserve the well-organized domain folders under `scripts/`. Do not
  replace deep inheritance with dozens of broad, disconnected helpers.
- Scene scripts coordinate Godot nodes, input, drawing and effects.
  Definition/policy/session objects own their respective data and rules.

## Work plan, in priority order

### 1. WorldRuntimeBridge: remove non-world responsibilities safely

Completed: PR #97 moved FIRE charge/unavailable presentation into
`MobileControls` and reused `UIManager`; PR #98 reused
`ProjectileFactory` for prototype/turn launches and deleted the shadowed
world realtime collision fallback.

Continue by identifying other genuinely duplicated or misplaced behavior.
Keep the existing ownership boundaries:

- **AI planning and timing:** `TurnAITurnSession`,
  `TurnAIVisualAimSession`, `TurnAIShotPlanner`,
  `RealtimeAIAimingSession`, `RealtimeAIMovementPlanner`, and
  `RealtimeCooldownPolicy`. The scene still applies player movement,
  shots, timers and camera events.
- **Menu/presentation:** `MainMenuNavigationSession`, `MainMenuView`,
  `MainMenuPresentation`, `PauseMenu`, `MobileControls`, `UIManager`.
  World code should connect scene callbacks, not reimplement UI geometry.
- **World geometry:** `TerrainManager`, `TerrainMath`, `SnowManager`,
  `WaterManager`, `LegacyBackdropRenderer`; preserve terrain generation
  RNG consumption, water volume and camera-space transforms.
- **Weapons/projectiles:** `WeaponDefinitionSession`,
  `ProjectileFactory`, `ProjectileManager`, `TurnProjectileSession`.
  Prefer shared factory/policy methods over separate legacy formulas.

Do not remove `WorldRuntimeBridge` merely by pasting its ~1,250 lines into
`MainGame`. Retire the ancestor only once all behavior has a clear owner
and the live scene no longer requires its lifecycle and compile-time hooks.

### 2. MainGame: turn a large facade into a lean coordinator

Focus next on `_ready`, `reset_match`, `_process`, input/menus and
scene adapters. Distinguish scene-only hooks from state/policy currently
owned elsewhere:

- `MatchState` and `MatchController` are the canonical match authority;
  `MatchRuntimeSynchronizer` is a transitional adapter. Avoid extra
  copies of player/health/projectile state.
- `WeaponDefinitionSession` owns weapon metadata/loadouts; never
  reintroduce hard-coded weapon-selection menus.
- `TurnProjectileSession` and `DestroyedTankSmokeSession` already own
  transient state; don't recreate it in another facade.
- Render calls requiring `CanvasItem.draw_*` can remain scene-facing
  while their numerical geometry resides in the existing managers.

Move an entire coherent responsibility at a time with source-level
ownership checks plus live behavioral tests. Do not create one-method
services or merely shuffle long functions between ancestors.

### 3. Special weapon extensibility

`MainGameSpecialWeaponsFacade` currently coordinates Laser, Nuke,
Bouncer, Ground Bomb and Machine Gun behavior. Make new weapon additions
primarily data-driven through `WeaponDefinition` / `WeaponRegistry`.
Extend `WeaponBounceLogic`, `WeaponSplitLogic`, `ProjectileFactory`
and effect components when a known capability is reused. Only introduce
a distinct behavior object/interface for independently meaningful
semantics; avoid one class per stat variant or a second weapon registry.

Protect per-weapon projectile ownership, damage/terrain changes,
RNG, camera holds, burst timing, and online serialization.

### 4. Untangle progression and online orchestration

`MainGameProgressionFacade` mixes campaign, garage, hotseat handoff and
online duel connection state. `MainGameOnlineHostWaitingFacade` also
owns client event reception, interpolation and synchronization—more
than just its name suggests.

Move network operations into the existing `scripts/network/` services
where they own a full responsibility, and UI operations into the
existing `scripts/ui/` views. Keep Godot RPC endpoints on a stable
scene node path, or test any deliberate move with real host/guest peers.
Rename a facade only **after** its responsibilities match the new name.
Do not break the online host-authoritative boundary.

### 5. Retire the next ancestor only after its responsibilities are gone

Re-evaluate the seven-layer chain after phases 1–4. A six-layer
inheritance graph is a desirable consequence of consolidation, not
a stand-alone success metric. Demand fewer duplicated algorithms,
clearer ownership, fewer cross-layer overrides and easier feature
additions—not a shorter diagram with wider, more tangled services.

## Lifecycle and migration risk

The active hierarchy implements `_process` and `reset_match` at all
seven layers; firing and turn advancement span several other layers.
An override with `super` is not automatically redundant. Record
exactly which implementations run in each mode and preserve:

- `super` call order and initialization/reset ordering
- Virtual-method hooks referenced by lower scripts at parse time
- Projectile launch/impact ordering and owner-sensitive camera targeting
- RNG call count and ordering (terrain, AI, effect spawning)
- Network snapshots, command validation, ENet synchronization
- Weapon loadout/selection, turn handoff and pause behavior

The previous removal of a lower weapon menu body still required a
minimal virtual compile-time method declaration in `MainGame`.
Treat such stubs as explicit transitional contracts and verify them
against the Godot parser. The duplicate-method guard must remain green.

## Naming and folder conventions

Follow `docs/ARCHITECTURE_AUDIT_2026_10_30.md` for names:
`State` = data, `Session` = mutable lifecycle, `Policy` = rule,
`Planner` / `Scorer` = search/evaluation, `Controller` = flow
coordination, `View` / `Renderer` = presentation, `Registry` /
`Definition` = canonical descriptions, `Factory` = construction.
`Bridge` / `Facade` marks a **temporary** compatibility seam.

## PR acceptance gates

Every implementation PR must pass the GitHub Godot 4.6.3 workflow:

1. Seven-layer maximum and duplicate inherited-method guard
2. Clean headless import and script-class compilation
3. Standalone smoke/policy contracts
4. Active-scene hotseat, campaign, weapon and UI integration
5. Realtime projectile/AI/camera integration
6. Online packet and snapshot validation
7. Real two-process ENet host/guest integration
8. Main scene startup; runtime `SCRIPT ERROR` logs count as failures

Prefer small, reversible PRs; merge only when the full workflow is green.
Android/on-device sensors, touch input, graphics and network latency remain
separate manual release-validation requirements.
