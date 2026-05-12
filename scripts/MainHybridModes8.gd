extends "res://scripts/MainHybridModes7.gd"

const POND_CHANCE: float = 0.38
const POND_ATTEMPTS: int = 10
const POND_MIN_WIDTH: float = 130.0
const POND_MAX_WIDTH: float = 430.0
const POND_MIN_DEPTH: float = 18.0
const POND_RIM_SEARCH_RADIUS: int = 55
const POND_SURFACE_DROP: float = 6.0
const POND_SPAWN_AVOID_RADIUS: float = 140.0

var ponds: Array[Dictionary] = []

func _generate_random_terrain() -> void:
	super._generate_random_terrain()
	_generate_ponds()

func _generate_ponds() -> void:
	ponds.clear()
	if terrain_points.size() < 30:
		return
	if rng.randf() > POND_CHANCE:
		return

	var best_pond: Dictionary = {}
	var best_score: float = -INF
	for attempt: int in range(POND_ATTEMPTS):
		var pond: Dictionary = _try_find_pond()
		if pond.is_empty():
			continue
		var score: float = float(pond.get("score", 0.0))
		if score > best_score:
			best_score = score
			best_pond = pond

	if not best_pond.is_empty():
		ponds.append(best_pond)

func _try_find_pond() -> Dictionary:
	var min_i: int = 12
	var max_i: int = terrain_points.size() - 13
	if max_i <= min_i:
		return {}

	var center_i: int = rng.randi_range(min_i, max_i)
	var center_x: float = terrain_points[center_i].x
	if absf(center_x - TANK_START_LEFT_X) < POND_SPAWN_AVOID_RADIUS:
		return {}
	if absf(center_x - active_right_start_x) < POND_SPAWN_AVOID_RADIUS:
		return {}

	# In screen coordinates, larger y is lower. A valley has a larger y than
	# nearby rims. Find the deepest local point near the chosen center.
	var valley_i: int = center_i
	var search_left: int = maxi(min_i, center_i - 12)
	var search_right: int = mini(max_i, center_i + 12)
	for i: int in range(search_left, search_right + 1):
		if terrain_points[i].y > terrain_points[valley_i].y:
			valley_i = i

	var valley_y: float = terrain_points[valley_i].y
	var left_i: int = valley_i
	var right_i: int = valley_i
	var left_best_i: int = valley_i
	var right_best_i: int = valley_i
	var left_highest_ground_y: float = valley_y
	var right_highest_ground_y: float = valley_y

	for step: int in range(1, POND_RIM_SEARCH_RADIUS + 1):
		left_i = valley_i - step
		if left_i < 1:
			break
		# Highest physical ground == smallest screen y.
		if terrain_points[left_i].y < left_highest_ground_y:
			left_highest_ground_y = terrain_points[left_i].y
			left_best_i = left_i

	for step: int in range(1, POND_RIM_SEARCH_RADIUS + 1):
		right_i = valley_i + step
		if right_i >= terrain_points.size() - 1:
			break
		if terrain_points[right_i].y < right_highest_ground_y:
			right_highest_ground_y = terrain_points[right_i].y
			right_best_i = right_i

	var spill_y: float = maxf(left_highest_ground_y, right_highest_ground_y)
	var depth: float = valley_y - spill_y
	if depth < POND_MIN_DEPTH:
		return {}

	var start_i: int = left_best_i
	var end_i: int = right_best_i
	if start_i >= end_i:
		return {}
	var width: float = terrain_points[end_i].x - terrain_points[start_i].x
	if width < POND_MIN_WIDTH or width > POND_MAX_WIDTH:
		return {}

	var water_y: float = spill_y + POND_SURFACE_DROP
	if water_y >= valley_y - 4.0:
		return {}

	return {
		"start_i": start_i,
		"end_i": end_i,
		"start_x": terrain_points[start_i].x,
		"end_x": terrain_points[end_i].x,
		"water_y": water_y,
		"score": depth + width * 0.08
	}

func _draw() -> void:
	if menu_state == MENU_STATE_GAME:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
		_draw_distant_mountains()
		_draw_ground_fill()
		_draw_ponds()
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
		# Preserve realtime-mode overlays from parent wrappers.
		if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
			_draw_realtime_projectiles()
			_draw_realtime_cooldown_widgets()
			_draw_steam_puffs()
		return
	super._draw()

func _draw_ponds() -> void:
	for pond: Dictionary in ponds:
		_draw_single_pond(pond)

func _draw_single_pond(pond: Dictionary) -> void:
	var start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
	var end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
	var water_y: float = float(pond.get("water_y", 0.0))
	if end_i <= start_i:
		return

	var poly: PackedVector2Array = PackedVector2Array()
	poly.append(_world_to_screen(Vector2(terrain_points[start_i].x, water_y)))
	for i: int in range(start_i, end_i + 1):
		var p: Vector2 = terrain_points[i]
		if p.y >= water_y:
			poly.append(_world_to_screen(Vector2(p.x, p.y)))
	poly.append(_world_to_screen(Vector2(terrain_points[end_i].x, water_y)))
	if poly.size() >= 3:
		draw_colored_polygon(poly, Color(0.04, 0.30, 0.62, 0.78))

	var left_screen: Vector2 = _world_to_screen(Vector2(terrain_points[start_i].x, water_y))
	var right_screen: Vector2 = _world_to_screen(Vector2(terrain_points[end_i].x, water_y))
	draw_line(left_screen, right_screen, Color(0.22, 0.70, 1.0, 0.90), 3.0)
	# Small highlight to make it feel like a surface rather than a blue fill.
	draw_line(left_screen + Vector2(0, 3), right_screen + Vector2(0, 3), Color(0.60, 0.90, 1.0, 0.28), 1.5)

func _is_in_pond(pos: Vector2) -> bool:
	for pond: Dictionary in ponds:
		var start_x: float = float(pond.get("start_x", 0.0))
		var end_x: float = float(pond.get("end_x", 0.0))
		var water_y: float = float(pond.get("water_y", 0.0))
		if pos.x >= start_x and pos.x <= end_x and pos.y >= water_y:
			# Only count it as water if terrain exists below the water surface here.
			if _ground_y_at_x(pos.x) >= water_y:
				return true
	return false

func _update_projectile(delta: float) -> void:
	projectile_vel.y += gravity * delta
	projectile_vel.x += wind * delta
	projectile_pos += projectile_vel * delta
	var enemy: int = 1 - current_player
	if projectile_pos.distance_to(tank_positions[enemy]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		_explode(projectile_pos)
		return
	if _is_in_pond(projectile_pos):
		_explode(projectile_pos)
		return
	var ground_y: float = _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		_explode(Vector2(projectile_pos.x, ground_y))
		return
	if projectile_pos.x < -100.0 or projectile_pos.x > active_world_width + 100.0 or projectile_pos.y > _bottom_floor_y() + 180.0:
		_explode(projectile_pos)

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
