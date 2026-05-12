extends "res://scripts/MainHybridModes.gd"

const RT_MOVEMENT_EXHAUST_COOLDOWN_MAX: float = 3.0
const RT_MAX_ACTIVE_PROJECTILES: int = 6

var rt_projectiles: Array[Dictionary] = []
var rt_movement_exhaust_cooldown: float = 0.0

func _setup_realtime_single_player() -> void:
	super._setup_realtime_single_player()
	rt_projectiles.clear()
	rt_movement_exhaust_cooldown = 0.0
	projectile_active = false

func reset_match() -> void:
	super.reset_match()
	rt_projectiles.clear()
	rt_movement_exhaust_cooldown = 0.0

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

	_update_all_realtime_projectiles(delta)

	if explosion_timer > 0.0:
		explosion_timer -= delta
		if explosion_timer <= 0.0:
			explosion_pos = Vector2.INF

	_update_camera(delta)
	_update_ui()
	queue_redraw()

func _player_can_fire() -> bool:
	return rt_player_fire_cooldown <= 0.0 and not game_over

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

func _update_realtime_cooldowns(delta: float) -> void:
	rt_player_fire_cooldown = maxf(0.0, rt_player_fire_cooldown - delta)
	rt_ai_fire_cooldown = maxf(0.0, rt_ai_fire_cooldown - delta)
	rt_ai_move_cooldown = maxf(0.0, rt_ai_move_cooldown - delta)
	if rt_movement_exhaust_cooldown > 0.0:
		rt_movement_exhaust_cooldown = maxf(0.0, rt_movement_exhaust_cooldown - delta)

func _update_realtime_player_movement(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0

	if rt_movement_exhaust_cooldown > 0.0:
		return

	if direction != 0.0 and rt_movement_energy > 0.0:
		var usable_delta: float = minf(delta, rt_movement_energy / RT_MOVEMENT_DRAIN_RATE)
		var new_x: float = clampf(tank_positions[HUMAN_PLAYER_INDEX].x + direction * TANK_MOVE_SPEED * usable_delta, 45.0, active_world_width - 45.0)
		if absf(new_x - tank_positions[AI_PLAYER_INDEX].x) >= 90.0:
			tank_positions[HUMAN_PLAYER_INDEX].x = new_x
			tank_positions[HUMAN_PLAYER_INDEX].y = _ground_y_at_x(new_x) - TANK_RADIUS
			rt_movement_energy = maxf(0.0, rt_movement_energy - RT_MOVEMENT_DRAIN_RATE * usable_delta)
			if rt_movement_energy <= 0.001:
				rt_movement_energy = 0.0
				rt_movement_exhaust_cooldown = RT_MOVEMENT_EXHAUST_COOLDOWN_MAX
	elif direction == 0.0:
		rt_movement_energy = minf(RT_MOVEMENT_ENERGY_MAX, rt_movement_energy + RT_MOVEMENT_RECHARGE_RATE * delta)

func _fire_realtime_projectile(owner: int) -> void:
	if game_over:
		return
	if rt_projectiles.size() >= RT_MAX_ACTIVE_PROJECTILES:
		rt_projectiles.pop_front()
	var facing: float = 1.0 if owner == HUMAN_PLAYER_INDEX else -1.0
	var shot_angle: float = player_angles[owner] if owner == AI_PLAYER_INDEX else angle_deg
	var shot_power_percent: float = player_power_percents[owner] if owner == AI_PLAYER_INDEX else power_percent
	var shot_power: float = _power_from_percent(shot_power_percent)
	var rad: float = deg_to_rad(shot_angle)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var start_pos: Vector2 = tank_positions[owner] + muzzle_offset
	var start_vel: Vector2 = Vector2(facing * shot_power * cos(rad), -shot_power * sin(rad))
	rt_projectiles.append({
		"owner": owner,
		"pos": start_pos,
		"vel": start_vel
	})
	# Keep the legacy single-projectile variables inert for realtime mode.
	projectile_active = false

func _update_all_realtime_projectiles(delta: float) -> void:
	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for projectile: Dictionary in rt_projectiles:
		var owner: int = int(projectile.get("owner", HUMAN_PLAYER_INDEX))
		var pos: Vector2 = projectile.get("pos", Vector2.ZERO)
		var vel: Vector2 = projectile.get("vel", Vector2.ZERO)
		vel.y += gravity * delta
		vel.x += wind * delta
		pos += vel * delta
		if _realtime_projectile_should_explode(owner, pos):
			_explode_realtime(pos)
		else:
			projectile["pos"] = pos
			projectile["vel"] = vel
			remaining.append(projectile)
	rt_projectiles = remaining

func _realtime_projectile_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	if pos.distance_to(tank_positions[target]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	if pos.x < -100.0 or pos.x > active_world_width + 100.0 or pos.y > _bottom_floor_y() + 180.0:
		return true
	return false

func _explode_realtime(pos: Vector2) -> void:
	# Do not flip projectile_active here. Realtime projectiles are tracked by
	# rt_projectiles, and multiple shells may be in flight at the same time.
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
		var newest_human_projectile: Vector2 = Vector2.INF
		for projectile: Dictionary in rt_projectiles:
			if int(projectile.get("owner", -1)) == HUMAN_PLAYER_INDEX:
				newest_human_projectile = projectile.get("pos", Vector2.INF)
		if newest_human_projectile != Vector2.INF:
			focus_x = newest_human_projectile.x
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(focus_x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	return super._camera_target_x()

func _draw() -> void:
	if menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		super._draw()
		_draw_realtime_projectiles()
		return
	super._draw()

func _draw_realtime_projectiles() -> void:
	for projectile: Dictionary in rt_projectiles:
		var owner: int = int(projectile.get("owner", HUMAN_PLAYER_INDEX))
		var pos: Vector2 = projectile.get("pos", Vector2.ZERO)
		var color: Color = Color(1.0, 0.92, 0.2) if owner == HUMAN_PLAYER_INDEX else Color(1.0, 0.38, 0.25)
		draw_circle(_world_to_screen(pos), PROJECTILE_RADIUS * CAMERA_SCALE, color)

func _draw_realtime_cooldown_widgets() -> void:
	var base: Vector2 = Vector2(18.0, VIEW_SIZE.y - 84.0)
	var fire_ready: float = 1.0 - clampf(rt_player_fire_cooldown / RT_PLAYER_FIRE_COOLDOWN_MAX, 0.0, 1.0)
	var move_ready: float = clampf(rt_movement_energy / RT_MOVEMENT_ENERGY_MAX, 0.0, 1.0)
	if rt_movement_exhaust_cooldown > 0.0:
		move_ready = 0.0
	_draw_meter(base, "FIRE", fire_ready)
	_draw_meter(base + Vector2(0.0, 34.0), "MOVE", move_ready)
	if rt_movement_exhaust_cooldown > 0.0:
		draw_string(ThemeDB.fallback_font, base + Vector2(176.0, 51.0), "%.1fs" % rt_movement_exhaust_cooldown, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw_meter(pos: Vector2, label: String, value: float) -> void:
	var box: Rect2 = Rect2(pos, Vector2(170.0, 24.0))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.62), true)
	draw_rect(box, Color(0.85, 0.90, 1.0, 0.30), false, 1.0)
	var bar_color: Color = _cooldown_color(value)
	draw_rect(Rect2(pos + Vector2(58.0, 7.0), Vector2(100.0 * clampf(value, 0.0, 1.0), 10.0)), bar_color, true)
	draw_string(ThemeDB.fallback_font, pos + Vector2(8.0, 17.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _cooldown_color(value: float) -> Color:
	var v: float = clampf(value, 0.0, 1.0)
	if v < 0.5:
		return Color(1.0, lerpf(0.12, 0.82, v / 0.5), 0.08, 0.90)
	return Color(lerpf(1.0, 0.35, (v - 0.5) / 0.5), 0.95, 0.16, 0.90)
