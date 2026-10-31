# Architecture audit checkpoint — October 30, 2026

> **Decision:** Pause the next inheritance retirement. Keep `main` at eight
> active layers until ownership, duplication and naming issues below are
> addressed. This is an analysis checkpoint, not a report of runtime bugs.

Baseline: `cf4c82d2f76765478529c5691ee636cf8fd42d25`
(`main`, successful Godot smoke/real ENet pipeline).

## Scope and measurements

The repository contains **78** `scripts/**/*.gd` source files. The
actual attached `scenes/Main.tscn` inheritance path is:

```text
MainGameOnlineHostWaitingFacade
 -> MainGameProgressionFacade
 -> MainGameSpecialWeaponsFacade
 -> MainGameModeFacade
 -> MainGame
 -> WeaponRuntimeBridge
 -> WorldRuntimeBridge
 -> Main (Node2D)
```

These **eight** active files total about **6,314 lines and 530 declared
functions**. A name-based comparison shows **110 method names implemented in
two or more** of the active ancestors. That is not the same as 110 redundant
methods: overrides and `super` handoffs are central to the current game.
Comparing normalized method bodies found **12 pairs of identical-looking
implementations** across these ancestors. Examples include:
`_update_projectile`, `_spawn_destroyed_smoke_puff`,
`_draw_destroyed_smoke_puffs`, `_has_active_realtime_shell_for_owner`,
`_make_weapon_menu_button`, and seven `_weapon_*` property lookups.
This count is a static screening result, not a behavioral equivalence proof.

### P0: dispatch and data-source consistency — resolve before 8 → 7

1. **Multiple projectile handlers.** The hierarchy contains five
   `_update_all_realtime_projectiles` implementations, and both
   `MainGame.gd` and `WeaponRuntimeBridge.gd` contain identical
   `_update_projectile` bodies. Map which overrides and `super` paths run
   in normal, special-weapon and online play. Preserve camera tracking and
   split-projectile semantics before removing unreachable fallbacks.
2. **Weapon values have two lookup routes.** `WeaponCatalog` provides
   legacy base defaults, and `WeaponRegistry` builds data-driven
   `WeaponDefinition` objects from that catalog plus special definitions.
   Some older `_weapon_*` methods look up the catalog directly, while
   the active `MainGameModeFacade` uses `_weapon_value` / the definition
   session. Verify that an override cannot accidentally reintroduce
   catalog-only stats; establish the registry/definition session as the
   intended runtime source of truth, retaining the catalog only as an input
   or migration adapter until tested.
3. **Different pond reflow algorithms coexist.** The inherited
   `WorldRuntimeBridge._reflow_single_pond` uses a local changed-X search
   window; `MainGame._reflow_single_pond` delegates to
   `WaterManager.reflow_single_pond` with a connected-basin policy.
   Determine the actual dispatch path and add crater/volume-conservation
   parity tests before consolidating. The historical
   `docs/WORLD_WATER_MANAGER_POLICY.md` already warns that these algorithms
   differ. Do not delete one merely because names match.

### P1: clear ownership and remove unnecessary forwarding

4. **`WorldRuntimeBridge.gd` is now broader than its name.** The former
   mode ancestor was folded into it to remove a layer. It currently contains
   menu callbacks, AI setup, mode lifecycle and compatibility render hooks
   as well as world/terrain behavior. This is a valid temporary adapter,
   not a completed separation. Move coherent behavior to existing composed
   owners with targeted scene tests rather than introducing another parent.
5. **Mode policy wrappers are paired.** `HotseatModeController` forwards
   much of its API to static `HotseatMode`; likewise
   `RealtimeSinglePlayerModeController` forwards to
   `RealtimeSinglePlayerMode`. Some indirection may be justified because
   controllers participate in the mode registry. Confirm which layer
   represents policy and which orchestrates runtime state. Avoid two
   public surfaces for the same policy without a reason.
6. **Mode identity appears in multiple forms.** `GameMode` contains
   integer mode IDs, the compatibility runtime has `GAME_MODE_*` integer
   constants, and `ModeControllerRegistry` uses string IDs.
   `MainGameModeFacade` maps between them. Prefer one canonical mode
   identity and an explicit, tested legacy adapter. `GameMode.gd` had
   no direct `GameMode.` callers in a repository search; verify with a
   full reference check before considering deletion.
7. **Some façade names underdescribe their actual roles.**
   `MainGameProgressionFacade` also owns campaign/menu and substantial
   online-duel connection state. `MainGameOnlineHostWaitingFacade`
   handles client smoothing and event reception, not only host waiting.
   Repartition responsibility before renaming. A broad rename alone
   would not reduce complexity.
8. **Visual AI code is split by path.** `TurnAIVisualAimSession` lives
   under `scripts/ai`, but `RealtimeAIAimingSession` lives under
   `scripts/modes`. Their interfaces and timing differ; do **not**
   merge them indiscriminately. Put AI-domain session/policy objects in
   a consistent directory once references are inventoried.

### P2: consistent naming, folders and documentation

Suggested naming guide for **new or substantively rewritten** classes:

| Suffix | Ownership and intent |
|---|---|
| `State` | Data-only state without runtime orchestration |
| `Session` | Mutable state spanning a match, mode, turn or effect lifecycle |
| `Policy` | Stateless decision, formatting or numerical rules |
| `Planner` / `Scorer` | Search/selection and evaluation algorithms |
| `Controller` | Coordinates a gameplay flow or mode, not a thin alias for static functions |
| `View` / `Renderer` | Controls and drawing, respectively |
| `Registry` / `Definition` | Canonical catalog and descriptive data object |
| `Factory` | Constructs new data, scene objects or projectile models |
| `Bridge` / `Facade` | Temporary integration/compatibility only, with a retirement plan |
| `Manager` | Prefer for objects managing owned state; existing stateless `*Manager` names can remain until touched |

Known taxonomy mismatches: `WindMeterPolicy` is correctly in
`scripts/ui` but `CURRENT_ARCHITECTURE.md` groups it with effects;
`LegacyBackdropRenderer` is actively used despite its `Legacy`
prefix and `scripts/core` location; AI session placement differs.
Several historical `docs/*.md` architecture sketches still show
removed ancestors. Treat `CURRENT_ARCHITECTURE.md` and the actual scene
script as authoritative; label historical sketches clearly when edited.

### Behavior-preserving differences, not automatic duplicates

- `SteamPuffEffect.advance` mutates existing puff dictionaries in place.
  `EffectsManager.update_rising_puffs` copies each puff before updating.
  They share arithmetic but have **different identity/mutation contracts**.
- `ProjectileManager.step_shell` takes a shell dictionary while
  `step_legacy_projectile` takes position/velocity fields. Consolidate
  only after data-shape parity is specified.
- A parent method overridden without a `super` call may be a fallback
  required for standalone scripts or other inherited callers; classify
  reachability before deleting it.

## Proposed cleanup gates

- Create a **method ownership/dispatch matrix** for the eight ancestors,
  explicitly marking each override as active, super-chained, fallback or
  candidate-dead, with evidence from the active scene.
- For projectile and weapon paths, create tests proving feature variants,
  split behavior, camera focus, registry overrides, reset and online parity.
- Centralize metadata behind the existing definition session before
  deleting catalog-only fallbacks.
- Add pond reflow conservation/crater regression cases before choosing
  the authoritative algorithm.
- Consolidate the two obvious policy-controller forwarding pairs only
  where the mode registry and tests show redundant public surfaces.
- Adopt the naming guide for new work and relocate/rename selectively,
  one cross-reference-safe change per PR. No global cosmetic renaming.
- Only after these pass: resume retiring `WeaponRuntimeBridge` from
  eight to seven active script layers.

## Rules for the next implementation PR

Every change must keep Godot 4.6.3 strict import, smoke, active-scene
integration, realtime/camera and network protocol tests, actual two-process
ENet, and main scene startup green. A lower inheritance count by itself
is **not** acceptance: total duplicated active logic, API ownership,
and readability must improve. Android on-device validation remains a
separate release gate.
