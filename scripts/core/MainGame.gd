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

# Projectile extraction facade
# ----------------------------
# Keep game behavior in this active entry point while routing common projectile
# data creation, stepping, and owner checks through helper modules. This is the
# bridge toward moving all projectile behavior into ProjectileManager.gd.

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

func _has_active_realtime_shell_for_owner(owner: int) -> bool:
	return ProjectileManager.has_shell_for_owner(rt_projectiles, owner)

func _update_projectile(delta: float) -> void:
	var stepped: Dictionary = ProjectileManager.step_legacy_projectile(projectile_pos, projectile_vel, gravity, wind, delta)
	projectile_pos = stepped.get("pos", projectile_pos)
	projectile_vel = stepped.get("vel", projectile_vel)
	if turn_projectile_weapon == WEAPON_CLUSTER and not turn_projectile_split_done and projectile_vel.y >= 0.0:
		_split_turn_cluster_projectile(projectile_pos, projectile_vel)
		return
	var enemy: int = 1 - current_player
	if ProjectileManager.projectile_hits_tank(projectile_pos, tank_positions[enemy], TANK_RADIUS, PROJECTILE_RADIUS):
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)
		return
	if _is_in_pond(projectile_pos):
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)
		return
	var ground_y: float = _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		_explode_turn_weapon(Vector2(projectile_pos.x, ground_y), turn_projectile_weapon, true)
		return
	if ProjectileManager.is_out_of_world(projectile_pos, active_world_width, _bottom_floor_y()):
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)

func _turn_shell_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = 1 - owner
	if ProjectileManager.projectile_hits_tank(pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS):
		return true
	if _is_in_pond(pos):
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	if ProjectileManager.is_out_of_world(pos, active_world_width, _bottom_floor_y()):
		return true
	return false

func _realtime_projectile_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	if ProjectileManager.projectile_hits_tank(pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS):
		return true
	if _is_in_pond(pos):
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	if ProjectileManager.is_out_of_world(pos, active_world_width, _bottom_floor_y()):
		return true
	return false

func _update_turn_weapon_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	turn_cluster_camera_pos = Vector2.INF
	var last_center_pos: Vector2 = Vector2.INF
	var any_center_shell_alive: bool = false

	for shell: Dictionary in turn_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var owner: int = int(stepped.get("owner", current_player))
		var weapon: String = str(stepped.get("weapon", WEAPON_CLUSTER_CHILD))
		var is_center: bool = bool(stepped.get("center_child", false))

		if is_center:
			last_center_pos = pos
			turn_cluster_camera_pos = pos

		if _turn_shell_should_explode(owner, pos):
			_explode_turn_weapon(pos, weapon, false)
			if is_center:
				cluster_camera_hold_pos = pos
				cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		else:
			remaining.append(stepped)
			if is_center:
				any_center_shell_alive = true

	turn_projectiles = remaining
	if any_center_shell_alive:
		cluster_camera_hold_pos = last_center_pos
	elif not turn_projectiles.is_empty() and cluster_camera_hold_pos == Vector2.INF:
		var avg: Vector2 = ProjectileManager.average_shell_position(turn_projectiles)
		turn_cluster_camera_pos = avg
		cluster_camera_hold_pos = avg

	if turn_projectiles.is_empty():
		turn_cluster_camera_pos = Vector2.INF
		if cluster_camera_hold_pos == Vector2.INF:
			cluster_camera_hold_pos = last_center_pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		if not game_over:
			_advance_turn()

func _update_all_realtime_projectiles(delta: float) -> void:
	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var cluster_focus_sum: Vector2 = Vector2.ZERO
	var cluster_focus_n: int = 0
	var had_cluster_children: bool = false
	var last_cluster_explosion: Vector2 = Vector2.INF

	for shell: Dictionary in rt_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var owner: int = int(stepped.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(stepped.get("weapon", WEAPON_STANDARD))
		var split_done: bool = bool(stepped.get("split", false))
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var vel: Vector2 = stepped.get("vel", Vector2.ZERO)

		if weapon == WEAPON_CLUSTER and not split_done and vel.y >= 0.0:
			_spawn_realtime_cluster_children(owner, pos, vel)
			realtime_cluster_focus_pos = pos
			realtime_cluster_focus_count = 3
		elif _realtime_projectile_should_explode(owner, pos):
			if weapon == WEAPON_CLUSTER_CHILD:
				had_cluster_children = true
				last_cluster_explosion = pos
				realtime_cluster_focus_count = maxi(0, realtime_cluster_focus_count - 1)
			_explode_realtime_weapon(pos, weapon)
		else:
			remaining.append(stepped)
			if weapon == WEAPON_CLUSTER_CHILD:
				had_cluster_children = true
				cluster_focus_sum += pos
				cluster_focus_n += 1

	rt_projectiles = remaining
	rt_player_shell_active = ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX)

	if cluster_focus_n > 0:
		realtime_cluster_focus_pos = cluster_focus_sum / float(cluster_focus_n)
		cluster_camera_hold_pos = realtime_cluster_focus_pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
	elif had_cluster_children:
		if last_cluster_explosion != Vector2.INF:
			realtime_cluster_focus_pos = last_cluster_explosion
			cluster_camera_hold_pos = last_cluster_explosion
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		if realtime_cluster_focus_count <= 0:
			realtime_cluster_focus_pos = Vector2.INF
	elif rt_projectiles.is_empty() and explosion_pos != Vector2.INF:
		cluster_camera_hold_pos = explosion_pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
