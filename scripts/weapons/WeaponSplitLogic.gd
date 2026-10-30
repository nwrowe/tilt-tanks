extends RefCounted
class_name WeaponSplitLogic

## Pure split-weapon decision and child factory. The runtime bridge retains
## mutation of live projectile arrays; this component never touches the scene.
static func should_split(definitions: Dictionary, weapon: String, split_done: bool, vel: Vector2) -> bool:
	var definition: WeaponDefinition = WeaponRegistry.get_definition(definitions, weapon)
	return definition != null and definition.has_split_behavior() and not split_done and vel.y >= 0.0

static func make_children(
	definitions: Dictionary,
	owner: int,
	weapon: String,
	pos: Vector2,
	vel: Vector2,
	spread_x: float,
	speed_y: float
) -> Array[Dictionary]:
	var definition: WeaponDefinition = WeaponRegistry.get_definition(definitions, weapon)
	if definition == null or definition.child_weapon_id == "" or definition.child_count <= 0:
		return []
	return ProjectileFactory.make_split_children(
		owner, pos, vel, spread_x, speed_y, definition.child_weapon_id, definition.child_count
	)
