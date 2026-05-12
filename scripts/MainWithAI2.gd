extends "res://scripts/MainWithAI.gd"

const AI_THINK_TIME_SLOWER: float = 1.75
const AI_RANDOM_ANGLE_ERROR_EASIER: float = 7.5
const AI_RANDOM_POWER_ERROR_EASIER: float = 12.0
const AI_SCORE_RANDOMNESS: float = 85.0
const AI_MOVE_OFFSETS: Array[float] = [-80.0, -40.0, 0.0, 40.0, 80.0]
const AI_MOVE_PENALTY_PER_PIXEL: float = 0.18
const AI_MOVE_CHANCE: float = 0.65
const AI_EDGE_MARGIN: float = 70.0
const AI_MIN_DISTANCE_FROM_HUMAN: float = 160.0

func _process(delta: float) -> void:
	if menu_state != MENU_STATE_GAME:
		queue_redraw()
		return

	if _is_ai_turn_waiting_for_explosion():
		_process_ai_turn_waiting_for_explosion(delta)
		return

	if _is_ai_turn_active():
		_process_ai_turn(delta)
	else:
		super._process(delta)

func _is_ai_turn_waiting_for_explosion() -> bool:
	return game_mode == GAME_MODE_SINGLE_PLAYER_QUICK and current_player == AI_PLAYER_INDEX and not projectile_active and not game_over and not overlay_open and explosion_timer > 0.0

func _process_ai_turn_waiting_for_explosion(delta: float) -> void:
	# Let the previous explosion animation complete before the computer starts
	# thinking. This also fixes the visual freeze that happened because the AI
	# process path bypassed the normal explosion timer update.
	explosion_timer -= delta
	if explosion_timer <= 0.0:
		explosion_timer = 0.0
		explosion_pos = Vector2.INF
		ai_pending_turn = false
	_update_camera(delta)
	_update_ui()
	queue_redraw()

func _begin_ai_turn() -> void:
	ai_pending_turn = true
	ai_think_timer = AI_THINK_TIME_SLOWER
	mobile_left_pressed = false
	mobile_right_pressed = false
	power_slider.release_focus()

func _take_ai_shot() -> void:
	var plan: Dictionary = _find_ai_plan()
	var planned_x: float = float(plan.get("move_x", tank_positions[AI_PLAYER_INDEX].x))
	_apply_ai_move(planned_x)

	var chosen_angle: float = float(plan.get("angle", 45.0)) + rng.randf_range(-AI_RANDOM_ANGLE_ERROR_EASIER, AI_RANDOM_ANGLE_ERROR_EASIER)
	var chosen_power_percent: float = float(plan.get("power_percent", 55.0)) + rng.randf_range(-AI_RANDOM_POWER_ERROR_EASIER, AI_RANDOM_POWER_ERROR_EASIER)

	angle_deg = clampf(chosen_angle, MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)
	power_percent = clampf(chosen_power_percent, 0.0, 100.0)
	power = _power_from_percent(power_percent)
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	power_slider.value = power_percent
	_on_fire_pressed()

func _find_ai_plan() -> Dictionary:
	var best_score: float = AI_MAX_SCORE_DISTANCE
	var best_angle: float = 45.0
	var best_power_percent: float = 55.0
	var best_x: float = tank_positions[AI_PLAYER_INDEX].x
	var start_x: float = tank_positions[AI_PLAYER_INDEX].x

	for offset: float in AI_MOVE_OFFSETS:
		var candidate_x: float = clampf(start_x + offset, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
		if absf(candidate_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
			continue
		var candidate_y: float = _ground_y_at_x(candidate_x) - TANK_RADIUS
		var candidate_pos: Vector2 = Vector2(candidate_x, candidate_y)
		var move_penalty: float = absf(candidate_x - start_x) * AI_MOVE_PENALTY_PER_PIXEL

		for test_angle: int in range(AI_MIN_ANGLE_DEG, AI_MAX_ANGLE_DEG + 1, AI_ANGLE_STEP_DEG + 2):
			for test_power_percent: int in range(AI_MIN_POWER_PERCENT, AI_MAX_POWER_PERCENT + 1, AI_POWER_STEP_PERCENT + 3):
				var score: float = _score_ai_shot_from_position(candidate_pos, float(test_angle), float(test_power_percent))
				score += move_penalty
				# Makes the AI pick a good-enough shot instead of perfectly dialing in.
				score += rng.randf_range(0.0, AI_SCORE_RANDOMNESS)
				if score < best_score:
					best_score = score
					best_angle = float(test_angle)
					best_power_percent = float(test_power_percent)
					best_x = candidate_x

	# The AI considers movement, but does not always move. This makes it feel less
	# robotic and avoids constant tiny repositioning.
	if rng.randf() > AI_MOVE_CHANCE:
		best_x = start_x
		var stationary: Dictionary = _find_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX])
		best_angle = float(stationary.get("angle", best_angle))
		best_power_percent = float(stationary.get("power_percent", best_power_percent))

	return {
		"angle": best_angle,
		"power_percent": best_power_percent,
		"move_x": best_x,
		"score": best_score
	}

func _find_ai_shot_from_position(shooter_pos: Vector2) -> Dictionary:
	var best_score: float = AI_MAX_SCORE_DISTANCE
	var best_angle: float = 45.0
	var best_power_percent: float = 55.0
	for test_angle: int in range(AI_MIN_ANGLE_DEG, AI_MAX_ANGLE_DEG + 1, AI_ANGLE_STEP_DEG + 2):
		for test_power_percent: int in range(AI_MIN_POWER_PERCENT, AI_MAX_POWER_PERCENT + 1, AI_POWER_STEP_PERCENT + 3):
			var score: float = _score_ai_shot_from_position(shooter_pos, float(test_angle), float(test_power_percent))
			score += rng.randf_range(0.0, AI_SCORE_RANDOMNESS)
			if score < best_score:
				best_score = score
				best_angle = float(test_angle)
				best_power_percent = float(test_power_percent)
	return {
		"angle": best_angle,
		"power_percent": best_power_percent,
		"score": best_score
	}

func _score_ai_shot_from_position(shooter_pos: Vector2, test_angle_deg: float, test_power_percent: float) -> float:
	var facing: float = -1.0
	var rad: float = deg_to_rad(test_angle_deg)
	var test_power: float = _power_from_percent(test_power_percent)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	var pos: Vector2 = shooter_pos + muzzle_offset
	var vel: Vector2 = Vector2(facing * test_power * cos(rad), -test_power * sin(rad))
	# The computer aims at an imperfect mental target rather than exact tank center.
	var target_pos: Vector2 = tank_positions[HUMAN_PLAYER_INDEX] + Vector2(rng.randf_range(-28.0, 28.0), rng.randf_range(-8.0, 8.0))
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
			var impact_distance: float = Vector2(pos.x, ground_y).distance_to(target_pos)
			best_distance = minf(best_distance, impact_distance)
			break

	return best_distance

func _apply_ai_move(target_x: float) -> void:
	var current_x: float = tank_positions[AI_PLAYER_INDEX].x
	if absf(target_x - current_x) < 4.0:
		return
	var clamped_x: float = clampf(target_x, AI_EDGE_MARGIN, active_world_width - AI_EDGE_MARGIN)
	if absf(clamped_x - tank_positions[HUMAN_PLAYER_INDEX].x) < AI_MIN_DISTANCE_FROM_HUMAN:
		return
	tank_positions[AI_PLAYER_INDEX].x = clamped_x
	tank_positions[AI_PLAYER_INDEX].y = _ground_y_at_x(clamped_x) - TANK_RADIUS
