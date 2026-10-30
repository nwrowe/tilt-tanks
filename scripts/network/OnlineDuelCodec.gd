extends RefCounted
class_name OnlineDuelCodec

## Pure, reusable wire-data conversion. Does not depend on the scene or ENet.
## Keep existing packet representations stable for compatibility with clients.
static func pack_vec2(value: Vector2) -> Dictionary:
	if value == Vector2.INF:
		return {"x": INF, "y": INF}
	return {"x": value.x, "y": value.y}

static func unpack_vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Dictionary:
		var data: Dictionary = value as Dictionary
		return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	return Vector2.ZERO

static func pack_vec2_array(values: Array) -> Array:
	var packed: Array = []
	for value: Variant in values:
		if value is Vector2:
			packed.append(pack_vec2(value as Vector2))
	return packed

static func float_array(value: Variant, fallback: Array) -> Array:
	var result: Array = []
	if value is Array:
		for entry: Variant in value:
			result.append(float(entry))
	else:
		result = fallback.duplicate()
	return result

static func int_array(value: Variant, fallback: Array) -> Array:
	var result: Array = []
	if value is Array:
		for entry: Variant in value:
			result.append(int(entry))
	else:
		result = fallback.duplicate()
	return result

static func safe_requested_weapon(payload: Dictionary, loadout: WeaponLoadout, default_weapon: String) -> String:
	var requested: String = str(payload.get("weapon", default_weapon))
	if loadout == null:
		return default_weapon
	return loadout.safe_weapon(requested)
