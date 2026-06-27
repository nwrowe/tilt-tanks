extends "res://scripts/core/MainGameProgressionFacade.gd"

# Hotseat handoff gate: each player must explicitly start their turn before
# aiming/movement/charging and the countdown timer become active.

const HOTSEAT_START_TURN_BUTTON_SIZE: Vector2 = Vector2(300.0, 68.0)
const HOTSEAT_START_TURN_BUTTON_POS: Vector2 = Vector2(
	(VIEW_SIZE.x - HOTSEAT_START_TURN_BUTTON_SIZE.x) * 0.5,
	VIEW_SIZE.y * 0.44
)

var hotseat_turn_start_pending: bool = false
var hotseat_start_turn_button: Button = null

func reset_match() -> void:
	hotseat_turn_start_pending = false
	super.reset_match()
	_arm_hotseat_turn_start_prompt()

func _build_overlay_ui() -> void:
	super._build_overlay_ui()
	_build_hotseat_start_turn_button()

func _return_to_main_menu() -> void:
	hotseat_turn_start_pending = false
	_update_hotseat_start_turn_button()
	super._return_to_main_menu()
	_update_hotseat_start_turn_button()

func _advance_turn() -> void:
	super._advance_turn()
	_arm_hotseat_turn_start_prompt()

func _process(delta: float) -> void:
	if _should_hold_for_hotseat_turn_start():
		_process_hotseat_turn_start_wait(delta)
		return

	super._process(delta)
	_update_hotseat_start_turn_button()

func _hotseat_can_begin_charge() -> bool:
	if _is_hotseat_turn_start_prompt_active():
		return false
	return super._hotseat_can_begin_charge()

func _update_ui() -> void:
	super._update_ui()
	if _is_hotseat_turn_start_prompt_active() and not game_over:
		status_label.text = "Pass phone to Player %d" % (current_player + 1)
		power_label.text = "Press START"

func _build_hotseat_start_turn_button() -> void:
	if hotseat_start_turn_button != null:
		return
	hotseat_start_turn_button = MobileControls.make_button(
		"Start Turn",
		HOTSEAT_START_TURN_BUTTON_POS,
		HOTSEAT_START_TURN_BUTTON_SIZE,
		ui_layer
	)
	hotseat_start_turn_button.visible = false
	hotseat_start_turn_button.pressed.connect(_on_hotseat_start_turn_pressed)

func _arm_hotseat_turn_start_prompt() -> void:
	if _is_hotseat_turn_start_prompt_mode() and not game_over:
		hotseat_turn_start_pending = true
		turn_timer = TURN_TIME_LIMIT
		_reset_hotseat_charge()
		_clear_hotseat_handoff_input_state()
	else:
		hotseat_turn_start_pending = false
	_update_hotseat_start_turn_button()

func _on_hotseat_start_turn_pressed() -> void:
	if hotseat_start_turn_button != null:
		hotseat_start_turn_button.release_focus()
	if not _is_hotseat_turn_start_prompt_active():
		hotseat_turn_start_pending = false
		_update_hotseat_start_turn_button()
		return

	hotseat_turn_start_pending = false
	turn_timer = TURN_TIME_LIMIT
	if match_state != null:
		match_state.turn_timer = turn_timer
	_reset_hotseat_charge()
	_clear_hotseat_handoff_input_state()
	_update_hotseat_start_turn_button()
	queue_redraw()

func _process_hotseat_turn_start_wait(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_match()
		return

	_clear_hotseat_handoff_input_state()
	_update_camera(delta)
	_update_ui()
	_update_muzzle_effects(delta)
	_update_hotseat_start_turn_button()
	queue_redraw()

func _should_hold_for_hotseat_turn_start() -> bool:
	return _is_hotseat_turn_start_prompt_active() \
		and not overlay_open \
		and not projectile_active \
		and turn_projectiles.is_empty() \
		and not machine_gun_active \
		and not machine_gun_turn_waiting_for_shells \
		and not pending_advance_after_explosion_hold \
		and explosion_timer <= 0.0 \
		and cluster_camera_hold_timer <= 0.0

func _is_hotseat_turn_start_prompt_active() -> bool:
	return hotseat_turn_start_pending and _is_hotseat_turn_start_prompt_mode() and not game_over

func _is_hotseat_turn_start_prompt_mode() -> bool:
	return menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_HOTSEAT and not single_player_mode

func _clear_hotseat_handoff_input_state() -> void:
	mobile_left_pressed = false
	mobile_right_pressed = false
	hotseat_fire_button_held = false
	hotseat_keyboard_fire_held = false
	if mobile_left_button != null:
		mobile_left_button.release_focus()
	if mobile_right_button != null:
		mobile_right_button.release_focus()
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _update_hotseat_start_turn_button() -> void:
	if hotseat_start_turn_button == null:
		return
	var should_show: bool = _is_hotseat_turn_start_prompt_active() and not overlay_open
	hotseat_start_turn_button.visible = should_show
	hotseat_start_turn_button.disabled = not should_show
	if should_show:
		hotseat_start_turn_button.text = "Start P%d Turn" % (current_player + 1)
