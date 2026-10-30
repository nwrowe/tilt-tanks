extends SceneTree
## Dependency-free CI smoke tests. Run after the editor import pass:
## godot --headless --path . --script res://tests/smoke.gd

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_main_scene()
	_test_match_controller()
	_test_composed_match_runtime_synchronizer()
	_test_match_damage()
	_test_player_frame_adoption()
	_test_complete_turn_with_settings()
	_test_weapon_catalog()
	_test_power_control_policy()
	_test_legacy_input_motion_policy()
	_test_composed_backdrop_geometry()
	_test_weapon_definition_session()
	_test_level_definitions()
	_test_tank_progression_data()
	if failures.is_empty():
		print("PASS: Tilt Tanks smoke checks")
		quit(0)
		return
	for failure: String in failures:
		printerr("FAIL: ", failure)
	quit(1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func _test_main_scene() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	_check(scene != null, "Main.tscn loads")
	if scene == null:
		return
	var main: Node = scene.instantiate()
	_check(main != null and main is Node2D, "Main scene instantiates as Node2D")
	if main != null:
		_check(main.get_script() != null, "Main scene has active gameplay script")
		main.free()

func _test_match_controller() -> void:
	var state: MatchState = MatchState.new()
	var controller: MatchController = MatchController.new(state)
	controller.start_match(
		0, 1500.0, 30.0, 45.0, 800.0, 50.0,
		Vector2(100.0, 300.0), Vector2(1300.0, 300.0), 0.0
	)
	_check(state.current_player == 0, "new match starts with player 1")
	_check(state.tank_positions[1].x == 1300.0, "match keeps tank spawn positions")
	controller.save_current_player_settings(32.0, 740.0, 62.0)
	_check(is_equal_approx(state.player_angles[0], 32.0), "player aim is saved")
	_check(is_equal_approx(state.player_power_percents[0], 62.0), "player power is saved")
	controller.advance_turn(30.0)
	_check(state.current_player == 1, "turn advances to player 2")
	controller.advance_turn(30.0)
	_check(state.current_player == 0, "turn cycles back to player 1")
	_check(is_equal_approx(state.player_angles[0], 32.0), "player 1 aim persists across turns")
	controller.begin_projectile(Vector2(200.0, 100.0), Vector2(40.0, -20.0))
	_check(state.projectile_active, "projectile begins")
	controller.sync_projectile_frame(true, Vector2(225.0, 95.0), Vector2(55.0, -10.0), Vector2.INF, 0.0)
	_check(state.projectile_active and state.projectile_pos == Vector2(225.0, 95.0), "controller adopts active projectile position")
	_check(state.projectile_vel == Vector2(55.0, -10.0), "controller adopts active projectile velocity")
	_check(state.explosion_pos == Vector2.INF, "active flight clears previous explosion")

	controller.finish_projectile_with_explosion(Vector2(250.0, 300.0), 0.5)
	_check(not state.projectile_active, "projectile clears on explosion")
	_check(state.explosion_timer > 0.0, "explosion timer is set")
	controller.sync_projectile_frame(false, Vector2.ZERO, Vector2.ZERO, Vector2(280.0, 315.0), 0.75)
	_check(not state.projectile_active and state.explosion_pos == Vector2(280.0, 315.0), "impact transitions into explosion state")
	_check(is_equal_approx(state.explosion_timer, 0.75), "controller preserves explosion hold duration")
	controller.sync_projectile_frame(false, Vector2.ZERO, Vector2.ZERO, Vector2.INF, 0.0)
	_check(state.explosion_pos == Vector2.INF and is_zero_approx(state.explosion_timer), "expired explosion clears controller state")
	controller.sync_projectile_frame(true, Vector2(100.0, 40.0), Vector2(7.0, 9.0), Vector2(200.0, 40.0), 1.0)
	_check(state.projectile_active and state.explosion_pos == Vector2.INF, "new projectile takes precedence over stale explosion")

	controller.apply_damage(1, 100)
	_check(controller.is_game_over() and controller.winner_index() == 0, "destroying player 2 ends match")
	# A complete health snapshot has one winner decision, never a transient
	# winner from applying two lethal health values in succession.
	controller.sync_health_values([0, 0])
	_check(controller.is_game_over() and controller.winner_index() == -1, "simultaneous destruction is game over without winner")
	_check(state.tank_health == [0, 0], "controller holds both destroyed tank values")
	controller.sync_health_values([72, 100])
	_check(not controller.is_game_over() and controller.winner_index() == -1, "restored health clears winner")
	_check(state.tank_health == [72, 100], "controller accepts one atomic damage snapshot")
	controller.sync_health_values([-5, 42])
	_check(state.tank_health[0] == 0 and controller.winner_index() == 1, "controller clamps negative health and awards player 2")
	controller.sync_health_values([100])
	_check(state.tank_health == [0, 42], "malformed health count does not partially update state")


func _test_player_frame_adoption() -> void:
	var state: MatchState = MatchState.new()
	var controller: MatchController = MatchController.new(state)
	controller.start_match(0, 1500.0, 30.0, 45.0, 800.0, 50.0, Vector2.ZERO, Vector2(1400, 300), 0.0)
	var positions: Array[Vector2] = [Vector2(100, 300), Vector2(1300, 280)]
	var angles: Array[float] = [31.0, 72.0]
	var powers: Array[float] = [700.0, 1050.0]
	var percents: Array[float] = [24.0, 82.0]
	controller.sync_runtime_player_frame(1, positions, angles, powers, percents, -35.0, 11.5, 2, 1750.0)
	_check(state.current_player == 1 and state.game_mode == 2, "controller adopts player and mode from runtime")
	_check(state.tank_positions[1] == Vector2(1300, 280), "controller adopts tank positions")
	_check(state.player_angles == [31.0, 72.0], "controller adopts both players' angles")
	_check(state.player_powers == [700.0, 1050.0], "controller adopts both players' power")
	_check(state.player_power_percents == [24.0, 82.0], "controller adopts both power percentages")
	_check(is_equal_approx(state.turn_timer, 11.5) and is_equal_approx(state.wind, -35.0), "controller adopts timer and wind")
	_check(is_equal_approx(state.active_world_width, 1750.0), "controller adopts active world width")
	positions[1] = Vector2.ZERO
	angles[0] = 0.0
	powers[0] = 0.0
	percents[0] = 0.0
	_check(state.tank_positions[1] == Vector2(1300, 280), "controller frame does not alias positions")
	_check(is_equal_approx(state.player_angles[0], 31.0), "controller frame does not alias angle arrays")
	_check(is_equal_approx(state.player_powers[0], 700.0), "controller frame does not alias power arrays")
	_check(is_equal_approx(state.player_power_percents[0], 24.0), "controller frame does not alias percentages")
	_check(state.tank_health == [100, 100] and not state.game_over, "player frame adoption does not change match health")
	controller.set_wind(22.5)
	_check(is_equal_approx(state.wind, 22.5), "level wind updates through controller")
	var first_build: TankBuildState = TankProgressionRegistry.default_player_build(0)
	var second_build: TankBuildState = TankProgressionRegistry.default_player_build(1)
	first_build.credits = 120
	var builds: Array[TankBuildState] = [first_build, second_build]
	controller.sync_tank_builds(builds)
	_check(state.tank_build_for_player(0).credits == 120, "controller adopts player 1 progression build")
	_check(state.tank_build_for_player(1).tank_class_id == second_build.tank_class_id, "controller preserves player 2 tank class")


func _test_match_damage() -> void:
	var impact: Vector2 = Vector2(100.0, 100.0)
	_check(MatchDamagePolicy.radial_damage(impact, impact, 10.0, 100.0, 75, 50, 4) == 75, "direct impact uses direct damage")
	_check(MatchDamagePolicy.radial_damage(impact, Vector2(155.0, 100.0), 10.0, 100.0, 75, 50, 4) == 20, "halfway blast preserves 1.35 power falloff")
	_check(MatchDamagePolicy.radial_damage(impact, Vector2(199.0, 100.0), 10.0, 100.0, 75, 50, 4) == 4, "weapon blast preserves four HP splash minimum")
	_check(MatchDamagePolicy.radial_damage(impact, Vector2(199.0, 100.0), 10.0, 100.0, 75, 50, 6) == 6, "classic blast preserves six HP splash minimum")
	_check(MatchDamagePolicy.radial_damage(impact, Vector2(201.0, 100.0), 10.0, 100.0, 75, 50, 4) == 0, "targets outside blast receive no damage")
	var state: MatchState = MatchState.new()
	var controller: MatchController = MatchController.new(state)
	controller.start_match(0, 1500.0, 30.0, 45.0, 800.0, 50.0, impact, Vector2(155.0, 100.0), 0.0)
	controller.apply_radial_damage(impact, state.tank_positions, 10.0, 100.0, 75, 50, 4)
	_check(state.tank_health == [25, 80], "controller applies both damage values together")
	_check(not controller.is_game_over() and controller.winner_index() == -1, "partial damage leaves no winner")
	controller.sync_health_values([50, 50])
	controller.apply_radial_damage(impact, [impact, impact], 10.0, 100.0, 75, 50, 4)
	_check(state.tank_health == [0, 0], "blast can destroy both tanks")
	_check(controller.is_game_over() and controller.winner_index() == -1, "simultaneous kill is a draw")
	controller.sync_health_values([100, 100])
	controller.apply_radial_damage(impact, [impact], 10.0, 100.0, 75, 50, 4)
	_check(state.tank_health == [100, 100] and not controller.is_game_over(), "malformed target count leaves health unchanged")

func _test_complete_turn_with_settings() -> void:
	var state: MatchState = MatchState.new()
	var controller: MatchController = MatchController.new(state)
	controller.start_match(
		0, 1500.0, 30.0, 45.0, 800.0, 50.0,
		Vector2(100, 300), Vector2(1400, 300), 0.0
	)
	var next_player: int = controller.complete_turn_without_shot(30.0, 39.0, 720.0, 33.0)
	_check(next_player == 1 and state.current_player == 1, "completing first turn advances to player 2")
	_check(is_equal_approx(state.player_angles[0], 39.0), "turn completion preserves player 1 aim")
	_check(is_equal_approx(state.player_powers[0], 720.0), "turn completion preserves player 1 power")
	_check(is_equal_approx(state.player_power_percents[0], 33.0), "turn completion preserves player 1 power percentage")
	_check(is_equal_approx(state.player_angles[1], 45.0), "outgoing player save does not overwrite next player")
	controller.complete_turn_without_shot(30.0, 58.0, 975.0, 68.0)
	_check(state.current_player == 0, "completing second turn returns to player 1")
	_check(is_equal_approx(state.player_angles[1], 58.0), "turn completion preserves player 2 aim")
	_check(is_equal_approx(state.player_power_percents[1], 68.0), "turn completion preserves player 2 charge")
	_check(is_equal_approx(state.turn_timer, 30.0), "turn completion resets timer")
	_check(state.tank_health == [100, 100] and not state.game_over, "turn completion leaves health and winner intact")

func _test_weapon_definition_session() -> void:
	var session: WeaponDefinitionSession = WeaponDefinitionSession.new()
	_check(session.definitions.has(WeaponCatalog.STANDARD), "session owns standard weapon definition")
	_check(session.loadout.has_weapon(WeaponCatalog.HEAVY), "session default loadout includes Heavy")
	_check(session.display_name(WeaponCatalog.HEAVY) != "", "session displays registry weapon names")
	_check(session.value(WeaponCatalog.HEAVY, "direct_damage", -1) != -1, "session reads definition metadata")
	_check(session.has_split_behavior(WeaponCatalog.CLUSTER), "session recognizes Cluster split behavior")
	_check(session.should_split_on_descent(WeaponCatalog.CLUSTER, false, Vector2(10, 12)), "session permits descending cluster split")
	_check(not session.should_split_on_descent(WeaponCatalog.CLUSTER, true, Vector2(10, 12)), "session blocks duplicate cluster split")
	var children: Array[Dictionary] = session.make_split_children(
		0, WeaponCatalog.CLUSTER, Vector2(100, 200), Vector2(20, 12),
		115.0, 58.0
	)
	_check(children.size() == 3, "session constructs registry-specified cluster children")
	var restricted: WeaponLoadout = WeaponLoadout.new(
		[WeaponCatalog.STANDARD, WeaponCatalog.HEAVY], WeaponCatalog.STANDARD
	)
	_check(session.set_loadout(restricted), "session adopts level-restricted weapon loadout")
	_check(session.safe_weapon(WeaponCatalog.CLUSTER) == WeaponCatalog.STANDARD, "session rejects restricted Cluster")
	_check(not session.set_loadout(null), "session rejects missing loadout")
	_check(session.loadout == restricted, "rejected loadout preserves current allowed weapons")
	session.reset_default()
	_check(session.safe_weapon(WeaponCatalog.CLUSTER) == WeaponCatalog.CLUSTER, "session reset restores full weapon set")

func _test_composed_match_runtime_synchronizer() -> void:
	var state: MatchState = MatchState.new()
	var controller: MatchController = MatchController.new(state)
	var adapter: MatchRuntimeSynchronizer = MatchRuntimeSynchronizer.new(controller)
	_check(adapter.state == state and adapter.controller == controller, "composed adapter owns expected controller and state")
	adapter.start_match(
		0, 1500.0, 30.0, 45.0, 800.0, 50.0,
		Vector2(100, 300), Vector2(1400, 300), 0.0
	)
	var positions: Array[Vector2] = [Vector2(120, 300), Vector2(1350, 290)]
	var angles: Array[float] = [35.0, 55.0]
	var powers: Array[float] = [700.0, 950.0]
	var charges: Array[float] = [25.0, 73.0]
	var health: Array[int] = [100, 65]
	var over: bool = adapter.sync_frame(
		1, positions, angles, powers, charges,
		17.0, 14.0, 0, 1550.0,
		true, Vector2(350, 100), Vector2(100, -20),
		Vector2.INF, 0.0, health
	)
	_check(not over and state.current_player == 1, "adapter synchronizes turn and game-over state")
	_check(state.player_angles == angles and state.player_power_percents == charges, "adapter synchronizes player settings")
	_check(state.projectile_active and state.projectile_pos == Vector2(350, 100), "adapter synchronizes active projectile")
	_check(state.tank_health == [100, 65], "adapter synchronizes health")
	adapter.sync_projectile(false, Vector2.ZERO, Vector2.ZERO, Vector2(350, 310), 0.5)
	_check(not state.projectile_active and state.explosion_pos == Vector2(350, 310), "adapter synchronizes projectile impact")
	var updated: Array[int] = adapter.apply_radial_damage(
		[100, 65], [Vector2(350, 310), Vector2(1200, 310)],
		Vector2(350, 310), 12.0, 90.0, 75, 50, 4
	)
	_check(updated == [25, 65] and state.tank_health == updated, "adapter applies controller radial damage")
	_check(adapter.sync_health([100, 0]), "adapter reports terminal health state")
	_check(controller.winner_index() == 0, "adapter retains controller winner result")

func _test_power_control_policy() -> void:
	_check(is_equal_approx(PowerControlPolicy.force_from_percent(0.0, 400.0, 1200.0), 400.0), "zero percent uses minimum launch force")
	_check(is_equal_approx(PowerControlPolicy.force_from_percent(50.0, 400.0, 1200.0), 800.0), "fifty percent maps to midpoint force")
	_check(is_equal_approx(PowerControlPolicy.force_from_percent(100.0, 400.0, 1200.0), 1200.0), "hundred percent uses maximum force")
	_check(is_equal_approx(PowerControlPolicy.force_from_percent(-10.0, 400.0, 1200.0), 400.0), "negative percentage is clamped")
	_check(is_equal_approx(PowerControlPolicy.force_from_percent(140.0, 400.0, 1200.0), 1200.0), "above maximum percentage is clamped")
	_check(is_equal_approx(PowerControlPolicy.clamp_percent(42.0), 42.0), "valid percentage is unchanged")

func _test_legacy_input_motion_policy() -> void:
	_check(is_equal_approx(LegacyInputMotionPolicy.keyboard_aim(45.0, 1.0, 0.2, 2.0, 94.0), 60.0), "keyboard up advances aim at 75 degrees per second")
	_check(is_equal_approx(LegacyInputMotionPolicy.keyboard_aim(45.0, -1.0, 0.2, 2.0, 94.0), 30.0), "keyboard down reduces aim")
	_check(is_equal_approx(LegacyInputMotionPolicy.keyboard_aim(90.0, 1.0, 0.2, 2.0, 94.0), 94.0), "keyboard aim is clamped")
	_check(is_equal_approx(LegacyInputMotionPolicy.tilt_aim(0.0, 0, 0.5, 2.0, 94.0), 48.0), "neutral gravity selects midpoint angle")
	_check(is_equal_approx(LegacyInputMotionPolicy.tilt_aim(4.9, 0, 0.5, 2.0, 94.0), 2.0), "player one tilt maps to minimum aim")
	_check(is_equal_approx(LegacyInputMotionPolicy.tilt_aim(4.9, 1, 0.5, 2.0, 94.0), 94.0), "player two tilt reverses player one direction")
	_check(is_equal_approx(LegacyInputMotionPolicy.tilt_aim(-12.0, 0, 0.5, 2.0, 94.0), 94.0), "gravity input outside full scale clamps")
	_check(is_equal_approx(LegacyInputMotionPolicy.next_tank_x(200.0, 1.0, 100.0, 0.5, 1500.0), 250.0), "tank position integrates movement")
	_check(is_equal_approx(LegacyInputMotionPolicy.next_tank_x(1490.0, 1.0, 100.0, 0.5, 1500.0), 1455.0), "tank cannot cross right world edge")
	_check(is_equal_approx(LegacyInputMotionPolicy.next_tank_x(20.0, -1.0, 100.0, 0.5, 1500.0), 45.0), "tank cannot cross left world edge")
	_check(not LegacyInputMotionPolicy.can_move_without_overlap(100.0, 185.0), "nearby tanks block movement")
	_check(LegacyInputMotionPolicy.can_move_without_overlap(100.0, 190.0), "ninety-unit tank gap is permitted")
	_check(is_equal_approx(LegacyInputMotionPolicy.camera_x(150.0, false, 0.0, 0.0, Vector2.INF, 800.0, 1.0, 1600.0), 0.0), "camera clamps near world start")
	_check(is_equal_approx(LegacyInputMotionPolicy.camera_x(800.0, false, 0.0, 0.0, Vector2.INF, 800.0, 1.0, 1600.0), 400.0), "camera follows active tank")
	_check(is_equal_approx(LegacyInputMotionPolicy.camera_x(300.0, true, 900.0, 0.5, Vector2(200.0, 0.0), 800.0, 1.0, 1600.0), 500.0), "active projectile takes camera priority")
	_check(is_equal_approx(LegacyInputMotionPolicy.camera_x(300.0, false, 0.0, 0.5, Vector2(750.0, 0.0), 800.0, 1.0, 1600.0), 350.0), "explosion hold becomes camera target")

func _test_composed_backdrop_geometry() -> void:
	var points: PackedVector2Array = LegacyBackdropRenderer.mountain_polygon(Vector2(900.0, 540.0))
	_check(points.size() == 12, "mountain backdrop retains original ten ridge points and two floor corners")
	_check(points[0] == Vector2(-120.0, 540.0), "backdrop retains left floor corner")
	_check(points[1] == Vector2(-120.0, 295.0), "backdrop retains first mountain ridge")
	_check(points[11] == Vector2(1020.0, 540.0), "backdrop retains right floor corner")
	var different: PackedVector2Array = LegacyBackdropRenderer.mountain_polygon(Vector2(600.0, 400.0))
	_check(different[0].y == 400.0 and different[11].x == 720.0, "backdrop adapts to viewport dimensions")

func _test_weapon_catalog() -> void:
	var definitions: Dictionary = WeaponRegistry.build_default_definitions()
	_check(definitions.has(WeaponCatalog.STANDARD), "standard shell is registered")
	_check(definitions.has(WeaponCatalog.HEAVY), "heavy shell is registered")
	_check(definitions.has(WeaponCatalog.CLUSTER), "cluster shell is registered")
	var loadout: WeaponLoadout = WeaponLoadout.from_registry(definitions, WeaponCatalog.STANDARD)
	_check(loadout.has_weapon(WeaponCatalog.STANDARD), "standard shell is selectable")
	_check(not loadout.has_weapon(WeaponCatalog.CLUSTER_CHILD), "cluster child is not selectable")
	_check(loadout.safe_weapon("unknown_weapon") == WeaponCatalog.STANDARD, "invalid weapon falls back to standard")

func _test_level_definitions() -> void:
	var levels: Dictionary = LevelRegistry.build_default_levels()
	_check(levels.has(LevelRegistry.LEVEL_DEFAULT), "default level is registered")
	_check(levels.has(LevelRegistry.LEVEL_SNOWY_RIDGE), "snow level is registered")
	var snow_level: LevelDefinition = LevelRegistry.get_level(levels, LevelRegistry.LEVEL_SNOWY_RIDGE)
	_check(snow_level != null, "snow level resolves to a definition")

func _test_tank_progression_data() -> void:
	var classes: Dictionary = TankProgressionRegistry.build_default_tank_classes()
	var upgrades: Dictionary = TankProgressionRegistry.build_default_upgrades()
	var crew: Dictionary = TankProgressionRegistry.build_default_crew()
	var build: TankBuildState = TankProgressionRegistry.default_player_build(0)
	_check(build.tank_class_id == TankProgressionRegistry.CLASS_SCOUT, "new tank starts as scout")
	_check(classes.has(build.tank_class_id), "starting class exists")
	var stats: Dictionary = TankProgressionRegistry.effective_stats(build, classes, upgrades, crew)
	_check(float(stats.get(TankProgressionRegistry.STAT_MAX_HEALTH, 0.0)) > 0.0, "starter tank has positive health")
	_check(not upgrades.is_empty(), "upgrade catalog is populated")
