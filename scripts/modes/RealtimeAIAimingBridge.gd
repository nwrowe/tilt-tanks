extends "res://scripts/modes/WorldRuntimeBridge.gd"

# Smooths realtime single-player AI turret motion.
# The runtime still owns concrete movement/shot helpers, but timing, aim-rate,
# tolerance, and noisy targeting policy now route through RealtimeAIController.

var realtime_ai_controller: RealtimeAIController = RealtimeAIController.new()

var rt_ai_visual_has_plan: bool = false
var rt_ai_visual_target_angle: float = 45.0
var rt_ai_visual_target_power_percent: float = 55.0

func reset_match() -> void:
	_clear_realtime_ai_visual_plan()
	super.reset_match()

func _setup_realtime_single_player() -> void:
	super._setup_realtime_single_player()
	_clear_realtime_ai_visual_plan()
	_choose_realtime_ai_visual_plan()

func _clear_realtime_ai_visual_plan() -> void:
	rt_ai_visual_has_plan = false

func _choose_realtime_ai_visual_plan() -> void:
	var aim: Dictionary = _find_ai_shot_from_position(tank_positions[AI_PLAYER_INDEX])
	rt_ai_visual_target_angle = realtime_ai_controller.noisy_target_angle(
		rng,
		float(aim.get("angle", 45.0)),
		RT_AI_AIM_ERROR_ANGLE,
		MOBILE_MIN_ANGLE,
		MOBILE_MAX_ANGLE
	)
	rt_ai_visual_target_power_percent = realtime_ai_controller.noisy_power_percent(
		rng,
		float(aim.get("power_percent", 55.0)),
		RT_AI_AIM_ERROR_POWER
	)
	rt_ai_visual_has_plan = true

func _update_realtime_ai(delta: float) -> void:
	if game_over or overlay_open:
		return

	if rt_ai_move_cooldown <= 0.0:
		_choose_realtime_ai_move_target()
		rt_ai_move_cooldown = realtime_ai_controller.next_move_cooldown(rng, RT_AI_MOVE_COOLDOWN_MAX)
		_clear_realtime_ai_visual_plan()

	_move_realtime_ai(delta)

	if not rt_ai_visual_has_plan:
		_choose_realtime_ai_visual_plan()

	_update_realtime_ai_visual_aim(delta)

	if rt_ai_fire_cooldown <= 0.0:
		if not realtime_ai_controller.can_fire_at_angle(player_angles[AI_PLAYER_INDEX], rt_ai_visual_target_angle):
			return

		player_angles[AI_PLAYER_INDEX] = rt_ai_visual_target_angle
		player_power_percents[AI_PLAYER_INDEX] = rt_ai_visual_target_power_percent
		player_powers[AI_PLAYER_INDEX] = _power_from_percent(rt_ai_visual_target_power_percent)
		_fire_realtime_projectile(AI_PLAYER_INDEX)
		rt_ai_fire_cooldown = realtime_ai_controller.next_fire_cooldown(rng, RT_AI_FIRE_COOLDOWN_MAX)
		_clear_realtime_ai_visual_plan()

func _update_realtime_ai_visual_aim(delta: float) -> void:
	if player_angles.size() <= AI_PLAYER_INDEX:
		return
	player_angles[AI_PLAYER_INDEX] = realtime_ai_controller.move_angle_toward_target(
		player_angles[AI_PLAYER_INDEX],
		rt_ai_visual_target_angle,
		delta
	)
