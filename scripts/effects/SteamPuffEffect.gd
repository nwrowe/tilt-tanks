extends RefCounted
class_name SteamPuffEffect

## Pure steam-puff simulation and presentation policy. The runtime retains
## its live puff collection and delegates only the calculations. Dictionaries
## are deliberately updated in place, matching the legacy behavior.

static func advance(puffs: Array[Dictionary], delta: float, rise_speed: float, default_life: float) -> Array[Dictionary]:
	if puffs.is_empty():
		return puffs
	var remaining: Array[Dictionary] = []
	for puff: Dictionary in puffs:
		var age: float = float(puff.get("age", 0.0)) + delta
		var life: float = float(puff.get("life", default_life))
		if age < life:
			var pos: Vector2 = puff.get("pos", Vector2.ZERO)
			var drift: float = float(puff.get("drift", 0.0))
			pos.x += drift * delta
			pos.y -= rise_speed * delta
			puff["age"] = age
			puff["pos"] = pos
			remaining.append(puff)
	return remaining

static func appearance(
	puff: Dictionary, default_life: float,
	start_radius: float, end_radius: float, camera_scale: float
) -> Dictionary:
	var age: float = float(puff.get("age", 0.0))
	var life: float = float(puff.get("life", default_life))
	var t: float = clampf(age / life, 0.0, 1.0)
	var pos: Vector2 = puff.get("pos", Vector2.ZERO)
	var radius: float = lerpf(start_radius, end_radius, t) * camera_scale
	var alpha: float = 0.52 * (1.0 - t)
	return {"pos": pos, "radius": radius, "color": Color(0.88, 0.90, 0.86, alpha)}
