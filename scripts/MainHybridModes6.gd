extends "res://scripts/MainHybridModes5.gd"

var rt_player_shell_active: bool = false

func _ready() -> void:
	super._ready()
	_resize_mobile_action_buttons()
	_update_fire_button_charge_style(0.0)

func _setup_realtime_single_player() -> void:
	super._setup_realtime_single_player()
	rt_player_shell_active = false
	_resize_mobile_action_buttons()
	_update_fire_button_charge_style(0.0)

func reset_match() -> void:
	super.reset_match()
	rt_player_shell_active = false
	_update_fire_button_charge_style(0.0)

func _resize_mobile_action_buttons() -> void:
	if mobile_left_button != null:
		mobile_left_button.position = Vector2(16, 430)
		mobile_left_button.size = Vector2(92, 88)
	if mobile_right_button != null:
		mobile_right_button.position = Vector2(122, 430)
		mobile_right_button.size = Vector2(92, 88)
	if mobile_fire_button != null:
		mobile_fire_button.position = Vector2(354, 448)
		mobile_fire_button.size = Vector2(180, 70)

func _player_can_fire() -> bool:
	return not rt_player_shell_active and not game_over

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

func _reset_realtime_charge_state() -> void:
	rt_fire_charge_time = 0.0
	rt_fire_charge_percent = 0.0
	rt_fire_button_held = false
	rt_keyboard_fire_held = false
	_update_fire_button_charge_style(0.0)

func _update_realtime_fire_charge(delta: float) -> void:
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
		_update_fire_button_charge_style(charge_ratio)
	elif rt_player_shell_active:
		_update_fire_button_unavailable_style()
	else:
		_update_fire_button_charge_style(0.0)

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
			if owner == HUMAN_PLAYER_INDEX:
				rt_player_shell_active = false
			_explode_realtime(pos)
		else:
			projectile["pos"] = pos
			projectile["vel"] = vel
			remaining.append(projectile)
	rt_projectiles = remaining

func _draw_realtime_cooldown_widgets() -> void:
	# Fire cooldown meter removed for realtime mode. FIRE button itself now shows
	# charge color. Movement is unlimited, so no MOVE meter is needed either.
	return

func _update_ui() -> void:
	super._update_ui()
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME and not game_over:
		if rt_fire_button_held or rt_keyboard_fire_held:
			power_label.text = "Charge: %.0f%%" % rt_fire_charge_percent
		elif rt_player_shell_active:
			power_label.text = "Shell in flight"
		else:
			power_label.text = "Hold FIRE"

func _update_fire_button_charge_style(charge_ratio: float) -> void:
	if mobile_fire_button == null:
		return
	var color: Color = _charge_button_color(charge_ratio)
	_apply_fire_button_style(color, color.darkened(0.35), Color.WHITE)

func _update_fire_button_unavailable_style() -> void:
	if mobile_fire_button == null:
		return
	_apply_fire_button_style(Color(0.18, 0.18, 0.20, 0.86), Color(0.08, 0.08, 0.10, 0.96), Color(0.75, 0.75, 0.78, 1.0))

func _charge_button_color(charge_ratio: float) -> Color:
	var v: float = clampf(charge_ratio, 0.0, 1.0)
	if v < 0.5:
		var t: float = v / 0.5
		return Color(lerpf(0.10, 1.0, t), 0.80, 0.12, 0.92)
	var t2: float = (v - 0.5) / 0.5
	return Color(1.0, lerpf(0.80, 0.12, t2), 0.08, 0.92)

func _apply_fire_button_style(bg: Color, border: Color, font: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(16)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.12)
	for state: String in ["normal", "hover", "focus"]:
		mobile_fire_button.add_theme_stylebox_override(state, normal)
	mobile_fire_button.add_theme_stylebox_override("pressed", pressed)
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		mobile_fire_button.add_theme_color_override(color_name, font)
