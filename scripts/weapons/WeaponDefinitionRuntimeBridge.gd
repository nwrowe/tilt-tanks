extends "res://scripts/weapons/WeaponRuntimeBridge.gd"

# Transitional bridge for Phase B weapon-definition migration.
# This keeps the existing weapon runtime intact while routing weapon stat,
# display, and menu lookups through WeaponRegistry / WeaponDefinition.

var weapon_definitions: Dictionary = WeaponRegistry.build_default_definitions()

func _build_weapon_ui() -> void:
	weapon_button = WeaponSelectMenu.make_weapon_button(ui_layer)
	weapon_button.pressed.connect(_toggle_weapon_menu)

	weapon_panel = WeaponSelectMenu.make_panel(ui_layer)
	WeaponSelectMenu.add_title(weapon_panel)

	var y: float = 66.0
	for weapon_id: String in WeaponRegistry.all_player_selectable_ids(weapon_definitions):
		var option_button: Button = WeaponSelectMenu.make_option_button(weapon_panel, _weapon_display_name(weapon_id), Vector2(42, y))
		option_button.pressed.connect(func(id: String = weapon_id) -> void:
			selected_weapon = id
			_close_weapon_menu()
		)
		y += 54.0

	var close_button: Button = WeaponSelectMenu.make_back_button(weapon_panel, Vector2(86, y + 4.0))
	close_button.pressed.connect(_close_weapon_menu)

func _weapon_definition(weapon: String) -> WeaponDefinition:
	return WeaponRegistry.get_definition(weapon_definitions, weapon)

func _weapon_display_name(weapon: String) -> String:
	return WeaponRegistry.display_name(weapon_definitions, weapon)

func _weapon_value(weapon: String, key: String, fallback: Variant) -> Variant:
	return WeaponRegistry.value(weapon_definitions, weapon, key, fallback)

func _weapon_split_behavior(weapon: String) -> String:
	return _weapon_definition(weapon).split_behavior

func _weapon_child_id(weapon: String) -> String:
	return _weapon_definition(weapon).child_weapon_id

func _weapon_child_count(weapon: String) -> int:
	return _weapon_definition(weapon).child_count

func _weapon_has_split_behavior(weapon: String) -> bool:
	return _weapon_definition(weapon).has_split_behavior()

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
