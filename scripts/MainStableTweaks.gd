extends "res://scripts/MainStablePowerPercent.gd"

const WORLD_WIDTH_MIN_TWEAK: float = 1500.0
const WORLD_WIDTH_MAX_TWEAK: float = 2600.0
const TRAJECTORY_DOT_COUNT: int = 7
const TRAJECTORY_DOT_DT: float = 0.145
const TRAJECTORY_DOT_RADIUS: float = 3.0
const BOTTOM_FLOOR_SCREEN_MARGIN: float = 4.0

var active_world_width: float = 1500.0
var active_right_start_x: float = 1370.0

func _bottom_floor_y() -> float:
	return (VIEW_SIZE.y - CAMERA_Y_OFFSET) / CAMERA_SCALE - BOTTOM_FLOOR_SCREEN_MARGIN

func _generate_random_terrain() -> void:
	terrain_points.clear()
	active_world_width = rng.randf_range(WORLD_WIDTH_MIN_TWEAK, WORLD_WIDTH_MAX_TWEAK)
	active_right_start_x = active_world_width - 130.0
	var floor_y: float = _bottom_floor_y()
	var control_spacing: float = rng.randf_range(65.0, 115.0)
	var control_points: Array[Vector2] = []
	var control_count: int = int(ceil(active_world_width / control_spacing)) + 2
	var previous_y: float = rng.randf_range(360.0, 455.0)
	for i: int in range(control_count):
		var x: float = float(i) * control_spacing
		var slope_kick: float = rng.randf_range(-95.0, 95.0)
		var y: float = clampf(previous_y + slope_kick, TERRAIN_MIN_Y, minf(TERRAIN_MAX_Y, floor_y))
		if x < 210.0 or x > active_world_width - 210.0:
			y = rng.randf_range(385.0, minf(455.0, floor_y))
		control_points.append(Vector2(x, y))
		previous_y = y
	var point_count: int = int(active_world_width / TERRAIN_STEP) + 1
	for i: int in range(point_count):
		var x: float = float(i) * TERRAIN_STEP
		var control_index: int = mini(int(floor(x / control_spacing)), control_points.size() - 2)
		var left: Vector2 = control_points[control_index]
		var right: Vector2 = control_points[control_index + 1]
		var t: float = clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		var y: float = lerpf(left.y, right.y, smooth_t)
		if x > 230.0 and x < active_world_width - 230.0:
			y += 10.0 * sin(x * 0.035 + rng.randf_range(-0.15, 0.15))
		terrain_points.append(Vector2(x, clampf(y, TERRAIN_MIN_Y, floor_y)))
	_flatten_spawn_area(TANK_START_LEFT_X, 48.0)
	_flatten_spawn_area(active_right_start_x, 48.0)
	_refresh_terrain_line()
	_settle_tanks_on_terrain()

func reset_match() -> void:
	_hide_overlays()
	current_player = 0
	player_angles = [45.0, 45.0]
	player_power_percents = [POWER_PERCENT_DEFAULT, POWER_PERCENT_DEFAULT]
	player_powers = [_power_from_percent(POWER_PERCENT_DEFAULT), _power_from_percent(POWER_PERCENT_DEFAULT)]
	angle_deg = 45.0
	power_percent = POWER_PERCENT_DEFAULT
	power = _power_from_percent(power_percent)
	power_slider.value = power_percent
	power_slider.release_focus()
	turn_timer = TURN_TIME_LIMIT
	wind = rng.randf_range(-MAX_WIND_ACCEL, MAX_WIND_ACCEL)
	tank_health = [100, 100]
	active_world_width = rng.randf_range(WORLD_WIDTH_MIN_TWEAK, WORLD_WIDTH_MAX_TWEAK)
	active_right_start_x = active_world_width - 130.0
	tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(active_right_start_x, 0.0)]
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
	var new_x: float = clampf(tank_positions[current_player].x + direction * TANK_MOVE_SPEED * delta, 45.0, active_world_width - 45.0)
	var other_player: int = 1 - current_player
	if absf(new_x - tank_positions[other_player].x) < 90.0:
		return
	tank_positions[current_player].x = new_x
	tank_positions[current_player].y = _ground_y_at_x(new_x) - TANK_RADIUS

func _update_projectile(delta: float) -> void:
	projectile_vel.y += gravity * delta
	projectile_vel.x += wind * delta
	projectile_pos += projectile_vel * delta
	var enemy: int = 1 - current_player
	if projectile_pos.distance_to(tank_positions[enemy]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		_explode(projectile_pos)
		return
	var ground_y: float = _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		_explode(Vector2(projectile_pos.x, ground_y))
		return
	if projectile_pos.x < -100.0 or projectile_pos.x > active_world_width + 100.0 or projectile_pos.y > _bottom_floor_y() + 180.0:
		_explode(projectile_pos)

func _apply_crater(pos: Vector2) -> void:
	var floor_y: float = _bottom_floor_y()
	for i: int in range(terrain_points.size()):
		var point: Vector2 = terrain_points[i]
		var dx: float = point.x - pos.x
		if absf(dx) <= CRATER_RADIUS:
			var normalized_x: float = dx / CRATER_RADIUS
			var bowl: float = sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
			var target_y: float = pos.y + CRATER_DEPTH * bowl
			point.y = clampf(maxf(point.y, target_y), TERRAIN_MIN_Y, floor_y)
			terrain_points[i] = point
	_refresh_terrain_line()

func _camera_target_x() -> float:
	var focus_x: float = tank_positions[current_player].x
	if projectile_active:
		focus_x = projectile_pos.x
	elif explosion_timer > 0.0 and explosion_pos != Vector2.INF:
		focus_x = explosion_pos.x
	var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
	return clampf(focus_x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
	_draw_distant_mountains()
	_draw_ground_fill()
	_draw_terrain_outline()
	_draw_tank(0, Color(0.25, 0.9, 0.35))
	_draw_tank(1, Color(0.95, 0.25, 0.25))
	if not game_over:
		_draw_trajectory_preview()
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

func _draw_trajectory_preview() -> void:
	if projectile_active or game_over:
		return
	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var pos: Vector2 = tank_positions[current_player] + muzzle_offset
	var vel: Vector2 = Vector2(facing * power * cos(rad), -power * sin(rad))
	for i: int in range(1, TRAJECTORY_DOT_COUNT + 1):
		vel.y += gravity * TRAJECTORY_DOT_DT
		vel.x += wind * TRAJECTORY_DOT_DT
		pos += vel * TRAJECTORY_DOT_DT
		if pos.x < 0.0 or pos.x > active_world_width or pos.y >= _ground_y_at_x(pos.x):
			break
		var alpha: float = 0.55 * (1.0 - float(i - 1) / float(TRAJECTORY_DOT_COUNT))
		draw_circle(_world_to_screen(pos), TRAJECTORY_DOT_RADIUS, Color(1.0, 1.0, 1.0, alpha))

func _draw_distant_mountains() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-120.0, VIEW_SIZE.y))
	for i: int in range(10):
		var x: float = float(i) * 150.0 - 120.0
		var y: float = 295.0 + 48.0 * sin(float(i) * 1.7)
		points.append(Vector2(x, y))
	points.append(Vector2(VIEW_SIZE.x + 120.0, VIEW_SIZE.y))
	draw_colored_polygon(points, Color(0.08, 0.10, 0.13))

func _draw_wind_widget() -> void:
	var box: Rect2 = Rect2(Vector2(18, 132), Vector2(142, 42))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.58), true)
	draw_rect(box, Color(0.85, 0.90, 1.0, 0.30), false, 1.0)
	var wind_strength: float = absf(wind) / MAX_WIND_ACCEL * 10.0
	var arrow_start: Vector2 = Vector2(34, 153)
	var arrow_end: Vector2 = Vector2(82, 153)
	if wind < 0.0:
		arrow_start = Vector2(82, 153)
		arrow_end = Vector2(34, 153)
	draw_line(arrow_start, arrow_end, Color(0.78, 0.90, 1.0), 3.0)
	draw_line(arrow_end, arrow_end + Vector2(-8 if wind > 0.0 else 8, -6), Color(0.78, 0.90, 1.0), 3.0)
	draw_line(arrow_end, arrow_end + Vector2(-8 if wind > 0.0 else 8, 6), Color(0.78, 0.90, 1.0), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(96, 160), "%.1f" % wind_strength, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
