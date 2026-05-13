extends "res://scripts/MainHybridModes16.gd"

const HOTSEAT_CHARGE_TIME_MAX: float = 1.65
const HOTSEAT_CHARGE_MIN_PERCENT: float = 10.0
const HOTSEAT_CHARGE_MAX_PERCENT: float = 100.0
const PAN_RELEASE_HOLD_TIME: float = 1.4

var hotseat_fire_button_held: bool = false
var hotseat_keyboard_fire_held: bool = false
var hotseat_charge_time: float = 0.0
var hotseat_charge_percent: float = 0.0
var swipe_panning: bool = false
var manual_camera_active: bool = false
var manual_camera_timer: float = 0.0
var turn_cluster_camera_pos: Vector2 = Vector2.INF

func _ready() -> void:
	super._ready()
	if mobile_fire_button != null:
		if not mobile_fire_button.button_down.is_connected(_on_hotseat_fire_button_down):
			mobile_fire_button.button_down.connect(_on_hotseat_fire_button_down)
		if not mobile_fire_button.button_up.is_connected(_on_hotseat_fire_button_up):
			mobile_fire_button.button_up.connect(_on_hotseat_fire_button_up)
	_update_power_slider_visibility()

func reset_match() -> void:
	hotseat_fire_button_held = false
	hotseat_keyboard_fire_held = false
	hotseat_charge_time = 0.0
	hotseat_charge_percent = 0.0
	manual_camera_active = false
	manual_camera_timer = 0.0
	turn_cluster_camera_pos = Vector2.INF
	super.reset_match()
	_update_power_slider_visibility()

func _show_game_ui() -> void:
	super._show_game_ui()
	_update_power_slider_visibility()

func _update_power_slider_visibility() -> void:
	if menu_state == MENU_STATE_GAME:
		if power_slider != null:
			power_slider.visible = false
		if power_label != null:
			power_label.visible = true

func _process(delta: float) -> void:
	_update_hotseat_charge(delta)
	if manual_camera_active:
		manual_camera_timer = maxf(0.0, manual_camera_timer - delta)
		if manual_camera_timer <= 0.0:
			manual_camera_active = false
	super._process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if menu_state != MENU_STATE_GAME or overlay_open:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		swipe_panning = touch.pressed
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_apply_camera_pan_delta(drag.relative.x)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			swipe_panning = mb.pressed
	elif event is InputEventMouseMotion and swipe_panning and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_apply_camera_pan_delta(mm.relative.x)

func _apply_camera_pan_delta(screen_dx: float) -> void:
	if absf(screen_dx) < 0.01:
		return
	var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
	camera_x = clampf(camera_x - screen_dx / CAMERA_SCALE, 0.0, maxf(0.0, active_world_width - camera_world_width))
	manual_camera_active = true
	manual_camera_timer = PAN_RELEASE_HOLD_TIME
	queue_redraw()

func _camera_target_x() -> float:
	if manual_camera_active and not projectile_active and turn_projectiles.is_empty() and rt_projectiles.is_empty():
		return camera_x
	if turn_cluster_camera_pos != Vector2.INF:
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(turn_cluster_camera_pos.x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	return super._camera_target_x()

func _draw_turn_widget() -> void:
	if game_over:
		return
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME:
		return
	var box: Rect2 = Rect2(Vector2(VIEW_SIZE.x - 232.0, 64.0), Vector2(156.0, 44.0))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.64), true)
	draw_rect(box, Color(1.0, 1.0, 1.0, 0.22), false, 1.0)
	var text: String = "P%d  %02ds" % [current_player + 1, int(ceil(turn_timer))]
	draw_string(ThemeDB.fallback_font, box.position + Vector2(16.0, 29.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _on_hotseat_fire_button_down() -> void:
	if not _is_hotseat_game_active():
		return
	if not _hotseat_can_begin_charge():
		return
	hotseat_fire_button_held = true
	hotseat_charge_time = 0.0
	hotseat_charge_percent = HOTSEAT_CHARGE_MIN_PERCENT
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _on_hotseat_fire_button_up() -> void:
	if not _is_hotseat_game_active():
		return
	if hotseat_fire_button_held:
		_release_hotseat_charged_shot()
	hotseat_fire_button_held = false
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _is_hotseat_game_active() -> bool:
	return menu_state == MENU_STATE_GAME and game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME

func _hotseat_can_begin_charge() -> bool:
	return not projectile_active and turn_projectiles.is_empty() and not game_over and not overlay_open

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
		var ratio: float = clampf(hotseat_charge_time / HOTSEAT_CHARGE_TIME_MAX, 0.0, 1.0)
		hotseat_charge_percent = lerpf(HOTSEAT_CHARGE_MIN_PERCENT, HOTSEAT_CHARGE_MAX_PERCENT, ratio)
		power_percent = hotseat_charge_percent
		power = _power_from_percent(power_percent)
		_update_fire_button_charge_style(ratio)
	elif _hotseat_can_begin_charge():
		_update_fire_button_charge_style(0.0)

func _release_hotseat_charged_shot() -> void:
	if not _hotseat_can_begin_charge():
		_reset_hotseat_charge()
		return
	power_percent = clampf(hotseat_charge_percent, HOTSEAT_CHARGE_MIN_PERCENT, HOTSEAT_CHARGE_MAX_PERCENT)
	power = _power_from_percent(power_percent)
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	_on_fire_pressed()
	_reset_hotseat_charge()

func _reset_hotseat_charge() -> void:
	hotseat_charge_time = 0.0
	hotseat_charge_percent = 0.0
	hotseat_fire_button_held = false
	hotseat_keyboard_fire_held = false

func _on_mobile_fire_pressed() -> void:
	if menu_state == MENU_STATE_GAME:
		if mobile_fire_button != null:
			mobile_fire_button.release_focus()
		return
	super._on_mobile_fire_pressed()

func _on_fire_pressed() -> void:
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME:
		super._on_fire_pressed()
		return
	if projectile_active or not turn_projectiles.is_empty() or game_over or overlay_open:
		return
	power_slider.release_focus()
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	turn_projectile_weapon = selected_weapon
	turn_projectile_split_done = false
	turn_cluster_camera_pos = Vector2.INF
	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	projectile_pos = tank_positions[current_player] + muzzle_offset
	projectile_vel = Vector2(facing * power * cos(rad), -power * sin(rad))
	projectile_active = true
	manual_camera_active = false
	_trigger_fire_fx(current_player, angle_deg)

func _split_turn_cluster_projectile(pos: Vector2, vel: Vector2) -> void:
	projectile_active = false
	turn_projectile_split_done = true
	turn_projectiles.clear()
	var spreads: Array[float] = [-CLUSTER_SPLIT_SPREAD_X, 0.0, CLUSTER_SPLIT_SPREAD_X]
	for spread: float in spreads:
		turn_projectiles.append({
			"owner": current_player,
			"weapon": WEAPON_CLUSTER_CHILD,
			"pos": pos,
			"vel": Vector2(vel.x + spread, maxf(absf(vel.y) * 0.35, CLUSTER_SPLIT_SPEED_Y)),
			"center_child": is_zero_approx(spread)
		})
	turn_cluster_camera_pos = pos

func _update_turn_weapon_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	turn_cluster_camera_pos = Vector2.INF
	for shell: Dictionary in turn_projectiles:
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var vel: Vector2 = shell.get("vel", Vector2.ZERO)
		var owner: int = int(shell.get("owner", current_player))
		var weapon: String = str(shell.get("weapon", WEAPON_CLUSTER_CHILD))
		vel.y += gravity * delta
		vel.x += wind * delta
		pos += vel * delta
		if bool(shell.get("center_child", false)):
			turn_cluster_camera_pos = pos
		if _turn_shell_should_explode(owner, pos):
			_explode_turn_weapon(pos, weapon, false)
		else:
			shell["pos"] = pos
			shell["vel"] = vel
			remaining.append(shell)
	turn_projectiles = remaining
	if turn_projectiles.is_empty():
		turn_cluster_camera_pos = Vector2.INF
		if not game_over:
			_advance_turn()

func _update_ui() -> void:
	super._update_ui()
	if _is_hotseat_game_active() and not game_over:
		if hotseat_fire_button_held or hotseat_keyboard_fire_held:
			power_label.text = "Charge: %.0f%%" % hotseat_charge_percent
		else:
			power_label.text = "Hold FIRE"
