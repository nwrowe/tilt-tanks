extends RefCounted
class_name WeaponRegistry

# Compatibility registry for data-driven weapon definitions.
# Active gameplay now uses these definitions as the source of truth for weapon
# stats/menu metadata, while special behaviors are implemented in runtime
# facades only when data alone is insufficient.

const SPLIT_NONE: String = "none"
const SPLIT_CLUSTER: String = "cluster"

const WEAPON_LASER: String = "laser"
const WEAPON_TACTICAL_NUKE: String = "tactical_nuke"
const WEAPON_BOUNCER: String = "bouncer"
const WEAPON_GROUND_BOMB: String = "ground_bomb"
const WEAPON_MACHINE_GUN: String = "machine_gun"
const WEAPON_MACHINE_GUN_ROUND: String = "machine_gun_round"

static func build_default_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	_register_from_catalog(definitions, WeaponCatalog.STANDARD, SPLIT_NONE, "", 0, true, 10)
	_register_from_catalog(definitions, WeaponCatalog.HEAVY, SPLIT_NONE, "", 0, true, 20)
	_register_from_catalog(definitions, WeaponCatalog.CLUSTER, SPLIT_CLUSTER, WeaponCatalog.CLUSTER_CHILD, 3, true, 30)
	_register_from_catalog(definitions, WeaponCatalog.CLUSTER_CHILD, SPLIT_NONE, "", 0, false, 999)

	_register_custom(definitions, {
		"id": WEAPON_LASER,
		"display_name": "Laser Drill",
		"explosion_radius": 18.0,
		"direct_radius": 14.0,
		"direct_damage": 18,
		"splash_damage": 6,
		"crater_radius": 16.0,
		"crater_depth": 130.0,
		"projectile_scale": 0.65,
		"player_selectable": true,
		"menu_order": 40,
		"behavior": "laser_cut",
		"laser_cut_width": 18.0,
		"laser_cut_depth": 180.0
	})

	_register_custom(definitions, {
		"id": WEAPON_TACTICAL_NUKE,
		"display_name": "Tactical Nuke",
		"explosion_radius": 170.0,
		"direct_radius": 52.0,
		"direct_damage": 125,
		"splash_damage": 110,
		"crater_radius": 155.0,
		"crater_depth": 118.0,
		"projectile_scale": 1.85,
		"player_selectable": true,
		"menu_order": 50,
		"behavior": "slow_large_explosion",
		"explosion_duration": 1.45
	})

	_register_custom(definitions, {
		"id": WEAPON_BOUNCER,
		"display_name": "Bouncing Bomb",
		"explosion_radius": 58.0,
		"direct_radius": 22.0,
		"direct_damage": 68,
		"splash_damage": 54,
		"crater_radius": 54.0,
		"crater_depth": 42.0,
		"projectile_scale": 0.95,
		"player_selectable": true,
		"menu_order": 60,
		"behavior": "bounce",
		"max_bounces": 3,
		"bounce_damping_x": 0.78,
		"bounce_damping_y": 0.66
	})

	_register_custom(definitions, {
		"id": WEAPON_GROUND_BOMB,
		"display_name": "Ground Bomb",
		"explosion_radius": 54.0,
		"direct_radius": 18.0,
		"direct_damage": 12,
		"splash_damage": 8,
		"crater_radius": 68.0,
		"crater_depth": -58.0,
		"projectile_scale": 1.05,
		"player_selectable": true,
		"menu_order": 70,
		"behavior": "add_ground",
		"ground_raise_amount": 58.0
	})

	_register_custom(definitions, {
		"id": WEAPON_MACHINE_GUN,
		"display_name": "Machine Gun",
		"explosion_radius": 18.0,
		"direct_radius": 12.0,
		"direct_damage": 12,
		"splash_damage": 6,
		"crater_radius": 13.0,
		"crater_depth": 8.0,
		"projectile_scale": 0.42,
		"player_selectable": true,
		"menu_order": 80,
		"behavior": "machine_gun",
		"burst_count": 10,
		"burst_interval": 0.1,
		"burst_angle_jitter": 3.0,
		"burst_power_jitter": 7.0,
		"child_weapon_id": WEAPON_MACHINE_GUN_ROUND
	})

	_register_custom(definitions, {
		"id": WEAPON_MACHINE_GUN_ROUND,
		"display_name": "Machine Gun Round",
		"explosion_radius": 18.0,
		"direct_radius": 12.0,
		"direct_damage": 12,
		"splash_damage": 6,
		"crater_radius": 13.0,
		"crater_depth": 8.0,
		"projectile_scale": 0.38,
		"player_selectable": false,
		"menu_order": 1000,
		"behavior": "standard"
	})

	return definitions

static func _register_from_catalog(
	definitions: Dictionary,
	weapon_id: String,
	split_behavior: String,
	child_weapon_id: String,
	child_count: int,
	player_selectable: bool,
	menu_order: int
) -> void:
	_register_custom(definitions, {
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
		"child_count": child_count,
		"player_selectable": player_selectable,
		"menu_order": menu_order,
		"behavior": "standard"
	})

static func _register_custom(definitions: Dictionary, data: Dictionary) -> void:
	definitions[str(data.get("id", WeaponCatalog.STANDARD))] = WeaponDefinition.new(data)

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
		if definition != null and definition.player_selectable:
			ids.append(weapon_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: WeaponDefinition = get_definition(definitions, a)
		var db: WeaponDefinition = get_definition(definitions, b)
		return da.menu_order < db.menu_order
	)
	return ids
