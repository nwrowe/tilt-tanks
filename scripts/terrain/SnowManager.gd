extends RefCounted
class_name SnowManager

# Stateless snow helpers used while moving snow behavior out of the legacy
# MainHybridModes inheritance chain. Drawing and tank state ownership remain in
# the active game script for now.

static func is_snow_at_x(points: Array[Vector2], x: float, terrain_step: float, snow_line_y: float) -> bool:
	return TerrainMath.is_above_snow_line(points, x, terrain_step, snow_line_y)

static func slope_at_x(points: Array[Vector2], x: float, terrain_step: float, world_width: float) -> float:
	return TerrainMath.slope_at_x(points, x, terrain_step, world_width)

static func adjusted_direction_and_speed(
	points: Array[Vector2],
	x: float,
	input_direction: float,
	base_speed: float,
	terrain_step: float,
	world_width: float,
	snow_line_y: float,
	uphill_reference_slope: float,
	slide_slope: float,
	slide_speed: float,
	drive_mult: float,
	uphill_slow_mult: float
) -> Dictionary:
	var direction: float = input_direction
	var speed: float = base_speed
	if not is_snow_at_x(points, x, terrain_step, snow_line_y):
		return {"direction": direction, "speed": speed, "blocked": false}

	var slope: float = slope_at_x(points, x, terrain_step, world_width)
	# Positive slope means downhill to the right; negative means downhill to the left.
	var downhill_direction: float = signf(slope)
	var moving_uphill: bool = input_direction != 0.0 and downhill_direction != 0.0 and signf(input_direction) == -downhill_direction

	if input_direction == 0.0 and absf(slope) > slide_slope:
		direction = downhill_direction
		speed = slide_speed
	elif moving_uphill:
		var steepness: float = clampf(absf(slope) / maxf(uphill_reference_slope, 0.01), 0.0, 1.6)
		var uphill_mult: float = clampf(lerpf(drive_mult, uphill_slow_mult, steepness), uphill_slow_mult, drive_mult)
		speed *= uphill_mult
	else:
		speed *= drive_mult
		if input_direction != 0.0 and signf(input_direction) == downhill_direction and absf(slope) > slide_slope:
			speed += slide_speed * 0.45
	return {"direction": direction, "speed": speed, "blocked": false}

static func snow_segments(points: Array[Vector2], snow_line_y: float) -> Array[Array]:
	var segments: Array[Array] = []
	var current: Array[Vector2] = []
	for point: Vector2 in points:
		if point.y <= snow_line_y:
			current.append(point)
		else:
			if current.size() >= 2:
				segments.append(current)
			current = []
	if current.size() >= 2:
		segments.append(current)
	return segments

static func snow_face_polygons(points: Array[Vector2], snow_line_y: float, shadow_lerp: float) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	for segment: Array in snow_segments(points, snow_line_y):
		if segment.size() < 2:
			continue
		var face: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in segment:
			face.append(point)
		for i: int in range(segment.size() - 1, -1, -1):
			var point: Vector2 = segment[i]
			face.append(Vector2(point.x, snow_line_y))

		var shadow: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in segment:
			shadow.append(Vector2(point.x, lerpf(point.y, snow_line_y, shadow_lerp)))
		for i: int in range(segment.size() - 1, -1, -1):
			var point: Vector2 = segment[i]
			shadow.append(Vector2(point.x, snow_line_y))

		faces.append({"face": face, "shadow": shadow})
	return faces
