extends RefCounted
class_name TerrainMath

static func bottom_floor_y(view_size: Vector2, camera_y_offset: float, camera_scale: float, screen_margin: float) -> float:
	return (view_size.y - camera_y_offset) / camera_scale - screen_margin

static func slope_at_x(points: Array[Vector2], x: float, terrain_step: float, world_width: float) -> float:
	if points.size() < 2:
		return 0.0
	var dx: float = terrain_step * 3.0
	var left_y: float = ground_y_at_x(points, clampf(x - dx, 0.0, world_width), terrain_step)
	var right_y: float = ground_y_at_x(points, clampf(x + dx, 0.0, world_width), terrain_step)
	return (right_y - left_y) / (2.0 * dx)

static func ground_y_at_x(points: Array[Vector2], x: float, terrain_step: float) -> float:
	if points.is_empty():
		return 0.0
	var clamped_x: float = clampf(x, points.front().x, points.back().x)
	var index: int = clampi(int(floor(clamped_x / terrain_step)), 0, points.size() - 2)
	var left: Vector2 = points[index]
	var right: Vector2 = points[index + 1]
	var denom: float = maxf(right.x - left.x, 0.001)
	var t: float = clampf((clamped_x - left.x) / denom, 0.0, 1.0)
	return lerpf(left.y, right.y, t)

static func deepest_index_in_range(points: Array[Vector2], start_i: int, end_i: int) -> int:
	if points.is_empty():
		return 0
	var s: int = clampi(start_i, 0, points.size() - 1)
	var e: int = clampi(end_i, 0, points.size() - 1)
	var best_i: int = s
	for i: int in range(s, e + 1):
		if points[i].y > points[best_i].y:
			best_i = i
	return best_i

static func is_above_snow_line(points: Array[Vector2], x: float, terrain_step: float, snow_line_y: float) -> bool:
	return ground_y_at_x(points, x, terrain_step) <= snow_line_y
