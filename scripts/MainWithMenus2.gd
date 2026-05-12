extends "res://scripts/MainWithMenus.gd"

const BUTTON_HOTSEAT_PATH: String = "res://assets/menu/button_hotseat.png"
const BUTTON_ONLINE_PATH: String = "res://assets/menu/button_online.png"

func _on_multiplayer_pressed() -> void:
	_show_multiplayer_menu()

func _show_multiplayer_menu() -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Hotseat", BUTTON_HOTSEAT_PATH, Vector2(0.5, 0.58), Vector2(310, 72), _on_hotseat_pressed)
	_add_menu_button("Online", BUTTON_ONLINE_PATH, Vector2(0.5, 0.69), Vector2(310, 72), _on_online_pressed)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.82), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _on_hotseat_pressed() -> void:
	# Current local two-player mode.
	_start_game(false)

func _on_online_pressed() -> void:
	# Placeholder until networking is implemented.
	menu_state = MENU_STATE_MULTIPLAYER
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label("Online", Vector2(0.5, 0.54), Vector2(420, 60), 28)
	_add_text_label("Coming soon", Vector2(0.5, 0.62), Vector2(420, 44), 20)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.76), Vector2(210, 58), _show_multiplayer_menu)
	queue_redraw()

func reset_match() -> void:
	# Fixes occasional invisible / missing red tank at match start.
	# MainStableTweaks used to randomize active_world_width once before positioning
	# the red tank, then randomize it again inside _generate_random_terrain(). That
	# could leave the red tank off the actual generated map/camera until movement
	# forced a position refresh. Here, terrain generation finalizes the width first;
	# then both tanks are placed and settled against that finalized terrain.
	_hide_overlays()
	current_player = 0
	player_angles = [45.0, 45.0]
	player_power_percents = [POWER_PERCENT_DEFAULT, POWER_PERCENT_DEFAULT]
	player_powers = [_power_from_percent(POWER_PERCENT_DEFAULT), _power_from_percent(POWER_PERCENT_DEFAULT)]
	angle_deg = 45.0
	power_percent = POWER_PERCENT_DEFAULT
	power = _power_from_percent(power_percent)
	power_slider.value = power_percent
	power_slider.release_focus()
	turn_timer = TURN_TIME_LIMIT
	wind = rng.randf_range(-MAX_WIND_ACCEL, MAX_WIND_ACCEL)
	tank_health = [100, 100]
	projectile_active = false
	projectile_pos = Vector2.ZERO
	projectile_vel = Vector2.ZERO
	explosion_pos = Vector2.INF
	explosion_timer = 0.0
	game_over = false
	mobile_left_pressed = false
	mobile_right_pressed = false

	# Temporary valid positions while terrain is generated.
	tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(TANK_START_LEFT_X + 300.0, 0.0)]
	_generate_random_terrain()

	# Place tanks using the finalized active_world_width / active_right_start_x.
	tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(active_right_start_x, 0.0)]
	_settle_tanks_on_terrain()
	camera_x = _camera_target_x()
	queue_redraw()
