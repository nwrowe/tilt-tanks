extends "res://scripts/core/MainGame.gd"

# Temporary mode facade during refactor.
# Routes low-risk mode decisions through scripts/modes/*.gd.
# If this tests cleanly, fold these overrides back into MainGame.gd.

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
	elif not keyboard_down and hotseat_keyboard_fire_held:
		hotseat_keyboard_fire_held = false
		_release_hotseat_charged_shot()

	if hotseat_fire_button_held or hotseat_keyboard_fire_held:
		hotseat_charge_time = minf(HOTSEAT_CHARGE_TIME_MAX, hotseat_charge_time + delta)
		var charge_ratio: float = clampf(hotseat_charge_time / HOTSEAT_CHARGE_TIME_MAX, 0.0, 1.0)
		hotseat_charge_percent = HotseatMode.charge_percent(hotseat_charge_time, HOTSEAT_CHARGE_TIME_MAX, HOTSEAT_CHARGE_MIN_PERCENT, HOTSEAT_CHARGE_MAX_PERCENT)
		power_percent = hotseat_charge_percent
		power = _power_from_percent(power_percent)
		_update_fire_button_charge_style(charge_ratio)
	elif _hotseat_can_begin_charge():
		_update_fire_button_charge_style(0.0)

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
