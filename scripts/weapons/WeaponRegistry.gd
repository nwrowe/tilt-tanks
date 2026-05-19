extends RefCounted
class_name WeaponRegistry

# Compatibility registry for data-driven weapon definitions.
# Initially this wraps the existing WeaponCatalog values so active gameplay can
# migrate gradually without changing weapon balance or behavior.

const SPLIT_NONE: String = "none"
const SPLIT_CLUSTER: String = "cluster"

static func build_default_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	_register_from_catalog(definitions, WeaponCatalog.STANDARD, SPLIT_NONE, "", 0)
	_register_from_catalog(definitions, WeaponCatalog.HEAVY, SPLIT_NONE, "", 0)
	_register_from_catalog(definitions, WeaponCatalog.CLUSTER, SPLIT_CLUSTER, WeaponCatalog.CLUSTER_CHILD, 3)
	_register_from_catalog(definitions, WeaponCatalog.CLUSTER_CHILD, SPLIT_NONE, "", 0)
	return definitions

static func _register_from_catalog(definitions: Dictionary, weapon_id: String, split_behavior: String, child_weapon_id: String, child_count: int) -> void:
	definitions[weapon_id] = WeaponDefinition.new({
		"id": weapon_id,
		"display_name": WeaponCatalog.display_name(weapon_id),
		"explosion_radius": WeaponCatalog.value(weapon_id, "explosion_radius", 64.0),
		"direct_radius": WeaponCatalog.value(weapon_id, "direct_radius", 22.0),
		"direct_damage": WeaponCatalog.value(weapon_id, "direct_damage", 75),
		"splash_damage": WeaponCatalog.value(weapon_id, "splash_damage", 62),
		"crater_radius": WeaponCatalog.value(weapon_id, "crater_radius", 58.0),
		"crater_depth": WeaponCatalog.value(weapon_id, "crater_depth", 48.0),
		"projectile_scale": WeaponCatalog.value(weapon_id, "projectile_scale", 1.0),
		"split_behavior": split_behavior,
		"child_weapon_id": child_weapon_id,
		"child_count": child_count
	})

static func get_definition(definitions: Dictionary, weapon_id: String) -> WeaponDefinition:
	if definitions.has(weapon_id):
		return definitions[weapon_id] as WeaponDefinition
	return definitions.get(WeaponCatalog.STANDARD, WeaponDefinition.new({"id": WeaponCatalog.STANDARD, "display_name": "Standard Shell"})) as WeaponDefinition

static func value(definitions: Dictionary, weapon_id: String, key: String, fallback: Variant) -> Variant:
	var definition: WeaponDefinition = get_definition(definitions, weapon_id)
	return definition.to_dictionary().get(key, fallback)

static func display_name(definitions: Dictionary, weapon_id: String) -> String:
	return str(value(definitions, weapon_id, "display_name", "Standard Shell"))

static func all_player_selectable_ids(definitions: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for weapon_id: String in definitions.keys():
		var definition: WeaponDefinition = definitions[weapon_id] as WeaponDefinition
		if definition != null and weapon_id != WeaponCatalog.CLUSTER_CHILD:
			ids.append(weapon_id)
	return ids
