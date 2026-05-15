extends "res://scripts/MainStableTweaks.gd"

# Consolidated compatibility layer while flattening the legacy chain.
# MainWithMenus plus later AI/realtime/menu compatibility pieces have been folded
# here while preserving realtime hold-to-charge, improved AI planning, multiplayer
# submenu behavior, and fixed reset-match tank placement.

const MENU_BG_LANDSCAPE_PATH: String = "res://assets/menu/main_menu_background_landscape.png"
const MENU_BG_PORTRAIT_PATH: String = "res://assets/menu/main_menu_background_portrait.png"
const MENU_LOGO_PATH: String = "res://assets/menu/tilt_tanks_logo.png"
const BUTTON_SINGLE_PLAYER_PATH: String = "res://assets/menu/button_single_player.png"
const BUTTON_MULTIPLAYER_PATH: String = "res://assets/menu/button_multiplayer.png"
const BUTTON_OPTIONS_PATH: String = "res://assets/menu/button_options.png"
const BUTTON_QUICK_GAME_PATH: String = "res://assets/menu/button_quick_game.png"
const BUTTON_CAMPAIGN_PATH: String = "res://assets/menu/button_campaign.png"
const BUTTON_BACK_PATH: String = "res://assets/menu/button_back.png"
const BUTTON_HOTSEAT_PATH: String = "res://assets/menu/button_hotseat.png"
const BUTTON_ONLINE_PATH: String = "res://assets/menu/button_online.png"

const MENU_STATE_MAIN: int = 0
const MENU_STATE_SINGLE_PLAYER: int = 1
const MENU_STATE_OPTIONS: int = 2
const MENU_STATE_MULTIPLAYER: int = 3
const MENU_STATE_GAME: int = 4

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

const STEAM_PUFF_LIFETIME: float = 0.95
const STEAM_PUFF_RISE_SPEED: float = 34.0
const STEAM_PUFF_DRIFT_SPEED: float = 18.0
const STEAM_PUFF_START_RADIUS: float = 4.0
const STEAM_PUFF_END_RADIUS: float = 13.0

var menu_state: int = MENU_STATE_MAIN
var menu_layer: CanvasLayer
var menu_buttons: Array[Control] = []
var menu_logo_texture: Texture2D
var menu_bg_landscape_texture: Texture2D
var menu_bg_portrait_texture: Texture2D
var single_player_mode: bool = false

var game_mode: int = GAME_MODE_HOTSEAT
var ai_pending_turn: bool = false
var ai_think_timer: float = 0.0

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

func _ready() -> void:
	super._ready()
	_load_menu_assets()
	_build_menu_layer()
	_show_main_menu()

func _on_mobile_fire_pressed() -> void:
	return

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
	super._process(delta)

func _draw() -> void:
	if menu_state == MENU_STATE_GAME:
		super._draw()
		return
	_draw_menu_background()

func _load_menu_assets() -> void:
	menu_bg_landscape_texture = _load_texture_if_exists(MENU_BG_LANDSCAPE_PATH)
	menu_bg_portrait_texture = _load_texture_if_exists(MENU_BG_PORTRAIT_PATH)
	menu_logo_texture = _load_texture_if_exists(MENU_LOGO_PATH)

func _load_texture_if_exists(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_menu_layer() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)

func _show_main_menu() -> void:
	menu_state = MENU_STATE_MAIN
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Single Player", BUTTON_SINGLE_PLAYER_PATH, Vector2(0.5, 0.54), Vector2(310, 72), _on_single_player_pressed)
	_add_menu_button("Multiplayer", BUTTON_MULTIPLAYER_PATH, Vector2(0.5, 0.65), Vector2(310, 72), _on_multiplayer_pressed)
	_add_menu_button("Options", BUTTON_OPTIONS_PATH, Vector2(0.5, 0.76), Vector2(310, 72), _on_options_pressed)
	queue_redraw()

func _show_single_player_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Quick Game", BUTTON_QUICK_GAME_PATH, Vector2(0.5, 0.58), Vector2(310, 72), _on_quick_game_pressed)
	_add_menu_button("Campaign", BUTTON_CAMPAIGN_PATH, Vector2(0.5, 0.69), Vector2(310, 72), _on_campaign_pressed)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.82), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _show_multiplayer_menu() -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Hotseat", BUTTON_HOTSEAT_PATH, Vector2(0.5, 0.58), Vector2(310, 72), _on_hotseat_pressed)
	_add_menu_button("Online", BUTTON_ONLINE_PATH, Vector2(0.5, 0.69), Vector2(310, 72), _on_online_pressed)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.82), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _show_placeholder_menu(title: String) -> void:
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label(title, Vector2(0.5, 0.54), Vector2(420, 60), 28)
	_add_text_label("Coming soon", Vector2(0.5, 0.62), Vector2(420, 44), 20)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.76), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _on_single_player_pressed() -> void:
	_show_single_player_menu()

func _on_multiplayer_pressed() -> void:
	_show_multiplayer_menu()

func _on_options_pressed() -> void:
	menu_state = MENU_STATE_OPTIONS
	_show_placeholder_menu("Options")

func _on_campaign_pressed() -> void:
	_show_placeholder_menu("Campaign")

func _on_online_pressed() -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label("Online", Vector2(0.5, 0.54), Vector2(420, 60), 28)
	_add_text_label("Coming soon", Vector2(0.5, 0.62), Vector2(420, 44), 20)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.76), Vector2(210, 58), _show_multiplayer_menu)
	queue_redraw()

func _on_quick_game_pressed() -> void:
	game_mode = GAME_MODE_SINGLE_PLAYER_REALTIME
	_start_game(true)

func _on_hotseat_pressed() -> void:
	game_mode = GAME_MODE_HOTSEAT
	_start_game(false)

func _start_game(is_single_player: bool) -> void:
	single_player_mode = is_single_player
	_clear_menu_controls()
	menu_state = MENU_STATE_GAME
	_show_game_ui()
	reset_match()
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		_setup_realtime_single_player()
	queue_redraw()

func _hide_game_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = false

func _show_game_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = true

func _clear_menu_controls() -> void:
	for control: Control in menu_buttons:
		if is_instance_valid(control):
			control.queue_free()
	menu_buttons.clear()

func _add_text_label(text: String, anchor: Vector2, size: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = size
	label.position = _anchored_position(anchor, size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	menu_layer.add_child(label)
	menu_buttons.append(label)
	return label

func _add_menu_button(text: String, texture_path: String, anchor: Vector2, size: Vector2, callback: Callable) -> Control:
	var texture: Texture2D = _load_texture_if_exists(texture_path)
	if texture != null:
		var texture_button: TextureButton = TextureButton.new()
		texture_button.texture_normal = texture
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_SCALE
		texture_button.size = size
		texture_button.position = _anchored_position(anchor, size)
		texture_button.focus_mode = Control.FOCUS_NONE
		texture_button.pressed.connect(callback)
		menu_layer.add_child(texture_button)
		menu_buttons.append(texture_button)
		return texture_button

	var button: Button = Button.new()
	button.text = text
	button.size = size
	button.position = _anchored_position(anchor, size)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	_style_menu_button(button)
	menu_layer.add_child(button)
	menu_buttons.append(button)
	return button

func _style_menu_button(button: Button) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.12, 0.16, 0.88)
	normal.border_color = Color(0.55, 0.82, 0.95, 0.65)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(18)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.17, 0.28, 0.34, 0.95)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 24)

func _anchored_position(anchor: Vector2, size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(viewport_size.x * anchor.x - size.x * 0.5, viewport_size.y * anchor.y - size.y * 0.5)

func reset_match() -> void:
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
	ai_pending_turn = false
	ai_think_timer = 0.0

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

func _is_ai_turn_active() -> bool:
	return game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and current_player == AI_PLAYER_INDEX and not projectile_active and not game_over and not overlay_open

func _is_ai_turn_waiting_for_explosion() -> bool:
	return game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and current_player == AI_PLAYER_INDEX and not projectile_active and not game_over and not overlay_open and explosion_timer > 0.0

func _advance_turn() -> void:
	super._advance_turn()
	if _is_ai_turn_active():
		_begin_ai_turn()
	else:
		ai_pending_turn = false

func _process_ai_turn(delta: float) -> void:
	if not ai_pending_turn:
		_begin_ai_turn()
	ai_think_timer -= delta
	_update_camera(delta)
	_update_ui()
	queue_redraw()
	if ai_think_timer <= 0.0:
		ai_pending_turn = false
		_take_ai_shot()

func _process_ai_turn_waiting_for_explosion(delta: float) -> void:
	explosion_timer -= delta
	if explosion_timer <= 0.0:
		explosion_timer = 0.0
		explosion_pos = Vector2.INF
		ai_pending_turn = false
	_update_camera(delta)
	_update_ui()
	queue_redraw()

func _begin_ai_turn() -> void:
	ai_pending_turn = true
	ai_think_timer = AI_THINK_TIME_SLOWER
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

func _find_ai_plan() -> Dictionary:
	var best_score: float = AI_MAX_SCORE_DISTANCE
	var best_angle: float = 45.0
	var best_power_percent: float = 55.0
	var best_x: float = tank_positions[AI_PLAYER_INDEX].x
	var start_x: float = tank_positions[AI_PLAYER_INDEX].x
	for offset: float in AI_MOVE_OFFSETS:
		var candidate_x: float = clampf(start_x + offset, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
		if absf(candidate_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
			continue
		var candidate_y: float = _ground_y_at_x(candidate_x) - TANK_RADIUS
		var candidate_pos: Vector2 = Vector2(candidate_x, candidate_y)
		var move_penalty: float = absf(candidate_x - start_x) * AI_MOVE_PENALTY_PER_PIXEL
		for test_angle: int in range(AI_MIN_ANGLE_DEG, AI_MAX_ANGLE_DEG + 1, AI_ANGLE_STEP_DEG + 2):
			for test_power_percent: int in range(AI_MIN_POWER_PERCENT, AI_MAX_POWER_PERCENT + 1, AI_POWER_STEP_PERCENT + 3):
				var score: float = _score_ai_shot_from_position(candidate_pos, float(test_angle), float(test_power_percent))
				score += move_penalty
				score += rng.randf_range(0.0, AI_SCORE_RANDOMNESS)
				if score < best_score:
					best_score = score
					best_angle = float(test_angle)
					best_power_percent = float(test_power_percent)
					best_x = candidate_x
	if rng.randf() > AI_MOVE_CHANCE:
		best_x = start_x
		var stationary: Dictionary = _find_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX])
		best_angle = float(stationary.get("angle", best_angle))
		best_power_percent = float(stationary.get("power_percent", best_power_percent))
	return {"angle": best_angle, "power_percent": best_power_percent, "move_x": best_x, "score": best_score}

func _find_ai_shot() -> Dictionary:
	return _find_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX])

func _find_ai_shot_from_position(shooter_pos: Vector2) -> Dictionary:
	var best_score: float = AI_MAX_SCORE_DISTANCE
	var best_angle: float = 45.0
	var best_power_percent: float = 55.0
	for test_angle: int in range(AI_MIN_ANGLE_DEG, AI_MAX_ANGLE_DEG + 1, AI_ANGLE_STEP_DEG + 2):
		for test_power_percent: int in range(AI_MIN_POWER_PERCENT, AI_MAX_POWER_PERCENT + 1, AI_POWER_STEP_PERCENT + 3):
			var score: float = _score_ai_shot_from_position(shooter_pos, float(test_angle), float(test_power_percent))
			score += rng.randf_range(0.0, AI_SCORE_RANDOMNESS)
			if score < best_score:
				best_score = score
				best_angle = float(test_angle)
				best_power_percent = float(test_power_percent)
	return {"angle": best_angle, "power_percent": best_power_percent, "score": best_score}

func _score_ai_shot(test_angle_deg: float, test_power_percent: float) -> float:
	return _score_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX], test_angle_deg, test_power_percent)

func _score_ai_shot_from_position(shooter_pos: Vector2, test_angle_deg: float, test_power_percent: float) -> float:
	var facing: float = -1.0
	var rad: float = deg_to_rad(test_angle_deg)
	var test_power: float = _power_from_percent(test_power_percent)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var pos: Vector2 = shooter_pos + muzzle_offset
	var vel: Vector2 = Vector2(facing * test_power * cos(rad), -test_power * sin(rad))
	var target_pos: Vector2 = tank_positions[HUMAN_PLAYER_INDEX] + Vector2(rng.randf_range(-28.0, 28.0), rng.randf_range(-8.0, 8.0))
	var best_distance: float = pos.distance_to(target_pos)
	var elapsed: float = 0.0
	while elapsed < AI_SIM_MAX_TIME:
		vel.y += gravity * AI_SIM_DT
		vel.x += wind * AI_SIM_DT
		pos += vel * AI_SIM_DT
		elapsed += AI_SIM_DT
		best_distance = minf(best_distance, pos.distance_to(target_pos))
		if pos.x < -100.0 or pos.x > active_world_width + 100.0:
			break
		if pos.y > _bottom_floor_y() + 180.0:
			break
		var ground_y: float = _ground_y_at_x(pos.x)
		if pos.y >= ground_y:
			best_distance = minf(best_distance, Vector2(pos.x, ground_y).distance_to(target_pos))
			break
	return best_distance

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

func _update_realtime_player_movement(delta: float) -> void:
	return

func _move_realtime_ai(delta: float) -> void:
	return

func _fire_realtime_projectile(owner: int) -> void:
	return

func _update_realtime_cooldowns(delta: float) -> void:
	rt_player_fire_cooldown = maxf(0.0, rt_player_fire_cooldown - delta)
	rt_ai_fire_cooldown = maxf(0.0, rt_ai_fire_cooldown - delta)
	rt_ai_move_cooldown = maxf(0.0, rt_ai_move_cooldown - delta)
	if rt_movement_exhaust_cooldown > 0.0:
		rt_movement_exhaust_cooldown = maxf(0.0, rt_movement_exhaust_cooldown - delta)
		movement_was_overheated = true
		if rt_movement_exhaust_cooldown <= 0.0:
			rt_movement_energy = maxf(rt_movement_energy, RT_MOVEMENT_ENERGY_MAX * 0.25)
	else:
		movement_was_overheated = false

func _update_realtime_ai(delta: float) -> void:
	if game_over or overlay_open:
		return
	if rt_ai_move_cooldown <= 0.0:
		_choose_realtime_ai_move_target()
		rt_ai_move_cooldown = rng.randf_range(RT_AI_MOVE_COOLDOWN_MAX * 0.65, RT_AI_MOVE_COOLDOWN_MAX * 1.25)
	_move_realtime_ai(delta)
	if rt_ai_fire_cooldown <= 0.0:
		_prepare_realtime_ai_shot()
		_fire_realtime_projectile(AI_PLAYER_INDEX)
		rt_ai_fire_cooldown = rng.randf_range(RT_AI_FIRE_COOLDOWN_MAX * 0.75, RT_AI_FIRE_COOLDOWN_MAX * 1.25)

func _choose_realtime_ai_move_target() -> void:
	if rng.randf() > RT_AI_MOVE_CHANCE:
		rt_ai_target_x = tank_positions[AI_PLAYER_INDEX].x
		return
	var move_options: Array[float] = [-100.0, -55.0, 0.0, 55.0, 100.0]
	var best_x: float = tank_positions[AI_PLAYER_INDEX].x
	var best_score: float = INF
	for offset: float in move_options:
		var candidate_x: float = clampf(tank_positions[AI_PLAYER_INDEX].x + offset, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
		if absf(candidate_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
			continue
		var candidate_y: float = _ground_y_at_x(candidate_x) - TANK_RADIUS
		var candidate_pos: Vector2 = Vector2(candidate_x, candidate_y)
		var shot: Dictionary = _find_ai_shot_from_position(candidate_pos)
		var score: float = float(shot.get("score", 999999.0)) + absf(offset) * 0.2 + rng.randf_range(0.0, 100.0)
		if score < best_score:
			best_score = score
			best_x = candidate_x
	rt_ai_target_x = best_x

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
	return super._camera_target_x()

func _draw_realtime_projectiles() -> void:
	for shell: Dictionary in rt_projectiles:
		var owner: int = int(shell.get("owner", HUMAN_PLAYER_INDEX))
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var color: Color = Color(1.0, 0.92, 0.2) if owner == HUMAN_PLAYER_INDEX else Color(1.0, 0.38, 0.25)
		draw_circle(_world_to_screen(pos), PROJECTILE_RADIUS * CAMERA_SCALE, color)

func _draw_realtime_cooldown_widgets() -> void:
	return

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
	super._update_ui()
	if menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and current_player == AI_PLAYER_INDEX and not game_over:
		status_label.text = "Computer thinking...   P1 HP: %d    CPU HP: %d" % [tank_health[0], tank_health[1]]
	elif menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and not game_over:
		status_label.text = "Your turn   P1 HP: %d    CPU HP: %d" % [tank_health[0], tank_health[1]]

func _update_steam_puffs(delta: float) -> void:
	if steam_puffs.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for puff: Dictionary in steam_puffs:
		var age: float = float(puff.get("age", 0.0)) + delta
		var life: float = float(puff.get("life", STEAM_PUFF_LIFETIME))
		if age < life:
			var pos: Vector2 = puff.get("pos", Vector2.ZERO)
			var drift: float = float(puff.get("drift", 0.0))
			pos.x += drift * delta
			pos.y -= STEAM_PUFF_RISE_SPEED * delta
			puff["age"] = age
			puff["pos"] = pos
			remaining.append(puff)
	steam_puffs = remaining

func _draw_steam_puffs() -> void:
	for puff: Dictionary in steam_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", STEAM_PUFF_LIFETIME))
		var t: float = clampf(age / life, 0.0, 1.0)
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = lerpf(STEAM_PUFF_START_RADIUS, STEAM_PUFF_END_RADIUS, t) * CAMERA_SCALE
		var alpha: float = 0.52 * (1.0 - t)
		draw_circle(_world_to_screen(pos), radius, Color(0.88, 0.90, 0.86, alpha))

func _randomize_wind() -> void:
	var display_wind: float = rng.randf_range(-WIND_DISPLAY_MAX, WIND_DISPLAY_MAX)
	wind = display_wind / WIND_DISPLAY_MAX * WIND_METER_MAX_ACCEL

func _draw_wind_widget() -> void:
	var box: Rect2 = Rect2(Vector2(18, 132), Vector2(178, 42))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.62), true)
	draw_rect(box, Color(0.85, 0.90, 1.0, 0.30), false, 1.0)
	var meter_left: float = box.position.x + 46.0
	var meter_right: float = box.position.x + box.size.x - 18.0
	var meter_center: float = (meter_left + meter_right) * 0.5
	var meter_y: float = box.position.y + 22.0
	var half_width: float = (meter_right - meter_left) * 0.5
	var display_wind: float = _wind_display_value()
	var strength: float = clampf(absf(display_wind) / WIND_DISPLAY_MAX, 0.0, 1.0)
	var fill_width: float = half_width * strength
	var bar_color: Color = _wind_strength_color(strength)
	draw_line(Vector2(meter_left, meter_y), Vector2(meter_right, meter_y), Color(0.55, 0.65, 0.75, 0.45), 8.0)
	draw_line(Vector2(meter_center, meter_y - 13.0), Vector2(meter_center, meter_y + 13.0), Color.WHITE, 2.0)
	if display_wind >= 0.0:
		draw_line(Vector2(meter_center, meter_y), Vector2(meter_center + fill_width, meter_y), bar_color, 8.0)
		_draw_small_arrow(Vector2(meter_center + fill_width + 4.0, meter_y), 1.0, bar_color)
	else:
		draw_line(Vector2(meter_center, meter_y), Vector2(meter_center - fill_width, meter_y), bar_color, 8.0)
		_draw_small_arrow(Vector2(meter_center - fill_width - 4.0, meter_y), -1.0, bar_color)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 8.0, box.position.y + 27.0), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x + box.size.x - 48.0, box.position.y + 35.0), "%+.0f" % display_wind, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _wind_display_value() -> float:
	return clampf(wind / WIND_METER_MAX_ACCEL * WIND_DISPLAY_MAX, -WIND_DISPLAY_MAX, WIND_DISPLAY_MAX)

func _wind_strength_color(strength: float) -> Color:
	var s: float = clampf(strength, 0.0, 1.0)
	if s < 0.55:
		return Color(0.35, 0.95, 0.35, 0.92)
	if s < 0.82:
		var t: float = (s - 0.55) / 0.27
		return Color(lerpf(0.35, 1.0, t), 0.95, lerpf(0.35, 0.08, t), 0.92)
	var t2: float = (s - 0.82) / 0.18
	return Color(1.0, lerpf(0.95, 0.12, t2), 0.08, 0.92)

func _draw_small_arrow(tip: Vector2, direction: float, color: Color) -> void:
	var d: float = signf(direction)
	if d == 0.0:
		return
	var p1: Vector2 = tip
	var p2: Vector2 = tip + Vector2(-8.0 * d, -6.0)
	var p3: Vector2 = tip + Vector2(-8.0 * d, 6.0)
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), color)

func _draw_menu_background() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	var viewport_size: Vector2 = viewport_rect.size
	var use_landscape: bool = viewport_size.x >= viewport_size.y
	var bg_texture: Texture2D = menu_bg_landscape_texture if use_landscape else menu_bg_portrait_texture
	if bg_texture != null:
		draw_texture_rect(bg_texture, Rect2(Vector2.ZERO, viewport_size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.04, 0.05, 0.12), true)
		_draw_fallback_menu_background(viewport_size)
	if menu_logo_texture != null:
		_draw_menu_logo_texture(viewport_size, use_landscape)
	else:
		_draw_fallback_logo(viewport_size, use_landscape)

func _draw_menu_logo_texture(viewport_size: Vector2, use_landscape: bool) -> void:
	var target_width: float = viewport_size.x * (0.36 if use_landscape else 0.70)
	var aspect: float = float(menu_logo_texture.get_width()) / float(menu_logo_texture.get_height())
	var target_size: Vector2 = Vector2(target_width, target_width / aspect)
	var y: float = viewport_size.y * (0.12 if use_landscape else 0.09)
	var rect: Rect2 = Rect2(Vector2((viewport_size.x - target_size.x) * 0.5, y), target_size)
	draw_texture_rect(menu_logo_texture, rect, false)

func _draw_fallback_logo(viewport_size: Vector2, use_landscape: bool) -> void:
	var title_y: float = viewport_size.y * (0.14 if use_landscape else 0.11)
	var subtitle_y: float = title_y + 48.0
	draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 95.0, title_y), "TILT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 125.0, subtitle_y), "TANKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1.0, 0.70, 0.08))

func _draw_fallback_menu_background(viewport_size: Vector2) -> void:
	var horizon_y: float = viewport_size.y * 0.56
	var hill_y: float = viewport_size.y * 0.72
	for i: int in range(8):
		var t: float = float(i) / 7.0
		var y0: float = viewport_size.y * t
		var color: Color = Color(0.04 + 0.15 * t, 0.05, 0.16 + 0.20 * t)
		draw_rect(Rect2(Vector2(0, y0), Vector2(viewport_size.x, viewport_size.y / 7.0 + 2.0)), color, true)
	draw_circle(Vector2(viewport_size.x * 0.50, horizon_y), 24.0, Color(1.0, 0.78, 0.18, 0.95))
	var mountains: PackedVector2Array = PackedVector2Array()
	mountains.append(Vector2(0, horizon_y + 85.0))
	for i: int in range(8):
		var x: float = viewport_size.x * float(i) / 7.0
		var y: float = horizon_y + 80.0 - 90.0 * absf(sin(float(i) * 1.37))
		mountains.append(Vector2(x, y))
	mountains.append(Vector2(viewport_size.x, horizon_y + 85.0))
	draw_colored_polygon(mountains, Color(0.19, 0.11, 0.32, 0.95))
	var hill: PackedVector2Array = PackedVector2Array()
	hill.append(Vector2(0, viewport_size.y))
	for i: int in range(30):
		var x2: float = viewport_size.x * float(i) / 29.0
		var y2: float = hill_y + 32.0 * sin(float(i) * 0.42)
		hill.append(Vector2(x2, y2))
	hill.append(Vector2(viewport_size.x, viewport_size.y))
	draw_colored_polygon(hill, Color(0.08, 0.25, 0.08, 1.0))
