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
