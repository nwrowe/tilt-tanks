extends RefCounted
class_name RealtimeAIAimingSession

## Realtime enemy's visual aim plan and smoothing policy. Never owns a game
## node, weapon/projectile runtime state, or rendering.
var controller: RealtimeAIController = RealtimeAIController.new()
var has_plan: bool = false
var target_angle: float = 45.0
var target_power_percent: float = 55.0

func clear() -> void:
	has_plan = false

func choose_plan(
	aim: Dictionary,
	rng: RandomNumberGenerator,
	angle_error: float,
	power_error: float,
	min_angle: float,
	max_angle: float
) -> void:
	target_angle = controller.noisy_target_angle(
		rng, float(aim.get("angle", 45.0)),
		angle_error, min_angle, max_angle
	)
	target_power_percent = controller.noisy_power_percent(
		rng, float(aim.get("power_percent", 55.0)),
		power_error
	)
	has_plan = true

func next_angle(current: float, delta: float) -> float:
	return controller.move_angle_toward_target(current, target_angle, delta)

func ready_to_fire(current_angle: float) -> bool:
	return controller.can_fire_at_angle(current_angle, target_angle)

func next_move_cooldown(rng: RandomNumberGenerator, max_cooldown: float) -> float:
	return controller.next_move_cooldown(rng, max_cooldown)

func next_fire_cooldown(rng: RandomNumberGenerator, max_cooldown: float) -> float:
	return controller.next_fire_cooldown(rng, max_cooldown)
