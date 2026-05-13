extends "res://scripts/MainHybridModes15.gd"

const MUZZLE_RECOIL_TIME: float = 0.18
const MUZZLE_RECOIL_DISTANCE: float = 13.0
const MUZZLE_SMOKE_LIFETIME: float = 0.55
const MUZZLE_SMOKE_RISE_SPEED: float = 26.0
const MUZZLE_SMOKE_DRIFT_SPEED: float = 18.0
const MUZZLE_SMOKE_START_RADIUS: float = 3.0
const MUZZLE_SMOKE_END_RADIUS: float = 10.0

var barrel_recoil_timers: Array[float] = [0.0, 0.0]
var barrel_recoil_angles: Array[float] = [45.0, 45.0]
var muzzle_smoke_puffs: Array[Dictionary] = []

func _add_main_menu_controls() -> void:
	# MainHybridModes15 added a second Main Menu button after relabeling Quit.
	# Keep only the original menu button relabeled from Quit -> Main Menu.
	return

func _ready() -> void:
	super._ready()
	_relabel_quit_buttons()

func reset_match() -> void:
	barrel_recoil_timers = [0.0, 0.0]
	barrel_recoil_angles = [45.0, 45.0]
	muzzle_smoke_puffs.clear()
	super.reset_match()

func _process(delta: float) -> void:
	super._process(delta)
	_update_muzzle_effects(delta)

func _update_muzzle_effects(delta: float) -> void:
	for i: int in range(barrel_recoil_timers.size()):
		barrel_recoil_timers[i] = maxf(0.0, barrel_recoil_timers[i] - delta)

	if muzzle_smoke_puffs.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for puff: Dictionary in muzzle_smoke_puffs:
		var age: float = float(puff.get("age", 0.0)) + delta
		var life: float = float(puff.get("life", MUZZLE_SMOKE_LIFETIME))
		if age < life:
			var pos: Vector2 = puff.get("pos", Vector2.ZERO)
			var drift: float = float(puff.get("drift", 0.0))
			pos.x += drift * delta
			pos.y -= MUZZLE_SMOKE_RISE_SPEED * delta
			puff["age"] = age
			puff["pos"] = pos
			remaining.append(puff)
	muzzle_smoke_puffs = remaining
	queue_redraw()

func _trigger_fire_fx(owner: int, shot_angle: float) -> void:
	if owner < 0 or owner >= 2:
		return
	barrel_recoil_timers[owner] = MUZZLE_RECOIL_TIME
	barrel_recoil_angles[owner] = shot_angle
	var facing: float = 1.0 if owner == 0 else -1.0
	var rad: float = deg_to_rad(shot_angle)
	var tip: Vector2 = tank_positions[owner] + Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	for i: int in range(4):
		muzzle_smoke_puffs.append({
			"pos": tip + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0)),
			"age": rng.randf_range(0.0, 0.08),
			"life": MUZZLE_SMOKE_LIFETIME,
			"drift": rng.randf_range(-MUZZLE_SMOKE_DRIFT_SPEED, MUZZLE_SMOKE_DRIFT_SPEED)
		})

func _on_fire_pressed() -> void:
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		super._on_fire_pressed()
		return
	if projectile_active or not turn_projectiles.is_empty() or game_over or overlay_open:
		return
	power_slider.release_focus()
	player_angles[current_player] = angle_deg
	player_powers[current_player] = power
	turn_projectile_weapon = selected_weapon
	turn_projectile_split_done = false
	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	projectile_pos = tank_positions[current_player] + muzzle_offset
	projectile_vel = Vector2(facing * power * cos(rad), -power * sin(rad))
	projectile_active = true
	_trigger_fire_fx(current_player, angle_deg)

func _fire_realtime_projectile(owner: int) -> void:
	if game_over:
		return
	if rt_projectiles.size() >= RT_MAX_ACTIVE_PROJECTILES:
		rt_projectiles.pop_front()
	var weapon: String = selected_weapon if owner == HUMAN_PLAYER_INDEX else WEAPON_STANDARD
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
		"weapon": weapon,
		"split": false,
		"pos": start_pos,
		"vel": start_vel
	})
	projectile_active = false
	_trigger_fire_fx(owner, shot_angle)

func _draw() -> void:
	super._draw()
	_draw_recoil_barrels()
	_draw_muzzle_smoke_puffs()

func _draw_recoil_barrels() -> void:
	for owner: int in range(2):
		if barrel_recoil_timers[owner] <= 0.0:
			continue
		var t: float = clampf(barrel_recoil_timers[owner] / MUZZLE_RECOIL_TIME, 0.0, 1.0)
		var recoil: float = MUZZLE_RECOIL_DISTANCE * t
		var facing: float = 1.0 if owner == 0 else -1.0
		var rad: float = deg_to_rad(barrel_recoil_angles[owner])
		var base: Vector2 = _world_to_screen(tank_positions[owner])
		var full_tip: Vector2 = base + Vector2(facing * CANNON_LENGTH * CAMERA_SCALE * cos(rad), -CANNON_LENGTH * CAMERA_SCALE * sin(rad))
		var recoil_tip: Vector2 = base + Vector2(facing * maxf(10.0, CANNON_LENGTH - recoil) * CAMERA_SCALE * cos(rad), -maxf(10.0, CANNON_LENGTH - recoil) * CAMERA_SCALE * sin(rad))
		# Cover the old full-length white barrel with a dark barrel shadow, then draw the recoiled white barrel.
		draw_line(base, full_tip, Color(0.08, 0.09, 0.10, 0.96), 6.0)
		draw_line(base, recoil_tip, Color.WHITE, 4.0)

func _draw_muzzle_smoke_puffs() -> void:
	for puff: Dictionary in muzzle_smoke_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", MUZZLE_SMOKE_LIFETIME))
		var t: float = clampf(age / life, 0.0, 1.0)
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = lerpf(MUZZLE_SMOKE_START_RADIUS, MUZZLE_SMOKE_END_RADIUS, t) * CAMERA_SCALE
		var alpha: float = 0.46 * (1.0 - t)
		draw_circle(_world_to_screen(pos), radius, Color(0.82, 0.84, 0.80, alpha))
