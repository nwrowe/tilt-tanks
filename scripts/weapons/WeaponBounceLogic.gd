extends RefCounted
class_name WeaponBounceLogic

## Pure Bouncer weapon physics and mutable shell contact policy.
## The runtime remains responsible for terrain sampling, tank/water
## collision, explosion effects and metadata selection.

static func reached_limit(bounces: int, maximum: int) -> bool:
	return bounces >= maximum

static func reflect_velocity(
	incoming: Vector2, slope: float,
	damping_x: float, damping_y: float,
	min_upward_speed: float
) -> Vector2:
	var normal: Vector2 = Vector2(-slope, -1.0).normalized()
	var reflected: Vector2 = incoming - 2.0 * incoming.dot(normal) * normal
	var damping: float = 0.5 * (damping_x + damping_y)
	reflected *= damping
	if reflected.y > -min_upward_speed:
		reflected.y = -min_upward_speed
	return reflected

static func apply_ground_bounce(
	shell: Dictionary, ground_y: float,
	projectile_radius: float, rebound_velocity: Vector2
) -> void:
	# Deliberately update the supplied dictionary in place. Realtime
	# projectiles retain their existing owner, weapon and split fields.
	var pos: Vector2 = shell.get("pos", Vector2.ZERO)
	shell["pos"] = Vector2(pos.x, ground_y - projectile_radius)
	shell["vel"] = rebound_velocity
	shell["bounces"] = int(shell.get("bounces", 0)) + 1
