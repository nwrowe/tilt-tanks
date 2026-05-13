extends "res://scripts/MainHybridModes12.gd"

const SNOW_UPHILL_SLOW_MULT: float = 0.28
const SNOW_FACE_ALPHA: float = 0.86
const SNOW_FACE_SHADOW_ALPHA: float = 0.24

func _draw_snow_caps() -> void:
	_draw_snow_faces()
	_draw_snow_surface_highlights()

func _draw_snow_faces() -> void:
	if terrain_points.size() < 2:
		return
	var segment: Array[Vector2] = []
	for i: int in range(terrain_points.size()):
		var p: Vector2 = terrain_points[i]
		if p.y <= SNOW_LINE_Y:
			segment.append(p)
		else:
			_draw_snow_face_segment(segment)
			segment.clear()
	_draw_snow_face_segment(segment)

func _draw_snow_face_segment(segment: Array[Vector2]) -> void:
	if segment.size() < 2:
		return
	var poly: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in segment:
		poly.append(_world_to_screen(p))
	for i: int in range(segment.size() - 1, -1, -1):
		poly.append(_world_to_screen(Vector2(segment[i].x, SNOW_LINE_Y)))
	draw_colored_polygon(poly, Color(0.90, 0.95, 1.0, SNOW_FACE_ALPHA))

	var shadow_poly: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in segment:
		shadow_poly.append(_world_to_screen(Vector2(p.x, lerpf(p.y, SNOW_LINE_Y, 0.62))))
	for i: int in range(segment.size() - 1, -1, -1):
		shadow_poly.append(_world_to_screen(Vector2(segment[i].x, SNOW_LINE_Y)))
	if shadow_poly.size() >= 3:
		draw_colored_polygon(shadow_poly, Color(0.62, 0.78, 1.0, SNOW_FACE_SHADOW_ALPHA))

func _draw_snow_surface_highlights() -> void:
	var segment: PackedVector2Array = PackedVector2Array()
	for i: int in range(terrain_points.size()):
		var p: Vector2 = terrain_points[i]
		if p.y <= SNOW_LINE_Y:
			segment.append(_world_to_screen(p))
		else:
			_draw_snow_highlight_segment(segment)
			segment = PackedVector2Array()
	_draw_snow_highlight_segment(segment)

func _draw_snow_highlight_segment(segment: PackedVector2Array) -> void:
	if segment.size() < 2:
		return
	for i: int in range(segment.size() - 1):
		draw_line(segment[i], segment[i + 1], Color(0.98, 1.0, 1.0, 0.96), 3.5)
		draw_line(segment[i] + Vector2(0, 5), segment[i + 1] + Vector2(0, 5), Color(0.68, 0.82, 1.0, 0.28), 1.5)

func _snow_adjusted_direction_and_speed(x: float, input_direction: float, base_speed: float) -> Dictionary:
	var direction: float = input_direction
	var speed: float = base_speed
	if not _is_snow_at_x(x):
		return {"direction": direction, "speed": speed, "blocked": false}

	var slope: float = _terrain_slope_at_x(x)
	var downhill_direction: float = signf(slope)
	var moving_uphill: bool = input_direction != 0.0 and downhill_direction != 0.0 and signf(input_direction) == -downhill_direction

	if input_direction == 0.0 and absf(slope) > SNOW_SLIDE_SLOPE:
		direction = downhill_direction
		speed = SNOW_SLIDE_SPEED
	elif moving_uphill:
		var steepness: float = clampf(absf(slope) / maxf(SNOW_UPHILL_BLOCK_SLOPE, 0.01), 0.0, 1.6)
		var uphill_mult: float = clampf(lerpf(SNOW_DRIVE_MULT, SNOW_UPHILL_SLOW_MULT, steepness), SNOW_UPHILL_SLOW_MULT, SNOW_DRIVE_MULT)
		speed *= uphill_mult
	else:
		speed *= SNOW_DRIVE_MULT
		if input_direction != 0.0 and signf(input_direction) == downhill_direction and absf(slope) > SNOW_SLIDE_SLOPE:
			speed += SNOW_SLIDE_SPEED * 0.45
	return {"direction": direction, "speed": speed, "blocked": false}
