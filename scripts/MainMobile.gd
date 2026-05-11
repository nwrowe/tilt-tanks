extends Node2D

@onready var terrain: Line2D = $Terrain
@onready var status_label: Label = $UI/Panel/StatusLabel
@onready var angle_label: Label = $UI/Panel/AngleLabel
@onready var power_label: Label = $UI/Panel/PowerLabel
@onready var power_slider: HSlider = $UI/Panel/PowerSlider
@onready var fire_button: Button = $UI/Panel/FireButton
@onready var reset_button: Button = $UI/Panel/ResetButton
@onready var ui_layer: CanvasLayer = $UI

const VIEW_SIZE := Vector2(900, 540)
const CAMERA_SCALE := 0.78
const CAMERA_Y_OFFSET := 70.0
const WORLD_WIDTH := 1500.0
const TERRAIN_STEP := 10.0
const TERRAIN_MIN_Y := 255.0
const TERRAIN_MAX_Y := 500.0
const TANK_RADIUS := 16.0
const TANK_START_LEFT_X := 130.0
const TANK_START_RIGHT_X := WORLD_WIDTH - 130.0
const TANK_MOVE_SPEED := 58.0
const CANNON_LENGTH := 48.0
const PROJECTILE_RADIUS := 5.0
const EXPLOSION_RADIUS := 62.0
const DIRECT_HIT_RADIUS := 24.0
const DIRECT_HIT_DAMAGE := 75
const MAX_SPLASH_DAMAGE := 70
const CRATER_RADIUS := 58.0
const CRATER_DEPTH := 48.0
const EXPLOSION_DURATION := 0.525
const MAX_WIND_ACCEL := 85.0
const TURN_TIME_LIMIT := 15.0
const POWER_MIN := 400.0
const POWER_MAX := 1200.0
const POWER_DEFAULT_PERCENT := 50.0
const MOBILE_TILT_FULL_SCALE := 0.18
const MOBILE_MIN_ANGLE := 2.0
const MOBILE_MAX_ANGLE := 94.0

var rng := RandomNumberGenerator.new()
var terrain_points: Array[Vector2] = []
var tank_positions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var tank_health: Array[int] = [100, 100]
var player_angles: Array[float] = [45.0, 45.0]
var player_power_percents: Array[float] = [POWER_DEFAULT_PERCENT, POWER_DEFAULT_PERCENT]

var current_player := 0
var angle_deg := 45.0
var power_percent := POWER_DEFAULT_PERCENT
var power := 800.0
var gravity := 520.0
var wind := 0.0
var turn_timer := TURN_TIME_LIMIT
var projectile_active := false
var projectile_pos := Vector2.ZERO
var projectile_vel := Vector2.ZERO
var explosion_pos := Vector2.INF
var explosion_timer := 0.0
var game_over := false
var camera_x := 0.0
var overlay_open := false
var end_popup_shown := false
var mobile_left_pressed := false
var mobile_right_pressed := false

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
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.17, 0.20, 0.82)
	normal.border_color = Color(0.85, 0.90, 1.0, 0.42)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.38, 0.46, 0.58, 0.92)
	for state in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("pressed", pressed)
	for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
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
	var menu_title := Label.new()
	menu_title.text = "Menu"
	menu_title.position = Vector2(16, 12)
	menu_title.size = Vector2(180, 24)
	menu_panel.add_child(menu_title)
	var rematch := _make_button("Rematch", Vector2(16, 46), Vector2(198, 36), menu_panel)
	var quit := _make_button("Quit", Vector2(16, 92), Vector2(198, 36), menu_panel)
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
	var end_rematch := _make_button("Rematch", Vector2(36, 96), Vector2(130, 46), end_panel)
	var end_quit := _make_button("Quit", Vector2(194, 96), Vector2(130, 46), end_panel)
	end_rematch.pressed.connect(reset_match)
	end_quit.pressed.connect(_quit_game)

func _make_button(text: String, pos: Vector2, size: Vector2, parent: Node) -> Button:
	var button := Button.new()
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
	var control_spacing := rng.randf_range(65.0, 115.0)
	var control_points: Array[Vector2] = []
	var control_count := int(ceil(WORLD_WIDTH / control_spacing)) + 2
	var previous_y := rng.randf_range(360.0, 455.0)
	for i in range(control_count):
		var x := float(i) * control_spacing
		var y := clampf(previous_y + rng.randf_range(-95.0, 95.0), TERRAIN_MIN_Y, TERRAIN_MAX_Y)
		if x < 210.0 or x > WORLD_WIDTH - 210.0:
			y = rng.randf_range(385.0, 455.0)
		control_points.append(Vector2(x, y))
		previous_y = y
	for i in range(int(WORLD_WIDTH / TERRAIN_STEP) + 1):
		var x := float(i) * TERRAIN_STEP
		var ci := mini(int(floor(x / control_spacing)), control_points.size() - 2)
		var left := control_points[ci]
		var right := control_points[ci + 1]
		var t := clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
		var smooth_t := t * t * (3.0 - 2.0 * t)
		var y := lerpf(left.y, right.y, smooth_t)
		if x > 230.0 and x < WORLD_WIDTH - 230.0:
			y += 10.0 * sin(x * 0.035 + rng.randf_range(-0.15, 0.15))
		terrain_points.append(Vector2(x, clampf(y, TERRAIN_MIN_Y, TERRAIN_MAX_Y)))
	_flatten_spawn_area(TANK_START_LEFT_X, 48.0)
	_flatten_spawn_area(TANK_START_RIGHT_X, 48.0)
	_refresh_terrain_line()
	_settle_tanks_on_terrain()

func _flatten_spawn_area(center_x: float, half_width: float) -> void:
	var y_sum := 0.0
	var count := 0
	for point in terrain_points:
		if absf(point.x - center_x) <= half_width:
			y_sum += point.y
			count += 1
	if count <= 0:
		return
	var flat_y := y_sum / float(count)
	for i in range(terrain_points.size()):
		var point := terrain_points[i]
		var dist := absf(point.x - center_x)
		if dist <= half_width:
			point.y = flat_y
		elif dist <= half_width + 40.0:
			point.y = lerpf(flat_y, point.y, (dist - half_width) / 40.0)
		terrain_points[i] = point

func _refresh_terrain_line() -> void:
	terrain.clear_points()
	for point in terrain_points:
		terrain.add_point(point)

func _settle_tanks_on_terrain() -> void:
	for player in range(2):
		tank_positions[player].y = _ground_y_at_x(tank_positions[player].x) - TANK_RADIUS

func _ground_y_at_x(x: float) -> float:
	if terrain_points.is_empty():
		return 460.0
	if x <= terrain_points[0].x:
		return terrain_points[0].y
	var last_index := terrain_points.size() - 1
	if x >= terrain_points[last_index].x:
		return terrain_points[last_index].y
	var index := mini(int(floor(x / TERRAIN_STEP)), last_index - 1)
	var left := terrain_points[index]
	var right := terrain_points[index + 1]
	var t := clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
	return lerpf(left.y, right.y, t)

func _update_angle_from_input(delta: float) -> void:
	var gravity_vec := Input.get_gravity()
	if gravity_vec.length() < 0.01:
		if Input.is_key_pressed(KEY_UP):
			angle_deg += 75.0 * delta
		if Input.is_key_pressed(KEY_DOWN):
			angle_deg -= 75.0 * delta
	else:
		var roll := clampf(gravity_vec.x / 9.8, -MOBILE_TILT_FULL_SCALE, MOBILE_TILT_FULL_SCALE)
		var aiming_roll := -roll if current_player == 0 else roll
		var normalized_roll := (aiming_roll / MOBILE_TILT_FULL_SCALE + 1.0) * 0.5
		angle_deg = lerpf(MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE, normalized_roll)
	angle_deg = clampf(angle_deg, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)

func _update_tank_movement(delta: float) -> void:
	var direction := 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0
	if direction == 0.0:
		return
	var new_x := clampf(tank_positions[current_player].x + direction * TANK_MOVE_SPEED * delta, 45.0, WORLD_WIDTH - 45.0)
	var other_player := 1 - current_player
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
	var facing := 1.0 if current_player == 0 else -1.0
	var rad := deg_to_rad(angle_deg)
	var muzzle_offset := Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	projectile_pos = tank_positions[current_player] + muzzle_offset
	projectile_vel = Vector2(facing * power * cos(rad), -power * sin(rad))
	projectile_active = true

func _update_projectile(delta: float) -> void:
	projectile_vel.y += gravity * delta
	projectile_vel.x += wind * delta
	projectile_pos += projectile_vel * delta
	var enemy := 1 - current_player
	if projectile_pos.distance_to(tank_positions[enemy]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		_explode(projectile_pos)
		return
	var ground_y := _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		_explode(Vector2(projectile_pos.x, ground_y))
		return
	if projectile_pos.x < -100.0 or projectile_pos.x > WORLD_WIDTH + 100.0 or projectile_pos.y > VIEW_SIZE.y + 160.0:
		_explode(projectile_pos)

func _explode(pos: Vector2) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = EXPLOSION_DURATION
	_apply_crater(pos)
	_apply_explosion_damage(pos)
	_settle_tanks_on_terrain()
	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
		_show_end_popup()
	else:
		_advance_turn()

func _apply_explosion_damage(pos: Vector2) -> void:
	for player in range(2):
		var dist := pos.distance_to(tank_positions[player])
		if dist <= DIRECT_HIT_RADIUS:
			tank_health[player] = maxi(0, tank_health[player] - DIRECT_HIT_DAMAGE)
		elif dist <= EXPLOSION_RADIUS:
			var normalized := (dist - DIRECT_HIT_RADIUS) / (EXPLOSION_RADIUS - DIRECT_HIT_RADIUS)
			var damage := maxi(6, int(round(float(MAX_SPLASH_DAMAGE) * pow(1.0 - normalized, 1.35))))
			tank_health[player] = maxi(0, tank_health[player] - damage)

func _apply_crater(pos: Vector2) -> void:
	for i in range(terrain_points.size()):
		var point := terrain_points[i]
		var dx := point.x - pos.x
		if absf(dx) <= CRATER_RADIUS:
			var nx := dx / CRATER_RADIUS
			var bowl := sqrt(maxf(0.0, 1.0 - nx * nx))
			var target_y := pos.y + CRATER_DEPTH * bowl
			point.y = clampf(maxf(point.y, target_y), TERRAIN_MIN_Y, VIEW_SIZE.y + 80.0)
			terrain_points[i] = point
	_refresh_terrain_line()

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
	tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(TANK_START_RIGHT_X, 0.0)]
	projectile_active = false
	projectile_pos = Vector2.ZERO
	projectile_vel = Vector2.ZERO
	explosion_pos = Vector2.INF
	explosion_timer = 0.0
	game_over = false
	mobile_left_pressed = false
	mobile_right_pressed = false
	_generate_random_terrain()
	camera_x = _camera_target_x()

func _show_end_popup() -> void:
	if end_popup_shown:
		return
	var winner := 1 if tank_health[0] <= 0 else 0
	end_label.text = "Player %d wins!\nP1 HP: %d    P2 HP: %d" % [winner + 1, tank_health[0], tank_health[1]]
	end_panel.visible = true
	overlay_open = true
	end_popup_shown = true

func _update_camera(delta: float) -> void:
	camera_x = lerpf(camera_x, _camera_target_x(), clampf(delta * 4.0, 0.0, 1.0))

func _camera_target_x() -> float:
	var focus_x := tank_positions[current_player].x
	if projectile_active:
		focus_x = projectile_pos.x
	elif explosion_timer > 0.0 and explosion_pos != Vector2.INF:
		focus_x = explosion_pos.x
	var camera_world_width := VIEW_SIZE.x / CAMERA_SCALE
	return clampf(focus_x - camera_world_width * 0.5, 0.0, WORLD_WIDTH - camera_world_width)

func _world_to_screen(world_point: Vector2) -> Vector2:
	return Vector2((world_point.x - camera_x) * CAMERA_SCALE, world_point.y * CAMERA_SCALE + CAMERA_Y_OFFSET)

func _update_ui() -> void:
	angle_label.text = "Angle: %.1f" % angle_deg
	power_label.text = "Power: %.0f%%" % power_percent
	if game_over:
		var winner := 1 if tank_health[0] <= 0 else 0
		status_label.text = "Player %d wins!  P1 HP: %d  P2 HP: %d" % [winner + 1, tank_health[0], tank_health[1]]
	else:
		status_label.text = "P1 HP: %d    P2 HP: %d" % [tank_health[0], tank_health[1]]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
	_draw_distant_mountains()
	_draw_ground_fill()
	_draw_terrain_outline()
	_draw_tank(0, Color(0.25, 0.9, 0.35))
	_draw_tank(1, Color(0.95, 0.25, 0.25))
	var base := _world_to_screen(tank_positions[current_player])
	var facing := 1.0 if current_player == 0 else -1.0
	var rad := deg_to_rad(angle_deg)
	var tip := base + Vector2(facing * CANNON_LENGTH * CAMERA_SCALE * cos(rad), -CANNON_LENGTH * CAMERA_SCALE * sin(rad))
	draw_line(base, tip, Color.WHITE, 4.0)
	if projectile_active:
		draw_circle(_world_to_screen(projectile_pos), PROJECTILE_RADIUS * CAMERA_SCALE, Color(1.0, 0.92, 0.2))
	if explosion_timer > 0.0 and explosion_pos != Vector2.INF:
		_draw_explosion()
	_draw_wind_widget()
	_draw_turn_widget()

func _draw_distant_mountains() -> void:
	var offset := camera_x * 0.18
	var points := PackedVector2Array()
	points.append(Vector2(-60.0, VIEW_SIZE.y))
	for i in range(9):
		points.append(Vector2(float(i) * 150.0 - fmod(offset, 150.0) - 60.0, 350.0 + 55.0 * sin(float(i) * 1.7)))
	points.append(Vector2(VIEW_SIZE.x + 60.0, VIEW_SIZE.y))
	draw_colored_polygon(points, Color(0.08, 0.10, 0.13))

func _draw_ground_fill() -> void:
	if terrain_points.is_empty(): return
	var polygon := PackedVector2Array([Vector2(0.0, VIEW_SIZE.y + 100.0)])
	for point in terrain_points:
		var sp := _world_to_screen(point)
		if sp.x >= -25.0 and sp.x <= VIEW_SIZE.x + 25.0:
			polygon.append(sp)
	polygon.append(Vector2(VIEW_SIZE.x, VIEW_SIZE.y + 100.0))
	if polygon.size() >= 3:
		draw_colored_polygon(polygon, Color(0.13, 0.24, 0.12))

func _draw_terrain_outline() -> void:
	var visible_points := PackedVector2Array()
	for point in terrain_points:
		var sp := _world_to_screen(point)
		if sp.x >= -25.0 and sp.x <= VIEW_SIZE.x + 25.0:
			visible_points.append(sp)
	if visible_points.size() >= 2:
		draw_polyline(visible_points, Color(0.28, 0.82, 0.35), 3.0)

func _draw_explosion() -> void:
	var elapsed := 1.0 - explosion_timer / EXPLOSION_DURATION
	var center := _world_to_screen(explosion_pos)
	var outer := EXPLOSION_RADIUS * CAMERA_SCALE * (0.55 + 0.65 * elapsed)
	draw_circle(center, outer, Color(1.0, 0.42, 0.06, 0.42 * (1.0 - elapsed)))
	draw_circle(center, outer * 0.48, Color(1.0, 0.88, 0.20, 0.75 * (1.0 - elapsed)))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		draw_line(center, center + Vector2(cos(a), sin(a)) * outer * 1.15, Color(1.0, 0.75, 0.15, 0.45 * (1.0 - elapsed)), 2.0)

func _draw_wind_widget() -> void:
	var box := Rect2(Vector2(18, 132), Vector2(122, 42))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.58), true)
	draw_rect(box, Color(0.85, 0.90, 1.0, 0.30), false, 1.0)
	var arrow_start := Vector2(38, 153)
	var arrow_end := Vector2(92, 153)
	if wind < 0.0:
		arrow_start = Vector2(92, 153)
		arrow_end = Vector2(38, 153)
	draw_line(arrow_start, arrow_end, Color(0.78, 0.90, 1.0), 3.0)
	draw_line(arrow_end, arrow_end + Vector2(-8 if wind > 0.0 else 8, -6), Color(0.78, 0.90, 1.0), 3.0)
	draw_line(arrow_end, arrow_end + Vector2(-8 if wind > 0.0 else 8, 6), Color(0.78, 0.90, 1.0), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 169), "%.1f" % (absf(wind) / MAX_WIND_ACCEL * 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func _draw_turn_widget() -> void:
	if game_over: return
	var box := Rect2(Vector2(VIEW_SIZE.x - 178.0, VIEW_SIZE.y - 70.0), Vector2(158.0, 48.0))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.64), true)
	draw_rect(box, Color(1.0, 1.0, 1.0, 0.30), false, 1.0)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(18.0, 31.0), "P%d  %02ds" % [current_player + 1, int(ceil(turn_timer))], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

func _draw_tank(index: int, color: Color) -> void:
	var pos := _world_to_screen(tank_positions[index])
	var facing := 1.0 if index == 0 else -1.0
	var s := CAMERA_SCALE
	var tread := PackedVector2Array([pos + Vector2(-25, 8) * s, pos + Vector2(25, 8) * s, pos + Vector2(30, 16) * s, pos + Vector2(22, 22) * s, pos + Vector2(-22, 22) * s, pos + Vector2(-30, 16) * s])
	draw_colored_polygon(tread, Color(color.r * 0.45, color.g * 0.45, color.b * 0.45))
	draw_line(pos + Vector2(-24, 15) * s, pos + Vector2(24, 15) * s, Color.BLACK, 3.0)
	var body := PackedVector2Array([pos + Vector2(-22, 5) * s, pos + Vector2(22, 5) * s, pos + Vector2(16, -10) * s, pos + Vector2(-16, -10) * s])
	draw_colored_polygon(body, color)
	draw_circle(pos + Vector2(0, -13) * s, 12.0 * s, color)
	if index != current_player or game_over:
		draw_line(pos + Vector2(facing * 6.0, -15.0) * s, pos + Vector2(facing * 38.0, -21.0) * s, Color.WHITE, 3.0)
	for wheel_x in [-18.0, 0.0, 18.0]:
		draw_circle(pos + Vector2(wheel_x, 16) * s, 4.0 * s, Color.BLACK)
