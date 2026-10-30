extends RefCounted
class_name WindMeterPolicy

## The wind meter's presentation values are independent from the game scene.
## WorldRuntimeBridge and the legacy fallback draw path keep their original
## placement, opacity and direct Godot drawing calls.

static func display_value(wind: float, max_accel: float, max_display: float) -> float:
	return clampf(wind / max_accel * max_display, -max_display, max_display)

static func strength(display_wind: float, max_display: float) -> float:
	return clampf(absf(display_wind) / max_display, 0.0, 1.0)

static func strength_color(value: float) -> Color:
	var s: float = clampf(value, 0.0, 1.0)
	if s < 0.55:
		return Color(0.35, 0.95, 0.35, 0.92)
	if s < 0.82:
		var t: float = (s - 0.55) / 0.27
		return Color(lerpf(0.35, 1.0, t), 0.95, lerpf(0.35, 0.08, t), 0.92)
	var t2: float = (s - 0.82) / 0.18
	return Color(1.0, lerpf(0.95, 0.12, t2), 0.08, 0.92)

static func arrow_points(tip: Vector2, direction: float) -> PackedVector2Array:
	var d: float = signf(direction)
	if d == 0.0:
		return PackedVector2Array()
	var p1: Vector2 = tip
	var p2: Vector2 = tip + Vector2(-8.0 * d, -6.0)
	var p3: Vector2 = tip + Vector2(-8.0 * d, 6.0)
	return PackedVector2Array([p1, p2, p3])
