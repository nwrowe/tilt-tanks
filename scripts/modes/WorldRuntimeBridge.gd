extends "res://scripts/Main.gd"

# Retired ModeRuntimeBridge: composed policy owners remain separate;
# lifecycle compatibility hooks were folded into the active world runtime.

# Compatibility constants and scene state; MainMenuView owns actual controls.
const POWER_FORCE_MIN: float = 400.0
const POWER_FORCE_MAX: float = 1200.0
const POWER_PERCENT_DEFAULT: float = 50.0

var power_percent: float = POWER_PERCENT_DEFAULT
var player_power_percents: Array[float] = [POWER_PERCENT_DEFAULT, POWER_PERCENT_DEFAULT]


const WORLD_WIDTH_MIN_TWEAK: float = 1500.0
const WORLD_WIDTH_MAX_TWEAK: float = 2600.0
const TRAJECTORY_DOT_COUNT: int = 7
const TRAJECTORY_DOT_DT: float = 0.145
const TRAJECTORY_DOT_RADIUS: float = 3.0
const BOTTOM_FLOOR_SCREEN_MARGIN: float = 4.0

var active_world_width: float = 1500.0
var active_right_start_x: float = 1370.0

# -----------------------------------------------------------------------------
# Menu asset paths
# Add your finished art to these paths when ready. The game runs with fallback
# colors/text buttons even before the assets exist.
# -----------------------------------------------------------------------------
const MENU_BG_LANDSCAPE_PATH: String = "res://assets/menu/main_menu_background_landscape.png"
const MENU_BG_PORTRAIT_PATH: String = "res://assets/menu/main_menu_background_portrait.png"
const MENU_LOGO_PATH: String = "res://assets/menu/tilt_tanks_logo.png"

const BUTTON_SINGLE_PLAYER_PATH: String = "res://assets/menu/button_single_player.png"
const BUTTON_MULTIPLAYER_PATH: String = "res://assets/menu/button_multiplayer.png"
const BUTTON_OPTIONS_PATH: String = "res://assets/menu/button_options.png"
const BUTTON_QUICK_GAME_PATH: String = "res://assets/menu/button_quick_game.png"
const BUTTON_CAMPAIGN_PATH: String = "res://assets/menu/button_campaign.png"
const BUTTON_BACK_PATH: String = "res://assets/menu/button_back.png"

const MENU_STATE_MAIN: int = 0
const MENU_STATE_SINGLE_PLAYER: int = 1
const MENU_STATE_OPTIONS: int = 2
const MENU_STATE_MULTIPLAYER: int = 3
const MENU_STATE_GAME: int = 4

var menu_navigation: MainMenuNavigationSession = MainMenuNavigationSession.new()
var menu_state: int:
	get:
		return menu_navigation.screen
	set(value):
		menu_navigation.screen = value
var menu_layer: CanvasLayer
var menu_buttons: Array[Control] = []
var menu_view: MainMenuView = MainMenuView.new()
var menu_logo_texture: Texture2D
var menu_bg_landscape_texture: Texture2D
var menu_bg_portrait_texture: Texture2D
var single_player_mode: bool:
	get:
		return menu_navigation.single_player
	set(value):
		menu_navigation.single_player = value


# Consolidated mode/runtime bridge while flattening the legacy chain.
# This body was moved from MainHybridModes4.gd and owns hotseat/single-player
# mode selection, AI planning, realtime movement/cooldowns, wind display helpers,
# and steam effects.

const GAME_MODE_HOTSEAT: int = 0
const GAME_MODE_SINGLE_PLAYER_QUICK: int = 1
const GAME_MODE_SINGLE_PLAYER_REALTIME: int = 2

const AI_PLAYER_INDEX: int = 1
const HUMAN_PLAYER_INDEX: int = 0
const AI_THINK_TIME: float = 0.85
const AI_ANGLE_STEP_DEG: int = 4
const AI_POWER_STEP_PERCENT: int = 4
const AI_MIN_ANGLE_DEG: int = 12
const AI_MAX_ANGLE_DEG: int = 84
const AI_MIN_POWER_PERCENT: int = 15
const AI_MAX_POWER_PERCENT: int = 100
const AI_SIM_DT: float = 0.055
const AI_SIM_MAX_TIME: float = 5.5
const AI_RANDOM_ANGLE_ERROR: float = 4.5
const AI_RANDOM_POWER_ERROR: float = 7.0
const AI_MAX_SCORE_DISTANCE: float = 999999.0

const WIND_DISPLAY_MAX: float = 10.0
const WIND_METER_MAX_ACCEL: float = MAX_WIND_ACCEL

const RT_PLAYER_FIRE_COOLDOWN_MAX: float = 4.0
const RT_AI_FIRE_COOLDOWN_MAX: float = 5.6
const RT_MOVEMENT_ENERGY_MAX: float = 3.0
const RT_MOVEMENT_RECHARGE_RATE: float = 0.55
const RT_MOVEMENT_DRAIN_RATE: float = 1.0
const RT_AI_AIM_ERROR_ANGLE: float = 8.5
const RT_AI_AIM_ERROR_POWER: float = 14.0
const RT_AI_SCORE_RANDOMNESS: float = 130.0
const RT_AI_MOVE_COOLDOWN_MAX: float = 4.0
const RT_AI_MOVE_CHANCE: float = 0.50
const RT_AI_MOVE_SPEED: float = 42.0
const RT_MOVEMENT_EXHAUST_COOLDOWN_MAX: float = 3.0
const RT_MAX_ACTIVE_PROJECTILES: int = 6

const AI_THINK_TIME_SLOWER: float = 1.75
const AI_RANDOM_ANGLE_ERROR_EASIER: float = 7.5
const AI_RANDOM_POWER_ERROR_EASIER: float = 12.0
const AI_SCORE_RANDOMNESS: float = 85.0
const AI_MOVE_OFFSETS: Array[float] = [-80.0, -40.0, 0.0, 40.0, 80.0]
const AI_MOVE_PENALTY_PER_PIXEL: float = 0.18
const AI_MOVE_CHANCE: float = 0.65
const AI_EDGE_MARGIN: float = 70.0
const AI_MIN_DISTANCE_FROM_HUMAN: float = 160.0

const BUTTON_HOTSEAT_PATH: String = "res://assets/menu/button_hotseat.png"
const BUTTON_ONLINE_PATH: String = "res://assets/menu/button_online.png"

const STEAM_PUFF_LIFETIME: float = 0.95
const STEAM_PUFF_RISE_SPEED: float = 34.0
const STEAM_PUFF_DRIFT_SPEED: float = 18.0
const STEAM_PUFF_START_RADIUS: float = 4.0
const STEAM_PUFF_END_RADIUS: float = 13.0

var game_mode: int = GAME_MODE_HOTSEAT
var turn_ai_session: TurnAITurnSession = TurnAITurnSession.new()
# Preserve legacy property access for descendant scripts.
var ai_pending_turn: bool:
	get:
		return turn_ai_session.pending
	set(value):
		turn_ai_session.pending = value

var ai_think_timer: float:
	get:
		return turn_ai_session.think_timer
	set(value):
		turn_ai_session.think_timer = value

var rt_player_fire_cooldown: float = 0.0
var rt_ai_fire_cooldown: float = 2.2
var rt_movement_energy: float = RT_MOVEMENT_ENERGY_MAX
var rt_ai_move_cooldown: float = 1.0
var rt_ai_target_x: float = 0.0
var rt_projectile_owner: int = HUMAN_PLAYER_INDEX
var rt_projectiles: Array[Dictionary] = []
var rt_movement_exhaust_cooldown: float = 0.0

var steam_puffs: Array[Dictionary] = []
var steam_spawn_timer: float = 0.0
var movement_was_overheated: bool = false


# World runtime declarations retained below.

var realtime_ai_aim: RealtimeAIAimingSession = RealtimeAIAimingSession.new()


# Consolidated world/runtime bridge while flattening the legacy chain.
# This body was moved from MainHybridModes12.gd and owns terrain/water/snow
# runtime constants, realtime fire-charge state, in-game draw composition, and
# movement helpers.

const VAR_TERRAIN_MIN_Y: float = 245.0
const VAR_TERRAIN_MAX_Y: float = 560.0
const VAR_START_MIN_Y: float = 390.0
const VAR_START_MAX_Y: float = 500.0
const VAR_CONTROL_SPACING_MIN: float = 58.0
const VAR_CONTROL_SPACING_MAX: float = 108.0
const VAR_SLOPE_KICK: float = 150.0
const VAR_DETAIL_WAVE_AMOUNT: float = 17.0

const POND_CHANCE: float = 0.38
const POND_ATTEMPTS: int = 10
const POND_MIN_WIDTH: float = 130.0
const POND_MAX_WIDTH: float = 430.0
const POND_MIN_DEPTH: float = 18.0
const POND_RIM_SEARCH_RADIUS: int = 55
const POND_SURFACE_DROP: float = 6.0
const POND_SPAWN_AVOID_RADIUS: float = 140.0

const WATER_REFLOW_SEARCH_CELLS: int = 85
const WATER_MIN_VISIBLE_DEPTH: float = 3.0
const WATER_MAX_SURFACE_ITERATIONS: int = 28
const WATER_CONNECTED_MARGIN: float = 2.0
const WATER_DRIVE_SPEED_MULT: float = 0.42
const WATER_FLOAT_TANK_SUBMERGENCE: float = 0.50

const SNOW_LINE_Y: float = 315.0
const SNOW_UPHILL_BLOCK_SLOPE: float = 0.58
const SNOW_SLIDE_SLOPE: float = 0.24
const SNOW_SLIDE_SPEED: float = 70.0
const SNOW_DRIVE_MULT: float = 0.72
const SNOW_EDGE_WIDTH: float = 7.0

const RT_CHARGE_TIME_MAX: float = 1.65
const RT_CHARGE_MIN_PERCENT: float = 10.0
const RT_CHARGE_MAX_PERCENT: float = 100.0

var ponds: Array[Dictionary] = []
var rt_player_shell_active: bool = false
var rt_fire_button_held: bool = false
var rt_keyboard_fire_held: bool = false
var rt_fire_charge_time: float = 0.0
var rt_fire_charge_percent: float = 0.0


# Compatibility implementations from the retired mode ancestor.
func _mode_runtime_ready() -> void:
	rng.randomize()
	if terrain != null:
		terrain.visible = false
	if reset_button != null:
		reset_button.visible = false
		reset_button.focus_mode = Control.FOCUS_NONE
	if fire_button != null:
		fire_button.visible = false
		fire_button.focus_mode = Control.FOCUS_NONE
	if power_slider != null:
		power_slider.min_value = 0.0
		power_slider.max_value = 100.0
		power_slider.step = 1.0
		power_slider.focus_mode = Control.FOCUS_NONE
	_build_overlay_ui()
	reset_match()
	_load_menu_assets()
	_build_menu_layer()
	_show_main_menu()

func _mode_runtime_draw() -> void:
	if menu_state == MENU_STATE_GAME:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
		_draw_distant_mountains()
		_draw_ground_fill()
		_draw_terrain_outline()
		_draw_tank(0, Color(0.25, 0.9, 0.35))
		_draw_tank(1, Color(0.95, 0.25, 0.25))
		if not game_over:
			_draw_trajectory_preview()
			var base: Vector2 = _world_to_screen(tank_positions[current_player])
			var facing: float = 1.0 if current_player == 0 else -1.0
			var rad: float = deg_to_rad(angle_deg)
			var tip: Vector2 = base + Vector2(facing * CANNON_LENGTH * CAMERA_SCALE * cos(rad), -CANNON_LENGTH * CAMERA_SCALE * sin(rad))
			draw_line(base, tip, Color.WHITE, 4.0)
		if projectile_active:
			draw_circle(_world_to_screen(projectile_pos), PROJECTILE_RADIUS * CAMERA_SCALE, Color(1.0, 0.92, 0.2))
		if explosion_timer > 0.0 and explosion_pos != Vector2.INF:
			_draw_explosion()
		_draw_wind_widget()
		_draw_turn_widget()
		return
	_draw_menu_background()

func _on_mobile_fire_pressed() -> void:
	return

func _on_multiplayer_pressed() -> void:
	_show_multiplayer_menu()

func _show_multiplayer_menu() -> void:
	menu_navigation.open_multiplayer()
	_hide_game_ui()
	_clear_menu_controls()
	menu_view.build_multiplayer(
		get_viewport_rect().size, BUTTON_HOTSEAT_PATH, BUTTON_ONLINE_PATH,
		BUTTON_BACK_PATH, _on_hotseat_pressed, _on_online_pressed, _show_main_menu
	)
	queue_redraw()

func _on_online_pressed() -> void:
	menu_navigation.show_online()
	_hide_game_ui()
	_clear_menu_controls()
	menu_view.build_placeholder(
		get_viewport_rect().size, "Online", BUTTON_BACK_PATH, _show_multiplayer_menu
	)
	queue_redraw()

func _on_quick_game_pressed() -> void:
	game_mode = GAME_MODE_SINGLE_PLAYER_REALTIME
	_start_game(true)

func _on_hotseat_pressed() -> void:
	game_mode = GAME_MODE_HOTSEAT
	_start_game(false)

func _start_game(is_single_player: bool) -> void:
	menu_navigation.choose_single_player(is_single_player)
	_clear_menu_controls()
	menu_navigation.enter_game()
	_show_game_ui()
	reset_match()
	queue_redraw()
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		_setup_realtime_single_player()

func _mode_runtime_setup_realtime_single_player() -> void:
	current_player = HUMAN_PLAYER_INDEX
	rt_player_fire_cooldown = 0.0
	rt_ai_fire_cooldown = rng.randf_range(2.0, RT_AI_FIRE_COOLDOWN_MAX)
	rt_movement_energy = RT_MOVEMENT_ENERGY_MAX
	rt_ai_move_cooldown = rng.randf_range(1.0, RT_AI_MOVE_COOLDOWN_MAX)
	rt_ai_target_x = tank_positions[AI_PLAYER_INDEX].x
	angle_deg = player_angles[HUMAN_PLAYER_INDEX]
	power_percent = player_power_percents[HUMAN_PLAYER_INDEX]
	power = _power_from_percent(power_percent)
	if power_slider != null:
		power_slider.value = power_percent
	steam_puffs.clear()
	steam_spawn_timer = 0.0
	movement_was_overheated = false
	rt_projectiles.clear()
	rt_movement_exhaust_cooldown = 0.0
	projectile_active = false

func _mode_runtime_reset_match() -> void:
	_hide_overlays()
	current_player = 0
	player_angles = [45.0, 45.0]
	player_power_percents = [POWER_PERCENT_DEFAULT, POWER_PERCENT_DEFAULT]
	player_powers = [_power_from_percent(POWER_PERCENT_DEFAULT), _power_from_percent(POWER_PERCENT_DEFAULT)]
	angle_deg = 45.0
	power_percent = POWER_PERCENT_DEFAULT
	power = _power_from_percent(power_percent)
	if power_slider != null:
		power_slider.value = power_percent
		power_slider.release_focus()
	turn_timer = TURN_TIME_LIMIT
	wind = rng.randf_range(-MAX_WIND_ACCEL, MAX_WIND_ACCEL)
	tank_health = [100, 100]
	projectile_active = false
	projectile_pos = Vector2.ZERO
	projectile_vel = Vector2.ZERO
	explosion_pos = Vector2.INF
	explosion_timer = 0.0
	game_over = false
	mobile_left_pressed = false
	mobile_right_pressed = false
	turn_ai_session.reset()

	tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(TANK_START_LEFT_X + 300.0, 0.0)]
	_generate_random_terrain()
	tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(active_right_start_x, 0.0)]
	_settle_tanks_on_terrain()
	camera_x = _camera_target_x()

	_randomize_wind()
	steam_puffs.clear()
	steam_spawn_timer = 0.0
	movement_was_overheated = false
	rt_projectiles.clear()
	rt_movement_exhaust_cooldown = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if menu_state != MENU_STATE_GAME:
		queue_redraw()
		return
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		_process_realtime_single_player(delta)
		return
	if _is_ai_turn_waiting_for_explosion():
		_process_ai_turn_waiting_for_explosion(delta)
		return
	if _is_ai_turn_active():
		_process_ai_turn(delta)
		return
	_process_legacy_gameplay_frame(delta)

func _is_ai_turn_active() -> bool:
	return TurnAITurnSession.can_act(
		game_mode == GAME_MODE_SINGLE_PLAYER_QUICK, current_player == AI_PLAYER_INDEX,
		projectile_active, game_over, overlay_open
	)

func _is_ai_turn_waiting_for_explosion() -> bool:
	return TurnAITurnSession.waiting_for_explosion(
		game_mode == GAME_MODE_SINGLE_PLAYER_QUICK, current_player == AI_PLAYER_INDEX,
		projectile_active, game_over, overlay_open, explosion_timer
	)

func _advance_turn() -> void:
	super._advance_turn()
	if _is_ai_turn_active():
		_begin_ai_turn()
	else:
		turn_ai_session.cancel()

func _process_ai_turn(delta: float) -> void:
	if not ai_pending_turn:
		_begin_ai_turn()
	var ready_to_fire: bool = turn_ai_session.step(delta)
	_update_camera(delta)
	_update_ui()
	queue_redraw()
	if ready_to_fire:
		turn_ai_session.cancel()
		_take_ai_shot()

func _process_ai_turn_waiting_for_explosion(delta: float) -> void:
	explosion_timer -= delta
	if explosion_timer <= 0.0:
		explosion_timer = 0.0
		explosion_pos = Vector2.INF
		turn_ai_session.cancel()
	_update_camera(delta)
	_update_ui()
	queue_redraw()

func _begin_ai_turn() -> void:
	turn_ai_session.begin(AI_THINK_TIME_SLOWER)
	mobile_left_pressed = false
	mobile_right_pressed = false
	if power_slider != null:
		power_slider.release_focus()

func _take_ai_shot() -> void:
	var plan: Dictionary = _find_ai_plan()
	var planned_x: float = float(plan.get("move_x", tank_positions[AI_PLAYER_INDEX].x))
	_apply_ai_move(planned_x)

	var chosen_angle: float = float(plan.get("angle", 45.0)) + rng.randf_range(-AI_RANDOM_ANGLE_ERROR_EASIER, AI_RANDOM_ANGLE_ERROR_EASIER)
	var chosen_power_percent: float = float(plan.get("power_percent", 55.0)) + rng.randf_range(-AI_RANDOM_POWER_ERROR_EASIER, AI_RANDOM_POWER_ERROR_EASIER)

	angle_deg = clampf(chosen_angle, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)
	power_percent = clampf(chosen_power_percent, 0.0, 100.0)
	power = _power_from_percent(power_percent)
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	if power_slider != null:
		power_slider.value = power_percent
	_on_fire_pressed()

func _turn_ai_search_config() -> Dictionary:
	return {
		"max_score": AI_MAX_SCORE_DISTANCE,
		"min_angle": AI_MIN_ANGLE_DEG, "max_angle": AI_MAX_ANGLE_DEG,
		"angle_step": AI_ANGLE_STEP_DEG,
		"min_power": AI_MIN_POWER_PERCENT, "max_power": AI_MAX_POWER_PERCENT,
		"power_step": AI_POWER_STEP_PERCENT,
		"score_randomness": AI_SCORE_RANDOMNESS,
		"move_offsets": AI_MOVE_OFFSETS,
		"edge_margin": AI_EDGE_MARGIN,
		"min_human_distance": AI_MIN_DISTANCE_FROM_HUMAN,
		"tank_radius": TANK_RADIUS,
		"move_penalty_per_pixel": AI_MOVE_PENALTY_PER_PIXEL,
		"move_chance": AI_MOVE_CHANCE
	}

func _find_ai_plan() -> Dictionary:
	return TurnAIShotPlanner.find_plan(
		rng, tank_positions[AI_PLAYER_INDEX], tank_positions[HUMAN_PLAYER_INDEX],
		active_world_width, Callable(self, "_ground_y_at_x"),
		Callable(self, "_score_ai_shot_from_position"), _turn_ai_search_config()
	)

func _find_ai_shot() -> Dictionary:
	return _find_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX])

func _find_ai_shot_from_position(shooter_pos: Vector2) -> Dictionary:
	return TurnAIShotPlanner.find_shot(
		rng, shooter_pos, Callable(self, "_score_ai_shot_from_position"),
		_turn_ai_search_config()
	)

func _score_ai_shot(test_angle_deg: float, test_power_percent: float) -> float:
	return _score_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX], test_angle_deg, test_power_percent)

func _score_ai_shot_from_position(shooter_pos: Vector2, test_angle_deg: float, test_power_percent: float) -> float:
	var test_power: float = _power_from_percent(test_power_percent)
	var target_pos: Vector2 = tank_positions[HUMAN_PLAYER_INDEX] + Vector2(
		rng.randf_range(-28.0, 28.0), rng.randf_range(-8.0, 8.0)
	)
	return TurnAIBallisticScorer.score(
		shooter_pos, target_pos, test_angle_deg, test_power,
		Callable(self, "_ground_y_at_x"),
		{
			"cannon_length": CANNON_LENGTH,
			"sim_dt": AI_SIM_DT,
			"max_time": AI_SIM_MAX_TIME,
			"gravity": gravity,
			"wind": wind,
			"world_width": active_world_width,
			"floor_y": _bottom_floor_y()
		}
	)

func _apply_ai_move(target_x: float) -> void:
	var current_x: float = tank_positions[AI_PLAYER_INDEX].x
	if absf(target_x - current_x) < 4.0:
		return
	var clamped_x: float = clampf(target_x, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
	if absf(clamped_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
		return
	tank_positions[AI_PLAYER_INDEX].x = clamped_x
	tank_positions[AI_PLAYER_INDEX].y = _ground_y_at_x(clamped_x) - TANK_RADIUS

func _process_realtime_single_player(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_match()
		_setup_realtime_single_player()

	if not game_over and not overlay_open:
		current_player = HUMAN_PLAYER_INDEX
		_update_angle_from_input(delta)
		_update_realtime_player_movement(delta)
		_update_realtime_power()
		_update_realtime_cooldowns(delta)
		_update_realtime_fire_charge(delta)
		_update_realtime_ai(delta)

	_update_all_realtime_projectiles(delta)

	if explosion_timer > 0.0:
		explosion_timer -= delta
		if explosion_timer <= 0.0:
			explosion_pos = Vector2.INF

	_update_camera(delta)
	_update_ui()
	_update_steam_puffs(delta)
	queue_redraw()

func _update_realtime_fire_charge(delta: float) -> void:
	return

func _update_realtime_power() -> void:
	power_percent = float(power_slider.value) if power_slider != null and power_slider.visible else power_percent
	power = _power_from_percent(power_percent)
	player_angles[HUMAN_PLAYER_INDEX] = angle_deg
	player_power_percents[HUMAN_PLAYER_INDEX] = power_percent
	player_powers[HUMAN_PLAYER_INDEX] = power

func _fire_realtime_projectile(owner: int) -> void:
	return

func _update_realtime_cooldowns(delta: float) -> void:
	var result: Dictionary = RealtimeCooldownPolicy.advance(
		rt_player_fire_cooldown, rt_ai_fire_cooldown, rt_ai_move_cooldown,
		rt_movement_exhaust_cooldown, rt_movement_energy,
		RT_MOVEMENT_ENERGY_MAX, delta
	)
	rt_player_fire_cooldown = float(result["player_fire"])
	rt_ai_fire_cooldown = float(result["ai_fire"])
	rt_ai_move_cooldown = float(result["ai_move"])
	rt_movement_exhaust_cooldown = float(result["exhaust"])
	rt_movement_energy = float(result["energy"])
	movement_was_overheated = bool(result["was_overheated"])

func _choose_realtime_ai_move_target() -> void:
	rt_ai_target_x = RealtimeAIMovementPlanner.choose_target_x(
		rng, tank_positions[AI_PLAYER_INDEX], tank_positions[HUMAN_PLAYER_INDEX],
		active_world_width, Callable(self, "_ground_y_at_x"),
		Callable(self, "_find_ai_shot_from_position"),
		{
			"move_chance": RT_AI_MOVE_CHANCE,
			"edge_margin": AI_EDGE_MARGIN,
			"min_human_distance": AI_MIN_DISTANCE_FROM_HUMAN,
			"tank_radius": TANK_RADIUS
		}
	)

func _prepare_realtime_ai_shot() -> void:
	var aim: Dictionary = _find_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX])
	var chosen_angle: float = float(aim.get("angle", 45.0)) + rng.randf_range(-RT_AI_AIM_ERROR_ANGLE, RT_AI_AIM_ERROR_ANGLE)
	var chosen_power_percent: float = float(aim.get("power_percent", 55.0)) + rng.randf_range(-RT_AI_AIM_ERROR_POWER, RT_AI_AIM_ERROR_POWER)
	player_angles[AI_PLAYER_INDEX] = clampf(chosen_angle, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)
	player_power_percents[AI_PLAYER_INDEX] = clampf(chosen_power_percent, 0.0, 100.0)
	player_powers[AI_PLAYER_INDEX] = _power_from_percent(player_power_percents[AI_PLAYER_INDEX])

func _update_all_realtime_projectiles(delta: float) -> void:
	return

func _camera_target_x() -> float:
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		var focus_x: float = tank_positions[HUMAN_PLAYER_INDEX].x
		var newest_human_projectile: Vector2 = Vector2.INF
		for shell: Dictionary in rt_projectiles:
			if int(shell.get("owner", -1)) == HUMAN_PLAYER_INDEX:
				newest_human_projectile = shell.get("pos", Vector2.INF)
		if newest_human_projectile != Vector2.INF:
			focus_x = newest_human_projectile.x
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(focus_x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	return LegacyInputMotionPolicy.camera_x(
		tank_positions[current_player].x, projectile_active, projectile_pos.x,
		explosion_timer, explosion_pos, VIEW_SIZE.x, CAMERA_SCALE, active_world_width
	)

func _draw_realtime_projectiles() -> void:
	for shell: Dictionary in rt_projectiles:
		var owner: int = int(shell.get("owner", HUMAN_PLAYER_INDEX))
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var color: Color = Color(1.0, 0.92, 0.2) if owner == HUMAN_PLAYER_INDEX else Color(1.0, 0.38, 0.25)
		draw_circle(_world_to_screen(pos), PROJECTILE_RADIUS * CAMERA_SCALE, color)

func _update_ui() -> void:
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME:
		angle_label.text = "Angle: %.1f" % angle_deg
		power_label.text = "Power: %.0f%%" % power_percent
		if game_over:
			var winner: String = "You" if tank_health[AI_PLAYER_INDEX] <= 0 else "Computer"
			status_label.text = "%s win!  You HP: %d  CPU HP: %d" % [winner, tank_health[HUMAN_PLAYER_INDEX], tank_health[AI_PLAYER_INDEX]]
		else:
			status_label.text = "Realtime Quick Game   You HP: %d    CPU HP: %d" % [tank_health[HUMAN_PLAYER_INDEX], tank_health[AI_PLAYER_INDEX]]
		return
	_update_legacy_main_ui()
	if menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and current_player == AI_PLAYER_INDEX and not game_over:
		status_label.text = "Computer thinking...   P1 HP: %d    CPU HP: %d" % [tank_health[0], tank_health[1]]
	elif menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and not game_over:
		status_label.text = "Your turn   P1 HP: %d    CPU HP: %d" % [tank_health[0], tank_health[1]]

func _update_steam_puffs(delta: float) -> void:
	steam_puffs = SteamPuffEffect.advance(
		steam_puffs, delta, STEAM_PUFF_RISE_SPEED, STEAM_PUFF_LIFETIME
	)

func _draw_steam_puffs() -> void:
	for puff: Dictionary in steam_puffs:
		var appearance: Dictionary = SteamPuffEffect.appearance(
			puff, STEAM_PUFF_LIFETIME, STEAM_PUFF_START_RADIUS,
			STEAM_PUFF_END_RADIUS, CAMERA_SCALE
		)
		draw_circle(
			_world_to_screen(appearance["pos"]), appearance["radius"], appearance["color"]
		)

func _randomize_wind() -> void:
	var display_wind: float = rng.randf_range(-WIND_DISPLAY_MAX, WIND_DISPLAY_MAX)
	wind = display_wind / WIND_DISPLAY_MAX * WIND_METER_MAX_ACCEL

func _wind_display_value() -> float:
	return WindMeterPolicy.display_value(wind, WIND_METER_MAX_ACCEL, WIND_DISPLAY_MAX)

func _wind_strength_color(strength: float) -> Color:
	return WindMeterPolicy.strength_color(strength)

func _draw_small_arrow(tip: Vector2, direction: float, color: Color) -> void:
	var points: PackedVector2Array = WindMeterPolicy.arrow_points(tip, direction)
	if not points.is_empty():
		draw_colored_polygon(points, color)

# Base gameplay frame behavior from the retired menu ancestor.
func _process_legacy_gameplay_frame(delta: float) -> void:
	if menu_state == MENU_STATE_GAME:
		if Input.is_key_pressed(KEY_R):
			reset_match()
	
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			_on_fire_pressed()
	
		if not projectile_active and not game_over and not overlay_open:
			_update_angle_from_input(delta)
			_update_tank_movement(delta)
			if power_slider != null:
				power_percent = float(power_slider.value)
			power = _power_from_percent(power_percent)
			player_angles[current_player] = angle_deg
			player_power_percents[current_player] = power_percent
			player_powers[current_player] = power
			turn_timer -= delta
			if turn_timer <= 0.0:
				_end_turn_without_shot()
	
		if projectile_active:
			_update_projectile(delta)
	
		if explosion_timer > 0.0:
			explosion_timer -= delta
			if explosion_timer <= 0.0:
				explosion_pos = Vector2.INF
	
		_update_camera(delta)
		_update_ui()
		queue_redraw()
	else:
		queue_redraw()

# Menu/gameplay compatibility entry points retained for external descendants.
func _load_menu_assets() -> void:
	menu_view.load_assets(MENU_BG_LANDSCAPE_PATH, MENU_BG_PORTRAIT_PATH, MENU_LOGO_PATH)
	menu_bg_landscape_texture = menu_view.landscape_texture
	menu_bg_portrait_texture = menu_view.portrait_texture
	menu_logo_texture = menu_view.logo_texture

func _load_texture_if_exists(path: String) -> Texture2D:
	return menu_view._load_texture(path)

func _build_menu_layer() -> void:
	menu_view.attach(self)
	menu_layer = menu_view.layer
	menu_buttons = menu_view.controls

func _show_main_menu() -> void:
	menu_navigation.open_main()
	_hide_game_ui()
	_clear_menu_controls()
	menu_view.build_home(
		get_viewport_rect().size, BUTTON_SINGLE_PLAYER_PATH, BUTTON_MULTIPLAYER_PATH,
		BUTTON_OPTIONS_PATH, _on_single_player_pressed, _on_multiplayer_pressed, _on_options_pressed
	)
	queue_redraw()

func _show_single_player_menu() -> void:
	menu_navigation.open_single_player()
	_hide_game_ui()
	_clear_menu_controls()
	menu_view.build_single_player(
		get_viewport_rect().size, BUTTON_QUICK_GAME_PATH, BUTTON_CAMPAIGN_PATH,
		BUTTON_BACK_PATH, _on_quick_game_pressed, _on_campaign_pressed, _show_main_menu
	)
	queue_redraw()

func _show_placeholder_menu(title: String) -> void:
	_hide_game_ui()
	_clear_menu_controls()
	menu_view.build_placeholder(
		get_viewport_rect().size, title, BUTTON_BACK_PATH, _show_main_menu
	)
	queue_redraw()

func _on_single_player_pressed() -> void:
	_show_single_player_menu()

func _on_options_pressed() -> void:
	menu_navigation.open_options()
	_show_placeholder_menu("Options")

func _on_campaign_pressed() -> void:
	_show_placeholder_menu("Campaign")

func _hide_game_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = false

func _mode_runtime_show_game_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = true

func _clear_menu_controls() -> void:
	menu_view.clear()

func _add_text_label(text: String, anchor: Vector2, size: Vector2, font_size: int) -> Label:
	return menu_view.add_label(get_viewport_rect().size, text, anchor, size, font_size)

func _add_menu_button(text: String, texture_path: String, anchor: Vector2, size: Vector2, callback: Callable) -> Control:
	return menu_view.add_button(get_viewport_rect().size, text, texture_path, anchor, size, callback)

func _style_menu_button(button: Button) -> void:
	menu_view.style_button(button)

func _anchored_position(anchor: Vector2, size: Vector2) -> Vector2:
	return MainMenuPresentation.anchored_position(get_viewport_rect().size, anchor, size)

func _draw_menu_background() -> void:
	menu_view.draw_background(self, get_viewport_rect().size)

func _update_angle_from_input(delta: float) -> void:
	var gravity_vec: Vector3 = Input.get_gravity()
	if gravity_vec.length() < 0.01:
		var axis: float = 0.0
		if Input.is_key_pressed(KEY_UP):
			axis += 1.0
		if Input.is_key_pressed(KEY_DOWN):
			axis -= 1.0
		angle_deg = LegacyInputMotionPolicy.keyboard_aim(
			angle_deg, axis, delta, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE
		)
	else:
		angle_deg = LegacyInputMotionPolicy.tilt_aim(
			gravity_vec.x, current_player, MOBILE_TILT_FULL_SCALE,
			MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE
		)

func _power_from_percent(percent: float) -> float:
	return PowerControlPolicy.force_from_percent(percent, POWER_FORCE_MIN, POWER_FORCE_MAX)

func _on_fire_pressed() -> void:
	if projectile_active or game_over or overlay_open:
		return
	if power_slider != null:
		power_slider.release_focus()
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	var facing: float = 1.0
	if current_player != 0:
		facing = -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	projectile_pos = tank_positions[current_player] + muzzle_offset
	projectile_vel = Vector2(facing * power * cos(rad), -power * sin(rad))
	projectile_active = true

func _load_current_player_settings() -> void:
	angle_deg = player_angles[current_player]
	power_percent = player_power_percents[current_player]
	power = _power_from_percent(power_percent)
	if power_slider != null:
		power_slider.value = power_percent
		power_slider.release_focus()

func _draw_distant_mountains() -> void:
	LegacyBackdropRenderer.draw_distant_mountains(self, VIEW_SIZE)

# Required compatibility method for lower ancestor compile-time dispatch.

func _bottom_floor_y() -> float:
	return (VIEW_SIZE.y - CAMERA_Y_OFFSET) / CAMERA_SCALE - BOTTOM_FLOOR_SCREEN_MARGIN

# Required compatibility method for lower ancestor compile-time dispatch.

func _draw_trajectory_preview() -> void:
	if projectile_active or game_over:
		return
	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var pos: Vector2 = tank_positions[current_player] + muzzle_offset
	var vel: Vector2 = Vector2(facing * power * cos(rad), -power * sin(rad))
	for i: int in range(1, TRAJECTORY_DOT_COUNT + 1):
		vel.y += gravity * TRAJECTORY_DOT_DT
		vel.x += wind * TRAJECTORY_DOT_DT
		pos += vel * TRAJECTORY_DOT_DT
		if pos.x < 0.0 or pos.x > active_world_width or pos.y >= _ground_y_at_x(pos.x):
			break
		var alpha: float = 0.55 * (1.0 - float(i - 1) / float(TRAJECTORY_DOT_COUNT))
		draw_circle(_world_to_screen(pos), TRAJECTORY_DOT_RADIUS, Color(1.0, 1.0, 1.0, alpha))

func _update_legacy_main_ui() -> void:
	if angle_label != null:
		angle_label.text = "Angle: %.1f" % angle_deg
	if power_label != null:
		power_label.text = "Power: %.0f%%" % power_percent
	if status_label == null:
		return
	if game_over:
		var winner: int = 0
		if tank_health[0] <= 0:
			winner = 1
		status_label.text = "Player %d wins!  P1 HP: %d  P2 HP: %d" % [winner + 1, tank_health[0], tank_health[1]]
	else:
		status_label.text = "P1 HP: %d    P2 HP: %d" % [tank_health[0], tank_health[1]]

# Active world/runtime implementations take precedence over compatibility helpers.
func _ready() -> void:
	_mode_runtime_ready()
	_resize_mobile_action_buttons()
	if mobile_fire_button != null:
		if not mobile_fire_button.button_down.is_connected(_on_realtime_fire_button_down):
			mobile_fire_button.button_down.connect(_on_realtime_fire_button_down)
		if not mobile_fire_button.button_up.is_connected(_on_realtime_fire_button_up):
			mobile_fire_button.button_up.connect(_on_realtime_fire_button_up)
	_update_fire_button_charge_style(0.0)

func _setup_realtime_single_player() -> void:
	_mode_runtime_setup_realtime_single_player()
	rt_player_shell_active = false
	rt_fire_button_held = false
	rt_keyboard_fire_held = false
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0
	_resize_mobile_action_buttons()
	_show_realtime_power_ui(false)
	_update_fire_button_charge_style(0.0)
	_clear_realtime_ai_visual_plan()
	_choose_realtime_ai_visual_plan()

func reset_match() -> void:
	_clear_realtime_ai_visual_plan()
	_mode_runtime_reset_match()
	rt_player_shell_active = false
	rt_fire_button_held = false
	rt_keyboard_fire_held = false
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0
	_update_fire_button_charge_style(0.0)

func _show_game_ui() -> void:
	_mode_runtime_show_game_ui()
	_show_realtime_power_ui(game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME)

func _show_realtime_power_ui(show_slider: bool) -> void:
	if power_slider != null:
		power_slider.visible = show_slider
	if power_label != null:
		power_label.visible = true

func _on_realtime_fire_button_down() -> void:
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME or menu_state != MENU_STATE_GAME:
		return
	if not _player_can_fire() or game_over or overlay_open:
		return
	rt_fire_button_held = true
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = RT_CHARGE_MIN_PERCENT
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _on_realtime_fire_button_up() -> void:
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME or menu_state != MENU_STATE_GAME:
		return
	if rt_fire_button_held:
		_release_realtime_charged_shot()
	rt_fire_button_held = false
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _player_can_fire() -> bool:
	return not rt_player_shell_active and not game_over

func _release_realtime_charged_shot() -> void:
	# Compatibility stub. MainGame.gd owns the active implementation.
	return

func _resize_mobile_action_buttons() -> void:
	# Keep left/right enlarged and move FIRE farther right so it is easier to hit.
	if mobile_left_button != null:
		mobile_left_button.position = Vector2(16, 430)
		mobile_left_button.size = Vector2(92, 88)
	if mobile_right_button != null:
		mobile_right_button.position = Vector2(122, 430)
		mobile_right_button.size = Vector2(92, 88)
	if mobile_fire_button != null:
		mobile_fire_button.position = Vector2(430, 448)
		mobile_fire_button.size = Vector2(188, 70)

func _draw_wind_widget() -> void:
	# Borderless center-zero wind meter with label.
	var box_pos: Vector2 = Vector2(18, 132)
	var box_size: Vector2 = Vector2(190, 42)
	draw_rect(Rect2(box_pos, box_size), Color(0.02, 0.03, 0.04, 0.42), true)

	var meter_left: float = box_pos.x + 58.0
	var meter_right: float = box_pos.x + box_size.x - 18.0
	var meter_center: float = (meter_left + meter_right) * 0.5
	var meter_y: float = box_pos.y + 22.0
	var half_width: float = (meter_right - meter_left) * 0.5
	var display_wind: float = _wind_display_value()
	var strength: float = WindMeterPolicy.strength(display_wind, WIND_DISPLAY_MAX)
	var fill_width: float = half_width * strength
	var bar_color: Color = _wind_strength_color(strength)

	draw_line(Vector2(meter_left, meter_y), Vector2(meter_right, meter_y), Color(0.55, 0.65, 0.75, 0.42), 8.0)
	draw_line(Vector2(meter_center, meter_y - 13.0), Vector2(meter_center, meter_y + 13.0), Color.WHITE, 2.0)
	if display_wind >= 0.0:
		draw_line(Vector2(meter_center, meter_y), Vector2(meter_center + fill_width, meter_y), bar_color, 8.0)
		_draw_small_arrow(Vector2(meter_center + fill_width + 4.0, meter_y), 1.0, bar_color)
	else:
		draw_line(Vector2(meter_center, meter_y), Vector2(meter_center - fill_width, meter_y), bar_color, 8.0)
		_draw_small_arrow(Vector2(meter_center - fill_width - 4.0, meter_y), -1.0, bar_color)

	draw_string(ThemeDB.fallback_font, Vector2(box_pos.x + 8.0, box_pos.y + 27.0), "wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(box_pos.x + box_size.x - 46.0, box_pos.y + 35.0), "%+.0f" % display_wind, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw() -> void:
	if menu_state == MENU_STATE_GAME:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
		_draw_distant_mountains()
		_draw_ponds_under_ground()
		_draw_ground_fill()
		_draw_water_surfaces()
		_draw_snow_caps()
		_draw_terrain_outline()
		_draw_tank(0, Color(0.25, 0.9, 0.35))
		_draw_tank(1, Color(0.95, 0.25, 0.25))
		if not game_over:
			_draw_trajectory_preview()
			var base: Vector2 = _world_to_screen(tank_positions[current_player])
			var facing: float = 1.0 if current_player == 0 else -1.0
			var rad: float = deg_to_rad(angle_deg)
			var tip: Vector2 = base + Vector2(facing * CANNON_LENGTH * CAMERA_SCALE * cos(rad), -CANNON_LENGTH * CAMERA_SCALE * sin(rad))
			draw_line(base, tip, Color.WHITE, 4.0)
		if projectile_active:
			draw_circle(_world_to_screen(projectile_pos), PROJECTILE_RADIUS * CAMERA_SCALE, Color(1.0, 0.92, 0.2))
		if explosion_timer > 0.0 and explosion_pos != Vector2.INF:
			_draw_explosion()
		_draw_wind_widget()
		_draw_turn_widget()
		if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
			_draw_realtime_projectiles()
			_draw_realtime_cooldown_widgets()
			_draw_steam_puffs()
		return
	_mode_runtime_draw()

func _draw_snow_caps() -> void:
	if terrain_points.size() < 2:
		return
	var segment: PackedVector2Array = PackedVector2Array()
	for i: int in range(terrain_points.size()):
		var p: Vector2 = terrain_points[i]
		if p.y <= SNOW_LINE_Y:
			segment.append(_world_to_screen(p))
		else:
			_draw_snow_segment(segment)
			segment = PackedVector2Array()
	_draw_snow_segment(segment)

func _draw_snow_segment(segment: PackedVector2Array) -> void:
	if segment.size() < 2:
		return
	for i: int in range(segment.size() - 1):
		draw_line(segment[i], segment[i + 1], Color(0.92, 0.96, 1.0, 0.95), SNOW_EDGE_WIDTH)
		draw_line(segment[i] + Vector2(0, 4), segment[i + 1] + Vector2(0, 4), Color(0.74, 0.86, 1.0, 0.42), 2.0)

func _is_snow_at_x(x: float) -> bool:
	return _ground_y_at_x(x) <= SNOW_LINE_Y

func _terrain_slope_at_x(x: float) -> float:
	var dx: float = TERRAIN_STEP * 3.0
	var left_y: float = _ground_y_at_x(clampf(x - dx, 0.0, active_world_width))
	var right_y: float = _ground_y_at_x(clampf(x + dx, 0.0, active_world_width))
	return (right_y - left_y) / (2.0 * dx)

func _pond_at_x(x: float) -> Dictionary:
	return WaterManager.pond_at_x(
		ponds, terrain_points, x, TERRAIN_STEP, WATER_MIN_VISIBLE_DEPTH
	)

func _tank_y_for_surface(player: int, x: float) -> float:
	return WaterManager.tank_y_for_surface(
		ponds, terrain_points, x, TERRAIN_STEP, TANK_RADIUS,
		WATER_MIN_VISIBLE_DEPTH, WATER_FLOAT_TANK_SUBMERGENCE
	)

func _movement_speed_mult_at_x(x: float) -> float:
	return WaterManager.movement_speed_mult_at_x(
		ponds, terrain_points, x, TERRAIN_STEP,
		WATER_MIN_VISIBLE_DEPTH, WATER_DRIVE_SPEED_MULT
	)

func _draw_ponds_under_ground() -> void:
	for pond: Dictionary in ponds:
		var start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
		var end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
		var water_y: float = float(pond.get("water_y", 0.0))
		if end_i <= start_i:
			continue
		var start_x: float = terrain_points[start_i].x
		var end_x: float = terrain_points[end_i].x
		var top_left: Vector2 = _world_to_screen(Vector2(start_x, water_y))
		var bottom_right: Vector2 = _world_to_screen(Vector2(end_x, _bottom_floor_y() + 260.0))
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(0.035, 0.22, 0.50, 0.95), true)

func _draw_water_surfaces() -> void:
	for pond: Dictionary in ponds:
		var start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
		var end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
		var water_y: float = float(pond.get("water_y", 0.0))
		var segment_start: int = -1
		for i: int in range(start_i, end_i + 1):
			var visible: bool = terrain_points[i].y > water_y + WATER_MIN_VISIBLE_DEPTH
			if visible and segment_start < 0:
				segment_start = i
			elif not visible and segment_start >= 0:
				_draw_water_surface_segment(segment_start, i - 1, water_y)
				segment_start = -1
		if segment_start >= 0:
			_draw_water_surface_segment(segment_start, end_i, water_y)

func _draw_water_surface_segment(start_i: int, end_i: int, water_y: float) -> void:
	if end_i <= start_i:
		return
	var left: Vector2 = _world_to_screen(Vector2(terrain_points[start_i].x, water_y))
	var right: Vector2 = _world_to_screen(Vector2(terrain_points[end_i].x, water_y))
	draw_line(left, right, Color(0.18, 0.66, 1.0, 0.88), 3.0)
	draw_line(left + Vector2(0, 3), right + Vector2(0, 3), Color(0.72, 0.92, 1.0, 0.28), 1.5)

func _water_volume_for_range(start_i: int, end_i: int, water_y: float) -> float:
	return WaterManager.water_volume_for_range(
		terrain_points, start_i, end_i, water_y, TERRAIN_STEP
	)

func _add_water_volume_to_pond(pond: Dictionary) -> Dictionary:
	var start_i: int = clampi(int(pond.get("start_i", 0)), 0, terrain_points.size() - 1)
	var end_i: int = clampi(int(pond.get("end_i", 0)), 0, terrain_points.size() - 1)
	var water_y: float = float(pond.get("water_y", 0.0))
	pond["volume"] = _water_volume_for_range(start_i, end_i, water_y)
	return pond

func _solve_water_level_for_volume(left_i: int, right_i: int, target_volume: float) -> float:
	return WaterManager.solve_water_level_for_volume(
		terrain_points, left_i, right_i, target_volume, TERRAIN_STEP,
		WATER_MAX_SURFACE_ITERATIONS
	)

func _reflow_single_pond(pond: Dictionary, _changed_x: float) -> Dictionary:
	# Keep this inherited compatibility hook, but use the same connected-basin
	# algorithm previously reached through MainGame's overriding implementation.
	return WaterManager.reflow_single_pond(
		terrain_points, pond, TERRAIN_STEP, WATER_CONNECTED_MARGIN,
		WATER_MIN_VISIBLE_DEPTH, WATER_MAX_SURFACE_ITERATIONS
	)

func _reflow_water_after_terrain_change(changed_x: float) -> void:
	if ponds.is_empty() or terrain_points.is_empty():
		return
	for i: int in range(ponds.size()):
		ponds[i] = _reflow_single_pond(ponds[i], changed_x)
	ponds = ponds.filter(func(p: Dictionary) -> bool:
		return float(p.get("volume", 0.0)) > 1.0 and int(p.get("end_i", 0)) > int(p.get("start_i", 0))
	)

func _is_in_pond(pos: Vector2) -> bool:
	return WaterManager.is_in_pond(
		ponds, terrain_points, pos, TERRAIN_STEP, WATER_MIN_VISIBLE_DEPTH
	)

func _realtime_projectile_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	if pos.distance_to(tank_positions[target]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		return true
	if _is_in_pond(pos):
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	if pos.x < -100.0 or pos.x > active_world_width + 100.0 or pos.y > _bottom_floor_y() + 180.0:
		return true
	return false

func _draw_realtime_cooldown_widgets() -> void:
	return

func _reset_realtime_charge_state() -> void:
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0
	rt_fire_button_held = false
	rt_keyboard_fire_held = false
	_update_fire_button_charge_style(0.0)

func _update_fire_button_charge_style(charge_ratio: float) -> void:
	if mobile_fire_button == null:
		return
	var color: Color = _charge_button_color(charge_ratio)
	_apply_fire_button_style(color, color.darkened(0.35), Color.WHITE)

func _update_fire_button_unavailable_style() -> void:
	if mobile_fire_button == null:
		return
	_apply_fire_button_style(Color(0.18, 0.18, 0.20, 0.86), Color(0.08, 0.08, 0.10, 0.96), Color(0.75, 0.75, 0.78, 1.0))

func _charge_button_color(charge_ratio: float) -> Color:
	var v: float = clampf(charge_ratio, 0.0, 1.0)
	if v < 0.5:
		var t: float = v / 0.5
		return Color(lerpf(0.10, 1.0, t), 0.80, 0.12, 0.92)
	var t2: float = (v - 0.5) / 0.5
	return Color(1.0, lerpf(0.80, 0.12, t2), 0.08, 0.92)

func _apply_fire_button_style(bg: Color, border: Color, font: Color) -> void:
	if mobile_fire_button == null:
		return
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(16)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.12)
	for state: String in ["normal", "hover", "focus"]:
		mobile_fire_button.add_theme_stylebox_override(state, normal)
	mobile_fire_button.add_theme_stylebox_override("pressed", pressed)
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		mobile_fire_button.add_theme_color_override(color_name, font)

func _snow_adjusted_direction_and_speed(x: float, input_direction: float, base_speed: float) -> Dictionary:
	var direction: float = input_direction
	var speed: float = base_speed
	if not _is_snow_at_x(x):
		return {"direction": direction, "speed": speed, "blocked": false}

	var slope: float = _terrain_slope_at_x(x)
	var blocked: bool = false
	var downhill_direction: float = signf(slope)
	var moving_uphill: bool = input_direction != 0.0 and signf(input_direction) == -downhill_direction and absf(slope) > SNOW_UPHILL_BLOCK_SLOPE
	if moving_uphill:
		blocked = true
		direction = 0.0
	elif input_direction == 0.0 and absf(slope) > SNOW_SLIDE_SLOPE:
		direction = downhill_direction
		speed = SNOW_SLIDE_SPEED
	else:
		speed *= SNOW_DRIVE_MULT
		if input_direction != 0.0 and signf(input_direction) == downhill_direction and absf(slope) > SNOW_SLIDE_SLOPE:
			speed += SNOW_SLIDE_SPEED * 0.45
	return {"direction": direction, "speed": speed, "blocked": blocked}

func _update_tank_movement(delta: float) -> void:
	var input_direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		input_direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		input_direction += 1.0
	var adjusted: Dictionary = _snow_adjusted_direction_and_speed(tank_positions[current_player].x, input_direction, TANK_MOVE_SPEED * _movement_speed_mult_at_x(tank_positions[current_player].x))
	var direction: float = float(adjusted.get("direction", 0.0))
	if direction == 0.0:
		return
	var speed: float = float(adjusted.get("speed", TANK_MOVE_SPEED))
	var new_x: float = LegacyInputMotionPolicy.next_tank_x(
		tank_positions[current_player].x, direction, speed, delta, active_world_width
	)
	var other_player: int = 1 - current_player
	if not LegacyInputMotionPolicy.can_move_without_overlap(new_x, tank_positions[other_player].x):
		return
	tank_positions[current_player].x = new_x
	tank_positions[current_player].y = _tank_y_for_surface(current_player, new_x)

func _update_realtime_player_movement(delta: float) -> void:
	rt_movement_energy = RT_MOVEMENT_ENERGY_MAX
	rt_movement_exhaust_cooldown = 0.0
	var input_direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		input_direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		input_direction += 1.0
	var adjusted: Dictionary = _snow_adjusted_direction_and_speed(tank_positions[HUMAN_PLAYER_INDEX].x, input_direction, TANK_MOVE_SPEED * _movement_speed_mult_at_x(tank_positions[HUMAN_PLAYER_INDEX].x))
	var direction: float = float(adjusted.get("direction", 0.0))
	if direction == 0.0:
		return
	var speed: float = float(adjusted.get("speed", TANK_MOVE_SPEED))
	var new_x: float = clampf(tank_positions[HUMAN_PLAYER_INDEX].x + direction * speed * delta, 45.0, active_world_width - 45.0)
	if absf(new_x - tank_positions[AI_PLAYER_INDEX].x) >= 90.0:
		tank_positions[HUMAN_PLAYER_INDEX].x = new_x
		tank_positions[HUMAN_PLAYER_INDEX].y = _tank_y_for_surface(HUMAN_PLAYER_INDEX, new_x)

func _move_realtime_ai(delta: float) -> void:
	var dx: float = rt_ai_target_x - tank_positions[AI_PLAYER_INDEX].x
	var input_direction: float = 0.0 if absf(dx) < 3.0 else signf(dx)
	var adjusted: Dictionary = _snow_adjusted_direction_and_speed(tank_positions[AI_PLAYER_INDEX].x, input_direction, RT_AI_MOVE_SPEED * _movement_speed_mult_at_x(tank_positions[AI_PLAYER_INDEX].x))
	var direction: float = float(adjusted.get("direction", 0.0))
	if direction == 0.0:
		return
	var speed: float = float(adjusted.get("speed", RT_AI_MOVE_SPEED))
	var new_x: float = tank_positions[AI_PLAYER_INDEX].x + direction * speed * delta
	if input_direction != 0.0:
		if (input_direction > 0.0 and new_x > rt_ai_target_x) or (input_direction < 0.0 and new_x < rt_ai_target_x):
			new_x = rt_ai_target_x
	new_x = clampf(new_x, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
	if absf(new_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
		return
	tank_positions[AI_PLAYER_INDEX].x = new_x
	tank_positions[AI_PLAYER_INDEX].y = _tank_y_for_surface(AI_PLAYER_INDEX, new_x)

# Previously in RealtimeAIAimingBridge. The planning state and noisy aim
# policy now live entirely in the composed RealtimeAIAimingSession.
func _clear_realtime_ai_visual_plan() -> void:
	realtime_ai_aim.clear()

func _choose_realtime_ai_visual_plan() -> void:
	var aim: Dictionary = _find_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX])
	realtime_ai_aim.choose_plan(
		aim, rng, RT_AI_AIM_ERROR_ANGLE, RT_AI_AIM_ERROR_POWER,
		MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE
	)

func _update_realtime_ai(delta: float) -> void:
	if game_over or overlay_open:
		return

	if rt_ai_move_cooldown <= 0.0:
		_choose_realtime_ai_move_target()
		rt_ai_move_cooldown = realtime_ai_aim.next_move_cooldown(rng, RT_AI_MOVE_COOLDOWN_MAX)
		_clear_realtime_ai_visual_plan()

	_move_realtime_ai(delta)

	if not realtime_ai_aim.has_plan:
		_choose_realtime_ai_visual_plan()

	_update_realtime_ai_visual_aim(delta)

	if rt_ai_fire_cooldown <= 0.0:
		if not realtime_ai_aim.ready_to_fire(player_angles[AI_PLAYER_INDEX]):
			return

		player_angles[AI_PLAYER_INDEX] = realtime_ai_aim.target_angle
		player_power_percents[AI_PLAYER_INDEX] = realtime_ai_aim.target_power_percent
		player_powers[AI_PLAYER_INDEX] = _power_from_percent(realtime_ai_aim.target_power_percent)
		_fire_realtime_projectile(AI_PLAYER_INDEX)
		rt_ai_fire_cooldown = realtime_ai_aim.next_fire_cooldown(rng, RT_AI_FIRE_COOLDOWN_MAX)
		_clear_realtime_ai_visual_plan()

func _update_realtime_ai_visual_aim(delta: float) -> void:
	if player_angles.size() <= AI_PLAYER_INDEX:
		return
	player_angles[AI_PLAYER_INDEX] = realtime_ai_aim.next_angle(
		player_angles[AI_PLAYER_INDEX], delta
	)

