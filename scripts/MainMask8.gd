extends "res://scripts/MainMask7.gd"

const TANK_FALL_PER_STEP: float = 10.0
const TANK_GROUND_SEARCH_DEEP: float = 150.0
const FULL_EDGE_WIDTH: float = 2.6

func _find_local_surface_y(x: float, current_tank_y: float) -> float:
	var col: int = clampi(int(round(x / TERRAIN_STEP)), 0, terrain_cols - 1)
	var feet_y: float = current_tank_y + TANK_RADIUS
	var start_row: int = clampi(int(floor((feet_y - LOCAL_GROUND_SEARCH_UP) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var end_row: int = clampi(int(ceil((feet_y + TANK_GROUND_SEARCH_DEEP) / TERRAIN_STEP)), 0, terrain_rows - 1)
	for row: int in range(start_row, end_row + 1):
		if solid[col][row] == 1:
			return float(row * TERRAIN_STEP)
	return INF

func _candidate_tank_position(x: float, current_y: float) -> Vector2:
	# If there is nearby ground, stand on it. If not, this is a drop / hole,
	# not a wall. Move forward and fall gradually instead of hanging at the lip.
	var surface_y: float = _find_local_tank_surface_y(x, current_y)
	if surface_y == INF:
		return Vector2(x, current_y + TANK_FALL_PER_STEP)
	var target_y: float = surface_y - TANK_RADIUS
	if target_y > current_y + TANK_FALL_PER_STEP:
		return Vector2(x, current_y + TANK_FALL_PER_STEP)
	return Vector2(x, target_y)

func _can_move_tank_to(candidate: Vector2, old_pos: Vector2) -> bool:
	var dy: float = candidate.y - old_pos.y
	if dy < -TANK_MAX_CLIMB_PER_MOVE:
		return false
	# Descending/falling is allowed as long as the body does not enter terrain.
	if _tank_body_collides(candidate):
		return false
	if dy > 0.0:
		return true
	return _has_ground_support(candidate)

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
			if _tank_body_collides(candidate):
				continue
			# Allow the tank to settle down after explosions, but don't pop it upward
			# through ceilings or impossible lips.
			if candidate.y >= old_pos.y or candidate.y >= old_pos.y - TANK_MAX_CLIMB_PER_MOVE:
				tank_positions[player] = candidate

func _draw_exposed_edges() -> void:
	# Restore full exposed-edge rendering so craters/tunnels have consistent outlines.
	# This is dynamic and avoids the expensive contour cache rebuild that caused impact hitches.
	var start_col: int = clampi(int(floor(camera_x / TERRAIN_STEP)) - 2, 0, terrain_cols - 1)
	var end_world_x: float = camera_x + VIEW_SIZE.x / CAMERA_SCALE
	var end_col: int = clampi(int(ceil(end_world_x / TERRAIN_STEP)) + 2, 0, terrain_cols - 1)
	var edge_color: Color = Color(0.32, 0.92, 0.40)
	var shadow_color: Color = Color(0.12, 0.34, 0.14)
	for col: int in range(start_col, end_col + 1):
		for row: int in range(0, terrain_rows):
			if solid[col][row] == 0:
				continue
			var x0: float = float(col * TERRAIN_STEP)
			var y0: float = float(row * TERRAIN_STEP)
			var x1: float = x0 + float(TERRAIN_STEP)
			var y1: float = y0 + float(TERRAIN_STEP)
			if not _is_solid_cell(col, row - 1):
				draw_line(_world_to_screen(Vector2(x0, y0)), _world_to_screen(Vector2(x1, y0)), edge_color, FULL_EDGE_WIDTH)
			if not _is_solid_cell(col - 1, row):
				draw_line(_world_to_screen(Vector2(x0, y0)), _world_to_screen(Vector2(x0, y1)), edge_color, FULL_EDGE_WIDTH)
			if not _is_solid_cell(col + 1, row):
				draw_line(_world_to_screen(Vector2(x1, y0)), _world_to_screen(Vector2(x1, y1)), edge_color, FULL_EDGE_WIDTH)
			if not _is_solid_cell(col, row + 1):
				draw_line(_world_to_screen(Vector2(x0, y1)), _world_to_screen(Vector2(x1, y1)), shadow_color, FULL_EDGE_WIDTH * 0.7)
