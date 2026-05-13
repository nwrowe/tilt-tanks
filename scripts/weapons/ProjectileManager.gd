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
