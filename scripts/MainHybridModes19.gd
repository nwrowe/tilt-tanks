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

func _generate_random_terrain() -> void:
	terrain_points.clear()
	active_world_width = rng.randf_range(WORLD_WIDTH_MIN_TWEAK, WORLD_WIDTH_MAX_TWEAK)
	active_right_start_x = active_world_width - 130.0
	terrain_points = TerrainManager.generate_varied_terrain(
		rng,
		active_world_width,
		TERRAIN_STEP,
		_bottom_floor_y(),
		VAR_TERRAIN_MIN_Y,
		VAR_TERRAIN_MAX_Y,
		VAR_START_MIN_Y,
		VAR_START_MAX_Y,
		VAR_CONTROL_SPACING_MIN,
		VAR_CONTROL_SPACING_MAX,
		VAR_SLOPE_KICK,
		VAR_DETAIL_WAVE_AMOUNT,
		TANK_START_LEFT_X,
		active_right_start_x,
		54.0
	)
	_refresh_terrain_line()
	_settle_tanks_on_terrain()
	_generate_ponds()

func _generate_ponds() -> void:
	ponds = WaterManager.generate_ponds(
		rng,
		terrain_points,
		active_right_start_x,
		TANK_START_LEFT_X,
		POND_CHANCE,
		POND_ATTEMPTS,
		POND_MIN_WIDTH,
		POND_MAX_WIDTH,
		POND_MIN_DEPTH,
		POND_RIM_SEARCH_RADIUS,
		POND_SURFACE_DROP,
		POND_SPAWN_AVOID_RADIUS,
		TERRAIN_STEP
	)

func _try_find_pond() -> Dictionary:
	return WaterManager.try_find_pond(
		rng,
		terrain_points,
		active_right_start_x,
		TANK_START_LEFT_X,
		POND_MIN_WIDTH,
		POND_MAX_WIDTH,
		POND_MIN_DEPTH,
		POND_RIM_SEARCH_RADIUS,
		POND_SURFACE_DROP,
		POND_SPAWN_AVOID_RADIUS
	)

func _flatten_spawn_area(center_x: float, half_width: float) -> void:
	TerrainManager.flatten_spawn_area(terrain_points, center_x, half_width)

func _refresh_terrain_line() -> void:
	TerrainManager.refresh_terrain_line(terrain, terrain_points)

func _settle_tanks_on_terrain() -> void:
	for player: int in range(tank_positions.size()):
		tank_positions[player].y = _tank_y_for_surface(player, tank_positions[player].x)

func _ground_y_at_x(x: float) -> float:
	return TerrainMath.ground_y_at_x(terrain_points, x, TERRAIN_STEP)

func _bottom_floor_y() -> float:
	return TerrainMath.bottom_floor_y(VIEW_SIZE, CAMERA_Y_OFFSET, CAMERA_SCALE, BOTTOM_FLOOR_SCREEN_MARGIN)

func _terrain_slope_at_x(x: float) -> float:
	return SnowManager.slope_at_x(terrain_points, x, TERRAIN_STEP, active_world_width)

func _is_snow_at_x(x: float) -> bool:
	return SnowManager.is_snow_at_x(terrain_points, x, TERRAIN_STEP, SNOW_LINE_Y)

func _snow_adjusted_direction_and_speed(x: float, input_direction: float, base_speed: float) -> Dictionary:
	return SnowManager.adjusted_direction_and_speed(
		terrain_points,
		x,
		input_direction,
		base_speed,
		TERRAIN_STEP,
		active_world_width,
		SNOW_LINE_Y,
		SNOW_UPHILL_BLOCK_SLOPE,
		SNOW_SLIDE_SLOPE,
		SNOW_SLIDE_SPEED,
		SNOW_DRIVE_MULT,
		SNOW_UPHILL_SLOW_MULT
	)

func _draw_snow_caps() -> void:
	_draw_snow_faces()
	_draw_snow_surface_highlights()

func _draw_snow_faces() -> void:
	for face_data: Dictionary in SnowManager.snow_face_polygons(terrain_points, SNOW_LINE_Y, 0.62):
		var face_world: PackedVector2Array = face_data.get("face", PackedVector2Array())
		var face_screen: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in face_world:
			face_screen.append(_world_to_screen(point))
		if face_screen.size() >= 3:
			draw_colored_polygon(face_screen, Color(0.90, 0.95, 1.0, SNOW_FACE_ALPHA))

		var shadow_world: PackedVector2Array = face_data.get("shadow", PackedVector2Array())
		var shadow_screen: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in shadow_world:
			shadow_screen.append(_world_to_screen(point))
		if shadow_screen.size() >= 3:
			draw_colored_polygon(shadow_screen, Color(0.62, 0.78, 1.0, SNOW_FACE_SHADOW_ALPHA))

func _draw_snow_surface_highlights() -> void:
	for segment_world: Array in SnowManager.snow_segments(terrain_points, SNOW_LINE_Y):
		var segment: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in segment_world:
			segment.append(_world_to_screen(point))
		_draw_snow_highlight_segment(segment)

func _draw_snow_highlight_segment(segment: PackedVector2Array) -> void:
	if segment.size() < 2:
		return
	for i: int in range(segment.size() - 1):
		draw_line(segment[i], segment[i + 1], Color(0.98, 1.0, 1.0, 0.96), 3.5)
		draw_line(segment[i] + Vector2(0, 5), segment[i + 1] + Vector2(0, 5), Color(0.68, 0.82, 1.0, 0.28), 1.5)

func _water_volume_for_range(start_i: int, end_i: int, water_y: float) -> float:
	return WaterManager.water_volume_for_range(terrain_points, start_i, end_i, water_y, TERRAIN_STEP)

func _add_water_volume_to_pond(pond: Dictionary) -> Dictionary:
	return WaterManager.add_volume_to_pond(terrain_points, pond, TERRAIN_STEP)

func _deepest_index_in_range(start_i: int, end_i: int) -> int:
	return TerrainMath.deepest_index_in_range(terrain_points, start_i, end_i)

func _connected_basin_from_valley(valley_i: int, reference_water_y: float) -> Dictionary:
	return WaterManager.connected_basin_from_valley(terrain_points, valley_i, reference_water_y, WATER_CONNECTED_MARGIN)

func _solve_water_level_for_volume(left_i: int, right_i: int, target_volume: float) -> float:
	return WaterManager.solve_water_level_for_volume(terrain_points, left_i, right_i, target_volume, TERRAIN_STEP, WATER_MAX_SURFACE_ITERATIONS)

func _pond_at_x(x: float) -> Dictionary:
	return WaterManager.pond_at_x(ponds, terrain_points, x, TERRAIN_STEP, WATER_MIN_VISIBLE_DEPTH)

func _is_in_pond(pos: Vector2) -> bool:
	return WaterManager.is_in_pond(ponds, terrain_points, pos, TERRAIN_STEP, WATER_MIN_VISIBLE_DEPTH)

func _reflow_single_pond(pond: Dictionary, changed_x: float) -> Dictionary:
	return WaterManager.reflow_single_pond(terrain_points, pond, TERRAIN_STEP, WATER_CONNECTED_MARGIN, WATER_MIN_VISIBLE_DEPTH, WATER_MAX_SURFACE_ITERATIONS)

func _draw_ponds_under_ground() -> void:
	for rect: Dictionary in WaterManager.backing_rects_for_ponds(ponds, terrain_points, _bottom_floor_y()):
		var top_left: Vector2 = _world_to_screen(rect.get("start", Vector2.ZERO))
		var bottom_right: Vector2 = _world_to_screen(rect.get("end", Vector2.ZERO))
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(0.035, 0.22, 0.50, 0.95), true)

func _draw_water_surfaces() -> void:
	for segment: Dictionary in WaterManager.surface_segments_for_ponds(ponds, terrain_points, WATER_MIN_VISIBLE_DEPTH):
		_draw_water_surface_segment_world(segment.get("start", Vector2.ZERO), segment.get("end", Vector2.ZERO))

func _draw_water_surface_segment(start_i: int, end_i: int, water_y: float) -> void:
	if terrain_points.is_empty() or end_i <= start_i:
		return
	var left_i: int = clampi(start_i, 0, terrain_points.size() - 1)
	var right_i: int = clampi(end_i, 0, terrain_points.size() - 1)
	_draw_water_surface_segment_world(Vector2(terrain_points[left_i].x, water_y), Vector2(terrain_points[right_i].x, water_y))

func _draw_water_surface_segment_world(start_world: Vector2, end_world: Vector2) -> void:
	var left: Vector2 = _world_to_screen(start_world)
	var right: Vector2 = _world_to_screen(end_world)
	draw_line(left, right, Color(0.18, 0.66, 1.0, 0.88), 3.0)
	draw_line(left + Vector2(0, 3), right + Vector2(0, 3), Color(0.72, 0.92, 1.0, 0.28), 1.5)

func _apply_crater(pos: Vector2) -> void:
	TerrainManager.apply_crater(terrain_points, pos, CRATER_RADIUS, CRATER_DEPTH, VAR_TERRAIN_MIN_Y, _bottom_floor_y())
	_refresh_terrain_line()
	_reflow_water_after_terrain_change(pos.x)

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

func _draw_ground_fill() -> void:
	if terrain_points.size() < 2:
		return
	var left_screen_x: float = -25.0
	var right_screen_x: float = VIEW_SIZE.x + 25.0
	var left_world_x: float = camera_x + left_screen_x / CAMERA_SCALE
	var right_world_x: float = camera_x + right_screen_x / CAMERA_SCALE

	var surface_points: PackedVector2Array = PackedVector2Array()
	surface_points.append(_world_to_screen(Vector2(left_world_x, _ground_y_at_x(left_world_x))))
	for point: Vector2 in terrain_points:
		if point.x > left_world_x and point.x < right_world_x:
			surface_points.append(_world_to_screen(point))
	surface_points.append(_world_to_screen(Vector2(right_world_x, _ground_y_at_x(right_world_x))))

	if surface_points.size() < 2:
		return
	var bottom_y: float = VIEW_SIZE.y + 100.0
	var polygon: PackedVector2Array = PackedVector2Array()
	polygon.append(Vector2(left_screen_x, bottom_y))
	polygon.append(Vector2(right_screen_x, bottom_y))
	for i: int in range(surface_points.size() - 1, -1, -1):
		polygon.append(surface_points[i])
	if polygon.size() >= 3:
		draw_colored_polygon(polygon, Color(0.13, 0.24, 0.12))

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
