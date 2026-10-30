extends RefCounted
class_name LegacyTerrainGeometry

## Pure terrain sampling and crater deformation extracted from the original
## tweaked gameplay runtime. RNG and all numeric parameters are supplied by
## the caller; terrain line refresh / tank settling stay on the game node.

static func generate_points(
	rng: RandomNumberGenerator,
	world_width: float,
	terrain_step: float,
	min_y: float,
	max_y: float,
	floor_y: float
) -> Array[Vector2]:
	var control_spacing: float = rng.randf_range(65.0, 115.0)
	var control_points: Array[Vector2] = []
	var control_count: int = int(ceil(world_width / control_spacing)) + 2
	var previous_y: float = rng.randf_range(360.0, 455.0)
	for i: int in range(control_count):
		var x: float = float(i) * control_spacing
		var slope_kick: float = rng.randf_range(-95.0, 95.0)
		var y: float = clampf(previous_y + slope_kick, min_y, minf(max_y, floor_y))
		if x < 210.0 or x > world_width - 210.0:
			y = rng.randf_range(385.0, minf(455.0, floor_y))
		control_points.append(Vector2(x, y))
		previous_y = y

	var points: Array[Vector2] = []
	var point_count: int = int(world_width / terrain_step) + 1
	for i: int in range(point_count):
		var x: float = float(i) * terrain_step
		var control_index: int = mini(int(floor(x / control_spacing)), control_points.size() - 2)
		var left: Vector2 = control_points[control_index]
		var right: Vector2 = control_points[control_index + 1]
		var t: float = clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		var y: float = lerpf(left.y, right.y, smooth_t)
		if x > 230.0 and x < world_width - 230.0:
			y += 10.0 * sin(x * 0.035 + rng.randf_range(-0.15, 0.15))
		points.append(Vector2(x, clampf(y, min_y, floor_y)))
	return points

static func apply_crater(
	points: Array[Vector2],
	pos: Vector2,
	radius: float,
	depth: float,
	min_y: float,
	floor_y: float
) -> void:
	for i: int in range(points.size()):
		var point: Vector2 = points[i]
		var dx: float = point.x - pos.x
		if absf(dx) <= radius:
			var normalized_x: float = dx / radius
			var bowl: float = sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
			var target_y: float = pos.y + depth * bowl
			point.y = clampf(maxf(point.y, target_y), min_y, floor_y)
			points[i] = point
