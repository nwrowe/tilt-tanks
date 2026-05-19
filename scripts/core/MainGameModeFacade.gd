extends "res://scripts/core/MainGameDefinitionFacade.gd"

# Top-level Phase C facade. This starts routing mode policy through explicit
# ModeController objects while preserving the existing gameplay implementation.

var mode_controllers: Dictionary = {}
var hotseat_mode_controller: HotseatModeController = HotseatModeController.new()
var realtime_mode_controller: RealtimeSinglePlayerModeController = RealtimeSinglePlayerModeController.new()

func _ready() -> void:
	_initialize_mode_controllers()
	super._ready()

func _initialize_mode_controllers() -> void:
	mode_controllers = ModeControllerRegistry.build_default_controllers(self, match_controller)
	hotseat_mode_controller = ModeControllerRegistry.controller_for_name(
		mode_controllers,
		ModeControllerRegistry.MODE_HOTSEAT
	) as HotseatModeController
	realtime_mode_controller = ModeControllerRegistry.controller_for_name(
		mode_controllers,
		ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER
	) as RealtimeSinglePlayerModeController

func _is_hotseat_game_active() -> bool:
	return hotseat_mode_controller.is_active(menu_state, game_mode, MENU_STATE_GAME, GAME_MODE_SINGLE_PLAYER_REALTIME)

func _hotseat_can_begin_charge() -> bool:
	return hotseat_mode_controller.can_begin_charge(projectile_active, turn_projectiles, game_over, overlay_open)

func _draw_turn_widget() -> void:
	if game_over:
		return
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME:
		return

	var box: Rect2 = Rect2(Vector2(VIEW_SIZE.x - 232.0, 64.0), Vector2(156.0, 44.0))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.64), true)
	draw_rect(box, Color(1.0, 1.0, 1.0, 0.22), false, 1.0)

	var text: String = hotseat_mode_controller.turn_label(current_player, turn_timer)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(16.0, 29.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _update_hotseat_charge(delta: float) -> void:
	if not _is_hotseat_game_active():
		return

	var keyboard_down: bool = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)

	if hotseat_mode_controller.can_begin_keyboard_charge(
		keyboard_down,
		hotseat_keyboard_fire_held,
		projectile_active,
		turn_projectiles,
		game_over,
		overlay_open
	):
		hotseat_keyboard_fire_held = true
		hotseat_charge_time = 0.0
		hotseat_charge_percent = HOTSEAT_CHARGE_MIN_PERCENT

	if hotseat_fire_button_held or hotseat_keyboard_fire_held:
		hotseat_charge_time = minf(HOTSEAT_CHARGE_TIME_MAX, hotseat_charge_time + delta)

		var charge_ratio: float = clampf(hotseat_charge_time / HOTSEAT_CHARGE_TIME_MAX, 0.0, 1.0)
		hotseat_charge_percent = hotseat_mode_controller.charge_percent(
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

	if hotseat_mode_controller.should_release_keyboard_charge(keyboard_down, hotseat_keyboard_fire_held):
		hotseat_keyboard_fire_held = false
		_release_hotseat_charged_shot()

func _player_can_fire() -> bool:
	return realtime_mode_controller.player_can_fire(rt_player_shell_active, game_over)

func _update_realtime_fire_charge(delta: float) -> void:
	if game_mode != GAME_MODE_SINGLE_PLAYER_REALTIME or menu_state != MENU_STATE_GAME:
		return

	var keyboard_down: bool = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)

	if realtime_mode_controller.can_begin_fire_charge(keyboard_down, rt_keyboard_fire_held, rt_player_shell_active, game_over, overlay_open):
		rt_keyboard_fire_held = true
		rt_fire_charge_time = 0.0
		rt_fire_charge_percent = RT_CHARGE_MIN_PERCENT
	elif realtime_mode_controller.should_release_fire_charge(keyboard_down, rt_keyboard_fire_held):
		rt_keyboard_fire_held = false
		_release_realtime_charged_shot()

	if rt_fire_button_held or rt_keyboard_fire_held:
		rt_fire_charge_time = minf(RT_CHARGE_TIME_MAX, rt_fire_charge_time + delta)

		var charge_ratio: float = clampf(rt_fire_charge_time / RT_CHARGE_TIME_MAX, 0.0, 1.0)
		rt_fire_charge_percent = realtime_mode_controller.charge_percent(
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

func _update_ui() -> void:
	super._update_ui()

	if _is_hotseat_game_active() and not game_over:
		if hotseat_fire_button_held or hotseat_keyboard_fire_held:
			power_label.text = "Charge: %.0f%%" % hotseat_charge_percent
		else:
			power_label.text = "Hold FIRE"
	elif game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME and not game_over:
		power_label.text = realtime_mode_controller.shell_status_label(
			rt_player_shell_active,
			rt_fire_button_held or rt_keyboard_fire_held,
			rt_fire_charge_percent,
			0.0
		)
