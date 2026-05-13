extends "res://scripts/MainHybridModes14.gd"

const WEAPON_STANDARD: String = "standard"
const WEAPON_HEAVY: String = "heavy"
const WEAPON_CLUSTER: String = "cluster"
const WEAPON_CLUSTER_CHILD: String = "cluster_child"

const HEAVY_EXPLOSION_RADIUS: float = 86.0
const HEAVY_DIRECT_HIT_RADIUS: float = 28.0
const HEAVY_DIRECT_DAMAGE: int = 62
const HEAVY_SPLASH_DAMAGE: int = 54
const HEAVY_CRATER_RADIUS: float = 78.0
const HEAVY_CRATER_DEPTH: float = 62.0

const CLUSTER_EXPLOSION_RADIUS: float = 46.0
const CLUSTER_DIRECT_HIT_RADIUS: float = 18.0
const CLUSTER_DIRECT_DAMAGE: int = 36
const CLUSTER_SPLASH_DAMAGE: int = 31
const CLUSTER_CRATER_RADIUS: float = 40.0
const CLUSTER_CRATER_DEPTH: float = 34.0
const CLUSTER_SPLIT_SPREAD_X: float = 115.0
const CLUSTER_SPLIT_SPEED_Y: float = 58.0

var turn_projectile_weapon: String = WEAPON_STANDARD
var turn_projectile_split_done: bool = false
var turn_projectiles: Array[Dictionary] = []
var last_explosion_visual_radius: float = EXPLOSION_RADIUS

func _ready() -> void:
	super._ready()
	_add_main_menu_controls()
	_relabel_quit_buttons()
	_resize_mobile_action_buttons()

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
		weapon_button.position = Vector2(786, 12)
		weapon_button.size = Vector2(44, 38)

func _build_weapon_ui() -> void:
	weapon_button = Button.new()
	weapon_button.text = "B"
	weapon_button.position = Vector2(786, 12)
	weapon_button.size = Vector2(44, 38)
	_style_mobile_button(weapon_button)
	ui_layer.add_child(weapon_button)
	weapon_button.pressed.connect(_toggle_weapon_menu)

	weapon_panel = Panel.new()
	weapon_panel.visible = false
	weapon_panel.position = Vector2(275, 126)
	weapon_panel.size = Vector2(350, 286)
	ui_layer.add_child(weapon_panel)

	var title: Label = Label.new()
	title.text = "Select Weapon"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(18, 16)
	title.size = Vector2(314, 32)
	title.add_theme_font_size_override("font_size", 24)
	weapon_panel.add_child(title)

	var standard_button: Button = _make_weapon_menu_button("Standard Shell", Vector2(42, 66))
	standard_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_STANDARD
		_close_weapon_menu()
	)

	var heavy_button: Button = _make_weapon_menu_button("Heavy Shell", Vector2(42, 120))
	heavy_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_HEAVY
		_close_weapon_menu()
	)

	var cluster_button: Button = _make_weapon_menu_button("Cluster Bomb", Vector2(42, 174))
	cluster_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_CLUSTER
		_close_weapon_menu()
	)

	var close_button: Button = _make_weapon_menu_button("Back", Vector2(86, 232))
	close_button.size = Vector2(178, 38)
	close_button.pressed.connect(_close_weapon_menu)

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
	super.reset_match()
	_resize_mobile_action_buttons()

func _process(delta: float) -> void:
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
	projectile_vel.y += gravity * delta
	projectile_vel.x += wind * delta
	projectile_pos += projectile_vel * delta
	if turn_projectile_weapon == WEAPON_CLUSTER and not turn_projectile_split_done and projectile_vel.y >= 0.0:
		_split_turn_cluster_projectile(projectile_pos, projectile_vel)
		return
	var enemy: int = 1 - current_player
	if projectile_pos.distance_to(tank_positions[enemy]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)
		return
	if _is_in_pond(projectile_pos):
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)
		return
	var ground_y: float = _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		_explode_turn_weapon(Vector2(projectile_pos.x, ground_y), turn_projectile_weapon, true)
		return
	if projectile_pos.x < -100.0 or projectile_pos.x > active_world_width + 100.0 or projectile_pos.y > _bottom_floor_y() + 180.0:
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)

func _split_turn_cluster_projectile(pos: Vector2, vel: Vector2) -> void:
	projectile_active = false
	turn_projectile_split_done = true
	turn_projectiles.clear()
	var spreads: Array[float] = [-CLUSTER_SPLIT_SPREAD_X, 0.0, CLUSTER_SPLIT_SPREAD_X]
	for spread: float in spreads:
		turn_projectiles.append({
			"owner": current_player,
			"weapon": WEAPON_CLUSTER_CHILD,
			"pos": pos,
			"vel": Vector2(vel.x + spread, maxf(absf(vel.y) * 0.35, CLUSTER_SPLIT_SPEED_Y))
		})

func _update_turn_weapon_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for shell: Dictionary in turn_projectiles:
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var vel: Vector2 = shell.get("vel", Vector2.ZERO)
		var owner: int = int(shell.get("owner", current_player))
		var weapon: String = str(shell.get("weapon", WEAPON_CLUSTER_CHILD))
		vel.y += gravity * delta
		vel.x += wind * delta
		pos += vel * delta
		if _turn_shell_should_explode(owner, pos):
			_explode_turn_weapon(pos, weapon, false)
		else:
			shell["pos"] = pos
			shell["vel"] = vel
			remaining.append(shell)
	turn_projectiles = remaining
	if turn_projectiles.is_empty() and not game_over:
		_advance_turn()

func _turn_shell_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = 1 - owner
	if pos.distance_to(tank_positions[target]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		return true
	if _is_in_pond(pos):
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	if pos.x < -100.0 or pos.x > active_world_width + 100.0 or pos.y > _bottom_floor_y() + 180.0:
		return true
	return false

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
	rt_projectiles.append({
		"owner": owner,
		"weapon": weapon,
		"split": false,
		"pos": start_pos,
		"vel": start_vel
	})
	projectile_active = false

func _update_all_realtime_projectiles(delta: float) -> void:
	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for shell: Dictionary in rt_projectiles:
		var owner: int = int(shell.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(shell.get("weapon", WEAPON_STANDARD))
		var split_done: bool = bool(shell.get("split", false))
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var vel: Vector2 = shell.get("vel", Vector2.ZERO)
		vel.y += gravity * delta
		vel.x += wind * delta
		pos += vel * delta
		if weapon == WEAPON_CLUSTER and not split_done and vel.y >= 0.0:
			_spawn_realtime_cluster_children(owner, pos, vel)
		elif _realtime_projectile_should_explode(owner, pos):
			_explode_realtime_weapon(pos, weapon)
		else:
			shell["pos"] = pos
			shell["vel"] = vel
			remaining.append(shell)
	rt_projectiles = remaining
	rt_player_shell_active = _has_active_realtime_shell_for_owner(HUMAN_PLAYER_INDEX)

func _spawn_realtime_cluster_children(owner: int, pos: Vector2, vel: Vector2) -> void:
	var spreads: Array[float] = [-CLUSTER_SPLIT_SPREAD_X, 0.0, CLUSTER_SPLIT_SPREAD_X]
	for spread: float in spreads:
		rt_projectiles.append({
			"owner": owner,
			"weapon": WEAPON_CLUSTER_CHILD,
			"split": true,
			"pos": pos,
			"vel": Vector2(vel.x + spread, maxf(absf(vel.y) * 0.35, CLUSTER_SPLIT_SPEED_Y))
		})

func _has_active_realtime_shell_for_owner(owner: int) -> bool:
	for shell: Dictionary in rt_projectiles:
		if int(shell.get("owner", -1)) == owner:
			return true
	return false

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
	var crater_radius: float = _weapon_crater_radius(weapon)
	var crater_depth: float = _weapon_crater_depth(weapon)
	var floor_y: float = _bottom_floor_y()
	for i: int in range(terrain_points.size()):
		var point: Vector2 = terrain_points[i]
		var dx: float = point.x - pos.x
		if absf(dx) <= crater_radius:
			var normalized_x: float = dx / crater_radius
			var bowl: float = sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
			var target_y: float = pos.y + crater_depth * bowl
			point.y = clampf(maxf(point.y, target_y), VAR_TERRAIN_MIN_Y, floor_y)
			terrain_points[i] = point
	_refresh_terrain_line()
	_reflow_water_after_terrain_change(pos.x)

func _weapon_explosion_radius(weapon: String) -> float:
	if weapon == WEAPON_HEAVY:
		return HEAVY_EXPLOSION_RADIUS
	if weapon == WEAPON_CLUSTER_CHILD or weapon == WEAPON_CLUSTER:
		return CLUSTER_EXPLOSION_RADIUS
	return EXPLOSION_RADIUS

func _weapon_direct_radius(weapon: String) -> float:
	if weapon == WEAPON_HEAVY:
		return HEAVY_DIRECT_HIT_RADIUS
	if weapon == WEAPON_CLUSTER_CHILD or weapon == WEAPON_CLUSTER:
		return CLUSTER_DIRECT_HIT_RADIUS
	return DIRECT_HIT_RADIUS

func _weapon_direct_damage(weapon: String) -> int:
	if weapon == WEAPON_HEAVY:
		return HEAVY_DIRECT_DAMAGE
	if weapon == WEAPON_CLUSTER_CHILD or weapon == WEAPON_CLUSTER:
		return CLUSTER_DIRECT_DAMAGE
	return DIRECT_HIT_DAMAGE

func _weapon_splash_damage(weapon: String) -> int:
	if weapon == WEAPON_HEAVY:
		return HEAVY_SPLASH_DAMAGE
	if weapon == WEAPON_CLUSTER_CHILD or weapon == WEAPON_CLUSTER:
		return CLUSTER_SPLASH_DAMAGE
	return MAX_SPLASH_DAMAGE

func _weapon_crater_radius(weapon: String) -> float:
	if weapon == WEAPON_HEAVY:
		return HEAVY_CRATER_RADIUS
	if weapon == WEAPON_CLUSTER_CHILD or weapon == WEAPON_CLUSTER:
		return CLUSTER_CRATER_RADIUS
	return CRATER_RADIUS

func _weapon_crater_depth(weapon: String) -> float:
	if weapon == WEAPON_HEAVY:
		return HEAVY_CRATER_DEPTH
	if weapon == WEAPON_CLUSTER_CHILD or weapon == WEAPON_CLUSTER:
		return CLUSTER_CRATER_DEPTH
	return CRATER_DEPTH

func _draw_realtime_projectiles() -> void:
	for shell: Dictionary in rt_projectiles:
		var owner: int = int(shell.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(shell.get("weapon", WEAPON_STANDARD))
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var radius: float = PROJECTILE_RADIUS * CAMERA_SCALE
		if weapon == WEAPON_HEAVY:
			radius *= 1.45
		elif weapon == WEAPON_CLUSTER_CHILD:
			radius *= 0.75
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
