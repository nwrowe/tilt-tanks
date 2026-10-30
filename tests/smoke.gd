extends SceneTree
## Dependency-free CI smoke tests. Run after the editor import pass:
## godot --headless --path . --script res://tests/smoke.gd

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_main_scene()
	_test_match_controller()
	_test_weapon_catalog()
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
	controller.finish_projectile_with_explosion(Vector2(250.0, 300.0), 0.5)
	_check(not state.projectile_active, "projectile clears on explosion")
	_check(state.explosion_timer > 0.0, "explosion timer is set")
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
