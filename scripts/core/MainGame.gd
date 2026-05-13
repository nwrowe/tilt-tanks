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

# Weapon lookup facade
# --------------------
# The prototype chain still owns most projectile behavior, but active weapon
# numbers now come from WeaponCatalog. This is a safe extraction because the
# inherited methods below are the same lookup points the prototype already uses.

func _weapon_explosion_radius(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "explosion_radius", EXPLOSION_RADIUS))

func _weapon_direct_radius(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "direct_radius", DIRECT_HIT_RADIUS))

func _weapon_direct_damage(weapon: String) -> int:
	return int(WeaponCatalog.value(weapon, "direct_damage", DIRECT_HIT_DAMAGE))

func _weapon_splash_damage(weapon: String) -> int:
	return int(WeaponCatalog.value(weapon, "splash_damage", MAX_SPLASH_DAMAGE))

func _weapon_crater_radius(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "crater_radius", CRATER_RADIUS))

func _weapon_crater_depth(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "crater_depth", CRATER_DEPTH))

func _weapon_projectile_scale(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "projectile_scale", 1.0))

# Projectile factory facade
# -------------------------
# Keep the existing update logic, but centralize how cluster child shell
# dictionaries are created so the next pass can move projectile management out
# of MainGame entirely.

func _split_turn_cluster_projectile(pos: Vector2, vel: Vector2) -> void:
	projectile_active = false
	turn_projectile_split_done = true
	turn_projectiles.clear()
	turn_projectiles = ProjectileFactory.make_cluster_children(
		current_player,
		pos,
		vel,
		CLUSTER_SPLIT_SPREAD_X,
		CLUSTER_SPLIT_SPEED_Y,
		WEAPON_CLUSTER_CHILD
	)
	turn_cluster_camera_pos = pos

func _spawn_realtime_cluster_children(owner: int, pos: Vector2, vel: Vector2) -> void:
	var children: Array[Dictionary] = ProjectileFactory.make_cluster_children(
		owner,
		pos,
		vel,
		CLUSTER_SPLIT_SPREAD_X,
		CLUSTER_SPLIT_SPEED_Y,
		WEAPON_CLUSTER_CHILD
	)
	for child: Dictionary in children:
		rt_projectiles.append(child)
