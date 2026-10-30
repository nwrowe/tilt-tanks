extends RefCounted
class_name LevelSession

## Owns the selected level definition and its configuration policy.
## Terrain rendering, gameplay resets and weapon-menu creation remain
## responsibilities of the game node and its existing collaborators.
var definitions: Dictionary = LevelRegistry.build_default_levels()
var selected_id: String = LevelRegistry.LEVEL_DEFAULT
var definition: LevelDefinition = LevelRegistry.get_level(definitions, selected_id)

func select(level_id: String) -> void:
	selected_id = level_id
	refresh()

func refresh() -> void:
	definition = LevelRegistry.get_level(definitions, selected_id)

func restricted_loadout() -> WeaponLoadout:
	if definition == null or not definition.has_weapon_restrictions():
		return null
	return WeaponLoadout.new(definition.default_weapon_ids, definition.default_weapon_ids[0])

func next_wind(rng: RandomNumberGenerator) -> float:
	if definition == null:
		return 0.0
	return rng.randf_range(-definition.wind_max_accel, definition.wind_max_accel)

func next_world_width(rng: RandomNumberGenerator, fallback_min: float, fallback_max: float) -> float:
	if definition == null:
		return rng.randf_range(fallback_min, fallback_max)
	return rng.randf_range(definition.world_width_min, definition.world_width_max)

func pond_chance(fallback: float) -> float:
	return definition.pond_chance if definition != null else fallback

func snow_line_y(fallback: float) -> float:
	return definition.snow_line_y if definition != null else fallback

func display_name() -> String:
	return definition.display_name if definition != null else "Default Hills"
