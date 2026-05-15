extends "res://scripts/MainHybridModes9.gd"

# Consolidated compatibility layer while flattening the legacy chain.
# MainHybridModes11.gd and MainHybridModes10.gd have been folded into this file
# so the active chain now skips them.

const SNOW_LINE_Y: float = 315.0
const SNOW_UPHILL_BLOCK_SLOPE: float = 0.58
const SNOW_SLIDE_SLOPE: float = 0.24
const SNOW_SLIDE_SPEED: float = 70.0
const SNOW_DRIVE_MULT: float = 0.72
const SNOW_EDGE_WIDTH: float = 7.0

const VAR_TERRAIN_MIN_Y: float = 245.0
const VAR_TERRAIN_MAX_Y: float = 560.0
const VAR_START_MIN_Y: float = 390.0
const VAR_START_MAX_Y: float = 500.0
const VAR_CONTROL_SPACING_MIN: float = 58.0
const VAR_CONTROL_SPACING_MAX: float = 108.0
const VAR_SLOPE_KICK: float = 150.0
const VAR_DETAIL_WAVE_AMOUNT: float = 17.0

const WATER_CONNECTED_MARGIN: float = 2.0
const WATER_DRIVE_SPEED_MULT: float = 0.42
const WATER_FLOAT_TANK_SUBMERGENCE: float = 0.50

func _ready() -> void:
	super._ready()
	_resize_mobile_action_buttons()

func _resize_mobile_action_buttons() -> void:
	# Keep left/right enlarged and move FIRE farther right so it is easier to hit.
	if mobile_left_button != null:
		mobile_left_button.position = Vector2(16, 430)
		mobile_left_button.size = Vector2(92, 88)
	if mobile_right_button != null:
		mobile_right_button.position = Vector2(122, 430)
		mobile_right_button.size = Vector2(92, 88)
	if mobile_fire_button != null:
		mobile_fire_button.position = Vector2(430, 448)
		mobile_fire_button.size = Vector2(188, 70)

func _draw_wind_widget() -> void:
	# Borderless center-zero wind meter with label.
	var box_pos: Vector2 = Vector2(18, 132)
	var box_size: Vector2 = Vector2(190, 42)
	draw_rect(Rect2(box_pos, box_size), Color(0.02, 0.03, 0.04, 0.42), true)

	var meter_left: float = box_pos.x + 58.0
	var meter_right: float = box_pos.x + box_size.x - 18.0
	var meter_center: float = (meter_left + meter_right) * 0.5
	var meter_y: float = box_pos.y + 22.0
	var half_width: float = (meter_right - meter_left) * 0.5
	var display_wind: float = _wind_display_value()
	var strength: float = clampf(absf(display_wind) / WIND_DISPLAY_MAX, 0.0, 1.0)
	var fill_width: float = half_width * strength
	var bar_color: Color = _wind_strength_color(strength)

	draw_line(Vector2(meter_left, meter_y), Vector2(meter_right, meter_y), Color(0.55, 0.65, 0.75, 0.42), 8.0)
	draw_line(Vector2(meter_center, meter_y - 13.0), Vector2(meter_center, meter_y + 13.0), Color.WHITE, 2.0)
	if display_wind >= 0.0:
		draw_line(Vector2(meter_center, meter_y), Vector2(meter_center + fill_width, meter_y), bar_color, 8.0)
		_draw_small_arrow(Vector2(meter_center + fill_width + 4.0, meter_y), 1.0, bar_color)
	else:
		draw_line(Vector2(meter_center, meter_y), Vector2(meter_center - fill_width, meter_y), bar_color, 8.0)
		_draw_small_arrow(Vector2(meter_center - fill_width - 4.0, meter_y), -1.0, bar_color)

	draw_string(ThemeDB.fallback_font, Vector2(box_pos.x + 8.0, box_pos.y + 27.0), "wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(box_pos.x + box_size.x - 46.0, box_pos.y + 35.0), "%+.0f" % display_wind, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw() -> void:
	if menu_state == MENU_STATE_GAME:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
		_draw_distant_mountains()
		_draw_ponds_under_ground()
		_draw_ground_fill()
		_draw_water_surfaces()
		_draw_snow_caps()
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
		if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
			_draw_realtime_projectiles()
			_draw_realtime_cooldown_widgets()
			_draw_steam_puffs()
		return
	super._draw()

func _draw_snow_caps() -> void:
	if terrain_points.size() < 2:
		return
	var segment: PackedVector2Array = PackedVector2Array()
	for i: int in range(terrain_points.size()):
		var p: Vector2 = terrain_points[i]
		if p.y <= SNOW_LINE_Y:
			segment.append(_world_to_screen(p))
		else:
			_draw_snow_segment(segment)
			segment = PackedVector2Array()
	_draw_snow_segment(segment)

func _draw_snow_segment(segment: PackedVector2Array) -> void:
	if segment.size() < 2:
		return
	for i: int in range(segment.size() - 1):
		draw_line(segment[i], segment[i + 1], Color(0.92, 0.96, 1.0, 0.95), SNOW_EDGE_WIDTH)
		draw_line(segment[i] + Vector2(0, 4), segment[i + 1] + Vector2(0, 4), Color(0.74, 0.86, 1.0, 0.42), 2.0)

func _is_snow_at_x(x: float) -> bool:
	return _ground_y_at_x(x) <= SNOW_LINE_Y

func _terrain_slope_at_x(x: float) -> float:
	var dx: float = TERRAIN_STEP * 3.0
	var left_y: float = _ground_y_at_x(clampf(x - dx, 0.0, active_world_width))
	var right_y: float = _ground_y_at_x(clampf(x + dx, 0.0, active_world_width))
	return (right_y - left_y) / (2.0 * dx)

func _snow_adjusted_direction_and_speed(x: float, input_direction: float, base_speed: float) -> Dictionary:
	var direction: float = input_direction
	var speed: float = base_speed
	if not _is_snow_at_x(x):
		return {"direction": direction, "speed": speed, "blocked": false}

	var slope: float = _terrain_slope_at_x(x)
	var blocked: bool = false
	var downhill_direction: float = signf(slope)
	var moving_uphill: bool = input_direction != 0.0 and signf(input_direction) == -downhill_direction and absf(slope) > SNOW_UPHILL_BLOCK_SLOPE
	if moving_uphill:
		blocked = true
		direction = 0.0
	elif input_direction == 0.0 and absf(slope) > SNOW_SLIDE_SLOPE:
		direction = downhill_direction
		speed = SNOW_SLIDE_SPEED
	else:
		speed *= SNOW_DRIVE_MULT
		if input_direction != 0.0 and signf(input_direction) == downhill_direction and absf(slope) > SNOW_SLIDE_SLOPE:
			speed += SNOW_SLIDE_SPEED * 0.45
	return {"direction": direction, "speed": speed, "blocked": blocked}

func _update_tank_movement(delta: float) -> void:
	var input_direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		input_direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		input_direction += 1.0
	var adjusted: Dictionary = _snow_adjusted_direction_and_speed(tank_positions[current_player].x, input_direction, TANK_MOVE_SPEED * _movement_speed_mult_at_x(tank_positions[current_player].x))
	var direction: float = float(adjusted.get("direction", 0.0))
	if direction == 0.0:
		return
	var speed: float = float(adjusted.get("speed", TANK_MOVE_SPEED))
	var new_x: float = clampf(tank_positions[current_player].x + direction * speed * delta, 45.0, active_world_width - 45.0)
	var other_player: int = 1 - current_player
	if absf(new_x - tank_positions[other_player].x) < 90.0:
		return
	tank_positions[current_player].x = new_x
	tank_positions[current_player].y = _tank_y_for_surface(current_player, new_x)

func _update_realtime_player_movement(delta: float) -> void:
	rt_movement_energy = RT_MOVEMENT_ENERGY_MAX
	rt_movement_exhaust_cooldown = 0.0
	var input_direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		input_direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		input_direction += 1.0
	var adjusted: Dictionary = _snow_adjusted_direction_and_speed(tank_positions[HUMAN_PLAYER_INDEX].x, input_direction, TANK_MOVE_SPEED * _movement_speed_mult_at_x(tank_positions[HUMAN_PLAYER_INDEX].x))
	var direction: float = float(adjusted.get("direction", 0.0))
	if direction == 0.0:
		return
	var speed: float = float(adjusted.get("speed", TANK_MOVE_SPEED))
	var new_x: float = clampf(tank_positions[HUMAN_PLAYER_INDEX].x + direction * speed * delta, 45.0, active_world_width - 45.0)
	if absf(new_x - tank_positions[AI_PLAYER_INDEX].x) >= 90.0:
		tank_positions[HUMAN_PLAYER_INDEX].x = new_x
		tank_positions[HUMAN_PLAYER_INDEX].y = _tank_y_for_surface(HUMAN_PLAYER_INDEX, new_x)

func _move_realtime_ai(delta: float) -> void:
	var dx: float = rt_ai_target_x - tank_positions[AI_PLAYER_INDEX].x
	var input_direction: float = 0.0 if absf(dx) < 3.0 else signf(dx)
	var adjusted: Dictionary = _snow_adjusted_direction_and_speed(tank_positions[AI_PLAYER_INDEX].x, input_direction, RT_AI_MOVE_SPEED * _movement_speed_mult_at_x(tank_positions[AI_PLAYER_INDEX].x))
	var direction: float = float(adjusted.get("direction", 0.0))
	if direction == 0.0:
		return
	var speed: float = float(adjusted.get("speed", RT_AI_MOVE_SPEED))
	var new_x: float = tank_positions[AI_PLAYER_INDEX].x + direction * speed * delta
	if input_direction != 0.0:
		if (input_direction > 0.0 and new_x > rt_ai_target_x) or (input_direction < 0.0 and new_x < rt_ai_target_x):
			new_x = rt_ai_target_x
	new_x = clampf(new_x, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
	if absf(new_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
		return
	tank_positions[AI_PLAYER_INDEX].x = new_x
	tank_positions[AI_PLAYER_INDEX].y = _tank_y_for_surface(AI_PLAYER_INDEX, new_x)
