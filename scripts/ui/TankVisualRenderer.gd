extends RefCounted
class_name TankVisualRenderer

## Draws the shared tank silhouette for the base and weapon runtimes.
## Scene ownership of camera transforms and barrel-angle selection stays
## with the caller. The barrel anchor/width are deliberately parameters:
## the weapon runtime and legacy base render slightly different barrels.

static func tread_polygon(center: Vector2, scale: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-25, 8) * scale,
		center + Vector2(25, 8) * scale,
		center + Vector2(30, 16) * scale,
		center + Vector2(22, 22) * scale,
		center + Vector2(-22, 22) * scale,
		center + Vector2(-30, 16) * scale
	])

static func body_polygon(center: Vector2, scale: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-22, 5) * scale,
		center + Vector2(22, 5) * scale,
		center + Vector2(16, -10) * scale,
		center + Vector2(-16, -10) * scale
	])

static func barrel_segment(
	center: Vector2, facing: float, scale: float,
	cannon_length: float, angle: float, anchor: Vector2
) -> PackedVector2Array:
	var start: Vector2 = center + Vector2(anchor.x * facing, anchor.y) * scale
	var rad: float = deg_to_rad(angle)
	return PackedVector2Array([
		start,
		start + Vector2(
			facing * cannon_length * cos(rad), -cannon_length * sin(rad)
		) * scale
	])

static func draw_tank(
	canvas: CanvasItem, center: Vector2, facing: float,
	scale: float, color: Color, show_barrel: bool,
	angle: float, cannon_length: float,
	barrel_anchor: Vector2, barrel_width: float
) -> void:
	canvas.draw_colored_polygon(tread_polygon(center, scale), Color(
		color.r * 0.45, color.g * 0.45, color.b * 0.45
	))
	canvas.draw_line(
		center + Vector2(-24, 15) * scale,
		center + Vector2(24, 15) * scale, Color.BLACK, 3.0
	)
	canvas.draw_colored_polygon(body_polygon(center, scale), color)
	canvas.draw_circle(center + Vector2(0, -13) * scale, 12.0 * scale, color)
	if show_barrel:
		var ends: PackedVector2Array = barrel_segment(
			center, facing, scale, cannon_length, angle, barrel_anchor
		)
		canvas.draw_line(ends[0], ends[1], Color.WHITE, barrel_width)
	for wheel_x: float in [-18.0, 0.0, 18.0]:
		canvas.draw_circle(center + Vector2(wheel_x, 16) * scale, 4.0 * scale, Color.BLACK)
