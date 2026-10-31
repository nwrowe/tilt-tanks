extends RefCounted
class_name DestroyedTankSmokeSession

## Tracks which destroyed tank emits smoke and when the next puff is due.
## Rendering and seeded puff position generation remain on the game node.

var tank_index: int = -1
var spawn_timer: float = 0.0

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

func reset() -> void:
	tank_index = -1
	spawn_timer = 0.0
