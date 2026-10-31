extends "res://scripts/core/MainGame.gd"

const GLOBAL_EXPLOSION_CAMERA_HOLD_TIME: float = 0.50

# Top-level Phase C facade. This starts routing mode policy through explicit
# ModeController objects while preserving the existing gameplay implementation.

var player_weapon_selection: PlayerWeaponSelection = PlayerWeaponSelection.new()
var level_session: LevelSession = LevelSession.new()
var mode_controllers: Dictionary = {}
var active_mode_state: ActiveModeState = ActiveModeState.new()
var hotseat_mode_controller: HotseatModeController = HotseatModeController.new()
var realtime_mode_controller: RealtimeSinglePlayerModeController = RealtimeSinglePlayerModeController.new()

func _ready() -> void:
	_initialize_mode_controllers()
	super._ready()

func reset_match() -> void:
	# The former level facade wrapped the mode reset with level setup
	# before and wind assignment afterward. Preserve this ordering.
	_apply_active_level_before_reset()
	_sync_active_mode_from_runtime()
	player_weapon_selection.reset(WEAPON_STANDARD)
	selected_weapon = WEAPON_STANDARD
	super.reset_match()
	_sync_active_mode_from_runtime()
	_apply_level_wind_after_reset()

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

# Weapon metadata getters now resolve from the canonical
# WeaponRuntimeBridge session. Only mode-specific behavior remains here.
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

# Migrated from the retired camera-hold compatibility layer. Keep super calls
# and the special human-vs-AI explosion focus behavior unchanged.
func _process(delta: float) -> void:
	super._process(delta)
	# Older cluster-specific paths can set a longer hold. Clamp global post-
	# explosion hold to the desired short pause before returning to player focus.
	if cluster_camera_hold_timer > GLOBAL_EXPLOSION_CAMERA_HOLD_TIME:
		cluster_camera_hold_timer = GLOBAL_EXPLOSION_CAMERA_HOLD_TIME

func _explode(pos: Vector2) -> void:
	super._explode(pos)
	_start_global_explosion_camera_hold(pos)

func _explode_turn_weapon(pos: Vector2, weapon: String, advance_after: bool) -> void:
	super._explode_turn_weapon(pos, weapon, advance_after)
	_start_global_explosion_camera_hold(pos)

func _explode_realtime_weapon(pos: Vector2, weapon: String) -> void:
	# Keep the base explosion/damage behavior, but do not start camera hold here.
	# Realtime camera hold is owner-aware in _update_all_realtime_projectiles().
	super._explode_realtime_weapon(pos, weapon)

func _update_all_realtime_projectiles(delta: float) -> void:
	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var cluster_focus_sum: Vector2 = Vector2.ZERO
	var cluster_focus_n: int = 0
	var had_human_cluster_children: bool = false
	var last_human_cluster_explosion: Vector2 = Vector2.INF
	var had_human_explosion: bool = false
	var last_human_explosion: Vector2 = Vector2.INF

	for shell: Dictionary in rt_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var owner: int = int(stepped.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(stepped.get("weapon", WEAPON_STANDARD))
		var split_done: bool = bool(stepped.get("split", false))
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var vel: Vector2 = stepped.get("vel", Vector2.ZERO)

		if weapon == WEAPON_CLUSTER and not split_done and vel.y >= 0.0:
			_spawn_realtime_cluster_children(owner, pos, vel)
			if owner == HUMAN_PLAYER_INDEX:
				realtime_cluster_focus_pos = pos
				realtime_cluster_focus_count = _weapon_child_count(weapon)
		elif _realtime_projectile_should_explode(owner, pos):
			if owner == HUMAN_PLAYER_INDEX:
				had_human_explosion = true
				last_human_explosion = pos
				if weapon == WEAPON_CLUSTER_CHILD:
					had_human_cluster_children = true
					last_human_cluster_explosion = pos
					realtime_cluster_focus_count = maxi(0, realtime_cluster_focus_count - 1)
			_explode_realtime_weapon(pos, weapon)
		else:
			remaining.append(stepped)
			if owner == HUMAN_PLAYER_INDEX and weapon == WEAPON_CLUSTER_CHILD:
				had_human_cluster_children = true
				cluster_focus_sum += pos
				cluster_focus_n += 1

	rt_projectiles = remaining
	rt_player_shell_active = ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX)

	if cluster_focus_n > 0:
		realtime_cluster_focus_pos = cluster_focus_sum / float(cluster_focus_n)
		_start_global_explosion_camera_hold(realtime_cluster_focus_pos)
	elif had_human_cluster_children:
		if last_human_cluster_explosion != Vector2.INF:
			realtime_cluster_focus_pos = last_human_cluster_explosion
			_start_global_explosion_camera_hold(last_human_cluster_explosion)
		if realtime_cluster_focus_count <= 0:
			realtime_cluster_focus_pos = Vector2.INF
	elif had_human_explosion and last_human_explosion != Vector2.INF:
		realtime_cluster_focus_pos = Vector2.INF
		_start_global_explosion_camera_hold(last_human_explosion)
	elif not ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX):
		realtime_cluster_focus_pos = Vector2.INF

func _start_global_explosion_camera_hold(pos: Vector2) -> void:
	if pos == Vector2.INF:
		return
	cluster_camera_hold_pos = pos
	cluster_camera_hold_timer = GLOBAL_EXPLOSION_CAMERA_HOLD_TIME
	manual_camera_active = false

# Level-facing gameplay overrides formerly in MainGameLevelFacade.
# Level identity/configuration now belongs to the composed LevelSession.
func _select_level(level_id: String) -> void:
	level_session.select(level_id)
	_apply_level_weapon_loadout()

func _apply_active_level_before_reset() -> void:
	level_session.refresh()
	_apply_level_weapon_loadout()

func _apply_level_weapon_loadout() -> void:
	var loadout: WeaponLoadout = level_session.restricted_loadout()
	if loadout == null:
		_reset_default_weapon_loadout()
		return
	_set_active_weapon_loadout(loadout)

func _apply_level_wind_after_reset() -> void:
	if level_session.definition == null:
		return
	wind = level_session.next_wind(rng)
	if match_controller != null:
		match_controller.set_wind(wind)

func _generate_random_terrain() -> void:
	# Keep terrain generation algorithm unchanged, but allow the active level to
	# provide the broad range values that previously had to be hardcoded.
	if level_session.definition == null:
		super._generate_random_terrain()
		return

	terrain_points.clear()
	active_world_width = level_session.next_world_width(rng, WORLD_WIDTH_MIN_TWEAK, WORLD_WIDTH_MAX_TWEAK)
	active_right_start_x = active_world_width - 130.0
	terrain_points = TerrainManager.generate_varied_terrain(
		rng,
		active_world_width,
		TERRAIN_STEP,
		_bottom_floor_y(),
		level_session.definition.terrain_min_y,
		level_session.definition.terrain_max_y,
		level_session.definition.start_min_y,
		level_session.definition.start_max_y,
		VAR_CONTROL_SPACING_MIN,
		VAR_CONTROL_SPACING_MAX,
		VAR_SLOPE_KICK,
		VAR_DETAIL_WAVE_AMOUNT,
		TANK_START_LEFT_X,
		active_right_start_x,
		54.0
	)
	_refresh_terrain_line()
	_settle_tanks_on_terrain()
	_generate_ponds()

func _generate_ponds() -> void:
	var level_pond_chance: float = level_session.pond_chance(POND_CHANCE)
	ponds = WaterManager.generate_ponds(
		rng,
		terrain_points,
		active_right_start_x,
		TANK_START_LEFT_X,
		level_pond_chance,
		POND_ATTEMPTS,
		POND_MIN_WIDTH,
		POND_MAX_WIDTH,
		POND_MIN_DEPTH,
		POND_RIM_SEARCH_RADIUS,
		POND_SURFACE_DROP,
		POND_SPAWN_AVOID_RADIUS,
		TERRAIN_STEP
	)

func _level_snow_line_y() -> float:
	return level_session.snow_line_y(SNOW_LINE_Y)

func _is_snow_at_x(x: float) -> bool:
	return SnowManager.is_snow_at_x(terrain_points, x, TERRAIN_STEP, _level_snow_line_y())

func _snow_adjusted_direction_and_speed(x: float, input_direction: float, base_speed: float) -> Dictionary:
	return SnowManager.adjusted_direction_and_speed(
		terrain_points,
		x,
		input_direction,
		base_speed,
		TERRAIN_STEP,
		active_world_width,
		_level_snow_line_y(),
		SNOW_UPHILL_BLOCK_SLOPE,
		SNOW_SLIDE_SLOPE,
		SNOW_SLIDE_SPEED,
		SNOW_DRIVE_MULT,
		SNOW_UPHILL_SLOW_MULT
	)

func _draw_snow_faces() -> void:
	for face_data: Dictionary in SnowManager.snow_face_polygons(terrain_points, _level_snow_line_y(), 0.62):
		var face_world: PackedVector2Array = face_data.get("face", PackedVector2Array())
		var face_screen: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in face_world:
			face_screen.append(_world_to_screen(point))
		if face_screen.size() >= 3:
			draw_colored_polygon(face_screen, Color(0.90, 0.95, 1.0, SNOW_FACE_ALPHA))

		var shadow_world: PackedVector2Array = face_data.get("shadow", PackedVector2Array())
		var shadow_screen: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in shadow_world:
			shadow_screen.append(_world_to_screen(point))
		if shadow_screen.size() >= 3:
			draw_colored_polygon(shadow_screen, Color(0.62, 0.78, 1.0, SNOW_FACE_SHADOW_ALPHA))

func _draw_snow_surface_highlights() -> void:
	for segment_world: Array in SnowManager.snow_segments(terrain_points, _level_snow_line_y()):
		var segment: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in segment_world:
			segment.append(_world_to_screen(point))
		_draw_snow_highlight_segment(segment)

func _active_level_name() -> String:
	return level_session.display_name()
