extends "res://scripts/MainWithAI2.gd"

const GAME_MODE_SINGLE_PLAYER_REALTIME: int = 2

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

var rt_player_fire_cooldown: float = 0.0
var rt_ai_fire_cooldown: float = 2.2
var rt_movement_energy: float = RT_MOVEMENT_ENERGY_MAX
var rt_ai_move_cooldown: float = 1.0
var rt_ai_target_x: float = 0.0
var rt_projectile_owner: int = HUMAN_PLAYER_INDEX

func _on_quick_game_pressed() -> void:
	game_mode = GAME_MODE_SINGLE_PLAYER_REALTIME
	_start_game(true)

func _start_game(is_single_player: bool) -> void:
	super._start_game(is_single_player)
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		_setup_realtime_single_player()

func _setup_realtime_single_player() -> void:
	current_player = HUMAN_PLAYER_INDEX
	rt_player_fire_cooldown = 0.0
	rt_ai_fire_cooldown = rng.randf_range(2.0, RT_AI_FIRE_COOLDOWN_MAX)
	rt_movement_energy = RT_MOVEMENT_ENERGY_MAX
	rt_ai_move_cooldown = rng.randf_range(1.0, RT_AI_MOVE_COOLDOWN_MAX)
	rt_ai_target_x = tank_positions[AI_PLAYER_INDEX].x
	angle_deg = player_angles[HUMAN_PLAYER_INDEX]
	power_percent = player_power_percents[HUMAN_PLAYER_INDEX]
	power = _power_from_percent(power_percent)
	power_slider.value = power_percent

func _process(delta: float) -> void:
	if menu_state != MENU_STATE_GAME:
		queue_redraw()
		return
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		_process_realtime_single_player(delta)
		return
	super._process(delta)

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
		_update_realtime_ai(delta)
		if _player_fire_requested() and _player_can_fire():
			_fire_realtime_projectile(HUMAN_PLAYER_INDEX)
			rt_player_fire_cooldown = RT_PLAYER_FIRE_COOLDOWN_MAX

	if projectile_active:
		_update_realtime_projectile(delta)

	if explosion_timer > 0.0:
		explosion_timer -= delta
		if explosion_timer <= 0.0:
			explosion_pos = Vector2.INF

	_update_camera(delta)
	_update_ui()
	queue_redraw()

func _player_fire_requested() -> bool:
	return Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)

func _player_can_fire() -> bool:
	return not projectile_active and rt_player_fire_cooldown <= 0.0

func _update_realtime_power() -> void:
	power_percent = float(power_slider.value)
	power = _power_from_percent(power_percent)
	player_angles[HUMAN_PLAYER_INDEX] = angle_deg
	player_power_percents[HUMAN_PLAYER_INDEX] = power_percent
	player_powers[HUMAN_PLAYER_INDEX] = power

func _update_realtime_cooldowns(delta: float) -> void:
	rt_player_fire_cooldown = maxf(0.0, rt_player_fire_cooldown - delta)
	rt_ai_fire_cooldown = maxf(0.0, rt_ai_fire_cooldown - delta)
	rt_ai_move_cooldown = maxf(0.0, rt_ai_move_cooldown - delta)

func _update_realtime_player_movement(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0

	if direction != 0.0 and rt_movement_energy > 0.0:
		var usable_delta: float = minf(delta, rt_movement_energy / RT_MOVEMENT_DRAIN_RATE)
		var new_x: float = clampf(tank_positions[HUMAN_PLAYER_INDEX].x + direction * TANK_MOVE_SPEED * usable_delta, 45.0, active_world_width - 45.0)
		if absf(new_x - tank_positions[AI_PLAYER_INDEX].x) >= 90.0:
			tank_positions[HUMAN_PLAYER_INDEX].x = new_x
			tank_positions[HUMAN_PLAYER_INDEX].y = _ground_y_at_x(new_x) - TANK_RADIUS
			rt_movement_energy = maxf(0.0, rt_movement_energy - RT_MOVEMENT_DRAIN_RATE * usable_delta)
	else:
		rt_movement_energy = minf(RT_MOVEMENT_ENERGY_MAX, rt_movement_energy + RT_MOVEMENT_RECHARGE_RATE * delta)

func _update_realtime_ai(delta: float) -> void:
	if game_over or overlay_open:
		return
	if rt_ai_move_cooldown <= 0.0:
		_choose_realtime_ai_move_target()
		rt_ai_move_cooldown = rng.randf_range(RT_AI_MOVE_COOLDOWN_MAX * 0.65, RT_AI_MOVE_COOLDOWN_MAX * 1.25)
	_move_realtime_ai(delta)
	if not projectile_active and rt_ai_fire_cooldown <= 0.0:
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

func _move_realtime_ai(delta: float) -> void:
	var dx: float = rt_ai_target_x - tank_positions[AI_PLAYER_INDEX].x
	if absf(dx) < 3.0:
		return
	var direction: float = signf(dx)
	var new_x: float = tank_positions[AI_PLAYER_INDEX].x + direction * RT_AI_MOVE_SPEED * delta
	if (direction > 0.0 and new_x > rt_ai_target_x) or (direction < 0.0 and new_x < rt_ai_target_x):
		new_x = rt_ai_target_x
	new_x = clampf(new_x, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
	if absf(new_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
		return
	tank_positions[AI_PLAYER_INDEX].x = new_x
	tank_positions[AI_PLAYER_INDEX].y = _ground_y_at_x(new_x) - TANK_RADIUS

func _prepare_realtime_ai_shot() -> void:
	var aim: Dictionary = _find_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX])
	var chosen_angle: float = float(aim.get("angle", 45.0)) + rng.randf_range(-RT_AI_AIM_ERROR_ANGLE, RT_AI_AIM_ERROR_ANGLE)
	var chosen_power_percent: float = float(aim.get("power_percent", 55.0)) + rng.randf_range(-RT_AI_AIM_ERROR_POWER, RT_AI_AIM_ERROR_POWER)
	player_angles[AI_PLAYER_INDEX] = clampf(chosen_angle, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)
	player_power_percents[AI_PLAYER_INDEX] = clampf(chosen_power_percent, 0.0, 100.0)
	player_powers[AI_PLAYER_INDEX] = _power_from_percent(player_power_percents[AI_PLAYER_INDEX])

func _fire_realtime_projectile(owner: int) -> void:
	if projectile_active or game_over:
		return
	rt_projectile_owner = owner
	var facing: float = 1.0 if owner == HUMAN_PLAYER_INDEX else -1.0
	var shot_angle: float = player_angles[owner] if owner == AI_PLAYER_INDEX else angle_deg
	var shot_power_percent: float = player_power_percents[owner] if owner == AI_PLAYER_INDEX else power_percent
	var shot_power: float = _power_from_percent(shot_power_percent)
	var rad: float = deg_to_rad(shot_angle)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	projectile_pos = tank_positions[owner] + muzzle_offset
	projectile_vel = Vector2(facing * shot_power * cos(rad), -shot_power * sin(rad))
	projectile_active = true

func _update_realtime_projectile(delta: float) -> void:
	projectile_vel.y += gravity * delta
	projectile_vel.x += wind * delta
	projectile_pos += projectile_vel * delta
	var target: int = AI_PLAYER_INDEX if rt_projectile_owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	if projectile_pos.distance_to(tank_positions[target]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		_explode_realtime(projectile_pos)
		return
	var ground_y: float = _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		_explode_realtime(Vector2(projectile_pos.x, ground_y))
		return
	if projectile_pos.x < -100.0 or projectile_pos.x > active_world_width + 100.0 or projectile_pos.y > _bottom_floor_y() + 180.0:
		_explode_realtime(projectile_pos)

func _explode_realtime(pos: Vector2) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = EXPLOSION_DURATION
	_apply_crater(pos)
	_apply_explosion_damage(pos)
	_settle_tanks_on_terrain()
	if tank_health[HUMAN_PLAYER_INDEX] <= 0 or tank_health[AI_PLAYER_INDEX] <= 0:
		game_over = true
		_show_end_popup()

func _camera_target_x() -> float:
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		var focus_x: float = tank_positions[HUMAN_PLAYER_INDEX].x
		if projectile_active and rt_projectile_owner == HUMAN_PLAYER_INDEX:
			focus_x = projectile_pos.x
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(focus_x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	return super._camera_target_x()

func _draw() -> void:
	super._draw()
	if menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and not game_over:
		_draw_realtime_cooldown_widgets()

func _draw_realtime_cooldown_widgets() -> void:
	var base: Vector2 = Vector2(18.0, VIEW_SIZE.y - 84.0)
	var fire_ready: float = 1.0 - clampf(rt_player_fire_cooldown / RT_PLAYER_FIRE_COOLDOWN_MAX, 0.0, 1.0)
	var move_ready: float = clampf(rt_movement_energy / RT_MOVEMENT_ENERGY_MAX, 0.0, 1.0)
	_draw_meter(base, "FIRE", fire_ready)
	_draw_meter(base + Vector2(0.0, 34.0), "MOVE", move_ready)

func _draw_meter(pos: Vector2, label: String, value: float) -> void:
	var box: Rect2 = Rect2(pos, Vector2(170.0, 24.0))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.62), true)
	draw_rect(box, Color(0.85, 0.90, 1.0, 0.30), false, 1.0)
	draw_rect(Rect2(pos + Vector2(58.0, 7.0), Vector2(100.0 * value, 10.0)), Color(0.65, 0.95, 0.45, 0.88), true)
	draw_string(ThemeDB.fallback_font, pos + Vector2(8.0, 17.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

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
