extends RefCounted
class_name ProjectileManager

static func step_shell(shell: Dictionary, gravity: float, wind: float, delta: float) -> Dictionary:
	var updated: Dictionary = shell.duplicate(true)
	var pos: Vector2 = updated.get("pos", Vector2.ZERO)
	var vel: Vector2 = updated.get("vel", Vector2.ZERO)
	vel.y += gravity * delta
	vel.x += wind * delta
	pos += vel * delta
	updated["pos"] = pos
	updated["vel"] = vel
	return updated

static func step_legacy_projectile(pos: Vector2, vel: Vector2, gravity: float, wind: float, delta: float) -> Dictionary:
	var new_vel: Vector2 = vel
	var new_pos: Vector2 = pos
	new_vel.y += gravity * delta
	new_vel.x += wind * delta
	new_pos += new_vel * delta
	return {
		"pos": new_pos,
		"vel": new_vel
	}

static func is_out_of_world(pos: Vector2, world_width: float, bottom_y: float) -> bool:
	return pos.x < -100.0 or pos.x > world_width + 100.0 or pos.y > bottom_y + 180.0

static func projectile_hits_tank(pos: Vector2, tank_pos: Vector2, tank_radius: float, projectile_radius: float) -> bool:
	return pos.distance_to(tank_pos) <= tank_radius + projectile_radius

## Canonical turn/realtime shell contact order. Callables keep pond,
## terrain and bottom-floor queries lazy: a tank or pond hit must not
## evaluate later world geometry, matching the original scene hooks.
static func should_shell_explode(
	pos: Vector2, target_pos: Vector2,
	tank_radius: float, projectile_radius: float,
	pond_contains: Callable, ground_height_at: Callable,
	world_width: float, bottom_floor: Callable
) -> bool:
	if projectile_hits_tank(pos, target_pos, tank_radius, projectile_radius):
		return true
	if bool(pond_contains.call(pos)):
		return true
	var ground_y: float = float(ground_height_at.call(pos.x))
	if pos.y >= ground_y:
		return true
	return is_out_of_world(pos, world_width, float(bottom_floor.call()))

static func average_shell_position(shells: Array[Dictionary]) -> Vector2:
	if shells.is_empty():
		return Vector2.INF
	var total: Vector2 = Vector2.ZERO
	for shell: Dictionary in shells:
		total += shell.get("pos", Vector2.ZERO)
	return total / float(shells.size())

static func average_shell_position_for_weapon(shells: Array[Dictionary], weapon: String) -> Vector2:
	var total: Vector2 = Vector2.ZERO
	var count: int = 0
	for shell: Dictionary in shells:
		if str(shell.get("weapon", "")) == weapon:
			total += shell.get("pos", Vector2.ZERO)
			count += 1
	if count <= 0:
		return Vector2.INF
	return total / float(count)

static func has_shell_for_owner(shells: Array[Dictionary], owner: int) -> bool:
	for shell: Dictionary in shells:
		if int(shell.get("owner", -1)) == owner:
			return true
	return false

## Average a selected weapon's shells and bias toward its forward-most round.
## Input shells, owner and projectile state are never mutated. An empty
## selection returns INF so callers can retain their previous camera focus.
static func leading_shell_focus_for_weapon(
	shells: Array[Dictionary], weapon: String, facing_left: bool, lead_bias: float
) -> Vector2:
	var count: int = 0
	var avg_pos: Vector2 = Vector2.ZERO
	var lead_pos: Vector2 = Vector2.INF
	var lead_initialized: bool = false
	var forward_sign: float = -1.0 if facing_left else 1.0
	for shell: Dictionary in shells:
		if str(shell.get("weapon", "")) != weapon:
			continue
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		avg_pos += pos
		count += 1
		if not lead_initialized or pos.x * forward_sign > lead_pos.x * forward_sign:
			lead_pos = pos
			lead_initialized = true
	if count <= 0:
		return Vector2.INF
	avg_pos /= float(count)
	return avg_pos.lerp(lead_pos, lead_bias)
