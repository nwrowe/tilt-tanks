extends "res://scripts/weapons/WeaponRuntimeBridge.gd"

# Transitional bridge for Phase B weapon-definition migration.
# This keeps the existing weapon runtime intact while routing weapon stat,
# display, menu, and loadout lookups through WeaponRegistry / WeaponDefinition.

var weapon_definition_session: WeaponDefinitionSession = WeaponDefinitionSession.new()
# Existing UI/weapon scripts still read these fields. Keep them as compatibility
# references while the session owns the registry and current permitted loadout.
var weapon_definitions: Dictionary = weapon_definition_session.definitions
var active_weapon_loadout: WeaponLoadout = weapon_definition_session.loadout

func reset_match() -> void:
	selected_weapon = _safe_selected_weapon(selected_weapon)
	super.reset_match()

func _build_weapon_ui() -> void:
	weapon_button = WeaponSelectMenu.make_weapon_button(ui_layer)
	weapon_button.pressed.connect(_toggle_weapon_menu)

	weapon_panel = WeaponSelectMenu.make_panel(ui_layer)
	WeaponSelectMenu.add_title(weapon_panel)

	# Build weapon options inside the ScrollContainer so the phone player can drag
	# the list directly with a finger. The Back button stays fixed below the list.
	var weapon_list: VBoxContainer = WeaponSelectMenu.make_scroll_area(weapon_panel)
	for weapon_id: String in active_weapon_loadout.weapon_ids:
		var option_button: Button = WeaponSelectMenu.make_list_option_button(weapon_list, _weapon_display_name(weapon_id))
		option_button.pressed.connect(func(id: String = weapon_id) -> void:
			selected_weapon = _safe_selected_weapon(id)
			_close_weapon_menu()
		)

	var close_button: Button = WeaponSelectMenu.make_back_button(weapon_panel, Vector2(86, 336))
	close_button.pressed.connect(_close_weapon_menu)

func _set_active_weapon_loadout(loadout: WeaponLoadout) -> void:
	if not weapon_definition_session.set_loadout(loadout):
		return
	active_weapon_loadout = weapon_definition_session.loadout
	selected_weapon = _safe_selected_weapon(selected_weapon)

func _reset_default_weapon_loadout() -> void:
	weapon_definition_session.reset_default()
	active_weapon_loadout = weapon_definition_session.loadout
	selected_weapon = _safe_selected_weapon(selected_weapon)

func _safe_selected_weapon(weapon: String) -> String:
	return weapon_definition_session.safe_weapon(weapon)

func _weapon_definition(weapon: String) -> WeaponDefinition:
	return weapon_definition_session.definition(weapon)

func _weapon_display_name(weapon: String) -> String:
	return weapon_definition_session.display_name(weapon)

func _weapon_value(weapon: String, key: String, fallback: Variant) -> Variant:
	return weapon_definition_session.value(weapon, key, fallback)

func _weapon_split_behavior(weapon: String) -> String:
	return weapon_definition_session.split_behavior(weapon)

func _weapon_child_id(weapon: String) -> String:
	return weapon_definition_session.child_id(weapon)

func _weapon_child_count(weapon: String) -> int:
	return weapon_definition_session.child_count(weapon)

func _weapon_has_split_behavior(weapon: String) -> bool:
	return weapon_definition_session.has_split_behavior(weapon)

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

# Compatibility entry points for callers still in the older game runtime.
# Split decisions and projectile child construction live in WeaponSplitLogic.
func _weapon_should_split_on_descent(weapon: String, split_done: bool, vel: Vector2) -> bool:
	return weapon_definition_session.should_split_on_descent(weapon, split_done, vel)

func _make_split_children(owner: int, weapon: String, pos: Vector2, vel: Vector2) -> Array[Dictionary]:
	return weapon_definition_session.make_split_children(
		owner, weapon, pos, vel, CLUSTER_SPLIT_SPREAD_X, CLUSTER_SPLIT_SPEED_Y
	)

func _split_turn_cluster_projectile(pos: Vector2, vel: Vector2) -> void:
	projectile_active = false
	turn_projectile_split_done = true
	turn_projectiles.clear()
	turn_projectiles = _make_split_children(current_player, turn_projectile_weapon, pos, vel)

func _spawn_realtime_cluster_children(owner: int, pos: Vector2, vel: Vector2) -> void:
	var children: Array[Dictionary] = _make_split_children(owner, WEAPON_CLUSTER, pos, vel)
	for child: Dictionary in children:
		rt_projectiles.append(child)
