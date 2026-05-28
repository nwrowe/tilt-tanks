extends RefCounted
class_name TankUpgradeDefinition

# Data object for one tank upgrade option.
# Examples: barrel stabilizer, reinforced armor, tracks, cope cage, engine tune.

var id: String = ""
var display_name: String = ""
var slot_id: String = ""
var tier: int = 1
var purchase_cost: int = 0
var description: String = ""
var stat_modifiers: Dictionary = {}
var required_tank_tier: int = 1
var required_upgrade_ids: Array[String] = []
var incompatible_upgrade_ids: Array[String] = []
var extra_fields: Dictionary = {}

func _init(data: Dictionary = {}) -> void:
	extra_fields = data.duplicate(true)
	id = str(data.get("id", id))
	display_name = str(data.get("display_name", display_name))
	slot_id = str(data.get("slot_id", slot_id))
	tier = int(data.get("tier", tier))
	purchase_cost = int(data.get("purchase_cost", purchase_cost))
	description = str(data.get("description", description))
	stat_modifiers = _duplicate_dictionary(data.get("stat_modifiers", stat_modifiers))
	required_tank_tier = int(data.get("required_tank_tier", required_tank_tier))
	required_upgrade_ids = _string_array_from(data.get("required_upgrade_ids", required_upgrade_ids))
	incompatible_upgrade_ids = _string_array_from(data.get("incompatible_upgrade_ids", incompatible_upgrade_ids))

func modifies_stat(stat_id: String) -> bool:
	return stat_modifiers.has(stat_id)

func stat_delta(stat_id: String) -> float:
	return float(stat_modifiers.get(stat_id, 0.0))

func prerequisites_met(installed_upgrade_ids: Array[String]) -> bool:
	for required_id: String in required_upgrade_ids:
		if not installed_upgrade_ids.has(required_id):
			return false
	for blocked_id: String in incompatible_upgrade_ids:
		if installed_upgrade_ids.has(blocked_id):
			return false
	return true

func to_dictionary() -> Dictionary:
	var data: Dictionary = extra_fields.duplicate(true)
	data["id"] = id
	data["display_name"] = display_name
	data["slot_id"] = slot_id
	data["tier"] = tier
	data["purchase_cost"] = purchase_cost
	data["description"] = description
	data["stat_modifiers"] = stat_modifiers.duplicate(true)
	data["required_tank_tier"] = required_tank_tier
	data["required_upgrade_ids"] = required_upgrade_ids.duplicate()
	data["incompatible_upgrade_ids"] = incompatible_upgrade_ids.duplicate()
	return data

static func _duplicate_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func _string_array_from(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result
