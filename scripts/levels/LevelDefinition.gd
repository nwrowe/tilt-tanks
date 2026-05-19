extends RefCounted
class_name LevelDefinition

# Passive data object for one level/world profile.
# This allows terrain, water, snow, wind, spawn rules, and weapon/loadout
# restrictions to move out of runtime bridge constants over time.

var id: String = "default"
var display_name: String = "Default Hills"
var world_width_min: float = 1500.0
var world_width_max: float = 1500.0
var terrain_min_y: float = 255.0
var terrain_max_y: float = 500.0
var start_min_y: float = 285.0
var start_max_y: float = 390.0
var wind_max_accel: float = 85.0
var pond_chance: float = 0.0
var snow_line_y: float = -999999.0
var default_weapon_ids: Array[String] = []
var background_id: String = "default"

func _init(data: Dictionary = {}) -> void:
	id = str(data.get("id", id))
	display_name = str(data.get("display_name", display_name))
	world_width_min = float(data.get("world_width_min", world_width_min))
	world_width_max = float(data.get("world_width_max", world_width_max))
	terrain_min_y = float(data.get("terrain_min_y", terrain_min_y))
	terrain_max_y = float(data.get("terrain_max_y", terrain_max_y))
	start_min_y = float(data.get("start_min_y", start_min_y))
	start_max_y = float(data.get("start_max_y", start_max_y))
	wind_max_accel = float(data.get("wind_max_accel", wind_max_accel))
	pond_chance = float(data.get("pond_chance", pond_chance))
	snow_line_y = float(data.get("snow_line_y", snow_line_y))
	default_weapon_ids = _string_array(data.get("default_weapon_ids", default_weapon_ids))
	background_id = str(data.get("background_id", background_id))

static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result

func has_weapon_restrictions() -> bool:
	return not default_weapon_ids.is_empty()
