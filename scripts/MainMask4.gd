extends "res://scripts/MainMask3.gd"

const BOTTOM_FLOOR_ROWS: int = 1
const CONTOUR_EDGE_WIDTH: float = 3.2
const TANK_LOCAL_SEARCH_UP: float = 10.0
const TANK_LOCAL_SEARCH_DOWN: float = 82.0
const TANK_MAX_STEP_UP: float = 18.0
const TANK_MAX_DROP: float = 34.0

var contour_segments: Array[Vector4] = []

func _generate_terrain_mask() -> void:
	super._generate_terrain_mask()
	_enforce_bottom_floor()
	_rebuild_contour_segments()

func _erase_circle(center: Vector2, radius: float) -> void:
	var min_col: int = clampi(int(floor((center.x - radius) / TERRAIN_STEP)), 0, terrain_cols - 1)
	var max_col: int = clampi(int(ceil((center.x + radius) / TERRAIN_STEP)), 0, terrain_cols - 1)
	var min_row: int = clampi(int(floor((center.y - radius) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var max_row: int = clampi(int(ceil((center.y + radius) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var floor_start_row: int = max(0, terrain_rows - BOTTOM_FLOOR_ROWS)
	var r2: float = radius * radius
	for col: int in range(min_col, max_col + 1):
		var x: float = float(col * TERRAIN_STEP)
		for row: int in range(min_row, max_row + 1):
			if row >= floor_start_row:
				continue
			var y: float = float(row * TERRAIN_STEP)
			if Vector2(x, y).distance_squared_to(center) <= r2:
				solid[col][row] = 0
	_enforce_bottom_floor()
	_rebuild_contour_segments()

func _enforce_bottom_floor() -> void:
	if terrain_rows <= 0:
		return
	var floor_start_row: int = max(0, terrain_rows - BOTTOM_FLOOR_ROWS)
	for col: int in range(terrain_cols):
		for row: int in range(floor_start_row, terrain_rows):
			solid[col][row] = 1

func _rebuild_contour_segments() -> void:
	contour_segments.clear()
	if terrain_cols <= 1 or terrain_rows <= 1:
		return
	for col: int in range(terrain_cols - 1):
		for row: int in range(terrain_rows - 1):
			var tl: bool = _is_solid_cell(col, row)
			var tr: bool = _is_solid_cell(col + 1, row)
			var br: bool = _is_solid_cell(col + 1, row + 1)
			var bl: bool = _is_solid_cell(col, row + 1)
			var mask: int = 0
			if tl:
				mask += 8
			if tr:
				mask += 4
			if br:
				mask += 2
			if bl:
				mask += 1
			if mask == 0 or mask == 15:
				continue
			var x0: float = float(col * TERRAIN_STEP)
			var y0: float = float(row * TERRAIN_STEP)
			var x1: float = float((col + 1) * TERRAIN_STEP)
			var y1: float = float((row + 1) * TERRAIN_STEP)
			var top: Vector2 = Vector2((x0 + x1) * 0.5, y0)
			var right: Vector2 = Vector2(x1, (y0 + y1) * 0.5)
			var bottom: Vector2 = Vector2((x0 + x1) * 0.5, y1)
			var left: Vector2 = Vector2(x0, (y0 + y1) * 0.5)
			_add_marching_segments(mask, top, right, bottom, left)

func _add_segment(a: Vector2, b: Vector2) -> void:
	contour_segments.append(Vector4(a.x, a.y, b.x, b.y))

func _add_marching_segments(mask: int, top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	match mask:
		1:
			_add_segment(left, bottom)
		2:
			_add_segment(bottom, right)
		3:
			_add_segment(left, right)
		4:
			_add_segment(top, right)
		5:
			_add_segment(top, left)
			_add_segment(bottom, right)
		6:
			_add_segment(top, bottom)
		7:
			_add_segment(top, left)
		8:
			_add_segment(top, left)
		9:
			_add_segment(top, bottom)
		10:
			_add_segment(top, right)
			_add_segment(left, bottom)
		11:
			_add_segment(top, right)
		12:
			_add_segment(left, right)
		13:
			_add_segment(bottom, right)
		14:
			_add_segment(left, bottom)

func _find_local_surface_y(x: float, current_tank_y: float) -> float:
	var col: int = clampi(int(round(x / TERRAIN_STEP)), 0, terrain_cols - 1)
	var tank_feet_y: float = current_tank_y + TANK_RADIUS
	var start_row: int = clampi(int(floor((tank_feet_y - TANK_LOCAL_SEARCH_UP) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var end_row: int = clampi(int(ceil((tank_feet_y + TANK_LOCAL_SEARCH_DOWN) / TERRAIN_STEP)), 0, terrain_rows - 1)
	for row: int in range(start_row, end_row + 1):
		if solid[col][row] == 1:
			return float(row * TERRAIN_STEP)
	return float(WORLD_HEIGHT - TERRAIN_STEP)

func _find_tank_surface_y(x: float, current_tank_y: float = -1.0) -> float:
	var sample_offsets: Array[float] = [-TANK_HALF_WIDTH, -TANK_HALF_WIDTH * 0.5, 0.0, TANK_HALF_WIDTH * 0.5, TANK_HALF_WIDTH]
	var best_y: float = float(WORLD_HEIGHT - TERRAIN_STEP)
	for offset: float in sample_offsets:
		var sx: float = clampf(x + offset, 0.0, float(world_width))
		var sy: float = _find_surface_y(sx) if current_tank_y < 0.0 else _find_local_surface_y(sx, current_tank_y)
		best_y = minf(best_y, sy)
	return best_y

func _update_tank_movement(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0
	if direction == 0.0:
		return
	var old_pos: Vector2 = tank_positions[current_player]
	var new_x: float = clampf(old_pos.x + direction * TANK_MOVE_SPEED * delta, 45.0, float(world_width) - 45.0)
	var other_player: int = 1 - current_player
	if absf(new_x - tank_positions[other_player].x) < 90.0:
		return
	var new_y: float = _find_tank_surface_y(new_x, old_pos.y) - TANK_RADIUS
	var dy: float = new_y - old_pos.y
	if dy < -TANK_MAX_STEP_UP:
		return
	if dy > TANK_MAX_DROP:
		new_y = old_pos.y + TANK_MAX_DROP
	tank_positions[current_player] = Vector2(new_x, new_y)

func _settle_tanks_on_terrain() -> void:
	for player: int in range(2):
		var current_y: float = tank_positions[player].y
		var target_y: float = _find_tank_surface_y(tank_positions[player].x, current_y) - TANK_RADIUS
		if current_y > 0.0 and target_y < current_y - TANK_MAX_STEP_UP:
			continue
		tank_positions[player].y = target_y

func _draw_exposed_edges() -> void:
	var left_bound: float = camera_x - 12.0
	var right_bound: float = camera_x + VIEW_SIZE.x / CAMERA_SCALE + 12.0
	var edge_color: Color = Color(0.32, 0.92, 0.40)
	for segment: Vector4 in contour_segments:
		if maxf(segment.x, segment.z) < left_bound or minf(segment.x, segment.z) > right_bound:
			continue
		draw_line(_world_to_screen(Vector2(segment.x, segment.y)), _world_to_screen(Vector2(segment.z, segment.w)), edge_color, CONTOUR_EDGE_WIDTH)

func _draw_distant_mountains() -> void:
	var offset: float = camera_x * 0.18
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-60.0, VIEW_SIZE.y))
	for i: int in range(9):
		points.append(Vector2(float(i) * 150.0 - fmod(offset, 150.0) - 60.0, 285.0 + 48.0 * sin(float(i) * 1.7)))
	points.append(Vector2(VIEW_SIZE.x + 60.0, VIEW_SIZE.y))
	draw_colored_polygon(points, Color(0.075, 0.095, 0.125))
