extends RefCounted
class_name TankBuildState

# Passive per-player tank build state.
# This records chassis/class, installed upgrades, assigned crew, and resources.
# It does not mutate combat directly; runtime integration should read the
# effective stats produced here.

var player_index: int = 0
var tank_class_id: String = "scout"
var installed_upgrade_ids: Array[String] = []
var assigned_crew_ids: Array[String] = []
var unlocked_weapon_ids: Array[String] = []
var credits: int = 0
var extra_fields: Dictionary = {}

func _init(data: Dictionary = {}) -> void:
	extra_fields = data.duplicate(true)
	player_index = int(data.get("player_index", player_index))
	tank_class_id = str(data.get("tank_class_id", tank_class_id))
	installed_upgrade_ids = _string_array_from(data.get("installed_upgrade_ids", installed_upgrade_ids))
	assigned_crew_ids = _string_array_from(data.get("assigned_crew_ids", assigned_crew_ids))
	unlocked_weapon_ids = _string_array_from(data.get("unlocked_weapon_ids", unlocked_weapon_ids))
	credits = int(data.get("credits", credits))

func has_upgrade(upgrade_id: String) -> bool:
	return installed_upgrade_ids.has(upgrade_id)

func has_crew(crew_id: String) -> bool:
	return assigned_crew_ids.has(crew_id)

func has_weapon_unlocked(weapon_id: String) -> bool:
	return unlocked_weapon_ids.is_empty() or unlocked_weapon_ids.has(weapon_id)

func with_upgrade(upgrade_id: String) -> TankBuildState:
	var data: Dictionary = to_dictionary()
	var upgrades: Array[String] = installed_upgrade_ids.duplicate()
	if not upgrades.has(upgrade_id):
		upgrades.append(upgrade_id)
	data["installed_upgrade_ids"] = upgrades
	return TankBuildState.new(data)

func with_crew(crew_id: String) -> TankBuildState:
	var data: Dictionary = to_dictionary()
	var crew: Array[String] = assigned_crew_ids.duplicate()
	if not crew.has(crew_id):
		crew.append(crew_id)
	data["assigned_crew_ids"] = crew
	return TankBuildState.new(data)

func to_dictionary() -> Dictionary:
	var data: Dictionary = extra_fields.duplicate(true)
	data["player_index"] = player_index
	data["tank_class_id"] = tank_class_id
	data["installed_upgrade_ids"] = installed_upgrade_ids.duplicate()
	data["assigned_crew_ids"] = assigned_crew_ids.duplicate()
	data["unlocked_weapon_ids"] = unlocked_weapon_ids.duplicate()
	data["credits"] = credits
	return data

static func _string_array_from(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result
