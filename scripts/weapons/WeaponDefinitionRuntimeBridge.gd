extends "res://scripts/weapons/WeaponRuntimeBridge.gd"

# Transitional bridge for Phase B weapon-definition migration.
# This keeps the existing weapon runtime intact while routing weapon stat and
# display lookups through WeaponRegistry / WeaponDefinition.

var weapon_definitions: Dictionary = WeaponRegistry.build_default_definitions()

func _weapon_definition(weapon: String) -> WeaponDefinition:
	return WeaponRegistry.get_definition(weapon_definitions, weapon)

func _weapon_display_name(weapon: String) -> String:
	return WeaponRegistry.display_name(weapon_definitions, weapon)

func _weapon_value(weapon: String, key: String, fallback: Variant) -> Variant:
	return WeaponRegistry.value(weapon_definitions, weapon, key, fallback)

func _weapon_explosion_radius(weapon: String) -> float:
	return float(_weapon_value(weapon, "explosion_radius", EXPLOSION_RADIUS))

func _weapon_direct_radius(weapon: String) -> float:
	return float(_weapon_value(weapon, "direct_radius", DIRECT_HIT_RADIUS))

func _weapon_direct_damage(weapon: String) -> int:
	return int(_weapon_value(weapon, "direct_damage", DIRECT_HIT_DAMAGE))

func _weapon_splash_damage(weapon: String) -> int:
	return int(_weapon_value(weapon, "splash_damage", MAX_SPLASH_DAMAGE))

func _weapon_crater_radius(weapon: String) -> float:
	return float(_weapon_value(weapon, "crater_radius", CRATER_RADIUS))

func _weapon_crater_depth(weapon: String) -> float:
	return float(_weapon_value(weapon, "crater_depth", CRATER_DEPTH))

func _weapon_projectile_scale(weapon: String) -> float:
	return float(_weapon_value(weapon, "projectile_scale", 1.0))
