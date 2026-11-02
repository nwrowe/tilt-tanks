extends "res://scripts/core/MainGameModeFacade.gd"

# Implements special weapon behaviors added after the data-driven weapon pass.
# Standard, Heavy, and Cluster continue through the existing runtime path.

const SPECIAL_LASER: String = WeaponRegistry.WEAPON_LASER
const SPECIAL_NUKE: String = WeaponRegistry.WEAPON_TACTICAL_NUKE
const SPECIAL_BOUNCER: String = WeaponRegistry.WEAPON_BOUNCER
const SPECIAL_GROUND_BOMB: String = WeaponRegistry.WEAPON_GROUND_BOMB
const SPECIAL_MACHINE_GUN: String = WeaponRegistry.WEAPON_MACHINE_GUN
const SPECIAL_MACHINE_GUN_ROUND: String = WeaponRegistry.WEAPON_MACHINE_GUN_ROUND

const NO_CAMERA_OWNER: int = -1
const HOTSEAT_CAMERA_READY_MARGIN: float = 90.0
const HOTSEAT_CAMERA_ALREADY_TARGET_EPS: float = 2.0
const MACHINE_GUN_CAMERA_LEAD_BIAS: float = 0.72
const BOUNCER_MIN_UPWARD_SPEED: float = 95.0

var weapon_burst: WeaponBurstSession = WeaponBurstSession.new()
# Preserve the two cross-facade fields needed by online host authority.
# All additional burst details live exclusively in the composed session.
var machine_gun_active: bool:
	get:
		return weapon_burst.active
	set(value):
		weapon_burst.active = value
var machine_gun_turn_waiting_for_shells: bool:
	get:
		return weapon_burst.turn_waiting_for_shells
	set(value):
		weapon_burst.turn_waiting_for_shells = value
var machine_gun_camera_active: bool = false
var machine_gun_camera_pos: Vector2 = Vector2.INF
var pending_advance_after_explosion_hold: bool = false
var quickgame_player_shot_hide_trajectory: bool = false
var realtime_explosion_camera_owner: int = NO_CAMERA_OWNER
var hotseat_camera_already_valid: bool = false
var turn_bouncer_bounce_count: int = 0

func reset_match() -> void:
	_clear_machine_gun_burst()
	pending_advance_after_explosion_hold = false
	quickgame_player_shot_hide_trajectory = false
	realtime_explosion_camera_owner = NO_CAMERA_OWNER
	hotseat_camera_already_valid = false
	turn_bouncer_bounce_count = 0
	super.reset_match()

func _process(delta: float) -> void:
	if game_over and menu_state == MENU_STATE_GAME:
		_process_game_over_visuals(delta)
		return
	_update_machine_gun_burst(delta)
	super._process(delta)
	_maybe_finish_machine_gun_turn()
	_maybe_advance_after_explosion_hold()
	_maybe_show_quickgame_trajectory_after_shot()

func _camera_target_x() -> float:
	# MainGame updates the camera before this facade gets to advance the delayed
	# hotseat turn. On the exact frame the explosion hold expires, keep the camera
	# fixed so it does not briefly lerp back toward the old player before the turn
	# switch occurs.
	if _should_freeze_camera_until_pending_hotseat_advance_runs():
		return camera_x
	if _should_hold_hotseat_camera_at_current_position():
		return camera_x
	if machine_gun_camera_active and machine_gun_camera_pos != Vector2.INF:
		return _camera_x_for_focus(machine_gun_camera_pos.x)
	# The inherited realtime camera chooses a human-owned projectile or tank
	# (and explicit camera holds) independently of explosion_pos/timer.
	# Do not mutate live explosion state merely to calculate camera focus.
	return super._camera_target_x()

func _camera_x_for_focus(focus_x: float) -> float:
	var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
	return clampf(focus_x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))

func _should_freeze_camera_until_pending_hotseat_advance_runs() -> bool:
	return (
		pending_advance_after_explosion_hold
		and game_mode == GAME_MODE_HOTSEAT
		and WeaponFramePolicy.can_advance_turn(
			game_over, projectile_active, not turn_projectiles.is_empty(),
			weapon_burst.active, weapon_burst.turn_waiting_for_shells,
			explosion_timer, cluster_camera_hold_timer
		)
	)

func _should_hold_hotseat_camera_at_current_position() -> bool:
	return hotseat_camera_already_valid and game_mode == GAME_MODE_HOTSEAT and not projectile_active and turn_projectiles.is_empty() and not weapon_burst.active and not weapon_burst.turn_waiting_for_shells and not pending_advance_after_explosion_hold

func _draw_trajectory_preview() -> void:
	# Hide immediately after a human shot in both hotseat and quick game. In quick
	# game, AI explosions alone should not hide the player's aiming preview.
	if pending_advance_after_explosion_hold or quickgame_player_shot_hide_trajectory:
		return
	super._draw_trajectory_preview()

func _hotseat_can_begin_charge() -> bool:
	if pending_advance_after_explosion_hold or weapon_burst.active or weapon_burst.turn_waiting_for_shells:
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
	if projectile_active or not turn_projectiles.is_empty() or game_over or overlay_open or weapon_burst.active or weapon_burst.turn_waiting_for_shells or pending_advance_after_explosion_hold:
		return

	hotseat_camera_already_valid = false

	if _weapon_behavior(selected_weapon) == "laser_cut":
		_fire_laser(current_player, angle_deg, power_percent, false, selected_weapon)
		if not game_over:
			pending_advance_after_explosion_hold = true
		return
	if _weapon_behavior(selected_weapon) == "machine_gun":
		_begin_machine_gun_burst(current_player, angle_deg, power_percent, false, selected_weapon)
		return

	super._on_fire_pressed()
	if _weapon_behavior(selected_weapon) == "bounce":
		turn_bouncer_bounce_count = 0

func _release_realtime_charged_shot() -> void:
	if _weapon_behavior(selected_weapon) == "laser_cut":
		if not _player_can_fire() or game_over or overlay_open:
			_reset_realtime_charge_state()
			return
		power_percent = clampf(rt_fire_charge_percent, RT_CHARGE_MIN_PERCENT, RT_CHARGE_MAX_PERCENT)
		power = _power_from_percent(power_percent)
		_fire_laser(HUMAN_PLAYER_INDEX, angle_deg, power_percent, true, selected_weapon)
		rt_player_shell_active = false
		quickgame_player_shot_hide_trajectory = true
		_reset_realtime_charge_state()
		return
	if _weapon_behavior(selected_weapon) == "machine_gun":
		if not _player_can_fire() or game_over or overlay_open or weapon_burst.active:
			_reset_realtime_charge_state()
			return
		power_percent = clampf(rt_fire_charge_percent, RT_CHARGE_MIN_PERCENT, RT_CHARGE_MAX_PERCENT)
		power = _power_from_percent(power_percent)
		_begin_machine_gun_burst(HUMAN_PLAYER_INDEX, angle_deg, power_percent, true, selected_weapon)
		rt_player_shell_active = true
		quickgame_player_shot_hide_trajectory = true
		_reset_realtime_charge_state()
		return
	super._release_realtime_charged_shot()
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and (ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX) or rt_player_shell_active):
		quickgame_player_shot_hide_trajectory = true

func _update_projectile(delta: float) -> void:
	if _weapon_behavior(turn_projectile_weapon) == "bounce":
		_update_bouncing_turn_projectile(delta)
		return
	super._update_projectile(delta)

func _update_turn_weapon_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	var last_explosion_pos: Vector2 = Vector2.INF
	var last_center_pos: Vector2 = Vector2.INF
	var any_center_shell_alive: bool = false

	turn_cluster_camera_pos = Vector2.INF

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
			last_explosion_pos = pos
			_explode_turn_weapon(pos, weapon, false)
			if is_center:
				cluster_camera_hold_pos = pos
				cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		else:
			remaining.append(stepped)
			if is_center:
				any_center_shell_alive = true

	turn_projectiles = remaining

	if weapon_burst.turn_waiting_for_shells or _turn_projectiles_include_weapon(_burst_round_weapon()):
		_update_machine_gun_camera_from_shells(turn_projectiles, weapon_burst.owner)
	elif any_center_shell_alive:
		cluster_camera_hold_pos = last_center_pos
	elif not turn_projectiles.is_empty() and cluster_camera_hold_pos == Vector2.INF:
		var avg: Vector2 = ProjectileManager.average_shell_position(turn_projectiles)
		turn_cluster_camera_pos = avg
		cluster_camera_hold_pos = avg

	if turn_projectiles.is_empty():
		turn_cluster_camera_pos = Vector2.INF
		if weapon_burst.turn_waiting_for_shells:
			_maybe_finish_machine_gun_turn()
			return
		if last_explosion_pos != Vector2.INF:
			cluster_camera_hold_pos = last_explosion_pos
		elif cluster_camera_hold_pos == Vector2.INF and last_center_pos != Vector2.INF:
			cluster_camera_hold_pos = last_center_pos
		if cluster_camera_hold_pos != Vector2.INF:
			cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		if not game_over:
			pending_advance_after_explosion_hold = true

func _update_all_realtime_projectiles(delta: float) -> void:
	# ModeFacade now steps all realtime shells exactly once. Preserve
	# burst-specific fire availability and camera focus after its pass.
	if rt_projectiles.is_empty():
		return
	super._update_all_realtime_projectiles(delta)
	rt_player_shell_active = rt_player_shell_active or weapon_burst.active
	if machine_gun_camera_active:
		_update_machine_gun_camera_from_shells(rt_projectiles, HUMAN_PLAYER_INDEX)

func _realtime_special_shell_step(shell: Dictionary, owner: int) -> Dictionary:
	if _weapon_behavior(str(shell.get("weapon", ""))) != "bounce":
		return {"handled": false}
	var bounce_result: Dictionary = _step_bouncer_shell(shell, owner)
	bounce_result["handled"] = true
	return bounce_result

func _fire_realtime_projectile(owner: int) -> void:
	if game_over:
		return
	var weapon: String = selected_weapon if owner == HUMAN_PLAYER_INDEX else WEAPON_STANDARD
	var shot_angle: float = player_angles[owner] if owner == AI_PLAYER_INDEX else angle_deg
	var shot_power_percent: float = player_power_percents[owner] if owner == AI_PLAYER_INDEX else power_percent
	if _weapon_behavior(weapon) == "laser_cut":
		_fire_laser(owner, shot_angle, shot_power_percent, true, weapon)
		return
	if _weapon_behavior(weapon) == "machine_gun":
		_begin_machine_gun_burst(owner, shot_angle, shot_power_percent, true, weapon)
		return
	# Normal and special fired shells have one scene owner for muzzle
	# geometry, capacity eviction, collection mutation and fire effects.
	_spawn_weapon_shell(owner, weapon, shot_angle, shot_power_percent, true)
	projectile_active = false
	if owner == HUMAN_PLAYER_INDEX:
		quickgame_player_shot_hide_trajectory = true

func _explode_turn_weapon(pos: Vector2, weapon: String, advance_after: bool) -> void:
	projectile_active = false
	_apply_weapon_impact(pos, weapon)
	if not _is_burst_round(weapon):
		_start_global_explosion_camera_hold(pos)
	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
		_show_end_popup()
	elif advance_after:
		pending_advance_after_explosion_hold = true

func _explode_realtime_weapon(pos: Vector2, weapon: String, owner: int = NO_CAMERA_OWNER) -> void:
	realtime_explosion_camera_owner = owner
	_apply_weapon_impact(pos, weapon)
	if owner == HUMAN_PLAYER_INDEX and not _is_burst_round(weapon):
		_start_global_explosion_camera_hold(pos)
	if tank_health[HUMAN_PLAYER_INDEX] <= 0 or tank_health[AI_PLAYER_INDEX] <= 0:
		game_over = true
		_show_end_popup()

## Shared scene-facing impact sequence for turn and realtime projectiles.
## Camera ownership, turn advance and end popup stay in the callers.
func _apply_weapon_impact(pos: Vector2, weapon: String) -> void:
	explosion_pos = pos
	explosion_timer = _weapon_explosion_duration(weapon)
	last_explosion_visual_radius = _weapon_explosion_radius(weapon)
	_apply_weapon_crater(pos, weapon)
	_apply_weapon_damage(pos, weapon)
	_settle_tanks_on_terrain()

func _apply_weapon_crater(pos: Vector2, weapon: String) -> void:
	if _weapon_behavior(weapon) == "add_ground":
		_apply_ground_bomb(pos, weapon)
		return
	super._apply_weapon_crater(pos, weapon)

func _weapon_behavior(weapon: String) -> String:
	return str(_weapon_value(weapon, "behavior", "standard"))

func _weapon_explosion_duration(weapon: String) -> float:
	return float(_weapon_value(weapon, "explosion_duration", EXPLOSION_DURATION))

func _weapon_machine_child(weapon: String = SPECIAL_MACHINE_GUN) -> String:
	return str(_weapon_value(weapon, "child_weapon_id", SPECIAL_MACHINE_GUN_ROUND))

func _burst_round_weapon() -> String:
	return weapon_burst.child_weapon_id if not weapon_burst.child_weapon_id.is_empty() else SPECIAL_MACHINE_GUN_ROUND

func _is_burst_round(weapon: String) -> bool:
	# Preserve default-round behavior for standalone compatibility callers.
	return weapon == SPECIAL_MACHINE_GUN_ROUND or weapon == weapon_burst.child_weapon_id

func _update_bouncing_turn_projectile(delta: float) -> void:
	var stepped: Dictionary = ProjectileManager.step_legacy_projectile(
		projectile_pos, projectile_vel, gravity, wind, delta
	)
	projectile_pos = stepped.get("pos", projectile_pos)
	projectile_vel = stepped.get("vel", projectile_vel)
	# The legacy turn projectile stores scalar position, velocity and
	# bounce count. Adapt those into a transient shell to reuse the exact
	# same contact policy as realtime (never duplicate persistent state).
	var shell: Dictionary = {
		"pos": projectile_pos, "vel": projectile_vel,
		"weapon": turn_projectile_weapon, "bounces": turn_bouncer_bounce_count
	}
	var result: Dictionary = _step_bouncer_shell(shell, current_player)
	if bool(result.get("explode", false)):
		_explode_turn_weapon(
			result.get("impact_pos", projectile_pos), turn_projectile_weapon, true
		)
		return
	projectile_pos = shell.get("pos", projectile_pos)
	projectile_vel = shell.get("vel", projectile_vel)
	turn_bouncer_bounce_count = int(shell.get("bounces", turn_bouncer_bounce_count))

func _step_bouncer_shell(shell: Dictionary, owner: int) -> Dictionary:
	var pos: Vector2 = shell.get("pos", Vector2.ZERO)
	var vel: Vector2 = shell.get("vel", Vector2.ZERO)
	var weapon: String = str(shell.get("weapon", SPECIAL_BOUNCER))
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	if ProjectileManager.projectile_hits_tank(pos, tank_positions[target], TANK_RADIUS, PROJECTILE_RADIUS) or _is_in_pond(pos) or ProjectileManager.is_out_of_world(pos, active_world_width, _bottom_floor_y()):
		return {"explode": true, "shell": shell}
	var ground_y: float = _ground_y_at_x(pos.x)
	if pos.y >= ground_y:
		var count: int = int(shell.get("bounces", 0))
		if WeaponBounceLogic.reached_limit(count, int(_weapon_value(weapon, "max_bounces", 3))):
			# Legacy turn explosions snap a terminal ground contact to the
			# ground surface. Realtime camera/explosion callers still use the
			# unmodified stepped position, as before.
			return {
				"explode": true, "shell": shell,
				"impact_pos": Vector2(pos.x, ground_y)
			}
		WeaponBounceLogic.apply_ground_bounce(
			shell, ground_y, PROJECTILE_RADIUS, _reflect_bouncer_velocity(pos.x, vel, weapon)
		)
	return {"explode": false, "shell": shell}

func _reflect_bouncer_velocity(
	x: float, incoming_vel: Vector2, weapon: String = SPECIAL_BOUNCER
) -> Vector2:
	return WeaponBounceLogic.reflect_velocity(
		incoming_vel, _terrain_slope_at_x(x),
		float(_weapon_value(weapon, "bounce_damping_x", 0.78)),
		float(_weapon_value(weapon, "bounce_damping_y", 0.66)),
		BOUNCER_MIN_UPWARD_SPEED
	)

func _begin_machine_gun_burst(
	owner: int, shot_angle: float, shot_power_percent: float,
	realtime: bool, weapon: String = SPECIAL_MACHINE_GUN
) -> void:
	weapon_burst.begin(
		owner, shot_angle, shot_power_percent, realtime,
		int(_weapon_value(weapon, "burst_count", 10)),
		float(_weapon_value(weapon, "burst_interval", 0.1)),
		weapon, _weapon_machine_child(weapon)
	)
	machine_gun_camera_active = true
	machine_gun_camera_pos = tank_positions[owner]
	if owner == HUMAN_PLAYER_INDEX:
		quickgame_player_shot_hide_trajectory = realtime
	_fire_next_machine_gun_round()

func _update_machine_gun_burst(delta: float) -> void:
	if not weapon_burst.active:
		return
	weapon_burst.advance(delta)
	while weapon_burst.round_due():
		_fire_next_machine_gun_round()

func _fire_next_machine_gun_round() -> void:
	if weapon_burst.remaining <= 0 or game_over:
		_finish_machine_gun_burst()
		return
	var shot: Dictionary = weapon_burst.shot_settings(
		rng,
		float(_weapon_value(weapon_burst.weapon_id, "burst_angle_jitter", 3.0)),
		float(_weapon_value(weapon_burst.weapon_id, "burst_power_jitter", 7.0)),
		MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE
	)
	_spawn_weapon_shell(
		weapon_burst.owner, _burst_round_weapon(), float(shot["angle"]),
		float(shot["power_percent"]), weapon_burst.realtime
	)
	weapon_burst.round_fired()
	if weapon_burst.remaining <= 0:
		_finish_machine_gun_burst()

func _finish_machine_gun_burst() -> void:
	if weapon_burst.finish():
		rt_player_shell_active = ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX)

func _maybe_finish_machine_gun_turn() -> void:
	if not weapon_burst.can_finish_turn(
		game_over, not turn_projectiles.is_empty(), explosion_timer,
		cluster_camera_hold_timer
	):
		return
	weapon_burst.turn_waiting_for_shells = false
	pending_advance_after_explosion_hold = true

func _maybe_advance_after_explosion_hold() -> void:
	if not pending_advance_after_explosion_hold:
		return
	if not WeaponFramePolicy.can_advance_turn(
		game_over, projectile_active, not turn_projectiles.is_empty(),
		weapon_burst.active, weapon_burst.turn_waiting_for_shells,
		explosion_timer, cluster_camera_hold_timer
	):
		return
	pending_advance_after_explosion_hold = false
	machine_gun_camera_active = false
	machine_gun_camera_pos = Vector2.INF
	_advance_turn()
	_hold_hotseat_camera_if_current_view_is_valid()

func _hold_hotseat_camera_if_current_view_is_valid() -> void:
	hotseat_camera_already_valid = false
	if game_mode != GAME_MODE_HOTSEAT:
		return
	var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
	var max_camera_x: float = maxf(0.0, active_world_width - camera_world_width)
	var target_x: float = super._camera_target_x()
	if absf(camera_x - target_x) <= HOTSEAT_CAMERA_ALREADY_TARGET_EPS:
		hotseat_camera_already_valid = true
		return
	var next_tank_x: float = tank_positions[current_player].x
	var visible_left: float = camera_x + HOTSEAT_CAMERA_READY_MARGIN
	var visible_right: float = camera_x + camera_world_width - HOTSEAT_CAMERA_READY_MARGIN
	if next_tank_x >= visible_left and next_tank_x <= visible_right:
		hotseat_camera_already_valid = true
		return
	if camera_x <= HOTSEAT_CAMERA_ALREADY_TARGET_EPS and target_x <= HOTSEAT_CAMERA_ALREADY_TARGET_EPS:
		hotseat_camera_already_valid = true
		return
	if camera_x >= max_camera_x - HOTSEAT_CAMERA_ALREADY_TARGET_EPS and target_x >= max_camera_x - HOTSEAT_CAMERA_ALREADY_TARGET_EPS:
		hotseat_camera_already_valid = true

func _maybe_show_quickgame_trajectory_after_shot() -> void:
	if not quickgame_player_shot_hide_trajectory:
		return
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME:
		quickgame_player_shot_hide_trajectory = false
		return
	if ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX) or rt_player_shell_active or weapon_burst.active:
		return
	if explosion_timer > 0.0 or cluster_camera_hold_timer > 0.0:
		return
	quickgame_player_shot_hide_trajectory = false
	machine_gun_camera_active = false
	machine_gun_camera_pos = Vector2.INF

func _update_machine_gun_camera_from_shells(shells: Array[Dictionary], owner: int) -> void:
	var focus: Vector2 = ProjectileManager.leading_shell_focus_for_weapon(
		shells, _burst_round_weapon(), owner != HUMAN_PLAYER_INDEX and owner != 0,
		MACHINE_GUN_CAMERA_LEAD_BIAS
	)
	# Keep the previous focus while a burst is between rounds.
	if focus != Vector2.INF:
		machine_gun_camera_pos = focus

func _clear_machine_gun_burst() -> void:
	weapon_burst.clear_active()
	machine_gun_camera_active = false
	machine_gun_camera_pos = Vector2.INF

func _turn_projectiles_include_weapon(weapon: String) -> bool:
	for shell: Dictionary in turn_projectiles:
		if str(shell.get("weapon", "")) == weapon:
			return true
	return false

func _realtime_special_projectiles_active() -> bool:
	if weapon_burst.active or machine_gun_camera_active:
		return true
	for shell: Dictionary in rt_projectiles:
		var weapon: String = str(shell.get("weapon", ""))
		if _weapon_behavior(weapon) == "bounce" or _is_burst_round(weapon):
			return true
	return false

func _spawn_weapon_shell(owner: int, weapon: String, shot_angle: float, shot_power_percent: float, realtime: bool) -> void:
	var facing: float = 1.0 if owner == HUMAN_PLAYER_INDEX else -1.0
	var shot_power: float = _power_from_percent(shot_power_percent)
	var shell: Dictionary = ProjectileFactory.make_fired_shell(
		owner, weapon, tank_positions[owner], facing, shot_angle,
		shot_power, CANNON_LENGTH
	)
	if realtime:
		if rt_projectiles.size() >= RT_MAX_ACTIVE_PROJECTILES and not _is_burst_round(weapon):
			rt_projectiles.pop_front()
		rt_projectiles.append(shell)
		# A new AI shell must not hide an already-active human projectile.
		# Recalculate after eviction so a popped human shell also clears it.
		rt_player_shell_active = ProjectileManager.has_shell_for_owner(
			rt_projectiles, HUMAN_PLAYER_INDEX
		)
	else:
		turn_projectiles.append(shell)
	_trigger_fire_fx(owner, shot_angle)

func _fire_laser(
	owner: int, shot_angle: float, shot_power_percent: float,
	realtime: bool, weapon: String = SPECIAL_LASER
) -> void:
	var facing: float = 1.0 if owner == HUMAN_PLAYER_INDEX else -1.0
	var rad: float = deg_to_rad(shot_angle)
	var start_pos: Vector2 = tank_positions[owner] + Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var dir: Vector2 = Vector2(facing * cos(rad), -sin(rad)).normalized()
	var end_pos: Vector2 = start_pos + dir * active_world_width * 1.2
	_cut_laser_path(start_pos, end_pos, weapon)
	_apply_laser_damage(owner, start_pos, end_pos, weapon)
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

func _cut_laser_path(
	start_pos: Vector2, end_pos: Vector2, weapon: String = SPECIAL_LASER
) -> void:
	TerrainManager.apply_laser_cut(
		terrain_points, start_pos, end_pos,
		float(_weapon_value(weapon, "laser_cut_width", 18.0)),
		float(_weapon_value(weapon, "laser_cut_depth", 180.0)),
		VAR_TERRAIN_MIN_Y, _bottom_floor_y()
	)
	_refresh_terrain_line()
	_reflow_water_after_terrain_change(start_pos.x)

func _apply_laser_damage(
	owner: int, start_pos: Vector2, end_pos: Vector2,
	weapon: String = SPECIAL_LASER
) -> void:
	var target: int = AI_PLAYER_INDEX if owner == HUMAN_PLAYER_INDEX else HUMAN_PLAYER_INDEX
	var dist: float = TerrainMath.point_to_segment_distance(tank_positions[target], start_pos, end_pos)
	if dist <= float(_weapon_value(weapon, "direct_radius", 14.0)) + TANK_RADIUS:
		tank_health = match_runtime_sync.apply_direct_damage(
			tank_health, target, int(_weapon_value(weapon, "direct_damage", 18))
		)
		_sync_game_over_state_from_match_controller()

func _apply_ground_bomb(pos: Vector2, weapon: String) -> void:
	TerrainManager.apply_ground_mound(
		terrain_points, pos, _weapon_crater_radius(weapon),
		float(_weapon_value(weapon, "ground_raise_amount", absf(_weapon_crater_depth(weapon)))),
		VAR_TERRAIN_MIN_Y, _bottom_floor_y()
	)
	_refresh_terrain_line()
