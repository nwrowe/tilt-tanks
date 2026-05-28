extends RefCounted
class_name CrewMemberDefinition

# Data object for a crew member assigned to a tank role.
# Inspired by FTL-style crew: role, level, XP, and stat modifiers that can improve
# tank performance over time.

var id: String = ""
var display_name: String = ""
var role_id: String = ""
var level: int = 1
var experience: int = 0
var max_level: int = 3
var training_cost: int = 0
var description: String = ""
var level_stat_modifiers: Dictionary = {}
var extra_fields: Dictionary = {}

func _init(data: Dictionary = {}) -> void:
	extra_fields = data.duplicate(true)
	id = str(data.get("id", id))
	display_name = str(data.get("display_name", display_name))
	role_id = str(data.get("role_id", role_id))
	level = int(data.get("level", level))
	experience = int(data.get("experience", experience))
	max_level = int(data.get("max_level", max_level))
	training_cost = int(data.get("training_cost", training_cost))
	description = str(data.get("description", description))
	level_stat_modifiers = _duplicate_dictionary(data.get("level_stat_modifiers", level_stat_modifiers))

func effective_level() -> int:
	return clampi(level, 1, max_level)

func stat_delta(stat_id: String) -> float:
	var total: float = 0.0
	for step: int in range(1, effective_level() + 1):
		var level_key: String = str(step)
		if level_stat_modifiers.has(level_key):
			var modifiers: Variant = level_stat_modifiers[level_key]
			if modifiers is Dictionary:
				total += float((modifiers as Dictionary).get(stat_id, 0.0))
	return total

func can_train() -> bool:
	return level < max_level

func trained_copy() -> CrewMemberDefinition:
	var data: Dictionary = to_dictionary()
	data["level"] = min(level + 1, max_level)
	return CrewMemberDefinition.new(data)

func to_dictionary() -> Dictionary:
	var data: Dictionary = extra_fields.duplicate(true)
	data["id"] = id
	data["display_name"] = display_name
	data["role_id"] = role_id
	data["level"] = level
	data["experience"] = experience
	data["max_level"] = max_level
	data["training_cost"] = training_cost
	data["description"] = description
	data["level_stat_modifiers"] = level_stat_modifiers.duplicate(true)
	return data

static func _duplicate_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
