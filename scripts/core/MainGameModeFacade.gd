extends "res://scripts/core/MainGameCameraHold.gd"

# Top-level Phase C facade. This starts routing mode policy through explicit
# ModeController objects while preserving the existing gameplay implementation.

var player_weapon_selection: PlayerWeaponSelection = PlayerWeaponSelection.new()
var mode_controllers: Dictionary = {}
var active_mode_state: ActiveModeState = ActiveModeState.new()
var hotseat_mode_controller: HotseatModeController = HotseatModeController.new()
var realtime_mode_controller: RealtimeSinglePlayerModeController = RealtimeSinglePlayerModeController.new()

func _ready() -> void:
	_initialize_mode_controllers()
	super._ready()

func reset_match() -> void:
	_sync_active_mode_from_runtime()
	player_weapon_selection.reset(WEAPON_STANDARD)
	selected_weapon = WEAPON_STANDARD
	super.reset_match()
	_sync_active_mode_from_runtime()

# Compatibility hooks formerly in MainGameDefinitionFacade. Per-player
# choices now live in a standalone component, while weapon definitions and
# split factories are inherited directly from WeaponDefinitionRuntimeBridge.
func _save_runtime_current_player_settings() -> void:
	_store_current_player_selected_weapon()
	super._save_runtime_current_player_settings()

func _load_current_player_settings() -> void:
	super._load_current_player_settings()
	_load_current_player_selected_weapon()

func _build_weapon_ui() -> void:
	weapon_button = WeaponSelectMenu.make_weapon_button(ui_layer)
	weapon_button.pressed.connect(_toggle_weapon_menu)

	weapon_panel = WeaponSelectMenu.make_panel(ui_layer)
	WeaponSelectMenu.add_title(weapon_panel)
	var weapon_list: VBoxContainer = WeaponSelectMenu.make_scroll_area(weapon_panel)

	for weapon_id: String in active_weapon_loadout.weapon_ids:
		var option_button: Button = WeaponSelectMenu.make_list_option_button(weapon_list, _weapon_display_name(weapon_id))
		option_button.pressed.connect(func(id: String = weapon_id) -> void:
			_set_selected_weapon_for_current_player(id)
			_close_weapon_menu()
		)

	var close_button: Button = WeaponSelectMenu.make_back_button(weapon_panel, Vector2(86, 334))
	close_button.pressed.connect(_close_weapon_menu)

func _set_selected_weapon_for_current_player(weapon_id: String) -> void:
	selected_weapon = _safe_selected_weapon(weapon_id)
	_store_current_player_selected_weapon()

func _store_current_player_selected_weapon() -> void:
	player_weapon_selection.save(current_player, selected_weapon, WEAPON_STANDARD)

func _load_current_player_selected_weapon() -> void:
	selected_weapon = player_weapon_selection.load(current_player, active_weapon_loadout, WEAPON_STANDARD)

# MainGame.gd still contains pre-registry weapon constants, so keep
# the metadata-based overrides while removing their separate facade layer.
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

func _initialize_mode_controllers() -> void:
	mode_controllers = ModeControllerRegistry.build_default_controllers(self, match_controller)
	hotseat_mode_controller = ModeControllerRegistry.controller_for_name(
		mode_controllers,
		ModeControllerRegistry.MODE_HOTSEAT
	) as HotseatModeController
	realtime_mode_controller = ModeControllerRegistry.controller_for_name(
		mode_controllers,
		ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER
	) as RealtimeSinglePlayerModeController
	_sync_active_mode_from_runtime()

func _select_runtime_mode(mode_name: String) -> void:
	# Compatibility layer: keep the legacy game_mode integer in sync while new
	# code can reason about explicit controller names.
	match mode_name:
		ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER:
			game_mode = GAME_MODE_SINGLE_PLAYER_REALTIME
		ModeControllerRegistry.MODE_HOTSEAT:
			game_mode = GAME_MODE_HOTSEAT
		ModeControllerRegistry.MODE_CAMPAIGN:
			game_mode = GAME_MODE_SINGLE_PLAYER_QUICK
		ModeControllerRegistry.MODE_NETWORK_MULTIPLAYER:
			game_mode = GAME_MODE_HOTSEAT
		_:
			game_mode = GAME_MODE_HOTSEAT
	active_mode_state.set_mode(mode_name, mode_controllers)

func _select_hotseat_mode() -> void:
	_select_runtime_mode(ModeControllerRegistry.MODE_HOTSEAT)

func _select_realtime_single_player_mode() -> void:
	_select_runtime_mode(ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER)

func _select_campaign_mode() -> void:
	_select_runtime_mode(ModeControllerRegistry.MODE_CAMPAIGN)

func _select_network_multiplayer_mode() -> void:
	_select_runtime_mode(ModeControllerRegistry.MODE_NETWORK_MULTIPLAYER)

func _sync_active_mode_from_runtime() -> void:
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		active_mode_state.set_mode(ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER, mode_controllers)
	elif active_mode_state.is_mode(ModeControllerRegistry.MODE_CAMPAIGN) or active_mode_state.is_mode(ModeControllerRegistry.MODE_NETWORK_MULTIPLAYER):
		# Preserve explicit future-mode selections that currently map onto legacy
		# compatibility game_mode values.
		active_mode_state.set_mode(active_mode_state.current_mode_name, mode_controllers)
	else:
		active_mode_state.set_mode(ModeControllerRegistry.MODE_HOTSEAT, mode_controllers)

func _is_active_mode(mode_name: String) -> bool:
	_sync_active_mode_from_runtime()
	return active_mode_state.is_mode(mode_name)

func _is_hotseat_game_active() -> bool:
	return hotseat_mode_controller.is_active(menu_state, game_mode, MENU_STATE_GAME, GAME_MODE_SINGLE_PLAYER_REALTIME)

func _hotseat_can_begin_charge() -> bool:
	return hotseat_mode_controller.can_begin_charge(projectile_active, turn_projectiles, game_over, overlay_open)

func _draw_turn_widget() -> void:
	if game_over:
		return
	if _is_active_mode(ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER) and menu_state == MENU_STATE_GAME:
		return

	var box: Rect2 = Rect2(Vector2(VIEW_SIZE.x - 232.0, 64.0), Vector2(156.0, 44.0))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.64), true)
	draw_rect(box, Color(1.0, 1.0, 1.0, 0.22), false, 1.0)

	var text: String = hotseat_mode_controller.turn_label(current_player, turn_timer)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(16.0, 29.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _update_hotseat_charge(delta: float) -> void:
	if not _is_hotseat_game_active():
		return

	var keyboard_down: bool = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)

	if hotseat_mode_controller.can_begin_keyboard_charge(
		keyboard_down,
		hotseat_keyboard_fire_held,
		projectile_active,
		turn_projectiles,
		game_over,
		overlay_open
	):
		hotseat_keyboard_fire_held = true
		hotseat_charge_time = 0.0
		hotseat_charge_percent = HOTSEAT_CHARGE_MIN_PERCENT

	if hotseat_fire_button_held or hotseat_keyboard_fire_held:
		hotseat_charge_time = minf(HOTSEAT_CHARGE_TIME_MAX, hotseat_charge_time + delta)

		var charge_ratio: float = clampf(hotseat_charge_time / HOTSEAT_CHARGE_TIME_MAX, 0.0, 1.0)
		hotseat_charge_percent = hotseat_mode_controller.charge_percent(
			hotseat_charge_time,
			HOTSEAT_CHARGE_TIME_MAX,
			HOTSEAT_CHARGE_MIN_PERCENT,
			HOTSEAT_CHARGE_MAX_PERCENT
		)

		power_percent = hotseat_charge_percent
		power = _power_from_percent(power_percent)
		_update_fire_button_charge_style(charge_ratio)

	elif _hotseat_can_begin_charge():
		_update_fire_button_charge_style(0.0)

	if hotseat_mode_controller.should_release_keyboard_charge(keyboard_down, hotseat_keyboard_fire_held):
		hotseat_keyboard_fire_held = false
		_release_hotseat_charged_shot()

func _player_can_fire() -> bool:
	return realtime_mode_controller.player_can_fire(rt_player_shell_active, game_over)

func _update_realtime_fire_charge(delta: float) -> void:
	if not _is_active_mode(ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER) or menu_state != MENU_STATE_GAME:
		return

	var keyboard_down: bool = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)

	if realtime_mode_controller.can_begin_fire_charge(keyboard_down, rt_keyboard_fire_held, rt_player_shell_active, game_over, overlay_open):
		rt_keyboard_fire_held = true
		rt_fire_charge_time = 0.0
		rt_fire_charge_percent = RT_CHARGE_MIN_PERCENT
	elif realtime_mode_controller.should_release_fire_charge(keyboard_down, rt_keyboard_fire_held):
		rt_keyboard_fire_held = false
		_release_realtime_charged_shot()

	if rt_fire_button_held or rt_keyboard_fire_held:
		rt_fire_charge_time = minf(RT_CHARGE_TIME_MAX, rt_fire_charge_time + delta)

		var charge_ratio: float = clampf(rt_fire_charge_time / RT_CHARGE_TIME_MAX, 0.0, 1.0)
		rt_fire_charge_percent = realtime_mode_controller.charge_percent(
			rt_fire_charge_time,
			RT_CHARGE_TIME_MAX,
			RT_CHARGE_MIN_PERCENT,
			RT_CHARGE_MAX_PERCENT
		)

		power_percent = rt_fire_charge_percent
		power = _power_from_percent(power_percent)
		_update_fire_button_charge_style(charge_ratio)
	elif rt_player_shell_active:
		_update_fire_button_unavailable_style()
	else:
		_update_fire_button_charge_style(0.0)

func _update_ui() -> void:
	super._update_ui()

	if _is_hotseat_game_active() and not game_over:
		if hotseat_fire_button_held or hotseat_keyboard_fire_held:
			power_label.text = "Charge: %.0f%%" % hotseat_charge_percent
		else:
			power_label.text = "Hold FIRE"
	elif _is_active_mode(ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER) and menu_state == MENU_STATE_GAME and not game_over:
		power_label.text = realtime_mode_controller.shell_status_label(
			rt_player_shell_active,
			rt_fire_button_held or rt_keyboard_fire_held,
			rt_fire_charge_percent,
			0.0
		)
