extends Node2D

@onready var terrain: Line2D = $Terrain
@onready var status_label: Label = $UI/Panel/StatusLabel
@onready var angle_label: Label = $UI/Panel/AngleLabel
@onready var power_label: Label = $UI/Panel/PowerLabel
@onready var power_slider: HSlider = $UI/Panel/PowerSlider
@onready var fire_button: Button = $UI/Panel/FireButton
@onready var reset_button: Button = $UI/Panel/ResetButton
@onready var ui_layer: CanvasLayer = $UI

const VIEW_SIZE: Vector2 = Vector2(900, 540)
const CAMERA_SCALE: float = 0.78
const CAMERA_Y_OFFSET: float = 70.0
const WORLD_WIDTH_MIN: float = 1200.0
const WORLD_WIDTH_MAX: float = 3000.0
const TERRAIN_STEP: float = 10.0
const TERRAIN_MIN_Y: float = 235.0
const TERRAIN_MAX_Y: float = 505.0
const TANK_RADIUS: float = 16.0
const TANK_START_LEFT_X: float = 130.0
const TANK_EDGE_MARGIN: float = 130.0
const TANK_MOVE_SPEED: float = 58.0
const CANNON_LENGTH: float = 48.0
const PROJECTILE_RADIUS: float = 5.0
const EXPLOSION_RADIUS: float = 62.0
const DAMAGE_RADIUS: float = EXPLOSION_RADIUS * 1.20
const DIRECT_HIT_RADIUS: float = 24.0
const DIRECT_HIT_DAMAGE: int = 75
const MAX_SPLASH_DAMAGE: int = 70
const EXPLOSION_DURATION: float = 0.525
const MAX_WIND_ACCEL: float = 85.0
const TURN_TIME_LIMIT: float = 15.0
const POWER_MIN: float = 400.0
const POWER_MAX: float = 1200.0
const POWER_DEFAULT_PERCENT: float = 50.0
const MOBILE_TILT_FULL_SCALE: float = 0.18
const MOBILE_MIN_ANGLE: float = 2.0
const MOBILE_MAX_ANGLE: float = 94.0
const LAKE_CHANCE: float = 0.25
const LAKE_MIN_WIDTH: float = 180.0
const LAKE_MAX_WIDTH: float = 420.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var world_width: float = 1500.0
var terrain_points: Array[Vector2] = []
var terrain_holes: Array[Vector3] = [] # x, y, radius; these make caves/tunnels through the heightfield.
var tank_positions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var tank_health: Array[int] = [100, 100]
var player_angles: Array[float] = [45.0, 45.0]
var player_power_percents: Array[float] = [POWER_DEFAULT_PERCENT, POWER_DEFAULT_PERCENT]

var lake_enabled: bool = false
var lake_x: float = 0.0
var lake_width: float = 0.0
var lake_y: float = 455.0

var current_player: int = 0
var angle_deg: float = 45.0
var power_percent: float = POWER_DEFAULT_PERCENT
var power: float = 800.0
var gravity: float = 520.0
var wind: float = 0.0
var turn_timer: float = TURN_TIME_LIMIT
var projectile_active: bool = false
var projectile_pos: Vector2 = Vector2.ZERO
var projectile_vel: Vector2 = Vector2.ZERO
var explosion_pos: Vector2 = Vector2.INF
var explosion_timer: float = 0.0
var game_over: bool = false
var camera_x: float = 0.0
var overlay_open: bool = false
var end_popup_shown: bool = false
var mobile_left_pressed: bool = false
var mobile_right_pressed: bool = false

var menu_button: Button
var menu_panel: Panel
var end_panel: Panel
var end_label: Label
var mobile_left_button: Button
var mobile_right_button: Button
var mobile_fire_button: Button

func _ready() -> void:
	rng.randomize()
	terrain.visible = false
	fire_button.visible = false
	reset_button.visible = false
	power_slider.min_value = 0.0
	power_slider.max_value = 100.0
	power_slider.step = 1.0
	for c: Control in [power_slider, fire_button, reset_button]:
		c.focus_mode = Control.FOCUS_NONE
	_build_overlay_ui()
	reset_match()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_match()
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
		_on_fire_pressed()
	if not projectile_active and not game_over and not overlay_open:
		_update_angle_from_input(delta)
		_update_tank_movement(delta)
		power_percent = float(power_slider.value)
		power = _power_from_percent(power_percent)
		player_angles[current_player] = angle_deg
		player_power_percents[current_player] = power_percent
		turn_timer -= delta
		if turn_timer <= 0.0:
			_end_turn_without_shot()
	if projectile_active:
		_update_projectile(delta)
	if explosion_timer > 0.0:
		explosion_timer -= delta
		if explosion_timer <= 0.0:
			explosion_pos = Vector2.INF
	_update_camera(delta)
	_update_ui()
	queue_redraw()

func _power_from_percent(percent: float) -> float:
	return lerpf(POWER_MIN, POWER_MAX, clampf(percent, 0.0, 100.0) / 100.0)

func _style_mobile_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = false
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.17, 0.20, 0.82)
	normal.border_color = Color(0.85, 0.90, 1.0, 0.42)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.38, 0.46, 0.58, 0.92)
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("pressed", pressed)
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, Color.WHITE)

func _build_overlay_ui() -> void:
	menu_button = _make_button("☰", Vector2(842, 12), Vector2(44, 38), ui_layer)
	menu_button.pressed.connect(_toggle_menu)
	mobile_left_button = _make_button("◀", Vector2(18, 448), Vector2(78, 72), ui_layer)
	mobile_right_button = _make_button("▶", Vector2(108, 448), Vector2(78, 72), ui_layer)
	mobile_fire_button = _make_button("FIRE", Vector2(382, 462), Vector2(136, 58), ui_layer)
	mobile_left_button.button_down.connect(func() -> void: mobile_left_pressed = true)
	mobile_left_button.button_up.connect(func() -> void: mobile_left_pressed = false; mobile_left_button.release_focus())
	mobile_right_button.button_down.connect(func() -> void: mobile_right_pressed = true)
	mobile_right_button.button_up.connect(func() -> void: mobile_right_pressed = false; mobile_right_button.release_focus())
	mobile_fire_button.pressed.connect(func() -> void: mobile_fire_button.release_focus(); _on_fire_pressed())

	menu_panel = Panel.new()
	menu_panel.visible = false
	menu_panel.position = Vector2(640, 58)
	menu_panel.size = Vector2(230, 145)
	ui_layer.add_child(menu_panel)
	var menu_title: Label = Label.new()
	menu_title.text = "Menu"
	menu_title.position = Vector2(16, 12)
	menu_title.size = Vector2(180, 24)
	menu_panel.add_child(menu_title)
	var rematch: Button = _make_button("Rematch", Vector2(16, 46), Vector2(198, 36), menu_panel)
	var quit: Button = _make_button("Quit", Vector2(16, 92), Vector2(198, 36), menu_panel)
	rematch.pressed.connect(reset_match)
	quit.pressed.connect(_quit_game)

	end_panel = Panel.new()
	end_panel.visible = false
	end_panel.position = Vector2(270, 165)
	end_panel.size = Vector2(360, 190)
	ui_layer.add_child(end_panel)
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.position = Vector2(18, 20)
	end_label.size = Vector2(324, 54)
	end_panel.add_child(end_label)
	var end_rematch: Button = _make_button("Rematch", Vector2(36, 96), Vector2(130, 46), end_panel)
	var end_quit: Button = _make_button("Quit", Vector2(194, 96), Vector2(130, 46), end_panel)
	end_rematch.pressed.connect(reset_match)
	end_quit.pressed.connect(_quit_game)

func _make_button(text: String, pos: Vector2, size: Vector2, parent: Node) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = pos
	button.size = size
	_style_mobile_button(button)
	parent.add_child(button)
	return button

func _toggle_menu() -> void:
	if game_over:
		return
	menu_button.release_focus()
	menu_panel.visible = not menu_panel.visible
	overlay_open = menu_panel.visible

func _hide_overlays() -> void:
	if menu_panel != null:
		menu_panel.visible = false
	if end_panel != null:
		end_panel.visible = false
	overlay_open = false
	end_popup_shown = false

func _quit_game() -> void:
	get_tree().quit()

func _generate_random_terrain() -> void:
	terrain_points.clear()
	terrain_holes.clear()
	world_width = rng.randf_range(WORLD_WIDTH_MIN, WORLD_WIDTH_MAX)
	var right_spawn_x: float = world_width - TANK_EDGE_MARGIN
	var control_spacing: float = rng.randf_range(65.0, 125.0)
	var control_points: Array[Vector2] = []
	var control_count: int = int(ceil(world_width / control_spacing)) + 2
	var previous_y: float = rng.randf_range(360.0, 455.0)
	for i: int in range(control_count):
		var x: float = float(i) * control_spacing
		var y: float = clampf(previous_y + rng.randf_range(-105.0, 105.0), TERRAIN_MIN_Y, TERRAIN_MAX_Y)
		if x < 210.0 or x > world_width - 210.0:
			y = rng.randf_range(385.0, 455.0)
		control_points.append(Vector2(x, y))
		previous_y = y
	for i: int in range(int(world_width / TERRAIN_STEP) + 1):
		var x: float = float(i) * TERRAIN_STEP
		var ci: int = mini(int(floor(x / control_spacing)), control_points.size() - 2)
		var left: Vector2 = control_points[ci]
		var right: Vector2 = control_points[ci + 1]
		var t: float = clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		var y: float = lerpf(left.y, right.y, smooth_t)
		if x > 230.0 and x < world_width - 230.0:
			y += 12.0 * sin(x * 0.035 + rng.randf_range(-0.15, 0.15))
		terrain_points.append(Vector2(x, clampf(y, TERRAIN_MIN_Y, TERRAIN_MAX_Y)))
	_flatten_spawn_area(TANK_START_LEFT_X, 48.0)
	_flatten_spawn_area(right_spawn_x, 48.0)
	_generate_lake()
	_refresh_terrain_line()
	_settle_tanks_on_terrain()

func _generate_lake() -> void:
	lake_enabled = rng.randf() < LAKE_CHANCE
	if not lake_enabled:
		return
	lake_width = rng.randf_range(LAKE_MIN_WIDTH, minf(LAKE_MAX_WIDTH, world_width * 0.28))
	lake_x = rng.randf_range(260.0, maxf(270.0, world_width - 260.0 - lake_width))
	var lowest_y: float = 0.0
	for point: Vector2 in terrain_points:
		if point.x >= lake_x and point.x <= lake_x + lake_width:
			lowest_y = maxf(lowest_y, point.y)
	lake_y = clampf(lowest_y - rng.randf_range(6.0, 18.0), 410.0, 486.0)

func _flatten_spawn_area(center_x: float, half_width: float) -> void:
	var y_sum: float = 0.0
	var count: int = 0
	for point: Vector2 in terrain_points:
		if absf(point.x - center_x) <= half_width:
			y_sum += point.y
			count += 1
	if count <= 0:
		return
	var flat_y: float = y_sum / float(count)
	for i: int in range(terrain_points.size()):
		var point: Vector2 = terrain_points[i]
		var dist: float = absf(point.x - center_x)
		if dist <= half_width:
			point.y = flat_y
		elif dist <= half_width + 40.0:
			point.y = lerpf(flat_y, point.y, (dist - half_width) / 40.0)
		terrain_points[i] = point

func _refresh_terrain_line() -> void:
	terrain.clear_points()
	for point: Vector2 in terrain_points:
		terrain.add_point(point)

func _settle_tanks_on_terrain() -> void:
	for player: int in range(2):
		tank_positions[player].y = _ground_y_at_x(tank_positions[player].x) - TANK_RADIUS

func _ground_y_at_x(x: float) -> float:
	if terrain_points.is_empty():
		return 460.0
	if x <= terrain_points[0].x:
		return terrain_points[0].y
	var last_index: int = terrain_points.size() - 1
	if x >= terrain_points[last_index].x:
		return terrain_points[last_index].y
	var index: int = mini(int(floor(x / TERRAIN_STEP)), last_index - 1)
	var left: Vector2 = terrain_points[index]
	var right: Vector2 = terrain_points[index + 1]
	var t: float = clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
	return lerpf(left.y, right.y, t)

func _is_in_terrain_hole(pos: Vector2) -> bool:
	for hole: Vector3 in terrain_holes:
		var center: Vector2 = Vector2(hole.x, hole.y)
		if pos.distance_to(center) <= hole.z:
			return true
	return false

func _is_in_lake(pos: Vector2) -> bool:
	return lake_enabled and pos.x >= lake_x and pos.x <= lake_x + lake_width and pos.y >= lake_y

func _is_solid_terrain_at(pos: Vector2) -> bool:
	if _is_in_terrain_hole(pos) or _is_in_lake(pos):
		return false
	return pos.y >= _ground_y_at_x(pos.x)

func _update_angle_from_input(delta: float) -> void:
	var gravity_vec: Vector3 = Input.get_gravity()
	if gravity_vec.length() < 0.01:
		if Input.is_key_pressed(KEY_UP):
			angle_deg += 75.0 * delta
		if Input.is_key_pressed(KEY_DOWN):
			angle_deg -= 75.0 * delta
	else:
		var roll: float = clampf(gravity_vec.x / 9.8, -MOBILE_TILT_FULL_SCALE, MOBILE_TILT_FULL_SCALE)
		var aiming_roll: float = -roll if current_player == 0 else roll
		var normalized_roll: float = (aiming_roll / MOBILE_TILT_FULL_SCALE + 1.0) * 0.5
		angle_deg = lerpf(MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE, normalized_roll)
	angle_deg = clampf(angle_deg, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)

func _update_tank_movement(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0
	if direction == 0.0:
		return
	var new_x: float = clampf(tank_positions[current_player].x + direction * TANK_MOVE_SPEED * delta, 45.0, world_width - 45.0)
	var other_player: int = 1 - current_player
	if absf(new_x - tank_positions[other_player].x) < 90.0:
		return
	tank_positions[current_player].x = new_x
	tank_positions[current_player].y = _ground_y_at_x(new_x) - TANK_RADIUS

func _on_fire_pressed() -> void:
	if projectile_active or game_over or overlay_open:
		return
	power_slider.release_focus()
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
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
	var enemy: int = 1 - current_player
	if projectile_pos.distance_to(tank_positions[enemy]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		_explode(projectile_pos, true)
		return
	if _is_in_lake(projectile_pos):
		_explode(projectile_pos, false)
		return
	if _is_solid_terrain_at(projectile_pos):
		_explode(projectile_pos, true)
		return
	if projectile_pos.x < -100.0 or projectile_pos.x > world_width + 100.0 or projectile_pos.y > VIEW_SIZE.y + 160.0:
		_explode(projectile_pos, false)

func _explode(pos: Vector2, carve_terrain: bool = true) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = EXPLOSION_DURATION
	if carve_terrain:
		_apply_crater(pos)
	_apply_explosion_damage(pos)
	_settle_tanks_on_terrain()
	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
		_show_end_popup()
	else:
		_advance_turn()

func _apply_explosion_damage(pos: Vector2) -> void:
	for player: int in range(2):
		var dist: float = pos.distance_to(tank_positions[player])
		if dist <= DIRECT_HIT_RADIUS:
			tank_health[player] = maxi(0, tank_health[player] - DIRECT_HIT_DAMAGE)
		elif dist <= DAMAGE_RADIUS:
			var normalized: float = (dist - DIRECT_HIT_RADIUS) / (DAMAGE_RADIUS - DIRECT_HIT_RADIUS)
			var damage: int = maxi(6, int(round(float(MAX_SPLASH_DAMAGE) * pow(1.0 - normalized, 1.35))))
			tank_health[player] = maxi(0, tank_health[player] - damage)

func _apply_crater(pos: Vector2) -> void:
	terrain_holes.append(Vector3(pos.x, pos.y, DAMAGE_RADIUS))

func _advance_turn() -> void:
	current_player = 1 - current_player
	_load_current_player_settings()
	turn_timer = TURN_TIME_LIMIT
	mobile_left_pressed = false
	mobile_right_pressed = false
	mobile_left_button.release_focus()
	mobile_right_button.release_focus()

func _end_turn_without_shot() -> void:
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	_advance_turn()

func _load_current_player_settings() -> void:
	angle_deg = player_angles[current_player]
	power_percent = player_power_percents[current_player]
	power = _power_from_percent(power_percent)
	power_slider.value = power_percent
	power_slider.release_focus()

func reset_match() -> void:
	_hide_overlays()
	current_player = 0
	player_angles = [45.0, 45.0]
	player_power_percents = [POWER_DEFAULT_PERCENT, POWER_DEFAULT_PERCENT]
	angle_deg = 45.0
	power_percent = POWER_DEFAULT_PERCENT
	power = _power_from_percent(power_percent)
	power_slider.value = power_percent
	power_slider.release_focus()
	turn_timer = TURN_TIME_LIMIT
	wind = rng.randf_range(-MAX_WIND_ACCEL, MAX_WIND_ACCEL)
	tank_health = [100, 100]
	projectile_active = false
	projectile_pos = Vector2.ZERO
	projectile_vel = Vector2.ZERO
	explosion_pos = Vector2.INF
	explosion_timer = 0.0
	game_over = false
	mobile_left_pressed = false
	mobile_right_pressed = false
	world_width = rng.randf_range(WORLD_WIDTH_MIN, WORLD_WIDTH_MAX)
	tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(world_width - TANK_EDGE_MARGIN, 0.0)]
	_generate_random_terrain()
	camera_x = _camera_target_x()

func _show_end_popup() -> void:
	if end_popup_shown:
		return
	var winner: int = 1 if tank_health[0] <= 0 else 0
	end_label.text = "Player %d wins!\nP1 HP: %d    P2 HP: %d" % [winner + 1, tank_health[0], tank_health[1]]
	end_panel.visible = true
	overlay_open = true
	end_popup_shown = true

func _update_camera(delta: float) -> void:
	camera_x = lerpf(camera_x, _camera_target_x(), clampf(delta * 4.0, 0.0, 1.0))

func _camera_target_x() -> float:
	var focus_x: float = tank_positions[current_player].x
	if projectile_active:
		focus_x = projectile_pos.x
	elif explosion_timer > 0.0 and explosion_pos != Vector2.INF:
		focus_x = explosion_pos.x
	var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
	return clampf(focus_x - camera_world_width * 0.5, 0.0, maxf(0.0, world_width - camera_world_width))

func _world_to_screen(world_point: Vector2) -> Vector2:
	return Vector2((world_point.x - camera_x) * CAMERA_SCALE, world_point.y * CAMERA_SCALE + CAMERA_Y_OFFSET)

func _update_ui() -> void:
	angle_label.text = "Angle: %.1f" % angle_deg
	power_label.text = "Power: %.0f%%" % power_percent
	if game_over:
		var winner: int = 1 if tank_health[0] <= 0 else 0
		status_label.text = "Player %d wins!  P1 HP: %d  P2 HP: %d" % [winner + 1, tank_health[0], tank_health[1]]
	else:
		status_label.text = "P1 HP: %d    P2 HP: %d" % [tank_health[0], tank_health[1]]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
	_draw_distant_mountains()
	_draw_ground_fill()
	_draw_lake()
	_draw_terrain_holes()
	_draw_terrain_outline()
	_draw_tank(0, Color(0.25, 0.9, 0.35))
	_draw_tank(1, Color(0.95, 0.25, 0.25))
	if not game_over:
		var base: Vector2 = _world_to_screen(tank_positions[current_player])
		var facing: float = 1.0 if current_player == 0 else -1.0
		var rad: float = deg_to_rad(angle_deg)
		var tip: Vector2 = base + Vector2(facing * CANNON_LENGTH * CAMERA_SCALE * cos(rad), -CANNON_LENGTH * CAMERA_SCALE * sin(rad))
		draw_line(base, tip, Color.WHITE, 4.0)
	if projectile_active:
		draw_circle(_world_to_screen(projectile_pos), PROJECTILE_RADIUS * CAMERA_SCALE, Color(1.0, 0.92, 0.2))
	if explosion_timer > 0.0 and explosion_pos != Vector2.INF:
		_draw_explosion()
	_draw_wind_widget()
	_draw_turn_widget()

func _draw_distant_mountains() -> void:
	var offset: float = camera_x * 0.18
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-60.0, VIEW_SIZE.y))
	for i: int in range(9):
		points.append(Vector2(float(i) * 150.0 - fmod(offset, 150.0) - 60.0, 350.0 + 55.0 * sin(float(i) * 1.7)))
	points.append(Vector2(VIEW_SIZE.x + 60.0, VIEW_SIZE.y))
	draw_colored_polygon(points, Color(0.08, 0.10, 0.13))

func _draw_ground_fill() -> void:
	if terrain_points.is_empty():
		return
	var polygon: PackedVector2Array = PackedVector2Array([Vector2(0.0, VIEW_SIZE.y + 100.0)])
	for point: Vector2 in terrain_points:
		var sp: Vector2 = _world_to_screen(point)
		if sp.x >= -25.0 and sp.x <= VIEW_SIZE.x + 25.0:
			polygon.append(sp)
	polygon.append(Vector2(VIEW_SIZE.x, VIEW_SIZE.y + 100.0))
	if polygon.size() >= 3:
		draw_colored_polygon(polygon, Color(0.13, 0.24, 0.12))

func _draw_lake() -> void:
	if not lake_enabled:
		return
	var left: Vector2 = _world_to_screen(Vector2(lake_x, lake_y))
	var right: Vector2 = _world_to_screen(Vector2(lake_x + lake_width, lake_y))
	var rect: Rect2 = Rect2(Vector2(left.x, left.y), Vector2(right.x - left.x, VIEW_SIZE.y - left.y + 40.0))
	draw_rect(rect, Color(0.04, 0.22, 0.42, 0.86), true)
	draw_line(Vector2(left.x, left.y), Vector2(right.x, right.y), Color(0.18, 0.62, 0.95, 0.95), 3.0)

func _draw_terrain_holes() -> void:
	for hole: Vector3 in terrain_holes:
		var center: Vector2 = _world_to_screen(Vector2(hole.x, hole.y))
		var radius: float = hole.z * CAMERA_SCALE
		draw_circle(center, radius, Color(0.06, 0.07, 0.10))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.23, 0.18, 0.12), 3.0)

func _draw_terrain_outline() -> void:
	var visible_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in terrain_points:
		var sp: Vector2 = _world_to_screen(point)
		if sp.x >= -25.0 and sp.x <= VIEW_SIZE.x + 25.0:
			visible_points.append(sp)
	if visible_points.size() >= 2:
		draw_polyline(visible_points, Color(0.28, 0.82, 0.35), 3.0)

func _draw_explosion() -> void:
	var elapsed: float = 1.0 - explosion_timer / EXPLOSION_DURATION
	var center: Vector2 = _world_to_screen(explosion_pos)
	var outer: float = EXPLOSION_RADIUS * CAMERA_SCALE * (0.55 + 0.65 * elapsed)
	draw_circle(center, outer, Color(1.0, 0.42, 0.06, 0.42 * (1.0 - elapsed)))
	draw_circle(center, outer * 0.48, Color(1.0, 0.88, 0.20, 0.75 * (1.0 - elapsed)))
	for i: int in range(8):
		var a: float = TAU * float(i) / 8.0
		draw_line(center, center + Vector2(cos(a), sin(a)) * outer * 1.15, Color(1.0, 0.75, 0.15, 0.45 * (1.0 - elapsed)), 2.0)

func _draw_wind_widget() -> void:
	var box: Rect2 = Rect2(Vector2(18, 132), Vector2(142, 42))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.58), true)
	draw_rect(box, Color(0.85, 0.90, 1.0, 0.30), false, 1.0)
	var arrow_start: Vector2 = Vector2(34, 153)
	var arrow_end: Vector2 = Vector2(82, 153)
	if wind < 0.0:
		arrow_start = Vector2(82, 153)
		arrow_end = Vector2(34, 153)
	draw_line(arrow_start, arrow_end, Color(0.78, 0.90, 1.0), 3.0)
	draw_line(arrow_end, arrow_end + Vector2(-8 if wind > 0.0 else 8, -6), Color(0.78, 0.90, 1.0), 3.0)
	draw_line(arrow_end, arrow_end + Vector2(-8 if wind > 0.0 else 8, 6), Color(0.78, 0.90, 1.0), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(96, 160), "%.1f" % (absf(wind) / MAX_WIND_ACCEL * 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func _draw_turn_widget() -> void:
	if game_over:
		return
	var box: Rect2 = Rect2(Vector2(VIEW_SIZE.x - 178.0, VIEW_SIZE.y - 70.0), Vector2(158.0, 48.0))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.64), true)
	draw_rect(box, Color(1.0, 1.0, 1.0, 0.30), false, 1.0)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(18.0, 31.0), "P%d  %02ds" % [current_player + 1, int(ceil(turn_timer))], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

func _draw_tank(index: int, color: Color) -> void:
	var pos: Vector2 = _world_to_screen(tank_positions[index])
	var facing: float = 1.0 if index == 0 else -1.0
	var s: float = CAMERA_SCALE
	var tread: PackedVector2Array = PackedVector2Array([pos + Vector2(-25, 8) * s, pos + Vector2(25, 8) * s, pos + Vector2(30, 16) * s, pos + Vector2(22, 22) * s, pos + Vector2(-22, 22) * s, pos + Vector2(-30, 16) * s])
	draw_colored_polygon(tread, Color(color.r * 0.45, color.g * 0.45, color.b * 0.45))
	draw_line(pos + Vector2(-24, 15) * s, pos + Vector2(24, 15) * s, Color.BLACK, 3.0)
	var body: PackedVector2Array = PackedVector2Array([pos + Vector2(-22, 5) * s, pos + Vector2(22, 5) * s, pos + Vector2(16, -10) * s, pos + Vector2(-16, -10) * s])
	draw_colored_polygon(body, color)
	draw_circle(pos + Vector2(0, -13) * s, 12.0 * s, color)
	if index != current_player:
		draw_line(pos + Vector2(facing * 6.0, -15.0) * s, pos + Vector2(facing * 38.0, -21.0) * s, Color.WHITE, 3.0)
	for wheel_x: float in [-18.0, 0.0, 18.0]:
		draw_circle(pos + Vector2(wheel_x, 16) * s, 4.0 * s, Color.BLACK)
