extends RefCounted
class_name TurnAIShotPlanner

## Deterministic given a supplied RNG and score callback. The mode runtime
## remains responsible for terrain lookup, projectile simulation and firing.
## Keep the candidate ordering and random draws identical to the legacy AI.

static func find_shot(
	rng: RandomNumberGenerator,
	shooter_pos: Vector2,
	score_shot: Callable,
	config: Dictionary
) -> Dictionary:
	var best_score: float = float(config["max_score"])
	var best_angle: float = 45.0
	var best_power_percent: float = 55.0
	for test_angle: int in range(
		int(config["min_angle"]), int(config["max_angle"]) + 1,
		int(config["angle_step"]) + 2
	):
		for test_power_percent: int in range(
			int(config["min_power"]), int(config["max_power"]) + 1,
			int(config["power_step"]) + 3
		):
			var score: float = float(score_shot.call(
				shooter_pos, float(test_angle), float(test_power_percent)
			))
			score += rng.randf_range(0.0, float(config["score_randomness"]))
			if score < best_score:
				best_score = score
				best_angle = float(test_angle)
				best_power_percent = float(test_power_percent)
	return {"angle": best_angle, "power_percent": best_power_percent, "score": best_score}

static func find_plan(
	rng: RandomNumberGenerator,
	shooter_pos: Vector2,
	human_pos: Vector2,
	world_width: float,
	ground_y_at_x: Callable,
	score_shot: Callable,
	config: Dictionary
) -> Dictionary:
	var best_score: float = float(config["max_score"])
	var best_angle: float = 45.0
	var best_power_percent: float = 55.0
	var start_x: float = shooter_pos.x
	var best_x: float = start_x

	for offset: float in config["move_offsets"]:
		var candidate_x: float = clampf(
			start_x + offset,
			float(config["edge_margin"]), world_width - float(config["edge_margin"])
		)
		if absf(candidate_x - human_pos.x) < float(config["min_human_distance"]):
			continue
		var candidate_y: float = float(ground_y_at_x.call(candidate_x)) - float(config["tank_radius"])
		var candidate_pos: Vector2 = Vector2(candidate_x, candidate_y)
		var move_penalty: float = absf(candidate_x - start_x) * float(config["move_penalty_per_pixel"])
		for test_angle: int in range(
			int(config["min_angle"]), int(config["max_angle"]) + 1,
			int(config["angle_step"]) + 2
		):
			for test_power_percent: int in range(
				int(config["min_power"]), int(config["max_power"]) + 1,
				int(config["power_step"]) + 3
			):
				var score: float = float(score_shot.call(
					candidate_pos, float(test_angle), float(test_power_percent)
				))
				score += move_penalty
				score += rng.randf_range(0.0, float(config["score_randomness"]))
				if score < best_score:
					best_score = score
					best_angle = float(test_angle)
					best_power_percent = float(test_power_percent)
					best_x = candidate_x

	if rng.randf() > float(config["move_chance"]):
		best_x = start_x
		var stationary: Dictionary = find_shot(rng, shooter_pos, score_shot, config)
		best_angle = float(stationary.get("angle", best_angle))
		best_power_percent = float(stationary.get("power_percent", best_power_percent))
	return {"angle": best_angle, "power_percent": best_power_percent, "move_x": best_x, "score": best_score}
