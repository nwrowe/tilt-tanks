extends RefCounted
class_name MainMenuPresentation

## Geometry and fallback drawing for the main menu. No menu state, callbacks,
## scene references or resource loading are owned by this component.
static func anchored_position(viewport_size: Vector2, anchor: Vector2, size: Vector2) -> Vector2:
	return Vector2(viewport_size.x * anchor.x - size.x * 0.5, viewport_size.y * anchor.y - size.y * 0.5)

static func logo_rect(viewport_size: Vector2, use_landscape: bool, texture_size: Vector2) -> Rect2:
	var target_width: float = viewport_size.x * (0.36 if use_landscape else 0.70)
	var aspect: float = texture_size.x / texture_size.y
	var target_size: Vector2 = Vector2(target_width, target_width / aspect)
	var y: float = viewport_size.y * (0.12 if use_landscape else 0.09)
	return Rect2(Vector2((viewport_size.x - target_size.x) * 0.5, y), target_size)

static func fallback_mountains(viewport_size: Vector2) -> PackedVector2Array:
	var horizon_y: float = viewport_size.y * 0.56
	var mountains: PackedVector2Array = PackedVector2Array()
	mountains.append(Vector2(0, horizon_y + 85.0))
	for i: int in range(8):
		var x: float = viewport_size.x * float(i) / 7.0
		var y: float = horizon_y + 80.0 - 90.0 * absf(sin(float(i) * 1.37))
		mountains.append(Vector2(x, y))
	mountains.append(Vector2(viewport_size.x, horizon_y + 85.0))
	return mountains

static func fallback_hill(viewport_size: Vector2) -> PackedVector2Array:
	var hill_y: float = viewport_size.y * 0.72
	var hill: PackedVector2Array = PackedVector2Array()
	hill.append(Vector2(0, viewport_size.y))
	for i: int in range(30):
		var x: float = viewport_size.x * float(i) / 29.0
		var y: float = hill_y + 32.0 * sin(float(i) * 0.42)
		hill.append(Vector2(x, y))
	hill.append(Vector2(viewport_size.x, viewport_size.y))
	return hill

static func draw_fallback_background(canvas: CanvasItem, viewport_size: Vector2) -> void:
	for i: int in range(8):
		var t: float = float(i) / 7.0
		var y0: float = viewport_size.y * t
		var color: Color = Color(0.04 + 0.15 * t, 0.05, 0.16 + 0.20 * t)
		canvas.draw_rect(
			Rect2(Vector2(0, y0), Vector2(viewport_size.x, viewport_size.y / 7.0 + 2.0)),
			color, true
		)
	canvas.draw_circle(Vector2(viewport_size.x * 0.5, viewport_size.y * 0.56), 24.0, Color(1.0, 0.78, 0.18, 0.95))
	canvas.draw_colored_polygon(fallback_mountains(viewport_size), Color(0.19, 0.11, 0.32, 0.95))
	canvas.draw_colored_polygon(fallback_hill(viewport_size), Color(0.08, 0.25, 0.08, 1.0))
