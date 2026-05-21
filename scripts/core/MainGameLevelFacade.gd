extends "res://scripts/core/MainGameModeFacade.gd"

# Top-level level-definition facade. This introduces active level data and
# starts routing safe world settings through LevelDefinition while preserving
# the current default behavior.

var level_definitions: Dictionary = LevelRegistry.build_default_levels()
var active_level_id: String = LevelRegistry.LEVEL_DEFAULT
var active_level_definition: LevelDefinition = LevelRegistry.get_level(level_definitions, active_level_id)

func reset_match() -> void:
	_apply_active_level_before_reset()
	super.reset_match()
	_apply_level_wind_after_reset()

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

func _apply_level_wind_after_reset() -> void:
	if active_level_definition == null:
		return
	wind = rng.randf_range(-active_level_definition.wind_max_accel, active_level_definition.wind_max_accel)
	if match_state != null:
		match_state.wind = wind

func _generate_random_terrain() -> void:
	# Keep terrain generation algorithm unchanged, but allow the active level to
	# provide the broad range values that previously had to be hardcoded.
	if active_level_definition == null:
		super._generate_random_terrain()
		return

	terrain_points.clear()
	active_world_width = rng.randf_range(active_level_definition.world_width_min, active_level_definition.world_width_max)
	active_right_start_x = active_world_width - 130.0
	terrain_points = TerrainManager.generate_varied_terrain(
		rng,
		active_world_width,
		TERRAIN_STEP,
		_bottom_floor_y(),
		active_level_definition.terrain_min_y,
		active_level_definition.terrain_max_y,
		active_level_definition.start_min_y,
		active_level_definition.start_max_y,
		VAR_CONTROL_SPACING_MIN,
		VAR_CONTROL_SPACING_MAX,
		VAR_SLOPE_KICK,
		VAR_DETAIL_WAVE_AMOUNT,
		TANK_START_LEFT_X,
		active_right_start_x,
		54.0
	)
	_refresh_terrain_line()
	_settle_tanks_on_terrain()
	_generate_ponds()

func _active_level_name() -> String:
	return active_level_definition.display_name if active_level_definition != null else "Default Hills"
