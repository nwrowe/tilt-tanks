extends RefCounted
class_name TankClassDefinition

# Data object for a purchasable tank class/chassis.
# Higher class tiers can support stronger stats, higher upgrade tiers, more crew,
# and broader weapon/loadout options.

var id: String = ""
var display_name: String = ""
var tier: int = 1
var purchase_cost: int = 0
var description: String = ""

var base_stats: Dictionary = {}
var stat_caps: Dictionary = {}
var slot_limits: Dictionary = {}
var crew_slots: Dictionary = {}
var allowed_weapon_ids: Array[String] = []
var max_weapon_tier: int = 1
var max_upgrade_tier: int = 1
var extra_fields: Dictionary = {}

func _init(data: Dictionary = {}) -> void:
	extra_fields = data.duplicate(true)
	id = str(data.get("id", id))
	display_name = str(data.get("display_name", display_name))
	tier = int(data.get("tier", tier))
	purchase_cost = int(data.get("purchase_cost", purchase_cost))
	description = str(data.get("description", description))
	base_stats = _duplicate_dictionary(data.get("base_stats", base_stats))
	stat_caps = _duplicate_dictionary(data.get("stat_caps", stat_caps))
	slot_limits = _duplicate_dictionary(data.get("slot_limits", slot_limits))
	crew_slots = _duplicate_dictionary(data.get("crew_slots", crew_slots))
	allowed_weapon_ids = _string_array_from(data.get("allowed_weapon_ids", allowed_weapon_ids))
	max_weapon_tier = int(data.get("max_weapon_tier", max_weapon_tier))
	max_upgrade_tier = int(data.get("max_upgrade_tier", max_upgrade_tier))

func slot_limit(slot_id: String) -> int:
	return int(slot_limits.get(slot_id, 0))

func supports_upgrade_slot(slot_id: String) -> bool:
	return slot_limit(slot_id) > 0

func crew_slot_limit(role_id: String) -> int:
	return int(crew_slots.get(role_id, 0))

func supports_crew_role(role_id: String) -> bool:
	return crew_slot_limit(role_id) > 0

func allows_weapon(weapon_id: String) -> bool:
	return allowed_weapon_ids.is_empty() or allowed_weapon_ids.has(weapon_id)

func capped_stat(stat_id: String, value: float) -> float:
	if stat_caps.has(stat_id):
		return minf(value, float(stat_caps[stat_id]))
	return value

func to_dictionary() -> Dictionary:
	var data: Dictionary = extra_fields.duplicate(true)
	data["id"] = id
	data["display_name"] = display_name
	data["tier"] = tier
	data["purchase_cost"] = purchase_cost
	data["description"] = description
	data["base_stats"] = base_stats.duplicate(true)
	data["stat_caps"] = stat_caps.duplicate(true)
	data["slot_limits"] = slot_limits.duplicate(true)
	data["crew_slots"] = crew_slots.duplicate(true)
	data["allowed_weapon_ids"] = allowed_weapon_ids.duplicate()
	data["max_weapon_tier"] = max_weapon_tier
	data["max_upgrade_tier"] = max_upgrade_tier
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
