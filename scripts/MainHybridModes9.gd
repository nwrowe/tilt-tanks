extends "res://scripts/MainHybridModes8.gd"

const WATER_REFLOW_SEARCH_CELLS: int = 85
const WATER_MIN_VISIBLE_DEPTH: float = 3.0
const WATER_MAX_SURFACE_ITERATIONS: int = 28

func _generate_ponds() -> void:
	super._generate_ponds()
	for i: int in range(ponds.size()):
		ponds[i] = _add_water_volume_to_pond(ponds[i])

func _add_water_volume_to_pond(pond: Dictionary) -> Dictionary:
	var start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
	var end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
	var water_y: float = float(pond.get("water_y", 0.0))
	var volume: float = _water_volume_for_range(start_i, end_i, water_y)
	pond["volume"] = volume
	return pond

func _water_volume_for_range(start_i: int, end_i: int, water_y: float) -> float:
	var volume: float = 0.0
	for i: int in range(start_i, end_i + 1):
		var depth: float = terrain_points[i].y - water_y
		if depth > 0.0:
			volume += depth * TERRAIN_STEP
	return volume

func _draw() -> void:
	if menu_state == MENU_STATE_GAME:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
		_draw_distant_mountains()
		_draw_ponds_under_ground()
		_draw_ground_fill()
		_draw_water_surfaces()
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

func _draw_ponds_under_ground() -> void:
	# Draw water first as a deep blue backing layer. Then grass is drawn on top,
	# hiding the water edges so only blue visible through depressions remains.
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
	# Draw only the flat visible water surface where terrain dips below water.
	# This avoids the old outlined blue polygons around the pond sides.
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

func _apply_crater(pos: Vector2) -> void:
	super._apply_crater(pos)
	_reflow_water_after_terrain_change(pos.x)

func _reflow_water_after_terrain_change(changed_x: float) -> void:
	if ponds.is_empty() or terrain_points.is_empty():
		return
	for i: int in range(ponds.size()):
		ponds[i] = _reflow_single_pond(ponds[i], changed_x)
	ponds = ponds.filter(func(p: Dictionary) -> bool:
		return float(p.get("volume", 0.0)) > 1.0 and int(p.get("end_i", 0)) > int(p.get("start_i", 0))
	)

func _reflow_single_pond(pond: Dictionary, changed_x: float) -> Dictionary:
	var old_start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
	var old_end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
	var volume: float = float(pond.get("volume", 0.0))
	if volume <= 0.0:
		volume = _water_volume_for_range(old_start_i, old_end_i, float(pond.get("water_y", 0.0)))
	if volume <= 0.0:
		return pond

	var center_x: float = clampf((float(pond.get("start_x", terrain_points[old_start_i].x)) + float(pond.get("end_x", terrain_points[old_end_i].x))) * 0.5, 0.0, active_world_width)
	# If the explosion is near this pond, bias the new basin search toward the blast;
	# otherwise use the old pond center. This lets water flow into nearby craters.
	if absf(changed_x - center_x) < float(WATER_REFLOW_SEARCH_CELLS * TERRAIN_STEP) * 1.5:
		center_x = lerpf(center_x, changed_x, 0.55)
	var center_i: int = clampi(int(round(center_x / TERRAIN_STEP)), 1, terrain_points.size() - 2)
	var left_limit: int = maxi(0, center_i - WATER_REFLOW_SEARCH_CELLS)
	var right_limit: int = mini(terrain_points.size() - 1, center_i + WATER_REFLOW_SEARCH_CELLS)

	# Find deepest available point in search area.
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

func _solve_water_level_for_volume(left_i: int, right_i: int, target_volume: float) -> float:
	var highest_y: float = -INF
	var lowest_y: float = INF
	for i: int in range(left_i, right_i + 1):
		highest_y = maxf(highest_y, terrain_points[i].y)
		lowest_y = minf(lowest_y, terrain_points[i].y)
	# Water surface must be above the lowest terrain, but lower than the deepest valley.
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

func _is_in_pond(pos: Vector2) -> bool:
	for pond: Dictionary in ponds:
		var start_x: float = float(pond.get("start_x", 0.0))
		var end_x: float = float(pond.get("end_x", 0.0))
		var water_y: float = float(pond.get("water_y", 0.0))
		if pos.x >= start_x and pos.x <= end_x and pos.y >= water_y:
			if _ground_y_at_x(pos.x) >= water_y + WATER_MIN_VISIBLE_DEPTH:
				return true
	return false
