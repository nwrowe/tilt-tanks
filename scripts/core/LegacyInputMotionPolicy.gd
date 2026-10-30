extends RefCounted
class_name LegacyInputMotionPolicy

## Pure aiming, movement and camera rules from MainStableTweaks.gd.
## Godot Input, terrain queries and drawing remain on the game node.

static func keyboard_aim(current: float, direction: float, delta: float, min_angle: float, max_angle: float) -> float:
	return clampf(current + direction * 75.0 * delta, min_angle, max_angle)

static func tilt_aim(gravity_x: float, player: int, full_scale: float, min_angle: float, max_angle: float) -> float:
	var roll: float = clampf(gravity_x / 9.8, -full_scale, full_scale)
	var aiming_roll: float = -roll if player == 0 else roll
	var normalized_roll: float = (aiming_roll / full_scale + 1.0) * 0.5
	return clampf(lerpf(min_angle, max_angle, normalized_roll), min_angle, max_angle)

static func next_tank_x(current_x: float, direction: float, speed: float, delta: float, world_width: float) -> float:
	return clampf(current_x + direction * speed * delta, 45.0, world_width - 45.0)

static func can_move_without_overlap(new_x: float, other_x: float) -> bool:
	return absf(new_x - other_x) >= 90.0

static func camera_x(
	tank_x: float, projectile_active: bool, projectile_x: float,
	explosion_timer: float, explosion_pos: Vector2,
	view_width: float, camera_scale: float, world_width: float
) -> float:
	var focus_x: float = tank_x
	if projectile_active:
		focus_x = projectile_x
	elif explosion_timer > 0.0 and explosion_pos != Vector2.INF:
		focus_x = explosion_pos.x
	var visible_width: float = view_width / camera_scale
	return clampf(focus_x - visible_width * 0.5, 0.0, maxf(0.0, world_width - visible_width))
