extends RefCounted
class_name WeaponCatalog

const STANDARD: String = "standard"
const HEAVY: String = "heavy"
const CLUSTER: String = "cluster"
const CLUSTER_CHILD: String = "cluster_child"

const DATA: Dictionary = {
	STANDARD: {
		"display_name": "Standard Shell",
		"explosion_radius": 64.0,
		"direct_radius": 22.0,
		"direct_damage": 75,
		"splash_damage": 62,
		"crater_radius": 58.0,
		"crater_depth": 48.0,
		"projectile_scale": 1.0
	},
	HEAVY: {
		"display_name": "Heavy Shell",
		"explosion_radius": 86.0,
		"direct_radius": 28.0,
		"direct_damage": 62,
		"splash_damage": 54,
		"crater_radius": 78.0,
		"crater_depth": 62.0,
		"projectile_scale": 1.45
	},
	CLUSTER: {
		"display_name": "Cluster Bomb",
		"explosion_radius": 46.0,
		"direct_radius": 18.0,
		"direct_damage": 36,
		"splash_damage": 31,
		"crater_radius": 40.0,
		"crater_depth": 34.0,
		"projectile_scale": 1.0
	},
	CLUSTER_CHILD: {
		"display_name": "Cluster Fragment",
		"explosion_radius": 46.0,
		"direct_radius": 18.0,
		"direct_damage": 36,
		"splash_damage": 31,
		"crater_radius": 40.0,
		"crater_depth": 34.0,
		"projectile_scale": 0.75
	}
}

static func value(weapon: String, key: String, fallback: Variant) -> Variant:
	return DATA.get(weapon, DATA[STANDARD]).get(key, fallback)

static func display_name(weapon: String) -> String:
	return str(value(weapon, "display_name", "Standard Shell"))
