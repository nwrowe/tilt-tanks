extends RefCounted
class_name WeaponDefinition

# Data object for one weapon type. This is intentionally passive so weapon data
# can be migrated out of hardcoded dictionaries and bridge scripts without
# changing runtime behavior all at once.

var id: String = ""
var display_name: String = ""
var explosion_radius: float = 64.0
var direct_radius: float = 22.0
var direct_damage: int = 75
var splash_damage: int = 62
var crater_radius: float = 58.0
var crater_depth: float = 48.0
var projectile_scale: float = 1.0
var split_behavior: String = "none"
var child_weapon_id: String = ""
var child_count: int = 0
var player_selectable: bool = true
var menu_order: int = 0

func _init(data: Dictionary = {}) -> void:
	id = str(data.get("id", id))
	display_name = str(data.get("display_name", display_name))
	explosion_radius = float(data.get("explosion_radius", explosion_radius))
	direct_radius = float(data.get("direct_radius", direct_radius))
	direct_damage = int(data.get("direct_damage", direct_damage))
	splash_damage = int(data.get("splash_damage", splash_damage))
	crater_radius = float(data.get("crater_radius", crater_radius))
	crater_depth = float(data.get("crater_depth", crater_depth))
	projectile_scale = float(data.get("projectile_scale", projectile_scale))
	split_behavior = str(data.get("split_behavior", split_behavior))
	child_weapon_id = str(data.get("child_weapon_id", child_weapon_id))
	child_count = int(data.get("child_count", child_count))
	player_selectable = bool(data.get("player_selectable", player_selectable))
	menu_order = int(data.get("menu_order", menu_order))

func has_split_behavior() -> bool:
	return split_behavior != "" and split_behavior != "none" and child_count > 0 and child_weapon_id != ""

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"explosion_radius": explosion_radius,
		"direct_radius": direct_radius,
		"direct_damage": direct_damage,
		"splash_damage": splash_damage,
		"crater_radius": crater_radius,
		"crater_depth": crater_depth,
		"projectile_scale": projectile_scale,
		"split_behavior": split_behavior,
		"child_weapon_id": child_weapon_id,
		"child_count": child_count,
		"player_selectable": player_selectable,
		"menu_order": menu_order
	}
