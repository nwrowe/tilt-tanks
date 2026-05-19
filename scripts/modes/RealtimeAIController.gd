extends ModeController
class_name RealtimeAIController

# Controller for realtime single-player AI policy. The current runtime still
# owns the concrete movement/shot helpers, but this controller centralizes
# timing/rate policy so the AI can later be swapped per mode/difficulty.

var barrel_aim_rate_deg: float = 32.0
var fire_angle_tolerance_deg: float = 1.25
var move_cooldown_min_mult: float = 0.65
var move_cooldown_max_mult: float = 1.25
var fire_cooldown_min_mult: float = 0.75
var fire_cooldown_max_mult: float = 1.25

func mode_name() -> String:
	return "realtime_ai"

func next_move_cooldown(rng: RandomNumberGenerator, max_cooldown: float) -> float:
	return rng.randf_range(max_cooldown * move_cooldown_min_mult, max_cooldown * move_cooldown_max_mult)

func next_fire_cooldown(rng: RandomNumberGenerator, max_cooldown: float) -> float:
	return rng.randf_range(max_cooldown * fire_cooldown_min_mult, max_cooldown * fire_cooldown_max_mult)

func can_fire_at_angle(current_angle: float, target_angle: float) -> bool:
	return absf(current_angle - target_angle) <= fire_angle_tolerance_deg

func move_angle_toward_target(current_angle: float, target_angle: float, delta: float) -> float:
	return move_toward(current_angle, target_angle, barrel_aim_rate_deg * delta)

func noisy_target_angle(rng: RandomNumberGenerator, base_angle: float, error_amount: float, min_angle: float, max_angle: float) -> float:
	return clampf(base_angle + rng.randf_range(-error_amount, error_amount), min_angle, max_angle)

func noisy_power_percent(rng: RandomNumberGenerator, base_percent: float, error_amount: float) -> float:
	return clampf(base_percent + rng.randf_range(-error_amount, error_amount), 0.0, 100.0)
