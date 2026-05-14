extends RefCounted
class_name TerrainManager

# Stateless terrain operations used during the gradual migration out of the
# MainHybridModes inheritance chain. Ownership of terrain_points, tanks, water,
# and drawing still remains in the active game script for now.

static func generate_varied_terrain(
	rng: RandomNumberGenerator,
	world_width: float,
	terrain_step: float,
	floor_y: float,
	terrain_min_y: float,
	terrain_max_y: float,
	start_min_y: float,
	start_max_y: float,
	control_spacing_min: float,
	control_spacing_max: float,
	slope_kick_amount: float,
	detail_wave_amount: float,
	left_spawn_x: float,
	right_spawn_x: float,
	spawn_flatten_half_width: float
) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var max_y: float = minf(terrain_max_y, floor_y)
	var control_spacing: float = rng.randf_range(control_spacing_min, control_spacing_max)
	var control_points: Array[Vector2] = []
	var control_count: int = int(ceil(world_width / control_spacing)) + 2
	var previous_y: float = rng.randf_range(start_min_y, minf(start_max_y, max_y))

	for i: int in range(control_count):
		var x: float = float(i) * control_spacing
		var slope_kick: float = rng.randf_range(-slope_kick_amount, slope_kick_amount)
		var y: float = clampf(previous_y + slope_kick, terrain_min_y, max_y)
		if x < 230.0 or x > world_width - 230.0:
			y = rng.randf_range(start_min_y, minf(start_max_y, max_y))
		control_points.append(Vector2(x, y))
		previous_y = y

	var point_count: int = int(world_width / terrain_step) + 1
	for i: int in range(point_count):
		var x: float = float(i) * terrain_step
		var control_index: int = mini(int(floor(x / control_spacing)), control_points.size() - 2)
		var left: Vector2 = control_points[control_index]
		var right: Vector2 = control_points[control_index + 1]
		var t: float = clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		var y: float = lerpf(left.y, right.y, smooth_t)
		if x > 250.0 and x < world_width - 250.0:
			y += detail_wave_amount * sin(x * 0.035 + rng.randf_range(-0.15, 0.15))
			y += 7.0 * sin(x * 0.071 + rng.randf_range(-0.2, 0.2))
		points.append(Vector2(x, clampf(y, terrain_min_y, max_y)))

	flatten_spawn_area(points, left_spawn_x, spawn_flatten_half_width)
	flatten_spawn_area(points, right_spawn_x, spawn_flatten_half_width)
	return points

static func flatten_spawn_area(points: Array[Vector2], center_x: float, half_width: float) -> void:
	if points.is_empty():
		return
	var y_sum: float = 0.0
	var count: int = 0
	for point: Vector2 in points:
		if absf(point.x - center_x) <= half_width:
			y_sum += point.y
			count += 1
	if count <= 0:
		return
	var flat_y: float = y_sum / float(count)
	for i: int in range(points.size()):
		var point: Vector2 = points[i]
		var dist: float = absf(point.x - center_x)
		if dist <= half_width:
			point.y = flat_y
		elif dist <= half_width + 40.0:
			point.y = lerpf(flat_y, point.y, (dist - half_width) / 40.0)
		points[i] = point

static func refresh_terrain_line(line: Line2D, points: Array[Vector2]) -> void:
	if line == null:
		return
	line.clear_points()
	for point: Vector2 in points:
		line.add_point(point)

static func settle_tanks_on_terrain(tank_positions: Array[Vector2], points: Array[Vector2], terrain_step: float, tank_radius: float) -> void:
	for player: int in range(tank_positions.size()):
		var pos: Vector2 = tank_positions[player]
		pos.y = TerrainMath.ground_y_at_x(points, pos.x, terrain_step) - tank_radius
		tank_positions[player] = pos

static func apply_crater(points: Array[Vector2], pos: Vector2, radius: float, depth: float, min_y: float, floor_y: float) -> void:
	for i: int in range(points.size()):
		var point: Vector2 = points[i]
		var dx: float = point.x - pos.x
		if absf(dx) <= radius:
			var normalized_x: float = dx / maxf(radius, 0.001)
			var bowl: float = sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
			var target_y: float = pos.y + depth * bowl
			point.y = clampf(maxf(point.y, target_y), min_y, floor_y)
			points[i] = point

static func clamp_tank_x(x: float, world_width: float, edge_margin: float) -> float:
	return clampf(x, edge_margin, maxf(edge_margin, world_width - edge_margin))

static func visible_surface_points(
	points: Array[Vector2],
	camera_x: float,
	camera_scale: float,
	view_width: float,
	terrain_step: float,
	left_screen_x: float,
	right_screen_x: float
) -> PackedVector2Array:
	var surface: PackedVector2Array = PackedVector2Array()
	if points.size() < 2 or camera_scale <= 0.0:
		return surface
	var left_world_x: float = camera_x + left_screen_x / camera_scale
	var right_world_x: float = camera_x + right_screen_x / camera_scale
	surface.append(Vector2(left_world_x, TerrainMath.ground_y_at_x(points, left_world_x, terrain_step)))
	for point: Vector2 in points:
		if point.x > left_world_x and point.x < right_world_x:
			surface.append(point)
	surface.append(Vector2(right_world_x, TerrainMath.ground_y_at_x(points, right_world_x, terrain_step)))
	return surface

static func ground_fill_polygon_world(
	points: Array[Vector2],
	camera_x: float,
	camera_scale: float,
	view_width: float,
	view_height: float,
	terrain_step: float,
	left_screen_x: float,
	right_screen_x: float,
	bottom_y: float
) -> PackedVector2Array:
	var surface: PackedVector2Array = visible_surface_points(points, camera_x, camera_scale, view_width, terrain_step, left_screen_x, right_screen_x)
	var polygon: PackedVector2Array = PackedVector2Array()
	if surface.size() < 2:
		return polygon
	var left_world_x: float = camera_x + left_screen_x / camera_scale
	var right_world_x: float = camera_x + right_screen_x / camera_scale
	polygon.append(Vector2(left_world_x, bottom_y))
	polygon.append(Vector2(right_world_x, bottom_y))
	for i: int in range(surface.size() - 1, -1, -1):
		polygon.append(surface[i])
	return polygon

static func terrain_outline_world(
	points: Array[Vector2],
	camera_x: float,
	camera_scale: float,
	view_width: float,
	terrain_step: float,
	left_screen_x: float,
	right_screen_x: float
) -> PackedVector2Array:
	return visible_surface_points(points, camera_x, camera_scale, view_width, terrain_step, left_screen_x, right_screen_x)
