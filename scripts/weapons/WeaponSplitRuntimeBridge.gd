extends "res://scripts/weapons/WeaponDefinitionRuntimeBridge.gd"

# Transitional bridge for moving split-weapon behavior onto WeaponDefinition.
# For now this preserves the existing cluster split physics constants while
# using definition metadata to decide whether a weapon splits and which child
# weapon it creates.

func _weapon_should_split_on_descent(weapon: String, split_done: bool, vel: Vector2) -> bool:
	return _weapon_has_split_behavior(weapon) and not split_done and vel.y >= 0.0

func _make_split_children(owner: int, weapon: String, pos: Vector2, vel: Vector2) -> Array[Dictionary]:
	var child_id: String = _weapon_child_id(weapon)
	var count: int = _weapon_child_count(weapon)
	if child_id == "" or count <= 0:
		return []
	return ProjectileFactory.make_split_children(owner, pos, vel, CLUSTER_SPLIT_SPREAD_X, CLUSTER_SPLIT_SPEED_Y, child_id, count)

func _split_turn_cluster_projectile(pos: Vector2, vel: Vector2) -> void:
	projectile_active = false
	turn_projectile_split_done = true
	turn_projectiles.clear()
	turn_projectiles = _make_split_children(current_player, turn_projectile_weapon, pos, vel)

func _spawn_realtime_cluster_children(owner: int, pos: Vector2, vel: Vector2) -> void:
	var children: Array[Dictionary] = _make_split_children(owner, WEAPON_CLUSTER, pos, vel)
	for child: Dictionary in children:
		rt_projectiles.append(child)
