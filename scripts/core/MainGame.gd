extends "res://scripts/weapons/WeaponRuntimeBridge.gd"

# CLEAN ACTIVE ENTRY POINT
# ------------------------
# MainGame.gd is now the active gameplay facade. MainHybridModes19, 18, 17,
# and 16 have been inlined here. The remaining inherited compatibility chain
# is intentionally removed in smaller follow-up passes.

const ACTIVE_BUILD_NAME: String = "MainGame refactor facade"

const MENU_PANEL_BUTTON_X: float = 16.0
const MENU_PANEL_BUTTON_W: float = 198.0
const MENU_PANEL_BUTTON_H: float = 36.0
const MENU_PANEL_START_Y: float = 46.0
const MENU_PANEL_GAP_Y: float = 46.0

const CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION: float = 0.85

const HOTSEAT_CHARGE_TIME_MAX: float = 1.65
const HOTSEAT_CHARGE_MIN_PERCENT: float = 10.0
const HOTSEAT_CHARGE_MAX_PERCENT: float = 100.0
const PAN_RELEASE_HOLD_TIME: float = 1.4

const MUZZLE_RECOIL_TIME: float = 0.18
const MUZZLE_RECOIL_DISTANCE: float = 13.0
const MUZZLE_SMOKE_LIFETIME: float = 0.55
const MUZZLE_SMOKE_RISE_SPEED: float = 26.0
const MUZZLE_SMOKE_DRIFT_SPEED: float = 18.0
const MUZZLE_SMOKE_START_RADIUS: float = 3.0
const MUZZLE_SMOKE_END_RADIUS: float = 10.0

# Compatibility references for older runtime code, modes and networking.
# The session remains the owner; methods below keep aliases synchronized.
var weapon_definitions: Dictionary = weapon_definition_session.definitions
var active_weapon_loadout: WeaponLoadout = weapon_definition_session.loadout

var match_state: MatchState = MatchState.new()
var match_controller: MatchController = MatchController.new(match_state)
var match_runtime_sync: MatchRuntimeSynchronizer = MatchRuntimeSynchronizer.new(match_controller)

var realtime_cluster_focus_count: int = 0
var realtime_cluster_focus_pos: Vector2 = Vector2.INF
var suppress_next_outside_close: bool = false
var hotseat_release_in_progress: bool = false

var cluster_camera_hold_timer: float = 0.0
var cluster_camera_hold_pos: Vector2 = Vector2.INF

var hotseat_fire_button_held: bool = false
var hotseat_keyboard_fire_held: bool = false
var hotseat_charge_time: float = 0.0
var hotseat_charge_percent: float = 0.0
var swipe_panning: bool = false
var manual_camera_active: bool = false
var manual_camera_timer: float = 0.0
var turn_cluster_camera_pos: Vector2 = Vector2.INF

var barrel_recoil_timers: Array[float] = [0.0, 0.0]
var barrel_recoil_angles: Array[float] = [45.0, 45.0]
var muzzle_smoke_puffs: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	if mobile_fire_button != null:
		if not mobile_fire_button.button_down.is_connected(_on_hotseat_fire_button_down):
			mobile_fire_button.button_down.connect(_on_hotseat_fire_button_down)
		if not mobile_fire_button.button_up.is_connected(_on_hotseat_fire_button_up):
			mobile_fire_button.button_up.connect(_on_hotseat_fire_button_up)
	_update_power_slider_visibility()
	_add_true_quit_button()
	_relayout_three_line_menu()
	print("Tilt Tanks active script: %s" % ACTIVE_BUILD_NAME)

func reset_match() -> void:
	realtime_cluster_focus_count = 0
	realtime_cluster_focus_pos = Vector2.INF
	suppress_next_outside_close = false
	cluster_camera_hold_timer = 0.0
	cluster_camera_hold_pos = Vector2.INF
	hotseat_fire_button_held = false
	hotseat_keyboard_fire_held = false
	hotseat_charge_time = 0.0
	hotseat_charge_percent = 0.0
	manual_camera_active = false
	manual_camera_timer = 0.0
	turn_cluster_camera_pos = Vector2.INF
	barrel_recoil_timers = [0.0, 0.0]
	barrel_recoil_angles = [45.0, 45.0]
	muzzle_smoke_puffs.clear()
	# Retains the former weapon-definition bridge reset guard before base reset.
	selected_weapon = _safe_selected_weapon(selected_weapon)
	super.reset_match()
	_initialize_match_controller_from_runtime_reset()
	_sync_match_state_from_runtime()
	_update_power_slider_visibility()
	_relayout_three_line_menu()

func _process(delta: float) -> void:
	if cluster_camera_hold_timer > 0.0:
		cluster_camera_hold_timer = maxf(0.0, cluster_camera_hold_timer - delta)
		if cluster_camera_hold_timer <= 0.0:
			cluster_camera_hold_pos = Vector2.INF
	_update_hotseat_charge(delta)
	if manual_camera_active:
		manual_camera_timer = maxf(0.0, manual_camera_timer - delta)
		if manual_camera_timer <= 0.0:
			manual_camera_active = false
	super._process(delta)
	_sync_match_state_from_runtime()
	_update_muzzle_effects(delta)

func _show_game_ui() -> void:
	super._show_game_ui()
	_update_power_slider_visibility()

func _update_power_slider_visibility() -> void:
	if menu_state == MENU_STATE_GAME:
		if power_slider != null:
			power_slider.visible = false
		if power_label != null:
			power_label.visible = true

# UI facade formerly in MainHybridModes19.gd

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
		_on_mobile_fire_pressed()
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

	var end_main_menu_button: Button = EndPopup.make_main_menu_button(end_panel)
	end_main_menu_button.pressed.connect(_return_to_main_menu)

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
	return

func _relabel_quit_buttons() -> void:
	return

func _add_true_quit_button() -> void:
	if menu_panel == null:
		return
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
	if menu_state != MENU_STATE_GAME or overlay_open:
		super._unhandled_input(event)
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

func _apply_camera_pan_delta(screen_dx: float) -> void:
	if absf(screen_dx) < 0.01:
		return
	var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
	camera_x = clampf(camera_x - screen_dx / CAMERA_SCALE, 0.0, maxf(0.0, active_world_width - camera_world_width))
	manual_camera_active = true
	manual_camera_timer = PAN_RELEASE_HOLD_TIME
	queue_redraw()

# Terrain/water/snow facade formerly in MainHybridModes19.gd

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

func _tank_y_for_surface(player: int, x: float) -> float:
	return WaterManager.tank_y_for_surface(ponds, terrain_points, x, TERRAIN_STEP, TANK_RADIUS, WATER_MIN_VISIBLE_DEPTH, WATER_FLOAT_TANK_SUBMERGENCE)

func _movement_speed_mult_at_x(x: float) -> float:
	return WaterManager.movement_speed_mult_at_x(ponds, terrain_points, x, TERRAIN_STEP, WATER_MIN_VISIBLE_DEPTH, WATER_DRIVE_SPEED_MULT)

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

func _draw_ground_fill() -> void:
	var polygon_world: PackedVector2Array = TerrainManager.ground_fill_polygon_world(
		terrain_points,
		camera_x,
		CAMERA_SCALE,
		VIEW_SIZE.x,
		VIEW_SIZE.y,
		TERRAIN_STEP,
		-25.0,
		VIEW_SIZE.x + 25.0,
		_bottom_floor_y() + 260.0
	)
	if polygon_world.size() < 3:
		return
	var polygon_screen: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon_world:
		polygon_screen.append(_world_to_screen(point))
	draw_colored_polygon(polygon_screen, Color(0.13, 0.24, 0.12))

func _draw_terrain_outline() -> void:
	var outline_world: PackedVector2Array = TerrainManager.terrain_outline_world(
		terrain_points,
		camera_x,
		CAMERA_SCALE,
		VIEW_SIZE.x,
		TERRAIN_STEP,
		-25.0,
		VIEW_SIZE.x + 25.0
	)
	if outline_world.size() < 2:
		return
	var outline_screen: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in outline_world:
		outline_screen.append(_world_to_screen(point))
	draw_polyline(outline_screen, Color(0.28, 0.82, 0.35), 3.0)

# Mode facade

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

	if HotseatMode.can_begin_keyboard_charge(keyboard_down, hotseat_keyboard_fire_held, projectile_active, turn_projectiles, game_over, overlay_open):
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

	if HotseatMode.should_release_keyboard_charge(keyboard_down, hotseat_keyboard_fire_held):
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
	if _is_hotseat_game_active() and not hotseat_release_in_progress:
		return
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

func _update_realtime_fire_charge(delta: float) -> void:
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME or menu_state != MENU_STATE_GAME:
		return

	var keyboard_down: bool = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)

	if RealtimeSinglePlayerMode.can_begin_fire_charge(keyboard_down, rt_keyboard_fire_held, rt_player_shell_active, game_over, overlay_open):
		rt_keyboard_fire_held = true
		rt_fire_charge_time = 0.0
		rt_fire_charge_percent = RT_CHARGE_MIN_PERCENT
	elif RealtimeSinglePlayerMode.should_release_fire_charge(keyboard_down, rt_keyboard_fire_held):
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

	if _is_hotseat_game_active() and not game_over:
		if hotseat_fire_button_held or hotseat_keyboard_fire_held:
			power_label.text = "Charge: %.0f%%" % hotseat_charge_percent
		else:
			power_label.text = "Hold FIRE"
	elif game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME and not game_over:
		power_label.text = RealtimeSinglePlayerMode.shell_status_label(
			rt_player_shell_active,
			rt_fire_button_held or rt_keyboard_fire_held,
			rt_fire_charge_percent,
			0.0
		)

# Effects facade

func _update_muzzle_effects(delta: float) -> void:
	for i: int in range(barrel_recoil_timers.size()):
		barrel_recoil_timers[i] = maxf(0.0, barrel_recoil_timers[i] - delta)
	muzzle_smoke_puffs = EffectsManager.update_rising_puffs(muzzle_smoke_puffs, delta, MUZZLE_SMOKE_RISE_SPEED)
	if not muzzle_smoke_puffs.is_empty():
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
		muzzle_smoke_puffs.append(EffectsManager.make_puff(
			tip + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0)),
			MUZZLE_SMOKE_LIFETIME,
			rng.randf_range(-MUZZLE_SMOKE_DRIFT_SPEED, MUZZLE_SMOKE_DRIFT_SPEED)
		))

func _spawn_steam_puff() -> void:
	var base_pos: Vector2 = tank_positions[HUMAN_PLAYER_INDEX]
	var offset: Vector2 = Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-33.0, -22.0))
	steam_puffs.append(EffectsManager.make_puff(
		base_pos + offset,
		STEAM_PUFF_LIFETIME,
		rng.randf_range(-STEAM_PUFF_DRIFT_SPEED, STEAM_PUFF_DRIFT_SPEED)
	))

func _draw() -> void:
	super._draw()
	_draw_recoil_barrels()
	_draw_muzzle_smoke_puffs()
	_draw_turn_cluster_projectiles()

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
		draw_line(base, full_tip, Color(0.08, 0.09, 0.10, 0.96), 6.0)
		draw_line(base, recoil_tip, Color.WHITE, 4.0)

func _draw_muzzle_smoke_puffs() -> void:
	for puff: Dictionary in muzzle_smoke_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", MUZZLE_SMOKE_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, MUZZLE_SMOKE_START_RADIUS, MUZZLE_SMOKE_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.46)
		draw_circle(_world_to_screen(pos), radius, Color(0.82, 0.84, 0.80, alpha))

func _draw_steam_puffs() -> void:
	for puff: Dictionary in steam_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", STEAM_PUFF_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, STEAM_PUFF_START_RADIUS, STEAM_PUFF_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.52)
		draw_circle(_world_to_screen(pos), radius, Color(0.88, 0.90, 0.86, alpha))

# Weapon lookup facade


# Projectile extraction facade

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

func _explode_turn_weapon(pos: Vector2, weapon: String, advance_after: bool) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = EXPLOSION_DURATION
	last_explosion_visual_radius = _weapon_explosion_radius(weapon)
	_apply_weapon_crater(pos, weapon)
	_apply_weapon_damage(pos, weapon)
	_settle_tanks_on_terrain()
	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
		_show_end_popup()
	elif advance_after:
		cluster_camera_hold_pos = pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		_advance_turn()

func _draw_turn_cluster_projectiles() -> void:
	for shell: Dictionary in turn_projectiles:
		var weapon: String = str(shell.get("weapon", WEAPON_CLUSTER_CHILD))
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var radius: float = PROJECTILE_RADIUS * CAMERA_SCALE
		if weapon == WEAPON_CLUSTER_CHILD:
			radius *= 0.78
		elif weapon == WEAPON_HEAVY:
			radius *= 1.45
		draw_circle(_world_to_screen(pos), radius, Color(1.0, 0.92, 0.20))

func _camera_target_x() -> float:
	if manual_camera_active and not projectile_active and turn_projectiles.is_empty() and rt_projectiles.is_empty():
		return camera_x
	if realtime_cluster_focus_pos != Vector2.INF:
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(realtime_cluster_focus_pos.x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	if turn_cluster_camera_pos != Vector2.INF:
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(turn_cluster_camera_pos.x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	if cluster_camera_hold_pos != Vector2.INF and cluster_camera_hold_timer > 0.0:
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(cluster_camera_hold_pos.x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	return super._camera_target_x()

# Existing gameplay callbacks remain on the game node; pure state sync
# and combat transitions are owned by MatchRuntimeSynchronizer/MatchController.
func _advance_turn() -> void:
	_sync_match_state_from_runtime()
	match_controller.advance_turn(TURN_TIME_LIMIT)
	_apply_post_turn_match_state()

func _end_turn_without_shot() -> void:
	_sync_match_state_from_runtime()
	_save_runtime_current_player_settings()
	match_controller.complete_turn_without_shot(
		TURN_TIME_LIMIT, angle_deg, power,
		power_percent if "power_percent" in self else 0.0
	)
	_apply_post_turn_match_state()

func _explode(pos: Vector2) -> void:
	super._explode(pos)
	_sync_match_state_from_runtime()

func _apply_explosion_damage(pos: Vector2) -> void:
	# Classic explosions previously used the base script's direct/splash loop.
	# The controller now applies that same six-HP-minimum profile to its state.
	_apply_controller_radial_damage(
		pos, DIRECT_HIT_RADIUS, EXPLOSION_RADIUS,
		DIRECT_HIT_DAMAGE, MAX_SPLASH_DAMAGE, 6
	)

func _apply_weapon_damage(pos: Vector2, weapon: String) -> void:
	# Registry-defined weapon stats use the original four-HP splash floor.
	_apply_controller_radial_damage(
		pos, _weapon_direct_radius(weapon), _weapon_explosion_radius(weapon),
		_weapon_direct_damage(weapon), _weapon_splash_damage(weapon), 4
	)

func _apply_controller_radial_damage(
	pos: Vector2,
	direct_radius: float,
	blast_radius: float,
	direct_damage: int,
	splash_damage: int,
	minimum_splash: int
) -> void:
	tank_health = match_runtime_sync.apply_radial_damage(
		tank_health, tank_positions, pos, direct_radius, blast_radius,
		direct_damage, splash_damage, minimum_splash
	)
	_sync_game_over_state_from_match_controller()

func _initialize_match_controller_from_runtime_reset() -> void:
	var default_angle: float = angle_deg
	var default_power: float = power
	var default_power_percent: float = power_percent if "power_percent" in self else 50.0
	var mode: int = game_mode if "game_mode" in self else 0
	var world_width: float = active_world_width if "active_world_width" in self else WORLD_WIDTH
	var left_start: Vector2 = tank_positions[0] if tank_positions.size() > 0 else Vector2.ZERO
	var right_start: Vector2 = tank_positions[1] if tank_positions.size() > 1 else Vector2.ZERO
	match_runtime_sync.start_match(
		mode,
		world_width,
		TURN_TIME_LIMIT,
		default_angle,
		default_power,
		default_power_percent,
		left_start,
		right_start,
		wind
	)

func _apply_post_turn_match_state() -> void:
	_apply_match_state_to_runtime_basics()
	_load_current_player_settings()
	_clear_turn_input_state()
	_sync_match_state_from_runtime()

func _clear_turn_input_state() -> void:
	mobile_left_pressed = false
	mobile_right_pressed = false
	if mobile_left_button != null:
		mobile_left_button.release_focus()
	if mobile_right_button != null:
		mobile_right_button.release_focus()

func _save_runtime_current_player_settings() -> void:
	if current_player < 0 or current_player >= player_angles.size():
		return
	player_angles[current_player] = angle_deg
	player_powers[current_player] = power
	if "player_power_percents" in self:
		player_power_percents[current_player] = power_percent

func _sync_projectile_state_to_match_controller() -> void:
	# Legacy physics still advances the projectile in game runtime; the
	# controller owns how a complete frame changes MatchState lifecycle.
	match_runtime_sync.sync_projectile(
		projectile_active, projectile_pos, projectile_vel,
		explosion_pos, explosion_timer
	)

func _sync_health_state_to_match_controller() -> void:
	# Transfer the runtime health values as one transaction. The controller
	# computes game-over/winner only after both tank values have been updated.
	match_runtime_sync.sync_health(tank_health)
	_sync_game_over_state_from_match_controller()

func _sync_game_over_state_from_match_controller() -> void:
	game_over = match_state.game_over
	# Keep the runtime health array as the rendering/UI source during transition.
	# The controller owns winner detection, while the existing UI still reads
	# game_over and tank_health directly.

func _sync_match_state_from_runtime() -> void:
	var frame_percents: Array[float] = player_power_percents if "player_power_percents" in self else match_state.player_power_percents
	var mode: int = game_mode if "game_mode" in self else 0
	var world_width: float = active_world_width if "active_world_width" in self else WORLD_WIDTH
	game_over = match_runtime_sync.sync_frame(
		current_player, tank_positions, player_angles, player_powers,
		frame_percents, wind, turn_timer, mode, world_width,
		projectile_active, projectile_pos, projectile_vel,
		explosion_pos, explosion_timer, tank_health
	)

func _apply_match_state_to_runtime_basics() -> void:
	current_player = match_state.current_player
	turn_timer = match_state.turn_timer
	wind = match_state.wind
	game_over = match_state.game_over
	if match_state.tank_positions.size() == tank_positions.size():
		tank_positions = match_state.tank_positions.duplicate()
	if match_state.tank_health.size() == tank_health.size():
		tank_health = match_state.tank_health.duplicate()
	if match_state.player_angles.size() == player_angles.size():
		player_angles = match_state.player_angles.duplicate()
	if match_state.player_powers.size() == player_powers.size():
		player_powers = match_state.player_powers.duplicate()
	if "player_power_percents" in self and match_state.player_power_percents.size() == player_power_percents.size():
		player_power_percents = match_state.player_power_percents.duplicate()

func _apply_match_projectile_state_to_runtime() -> void:
	projectile_active = match_state.projectile_active
	projectile_pos = match_state.projectile_pos
	projectile_vel = match_state.projectile_vel
	explosion_pos = match_state.explosion_pos
	explosion_timer = match_state.explosion_timer

# Weapon registry / loadout compatibility API: policy is composed, not inherited.
func _set_active_weapon_loadout(loadout: WeaponLoadout) -> void:
	if not weapon_definition_session.set_loadout(loadout):
		return
	active_weapon_loadout = weapon_definition_session.loadout
	selected_weapon = _safe_selected_weapon(selected_weapon)

func _reset_default_weapon_loadout() -> void:
	weapon_definition_session.reset_default()
	active_weapon_loadout = weapon_definition_session.loadout
	selected_weapon = _safe_selected_weapon(selected_weapon)

func _safe_selected_weapon(weapon: String) -> String:
	return weapon_definition_session.safe_weapon(weapon)

func _weapon_definition(weapon: String) -> WeaponDefinition:
	return weapon_definition_session.definition(weapon)

func _weapon_display_name(weapon: String) -> String:
	return weapon_definition_session.display_name(weapon)

func _weapon_split_behavior(weapon: String) -> String:
	return weapon_definition_session.split_behavior(weapon)

func _weapon_child_id(weapon: String) -> String:
	return weapon_definition_session.child_id(weapon)

func _weapon_child_count(weapon: String) -> int:
	return weapon_definition_session.child_count(weapon)

func _weapon_has_split_behavior(weapon: String) -> bool:
	return weapon_definition_session.has_split_behavior(weapon)

func _weapon_should_split_on_descent(weapon: String, split_done: bool, vel: Vector2) -> bool:
	return weapon_definition_session.should_split_on_descent(weapon, split_done, vel)

func _make_split_children(owner: int, weapon: String, pos: Vector2, vel: Vector2) -> Array[Dictionary]:
	return weapon_definition_session.make_split_children(
		owner, weapon, pos, vel, CLUSTER_SPLIT_SPREAD_X, CLUSTER_SPLIT_SPEED_Y
	)
