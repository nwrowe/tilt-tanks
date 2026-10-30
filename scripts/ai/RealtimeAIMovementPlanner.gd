extends RefCounted
class_name RealtimeAIMovementPlanner

## Scene-independent movement target selection for the realtime AI.
## Keep the candidate sequence, shot scoring calls and random draws identical
## to the former ModeRuntimeBridge implementation. The game remains the owner
## of tank positions, ground heights, shot scoring and motion application.

static func choose_target_x(
	rng: RandomNumberGenerator,
	ai_pos: Vector2,
	human_pos: Vector2,
	world_width: float,
	ground_y_at_x: Callable,
	find_shot: Callable,
	config: Dictionary
) -> float:
	if rng.randf() > float(config["move_chance"]):
		return ai_pos.x
	var move_options: Array[float] = [-100.0, -55.0, 0.0, 55.0, 100.0]
	var best_x: float = ai_pos.x
	var best_score: float = INF
	for offset: float in move_options:
		var candidate_x: float = clampf(
			ai_pos.x + offset, float(config["edge_margin"]),
			world_width - float(config["edge_margin"])
		)
		if absf(candidate_x - human_pos.x) < float(config["min_human_distance"]):
			continue
		var candidate_y: float = float(ground_y_at_x.call(candidate_x)) - float(config["tank_radius"])
		var candidate_pos: Vector2 = Vector2(candidate_x, candidate_y)
		var shot: Dictionary = find_shot.call(candidate_pos)
		var score: float = float(shot.get("score", 999999.0)) + absf(offset) * 0.2 + rng.randf_range(0.0, 100.0)
		if score < best_score:
			best_score = score
			best_x = candidate_x
	return best_x
