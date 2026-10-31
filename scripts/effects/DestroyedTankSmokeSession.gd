extends RefCounted
class_name DestroyedTankSmokeSession

## Owns destroyed-tank smoke state, puff generation and puff aging.
## The gameplay node supplies tank positions and its seeded RNG, and remains
## responsible only for drawing puffs in screen coordinates.

var tank_index: int = -1
var spawn_timer: float = 0.0
var puffs: Array[Dictionary] = []

func start(health: Array[int]) -> bool:
	if tank_index >= 0:
		return false
	if health.size() < 2:
		return false
	if health[0] <= 0:
		tank_index = 0
	elif health[1] <= 0:
		tank_index = 1
	else:
		return false
	spawn_timer = 0.0
	return true

func advance(delta: float, interval: float) -> bool:
	if tank_index < 0:
		return false
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = interval
		return true
	return false

func spawn_puff(
	tank_positions: Array[Vector2], rng: RandomNumberGenerator,
	lifetime: float, drift_speed: float
) -> void:
	if tank_index < 0 or tank_index >= tank_positions.size():
		return
	var base_pos: Vector2 = tank_positions[tank_index]
	# Preserve exactly three draws per puff and their prior order:
	# horizontal offset, vertical offset, then horizontal drift.
	var offset: Vector2 = Vector2(
		rng.randf_range(-15.0, 15.0), rng.randf_range(-36.0, -18.0)
	)
	puffs.append(EffectsManager.make_puff(
		base_pos + offset, lifetime,
		rng.randf_range(-drift_speed, drift_speed)
	))

func update_puffs(delta: float, rise_speed: float) -> void:
	puffs = EffectsManager.update_rising_puffs(puffs, delta, rise_speed)

func reset() -> void:
	tank_index = -1
	spawn_timer = 0.0
	puffs.clear()
