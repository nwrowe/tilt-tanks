extends "res://scripts/MainHybridModes12.gd"

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

const DESTROYED_SMOKE_INTERVAL: float = 0.16
const DESTROYED_SMOKE_LIFETIME: float = 1.35
const DESTROYED_SMOKE_RISE_SPEED: float = 42.0
const DESTROYED_SMOKE_DRIFT_SPEED: float = 24.0
const DESTROYED_SMOKE_START_RADIUS: float = 5.0
const DESTROYED_SMOKE_END_RADIUS: float = 18.0

const SNOW_UPHILL_SLOW_MULT: float = 0.28
const SNOW_FACE_ALPHA: float = 0.86
const SNOW_FACE_SHADOW_ALPHA: float = 0.24

var weapon_button: Button
var weapon_panel: Panel
var weapon_menu_open: bool = false
var selected_weapon: String = WEAPON_STANDARD

var turn_projectile_weapon: String = WEAPON_STANDARD
var turn_projectile_split_done: bool = false
var turn_projectiles: Array[Dictionary] = []
var last_explosion_visual_radius: float = EXPLOSION_RADIUS

var destroyed_smoke_puffs: Array[Dictionary] = []
var destroyed_smoke_timer: float = 0.0
var destroyed_tank_index: int = -1

func _unhandled_input(event: InputEvent) -> void:
	# Compatibility hook for MainGame.gd while flattening the inheritance chain.
	return

func _ready() -> void:
	super._ready()
	_add_main_menu_controls()
	_relabel_quit_buttons()
	_resize_mobile_action_buttons()
	_build_weapon_ui()

func _resize_mobile_action_buttons() -> void:
	if mobile_left_button != null:
		mobile_left_button.position = Vector2(16, 430)
		mobile_left_button.size = Vector2(92, 88)
	if mobile_right_button != null:
		mobile_right_button.position = Vector2(122, 430)
		mobile_right_button.size = Vector2(92, 88)
	if mobile_fire_button != null:
		mobile_fire_button.position = Vector2(696, 448)
		mobile_fire_button.size = Vector2(188, 70)
	if weapon_button != null:
		weapon_button.position = WeaponSelectMenu.BUTTON_POS
		weapon_button.size = WeaponSelectMenu.BUTTON_SIZE

func _build_weapon_ui() -> void:
	weapon_button = WeaponSelectMenu.make_weapon_button(ui_layer)
	weapon_button.pressed.connect(_toggle_weapon_menu)

	weapon_panel = WeaponSelectMenu.make_panel(ui_layer)
	WeaponSelectMenu.add_title(weapon_panel)

	var standard_button: Button = WeaponSelectMenu.make_option_button(weapon_panel, WeaponCatalog.display_name(WEAPON_STANDARD), Vector2(42, 66))
	standard_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_STANDARD
		_close_weapon_menu()
	)

	var heavy_button: Button = WeaponSelectMenu.make_option_button(weapon_panel, WeaponCatalog.display_name(WEAPON_HEAVY), Vector2(42, 120))
	heavy_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_HEAVY
		_close_weapon_menu()
	)

	var cluster_button: Button = WeaponSelectMenu.make_option_button(weapon_panel, WeaponCatalog.display_name(WEAPON_CLUSTER), Vector2(42, 174))
	cluster_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_CLUSTER
		_close_weapon_menu()
	)

	var close_button: Button = WeaponSelectMenu.make_back_button(weapon_panel, Vector2(86, 232))
	close_button.pressed.connect(_close_weapon_menu)

func _make_weapon_menu_button(text: String, pos: Vector2) -> Button:
	return WeaponSelectMenu.make_option_button(weapon_panel, text, pos)

func _toggle_weapon_menu() -> void:
	if game_over:
		return
	if weapon_button != null:
		weapon_button.release_focus()
	if weapon_menu_open:
		_close_weapon_menu()
	else:
		_open_weapon_menu()

func _open_weapon_menu() -> void:
	weapon_menu_open = true
	overlay_open = true
	if weapon_panel != null:
		weapon_panel.visible = true
	mobile_left_pressed = false
	mobile_right_pressed = false
	if mobile_left_button != null:
		mobile_left_button.release_focus()
	if mobile_right_button != null:
		mobile_right_button.release_focus()
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _close_weapon_menu() -> void:
	weapon_menu_open = false
	if weapon_panel != null:
		weapon_panel.visible = false
	overlay_open = (menu_panel != null and menu_panel.visible) or (end_panel != null and end_panel.visible)

func _hide_overlays() -> void:
	super._hide_overlays()
	weapon_menu_open = false
	if weapon_panel != null:
		weapon_panel.visible = false

func _add_main_menu_controls() -> void:
	if menu_panel != null:
		menu_panel.size = Vector2(230, 194)
		var main_button: Button = Button.new()
		main_button.text = "Main Menu"
		main_button.position = Vector2(16, 138)
		main_button.size = Vector2(198, 36)
		_style_mobile_button(main_button)
		menu_panel.add_child(main_button)
		main_button.pressed.connect(_return_to_main_menu)

func _relabel_quit_buttons() -> void:
	_relabel_quit_buttons_recursive(ui_layer)

func _relabel_quit_buttons_recursive(node: Node) -> void:
	if node is Button:
		var button: Button = node as Button
		if button.text == "Quit":
			button.text = "Main Menu"
	for child: Node in node.get_children():
		_relabel_quit_buttons_recursive(child)

func _quit_game() -> void:
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	turn_projectiles.clear()
	rt_projectiles.clear()
	projectile_active = false
	game_over = false
	overlay_open = false
	weapon_menu_open = false
	destroyed_tank_index = -1
	destroyed_smoke_puffs.clear()
	if menu_panel != null:
		menu_panel.visible = false
	if end_panel != null:
		end_panel.visible = false
	if weapon_panel != null:
		weapon_panel.visible = false
	_show_main_menu()

func reset_match() -> void:
	turn_projectiles.clear()
	turn_projectile_weapon = selected_weapon
	turn_projectile_split_done = false
	last_explosion_visual_radius = EXPLOSION_RADIUS
	destroyed_smoke_puffs.clear()
	destroyed_smoke_timer = 0.0
	destroyed_tank_index = -1
	super.reset_match()
	_resize_mobile_action_buttons()
	_close_weapon_menu()

func _process(delta: float) -> void:
	if weapon_menu_open and menu_state == MENU_STATE_GAME:
		_update_destroyed_smoke(delta)
		queue_redraw()
		return
	if menu_state == MENU_STATE_GAME and game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME and not turn_projectiles.is_empty():
		_update_turn_weapon_projectiles(delta)
		if explosion_timer > 0.0:
			explosion_timer -= delta
			if explosion_timer <= 0.0:
				explosion_pos = Vector2.INF
		_update_camera(delta)
		_update_ui()
		_update_destroyed_smoke(delta)
		queue_redraw()
		return
	super._process(delta)
	_update_destroyed_smoke(delta)

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
	if ProjectileManager.projectile_hits_tank(pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS):
		return true
	if _is_in_pond(pos):
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	return ProjectileManager.is_out_of_world(pos, active_world_width, _bottom_floor_y())

func _fire_realtime_projectile(owner: int) -> void:
	if game_over:
		return
	if rt_projectiles.size() >= RT_MAX_ACTIVE_PROJECTILES:
		rt_projectiles.pop_front()
	var weapon: String = selected_weapon if owner == HUMAN_PLAYER_INDEX else WEAPON_STANDARD
	var facing: float = 1.0 if owner == HUMAN_PLAYER_INDEX else -1.0
	var shot_angle: float = player_angles[owner] if owner == AI_PLAYER_INDEX else angle_deg
	var shot_power_percent: float = player_power_percents[owner] if owner == AI_PLAYER_INDEX else power_percent
	var shot_power: float = _power_from_percent(shot_power_percent)
	var rad: float = deg_to_rad(shot_angle)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var start_pos: Vector2 = tank_positions[owner] + muzzle_offset
	var start_vel: Vector2 = Vector2(facing * shot_power * cos(rad), -shot_power * sin(rad))
	rt_projectiles.append(ProjectileFactory.make_shell(owner, weapon, start_pos, start_vel, false))
	projectile_active = false

func _update_all_realtime_projectiles(delta: float) -> void:
	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for shell: Dictionary in rt_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var owner: int = int(stepped.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(stepped.get("weapon", WEAPON_STANDARD))
		var split_done: bool = bool(stepped.get("split", false))
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var vel: Vector2 = stepped.get("vel", Vector2.ZERO)
		if weapon == WEAPON_CLUSTER and not split_done and vel.y >= 0.0:
			_spawn_realtime_cluster_children(owner, pos, vel)
		elif _realtime_projectile_should_explode(owner, pos):
			_explode_realtime_weapon(pos, weapon)
		else:
			remaining.append(stepped)
	rt_projectiles = remaining
	rt_player_shell_active = ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX)

func _spawn_realtime_cluster_children(owner: int, pos: Vector2, vel: Vector2) -> void:
	var children: Array[Dictionary] = ProjectileFactory.make_cluster_children(owner, pos, vel, CLUSTER_SPLIT_SPREAD_X, CLUSTER_SPLIT_SPEED_Y, WEAPON_CLUSTER_CHILD)
	for child: Dictionary in children:
		rt_projectiles.append(child)

func _has_active_realtime_shell_for_owner(owner: int) -> bool:
	return ProjectileManager.has_shell_for_owner(rt_projectiles, owner)

func _realtime_projectile_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	if ProjectileManager.projectile_hits_tank(pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS):
		return true
	if _is_in_pond(pos):
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	return ProjectileManager.is_out_of_world(pos, active_world_width, _bottom_floor_y())

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

func _show_end_popup() -> void:
	_start_destroyed_tank_smoke()
	super._show_end_popup()

func _start_destroyed_tank_smoke() -> void:
	if destroyed_tank_index >= 0:
		return
	if tank_health[0] <= 0:
		destroyed_tank_index = 0
	elif tank_health[1] <= 0:
		destroyed_tank_index = 1
	else:
		return
	destroyed_smoke_timer = 0.0
	for i: int in range(7):
		_spawn_destroyed_smoke_puff()

func _update_destroyed_smoke(delta: float) -> void:
	if destroyed_tank_index >= 0:
		destroyed_smoke_timer -= delta
		if destroyed_smoke_timer <= 0.0:
			_spawn_destroyed_smoke_puff()
			destroyed_smoke_timer = DESTROYED_SMOKE_INTERVAL
	destroyed_smoke_puffs = EffectsManager.update_rising_puffs(destroyed_smoke_puffs, delta, DESTROYED_SMOKE_RISE_SPEED)

func _spawn_destroyed_smoke_puff() -> void:
	if destroyed_tank_index < 0 or destroyed_tank_index >= tank_positions.size():
		return
	var base_pos: Vector2 = tank_positions[destroyed_tank_index]
	var offset: Vector2 = Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-36.0, -18.0))
	destroyed_smoke_puffs.append(EffectsManager.make_puff(
		base_pos + offset,
		DESTROYED_SMOKE_LIFETIME,
		rng.randf_range(-DESTROYED_SMOKE_DRIFT_SPEED, DESTROYED_SMOKE_DRIFT_SPEED)
	))

func _draw() -> void:
	super._draw()
	_draw_destroyed_smoke_puffs()

func _draw_destroyed_smoke_puffs() -> void:
	for puff: Dictionary in destroyed_smoke_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", DESTROYED_SMOKE_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, DESTROYED_SMOKE_START_RADIUS, DESTROYED_SMOKE_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.58)
		draw_circle(_world_to_screen(pos), radius, Color(0.78, 0.80, 0.77, alpha))

func _draw_realtime_projectiles() -> void:
	for shell: Dictionary in rt_projectiles:
		var owner: int = int(shell.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(shell.get("weapon", WEAPON_STANDARD))
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var radius: float = PROJECTILE_RADIUS * CAMERA_SCALE * _weapon_projectile_scale(weapon)
		var color: Color = Color(1.0, 0.92, 0.2) if owner == HUMAN_PLAYER_INDEX else Color(1.0, 0.38, 0.25)
		draw_circle(_world_to_screen(pos), radius, color)

func _draw_explosion() -> void:
	var elapsed_ratio: float = 1.0 - explosion_timer / EXPLOSION_DURATION
	var center: Vector2 = _world_to_screen(explosion_pos)
	var outer_radius: float = last_explosion_visual_radius * CAMERA_SCALE * (0.55 + 0.65 * elapsed_ratio)
	var inner_radius: float = outer_radius * 0.48
	draw_circle(center, outer_radius, Color(1.0, 0.42, 0.06, 0.42 * (1.0 - elapsed_ratio)))
	draw_circle(center, inner_radius, Color(1.0, 0.88, 0.20, 0.75 * (1.0 - elapsed_ratio)))
	for i: int in range(8):
		var a: float = TAU * float(i) / 8.0
		var ray_end: Vector2 = center + Vector2(cos(a), sin(a)) * outer_radius * 1.15
		draw_line(center, ray_end, Color(1.0, 0.75, 0.15, 0.45 * (1.0 - elapsed_ratio)), 2.0)
