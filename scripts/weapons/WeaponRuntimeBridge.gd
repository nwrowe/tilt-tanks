extends "res://scripts/modes/WorldRuntimeBridge.gd"

# Active weapon runtime bridge while MainGame.gd is being flattened.
# Most newer behavior is already overridden in scripts/core/MainGame.gd. This
# layer keeps only the declarations and fallback/runtime hooks still needed by
# the active chain, and delegates weapon/projectile/effect data to helper scripts.

const WEAPON_STANDARD: String = WeaponCatalog.STANDARD
const WEAPON_HEAVY: String = WeaponCatalog.HEAVY
const WEAPON_CLUSTER: String = WeaponCatalog.CLUSTER
const WEAPON_CLUSTER_CHILD: String = WeaponCatalog.CLUSTER_CHILD

const CLUSTER_SPLIT_SPREAD_X: float = 115.0
const CLUSTER_SPLIT_SPEED_Y: float = 58.0


const SNOW_UPHILL_SLOW_MULT: float = 0.28
const SNOW_FACE_ALPHA: float = 0.86
const SNOW_FACE_SHADOW_ALPHA: float = 0.24

var weapon_button: Button
var weapon_panel: Panel
var weapon_menu_open: bool = false
# Canonical weapon metadata owner for this runtime and all descendants.
# Older catalog IDs remain input to WeaponRegistry, not a second stat source.
var weapon_definition_session: WeaponDefinitionSession = WeaponDefinitionSession.new()
var selected_weapon: String = WEAPON_STANDARD

# Composed owner; keep the legacy game-facing names for special weapons,
# match snapshots, AI, hotseat input and active scene tests.
var turn_projectile_session: TurnProjectileSession = TurnProjectileSession.new()
var turn_projectile_weapon: String:
	get:
		return turn_projectile_session.weapon
	set(value):
		turn_projectile_session.weapon = value
var turn_projectile_split_done: bool:
	get:
		return turn_projectile_session.split_done
	set(value):
		turn_projectile_session.split_done = value
var turn_projectiles: Array[Dictionary]:
	get:
		return turn_projectile_session.shells
	set(value):
		turn_projectile_session.shells = value
var last_explosion_visual_radius: float = EXPLOSION_RADIUS

func _unhandled_input(event: InputEvent) -> void:
	# Compatibility hook for MainGame.gd while flattening the inheritance chain.
	return

func _on_fire_pressed() -> void:
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		super._on_fire_pressed()
		return
	if projectile_active or not turn_projectiles.is_empty() or game_over or overlay_open:
		return
	power_slider.release_focus()
	player_angles[current_player] = angle_deg
	player_powers[current_player] = power
	turn_projectile_weapon = selected_weapon
	turn_projectile_split_done = false
	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	projectile_pos = tank_positions[current_player] + muzzle_offset
	projectile_vel = Vector2(facing * power * cos(rad), -power * sin(rad))
	projectile_active = true

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

func _split_turn_cluster_projectile(pos: Vector2, vel: Vector2) -> void:
	projectile_active = false
	turn_projectile_split_done = true
	turn_projectiles.clear()
	turn_projectiles = ProjectileFactory.make_cluster_children(current_player, pos, vel, CLUSTER_SPLIT_SPREAD_X, CLUSTER_SPLIT_SPEED_Y, WEAPON_CLUSTER_CHILD)

func _update_turn_weapon_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for shell: Dictionary in turn_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var owner: int = int(stepped.get("owner", current_player))
		var weapon: String = str(stepped.get("weapon", WEAPON_CLUSTER_CHILD))
		if _turn_shell_should_explode(owner, pos):
			_explode_turn_weapon(pos, weapon, false)
		else:
			remaining.append(stepped)
	turn_projectiles = remaining
	if turn_projectiles.is_empty() and not game_over:
		_advance_turn()

func _turn_shell_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = 1 - owner
	return ProjectileManager.should_shell_explode(
		pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS,
		Callable(self, "_is_in_pond"), Callable(self, "_ground_y_at_x"),
		active_world_width, Callable(self, "_bottom_floor_y")
	)

func _has_active_realtime_shell_for_owner(owner: int) -> bool:
	return ProjectileManager.has_shell_for_owner(rt_projectiles, owner)

func _realtime_projectile_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	return ProjectileManager.should_shell_explode(
		pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS,
		Callable(self, "_is_in_pond"), Callable(self, "_ground_y_at_x"),
		active_world_width, Callable(self, "_bottom_floor_y")
	)

func _explode_realtime(pos: Vector2) -> void:
	_explode_realtime_weapon(pos, WEAPON_STANDARD)

func _explode_realtime_weapon(pos: Vector2, weapon: String) -> void:
	explosion_pos = pos
	explosion_timer = EXPLOSION_DURATION
	last_explosion_visual_radius = _weapon_explosion_radius(weapon)
	_apply_weapon_crater(pos, weapon)
	_apply_weapon_damage(pos, weapon)
	_settle_tanks_on_terrain()
	if tank_health[HUMAN_PLAYER_INDEX] <= 0 or tank_health[AI_PLAYER_INDEX] <= 0:
		game_over = true
		_show_end_popup()

func _explode_turn_weapon(pos: Vector2, weapon: String, advance_after: bool) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = EXPLOSION_DURATION
	last_explosion_visual_radius = _weapon_explosion_radius(weapon)
	_apply_weapon_crater(pos, weapon)
	_apply_weapon_damage(pos, weapon)
	_settle_tanks_on_terrain()
	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
		_show_end_popup()
	elif advance_after:
		_advance_turn()

func _apply_weapon_damage(pos: Vector2, weapon: String) -> void:
	var direct_radius: float = _weapon_direct_radius(weapon)
	var explosion_radius: float = _weapon_explosion_radius(weapon)
	var direct_damage: int = _weapon_direct_damage(weapon)
	var splash_damage: int = _weapon_splash_damage(weapon)
	for player: int in range(2):
		var dist: float = pos.distance_to(tank_positions[player])
		if dist <= direct_radius:
			tank_health[player] = maxi(0, tank_health[player] - direct_damage)
		elif dist <= explosion_radius:
			var normalized: float = (dist - direct_radius) / maxf(explosion_radius - direct_radius, 1.0)
			var damage_float: float = float(splash_damage) * pow(1.0 - normalized, 1.35)
			var damage: int = maxi(4, int(round(damage_float)))
			tank_health[player] = maxi(0, tank_health[player] - damage)

func _apply_weapon_crater(pos: Vector2, weapon: String) -> void:
	TerrainManager.apply_crater(
		terrain_points,
		pos,
		_weapon_crater_radius(weapon),
		_weapon_crater_depth(weapon),
		VAR_TERRAIN_MIN_Y,
		_bottom_floor_y()
	)
	_refresh_terrain_line()
	_reflow_water_after_terrain_change(pos.x)

func _weapon_value(weapon: String, key: String, fallback: Variant) -> Variant:
	return weapon_definition_session.value(weapon, key, fallback)

func _weapon_explosion_radius(weapon: String) -> float:
	return float(_weapon_value(weapon, "explosion_radius", EXPLOSION_RADIUS))

func _weapon_direct_radius(weapon: String) -> float:
	return float(_weapon_value(weapon, "direct_radius", DIRECT_HIT_RADIUS))

func _weapon_direct_damage(weapon: String) -> int:
	return int(_weapon_value(weapon, "direct_damage", DIRECT_HIT_DAMAGE))

func _weapon_splash_damage(weapon: String) -> int:
	return int(_weapon_value(weapon, "splash_damage", MAX_SPLASH_DAMAGE))

func _weapon_crater_radius(weapon: String) -> float:
	return float(_weapon_value(weapon, "crater_radius", CRATER_RADIUS))

func _weapon_crater_depth(weapon: String) -> float:
	return float(_weapon_value(weapon, "crater_depth", CRATER_DEPTH))

func _weapon_projectile_scale(weapon: String) -> float:
	return float(_weapon_value(weapon, "projectile_scale", 1.0))

