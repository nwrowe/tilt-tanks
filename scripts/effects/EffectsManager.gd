extends RefCounted
class_name EffectsManager

static func make_puff(pos: Vector2, life: float, drift: float, age: float = 0.0) -> Dictionary:
	return {
		"pos": pos,
		"age": age,
		"life": life,
		"drift": drift
	}

static func update_rising_puffs(puffs: Array[Dictionary], delta: float, rise_speed: float) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = []
	for puff: Dictionary in puffs:
		var age: float = float(puff.get("age", 0.0)) + delta
		var life: float = float(puff.get("life", 1.0))
		if age < life:
			var updated: Dictionary = puff.duplicate(true)
			var pos: Vector2 = updated.get("pos", Vector2.ZERO)
			var drift: float = float(updated.get("drift", 0.0))
			pos.x += drift * delta
			pos.y -= rise_speed * delta
			updated["age"] = age
			updated["pos"] = pos
			remaining.append(updated)
	return remaining

static func recoil_tip(base: Vector2, facing: float, angle_deg: float, cannon_length: float, recoil_distance: float, scale: float) -> Vector2:
	var rad: float = deg_to_rad(angle_deg)
	var length: float = maxf(10.0, cannon_length - recoil_distance)
	return base + Vector2(facing * length * scale * cos(rad), -length * scale * sin(rad))

static func cannon_tip_world(base: Vector2, facing: float, angle_deg: float, cannon_length: float) -> Vector2:
	var rad: float = deg_to_rad(angle_deg)
	return base + Vector2(facing * cannon_length * cos(rad), -cannon_length * sin(rad))

static func effect_alpha(age: float, life: float, base_alpha: float) -> float:
	if life <= 0.0:
		return 0.0
	var t: float = clampf(age / life, 0.0, 1.0)
	return base_alpha * (1.0 - t)

static func effect_radius(age: float, life: float, start_radius: float, end_radius: float) -> float:
	if life <= 0.0:
		return end_radius
	var t: float = clampf(age / life, 0.0, 1.0)
	return lerpf(start_radius, end_radius, t)

## Draw shared smoke circles with the exact camera transform and fade
## used by the former scene-specific muzzle/destroyed-smoke loops.
static func draw_rising_puffs(
	canvas: CanvasItem, puffs: Array[Dictionary],
	camera_x: float, camera_scale: float, camera_y_offset: float,
	default_life: float, start_radius: float, end_radius: float,
	base_alpha: float, color: Color
) -> void:
	for puff: Dictionary in puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", default_life))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = effect_radius(age, life, start_radius, end_radius) * camera_scale
		var alpha: float = effect_alpha(age, life, base_alpha)
		var screen_pos: Vector2 = Vector2(
			(pos.x - camera_x) * camera_scale,
			pos.y * camera_scale + camera_y_offset
		)
		canvas.draw_circle(
			screen_pos, radius, Color(color.r, color.g, color.b, alpha)
		)

## One explosion drawing sequence for base and weapon runtimes.
## The caller owns lifetime, center transform, and weapon-specific radius.
static func draw_explosion(
	canvas: CanvasItem, center: Vector2,
	elapsed_ratio: float, radius_pixels: float
) -> void:
	var outer_radius: float = radius_pixels * (0.55 + 0.65 * elapsed_ratio)
	var inner_radius: float = outer_radius * 0.48
	canvas.draw_circle(center, outer_radius, Color(
		1.0, 0.42, 0.06, 0.42 * (1.0 - elapsed_ratio)
	))
	canvas.draw_circle(center, inner_radius, Color(
		1.0, 0.88, 0.20, 0.75 * (1.0 - elapsed_ratio)
	))
	for i: int in range(8):
		var a: float = TAU * float(i) / 8.0
		var ray_end: Vector2 = center + Vector2(cos(a), sin(a)) * outer_radius * 1.15
		canvas.draw_line(center, ray_end, Color(
			1.0, 0.75, 0.15, 0.45 * (1.0 - elapsed_ratio)
		), 2.0)
