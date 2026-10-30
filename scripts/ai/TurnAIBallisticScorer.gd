extends RefCounted
class_name TurnAIBallisticScorer

## Pure trajectory-to-target distance scoring. Target jitter and launch-power
## lookup are supplied by the runtime, preserving the order of RNG draws.
## Ground height is injected so this has no dependency on a game scene.

static func score(
	shooter_pos: Vector2,
	target_pos: Vector2,
	angle_deg: float,
	power: float,
	ground_y_at_x: Callable,
	config: Dictionary
) -> float:
	var facing: float = -1.0
	var rad: float = deg_to_rad(angle_deg)
	var cannon_length: float = float(config["cannon_length"])
	var muzzle_offset: Vector2 = Vector2(
		facing * cannon_length * cos(rad), -cannon_length * sin(rad)
	)
	var pos: Vector2 = shooter_pos + muzzle_offset
	var vel: Vector2 = Vector2(facing * power * cos(rad), -power * sin(rad))
	var best_distance: float = pos.distance_to(target_pos)
	var elapsed: float = 0.0

	var sim_dt: float = float(config["sim_dt"])
	var max_time: float = float(config["max_time"])
	var gravity: float = float(config["gravity"])
	var wind: float = float(config["wind"])
	var world_width: float = float(config["world_width"])
	var floor_y: float = float(config["floor_y"])
	while elapsed < max_time:
		vel.y += gravity * sim_dt
		vel.x += wind * sim_dt
		pos += vel * sim_dt
		elapsed += sim_dt
		best_distance = minf(best_distance, pos.distance_to(target_pos))
		if pos.x < -100.0 or pos.x > world_width + 100.0:
			break
		if pos.y > floor_y + 180.0:
			break
		var ground_y: float = float(ground_y_at_x.call(pos.x))
		if pos.y >= ground_y:
			best_distance = minf(
				best_distance, Vector2(pos.x, ground_y).distance_to(target_pos)
			)
			break
	return best_distance
