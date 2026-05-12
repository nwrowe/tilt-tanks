extends "res://scripts/MainHybridModes4.gd"

const RT_CHARGE_TIME_MAX: float = 1.65
const RT_CHARGE_MIN_PERCENT: float = 10.0
const RT_CHARGE_MAX_PERCENT: float = 100.0

var rt_fire_button_held: bool = false
var rt_keyboard_fire_held: bool = false
var rt_fire_charge_time: float = 0.0
var rt_fire_charge_percent: float = 0.0

func _ready() -> void:
	super._ready()
	if mobile_fire_button != null:
		mobile_fire_button.button_down.connect(_on_realtime_fire_button_down)
		mobile_fire_button.button_up.connect(_on_realtime_fire_button_up)

func _setup_realtime_single_player() -> void:
	super._setup_realtime_single_player()
	rt_fire_button_held = false
	rt_keyboard_fire_held = false
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0
	_show_realtime_power_ui(false)

func _on_hotseat_pressed() -> void:
	_show_realtime_power_ui(true)
	super._on_hotseat_pressed()

func _show_game_ui() -> void:
	super._show_game_ui()
	_show_realtime_power_ui(game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME)

func _show_realtime_power_ui(show_slider: bool) -> void:
	if power_slider != null:
		power_slider.visible = show_slider
	if power_label != null:
		power_label.visible = true

func _on_mobile_fire_pressed() -> void:
	# In realtime single-player, mobile fire is handled by button_down/button_up.
	# This prevents the old turn-based _on_fire_pressed() path from creating a
	# legacy projectile that appears at the turret tip but does not move.
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME:
		if mobile_fire_button != null:
			mobile_fire_button.release_focus()
		return
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()
	_on_fire_pressed()

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
	queue_redraw()

func _update_realtime_fire_charge(delta: float) -> void:
	# Keyboard/desktop support: hold Space / ui_accept to charge, release to fire.
	var keyboard_down: bool = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)
	if keyboard_down and not rt_keyboard_fire_held and _player_can_fire():
		rt_keyboard_fire_held = true
		rt_fire_charge_time = 0.0
		rt_fire_charge_percent = RT_CHARGE_MIN_PERCENT
	elif not keyboard_down and rt_keyboard_fire_held:
		rt_keyboard_fire_held = false
		_release_realtime_charged_shot()

	if rt_fire_button_held or rt_keyboard_fire_held:
		rt_fire_charge_time = minf(RT_CHARGE_TIME_MAX, rt_fire_charge_time + delta)
		var charge_ratio: float = clampf(rt_fire_charge_time / RT_CHARGE_TIME_MAX, 0.0, 1.0)
		rt_fire_charge_percent = lerpf(RT_CHARGE_MIN_PERCENT, RT_CHARGE_MAX_PERCENT, charge_ratio)
		power_percent = rt_fire_charge_percent
		power = _power_from_percent(power_percent)

func _release_realtime_charged_shot() -> void:
	if not _player_can_fire() or game_over or overlay_open:
		return
	power_percent = clampf(rt_fire_charge_percent, RT_CHARGE_MIN_PERCENT, RT_CHARGE_MAX_PERCENT)
	power = _power_from_percent(power_percent)
	player_angles[HUMAN_PLAYER_INDEX] = angle_deg
	player_power_percents[HUMAN_PLAYER_INDEX] = power_percent
	player_powers[HUMAN_PLAYER_INDEX] = power
	_fire_realtime_projectile(HUMAN_PLAYER_INDEX)
	rt_player_fire_cooldown = RT_PLAYER_FIRE_COOLDOWN_MAX
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0

func _update_realtime_power() -> void:
	# Realtime single-player no longer uses the slider. Power comes from the
	# hold-to-charge fire button. Preserve the previous charge value only for UI.
	player_angles[HUMAN_PLAYER_INDEX] = angle_deg
	player_power_percents[HUMAN_PLAYER_INDEX] = power_percent
	player_powers[HUMAN_PLAYER_INDEX] = _power_from_percent(power_percent)

func _update_realtime_player_movement(delta: float) -> void:
	# Unlimited movement in realtime single-player: no movement energy drain or
	# overheat cooldown. Movement cooldown variables are reset so old UI/states do
	# not linger.
	rt_movement_energy = RT_MOVEMENT_ENERGY_MAX
	rt_movement_exhaust_cooldown = 0.0
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0
	if direction == 0.0:
		return
	var new_x: float = clampf(tank_positions[HUMAN_PLAYER_INDEX].x + direction * TANK_MOVE_SPEED * delta, 45.0, active_world_width - 45.0)
	if absf(new_x - tank_positions[AI_PLAYER_INDEX].x) >= 90.0:
		tank_positions[HUMAN_PLAYER_INDEX].x = new_x
		tank_positions[HUMAN_PLAYER_INDEX].y = _ground_y_at_x(new_x) - TANK_RADIUS

func _draw_realtime_cooldown_widgets() -> void:
	var base: Vector2 = Vector2(18.0, 184.0)
	var fire_ready: float = 1.0 - clampf(rt_player_fire_cooldown / RT_PLAYER_FIRE_COOLDOWN_MAX, 0.0, 1.0)
	if rt_fire_button_held or rt_keyboard_fire_held:
		fire_ready = clampf(rt_fire_charge_percent / RT_CHARGE_MAX_PERCENT, 0.0, 1.0)
		_draw_meter(base, "CHARGE", fire_ready)
	else:
		_draw_meter(base, "FIRE", fire_ready)

func _update_ui() -> void:
	super._update_ui()
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME and not game_over:
		if rt_fire_button_held or rt_keyboard_fire_held:
			power_label.text = "Charge: %.0f%%" % rt_fire_charge_percent
		elif rt_player_fire_cooldown > 0.0:
			power_label.text = "Fire cooling"
		else:
			power_label.text = "Hold FIRE"
