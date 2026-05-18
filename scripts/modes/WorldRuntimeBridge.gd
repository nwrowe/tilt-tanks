extends "res://scripts/modes/ModeRuntimeBridge.gd"

# Consolidated world/runtime bridge while flattening the legacy chain.
# This body was moved from MainHybridModes12.gd and owns terrain/water/snow
# runtime constants, realtime fire-charge state, in-game draw composition, and
# movement helpers.

const VAR_TERRAIN_MIN_Y: float = 245.0
const VAR_TERRAIN_MAX_Y: float = 560.0
const VAR_START_MIN_Y: float = 390.0
const VAR_START_MAX_Y: float = 500.0
const VAR_CONTROL_SPACING_MIN: float = 58.0
const VAR_CONTROL_SPACING_MAX: float = 108.0
const VAR_SLOPE_KICK: float = 150.0
const VAR_DETAIL_WAVE_AMOUNT: float = 17.0

const POND_CHANCE: float = 0.38
const POND_ATTEMPTS: int = 10
const POND_MIN_WIDTH: float = 130.0
const POND_MAX_WIDTH: float = 430.0
const POND_MIN_DEPTH: float = 18.0
const POND_RIM_SEARCH_RADIUS: int = 55
const POND_SURFACE_DROP: float = 6.0
const POND_SPAWN_AVOID_RADIUS: float = 140.0

const WATER_REFLOW_SEARCH_CELLS: int = 85
const WATER_MIN_VISIBLE_DEPTH: float = 3.0
const WATER_MAX_SURFACE_ITERATIONS: int = 28
const WATER_CONNECTED_MARGIN: float = 2.0
const WATER_DRIVE_SPEED_MULT: float = 0.42
const WATER_FLOAT_TANK_SUBMERGENCE: float = 0.50

const SNOW_LINE_Y: float = 315.0
const SNOW_UPHILL_BLOCK_SLOPE: float = 0.58
const SNOW_SLIDE_SLOPE: float = 0.24
const SNOW_SLIDE_SPEED: float = 70.0
const SNOW_DRIVE_MULT: float = 0.72
const SNOW_EDGE_WIDTH: float = 7.0

const RT_CHARGE_TIME_MAX: float = 1.65
const RT_CHARGE_MIN_PERCENT: float = 10.0
const RT_CHARGE_MAX_PERCENT: float = 100.0

var ponds: Array[Dictionary] = []
var rt_player_shell_active: bool = false
var rt_fire_button_held: bool = false
var rt_keyboard_fire_held: bool = false
var rt_fire_charge_time: float = 0.0
var rt_fire_charge_percent: float = 0.0

func _ready() -> void:
	super._ready()
	_resize_mobile_action_buttons()
	if mobile_fire_button != null:
		if not mobile_fire_button.button_down.is_connected(_on_realtime_fire_button_down):
			mobile_fire_button.button_down.connect(_on_realtime_fire_button_down)
		if not mobile_fire_button.button_up.is_connected(_on_realtime_fire_button_up):
			mobile_fire_button.button_up.connect(_on_realtime_fire_button_up)
	_update_fire_button_charge_style(0.0)

func _setup_realtime_single_player() -> void:
	super._setup_realtime_single_player()
	rt_player_shell_active = false
	rt_fire_button_held = false
	rt_keyboard_fire_held = false
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0
	_resize_mobile_action_buttons()
	_show_realtime_power_ui(false)
	_update_fire_button_charge_style(0.0)

func reset_match() -> void:
	super.reset_match()
	rt_player_shell_active = false
	rt_fire_button_held = false
	rt_keyboard_fire_held = false
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0
	_update_fire_button_charge_style(0.0)

func _show_game_ui() -> void:
	super._show_game_ui()
	_show_realtime_power_ui(game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME)

func _show_realtime_power_ui(show_slider: bool) -> void:
	if power_slider != null:
		power_slider.visible = show_slider
	if power_label != null:
		power_label.visible = true

func _on_realtime_fire_button_down() -> void:
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME or menu_state != MENU_STATE_GAME:
		return
	if not _player_can_fire() or game_over or overlay_open:
		return
	rt_fire_button_held = true
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = RT_CHARGE_MIN_PERCENT
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _on_realtime_fire_button_up() -> void:
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME or menu_state != MENU_STATE_GAME:
		return
	if rt_fire_button_held:
		_release_realtime_charged_shot()
	rt_fire_button_held = false
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _player_can_fire() -> bool:
	return not rt_player_shell_active and not game_over

func _release_realtime_charged_shot() -> void:
	# Compatibility stub. MainGame.gd owns the active implementation.
	return

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

func _pond_at_x(x: float) -> Dictionary:
	for pond: Dictionary in ponds:
		var start_x: float = float(pond.get("start_x", 0.0))
		var end_x: float = float(pond.get("end_x", 0.0))
		var water_y: float = float(pond.get("water_y", 0.0))
		if x >= start_x and x <= end_x and _ground_y_at_x(x) >= water_y + WATER_MIN_VISIBLE_DEPTH:
			return pond
	return {}

func _tank_y_for_surface(player: int, x: float) -> float:
	var ground_y: float = _ground_y_at_x(x) - TANK_RADIUS
	var pond: Dictionary = _pond_at_x(x)
	if pond.is_empty():
		return ground_y
	var water_y: float = float(pond.get("water_y", 0.0))
	var float_y: float = water_y + TANK_RADIUS * (1.0 - WATER_FLOAT_TANK_SUBMERGENCE)
	return minf(ground_y, float_y)

func _movement_speed_mult_at_x(x: float) -> float:
	return WATER_DRIVE_SPEED_MULT if not _pond_at_x(x).is_empty() else 1.0

func _draw_ponds_under_ground() -> void:
	for pond: Dictionary in ponds:
		var start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
		var end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
		var water_y: float = float(pond.get("water_y", 0.0))
		if end_i <= start_i:
			continue
		var start_x: float = terrain_points[start_i].x
		var end_x: float = terrain_points[end_i].x
		var top_left: Vector2 = _world_to_screen(Vector2(start_x, water_y))
		var bottom_right: Vector2 = _world_to_screen(Vector2(end_x, _bottom_floor_y() + 260.0))
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(0.035, 0.22, 0.50, 0.95), true)

func _draw_water_surfaces() -> void:
	for pond: Dictionary in ponds:
		var start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
		var end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
		var water_y: float = float(pond.get("water_y", 0.0))
		var segment_start: int = -1
		for i: int in range(start_i, end_i + 1):
			var visible: bool = terrain_points[i].y > water_y + WATER_MIN_VISIBLE_DEPTH
			if visible and segment_start < 0:
				segment_start = i
			elif not visible and segment_start >= 0:
				_draw_water_surface_segment(segment_start, i - 1, water_y)
				segment_start = -1
		if segment_start >= 0:
			_draw_water_surface_segment(segment_start, end_i, water_y)

func _draw_water_surface_segment(start_i: int, end_i: int, water_y: float) -> void:
	if end_i <= start_i:
		return
	var left: Vector2 = _world_to_screen(Vector2(terrain_points[start_i].x, water_y))
	var right: Vector2 = _world_to_screen(Vector2(terrain_points[end_i].x, water_y))
	draw_line(left, right, Color(0.18, 0.66, 1.0, 0.88), 3.0)
	draw_line(left + Vector2(0, 3), right + Vector2(0, 3), Color(0.72, 0.92, 1.0, 0.28), 1.5)

func _water_volume_for_range(start_i: int, end_i: int, water_y: float) -> float:
	var volume: float = 0.0
	for i: int in range(start_i, end_i + 1):
		var depth: float = terrain_points[i].y - water_y
		if depth > 0.0:
			volume += depth * TERRAIN_STEP
	return volume

func _add_water_volume_to_pond(pond: Dictionary) -> Dictionary:
	var start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
	var end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
	var water_y: float = float(pond.get("water_y", 0.0))
	pond["volume"] = _water_volume_for_range(start_i, end_i, water_y)
	return pond

func _solve_water_level_for_volume(left_i: int, right_i: int, target_volume: float) -> float:
	var highest_y: float = -INF
	var lowest_y: float = INF
	for i: int in range(left_i, right_i + 1):
		highest_y = maxf(highest_y, terrain_points[i].y)
		lowest_y = minf(lowest_y, terrain_points[i].y)
	var low_surface: float = lowest_y
	var high_surface: float = highest_y
	for iter: int in range(WATER_MAX_SURFACE_ITERATIONS):
		var mid: float = (low_surface + high_surface) * 0.5
		var vol: float = _water_volume_for_range(left_i, right_i, mid)
		if vol > target_volume:
			low_surface = mid
		else:
			high_surface = mid
	return (low_surface + high_surface) * 0.5

func _reflow_single_pond(pond: Dictionary, changed_x: float) -> Dictionary:
	var old_start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
	var old_end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
	var volume: float = float(pond.get("volume", 0.0))
	if volume <= 0.0:
		volume = _water_volume_for_range(old_start_i, old_end_i, float(pond.get("water_y", 0.0)))
	if volume <= 0.0:
		return pond
	var center_x: float = clampf((float(pond.get("start_x", terrain_points[old_start_i].x)) + float(pond.get("end_x", terrain_points[old_end_i].x))) * 0.5, 0.0, active_world_width)
	if absf(changed_x - center_x) < float(WATER_REFLOW_SEARCH_CELLS * TERRAIN_STEP) * 1.5:
		center_x = lerpf(center_x, changed_x, 0.55)
	var center_i: int = clampi(int(round(center_x / TERRAIN_STEP)), 1, terrain_points.size() - 2)
	var left_limit: int = maxi(0, center_i - WATER_REFLOW_SEARCH_CELLS)
	var right_limit: int = mini(terrain_points.size() - 1, center_i + WATER_REFLOW_SEARCH_CELLS)
	var valley_i: int = center_i
	for i: int in range(left_limit, right_limit + 1):
		if terrain_points[i].y > terrain_points[valley_i].y:
			valley_i = i
	var water_y: float = _solve_water_level_for_volume(left_limit, right_limit, volume)
	if water_y >= terrain_points[valley_i].y - WATER_MIN_VISIBLE_DEPTH:
		pond["volume"] = volume
		return pond
	var start_i: int = valley_i
	while start_i > left_limit and terrain_points[start_i].y > water_y:
		start_i -= 1
	var end_i: int = valley_i
	while end_i < right_limit and terrain_points[end_i].y > water_y:
		end_i += 1
	if end_i <= start_i:
		return pond
	return {
		"start_i": start_i,
		"end_i": end_i,
		"start_x": terrain_points[start_i].x,
		"end_x": terrain_points[end_i].x,
		"water_y": water_y,
		"volume": volume,
		"score": volume
	}

func _reflow_water_after_terrain_change(changed_x: float) -> void:
	if ponds.is_empty() or terrain_points.is_empty():
		return
	for i: int in range(ponds.size()):
		ponds[i] = _reflow_single_pond(ponds[i], changed_x)
	ponds = ponds.filter(func(p: Dictionary) -> bool:
		return float(p.get("volume", 0.0)) > 1.0 and int(p.get("end_i", 0)) > int(p.get("start_i", 0))
	)

func _is_in_pond(pos: Vector2) -> bool:
	for pond: Dictionary in ponds:
		var start_x: float = float(pond.get("start_x", 0.0))
		var end_x: float = float(pond.get("end_x", 0.0))
		var water_y: float = float(pond.get("water_y", 0.0))
		if pos.x >= start_x and pos.x <= end_x and pos.y >= water_y:
			if _ground_y_at_x(pos.x) >= water_y + WATER_MIN_VISIBLE_DEPTH:
				return true
	return false

func _realtime_projectile_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
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

func _draw_realtime_cooldown_widgets() -> void:
	return

func _reset_realtime_charge_state() -> void:
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0
	rt_fire_button_held = false
	rt_keyboard_fire_held = false
	_update_fire_button_charge_style(0.0)

func _update_fire_button_charge_style(charge_ratio: float) -> void:
	if mobile_fire_button == null:
		return
	var color: Color = _charge_button_color(charge_ratio)
	_apply_fire_button_style(color, color.darkened(0.35), Color.WHITE)

func _update_fire_button_unavailable_style() -> void:
	if mobile_fire_button == null:
		return
	_apply_fire_button_style(Color(0.18, 0.18, 0.20, 0.86), Color(0.08, 0.08, 0.10, 0.96), Color(0.75, 0.75, 0.78, 1.0))

func _charge_button_color(charge_ratio: float) -> Color:
	var v: float = clampf(charge_ratio, 0.0, 1.0)
	if v < 0.5:
		var t: float = v / 0.5
		return Color(lerpf(0.10, 1.0, t), 0.80, 0.12, 0.92)
	var t2: float = (v - 0.5) / 0.5
	return Color(1.0, lerpf(0.80, 0.12, t2), 0.08, 0.92)

func _apply_fire_button_style(bg: Color, border: Color, font: Color) -> void:
	if mobile_fire_button == null:
		return
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(16)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.12)
	for state: String in ["normal", "hover", "focus"]:
		mobile_fire_button.add_theme_stylebox_override(state, normal)
	mobile_fire_button.add_theme_stylebox_override("pressed", pressed)
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		mobile_fire_button.add_theme_color_override(color_name, font)

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
