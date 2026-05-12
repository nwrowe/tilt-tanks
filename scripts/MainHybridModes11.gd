extends "res://scripts/MainHybridModes10.gd"

const VAR_TERRAIN_MIN_Y: float = 245.0
const VAR_TERRAIN_MAX_Y: float = 560.0
const VAR_START_MIN_Y: float = 390.0
const VAR_START_MAX_Y: float = 500.0
const VAR_CONTROL_SPACING_MIN: float = 58.0
const VAR_CONTROL_SPACING_MAX: float = 108.0
const VAR_SLOPE_KICK: float = 150.0
const VAR_DETAIL_WAVE_AMOUNT: float = 17.0

func _generate_random_terrain() -> void:
	terrain_points.clear()
	active_world_width = rng.randf_range(WORLD_WIDTH_MIN_TWEAK, WORLD_WIDTH_MAX_TWEAK)
	active_right_start_x = active_world_width - 130.0
	var floor_y: float = _bottom_floor_y()
	var terrain_max_y: float = minf(VAR_TERRAIN_MAX_Y, floor_y)
	var control_spacing: float = rng.randf_range(VAR_CONTROL_SPACING_MIN, VAR_CONTROL_SPACING_MAX)
	var control_points: Array[Vector2] = []
	var control_count: int = int(ceil(active_world_width / control_spacing)) + 2
	var previous_y: float = rng.randf_range(VAR_START_MIN_Y, minf(VAR_START_MAX_Y, terrain_max_y))

	for i: int in range(control_count):
		var x: float = float(i) * control_spacing
		var slope_kick: float = rng.randf_range(-VAR_SLOPE_KICK, VAR_SLOPE_KICK)
		var y: float = clampf(previous_y + slope_kick, VAR_TERRAIN_MIN_Y, terrain_max_y)
		if x < 230.0 or x > active_world_width - 230.0:
			y = rng.randf_range(VAR_START_MIN_Y, minf(VAR_START_MAX_Y, terrain_max_y))
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
		if x > 250.0 and x < active_world_width - 250.0:
			y += VAR_DETAIL_WAVE_AMOUNT * sin(x * 0.035 + rng.randf_range(-0.15, 0.15))
			y += 7.0 * sin(x * 0.071 + rng.randf_range(-0.2, 0.2))
		terrain_points.append(Vector2(x, clampf(y, VAR_TERRAIN_MIN_Y, terrain_max_y)))

	_flatten_spawn_area(TANK_START_LEFT_X, 54.0)
	_flatten_spawn_area(active_right_start_x, 54.0)
	_refresh_terrain_line()
	_settle_tanks_on_terrain()
	_generate_ponds()
