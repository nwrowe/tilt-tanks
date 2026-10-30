extends RefCounted
class_name WeaponDefinitionSession

## Registry, allowed loadout and metadata lookup without a game-node parent.
## Runtime menu/weapon callbacks remain on the active scene for now.
var definitions: Dictionary = WeaponRegistry.build_default_definitions()
var loadout: WeaponLoadout = WeaponLoadout.from_registry(definitions, WeaponCatalog.STANDARD)

func set_loadout(value: WeaponLoadout) -> bool:
	if value == null:
		return false
	loadout = value
	return true

func reset_default() -> void:
	loadout = WeaponLoadout.from_registry(definitions, WeaponCatalog.STANDARD)

func safe_weapon(weapon: String) -> String:
	return loadout.safe_weapon(weapon) if loadout != null else weapon

func definition(weapon: String) -> WeaponDefinition:
	return WeaponRegistry.get_definition(definitions, weapon)

func display_name(weapon: String) -> String:
	return WeaponRegistry.display_name(definitions, weapon)

func value(weapon: String, key: String, fallback: Variant) -> Variant:
	return WeaponRegistry.value(definitions, weapon, key, fallback)

func has_split_behavior(weapon: String) -> bool:
	var item: WeaponDefinition = definition(weapon)
	return item != null and item.has_split_behavior()

func split_behavior(weapon: String) -> String:
	var item: WeaponDefinition = definition(weapon)
	return item.split_behavior if item != null else ""

func child_id(weapon: String) -> String:
	var item: WeaponDefinition = definition(weapon)
	return item.child_weapon_id if item != null else ""

func child_count(weapon: String) -> int:
	var item: WeaponDefinition = definition(weapon)
	return item.child_count if item != null else 0

func should_split_on_descent(weapon: String, already_split: bool, velocity: Vector2) -> bool:
	return WeaponSplitLogic.should_split(definitions, weapon, already_split, velocity)

func make_split_children(
	owner: int, weapon: String, pos: Vector2, vel: Vector2,
	spread_x: float, speed_y: float
) -> Array[Dictionary]:
	return WeaponSplitLogic.make_children(
		definitions, owner, weapon, pos, vel, spread_x, speed_y
	)
