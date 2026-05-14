extends RefCounted
class_name TerrainManager

# Stateless terrain operations used during the gradual migration out of the
# MainHybridModes inheritance chain. Ownership of terrain_points, tanks, water,
# and drawing still remains in the active game script for now.

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
