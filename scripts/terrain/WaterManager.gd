extends RefCounted
class_name WaterManager

static func generate_ponds(
	rng: RandomNumberGenerator,
	points: Array[Vector2],
	active_right_start_x: float,
	left_spawn_x: float,
	pond_chance: float,
	attempts: int,
	min_width: float,
	max_width: float,
	min_depth: float,
	rim_search_radius: int,
	surface_drop: float,
	spawn_avoid_radius: float,
	terrain_step: float
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if points.size() < 30:
		return result
	if rng.randf() > pond_chance:
		return result

	var best_pond: Dictionary = {}
	var best_score: float = -INF
	for attempt: int in range(attempts):
		var pond: Dictionary = try_find_pond(
			rng,
			points,
			active_right_start_x,
			left_spawn_x,
			min_width,
			max_width,
			min_depth,
			rim_search_radius,
			surface_drop,
			spawn_avoid_radius
		)
		if pond.is_empty():
			continue
		var score: float = float(pond.get("score", 0.0))
		if score > best_score:
			best_score = score
			best_pond = pond

	if not best_pond.is_empty():
		result.append(add_volume_to_pond(points, best_pond, terrain_step))
	return result

static func try_find_pond(
	rng: RandomNumberGenerator,
	points: Array[Vector2],
	active_right_start_x: float,
	left_spawn_x: float,
	min_width: float,
	max_width: float,
	min_depth: float,
	rim_search_radius: int,
	surface_drop: float,
	spawn_avoid_radius: float
) -> Dictionary:
	var min_i: int = 12
	var max_i: int = points.size() - 13
	if max_i <= min_i:
		return {}

	var center_i: int = rng.randi_range(min_i, max_i)
	var center_x: float = points[center_i].x
	if absf(center_x - left_spawn_x) < spawn_avoid_radius:
		return {}
	if absf(center_x - active_right_start_x) < spawn_avoid_radius:
		return {}

	var valley_i: int = center_i
	var search_left: int = maxi(min_i, center_i - 12)
	var search_right: int = mini(max_i, center_i + 12)
	for i: int in range(search_left, search_right + 1):
		if points[i].y > points[valley_i].y:
			valley_i = i

	var valley_y: float = points[valley_i].y
	var left_best_i: int = valley_i
	var right_best_i: int = valley_i
	var left_highest_ground_y: float = valley_y
	var right_highest_ground_y: float = valley_y

	for step: int in range(1, rim_search_radius + 1):
		var left_i: int = valley_i - step
		if left_i < 1:
			break
		if points[left_i].y < left_highest_ground_y:
			left_highest_ground_y = points[left_i].y
			left_best_i = left_i

	for step: int in range(1, rim_search_radius + 1):
		var right_i: int = valley_i + step
		if right_i >= points.size() - 1:
			break
		if points[right_i].y < right_highest_ground_y:
			right_highest_ground_y = points[right_i].y
			right_best_i = right_i

	var spill_y: float = maxf(left_highest_ground_y, right_highest_ground_y)
	var depth: float = valley_y - spill_y
	if depth < min_depth:
		return {}

	var start_i: int = left_best_i
	var end_i: int = right_best_i
	if start_i >= end_i:
		return {}
	var width: float = points[end_i].x - points[start_i].x
	if width < min_width or width > max_width:
		return {}

	var water_y: float = spill_y + surface_drop
	if water_y >= valley_y - 4.0:
		return {}

	return {
		"start_i": start_i,
		"end_i": end_i,
		"start_x": points[start_i].x,
		"end_x": points[end_i].x,
		"water_y": water_y,
		"score": depth + width * 0.08
	}

static func pond_at_x(ponds: Array[Dictionary], terrain_points: Array[Vector2], x: float, terrain_step: float, min_visible_depth: float) -> Dictionary:
	for pond: Dictionary in ponds:
		var start_x: float = float(pond.get("start_x", 0.0))
		var end_x: float = float(pond.get("end_x", 0.0))
		var water_y: float = float(pond.get("water_y", 0.0))
		if x >= start_x and x <= end_x:
			if TerrainMath.ground_y_at_x(terrain_points, x, terrain_step) >= water_y + min_visible_depth:
				return pond
	return {}

static func is_in_pond(ponds: Array[Dictionary], terrain_points: Array[Vector2], pos: Vector2, terrain_step: float, min_visible_depth: float) -> bool:
	for pond: Dictionary in ponds:
		var start_x: float = float(pond.get("start_x", 0.0))
		var end_x: float = float(pond.get("end_x", 0.0))
		var water_y: float = float(pond.get("water_y", 0.0))
		if pos.x >= start_x and pos.x <= end_x and pos.y >= water_y:
			if TerrainMath.ground_y_at_x(terrain_points, pos.x, terrain_step) >= water_y + min_visible_depth:
				return true
	return false

static func water_volume_for_range(points: Array[Vector2], start_i: int, end_i: int, water_y: float, terrain_step: float) -> float:
	if points.is_empty():
		return 0.0
	var s: int = clampi(start_i, 0, points.size() - 1)
	var e: int = clampi(end_i, 0, points.size() - 1)
	var volume: float = 0.0
	for i: int in range(s, e + 1):
		var depth: float = points[i].y - water_y
		if depth > 0.0:
			volume += depth * terrain_step
	return volume

static func add_volume_to_pond(points: Array[Vector2], pond: Dictionary, terrain_step: float) -> Dictionary:
	if points.is_empty():
		return pond
	var updated: Dictionary = pond.duplicate(true)
	var start_i: int = clampi(int(updated.get("start_i", 0)), 0, points.size() - 1)
	var end_i: int = clampi(int(updated.get("end_i", 0)), 0, points.size() - 1)
	var water_y: float = float(updated.get("water_y", 0.0))
	updated["volume"] = water_volume_for_range(points, start_i, end_i, water_y, terrain_step)
	return updated

static func connected_basin_from_valley(points: Array[Vector2], valley_i: int, reference_water_y: float, margin: float) -> Dictionary:
	if points.is_empty():
		return {"left_i": 0, "right_i": 0}
	var left_i: int = clampi(valley_i, 0, points.size() - 1)
	while left_i > 0 and points[left_i].y > reference_water_y - margin:
		left_i -= 1
	var right_i: int = clampi(valley_i, 0, points.size() - 1)
	while right_i < points.size() - 1 and points[right_i].y > reference_water_y - margin:
		right_i += 1
	return {"left_i": left_i, "right_i": right_i}

static func solve_water_level_for_volume(points: Array[Vector2], left_i: int, right_i: int, target_volume: float, terrain_step: float, iterations: int) -> float:
	if points.is_empty():
		return 0.0
	var l: int = clampi(left_i, 0, points.size() - 1)
	var r: int = clampi(right_i, 0, points.size() - 1)
	var highest_y: float = -INF
	var lowest_y: float = INF
	for i: int in range(l, r + 1):
		highest_y = maxf(highest_y, points[i].y)
		lowest_y = minf(lowest_y, points[i].y)
	var low_surface: float = lowest_y
	var high_surface: float = highest_y
	for iter: int in range(iterations):
		var mid: float = (low_surface + high_surface) * 0.5
		var vol: float = water_volume_for_range(points, l, r, mid, terrain_step)
		if vol > target_volume:
			low_surface = mid
		else:
			high_surface = mid
	return (low_surface + high_surface) * 0.5

static func reflow_single_pond(
	points: Array[Vector2],
	pond: Dictionary,
	terrain_step: float,
	connected_margin: float,
	min_visible_depth: float,
	max_surface_iterations: int
) -> Dictionary:
	if points.is_empty():
		return pond
	var old_start_i: int = clampi(int(pond.get("start_i", 0)), 0, points.size() - 1)
	var old_end_i: int = clampi(int(pond.get("end_i", 0)), 0, points.size() - 1)
	var volume: float = float(pond.get("volume", 0.0))
	if volume <= 0.0:
		volume = water_volume_for_range(points, old_start_i, old_end_i, float(pond.get("water_y", 0.0)), terrain_step)
	if volume <= 0.0:
		return pond

	var old_water_y: float = float(pond.get("water_y", 0.0))
	var valley_i: int = TerrainMath.deepest_index_in_range(points, old_start_i, old_end_i)
	var basin: Dictionary = connected_basin_from_valley(points, valley_i, old_water_y, connected_margin)
	var left_i: int = int(basin.get("left_i", old_start_i))
	var right_i: int = int(basin.get("right_i", old_end_i))
	if right_i <= left_i:
		return pond

	var water_y: float = solve_water_level_for_volume(points, left_i, right_i, volume, terrain_step, max_surface_iterations)
	var deepest_i: int = TerrainMath.deepest_index_in_range(points, left_i, right_i)
	if water_y >= points[deepest_i].y - min_visible_depth:
		var unchanged: Dictionary = pond.duplicate(true)
		unchanged["volume"] = volume
		return unchanged

	var wet_start_i: int = deepest_i
	while wet_start_i > left_i and points[wet_start_i].y > water_y + connected_margin:
		wet_start_i -= 1
	var wet_end_i: int = deepest_i
	while wet_end_i < right_i and points[wet_end_i].y > water_y + connected_margin:
		wet_end_i += 1
	if wet_end_i <= wet_start_i:
		return pond

	return {
		"start_i": wet_start_i,
		"end_i": wet_end_i,
		"start_x": points[wet_start_i].x,
		"end_x": points[wet_end_i].x,
		"water_y": water_y,
		"volume": volume,
		"score": volume
	}

static func backing_rects_for_ponds(ponds: Array[Dictionary], points: Array[Vector2], floor_y: float) -> Array[Dictionary]:
	var rects: Array[Dictionary] = []
	if points.is_empty():
		return rects
	for pond: Dictionary in ponds:
		var start_i: int = clampi(int(pond.get("start_i", 0)), 0, points.size() - 1)
		var end_i: int = clampi(int(pond.get("end_i", 0)), 0, points.size() - 1)
		var water_y: float = float(pond.get("water_y", 0.0))
		if end_i <= start_i:
			continue
		rects.append({
			"start": Vector2(points[start_i].x, water_y),
			"end": Vector2(points[end_i].x, floor_y + 260.0)
		})
	return rects

static func surface_segments_for_ponds(ponds: Array[Dictionary], points: Array[Vector2], min_visible_depth: float) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if points.is_empty():
		return segments
	for pond: Dictionary in ponds:
		var start_i: int = clampi(int(pond.get("start_i", 0)), 0, points.size() - 1)
		var end_i: int = clampi(int(pond.get("end_i", 0)), 0, points.size() - 1)
		var water_y: float = float(pond.get("water_y", 0.0))
		var segment_start: int = -1
		for i: int in range(start_i, end_i + 1):
			var visible: bool = points[i].y > water_y + min_visible_depth
			if visible and segment_start < 0:
				segment_start = i
			elif not visible and segment_start >= 0:
				if i - 1 > segment_start:
					segments.append({"start": Vector2(points[segment_start].x, water_y), "end": Vector2(points[i - 1].x, water_y)})
				segment_start = -1
		if segment_start >= 0 and end_i > segment_start:
			segments.append({"start": Vector2(points[segment_start].x, water_y), "end": Vector2(points[end_i].x, water_y)})
	return segments
