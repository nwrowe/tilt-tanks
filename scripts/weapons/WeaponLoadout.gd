extends RefCounted
class_name WeaponLoadout

# Defines which weapons are available to a player/mode/campaign level.
# This is passive scaffolding for later campaign and multiplayer work.

var weapon_ids: Array[String] = []
var default_weapon_id: String = ""

func _init(ids: Array[String] = [], default_id: String = "") -> void:
	weapon_ids = ids.duplicate()
	default_weapon_id = default_id if default_id != "" else _first_or_empty(weapon_ids)

static func from_registry(definitions: Dictionary, default_id: String = "") -> WeaponLoadout:
	var ids: Array[String] = WeaponRegistry.all_player_selectable_ids(definitions)
	return WeaponLoadout.new(ids, default_id if default_id != "" else _first_or_empty(ids))

static func _first_or_empty(ids: Array[String]) -> String:
	return ids[0] if not ids.is_empty() else ""

func has_weapon(weapon_id: String) -> bool:
	return weapon_ids.has(weapon_id)

func safe_weapon(weapon_id: String) -> String:
	if has_weapon(weapon_id):
		return weapon_id
	return default_weapon_id

func add_weapon(weapon_id: String) -> void:
	if weapon_id != "" and not weapon_ids.has(weapon_id):
		weapon_ids.append(weapon_id)

func remove_weapon(weapon_id: String) -> void:
	weapon_ids.erase(weapon_id)
	if default_weapon_id == weapon_id:
		default_weapon_id = _first_or_empty(weapon_ids)
