extends "res://scripts/MainMask5.gd"

const TANK_COLLISION_HALF_WIDTH: float = 24.0
const TANK_COLLISION_HEIGHT: float = 25.0
const TANK_MOVE_SUBSTEP: float = 3.0
const TANK_MAX_CLIMB_PER_MOVE: float = 12.0
const TANK_MAX_DROP_PER_MOVE: float = 18.0

func _erase_circle(center: Vector2, radius: float) -> void:
	# Fast terrain carve: erase mask cells only. Do NOT rebuild contour cache here;
	# the cached contour pass was the source of the visible hitch on impact.
	explosion_pos = center
	explosion_timer = EXPLOSION_DURATION
	var min_col: int = clampi(int(floor((center.x - radius) / TERRAIN_STEP)), 0, terrain_cols - 1)
	var max_col: int = clampi(int(ceil((center.x + radius) / TERRAIN_STEP)), 0, terrain_cols - 1)
	var min_row: int = clampi(int(floor((center.y - radius) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var max_row: int = clampi(int(ceil((center.y + radius) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var floor_row: int = _visible_floor_row()
	var r2: float = radius * radius
	for col: int in range(min_col, max_col + 1):
		var x: float = float(col * TERRAIN_STEP)
		for row: int in range(min_row, max_row + 1):
			if row >= floor_row:
				continue
			var y: float = float(row * TERRAIN_STEP)
			if Vector2(x, y).distance_squared_to(center) <= r2:
				solid[col][row] = 0
	_enforce_bottom_floor()

func _draw_exposed_edges() -> void:
	# Cheap dynamic edge renderer: only draw top-facing exposed cells in the visible range.
	# This updates immediately after explosions without a costly full marching-squares rebuild.
	var start_col: int = clampi(int(floor(camera_x / TERRAIN_STEP)) - 2, 0, terrain_cols - 1)
	var end_world_x: float = camera_x + VIEW_SIZE.x / CAMERA_SCALE
	var end_col: int = clampi(int(ceil(end_world_x / TERRAIN_STEP)) + 2, 0, terrain_cols - 1)
	var edge_color: Color = Color(0.32, 0.92, 0.40)
	for col: int in range(start_col, end_col + 1):
		for row: int in range(0, terrain_rows):
			if solid[col][row] == 1 and not _is_solid_cell(col, row - 1):
				var x0: float = float(col * TERRAIN_STEP)
				var y0: float = float(row * TERRAIN_STEP)
				draw_line(_world_to_screen(Vector2(x0, y0)), _world_to_screen(Vector2(x0 + float(TERRAIN_STEP), y0)), edge_color, CONTOUR_EDGE_WIDTH)

func _tank_rect_collides(center: Vector2) -> bool:
	var left_col: int = clampi(int(floor((center.x - TANK_COLLISION_HALF_WIDTH) / TERRAIN_STEP)), 0, terrain_cols - 1)
	var right_col: int = clampi(int(ceil((center.x + TANK_COLLISION_HALF_WIDTH) / TERRAIN_STEP)), 0, terrain_cols - 1)
	var top_row: int = clampi(int(floor((center.y - TANK_COLLISION_HEIGHT) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var bottom_row: int = clampi(int(ceil((center.y + TANK_RADIUS) / TERRAIN_STEP)), 0, terrain_rows - 1)
	for col: int in range(left_col, right_col + 1):
		for row: int in range(top_row, bottom_row + 1):
			if solid[col][row] == 1:
				return true
	return false

func _has_ground_support(center: Vector2) -> bool:
	var foot_y: float = center.y + TANK_RADIUS + 2.0
	var sample_offsets: Array[float] = [-TANK_COLLISION_HALF_WIDTH * 0.8, 0.0, TANK_COLLISION_HALF_WIDTH * 0.8]
	for offset: float in sample_offsets:
		if _is_solid_at(Vector2(center.x + offset, foot_y)):
			return true
	return false

func _candidate_tank_position(x: float, current_y: float) -> Vector2:
	# Find a nearby floor from the current feet level, not the global top surface.
	var surface_y: float = _find_local_tank_surface_y(x, current_y)
	if surface_y == INF:
		return Vector2(x, current_y)
	return Vector2(x, surface_y - TANK_RADIUS)

func _can_move_tank_to(candidate: Vector2, old_pos: Vector2) -> bool:
	var dy: float = candidate.y - old_pos.y
	if dy < -TANK_MAX_CLIMB_PER_MOVE:
		return false
	if dy > TANK_MAX_DROP_PER_MOVE:
		return false
	# Prevent the body from entering solid terrain. This is the wall/ceiling check
	# missing from the earlier local-surface method.
	if _tank_rect_collides(candidate):
		return false
	# Require ground support unless the tank is descending only very slightly.
	if not _has_ground_support(candidate):
		return false
	return true

func _update_tank_movement(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0
	if direction == 0.0:
		return
	var total_dx: float = direction * TANK_MOVE_SPEED * delta
	var remaining: float = absf(total_dx)
	var step_sign: float = signf(total_dx)
	while remaining > 0.0:
		var step_dx: float = minf(TANK_MOVE_SUBSTEP, remaining) * step_sign
		var old_pos: Vector2 = tank_positions[current_player]
		var new_x: float = clampf(old_pos.x + step_dx, 45.0, float(world_width) - 45.0)
		var other_player: int = 1 - current_player
		if absf(new_x - tank_positions[other_player].x) < 90.0:
			return
		var candidate: Vector2 = _candidate_tank_position(new_x, old_pos.y)
		if not _can_move_tank_to(candidate, old_pos):
			return
		tank_positions[current_player] = candidate
		remaining -= absf(step_dx)

func _settle_tanks_on_terrain() -> void:
	for player: int in range(2):
		var old_pos: Vector2 = tank_positions[player]
		if old_pos.y <= 0.0:
			tank_positions[player].y = _find_global_tank_surface_y(old_pos.x) - TANK_RADIUS
		else:
			var candidate: Vector2 = _candidate_tank_position(old_pos.x, old_pos.y)
			if _can_move_tank_to(candidate, old_pos) or candidate.y >= old_pos.y:
				tank_positions[player] = candidate
