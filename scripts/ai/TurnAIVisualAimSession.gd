extends RefCounted
class_name TurnAIVisualAimSession

## Owns turn-based AI's visual aim plan and display target. Ballistic search,
## world movement and firing stay with existing planner/runtime components.

var plan: Dictionary = {}
var target_angle: float = 45.0
var target_power_percent: float = 55.0

static func perturb_plan(
	base_plan: Dictionary, rng: RandomNumberGenerator,
	angle_error: float, power_error: float,
	min_angle: float, max_angle: float
) -> Dictionary:
	# Mutate the supplied plan, matching the original runtime behavior.
	# The angle error draw must precede the power error draw.
	var final_angle: float = clampf(
		float(base_plan.get("angle", 45.0)) + rng.randf_range(-angle_error, angle_error),
		min_angle, max_angle
	)
	var final_power_percent: float = clampf(
		float(base_plan.get("power_percent", 55.0)) + rng.randf_range(-power_error, power_error),
		0.0, 100.0
	)
	base_plan["angle"] = final_angle
	base_plan["power_percent"] = final_power_percent
	return base_plan

func track(new_plan: Dictionary, fallback_angle: float, fallback_power: float) -> void:
	plan = new_plan
	target_angle = float(plan.get("angle", fallback_angle))
	target_power_percent = float(plan.get("power_percent", fallback_power))

func advance_angle(current_angle: float, rate_deg_per_sec: float, delta: float) -> float:
	return move_toward(current_angle, target_angle, rate_deg_per_sec * delta)

func shot_settings(fallback_x: float, min_angle: float, max_angle: float) -> Dictionary:
	# Interpret the visual plan without consuming it. The runtime clears
	# the plan only after applying movement, power and UI settings.
	return {
		"move_x": float(plan.get("move_x", fallback_x)),
		"angle": clampf(float(plan.get("angle", 45.0)), min_angle, max_angle),
		"power_percent": clampf(float(plan.get("power_percent", 55.0)), 0.0, 100.0)
	}

func clear_plan() -> void:
	plan.clear()
