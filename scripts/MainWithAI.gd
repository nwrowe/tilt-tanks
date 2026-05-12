extends "res://scripts/MainWithMenus2.gd"

const GAME_MODE_HOTSEAT: int = 0
const GAME_MODE_SINGLE_PLAYER_QUICK: int = 1

const AI_PLAYER_INDEX: int = 1
const HUMAN_PLAYER_INDEX: int = 0
const AI_THINK_TIME: float = 0.85
const AI_ANGLE_STEP_DEG: int = 4
const AI_POWER_STEP_PERCENT: int = 4
const AI_MIN_ANGLE_DEG: int = 12
const AI_MAX_ANGLE_DEG: int = 84
const AI_MIN_POWER_PERCENT: int = 15
const AI_MAX_POWER_PERCENT: int = 100
const AI_SIM_DT: float = 0.055
const AI_SIM_MAX_TIME: float = 5.5
const AI_RANDOM_ANGLE_ERROR: float = 4.5
const AI_RANDOM_POWER_ERROR: float = 7.0
const AI_MAX_SCORE_DISTANCE: float = 999999.0

var game_mode: int = GAME_MODE_HOTSEAT
var ai_pending_turn: bool = false
var ai_think_timer: float = 0.0

func _on_quick_game_pressed() -> void:
	game_mode = GAME_MODE_SINGLE_PLAYER_QUICK
	_start_game(true)

func _on_hotseat_pressed() -> void:
	game_mode = GAME_MODE_HOTSEAT
	_start_game(false)

func _process(delta: float) -> void:
	if menu_state != MENU_STATE_GAME:
		queue_redraw()
		return

	if _is_ai_turn_active():
		_process_ai_turn(delta)
	else:
		super._process(delta)

func _is_ai_turn_active() -> bool:
	return game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and current_player == AI_PLAYER_INDEX and not projectile_active and not game_over and not overlay_open

func _advance_turn() -> void:
	super._advance_turn()
	if _is_ai_turn_active():
		_begin_ai_turn()
	else:
		ai_pending_turn = false

func reset_match() -> void:
	super.reset_match()
	ai_pending_turn = false
	ai_think_timer = 0.0

func _begin_ai_turn() -> void:
	ai_pending_turn = true
	ai_think_timer = AI_THINK_TIME
	mobile_left_pressed = false
	mobile_right_pressed = false
	power_slider.release_focus()

func _process_ai_turn(delta: float) -> void:
	# Keep the camera/UI responsive while the computer is thinking.
	if not ai_pending_turn:
		_begin_ai_turn()

	ai_think_timer -= delta
	_update_camera(delta)
	_update_ui()
	queue_redraw()

	if ai_think_timer <= 0.0:
		ai_pending_turn = false
		_take_ai_shot()

func _take_ai_shot() -> void:
	var aim: Dictionary = _find_ai_shot()
	var chosen_angle: float = float(aim.get("angle", 45.0)) + rng.randf_range(-AI_RANDOM_ANGLE_ERROR, AI_RANDOM_ANGLE_ERROR)
	var chosen_power_percent: float = float(aim.get("power_percent", 55.0)) + rng.randf_range(-AI_RANDOM_POWER_ERROR, AI_RANDOM_POWER_ERROR)

	angle_deg = clampf(chosen_angle, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)
	power_percent = clampf(chosen_power_percent, 0.0, 100.0)
	power = _power_from_percent(power_percent)
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	power_slider.value = power_percent
	_on_fire_pressed()

func _find_ai_shot() -> Dictionary:
	var best_score: float = AI_MAX_SCORE_DISTANCE
	var best_angle: float = 45.0
	var best_power_percent: float = 55.0

	for test_angle: int in range(AI_MIN_ANGLE_DEG, AI_MAX_ANGLE_DEG + 1, AI_ANGLE_STEP_DEG):
		for test_power_percent: int in range(AI_MIN_POWER_PERCENT, AI_MAX_POWER_PERCENT + 1, AI_POWER_STEP_PERCENT):
			var score: float = _score_ai_shot(float(test_angle), float(test_power_percent))
			if score < best_score:
				best_score = score
				best_angle = float(test_angle)
				best_power_percent = float(test_power_percent)

	return {
		"angle": best_angle,
		"power_percent": best_power_percent,
		"score": best_score
	}

func _score_ai_shot(test_angle_deg: float, test_power_percent: float) -> float:
	var facing: float = -1.0
	var rad: float = deg_to_rad(test_angle_deg)
	var test_power: float = _power_from_percent(test_power_percent)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var pos: Vector2 = tank_positions[AI_PLAYER_INDEX] + muzzle_offset
	var vel: Vector2 = Vector2(facing * test_power * cos(rad), -test_power * sin(rad))
	var target_pos: Vector2 = tank_positions[HUMAN_PLAYER_INDEX]
	var best_distance: float = pos.distance_to(target_pos)
	var elapsed: float = 0.0

	while elapsed < AI_SIM_MAX_TIME:
		vel.y += gravity * AI_SIM_DT
		vel.x += wind * AI_SIM_DT
		pos += vel * AI_SIM_DT
		elapsed += AI_SIM_DT

		var dist_to_target: float = pos.distance_to(target_pos)
		best_distance = minf(best_distance, dist_to_target)

		if pos.x < -100.0 or pos.x > active_world_width + 100.0:
			break
		if pos.y > _bottom_floor_y() + 180.0:
			break

		var ground_y: float = _ground_y_at_x(pos.x)
		if pos.y >= ground_y:
			# Prefer impacts near the human tank, but do not require a direct hit.
			var impact_distance: float = Vector2(pos.x, ground_y).distance_to(target_pos)
			best_distance = minf(best_distance, impact_distance)
			break

	return best_distance

func _update_ui() -> void:
	super._update_ui()
	if menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and current_player == AI_PLAYER_INDEX and not game_over:
		status_label.text = "Computer thinking...   P1 HP: %d    CPU HP: %d" % [tank_health[0], tank_health[1]]
	elif menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and not game_over:
		status_label.text = "Your turn   P1 HP: %d    CPU HP: %d" % [tank_health[0], tank_health[1]]
