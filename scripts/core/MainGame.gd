extends "res://scripts/MainHybridModes19.gd"

# CLEAN ACTIVE ENTRY POINT
# ------------------------
# This script intentionally extends the last known-good prototype build while
# we migrate systems into organized modules. The scene should point here from
# now on, instead of directly to MainHybridModesXX.gd.
#
# Refactor plan:
# - Keep behavior stable through this file.
# - Move weapon constants/lookup into scripts/weapons/WeaponCatalog.gd.
# - Move mode constants into scripts/modes/GameMode.gd.
# - Gradually extract terrain, projectiles, UI, effects, and game modes.
# - Once parity is confirmed, archive/delete the old MainHybridModesXX chain.

const ACTIVE_BUILD_NAME: String = "MainGame refactor facade"

func _ready() -> void:
	super._ready()
	print("Tilt Tanks active script: %s" % ACTIVE_BUILD_NAME)
