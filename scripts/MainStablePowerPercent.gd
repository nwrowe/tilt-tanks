extends "res://scripts/Main.gd"

const POWER_FORCE_MIN: float = 400.0
const POWER_FORCE_MAX: float = 1200.0
const POWER_PERCENT_DEFAULT: float = 50.0

var power_percent: float = POWER_PERCENT_DEFAULT
var player_power_percents: Array[float] = [POWER_PERCENT_DEFAULT, POWER_PERCENT_DEFAULT]

func _ready() -> void:
	rng.randomize()
	terrain.visible = false
	reset_button.visible = false
	fire_button.visible = false
	power_slider.min_value = 0.0
	power_slider.max_value = 100.0
	power_slider.step = 1.0
	power_slider.focus_mode = Control.FOCUS_NONE
	fire_button.focus_mode = Control.FOCUS_NONE
	reset_button.focus_mode = Control.FOCUS_NONE
	_build_overlay_ui()
	reset_match()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_match()

	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
		_on_fire_pressed()

	if not projectile_active and not game_over and not overlay_open:
		_update_angle_from_input(delta)
		_update_tank_movement(delta)
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

func _power_from_percent(percent: float) -> float:
	return lerpf(POWER_FORCE_MIN, POWER_FORCE_MAX, clampf(percent, 0.0, 100.0) / 100.0)

func _on_fire_pressed() -> void:
	if projectile_active or game_over or overlay_open:
		return
	power_slider.release_focus()
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	projectile_pos = tank_positions[current_player] + muzzle_offset
	projectile_vel = Vector2(facing * power * cos(rad), -power * sin(rad))
	projectile_active = true

func _end_turn_without_shot() -> void:
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	_advance_turn()

func _load_current_player_settings() -> void:
	angle_deg = player_angles[current_player]
	power_percent = player_power_percents[current_player]
	power = _power_from_percent(power_percent)
	power_slider.value = power_percent
	power_slider.release_focus()

func reset_match() -> void:
	_hide_overlays()
	current_player = 0
	player_angles = [45.0, 45.0]
	player_power_percents = [POWER_PERCENT_DEFAULT, POWER_PERCENT_DEFAULT]
	player_powers = [_power_from_percent(POWER_PERCENT_DEFAULT), _power_from_percent(POWER_PERCENT_DEFAULT)]
	angle_deg = 45.0
	power_percent = POWER_PERCENT_DEFAULT
	power = _power_from_percent(power_percent)
	power_slider.value = power_percent
	power_slider.release_focus()
	turn_timer = TURN_TIME_LIMIT
	wind = rng.randf_range(-MAX_WIND_ACCEL, MAX_WIND_ACCEL)
	tank_health = [100, 100]
	tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(TANK_START_RIGHT_X, 0.0)]
	projectile_active = false
	projectile_pos = Vector2.ZERO
	projectile_vel = Vector2.ZERO
	explosion_pos = Vector2.INF
	explosion_timer = 0.0
	game_over = false
	mobile_left_pressed = false
	mobile_right_pressed = false
	_generate_random_terrain()
	camera_x = _camera_target_x()

func _update_ui() -> void:
	angle_label.text = "Angle: %.1f" % angle_deg
	power_label.text = "Power: %.0f%%" % power_percent
	if game_over:
		var winner: int = 1 if tank_health[0] <= 0 else 0
		status_label.text = "Player %d wins!  P1 HP: %d  P2 HP: %d" % [winner + 1, tank_health[0], tank_health[1]]
	else:
		status_label.text = "P1 HP: %d    P2 HP: %d" % [tank_health[0], tank_health[1]]
