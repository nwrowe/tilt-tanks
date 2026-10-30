extends RefCounted
class_name OnlineDuelInterpolation

## Client-only authoritative target state and smoothing math. This object
## never sends RPCs or changes authoritative host state.
var has_authoritative_state: bool = false
var tank_targets: Array = []
var projectile_target: Vector2 = Vector2.INF
var was_projectile_active: bool = false

func reset() -> void:
	has_authoritative_state = false
	tank_targets.clear()
	projectile_target = Vector2.INF
	was_projectile_active = false

func interpolate_tanks(positions: Array[Vector2], delta: float, smooth_time: float) -> void:
	if tank_targets.size() != positions.size():
		return
	var alpha: float = clampf(delta / smooth_time, 0.0, 1.0)
	for i: int in range(positions.size()):
		var target: Vector2 = tank_targets[i]
		positions[i] = positions[i].lerp(target, alpha)

func interpolate_projectile(current: Vector2, active: bool, delta: float, smooth_time: float) -> Vector2:
	if not active or projectile_target == Vector2.INF:
		return current
	var alpha: float = clampf(delta / smooth_time, 0.0, 1.0)
	return current.lerp(projectile_target, alpha)
