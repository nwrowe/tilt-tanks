extends "res://scripts/MainHybridModes18.gd"

const MENU_PANEL_BUTTON_X: float = 16.0
const MENU_PANEL_BUTTON_W: float = 198.0
const MENU_PANEL_BUTTON_H: float = 36.0
const MENU_PANEL_START_Y: float = 46.0
const MENU_PANEL_GAP_Y: float = 46.0

var realtime_cluster_focus_count: int = 0
var realtime_cluster_focus_pos: Vector2 = Vector2.INF
var suppress_next_outside_close: bool = false

func _ready() -> void:
	super._ready()
	_relayout_three_line_menu()

func reset_match() -> void:
	realtime_cluster_focus_count = 0
	realtime_cluster_focus_pos = Vector2.INF
	suppress_next_outside_close = false
	super.reset_match()
	_relayout_three_line_menu()

func _style_mobile_button(button: Button) -> void:
	MobileControls.style_mobile_button(button)

func _make_button(text: String, pos: Vector2, size: Vector2, parent: Node) -> Button:
	return MobileControls.make_button(text, pos, size, parent)

func _build_overlay_ui() -> void:
	menu_button = MobileControls.make_menu_button(ui_layer)
	menu_button.pressed.connect(_toggle_menu)

	mobile_left_button = MobileControls.make_left_button(ui_layer)
	mobile_right_button = MobileControls.make_right_button(ui_layer)
	mobile_fire_button = MobileControls.make_fire_button(ui_layer)

	mobile_left_button.button_down.connect(func() -> void:
		mobile_left_pressed = true
	)
	mobile_left_button.button_up.connect(func() -> void:
		mobile_left_pressed = false
		mobile_left_button.release_focus()
	)

	mobile_right_button.button_down.connect(func() -> void:
		mobile_right_pressed = true
	)
	mobile_right_button.button_up.connect(func() -> void:
		mobile_right_pressed = false
		mobile_right_button.release_focus()
	)

	mobile_fire_button.pressed.connect(func() -> void:
		mobile_fire_button.release_focus()
		_on_fire_pressed()
	)

	menu_panel = Panel.new()
	menu_panel.visible = false
	menu_panel.position = Vector2(640, 58)
	menu_panel.size = Vector2(230, 145)
	ui_layer.add_child(menu_panel)

	var menu_title: Label = Label.new()
	menu_title.text = "Menu"
	menu_title.position = Vector2(16, 12)
	menu_title.size = Vector2(180, 24)
	menu_panel.add_child(menu_title)

	var rematch_button: Button = MobileControls.make_button("Rematch", Vector2(16, 46), Vector2(198, 36), menu_panel)
	rematch_button.pressed.connect(reset_match)

	var main_menu_button: Button = MobileControls.make_button("Main Menu", Vector2(16, 92), Vector2(198, 36), menu_panel)
	main_menu_button.pressed.connect(_return_to_main_menu)

	end_panel = EndPopup.make_panel(ui_layer)
	end_label = EndPopup.make_label(end_panel)

	var end_rematch_button: Button = EndPopup.make_rematch_button(end_panel)
	end_rematch_button.pressed.connect(reset_match)

	var end_quit_button: Button = EndPopup.make_quit_button(end_panel)
	end_quit_button.pressed.connect(func() -> void:
		get_tree().quit()
	)

func _make_weapon_menu_button(text: String, pos: Vector2) -> Button:
	return WeaponSelectMenu.make_option_button(weapon_panel, text, pos)

func _build_weapon_ui() -> void:
	weapon_button = WeaponSelectMenu.make_weapon_button(ui_layer)
	weapon_button.pressed.connect(_toggle_weapon_menu)

	weapon_panel = WeaponSelectMenu.make_panel(ui_layer)
	WeaponSelectMenu.add_title(weapon_panel)

	var standard_button: Button = WeaponSelectMenu.make_option_button(weapon_panel, "Standard Shell", Vector2(42, 66))
	standard_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_STANDARD
		_close_weapon_menu()
	)

	var heavy_button: Button = WeaponSelectMenu.make_option_button(weapon_panel, "Heavy Shell", Vector2(42, 120))
	heavy_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_HEAVY
		_close_weapon_menu()
	)

	var cluster_button: Button = WeaponSelectMenu.make_option_button(weapon_panel, "Cluster Bomb", Vector2(42, 174))
	cluster_button.pressed.connect(func() -> void:
		selected_weapon = WEAPON_CLUSTER
		_close_weapon_menu()
	)

	var close_button: Button = WeaponSelectMenu.make_back_button(weapon_panel, Vector2(86, 232))
	close_button.pressed.connect(_close_weapon_menu)

func _add_main_menu_controls() -> void:
	# The active overlay builder already creates the Main Menu button. Keep this
	# override as a no-op because an inherited _ready() still calls it.
	return

func _relabel_quit_buttons() -> void:
	# Legacy builds used this to turn old Quit buttons into Main Menu buttons.
	# The active builder now creates Main Menu explicitly and adds real Quit
	# separately, so relabeling would create duplicate overlapping labels.
	return

func _add_true_quit_button() -> void:
	if menu_panel == null:
		return
	# Avoid duplicates if a parent already created the button.
	for child: Node in menu_panel.get_children():
		if child is Button and (child as Button).text == "Quit":
			return
	var quit_button: Button = PauseMenu.make_quit_button(menu_panel)
	quit_button.pressed.connect(func() -> void:
		get_tree().quit()
	)

func _relayout_three_line_menu() -> void:
	if menu_panel == null:
		return
	var buttons_by_label: Dictionary = {}
	for child: Node in menu_panel.get_children():
		if child is Button:
			var button: Button = child as Button
			if button.text in ["Rematch", "Main Menu", "Quit"] and not buttons_by_label.has(button.text):
				buttons_by_label[button.text] = button
	var desired_order: Array[String] = ["Rematch", "Main Menu", "Quit"]
	var y: float = MENU_PANEL_START_Y
	for label: String in desired_order:
		if buttons_by_label.has(label):
			var button: Button = buttons_by_label[label] as Button
			button.position = Vector2(MENU_PANEL_BUTTON_X, y)
			button.size = Vector2(MENU_PANEL_BUTTON_W, MENU_PANEL_BUTTON_H)
			y += MENU_PANEL_GAP_Y
	menu_panel.size = Vector2(230.0, y + 12.0)

func _toggle_menu() -> void:
	if game_over:
		return
	if menu_button != null:
		menu_button.release_focus()
	if weapon_menu_open:
		_close_weapon_menu()
	if menu_panel == null:
		return
	menu_panel.visible = not menu_panel.visible
	overlay_open = (menu_panel != null and menu_panel.visible) or (weapon_panel != null and weapon_panel.visible) or (end_panel != null and end_panel.visible)
	_relayout_three_line_menu()

func _toggle_weapon_menu() -> void:
	if game_over:
		return
	if weapon_button != null:
		weapon_button.release_focus()
	if menu_panel != null and menu_panel.visible:
		menu_panel.visible = false
	if weapon_menu_open:
		_close_weapon_menu()
	else:
		_open_weapon_menu()
	overlay_open = (menu_panel != null and menu_panel.visible) or (weapon_panel != null and weapon_panel.visible) or (end_panel != null and end_panel.visible)

func _unhandled_input(event: InputEvent) -> void:
	if _handle_outside_menu_tap(event):
		return
	super._unhandled_input(event)

func _handle_outside_menu_tap(event: InputEvent) -> bool:
	if menu_state != MENU_STATE_GAME:
		return false
	var click_pos: Vector2 = Vector2.INF
	var is_press: bool = false
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		is_press = touch.pressed
		click_pos = touch.position
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		is_press = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		click_pos = mb.position
	if not is_press:
		return false
	var closed_any: bool = false
	if menu_panel != null and menu_panel.visible and not _point_inside_control(menu_panel, click_pos) and not _point_inside_control(menu_button, click_pos):
		menu_panel.visible = false
		closed_any = true
	if weapon_panel != null and weapon_panel.visible and not _point_inside_control(weapon_panel, click_pos) and not _point_inside_control(weapon_button, click_pos):
		weapon_menu_open = false
		weapon_panel.visible = false
		closed_any = true
	if closed_any:
		overlay_open = (menu_panel != null and menu_panel.visible) or (weapon_panel != null and weapon_panel.visible) or (end_panel != null and end_panel.visible)
		return true
	return false

func _point_inside_control(control: Control, point: Vector2) -> bool:
	if control == null or not control.visible:
		return false
	var rect: Rect2 = Rect2(control.global_position, control.size)
	return rect.has_point(point)

func _camera_target_x() -> float:
	if realtime_cluster_focus_pos != Vector2.INF:
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(realtime_cluster_focus_pos.x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	return super._camera_target_x()

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

func _update_all_realtime_projectiles(delta: float) -> void:
	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var cluster_focus_sum: Vector2 = Vector2.ZERO
	var cluster_focus_n: int = 0
	var had_cluster_children: bool = false
	var last_cluster_explosion: Vector2 = Vector2.INF

	for shell: Dictionary in rt_projectiles:
		var owner: int = int(shell.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(shell.get("weapon", WEAPON_STANDARD))
		var split_done: bool = bool(shell.get("split", false))
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var vel: Vector2 = shell.get("vel", Vector2.ZERO)
		vel.y += gravity * delta
		vel.x += wind * delta
		pos += vel * delta

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
			shell["pos"] = pos
			shell["vel"] = vel
			remaining.append(shell)
			if weapon == WEAPON_CLUSTER_CHILD:
				had_cluster_children = true
				cluster_focus_sum += pos
				cluster_focus_n += 1

	rt_projectiles = remaining
	rt_player_shell_active = _has_active_realtime_shell_for_owner(HUMAN_PLAYER_INDEX)

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
