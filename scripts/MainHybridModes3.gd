extends "res://scripts/MainHybridModes2.gd"

const RT_MOVEMENT_RECOVER_FRACTION: float = 0.25
const STEAM_PUFF_INTERVAL: float = 0.22
const STEAM_PUFF_LIFETIME: float = 0.95
const STEAM_PUFF_RISE_SPEED: float = 34.0
const STEAM_PUFF_DRIFT_SPEED: float = 18.0
const STEAM_PUFF_START_RADIUS: float = 4.0
const STEAM_PUFF_END_RADIUS: float = 13.0

var steam_puffs: Array[Dictionary] = []
var steam_spawn_timer: float = 0.0
var movement_was_overheated: bool = false

func _setup_realtime_single_player() -> void:
	super._setup_realtime_single_player()
	steam_puffs.clear()
	steam_spawn_timer = 0.0
	movement_was_overheated = false

func reset_match() -> void:
	super.reset_match()
	steam_puffs.clear()
	steam_spawn_timer = 0.0
	movement_was_overheated = false

func _update_realtime_cooldowns(delta: float) -> void:
	rt_player_fire_cooldown = maxf(0.0, rt_player_fire_cooldown - delta)
	rt_ai_fire_cooldown = maxf(0.0, rt_ai_fire_cooldown - delta)
	rt_ai_move_cooldown = maxf(0.0, rt_ai_move_cooldown - delta)
	if rt_movement_exhaust_cooldown > 0.0:
		rt_movement_exhaust_cooldown = maxf(0.0, rt_movement_exhaust_cooldown - delta)
		movement_was_overheated = true
		if rt_movement_exhaust_cooldown <= 0.0:
			rt_movement_energy = maxf(rt_movement_energy, RT_MOVEMENT_ENERGY_MAX * RT_MOVEMENT_RECOVER_FRACTION)
	else:
		movement_was_overheated = false

func _process_realtime_single_player(delta: float) -> void:
	super._process_realtime_single_player(delta)
	_update_steam_puffs(delta)

func _update_realtime_player_movement(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or mobile_left_pressed:
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or mobile_right_pressed:
		direction += 1.0

	if rt_movement_exhaust_cooldown > 0.0:
		_spawn_overheat_steam(delta)
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
				movement_was_overheated = true
				_spawn_steam_puff()
	elif direction == 0.0:
		rt_movement_energy = minf(RT_MOVEMENT_ENERGY_MAX, rt_movement_energy + RT_MOVEMENT_RECHARGE_RATE * delta)

func _spawn_overheat_steam(delta: float) -> void:
	steam_spawn_timer -= delta
	if steam_spawn_timer <= 0.0:
		_spawn_steam_puff()
		steam_spawn_timer = STEAM_PUFF_INTERVAL

func _spawn_steam_puff() -> void:
	var base_pos: Vector2 = tank_positions[HUMAN_PLAYER_INDEX]
	var offset: Vector2 = Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-33.0, -22.0))
	steam_puffs.append({
		"pos": base_pos + offset,
		"age": 0.0,
		"life": STEAM_PUFF_LIFETIME,
		"drift": rng.randf_range(-STEAM_PUFF_DRIFT_SPEED, STEAM_PUFF_DRIFT_SPEED)
	})

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

func _draw() -> void:
	super._draw()
	if menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		_draw_steam_puffs()

func _draw_steam_puffs() -> void:
	for puff: Dictionary in steam_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", STEAM_PUFF_LIFETIME))
		var t: float = clampf(age / life, 0.0, 1.0)
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = lerpf(STEAM_PUFF_START_RADIUS, STEAM_PUFF_END_RADIUS, t) * CAMERA_SCALE
		var alpha: float = 0.52 * (1.0 - t)
		draw_circle(_world_to_screen(pos), radius, Color(0.88, 0.90, 0.86, alpha))

func _draw_realtime_cooldown_widgets() -> void:
	# Move meters to the upper-left of the play area so they do not sit under
	# the bottom-left mobile movement buttons.
	var base: Vector2 = Vector2(18.0, 184.0)
	var fire_ready: float = 1.0 - clampf(rt_player_fire_cooldown / RT_PLAYER_FIRE_COOLDOWN_MAX, 0.0, 1.0)
	var move_ready: float = clampf(rt_movement_energy / RT_MOVEMENT_ENERGY_MAX, 0.0, 1.0)
	if rt_movement_exhaust_cooldown > 0.0:
		move_ready = 0.0
	_draw_meter(base, "FIRE", fire_ready)
	_draw_meter(base + Vector2(0.0, 34.0), "MOVE", move_ready)
	if rt_movement_exhaust_cooldown > 0.0:
		draw_string(ThemeDB.fallback_font, base + Vector2(176.0, 51.0), "%.1fs" % rt_movement_exhaust_cooldown, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
