extends RefCounted
class_name LevelRegistry

const LEVEL_DEFAULT: String = "default"
const LEVEL_WIDE_HILLS: String = "wide_hills"
const LEVEL_SNOWY_RIDGE: String = "snowy_ridge"
const LEVEL_WATER_BASIN: String = "water_basin"

static func build_default_levels() -> Dictionary:
	return {
		LEVEL_DEFAULT: LevelDefinition.new({
			"id": LEVEL_DEFAULT,
			"display_name": "Default Hills"
		}),
		LEVEL_WIDE_HILLS: LevelDefinition.new({
			"id": LEVEL_WIDE_HILLS,
			"display_name": "Wide Hills",
			"world_width_min": 1800.0,
			"world_width_max": 2300.0,
			"background_id": "hills"
		}),
		LEVEL_SNOWY_RIDGE: LevelDefinition.new({
			"id": LEVEL_SNOWY_RIDGE,
			"display_name": "Snowy Ridge",
			"snow_line_y": 315.0,
			"background_id": "snow"
		}),
		LEVEL_WATER_BASIN: LevelDefinition.new({
			"id": LEVEL_WATER_BASIN,
			"display_name": "Water Basin",
			"pond_chance": 1.0,
			"background_id": "water"
		})
	}

static func get_level(levels: Dictionary, level_id: String) -> LevelDefinition:
	if levels.has(level_id):
		return levels[level_id] as LevelDefinition
	return levels.get(LEVEL_DEFAULT, LevelDefinition.new()) as LevelDefinition

static func all_level_ids(levels: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id: String in levels.keys():
		ids.append(id)
	ids.sort()
	return ids
