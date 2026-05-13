extends RefCounted
class_name ProjectileFactory

static func make_shell(owner: int, weapon: String, pos: Vector2, vel: Vector2, split: bool = false, center_child: bool = false) -> Dictionary:
	return {
		"owner": owner,
		"weapon": weapon,
		"split": split,
		"center_child": center_child,
		"pos": pos,
		"vel": vel
	}

static func make_cluster_children(owner: int, pos: Vector2, vel: Vector2, spread_x: float, split_speed_y: float, child_weapon: String) -> Array[Dictionary]:
	var children: Array[Dictionary] = []
	var spreads: Array[float] = [-spread_x, 0.0, spread_x]
	for spread: float in spreads:
		children.append(make_shell(
			owner,
			child_weapon,
			pos,
			Vector2(vel.x + spread, maxf(absf(vel.y) * 0.35, split_speed_y)),
			true,
			is_zero_approx(spread)
		))
	return children
