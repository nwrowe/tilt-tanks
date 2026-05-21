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

func _generate_ponds() -> void:
	var level_pond_chance: float = POND_CHANCE
	if active_level_definition != null:
		level_pond_chance = active_level_definition.pond_chance
	ponds = WaterManager.generate_ponds(
		rng,
		terrain_points,
		active_right_start_x,
		TANK_START_LEFT_X,
		level_pond_chance,
		POND_ATTEMPTS,
		POND_MIN_WIDTH,
		POND_MAX_WIDTH,
		POND_MIN_DEPTH,
		POND_RIM_SEARCH_RADIUS,
		POND_SURFACE_DROP,
		POND_SPAWN_AVOID_RADIUS,
		TERRAIN_STEP
	)

func _level_snow_line_y() -> float:
	return active_level_definition.snow_line_y if active_level_definition != null else SNOW_LINE_Y

func _is_snow_at_x(x: float) -> bool:
	return SnowManager.is_snow_at_x(terrain_points, x, TERRAIN_STEP, _level_snow_line_y())

func _snow_adjusted_direction_and_speed(x: float, input_direction: float, base_speed: float) -> Dictionary:
	return SnowManager.adjusted_direction_and_speed(
		terrain_points,
		x,
		input_direction,
		base_speed,
		TERRAIN_STEP,
		active_world_width,
		_level_snow_line_y(),
		SNOW_UPHILL_BLOCK_SLOPE,
		SNOW_SLIDE_SLOPE,
		SNOW_SLIDE_SPEED,
		SNOW_DRIVE_MULT,
		SNOW_UPHILL_SLOW_MULT
	)

func _draw_snow_faces() -> void:
	for face_data: Dictionary in SnowManager.snow_face_polygons(terrain_points, _level_snow_line_y(), 0.62):
		var face_world: PackedVector2Array = face_data.get("face", PackedVector2Array())
		var face_screen: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in face_world:
			face_screen.append(_world_to_screen(point))
		if face_screen.size() >= 3:
			draw_colored_polygon(face_screen, Color(0.90, 0.95, 1.0, SNOW_FACE_ALPHA))

		var shadow_world: PackedVector2Array = face_data.get("shadow", PackedVector2Array())
		var shadow_screen: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in shadow_world:
			shadow_screen.append(_world_to_screen(point))
		if shadow_screen.size() >= 3:
			draw_colored_polygon(shadow_screen, Color(0.62, 0.78, 1.0, SNOW_FACE_SHADOW_ALPHA))

func _draw_snow_surface_highlights() -> void:
	for segment_world: Array in SnowManager.snow_segments(terrain_points, _level_snow_line_y()):
		var segment: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in segment_world:
			segment.append(_world_to_screen(point))
		_draw_snow_highlight_segment(segment)

func _active_level_name() -> String:
	return active_level_definition.display_name if active_level_definition != null else "Default Hills"
