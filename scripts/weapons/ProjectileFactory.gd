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
	return make_split_children(owner, pos, vel, spread_x, split_speed_y, child_weapon, 3)

static func make_split_children(owner: int, pos: Vector2, vel: Vector2, spread_x: float, split_speed_y: float, child_weapon: String, child_count: int) -> Array[Dictionary]:
	var children: Array[Dictionary] = []
	var count: int = maxi(1, child_count)
	if count == 1:
		children.append(make_shell(
			owner,
			child_weapon,
			pos,
			Vector2(vel.x, maxf(absf(vel.y) * 0.35, split_speed_y)),
			true,
			true
		))
		return children

	var center_index: float = float(count - 1) * 0.5
	for i: int in range(count):
		var offset_ratio: float = (float(i) - center_index) / center_index
		var spread: float = spread_x * offset_ratio
		children.append(make_shell(
			owner,
			child_weapon,
			pos,
			Vector2(vel.x + spread, maxf(absf(vel.y) * 0.35, split_speed_y)),
			true,
			absf(offset_ratio) < 0.01
		))
	return children
