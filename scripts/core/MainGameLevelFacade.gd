extends "res://scripts/core/MainGameModeFacade.gd"

# Top-level level-definition facade. This introduces active level data without
# changing current terrain generation behavior yet. Future passes can route
# terrain, water, snow, wind, and loadouts through active_level_definition.

var level_definitions: Dictionary = LevelRegistry.build_default_levels()
var active_level_id: String = LevelRegistry.LEVEL_DEFAULT
var active_level_definition: LevelDefinition = LevelRegistry.get_level(level_definitions, active_level_id)

func reset_match() -> void:
	_apply_active_level_before_reset()
	super.reset_match()

func _select_level(level_id: String) -> void:
	active_level_id = level_id
	active_level_definition = LevelRegistry.get_level(level_definitions, active_level_id)
	_apply_level_weapon_loadout()

func _apply_active_level_before_reset() -> void:
	active_level_definition = LevelRegistry.get_level(level_definitions, active_level_id)
	_apply_level_weapon_loadout()

func _apply_level_weapon_loadout() -> void:
	if active_level_definition == null or not active_level_definition.has_weapon_restrictions():
		_reset_default_weapon_loadout()
		return
	var loadout: WeaponLoadout = WeaponLoadout.new(active_level_definition.default_weapon_ids, active_level_definition.default_weapon_ids[0])
	_set_active_weapon_loadout(loadout)

func _active_level_name() -> String:
	return active_level_definition.display_name if active_level_definition != null else "Default Hills"
