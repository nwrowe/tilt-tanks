# Tank Progression Design

This document defines the direction for upgradeable tanks, tank classes, and trainable crew.

## Design goal

Tilt Tanks should support a deeper FTL-like configuration layer without breaking the fast artillery-game loop.

The player should be able to pause between shots or during a non-action setup state, inspect the tank, install upgrades, train crew, and configure weapons. The game can later decide whether this is allowed any time, only between turns, only in campaign, or only in special prep phases.

## Core idea

Each player has a `TankBuildState`:

```text
TankBuildState
 -> tank_class_id
 -> installed_upgrade_ids
 -> assigned_crew_ids
 -> unlocked_weapon_ids
 -> credits/resources
```

Effective tank performance comes from three layers:

```text
Tank class base stats
+ hardware upgrade modifiers
+ crew skill modifiers
= effective stats, capped by tank class stat ceilings
```

## Tank classes

Tank classes are purchasable chassis tiers. Higher classes support better stats, stronger weapons, more upgrade slots, and more crew slots.

Initial classes:

```text
Scout Tank   -> tier 1, fast starter, light upgrade capacity
Medium Tank  -> tier 2, balanced chassis, more upgrade slots
Heavy Tank   -> tier 3, durable chassis, larger crew
Siege Tank   -> tier 4, late-game heavy weapon chassis
```

Class limits should control:

- base health
- damage resistance cap
- fire-power cap
- aim-stability cap
- reload-speed cap
- engine/mobility cap
- track/grip cap
- weapon tier
- hardware upgrade tier
- crew-role capacity

## Hardware upgrades

Initial upgrade slots:

```text
barrel
armor
tracks
cope_cage
engine
electronics
```

Example upgrades:

- Stabilized Barrel: improves aim stability and fire power
- Reinforced Armor: improves health and resistance
- Wide Tracks: improves traction and snow/hill handling
- Engine Tune: improves movement response
- Cope Cage: improves splash/overhead survivability with a mobility cost
- Ballistic Computer: improves aiming and specialist efficiency

The key design constraint is that upgrades should be data-first. Runtime behavior should read effective stats rather than hardcoding one-off upgrade checks wherever possible.

## Crew system

Crew should work like a light FTL-inspired system: each crew member has a role, level, XP/training state, and stat modifiers.

Initial roles:

```text
driver             -> movement, traction, terrain handling
gunner             -> aim stability, reload cadence
weapon_specialist  -> special weapon handling, fire power
engineer           -> survivability, repair/system efficiency
commander          -> broad coordination bonuses
```

Crew should eventually gain XP from use:

- driver gains XP from movement/terrain recovery
- gunner gains XP from firing/hitting
- weapon specialist gains XP from special weapon use
- engineer gains XP from surviving damage/repair actions
- commander gains XP from victories or multi-system actions

For the first pass, crew can be trained directly through a menu or debug/purchase flow.

## Pause/configuration model

The FTL-style pause idea fits well, but it should be scoped carefully.

Recommended phases:

1. **Current demonstrator**: pause menu can open, but progression data is passive only.
2. **Garage screen**: add a non-combat configuration menu from the main menu.
3. **Between-turn configuration**: allow limited changes during hotseat between shots.
4. **Campaign pause configuration**: allow deeper FTL-style setup during campaign, possibly consuming resources or action points.
5. **Realtime restrictions**: in realtime single-player, either freeze gameplay while configuring or restrict configuration to pre-match/pause states.

## First implementation pass

The current branch adds passive data/model code only:

```text
scripts/progression/TankClassDefinition.gd
scripts/progression/TankUpgradeDefinition.gd
scripts/progression/CrewMemberDefinition.gd
scripts/progression/TankBuildState.gd
scripts/progression/TankProgressionRegistry.gd
```

This establishes the vocabulary and stat math without changing live combat.

## Future integration steps

Recommended order:

1. Add `TankBuildState` arrays to `MatchState` for player 1/player 2.
2. Initialize both players with default Scout builds.
3. Add read-only tank summary to the pause menu.
4. Apply `max_health` to tank starting health.
5. Apply `damage_resist` during damage calculation.
6. Apply `fire_power` to outgoing damage or explosive effect scaling.
7. Apply `aim_stability` to jitter/trajectory preview quality.
8. Apply `engine_power` and `track_grip` to movement and snow/terrain behavior.
9. Add a garage/configuration UI.
10. Add purchases, training, and campaign persistence.

## Important balance rule

Do not make upgrades purely linear power creep. Higher tank classes should open wider build styles, not simply make all lower tanks obsolete.

Example tradeoffs:

- Scout: fast, accurate, low survivability
- Medium: balanced
- Heavy: durable, slower, strong armor slots
- Siege: strongest weapons, slowest, needs crew investment

## Open questions

- Should hotseat players both configure from the same pause menu, or should each player have a hidden setup screen?
- Should crew be persistent across campaign missions only, or also in quick/hotseat games?
- Should tank purchases exist in local hotseat, or only campaign?
- Should upgrades be installed instantly mid-game, or only during setup/garage phases?
- Should weapons be tied to tank class, crew skill, or both?
