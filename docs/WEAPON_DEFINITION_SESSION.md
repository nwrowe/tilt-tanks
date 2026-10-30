# Weapon definition session extraction

WeaponDefinitionRuntimeBridge previously owned the weapon registry,
allowed loadout and metadata-policy lookups as inherited state. The new
scene-independent WeaponDefinitionSession owns those functions instead,
including the definition lookup, loadout validation, fallback weapon,
split eligibility and child construction.

The existing gameplay layer retains compatibility references named
weapon_definitions and active_weapon_loadout for older menus, AI,
networking and level scripts. Its loadout update/reset entry points
now update the session first and keep those references synchronized.

This is an intentional prerequisite for retiring the remaining
WeaponDefinitionRuntimeBridge inheritance layer. The bridge is still in
the chain in this PR, so this PR does not change the depth budget.

CI tests standalone registry, loadout restriction, split-weapon logic,
and live-game use of the same session after switching between default
and synthetic restricted levels. It also retains multiplayer and
realtime test coverage.

Once validated, the small engine-facing callbacks can be relocated
directly to the weapon runtime and the redundant bridge deleted,
lowering active scene depth by another layer.
