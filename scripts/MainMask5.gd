extends "res://scripts/MainMask4.gd"

const VISIBLE_FLOOR_MARGIN: float = 4.0
const WALKABLE_STEP_UP: float = 14.0
const WALKABLE_DROP_DOWN: float = 28.0
const LOCAL_GROUND_SEARCH_UP: float = 8.0
const LOCAL_GROUND_SEARCH_DOWN: float = 42.0

func _visible_floor_world_y() -> float:
	return (VIEW_SIZE.y - CAMERA_Y_OFFSET) / CAMERA_SCALE - VISIBLE_FLOOR_MARGIN

func _visible_floor_row() -> int:
	return clampi(int(round(_visible_floor_world_y() / TERRAIN_STEP)), 0, terrain_rows - 1)

func _enforce_bottom_floor() -> void:
	if terrain_rows <= 0:
		return
	var floor_row: int = _visible_floor_row()
	for col: int in range(terrain_cols):
		for row: int in range(floor_row, terrain_rows):
			solid[col][row] = 1

func _erase_circle(center: Vector2, radius: float) -> void:
	# Start the visual explosion immediately, then carve. The expensive contour rebuild happens
	# while the explosion flash is visible, which makes the hitch less obvious.
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
	_rebuild_contour_segments()

func _find_global_tank_surface_y(x: float) -> float:
	var sample_offsets: Array[float] = [-TANK_HALF_WIDTH, -TANK_HALF_WIDTH * 0.5, 0.0, TANK_HALF_WIDTH * 0.5, TANK_HALF_WIDTH]
	var best_y: float = _visible_floor_world_y()
	for offset: float in sample_offsets:
		var sx: float = clampf(x + offset, 0.0, float(world_width))
		best_y = minf(best_y, _find_surface_y(sx))
	return best_y

func _find_local_surface_y(x: float, current_tank_y: float) -> float:
	var col: int = clampi(int(round(x / TERRAIN_STEP)), 0, terrain_cols - 1)
	var feet_y: float = current_tank_y + TANK_RADIUS
	var start_row: int = clampi(int(floor((feet_y - LOCAL_GROUND_SEARCH_UP) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var end_row: int = clampi(int(ceil((feet_y + LOCAL_GROUND_SEARCH_DOWN) / TERRAIN_STEP)), 0, terrain_rows - 1)
	for row: int in range(start_row, end_row + 1):
		if solid[col][row] == 1:
			return float(row * TERRAIN_STEP)
	return INF

func _find_local_tank_surface_y(x: float, current_tank_y: float) -> float:
	var sample_offsets: Array[float] = [-TANK_HALF_WIDTH, -TANK_HALF_WIDTH * 0.5, 0.0, TANK_HALF_WIDTH * 0.5, TANK_HALF_WIDTH]
	var best_y: float = INF
	for offset: float in sample_offsets:
		var sx: float = clampf(x + offset, 0.0, float(world_width))
		best_y = minf(best_y, _find_local_surface_y(sx, current_tank_y))
	return best_y

func _settle_tanks_on_terrain() -> void:
	for player: int in range(2):
		if tank_positions[player].y <= 0.0:
			tank_positions[player].y = _find_global_tank_surface_y(tank_positions[player].x) - TANK_RADIUS
		else:
			var local_y: float = _find_local_tank_surface_y(tank_positions[player].x, tank_positions[player].y)
			if local_y != INF:
				var target_y: float = local_y - TANK_RADIUS
				if target_y >= tank_positions[player].y - WALKABLE_STEP_UP:
					tank_positions[player].y = minf(target_y, tank_positions[player].y + WALKABLE_DROP_DOWN)

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
	var local_surface_y: float = _find_local_tank_surface_y(new_x, old_pos.y)
	if local_surface_y == INF:
		return
	var new_y: float = local_surface_y - TANK_RADIUS
	var dy: float = new_y - old_pos.y
	if dy < -WALKABLE_STEP_UP:
		# Too steep / wall / overhang lip: block movement instead of snapping upward.
		return
	if dy > WALKABLE_DROP_DOWN:
		# Drive down drops gradually rather than teleporting.
		new_y = old_pos.y + WALKABLE_DROP_DOWN
	tank_positions[current_player] = Vector2(new_x, new_y)

func _apply_explosion_damage(pos: Vector2) -> void:
	# Damage if any part of the tank overlaps the explosion circle. Approximate the tank
	# footprint as a circle by subtracting TANK_RADIUS from center distance.
	for player: int in range(2):
		var surface_dist: float = maxf(0.0, pos.distance_to(tank_positions[player]) - TANK_RADIUS)
		if surface_dist <= DIRECT_HIT_RADIUS:
			tank_health[player] = maxi(0, tank_health[player] - DIRECT_HIT_DAMAGE)
		elif surface_dist <= DAMAGE_RADIUS:
			var normalized: float = (surface_dist - DIRECT_HIT_RADIUS) / (DAMAGE_RADIUS - DIRECT_HIT_RADIUS)
			var damage: int = maxi(6, int(round(float(MAX_SPLASH_DAMAGE) * pow(1.0 - normalized, 1.35))))
			tank_health[player] = maxi(0, tank_health[player] - damage)
