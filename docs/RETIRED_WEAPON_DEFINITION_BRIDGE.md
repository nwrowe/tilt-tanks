# Retired weapon definition inheritance bridge

The active scene no longer inherits `WeaponDefinitionRuntimeBridge.gd`.
`MainGame.gd` now extends `WeaponRuntimeBridge.gd` directly and the
obsolete definition bridge has been deleted.

**Active inheritance depth: 13 → 12.**

The independent `WeaponDefinitionSession` (introduced before retirement)
owns the default registry, current permitted loadout, fallback weapon and
definition-driven split policy. `MainGame.gd` retains only the compact
compatibility API that existing UI, weapons, AI, level configuration and RPC
handlers invoke. The legacy fields `weapon_definitions` and
`active_weapon_loadout` remain references synchronized with the session.

## Preserved behavior

- The old bridge's pre-reset selected-weapon validation now occurs immediately
  before the base reset call in `MainGame.reset_match`.
- Runtime weapons still receive registry metadata from `_weapon_value` and
  the existing mode-level stat overrides; default and restricted loadouts
  remain supported.
- Cluster split decision and child construction continue to call
  `WeaponDefinitionSession` / `WeaponSplitLogic`.
- The active mode-level weapon menu, split-camera focus and gameplay effects
  remain untouched. The older main and weapon runtime implementations remain
  fallback methods; no additional mega-facade was created.

The existing behavior of the active game is covered by smoke, gameplay,
level restriction, realtime AI/camera, network protocol and two-process
ENet tests. A new live-scene test verifies the registry APIs, direct cluster
policy and loadout invalidation after switching to a restricted level.

GitHub Actions now rejects any inheritance chain deeper than 12.
