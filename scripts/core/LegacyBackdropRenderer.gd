extends RefCounted
class_name LegacyBackdropRenderer

## Draw-only helper for the old stylized mountain silhouette. Called from
## the active CanvasItem's _draw; it owns no gameplay state or inheritance.
static func mountain_polygon(view_size: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-120.0, view_size.y))
	for i: int in range(10):
		var x: float = float(i) * 150.0 - 120.0
		var y: float = 295.0 + 48.0 * sin(float(i) * 1.7)
		points.append(Vector2(x, y))
	points.append(Vector2(view_size.x + 120.0, view_size.y))
	return points

static func draw_distant_mountains(canvas: CanvasItem, view_size: Vector2) -> void:
	canvas.draw_colored_polygon(mountain_polygon(view_size), Color(0.08, 0.10, 0.13))
