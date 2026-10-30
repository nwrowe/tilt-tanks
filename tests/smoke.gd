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
	_test_main_menu_presentation()
	_test_water_manager_world_policy()
	_test_turn_ai_ballistic_scorer()
	_test_turn_ai_shot_planner()
	_test_realtime_ai_movement_planner()
	_test_steam_puff_effect()
	_test_realtime_cooldown_policy()
	_test_wind_meter_policy()
	_test_turn_ai_session()
	_test_menu_navigation_session()
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

func _movement_test_ground(_x: float) -> float:
	return 200.0

func _movement_test_score(shooter_pos: Vector2) -> Dictionary:
	return {"score": absf(shooter_pos.x - 900.0) * 1000.0}

func _test_realtime_ai_movement_planner() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var config: Dictionary = {
		"move_chance": 1.0, "edge_margin": 70.0,
		"min_human_distance": 160.0, "tank_radius": 24.0
	}
	var ai_pos: Vector2 = Vector2(800.0, 200.0)
	var human_pos: Vector2 = Vector2(100.0, 200.0)
	var ground: Callable = Callable(self, "_movement_test_ground")
	var score: Callable = Callable(self, "_movement_test_score")

	rng.seed = 20261030
	var choice: float = RealtimeAIMovementPlanner.choose_target_x(
		rng, ai_pos, human_pos, 1200.0, ground, score, config
	)
	var next_random: float = rng.randf()
	_check(is_equal_approx(choice, 900.0), "realtime AI movement chooses lowest-scoring safe offset")

	rng.seed = 20261030
	var repeat_choice: float = RealtimeAIMovementPlanner.choose_target_x(
		rng, ai_pos, human_pos, 1200.0, ground, score, config
	)
	_check(is_equal_approx(choice, repeat_choice) and is_equal_approx(rng.randf(), next_random),
		"realtime movement planning reproduces choice and RNG consumption")

	config["move_chance"] = 0.0
	rng.seed = 20261030
	_check(is_equal_approx(
		RealtimeAIMovementPlanner.choose_target_x(rng, ai_pos, human_pos, 1200.0, ground, score, config), ai_pos.x
	), "realtime AI respects no-move probability gate")

	config["move_chance"] = 1.0
	config["min_human_distance"] = 1400.0
	rng.seed = 20261030
	_check(is_equal_approx(
		RealtimeAIMovementPlanner.choose_target_x(rng, ai_pos, human_pos, 1200.0, ground, score, config), ai_pos.x
	), "realtime AI retains position when all movement candidates are unsafe")

func _test_steam_puff_effect() -> void:
	var puff: Dictionary = {"pos": Vector2(100.0, 200.0), "age": 0.0, "life": 0.95, "drift": 10.0}
	var puffs: Array[Dictionary] = [puff]
	var updated: Array[Dictionary] = SteamPuffEffect.advance(puffs, 0.2, 34.0, 0.95)
	_check(updated.size() == 1, "steam puff remains active before expiry")
	_check(is_equal_approx(float(puff.get("age")), 0.2), "steam effect keeps mutable puff identity")
	_check((puff.get("pos") as Vector2).distance_to(Vector2(102.0, 193.2)) < 0.0001,
		"steam puff keeps drift and rise integration")
	var look: Dictionary = SteamPuffEffect.appearance(puff, 0.95, 4.0, 13.0, 0.66)
	_check(look["pos"] == puff["pos"], "steam render policy uses simulated position")
	_check(is_equal_approx(float(look["radius"]), lerpf(4.0, 13.0, 0.2 / 0.95) * 0.66),
		"steam effect preserves interpolated render radius")
	_check(is_equal_approx((look["color"] as Color).a, 0.52 * (1.0 - 0.2 / 0.95)),
		"steam effect preserves fade alpha")
	_check(SteamPuffEffect.advance(updated, 0.75, 34.0, 0.95).is_empty(),
		"steam puff expires at original lifetime boundary")
	var bare: Array[Dictionary] = [{"pos": Vector2.ZERO}]
	var defaults: Array[Dictionary] = SteamPuffEffect.advance(bare, 0.1, 34.0, 0.95)
	_check(defaults.size() == 1 and is_equal_approx(float(defaults[0]["age"]), 0.1),
		"steam puff preserves default lifetime and missing fields")

func _test_realtime_cooldown_policy() -> void:
	var warm: Dictionary = RealtimeCooldownPolicy.advance(0.5, 1.0, 2.0, 0.3, 0.10, 3.0, 0.1)
	_check(is_equal_approx(float(warm["player_fire"]), 0.4) and is_equal_approx(float(warm["ai_fire"]), 0.9),
		"realtime cooldowns subtract delta from player and AI firing timers")
	_check(is_equal_approx(float(warm["ai_move"]), 1.9) and is_equal_approx(float(warm["exhaust"]), 0.2),
		"realtime movement timers decrement in the same frame")
	_check(bool(warm["was_overheated"]) and is_equal_approx(float(warm["energy"]), 0.10),
		"realtime overheat retains energy before the cooldown expires")
	var expiry: Dictionary = RealtimeCooldownPolicy.advance(0.01, 0.01, 0.01, 0.05, 0.10, 3.0, 0.1)
	_check(is_zero_approx(float(expiry["exhaust"])) and is_equal_approx(float(expiry["energy"]), 0.75),
		"the expiry frame restores at least one-quarter movement energy")
	_check(bool(expiry["was_overheated"]) and is_zero_approx(float(expiry["player_fire"])),
		"the expiry frame is still marked overheated and fire cooldowns clamp at zero")
	var clear: Dictionary = RealtimeCooldownPolicy.advance(0.0, 0.0, 0.0, 0.0, 0.80, 3.0, 0.1)
	_check(not bool(clear["was_overheated"]) and is_equal_approx(float(clear["energy"]), 0.80),
		"the frame after expiry clears the overheat flag without losing movement energy")

func _test_wind_meter_policy() -> void:
	_check(is_equal_approx(WindMeterPolicy.display_value(42.5, 85.0, 10.0), 5.0),
		"wind meter preserves physical acceleration to display scaling")
	_check(is_equal_approx(WindMeterPolicy.display_value(-170.0, 85.0, 10.0), -10.0),
		"wind display clamps negative out-of-range acceleration")
	_check(is_equal_approx(WindMeterPolicy.strength(-5.0, 10.0), 0.5),
		"wind strength uses absolute display value")
	_check(is_equal_approx(WindMeterPolicy.strength(30.0, 10.0), 1.0),
		"wind meter strength clamps magnitude")
	_check(WindMeterPolicy.strength_color(0.1).is_equal_approx(Color(0.35, 0.95, 0.35, 0.92)),
		"weak wind keeps legacy green meter color")
	_check(WindMeterPolicy.strength_color(0.55).is_equal_approx(Color(0.35, 0.95, 0.35, 0.92)),
		"wind color is continuous at first gradient transition")
	_check(WindMeterPolicy.strength_color(0.82).is_equal_approx(Color(1.0, 0.95, 0.08, 0.92)),
		"wind color is continuous at second gradient transition")
	_check(WindMeterPolicy.strength_color(1.0).is_equal_approx(Color(1.0, 0.12, 0.08, 0.92)),
		"strong wind retains red meter color")
	var arrow_right: PackedVector2Array = WindMeterPolicy.arrow_points(Vector2(100, 100), 1.0)
	var arrow_left: PackedVector2Array = WindMeterPolicy.arrow_points(Vector2(100, 100), -1.0)
	_check(arrow_right.size() == 3 and arrow_right[1] == Vector2(92, 94),
		"positive wind retains right-facing arrowhead geometry")
	_check(arrow_left.size() == 3 and arrow_left[1] == Vector2(108, 94),
		"negative wind reverses the arrowhead geometry")
	_check(WindMeterPolicy.arrow_points(Vector2.ZERO, 0.0).is_empty(),
		"zero-direction wind arrow renders no polygon")

func _test_turn_ai_session() -> void:
	var session: TurnAITurnSession = TurnAITurnSession.new()
	_check(not session.pending and is_zero_approx(session.think_timer), "AI turn session starts idle")
	session.begin(1.75)
	_check(session.pending and is_equal_approx(session.think_timer, 1.75),
		"AI turn session owns pending state and initial delay")
	_check(not session.step(0.60) and session.pending and is_equal_approx(session.think_timer, 1.15),
		"AI turn session decrements think timer without firing early")
	_check(session.step(1.20) and session.pending, "AI turn session reports elapsed think delay")
	session.cancel()
	_check(not session.pending and session.think_timer < 0.0,
		"cancelling an AI turn preserves the original elapsed timer")
	session.reset()
	_check(not session.pending and is_zero_approx(session.think_timer),
		"match reset clears AI turn session completely")
	_check(TurnAITurnSession.can_act(true, true, false, false, false),
		"quick game AI can act while idle")
	_check(not TurnAITurnSession.can_act(true, true, true, false, false),
		"AI turn waits for projectile completion")
	_check(not TurnAITurnSession.can_act(false, true, false, false, false),
		"hotseat turns never trigger turn AI")
	_check(not TurnAITurnSession.can_act(true, true, false, true, false),
		"game over blocks AI turns")
	_check(not TurnAITurnSession.can_act(true, true, false, false, true),
		"open overlays block AI turns")
	_check(TurnAITurnSession.waiting_for_explosion(true, true, false, false, false, 0.1),
		"AI waits while impact effect remains active")
	_check(not TurnAITurnSession.waiting_for_explosion(true, true, false, false, false, 0.0),
		"completed explosion releases AI waiting state")

func _test_menu_navigation_session() -> void:
	var navigation: MainMenuNavigationSession = MainMenuNavigationSession.new()
	_check(navigation.screen == 0 and not navigation.single_player,
		"menu navigation defaults to home, without single-player selection")
	navigation.open_single_player()
	_check(navigation.screen == 1 and navigation.single_player,
		"single-player submenu sets screen and selection")
	navigation.open_options()
	_check(navigation.screen == 2 and navigation.single_player,
		"options menu preserves selection as before")
	navigation.show_online()
	_check(navigation.screen == 3 and navigation.single_player,
		"online action changes screen without resetting selection")
	navigation.open_multiplayer()
	_check(navigation.screen == 3 and not navigation.single_player,
		"multiplayer navigation resets single-player selection")
	navigation.choose_single_player(true)
	navigation.enter_game()
	_check(navigation.screen == 4 and navigation.single_player,
		"game entry retains the selection made before clearing controls")
	navigation.open_main()
	_check(navigation.screen == 0 and not navigation.single_player,
		"return to main menu clears single-player selection")

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

func _test_main_menu_presentation() -> void:
	var wide: Vector2 = Vector2(900.0, 540.0)
	var portrait: Vector2 = Vector2(540.0, 900.0)
	_check(MainMenuPresentation.anchored_position(wide, Vector2(0.5, 0.5), Vector2(310, 72)) == Vector2(295, 234), "menu button centers in landscape")
	_check(MainMenuPresentation.anchored_position(portrait, Vector2(0.5, 0.5), Vector2(310, 72)) == Vector2(115, 414), "menu button centers in portrait")
	var logo_wide: Rect2 = MainMenuPresentation.logo_rect(wide, true, Vector2(600, 300))
	_check(is_equal_approx(logo_wide.size.x, 324.0), "landscape logo width uses 36 percent")
	_check(is_equal_approx(logo_wide.size.y, 162.0), "landscape logo keeps original aspect")
	_check(is_equal_approx(logo_wide.position.y, 64.8), "landscape logo keeps original vertical offset")
	var logo_portrait: Rect2 = MainMenuPresentation.logo_rect(portrait, false, Vector2(600, 300))
	_check(is_equal_approx(logo_portrait.size.x, 378.0), "portrait logo width uses 70 percent")
	_check(is_equal_approx(logo_portrait.position.y, 81.0), "portrait logo retains vertical offset")
	var mountains: PackedVector2Array = MainMenuPresentation.fallback_mountains(wide)
	_check(mountains.size() == 10, "fallback menu background has eight ridge points")
	_check(mountains[0] == Vector2(0, 387.4), "fallback menu mountains keep horizon height")
	_check(is_equal_approx(mountains[9].x, 900.0), "fallback mountains end at viewport edge")
	var hill: PackedVector2Array = MainMenuPresentation.fallback_hill(wide)
	_check(hill.size() == 32, "fallback hill retains thirty interior points")
	_check(hill[0] == Vector2(0, 540) and hill[31] == Vector2(900, 540), "fallback hill meets viewport floor")

func _test_water_manager_world_policy() -> void:
	var points: Array[Vector2] = [
		Vector2(0, 100), Vector2(10, 140), Vector2(20, 160),
		Vector2(30, 140), Vector2(40, 100)
	]
	var volume: float = WaterManager.water_volume_for_range(points, 0, 4, 120.0, 10.0)
	_check(is_equal_approx(volume, 800.0), "water manager retains expected volume integration")
	var water_level: float = WaterManager.solve_water_level_for_volume(points, 0, 4, volume, 10.0, 28)
	_check(absf(water_level - 120.0) < 0.001, "water level solver preserves target volume")
	var pond: Dictionary = {"start_i": 0, "end_i": 4, "start_x": 0.0, "end_x": 40.0, "water_y": 120.0}
	var ponds: Array[Dictionary] = [pond]
	_check(not WaterManager.pond_at_x(ponds, points, 20.0, 10.0, 3.0).is_empty(), "submerged terrain registers pond")
	_check(WaterManager.pond_at_x(ponds, points, 0.0, 10.0, 3.0).is_empty(), "dry pond edge is excluded")
	_check(WaterManager.is_in_pond(ponds, points, Vector2(20, 130), 10.0, 3.0), "shell below water surface is submerged")
	_check(not WaterManager.is_in_pond(ponds, points, Vector2(20, 110), 10.0, 3.0), "shell above water surface stays dry")
	_check(is_equal_approx(WaterManager.tank_y_for_surface(ponds, points, 20.0, 10.0, 16.0, 3.0, 0.5), 128.0), "floating tank respects half-submergence")
	_check(is_equal_approx(WaterManager.movement_speed_mult_at_x(ponds, points, 20.0, 10.0, 3.0, 0.42), 0.42), "pond movement uses original water slowdown")
	_check(is_equal_approx(WaterManager.movement_speed_mult_at_x(ponds, points, 0.0, 10.0, 3.0, 0.42), 1.0), "dry ground retains normal speed")

func _ai_test_ground(_x: float) -> float:
	return 300.0

func _ai_test_score(pos: Vector2, angle: float, power_percent: float) -> float:
	return absf(pos.x - 600.0) * 0.1 + absf(angle - 36.0) + absf(power_percent - 22.0)

func _test_turn_ai_shot_planner() -> void:
	var config: Dictionary = {
		"max_score": 999999.0, "min_angle": 12, "max_angle": 48,
		"angle_step": 4, "min_power": 10, "max_power": 34,
		"power_step": 1, "score_randomness": 0.0,
		"move_offsets": [-80.0, 0.0, 100.0],
		"edge_margin": 70.0, "min_human_distance": 160.0,
		"tank_radius": 16.0, "move_penalty_per_pixel": 0.02,
		"move_chance": 1.0
	}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var scorer: Callable = Callable(self, "_ai_test_score")
	var shot: Dictionary = TurnAIShotPlanner.find_shot(rng, Vector2(600, 284), scorer, config)
	_check(is_equal_approx(float(shot["angle"]), 36.0), "planner selects lowest-scoring shot angle")
	_check(is_equal_approx(float(shot["power_percent"]), 22.0), "planner selects lowest-scoring shot power")
	_check(is_zero_approx(float(shot["score"])), "zero-noise planner preserves base shot score")
	var plan: Dictionary = TurnAIShotPlanner.find_plan(
		rng, Vector2(500, 284), Vector2(1200, 284), 1500.0,
		Callable(self, "_ai_test_ground"), scorer, config
	)
	_check(is_equal_approx(float(plan["move_x"]), 600.0), "planner prefers useful movement after move penalty")
	_check(is_equal_approx(float(plan["angle"]), 36.0), "planner searches angle over movement candidates")
	_check(is_equal_approx(float(plan["power_percent"]), 22.0), "planner searches power over movement candidates")
	_check(is_equal_approx(float(plan["score"]), 2.0), "planner includes movement penalty in best score")
	config["move_chance"] = -1.0
	var stationary: Dictionary = TurnAIShotPlanner.find_plan(
		rng, Vector2(500, 284), Vector2(1200, 284), 1500.0,
		Callable(self, "_ai_test_ground"), scorer, config
	)
	_check(is_equal_approx(float(stationary["move_x"]), 500.0), "stationary fallback preserves start position")
	_check(is_equal_approx(float(stationary["angle"]), 36.0), "stationary fallback independently recalculates aim")
	config["move_chance"] = 1.0
	config["min_human_distance"] = 1000.0
	var blocked: Dictionary = TurnAIShotPlanner.find_plan(
		rng, Vector2(500, 284), Vector2(600, 284), 1500.0,
		Callable(self, "_ai_test_ground"), scorer, config
	)
	_check(is_equal_approx(float(blocked["move_x"]), 500.0), "unsafe movement candidates are rejected")
	_check(is_equal_approx(float(blocked["angle"]), 45.0), "no valid candidate retains default angle")

func _ai_test_high_ground(_x: float) -> float:
	return 1000.0

func _ai_test_low_ground(_x: float) -> float:
	return 30.0

func _test_turn_ai_ballistic_scorer() -> void:
	var config: Dictionary = {
		"cannon_length": 0.0, "sim_dt": 1.0, "max_time": 2.0,
		"gravity": 10.0, "wind": 0.0, "world_width": 500.0,
		"floor_y": 1000.0
	}
	var scorer: Callable = Callable(self, "_ai_test_high_ground")
	var hit: float = TurnAIBallisticScorer.score(
		Vector2(200, 0), Vector2(180, 10), 0.0, 20.0, scorer, config
	)
	_check(is_zero_approx(hit), "trajectory scorer includes first simulated impact position")
	config["max_time"] = 0.0
	var static_distance: float = TurnAIBallisticScorer.score(
		Vector2(200, 0), Vector2(180, 10), 0.0, 20.0, scorer, config
	)
	_check(is_equal_approx(static_distance, sqrt(500.0)), "zero simulated time scores muzzle distance")
	config["max_time"] = 2.0
	var ground_hit: float = TurnAIBallisticScorer.score(
		Vector2(200, 0), Vector2(160, 30), 0.0, 20.0,
		Callable(self, "_ai_test_low_ground"), config
	)
	_check(is_zero_approx(ground_hit), "ground contact includes closest terrain impact")
	config["wind"] = 10.0
	var wind_hit: float = TurnAIBallisticScorer.score(
		Vector2(200, 0), Vector2(190, 10), 0.0, 20.0, scorer, config
	)
	_check(is_zero_approx(wind_hit), "wind changes the projectile trajectory before distance evaluation")

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
