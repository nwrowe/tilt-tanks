extends "res://scripts/core/MainGameLevelFacade.gd"

# Implements special weapon behaviors added after the data-driven weapon pass.
# Standard, Heavy, and Cluster continue through the existing runtime path.

const SPECIAL_LASER: String = WeaponRegistry.WEAPON_LASER
const SPECIAL_NUKE: String = WeaponRegistry.WEAPON_TACTICAL_NUKE
const SPECIAL_BOUNCER: String = WeaponRegistry.WEAPON_BOUNCER
const SPECIAL_GROUND_BOMB: String = WeaponRegistry.WEAPON_GROUND_BOMB
const SPECIAL_MACHINE_GUN: String = WeaponRegistry.WEAPON_MACHINE_GUN
const SPECIAL_MACHINE_GUN_ROUND: String = WeaponRegistry.WEAPON_MACHINE_GUN_ROUND

const NO_CAMERA_OWNER: int = -1

var machine_gun_active: bool = false
var machine_gun_owner: int = 0
var machine_gun_remaining: int = 0
var machine_gun_timer: float = 0.0
var machine_gun_interval: float = 0.1
var machine_gun_angle: float = 45.0
var machine_gun_power_percent: float = 50.0
var machine_gun_realtime: bool = false
var machine_gun_turn_waiting_for_shells: bool = false
var pending_advance_after_explosion_hold: bool = false
var quickgame_player_shot_hide_trajectory: bool = false
var realtime_explosion_camera_owner: int = NO_CAMERA_OWNER
var turn_bouncer_bounce_count: int = 0

func reset_match() -> void:
	_clear_machine_gun_burst()
	pending_advance_after_explosion_hold = false
	quickgame_player_shot_hide_trajectory = false
	realtime_explosion_camera_owner = NO_CAMERA_OWNER
	turn_bouncer_bounce_count = 0
	super.reset_match()

func _process(delta: float) -> void:
	_update_machine_gun_burst(delta)
	super._process(delta)
	_maybe_finish_machine_gun_turn()
	_maybe_advance_after_explosion_hold()
	_maybe_show_quickgame_trajectory_after_shot()

func _camera_target_x() -> float:
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and explosion_timer > 0.0 and realtime_explosion_camera_owner != HUMAN_PLAYER_INDEX:
		var saved_explosion_pos: Vector2 = explosion_pos
		var saved_explosion_timer: float = explosion_timer
		explosion_pos = Vector2.INF
		explosion_timer = 0.0
		var target_x: float = super._camera_target_x()
		explosion_pos = saved_explosion_pos
		explosion_timer = saved_explosion_timer
		return target_x
	return super._camera_target_x()

func _draw_trajectory_preview() -> void:
	# Hide immediately after a human shot in both hotseat and quick game. In quick
	# game, AI explosions alone should not hide the player's aiming preview.
	if pending_advance_after_explosion_hold or quickgame_player_shot_hide_trajectory:
		return
	super._draw_trajectory_preview()

func _hotseat_can_begin_charge() -> bool:
	if pending_advance_after_explosion_hold or machine_gun_active or machine_gun_turn_waiting_for_shells:
		return false
	return super._hotseat_can_begin_charge()

func _on_fire_pressed() -> void:
	# Preserve hotseat hold-to-charge behavior. The actual shot should begin only
	# when the charge is released and MainGame sets hotseat_release_in_progress.
	if _is_hotseat_game_active() and not hotseat_release_in_progress:
		return
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		super._on_fire_pressed()
		if ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX) or rt_player_shell_active:
			quickgame_player_shot_hide_trajectory = true
		return
	if projectile_active or not turn_projectiles.is_empty() or game_over or overlay_open or machine_gun_active or machine_gun_turn_waiting_for_shells or pending_advance_after_explosion_hold:
		return

	if selected_weapon == SPECIAL_LASER:
		_fire_laser(current_player, angle_deg, power_percent, false)
		if not game_over:
			pending_advance_after_explosion_hold = true
		return
	if selected_weapon == SPECIAL_MACHINE_GUN:
		_begin_machine_gun_burst(current_player, angle_deg, power_percent, false)
		return

	super._on_fire_pressed()
	if selected_weapon == SPECIAL_BOUNCER:
		turn_bouncer_bounce_count = 0

func _release_realtime_charged_shot() -> void:
	if selected_weapon == SPECIAL_LASER:
		if not _player_can_fire() or game_over or overlay_open:
			_reset_realtime_charge_state()
			return
		power_percent = clampf(rt_fire_charge_percent, RT_CHARGE_MIN_PERCENT, RT_CHARGE_MAX_PERCENT)
		power = _power_from_percent(power_percent)
		_fire_laser(HUMAN_PLAYER_INDEX, angle_deg, power_percent, true)
		rt_player_shell_active = false
		quickgame_player_shot_hide_trajectory = true
		_reset_realtime_charge_state()
		return
	if selected_weapon == SPECIAL_MACHINE_GUN:
		if not _player_can_fire() or game_over or overlay_open or machine_gun_active:
			_reset_realtime_charge_state()
			return
		power_percent = clampf(rt_fire_charge_percent, RT_CHARGE_MIN_PERCENT, RT_CHARGE_MAX_PERCENT)
		power = _power_from_percent(power_percent)
		_begin_machine_gun_burst(HUMAN_PLAYER_INDEX, angle_deg, power_percent, true)
		rt_player_shell_active = true
		quickgame_player_shot_hide_trajectory = true
		_reset_realtime_charge_state()
		return
	super._release_realtime_charged_shot()
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and (ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX) or rt_player_shell_active):
		quickgame_player_shot_hide_trajectory = true

func _update_projectile(delta: float) -> void:
	if turn_projectile_weapon == SPECIAL_BOUNCER:
		_update_bouncing_turn_projectile(delta)
		return
	super._update_projectile(delta)

func _update_turn_weapon_projectiles(delta: float) -> void:
	# Only take over the turn-projectile loop while machine-gun rounds are active.
	# Otherwise defer to the base implementation so Cluster/Burst camera behavior
	# remains unchanged.
	if not machine_gun_turn_waiting_for_shells and not _turn_projectiles_include_weapon(SPECIAL_MACHINE_GUN_ROUND):
		super._update_turn_weapon_projectiles(delta)
		return

	var remaining: Array[Dictionary] = []
	for shell: Dictionary in turn_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var owner: int = int(stepped.get("owner", current_player))
		var weapon: String = str(stepped.get("weapon", WEAPON_CLUSTER_CHILD))
		if _turn_shell_should_explode(owner, pos):
			_explode_turn_weapon(pos, weapon, false)
			if weapon == SPECIAL_MACHINE_GUN_ROUND:
				_start_global_explosion_camera_hold(pos)
		else:
			remaining.append(stepped)
	turn_projectiles = remaining
	_maybe_finish_machine_gun_turn()

func _update_all_realtime_projectiles(delta: float) -> void:
	# Let the older, working realtime Cluster/Burst camera path handle normal
	# projectiles. This override is only for special projectile behaviors.
	if not _realtime_special_projectiles_active():
		super._update_all_realtime_projectiles(delta)
		return

	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var human_shell_alive: bool = false
	for shell: Dictionary in rt_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var owner: int = int(stepped.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(stepped.get("weapon", WEAPON_STANDARD))
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var vel: Vector2 = stepped.get("vel", Vector2.ZERO)
		var split_done: bool = bool(stepped.get("split", false))

		if weapon == SPECIAL_BOUNCER:
			var bounce_result: Dictionary = _step_bouncer_shell(stepped, owner)
			if bool(bounce_result.get("explode", false)):
				_explode_realtime_weapon(pos, weapon, owner)
			else:
				remaining.append(bounce_result.get("shell", stepped))
				if owner == HUMAN_PLAYER_INDEX:
					human_shell_alive = true
		elif _weapon_has_split_behavior(weapon) and not split_done and vel.y >= 0.0:
			_spawn_realtime_cluster_children(owner, pos, vel)
			if owner == HUMAN_PLAYER_INDEX:
				realtime_cluster_focus_pos = pos
				realtime_cluster_focus_count = _weapon_child_count(weapon)
		elif _realtime_projectile_should_explode(owner, pos):
			_explode_realtime_weapon(pos, weapon, owner)
			if owner == HUMAN_PLAYER_INDEX and weapon == SPECIAL_MACHINE_GUN_ROUND:
				_start_global_explosion_camera_hold(pos)
		else:
			remaining.append(stepped)
			if owner == HUMAN_PLAYER_INDEX:
				human_shell_alive = true
	rt_projectiles = remaining
	rt_player_shell_active = human_shell_alive or machine_gun_active

func _fire_realtime_projectile(owner: int) -> void:
	if game_over:
		return
	var weapon: String = selected_weapon if owner == HUMAN_PLAYER_INDEX else WEAPON_STANDARD
	if weapon == SPECIAL_LASER:
		var shot_angle: float = player_angles[owner] if owner == AI_PLAYER_INDEX else angle_deg
		var shot_power_percent: float = player_power_percents[owner] if owner == AI_PLAYER_INDEX else power_percent
		_fire_laser(owner, shot_angle, shot_power_percent, true)
		return
	if weapon == SPECIAL_MACHINE_GUN:
		var mg_angle: float = player_angles[owner] if owner == AI_PLAYER_INDEX else angle_deg
		var mg_power_percent: float = player_power_percents[owner] if owner == AI_PLAYER_INDEX else power_percent
		_begin_machine_gun_burst(owner, mg_angle, mg_power_percent, true)
		return
	if rt_projectiles.size() >= RT_MAX_ACTIVE_PROJECTILES:
		rt_projectiles.pop_front()
	var facing: float = 1.0 if owner == HUMAN_PLAYER_INDEX else -1.0
	var shot_angle_default: float = player_angles[owner] if owner == AI_PLAYER_INDEX else angle_deg
	var shot_power_percent_default: float = player_power_percents[owner] if owner == AI_PLAYER_INDEX else power_percent
	var shot_power: float = _power_from_percent(shot_power_percent_default)
	var rad: float = deg_to_rad(shot_angle_default)
	var start_pos: Vector2 = tank_positions[owner] + Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var start_vel: Vector2 = Vector2(facing * shot_power * cos(rad), -shot_power * sin(rad))
	rt_projectiles.append(ProjectileFactory.make_shell(owner, weapon, start_pos, start_vel, false))
	projectile_active = false
	_trigger_fire_fx(owner, shot_angle_default)
	if owner == HUMAN_PLAYER_INDEX:
		quickgame_player_shot_hide_trajectory = true

func _explode_turn_weapon(pos: Vector2, weapon: String, advance_after: bool) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = _weapon_explosion_duration(weapon)
	last_explosion_visual_radius = _weapon_explosion_radius(weapon)
	_apply_weapon_crater(pos, weapon)
	_apply_weapon_damage(pos, weapon)
	_settle_tanks_on_terrain()
	_start_global_explosion_camera_hold(pos)
	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
		_show_end_popup()
	elif advance_after:
		pending_advance_after_explosion_hold = true

func _explode_realtime_weapon(pos: Vector2, weapon: String, owner: int = NO_CAMERA_OWNER) -> void:
	realtime_explosion_camera_owner = owner
	explosion_pos = pos
	explosion_timer = _weapon_explosion_duration(weapon)
	last_explosion_visual_radius = _weapon_explosion_radius(weapon)
	_apply_weapon_crater(pos, weapon)
	_apply_weapon_damage(pos, weapon)
	_settle_tanks_on_terrain()
	if owner == HUMAN_PLAYER_INDEX:
		_start_global_explosion_camera_hold(pos)
	if tank_health[HUMAN_PLAYER_INDEX] <= 0 or tank_health[AI_PLAYER_INDEX] <= 0:
		game_over = true
		_show_end_popup()

func _apply_weapon_crater(pos: Vector2, weapon: String) -> void:
	if _weapon_behavior(weapon) == "add_ground":
		_apply_ground_bomb(pos, weapon)
		return
	super._apply_weapon_crater(pos, weapon)

func _weapon_behavior(weapon: String) -> String:
	return str(_weapon_value(weapon, "behavior", "standard"))

func _weapon_explosion_duration(weapon: String) -> float:
	return float(_weapon_value(weapon, "explosion_duration", EXPLOSION_DURATION))

func _weapon_machine_child() -> String:
	return str(_weapon_value(SPECIAL_MACHINE_GUN, "child_weapon_id", SPECIAL_MACHINE_GUN_ROUND))

func _update_bouncing_turn_projectile(delta: float) -> void:
	var stepped: Dictionary = ProjectileManager.step_legacy_projectile(projectile_pos, projectile_vel, gravity, wind, delta)
	projectile_pos = stepped.get("pos", projectile_pos)
	projectile_vel = stepped.get("vel", projectile_vel)
	var enemy: int = 1 - current_player
	if ProjectileManager.projectile_hits_tank(projectile_pos, tank_positions[enemy], TANK_RADIUS, PROJECTILE_RADIUS) or _is_in_pond(projectile_pos) or ProjectileManager.is_out_of_world(projectile_pos, active_world_width, _bottom_floor_y()):
		_explode_turn_weapon(projectile_pos, turn_projectile_weapon, true)
		return
	var ground_y: float = _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		if turn_bouncer_bounce_count >= int(_weapon_value(SPECIAL_BOUNCER, "max_bounces", 3)):
			_explode_turn_weapon(Vector2(projectile_pos.x, ground_y), turn_projectile_weapon, true)
			return
		projectile_pos.y = ground_y - PROJECTILE_RADIUS
		projectile_vel.x *= float(_weapon_value(SPECIAL_BOUNCER, "bounce_damping_x", 0.78))
		projectile_vel.y = minf(-absf(projectile_vel.y) * float(_weapon_value(SPECIAL_BOUNCER, "bounce_damping_y", 0.66)), -120.0)
		turn_bouncer_bounce_count += 1

func _step_bouncer_shell(shell: Dictionary, owner: int) -> Dictionary:
	var pos: Vector2 = shell.get("pos", Vector2.ZERO)
	var vel: Vector2 = shell.get("vel", Vector2.ZERO)
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	if ProjectileManager.projectile_hits_tank(pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS) or _is_in_pond(pos) or ProjectileManager.is_out_of_world(pos, active_world_width, _bottom_floor_y()):
		return {"explode": true, "shell": shell}
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		var count: int = int(shell.get("bounces", 0))
		if count >= int(_weapon_value(SPECIAL_BOUNCER, "max_bounces", 3)):
			return {"explode": true, "shell": shell}
		shell["pos"] = Vector2(pos.x, ground_y - PROJECTILE_RADIUS)
		shell["vel"] = Vector2(
			vel.x * float(_weapon_value(SPECIAL_BOUNCER, "bounce_damping_x", 0.78)),
			minf(-absf(vel.y) * float(_weapon_value(SPECIAL_BOUNCER, "bounce_damping_y", 0.66)), -120.0)
		)
		shell["bounces"] = count + 1
	return {"explode": false, "shell": shell}

func _begin_machine_gun_burst(owner: int, shot_angle: float, shot_power_percent: float, realtime: bool) -> void:
	machine_gun_active = true
	machine_gun_turn_waiting_for_shells = not realtime
	machine_gun_owner = owner
	machine_gun_remaining = int(_weapon_value(SPECIAL_MACHINE_GUN, "burst_count", 10))
	machine_gun_interval = float(_weapon_value(SPECIAL_MACHINE_GUN, "burst_interval", 0.1))
	machine_gun_timer = 0.0
	machine_gun_angle = shot_angle
	machine_gun_power_percent = shot_power_percent
	machine_gun_realtime = realtime
	if owner == HUMAN_PLAYER_INDEX:
		quickgame_player_shot_hide_trajectory = realtime
	_fire_next_machine_gun_round()

func _update_machine_gun_burst(delta: float) -> void:
	if not machine_gun_active:
		return
	machine_gun_timer -= delta
	while machine_gun_active and machine_gun_timer <= 0.0:
		_fire_next_machine_gun_round()

func _fire_next_machine_gun_round() -> void:
	if machine_gun_remaining <= 0 or game_over:
		_finish_machine_gun_burst()
		return
	var angle_jitter: float = float(_weapon_value(SPECIAL_MACHINE_GUN, "burst_angle_jitter", 3.0))
	var power_jitter: float = float(_weapon_value(SPECIAL_MACHINE_GUN, "burst_power_jitter", 7.0))
	var shot_angle: float = clampf(machine_gun_angle + rng.randf_range(-angle_jitter, angle_jitter), MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)
	var shot_percent: float = clampf(machine_gun_power_percent + rng.randf_range(-power_jitter, power_jitter), 0.0, 100.0)
	_spawn_special_shell(machine_gun_owner, _weapon_machine_child(), shot_angle, shot_percent, machine_gun_realtime)
	machine_gun_remaining -= 1
	machine_gun_timer += machine_gun_interval
	if machine_gun_remaining <= 0:
		_finish_machine_gun_burst()

func _finish_machine_gun_burst() -> void:
	var was_realtime: bool = machine_gun_realtime
	machine_gun_active = false
	if was_realtime:
		rt_player_shell_active = ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX)

func _maybe_finish_machine_gun_turn() -> void:
	if not machine_gun_turn_waiting_for_shells:
		return
	if machine_gun_active or game_over:
		return
	if not turn_projectiles.is_empty():
		return
	if explosion_timer > 0.0 or cluster_camera_hold_timer > 0.0:
		return
	machine_gun_turn_waiting_for_shells = false
	pending_advance_after_explosion_hold = true

func _maybe_advance_after_explosion_hold() -> void:
	if not pending_advance_after_explosion_hold:
		return
	if game_over or projectile_active or not turn_projectiles.is_empty() or machine_gun_active or machine_gun_turn_waiting_for_shells:
		return
	if explosion_timer > 0.0 or cluster_camera_hold_timer > 0.0:
		return
	pending_advance_after_explosion_hold = false
	_advance_turn()
	_snap_camera_to_turn_target_if_needed()

func _maybe_show_quickgame_trajectory_after_shot() -> void:
	if not quickgame_player_shot_hide_trajectory:
		return
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME:
		quickgame_player_shot_hide_trajectory = false
		return
	if ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX) or rt_player_shell_active or machine_gun_active:
		return
	if explosion_timer > 0.0 or cluster_camera_hold_timer > 0.0:
		return
	quickgame_player_shot_hide_trajectory = false

func _snap_camera_to_turn_target_if_needed() -> void:
	if game_mode != GAME_MODE_HOTSEAT:
		return
	var target_x: float = _camera_target_x()
	if absf(camera_x - target_x) <= 85.0:
		camera_x = target_x

func _clear_machine_gun_burst() -> void:
	machine_gun_active = false
	machine_gun_remaining = 0
	machine_gun_timer = 0.0
	machine_gun_turn_waiting_for_shells = false

func _turn_projectiles_include_weapon(weapon: String) -> bool:
	for shell: Dictionary in turn_projectiles:
		if str(shell.get("weapon", "")) == weapon:
			return true
	return false

func _realtime_special_projectiles_active() -> bool:
	if machine_gun_active:
		return true
	for shell: Dictionary in rt_projectiles:
		var weapon: String = str(shell.get("weapon", ""))
		if weapon == SPECIAL_BOUNCER or weapon == SPECIAL_MACHINE_GUN_ROUND:
			return true
	return false

func _spawn_special_shell(owner: int, weapon: String, shot_angle: float, shot_power_percent: float, realtime: bool) -> void:
	var facing: float = 1.0 if owner == HUMAN_PLAYER_INDEX else -1.0
	var shot_power: float = _power_from_percent(shot_power_percent)
	var rad: float = deg_to_rad(shot_angle)
	var start_pos: Vector2 = tank_positions[owner] + Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var start_vel: Vector2 = Vector2(facing * shot_power * cos(rad), -shot_power * sin(rad))
	var shell: Dictionary = ProjectileFactory.make_shell(owner, weapon, start_pos, start_vel, false)
	if realtime:
		if rt_projectiles.size() >= RT_MAX_ACTIVE_PROJECTILES and weapon != SPECIAL_MACHINE_GUN_ROUND:
			rt_projectiles.pop_front()
		rt_projectiles.append(shell)
		rt_player_shell_active = owner == HUMAN_PLAYER_INDEX
	else:
		turn_projectiles.append(shell)
	_trigger_fire_fx(owner, shot_angle)

func _fire_laser(owner: int, shot_angle: float, shot_power_percent: float, realtime: bool) -> void:
	var facing: float = 1.0 if owner == HUMAN_PLAYER_INDEX else -1.0
	var rad: float = deg_to_rad(shot_angle)
	var start_pos: Vector2 = tank_positions[owner] + Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var dir: Vector2 = Vector2(facing * cos(rad), -sin(rad)).normalized()
	var end_pos: Vector2 = start_pos + dir * active_world_width * 1.2
	_cut_laser_path(start_pos, end_pos)
	_apply_laser_damage(owner, start_pos, end_pos)
	realtime_explosion_camera_owner = owner if realtime else NO_CAMERA_OWNER
	explosion_pos = end_pos
	explosion_timer = 0.18
	last_explosion_visual_radius = 20.0
	_settle_tanks_on_terrain()
	_trigger_fire_fx(owner, shot_angle)
	if not realtime or owner == HUMAN_PLAYER_INDEX:
		_start_global_explosion_camera_hold(end_pos)
	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
		_show_end_popup()

func _cut_laser_path(start_pos: Vector2, end_pos: Vector2) -> void:
	var width: float = float(_weapon_value(SPECIAL_LASER, "laser_cut_width", 18.0))
	var depth: float = float(_weapon_value(SPECIAL_LASER, "laser_cut_depth", 180.0))
	var seg: Vector2 = end_pos - start_pos
	var seg_len_sq: float = maxf(seg.length_squared(), 1.0)
	for i: int in range(terrain_points.size()):
		var p: Vector2 = terrain_points[i]
		var t: float = clampf((p - start_pos).dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest: Vector2 = start_pos + seg * t
		if p.distance_to(closest) <= width:
			p.y = clampf(p.y + depth, VAR_TERRAIN_MIN_Y, _bottom_floor_y())
			terrain_points[i] = p
	_refresh_terrain_line()
	_reflow_water_after_terrain_change(start_pos.x)

func _apply_laser_damage(owner: int, start_pos: Vector2, end_pos: Vector2) -> void:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	var dist: float = _point_to_segment_distance(tank_positions[target], start_pos, end_pos)
	if dist <= float(_weapon_value(SPECIAL_LASER, "direct_radius", 14.0)) + TANK_RADIUS:
		tank_health[target] = maxi(0, tank_health[target] - int(_weapon_value(SPECIAL_LASER, "direct_damage", 18)))

func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((point - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _apply_ground_bomb(pos: Vector2, weapon: String) -> void:
	var radius: float = _weapon_crater_radius(weapon)
	var raise_amount: float = float(_weapon_value(weapon, "ground_raise_amount", absf(_weapon_crater_depth(weapon))))
	for i: int in range(terrain_points.size()):
		var point: Vector2 = terrain_points[i]
		var dx: float = point.x - pos.x
		if absf(dx) <= radius:
			var normalized_x: float = dx / maxf(radius, 0.001)
			var mound: float = sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
			point.y = clampf(point.y - raise_amount * mound, VAR_TERRAIN_MIN_Y, _bottom_floor_y())
			terrain_points[i] = point
	_refresh_terrain_line()
