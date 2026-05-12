extends "res://scripts/MainHybridModes9.gd"

const WATER_CONNECTED_MARGIN: float = 2.0
const WATER_DRIVE_SPEED_MULT: float = 0.42
const WATER_FLOAT_TANK_SUBMERGENCE: float = 0.50

func _reflow_single_pond(pond: Dictionary, changed_x: float) -> Dictionary:
	var old_start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
	var old_end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
	var volume: float = float(pond.get("volume", 0.0))
	if volume <= 0.0:
		volume = _water_volume_for_range(old_start_i, old_end_i, float(pond.get("water_y", 0.0)))
	if volume <= 0.0:
		return pond

	# Key fix: water can only reflow within the currently connected basin.
	# The old model searched broadly and biased toward explosions, which allowed
	# water to teleport into distant, disconnected craters. Here the old pond's
	# current water level determines the connected wet basin, and reflow is solved
	# only inside that basin. If an explosion breaks the rim and connects a crater,
	# the connected basin naturally expands; otherwise it stays isolated.
	var old_water_y: float = float(pond.get("water_y", 0.0))
	var valley_i: int = _deepest_index_in_range(old_start_i, old_end_i)
	var basin: Dictionary = _connected_basin_from_valley(valley_i, old_water_y)
	var left_i: int = int(basin.get("left_i", old_start_i))
	var right_i: int = int(basin.get("right_i", old_end_i))
	if right_i <= left_i:
		return pond

	var water_y: float = _solve_water_level_for_volume(left_i, right_i, volume)
	var deepest_i: int = _deepest_index_in_range(left_i, right_i)
	if water_y >= terrain_points[deepest_i].y - WATER_MIN_VISIBLE_DEPTH:
		pond["volume"] = volume
		return pond

	var wet_start_i: int = deepest_i
	while wet_start_i > left_i and terrain_points[wet_start_i].y > water_y + WATER_CONNECTED_MARGIN:
		wet_start_i -= 1
	var wet_end_i: int = deepest_i
	while wet_end_i < right_i and terrain_points[wet_end_i].y > water_y + WATER_CONNECTED_MARGIN:
		wet_end_i += 1
	if wet_end_i <= wet_start_i:
		return pond

	return {
		"start_i": wet_start_i,
		"end_i": wet_end_i,
		"start_x": terrain_points[wet_start_i].x,
		"end_x": terrain_points[wet_end_i].x,
		"water_y": water_y,
		"volume": volume,
		"score": volume
	}

func _connected_basin_from_valley(valley_i: int, reference_water_y: float) -> Dictionary:
	var left_i: int = valley_i
	while left_i > 0 and terrain_points[left_i].y > reference_water_y - WATER_CONNECTED_MARGIN:
		left_i -= 1
	var right_i: int = valley_i
	while right_i < terrain_points.size() - 1 and terrain_points[right_i].y > reference_water_y - WATER_CONNECTED_MARGIN:
		right_i += 1
	return {
		"left_i": left_i,
		"right_i": right_i
	}

func _deepest_index_in_range(start_i: int, end_i: int) -> int:
	var s: int = clampi(start_i, 0, terrain_points.size() - 1)
	var e: int = clampi(end_i, 0, terrain_points.size() - 1)
	var best_i: int = s
	for i: int in range(s, e + 1):
		if terrain_points[i].y > terrain_points[best_i].y:
			best_i = i
	return best_i

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
	# Float with about half the tank above the water surface. Since tank position
	# is its center, this puts the center roughly on the water line, with clamping
	# so shallow water doesn't lift the tank above nearby terrain unrealistically.
	var float_y: float = water_y + TANK_RADIUS * (1.0 - WATER_FLOAT_TANK_SUBMERGENCE)
	return minf(ground_y, float_y)

func _movement_speed_mult_at_x(x: float) -> float:
	return WATER_DRIVE_SPEED_MULT if not _pond_at_x(x).is_empty() else 1.0

func _settle_tanks_on_terrain() -> void:
	for player: int in range(2):
		tank_positions[player].y = _tank_y_for_surface(player, tank_positions[player].x)

func _update_tank_movement(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0
	if direction == 0.0:
		return
	var speed_mult: float = _movement_speed_mult_at_x(tank_positions[current_player].x)
	var new_x: float = clampf(tank_positions[current_player].x + direction * TANK_MOVE_SPEED * speed_mult * delta, 45.0, active_world_width - 45.0)
	var other_player: int = 1 - current_player
	if absf(new_x - tank_positions[other_player].x) < 90.0:
		return
	tank_positions[current_player].x = new_x
	tank_positions[current_player].y = _tank_y_for_surface(current_player, new_x)

func _update_realtime_player_movement(delta: float) -> void:
	# Unlimited movement in realtime single-player, but slowed while driving/floating
	# through water.
	rt_movement_energy = RT_MOVEMENT_ENERGY_MAX
	rt_movement_exhaust_cooldown = 0.0
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0
	if direction == 0.0:
		return
	var speed_mult: float = _movement_speed_mult_at_x(tank_positions[HUMAN_PLAYER_INDEX].x)
	var new_x: float = clampf(tank_positions[HUMAN_PLAYER_INDEX].x + direction * TANK_MOVE_SPEED * speed_mult * delta, 45.0, active_world_width - 45.0)
	if absf(new_x - tank_positions[AI_PLAYER_INDEX].x) >= 90.0:
		tank_positions[HUMAN_PLAYER_INDEX].x = new_x
		tank_positions[HUMAN_PLAYER_INDEX].y = _tank_y_for_surface(HUMAN_PLAYER_INDEX, new_x)

func _move_realtime_ai(delta: float) -> void:
	var dx: float = rt_ai_target_x - tank_positions[AI_PLAYER_INDEX].x
	if absf(dx) < 3.0:
		return
	var direction: float = signf(dx)
	var speed_mult: float = _movement_speed_mult_at_x(tank_positions[AI_PLAYER_INDEX].x)
	var new_x: float = tank_positions[AI_PLAYER_INDEX].x + direction * RT_AI_MOVE_SPEED * speed_mult * delta
	if (direction > 0.0 and new_x > rt_ai_target_x) or (direction < 0.0 and new_x < rt_ai_target_x):
		new_x = rt_ai_target_x
	new_x = clampf(new_x, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
	if absf(new_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
		return
	tank_positions[AI_PLAYER_INDEX].x = new_x
	tank_positions[AI_PLAYER_INDEX].y = _tank_y_for_surface(AI_PLAYER_INDEX, new_x)
