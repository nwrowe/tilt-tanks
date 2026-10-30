extends "res://scripts/Main.gd"

# Compatibility constants and legacy scene fields required by later game
# layers. Gameplay policies already live in separate independent components.

const POWER_FORCE_MIN: float = 400.0
const POWER_FORCE_MAX: float = 1200.0
const POWER_PERCENT_DEFAULT: float = 50.0

var power_percent: float = POWER_PERCENT_DEFAULT
var player_power_percents: Array[float] = [POWER_PERCENT_DEFAULT, POWER_PERCENT_DEFAULT]


const WORLD_WIDTH_MIN_TWEAK: float = 1500.0
const WORLD_WIDTH_MAX_TWEAK: float = 2600.0
const TRAJECTORY_DOT_COUNT: int = 7
const TRAJECTORY_DOT_DT: float = 0.145
const TRAJECTORY_DOT_RADIUS: float = 3.0
const BOTTOM_FLOOR_SCREEN_MARGIN: float = 4.0

var active_world_width: float = 1500.0
var active_right_start_x: float = 1370.0

# -----------------------------------------------------------------------------
# Menu asset paths
# Add your finished art to these paths when ready. The game runs with fallback
# colors/text buttons even before the assets exist.
# -----------------------------------------------------------------------------
const MENU_BG_LANDSCAPE_PATH: String = "res://assets/menu/main_menu_background_landscape.png"
const MENU_BG_PORTRAIT_PATH: String = "res://assets/menu/main_menu_background_portrait.png"
const MENU_LOGO_PATH: String = "res://assets/menu/tilt_tanks_logo.png"

const BUTTON_SINGLE_PLAYER_PATH: String = "res://assets/menu/button_single_player.png"
const BUTTON_MULTIPLAYER_PATH: String = "res://assets/menu/button_multiplayer.png"
const BUTTON_OPTIONS_PATH: String = "res://assets/menu/button_options.png"
const BUTTON_QUICK_GAME_PATH: String = "res://assets/menu/button_quick_game.png"
const BUTTON_CAMPAIGN_PATH: String = "res://assets/menu/button_campaign.png"
const BUTTON_BACK_PATH: String = "res://assets/menu/button_back.png"

const MENU_STATE_MAIN: int = 0
const MENU_STATE_SINGLE_PLAYER: int = 1
const MENU_STATE_OPTIONS: int = 2
const MENU_STATE_MULTIPLAYER: int = 3
const MENU_STATE_GAME: int = 4

var menu_state: int = MENU_STATE_MAIN
var menu_layer: CanvasLayer
var menu_buttons: Array[Control] = []
var menu_view: MainMenuView = MainMenuView.new()
var menu_logo_texture: Texture2D
var menu_bg_landscape_texture: Texture2D
var menu_bg_portrait_texture: Texture2D
var single_player_mode: bool = false

func _ready() -> void:
	rng.randomize()
	if terrain != null:
		terrain.visible = false
	if reset_button != null:
		reset_button.visible = false
		reset_button.focus_mode = Control.FOCUS_NONE
	if fire_button != null:
		fire_button.visible = false
		fire_button.focus_mode = Control.FOCUS_NONE
	if power_slider != null:
		power_slider.min_value = 0.0
		power_slider.max_value = 100.0
		power_slider.step = 1.0
		power_slider.focus_mode = Control.FOCUS_NONE
	_build_overlay_ui()
	reset_match()
	_load_menu_assets()
	_build_menu_layer()
	_show_main_menu()

func _process(delta: float) -> void:
	if menu_state == MENU_STATE_GAME:
		if Input.is_key_pressed(KEY_R):
			reset_match()
	
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			_on_fire_pressed()
	
		if not projectile_active and not game_over and not overlay_open:
			_update_angle_from_input(delta)
			_update_tank_movement(delta)
			if power_slider != null:
				power_percent = float(power_slider.value)
			power = _power_from_percent(power_percent)
			player_angles[current_player] = angle_deg
			player_power_percents[current_player] = power_percent
			player_powers[current_player] = power
			turn_timer -= delta
			if turn_timer <= 0.0:
				_end_turn_without_shot()
	
		if projectile_active:
			_update_projectile(delta)
	
		if explosion_timer > 0.0:
			explosion_timer -= delta
			if explosion_timer <= 0.0:
				explosion_pos = Vector2.INF
	
		_update_camera(delta)
		_update_ui()
		queue_redraw()
	else:
		queue_redraw()

func _draw() -> void:
	if menu_state == MENU_STATE_GAME:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.06, 0.07, 0.10), true)
		_draw_distant_mountains()
		_draw_ground_fill()
		_draw_terrain_outline()
		_draw_tank(0, Color(0.25, 0.9, 0.35))
		_draw_tank(1, Color(0.95, 0.25, 0.25))
		if not game_over:
			_draw_trajectory_preview()
			var base: Vector2 = _world_to_screen(tank_positions[current_player])
			var facing: float = 1.0 if current_player == 0 else -1.0
			var rad: float = deg_to_rad(angle_deg)
			var tip: Vector2 = base + Vector2(facing * CANNON_LENGTH * CAMERA_SCALE * cos(rad), -CANNON_LENGTH * CAMERA_SCALE * sin(rad))
			draw_line(base, tip, Color.WHITE, 4.0)
		if projectile_active:
			draw_circle(_world_to_screen(projectile_pos), PROJECTILE_RADIUS * CAMERA_SCALE, Color(1.0, 0.92, 0.2))
		if explosion_timer > 0.0 and explosion_pos != Vector2.INF:
			_draw_explosion()
		_draw_wind_widget()
		_draw_turn_widget()
		return
	_draw_menu_background()

func _load_menu_assets() -> void:
	menu_view.load_assets(MENU_BG_LANDSCAPE_PATH, MENU_BG_PORTRAIT_PATH, MENU_LOGO_PATH)
	menu_bg_landscape_texture = menu_view.landscape_texture
	menu_bg_portrait_texture = menu_view.portrait_texture
	menu_logo_texture = menu_view.logo_texture

func _load_texture_if_exists(path: String) -> Texture2D:
	return menu_view._load_texture(path)

func _build_menu_layer() -> void:
	menu_view.attach(self)
	menu_layer = menu_view.layer
	menu_buttons = menu_view.controls

func _show_main_menu() -> void:
	menu_state = MENU_STATE_MAIN
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Single Player", BUTTON_SINGLE_PLAYER_PATH, Vector2(0.5, 0.54), Vector2(310, 72), _on_single_player_pressed)
	_add_menu_button("Multiplayer", BUTTON_MULTIPLAYER_PATH, Vector2(0.5, 0.65), Vector2(310, 72), _on_multiplayer_pressed)
	_add_menu_button("Options", BUTTON_OPTIONS_PATH, Vector2(0.5, 0.76), Vector2(310, 72), _on_options_pressed)
	queue_redraw()

func _show_single_player_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Quick Game", BUTTON_QUICK_GAME_PATH, Vector2(0.5, 0.58), Vector2(310, 72), _on_quick_game_pressed)
	_add_menu_button("Campaign", BUTTON_CAMPAIGN_PATH, Vector2(0.5, 0.69), Vector2(310, 72), _on_campaign_pressed)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.82), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _show_placeholder_menu(title: String) -> void:
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label(title, Vector2(0.5, 0.54), Vector2(420, 60), 28)
	_add_text_label("Coming soon", Vector2(0.5, 0.62), Vector2(420, 44), 20)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.76), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _on_single_player_pressed() -> void:
	_show_single_player_menu()

func _on_multiplayer_pressed() -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	_show_placeholder_menu("Multiplayer")

func _on_options_pressed() -> void:
	menu_state = MENU_STATE_OPTIONS
	_show_placeholder_menu("Options")

func _on_campaign_pressed() -> void:
	_show_placeholder_menu("Campaign")

func _on_quick_game_pressed() -> void:
	_start_game(true)

func _start_game(is_single_player: bool) -> void:
	single_player_mode = is_single_player
	_clear_menu_controls()
	menu_state = MENU_STATE_GAME
	_show_game_ui()
	reset_match()
	queue_redraw()

func _hide_game_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = false

func _show_game_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = true

func _clear_menu_controls() -> void:
	menu_view.clear()

func _add_text_label(text: String, anchor: Vector2, size: Vector2, font_size: int) -> Label:
	return menu_view.add_label(get_viewport_rect().size, text, anchor, size, font_size)

func _add_menu_button(text: String, texture_path: String, anchor: Vector2, size: Vector2, callback: Callable) -> Control:
	return menu_view.add_button(get_viewport_rect().size, text, texture_path, anchor, size, callback)

func _style_menu_button(button: Button) -> void:
	menu_view.style_button(button)

func _anchored_position(anchor: Vector2, size: Vector2) -> Vector2:
	return MainMenuPresentation.anchored_position(get_viewport_rect().size, anchor, size)

func _draw_menu_background() -> void:
	menu_view.draw_background(self, get_viewport_rect().size)

func _draw_menu_logo_texture(viewport_size: Vector2, use_landscape: bool) -> void:
	var rect: Rect2 = MainMenuPresentation.logo_rect(
		viewport_size, use_landscape,
		Vector2(float(menu_logo_texture.get_width()), float(menu_logo_texture.get_height()))
	)
	draw_texture_rect(menu_logo_texture, rect, false)

func _draw_fallback_logo(viewport_size: Vector2, use_landscape: bool) -> void:
	var title_y: float = viewport_size.y * (0.14 if use_landscape else 0.11)
	var subtitle_y: float = title_y + 48.0
	draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 95.0, title_y), "TILT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 125.0, subtitle_y), "TANKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1.0, 0.70, 0.08))

func _draw_fallback_menu_background(viewport_size: Vector2) -> void:
	MainMenuPresentation.draw_fallback_background(self, viewport_size)

func _update_angle_from_input(delta: float) -> void:
	var gravity_vec: Vector3 = Input.get_gravity()
	if gravity_vec.length() < 0.01:
		var axis: float = 0.0
		if Input.is_key_pressed(KEY_UP):
			axis += 1.0
		if Input.is_key_pressed(KEY_DOWN):
			axis -= 1.0
		angle_deg = LegacyInputMotionPolicy.keyboard_aim(
			angle_deg, axis, delta, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE
		)
	else:
		angle_deg = LegacyInputMotionPolicy.tilt_aim(
			gravity_vec.x, current_player, MOBILE_TILT_FULL_SCALE,
			MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE
		)

func _camera_target_x() -> float:
	return LegacyInputMotionPolicy.camera_x(
		tank_positions[current_player].x, projectile_active, projectile_pos.x,
		explosion_timer, explosion_pos, VIEW_SIZE.x, CAMERA_SCALE,
		active_world_width
	)

func _power_from_percent(percent: float) -> float:
	return PowerControlPolicy.force_from_percent(percent, POWER_FORCE_MIN, POWER_FORCE_MAX)

func _on_fire_pressed() -> void:
	if projectile_active or game_over or overlay_open:
		return
	if power_slider != null:
		power_slider.release_focus()
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	var facing: float = 1.0
	if current_player != 0:
		facing = -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	projectile_pos = tank_positions[current_player] + muzzle_offset
	projectile_vel = Vector2(facing * power * cos(rad), -power * sin(rad))
	projectile_active = true

func _load_current_player_settings() -> void:
	angle_deg = player_angles[current_player]
	power_percent = player_power_percents[current_player]
	power = _power_from_percent(power_percent)
	if power_slider != null:
		power_slider.value = power_percent
		power_slider.release_focus()

func _update_ui() -> void:
	if angle_label != null:
		angle_label.text = "Angle: %.1f" % angle_deg
	if power_label != null:
		power_label.text = "Power: %.0f%%" % power_percent
	if status_label == null:
		return
	if game_over:
		var winner: int = 0
		if tank_health[0] <= 0:
			winner = 1
		status_label.text = "Player %d wins!  P1 HP: %d  P2 HP: %d" % [winner + 1, tank_health[0], tank_health[1]]
	else:
		status_label.text = "P1 HP: %d    P2 HP: %d" % [tank_health[0], tank_health[1]]

func _draw_distant_mountains() -> void:
	LegacyBackdropRenderer.draw_distant_mountains(self, VIEW_SIZE)

# Required compatibility method for lower ancestor compile-time dispatch.
func _bottom_floor_y() -> float:
	return (VIEW_SIZE.y - CAMERA_Y_OFFSET) / CAMERA_SCALE - BOTTOM_FLOOR_SCREEN_MARGIN

# Required compatibility method for lower ancestor compile-time dispatch.
func _draw_trajectory_preview() -> void:
	if projectile_active or game_over:
		return
	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var pos: Vector2 = tank_positions[current_player] + muzzle_offset
	var vel: Vector2 = Vector2(facing * power * cos(rad), -power * sin(rad))
	for i: int in range(1, TRAJECTORY_DOT_COUNT + 1):
		vel.y += gravity * TRAJECTORY_DOT_DT
		vel.x += wind * TRAJECTORY_DOT_DT
		pos += vel * TRAJECTORY_DOT_DT
		if pos.x < 0.0 or pos.x > active_world_width or pos.y >= _ground_y_at_x(pos.x):
			break
		var alpha: float = 0.55 * (1.0 - float(i - 1) / float(TRAJECTORY_DOT_COUNT))
		draw_circle(_world_to_screen(pos), TRAJECTORY_DOT_RADIUS, Color(1.0, 1.0, 1.0, alpha))
