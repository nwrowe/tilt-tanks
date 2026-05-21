extends "res://scripts/core/MainGameCameraHold.gd"

# Top-level compatibility facade that ensures Phase B weapon-definition data is
# the active source of truth even while MainGame.gd still contains older
# hardcoded weapon facade methods.

func _build_weapon_ui() -> void:
	weapon_button = WeaponSelectMenu.make_weapon_button(ui_layer)
	weapon_button.pressed.connect(_toggle_weapon_menu)

	weapon_panel = WeaponSelectMenu.make_panel(ui_layer)
	WeaponSelectMenu.add_title(weapon_panel)
	var weapon_list: VBoxContainer = WeaponSelectMenu.make_scroll_area(weapon_panel)

	for weapon_id: String in active_weapon_loadout.weapon_ids:
		var option_button: Button = WeaponSelectMenu.make_list_option_button(weapon_list, _weapon_display_name(weapon_id))
		option_button.pressed.connect(func(id: String = weapon_id) -> void:
			selected_weapon = _safe_selected_weapon(id)
			_close_weapon_menu()
		)

	var close_button: Button = WeaponSelectMenu.make_back_button(weapon_panel, Vector2(86, 334))
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

func _weapon_should_split_on_descent(weapon: String, split_done: bool, vel: Vector2) -> bool:
	return _weapon_has_split_behavior(weapon) and not split_done and vel.y >= 0.0

func _make_split_children(owner: int, weapon: String, pos: Vector2, vel: Vector2) -> Array[Dictionary]:
	var child_id: String = _weapon_child_id(weapon)
	var count: int = _weapon_child_count(weapon)
	if child_id == "" or count <= 0:
		return []
	return ProjectileFactory.make_split_children(owner, pos, vel, CLUSTER_SPLIT_SPREAD_X, CLUSTER_SPLIT_SPEED_Y, child_id, count)

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

func _split_turn_cluster_projectile(pos: Vector2, vel: Vector2) -> void:
	projectile_active = false
	turn_projectile_split_done = true
	turn_projectiles.clear()
	turn_projectiles = _make_split_children(current_player, turn_projectile_weapon, pos, vel)
	turn_cluster_camera_pos = pos

func _spawn_realtime_cluster_children(owner: int, pos: Vector2, vel: Vector2) -> void:
	var children: Array[Dictionary] = _make_split_children(owner, WEAPON_CLUSTER, pos, vel)
	for child: Dictionary in children:
		rt_projectiles.append(child)
