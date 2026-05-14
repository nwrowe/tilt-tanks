extends "res://scripts/MainHybridModes19.gd"

# CLEAN ACTIVE ENTRY POINT
# ------------------------
# This script intentionally extends the last known-good prototype build while
# we migrate systems into organized modules. The scene should point here from
# now on, instead of directly to MainHybridModesXX.gd.
#
# Refactor plan:
# - Keep behavior stable through this file.
# - Move weapon constants/lookup into scripts/weapons/WeaponCatalog.gd.
# - Move mode constants into scripts/modes/GameMode.gd.
# - Gradually extract terrain, projectiles, UI, effects, and game modes.
# - Once parity is confirmed, archive/delete the old MainHybridModesXX chain.

const ACTIVE_BUILD_NAME: String = "MainGame refactor facade"

var hotseat_release_in_progress: bool = false

func _ready() -> void:
	super._ready()
	print("Tilt Tanks active script: %s" % ACTIVE_BUILD_NAME)

# Mode facade
# -----------
# Low-risk hotseat/realtime decisions are routed through scripts/modes/*.gd
# while the full mode runtime loops are gradually extracted.

func _is_hotseat_game_active() -> bool:
	return HotseatMode.is_active(menu_state, game_mode, MENU_STATE_GAME, GAME_MODE_SINGLE_PLAYER_REALTIME)

func _hotseat_can_begin_charge() -> bool:
	return HotseatMode.can_begin_charge(projectile_active, turn_projectiles, game_over, overlay_open)

func _draw_turn_widget() -> void:
	if game_over:
		return
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME:
		return

	var box: Rect2 = Rect2(Vector2(VIEW_SIZE.x - 232.0, 64.0), Vector2(156.0, 44.0))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.64), true)
	draw_rect(box, Color(1.0, 1.0, 1.0, 0.22), false, 1.0)

	var text: String = HotseatMode.turn_label(current_player, turn_timer)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(16.0, 29.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _update_hotseat_charge(delta: float) -> void:
	if not _is_hotseat_game_active():
		return

	var keyboard_down: bool = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)

	if keyboard_down and not hotseat_keyboard_fire_held and _hotseat_can_begin_charge():
		hotseat_keyboard_fire_held = true
		hotseat_charge_time = 0.0
		hotseat_charge_percent = HOTSEAT_CHARGE_MIN_PERCENT

	if hotseat_fire_button_held or hotseat_keyboard_fire_held:
		hotseat_charge_time = minf(HOTSEAT_CHARGE_TIME_MAX, hotseat_charge_time + delta)

		var charge_ratio: float = clampf(hotseat_charge_time / HOTSEAT_CHARGE_TIME_MAX, 0.0, 1.0)
		hotseat_charge_percent = HotseatMode.charge_percent(
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

	if not keyboard_down and hotseat_keyboard_fire_held:
		hotseat_keyboard_fire_held = false
		_release_hotseat_charged_shot()

func _draw_trajectory_preview() -> void:
	if projectile_active or not turn_projectiles.is_empty() or game_over:
		return

	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var pos: Vector2 = tank_positions[current_player] + muzzle_offset

	var preview_power: float = power
	if _is_hotseat_game_active() and (hotseat_fire_button_held or hotseat_keyboard_fire_held):
		preview_power = _power_from_percent(clampf(hotseat_charge_percent, HOTSEAT_CHARGE_MIN_PERCENT, HOTSEAT_CHARGE_MAX_PERCENT))

	var vel: Vector2 = Vector2(facing * preview_power * cos(rad), -preview_power * sin(rad))

	for i: int in range(1, TRAJECTORY_DOT_COUNT + 1):
		vel.y += gravity * TRAJECTORY_DOT_DT
		vel.x += wind * TRAJECTORY_DOT_DT
		pos += vel * TRAJECTORY_DOT_DT

		if pos.x < 0.0 or pos.x > active_world_width or pos.y >= _ground_y_at_x(pos.x):
			break

		var alpha: float = 0.55 * (1.0 - float(i - 1) / float(TRAJECTORY_DOT_COUNT))
		draw_circle(_world_to_screen(pos), TRAJECTORY_DOT_RADIUS, Color(1.0, 1.0, 1.0, alpha))

func _player_can_fire() -> bool:
	return RealtimeSinglePlayerMode.player_can_fire(rt_player_shell_active, game_over)

func _on_fire_pressed() -> void:
	# In hotseat mode, keyboard/mobile charging should be the only path that
	# launches a shot. Spacebar can otherwise trigger a focused Button's pressed
	# signal immediately, causing a minimum-power shot.
	if _is_hotseat_game_active() and not hotseat_release_in_progress:
		return

	super._on_fire_pressed()

func _update_realtime_fire_charge(delta: float) -> void:
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME or menu_state != MENU_STATE_GAME:
		return

	var keyboard_down: bool = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)

	if keyboard_down and not rt_keyboard_fire_held and _player_can_fire() and not overlay_open:
		rt_keyboard_fire_held = true
		rt_fire_charge_time = 0.0
		rt_fire_charge_percent = RT_CHARGE_MIN_PERCENT
	elif not keyboard_down and rt_keyboard_fire_held:
		rt_keyboard_fire_held = false
		_release_realtime_charged_shot()

	if rt_fire_button_held or rt_keyboard_fire_held:
		rt_fire_charge_time = minf(RT_CHARGE_TIME_MAX, rt_fire_charge_time + delta)

		var charge_ratio: float = clampf(rt_fire_charge_time / RT_CHARGE_TIME_MAX, 0.0, 1.0)
		rt_fire_charge_percent = RealtimeSinglePlayerMode.charge_percent(
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

func _release_hotseat_charged_shot() -> void:
	if not _hotseat_can_begin_charge():
		_reset_hotseat_charge()
		return

	power_percent = clampf(hotseat_charge_percent, HOTSEAT_CHARGE_MIN_PERCENT, HOTSEAT_CHARGE_MAX_PERCENT)
	power = _power_from_percent(power_percent)

	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power

	hotseat_release_in_progress = true
	_on_fire_pressed()
	hotseat_release_in_progress = false

	_reset_hotseat_charge()

func _release_realtime_charged_shot() -> void:
	if not _player_can_fire() or game_over or overlay_open:
		_reset_realtime_charge_state()
		return

	power_percent = clampf(rt_fire_charge_percent, RT_CHARGE_MIN_PERCENT, RT_CHARGE_MAX_PERCENT)
	power = _power_from_percent(power_percent)

	player_angles[HUMAN_PLAYER_INDEX] = angle_deg
	player_power_percents[HUMAN_PLAYER_INDEX] = power_percent
	player_powers[HUMAN_PLAYER_INDEX] = power

	_fire_realtime_projectile(HUMAN_PLAYER_INDEX)
	rt_player_shell_active = true
	_reset_realtime_charge_state()

func _update_ui() -> void:
	super._update_ui()

	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME and not game_over:
		power_label.text = RealtimeSinglePlayerMode.shell_status_label(
			rt_player_shell_active,
			rt_fire_button_held or rt_keyboard_fire_held,
			rt_fire_charge_percent,
			0.0
		)

# Effects facade
# --------------
# Effect math lives in EffectsManager; MainGame still owns when effects spawn
# until the remaining legacy chain is collapsed.

func _update_muzzle_effects(delta: float) -> void:
	for i: int in range(barrel_recoil_timers.size()):
		barrel_recoil_timers[i] = maxf(0.0, barrel_recoil_timers[i] - delta)
	muzzle_smoke_puffs = EffectsManager.update_rising_puffs(muzzle_smoke_puffs, delta, MUZZLE_SMOKE_RISE_SPEED)
	if not muzzle_smoke_puffs.is_empty():
		queue_redraw()

func _spawn_destroyed_smoke_puff() -> void:
	if destroyed_tank_index < 0 or destroyed_tank_index >= tank_positions.size():
		return
	var base_pos: Vector2 = tank_positions[destroyed_tank_index]
	var offset: Vector2 = Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-36.0, -18.0))
	destroyed_smoke_puffs.append(EffectsManager.make_puff(
		base_pos + offset,
		DESTROYED_SMOKE_LIFETIME,
		rng.randf_range(-DESTROYED_SMOKE_DRIFT_SPEED, DESTROYED_SMOKE_DRIFT_SPEED)
	))

func _spawn_steam_puff() -> void:
	var base_pos: Vector2 = tank_positions[HUMAN_PLAYER_INDEX]
	var offset: Vector2 = Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-33.0, -22.0))
	steam_puffs.append(EffectsManager.make_puff(
		base_pos + offset,
		STEAM_PUFF_LIFETIME,
		rng.randf_range(-STEAM_PUFF_DRIFT_SPEED, STEAM_PUFF_DRIFT_SPEED)
	))

func _draw_muzzle_smoke_puffs() -> void:
	for puff: Dictionary in muzzle_smoke_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", MUZZLE_SMOKE_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, MUZZLE_SMOKE_START_RADIUS, MUZZLE_SMOKE_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.46)
		draw_circle(_world_to_screen(pos), radius, Color(0.82, 0.84, 0.80, alpha))

func _draw_destroyed_smoke_puffs() -> void:
	for puff: Dictionary in destroyed_smoke_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", DESTROYED_SMOKE_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, DESTROYED_SMOKE_START_RADIUS, DESTROYED_SMOKE_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.58)
		draw_circle(_world_to_screen(pos), radius, Color(0.78, 0.80, 0.77, alpha))

func _draw_steam_puffs() -> void:
	for puff: Dictionary in steam_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", STEAM_PUFF_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, STEAM_PUFF_START_RADIUS, STEAM_PUFF_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.52)
		draw_circle(_world_to_screen(pos), radius, Color(0.88, 0.90, 0.86, alpha))

# Weapon lookup facade
# --------------------
# The prototype chain still owns most projectile behavior, but active weapon
# numbers now come from WeaponCatalog. This is a safe extraction because the
# inherited methods below are the same lookup points the prototype already uses.

func _weapon_explosion_radius(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "explosion_radius", EXPLOSION_RADIUS))

func _weapon_direct_radius(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "direct_radius", DIRECT_HIT_RADIUS))

func _weapon_direct_damage(weapon: String) -> int:
	return int(WeaponCatalog.value(weapon, "direct_damage", DIRECT_HIT_DAMAGE))

func _weapon_splash_damage(weapon: String) -> int:
	return int(WeaponCatalog.value(weapon, "splash_damage", MAX_SPLASH_DAMAGE))

func _weapon_crater_radius(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "crater_radius", CRATER_RADIUS))

func _weapon_crater_depth(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "crater_depth", CRATER_DEPTH))

func _weapon_projectile_scale(weapon: String) -> float:
	return float(WeaponCatalog.value(weapon, "projectile_scale", 1.0))

# Projectile extraction facade
# ----------------------------
# Keep game behavior in this active entry point while routing common projectile
# data creation, stepping, and owner checks through helper modules. This is the
# bridge toward moving all projectile behavior into ProjectileManager.gd.

func _split_turn_cluster_projectile(pos: Vector2, vel: Vector2) -> void:
	projectile_active = false
	turn_projectile_split_done = true
	turn_projectiles.clear()
	turn_projectiles = ProjectileFactory.make_cluster_children(
		current_player,
		pos,
		vel,
		CLUSTER_SPLIT_SPREAD_X,
		CLUSTER_SPLIT_SPEED_Y,
		WEAPON_CLUSTER_CHILD
	)
	turn_cluster_camera_pos = pos

func _spawn_realtime_cluster_children(owner: int, pos: Vector2, vel: Vector2) -> void:
	var children: Array[Dictionary] = ProjectileFactory.make_cluster_children(
		owner,
		pos,
		vel,
		CLUSTER_SPLIT_SPREAD_X,
		CLUSTER_SPLIT_SPEED_Y,
		WEAPON_CLUSTER_CHILD
	)
	for child: Dictionary in children:
		rt_projectiles.append(child)

func _has_active_realtime_shell_for_owner(owner: int) -> bool:
	return ProjectileManager.has_shell_for_owner(rt_projectiles, owner)

func _update_projectile(delta: float) -> void:
	var stepped: Dictionary = ProjectileManager.step_legacy_projectile(projectile_pos, projectile_vel, gravity, wind, delta)
	projectile_pos = stepped.get("pos", projectile_pos)
	projectile_vel = stepped.get("vel", projectile_vel)
	if turn_projectile_weapon == WEAPON_CLUSTER and not turn_projectile_split_done and projectile_vel.y >= 0.0:
		_split_turn_cluster_projectile(projectile_pos, projectile_vel)
		return
	var enemy: int = 1 - current_player
	if ProjectileManager.projectile_hits_tank(projectile_pos, tank_positions[enemy], TANK_RADIUS, PROJECTILE_RADIUS):
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)
		return
	if _is_in_pond(projectile_pos):
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)
		return
	var ground_y: float = _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		_explode_turn_weapon(Vector2(projectile_pos.x, ground_y), turn_projectile_weapon, true)
		return
	if ProjectileManager.is_out_of_world(projectile_pos, active_world_width, _bottom_floor_y()):
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)

func _turn_shell_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = 1 - owner
	if ProjectileManager.projectile_hits_tank(pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS):
		return true
	if _is_in_pond(pos):
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	if ProjectileManager.is_out_of_world(pos, active_world_width, _bottom_floor_y()):
		return true
	return false

func _realtime_projectile_should_explode(owner: int, pos: Vector2) -> bool:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	if ProjectileManager.projectile_hits_tank(pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS):
		return true
	if _is_in_pond(pos):
		return true
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		return true
	if ProjectileManager.is_out_of_world(pos, active_world_width, _bottom_floor_y()):
		return true
	return false

func _update_turn_weapon_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	turn_cluster_camera_pos = Vector2.INF
	var last_center_pos: Vector2 = Vector2.INF
	var any_center_shell_alive: bool = false

	for shell: Dictionary in turn_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var owner: int = int(stepped.get("owner", current_player))
		var weapon: String = str(stepped.get("weapon", WEAPON_CLUSTER_CHILD))
		var is_center: bool = bool(stepped.get("center_child", false))

		if is_center:
			last_center_pos = pos
			turn_cluster_camera_pos = pos

		if _turn_shell_should_explode(owner, pos):
			_explode_turn_weapon(pos, weapon, false)
			if is_center:
				cluster_camera_hold_pos = pos
				cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		else:
			remaining.append(stepped)
			if is_center:
				any_center_shell_alive = true

	turn_projectiles = remaining
	if any_center_shell_alive:
		cluster_camera_hold_pos = last_center_pos
	elif not turn_projectiles.is_empty() and cluster_camera_hold_pos == Vector2.INF:
		var avg: Vector2 = ProjectileManager.average_shell_position(turn_projectiles)
		turn_cluster_camera_pos = avg
		cluster_camera_hold_pos = avg

	if turn_projectiles.is_empty():
		turn_cluster_camera_pos = Vector2.INF
		if cluster_camera_hold_pos == Vector2.INF:
			cluster_camera_hold_pos = last_center_pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		if not game_over:
			_advance_turn()

func _update_all_realtime_projectiles(delta: float) -> void:
	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var cluster_focus_sum: Vector2 = Vector2.ZERO
	var cluster_focus_n: int = 0
	var had_cluster_children: bool = false
	var last_cluster_explosion: Vector2 = Vector2.INF

	for shell: Dictionary in rt_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var owner: int = int(stepped.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(stepped.get("weapon", WEAPON_STANDARD))
		var split_done: bool = bool(stepped.get("split", false))
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var vel: Vector2 = stepped.get("vel", Vector2.ZERO)

		if weapon == WEAPON_CLUSTER and not split_done and vel.y >= 0.0:
			_spawn_realtime_cluster_children(owner, pos, vel)
			realtime_cluster_focus_pos = pos
			realtime_cluster_focus_count = 3
		elif _realtime_projectile_should_explode(owner, pos):
			if weapon == WEAPON_CLUSTER_CHILD:
				had_cluster_children = true
				last_cluster_explosion = pos
				realtime_cluster_focus_count = maxi(0, realtime_cluster_focus_count - 1)
			_explode_realtime_weapon(pos, weapon)
		else:
			remaining.append(stepped)
			if weapon == WEAPON_CLUSTER_CHILD:
				had_cluster_children = true
				cluster_focus_sum += pos
				cluster_focus_n += 1

	rt_projectiles = remaining
	rt_player_shell_active = ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX)

	if cluster_focus_n > 0:
		realtime_cluster_focus_pos = cluster_focus_sum / float(cluster_focus_n)
		cluster_camera_hold_pos = realtime_cluster_focus_pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
	elif had_cluster_children:
		if last_cluster_explosion != Vector2.INF:
			realtime_cluster_focus_pos = last_cluster_explosion
			cluster_camera_hold_pos = last_cluster_explosion
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		if realtime_cluster_focus_count <= 0:
			realtime_cluster_focus_pos = Vector2.INF
	elif rt_projectiles.is_empty() and explosion_pos != Vector2.INF:
		cluster_camera_hold_pos = explosion_pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
