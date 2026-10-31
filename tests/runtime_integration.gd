extends SceneTree
## Exercises the *active scene and inheritance chain*, not mocked controllers.
## Run after `godot --headless --path . --import`.
## godot --headless --path . --script res://tests/runtime_integration.gd

const GAME_MENU_STATE: int = 4
const SINGLE_PLAYER_MENU_STATE: int = 1

var failures: Array[String] = []
var checks: int = 0
var game: Node2D = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	if scene == null:
		_check(false, "main scene resource loads")
		_finish()
		return

	game = scene.instantiate() as Node2D
	if game == null:
		_check(false, "main scene instantiates as Node2D")
		_finish()
		return

	root.add_child(game)
	# Let Godot run the real _ready() chain, building gameplay and menu controls.
	await process_frame
	# Keep background physics/AI/timers from racing deterministic assertions.
	game.set_process(false)
	_check(int(game.get("menu_state")) == 0, "scene starts at main menu")
	_check(game.get("menu_layer") != null, "scene creates menu layer")

	_test_campaign_navigation()
	await process_frame
	_test_campaign_map_drag()
	_test_campaign_level_launch()
	_test_hotseat_weapons_turns_and_fire()
	_test_cluster_split_runtime()
	_test_player_weapon_selection_component()
	_test_metadata_weapon_overrides()
	_test_composed_weapon_definition_session()
	_test_weapon_bridge_retirement()
	_test_runtime_match_health_bridge()
	_test_runtime_projectile_bridge()
	_test_runtime_player_frame_bridge()
	_test_level_and_build_state_bridge()
	_test_level_session_configs()
	_test_runtime_radial_damage()
	_test_runtime_turn_completion()
	_test_power_percent_layer_retirement()
	_test_active_world_movement_policy()
	_test_retired_tweaks_runtime_hooks()
	_test_menu_layout_policy_live()
	_test_composed_menu_view()
	_test_menu_layer_retirement()
	_test_water_manager_world_delegation()
	_test_turn_ai_ballistic_scorer_live()
	_test_turn_ai_planner_live()
	_test_realtime_ai_movement_planner_live()
	_test_steam_puff_effect_live()
	_test_realtime_cooldown_policy_live()
	_test_wind_meter_policy_live()
	_test_turn_ai_session_live()
	_test_menu_navigation_session_live()
	_test_composed_menu_screen_layouts_live()
	_test_mode_runtime_ancestor_retirement()
	_test_destroyed_smoke_session_live()
	_test_turn_ai_visual_aim_session_live()

	game.queue_free()
	await process_frame
	_finish()

func _test_campaign_navigation() -> void:
	game.call("_show_single_player_menu")
	_check(int(game.get("menu_state")) == SINGLE_PLAYER_MENU_STATE, "single-player menu opens")
	game.call("_on_campaign_pressed")
	var scroll: ScrollContainer = game.get("campaign_map_scroll") as ScrollContainer
	_check(scroll != null, "campaign creates a scrollable map")
	_check(scroll is CampaignMapView, "campaign uses the extracted map view")
	if scroll != null:
		var nodes: Array[Node] = scroll.find_children("*", "Button", true, false)
		var ready_count: int = 0
		var locked_count: int = 0
		for node: Node in nodes:
			var button: Button = node as Button
			if button == null:
				continue
			if button.text.begins_with("1") and not button.disabled:
				ready_count += 1
			elif button.disabled:
				locked_count += 1
		_check(ready_count == 1, "campaign has one available level node")
		_check(locked_count >= 5, "campaign locks future level nodes")
	var garage_button: Button = _find_menu_button("Tank Garage")
	_check(garage_button != null, "campaign displays Tank Garage action")
	if garage_button != null:
		garage_button.emit_signal("pressed")
		_check(game.get("campaign_map_scroll") == null, "garage replaces campaign map")
		var garage_controls: Array = game.get("menu_buttons")
		var disabled_upgrades: int = 0
		for control: Variant in garage_controls:
			if control is Button and (control as Button).disabled:
				disabled_upgrades += 1
		_check(disabled_upgrades >= 4, "extracted garage retains read-only upgrade previews")
		var garage_text: String = TankGarageView.summary_text(
			0,
			game.call("_tank_build_for_player", 0),
			game.get("tank_classes"),
			game.get("tank_upgrades"),
			game.get("tank_crew")
		)
		_check(garage_text.contains("Scout Tank"), "garage summary uses starting tank class")
		_check(garage_text.contains("Credits: 0"), "garage summary preserves starting credits")
		_check(_find_menu_button("Back") != null, "garage has Back action")
		var back: Button = _find_menu_button("Back")
		if back != null:
			back.emit_signal("pressed")
			_check(game.get("campaign_map_scroll") != null, "garage Back restores campaign map")

func _test_campaign_map_drag() -> void:
	var scroll: ScrollContainer = game.get("campaign_map_scroll") as ScrollContainer
	if scroll == null:
		_check(false, "map remains available for drag test")
		return
	var before: int = scroll.scroll_horizontal
	var swipe: InputEventScreenDrag = InputEventScreenDrag.new()
	swipe.relative = Vector2(-260.0, 0.0)
	game.call("_on_campaign_map_scroll_gui_input", swipe)
	_check(scroll.scroll_horizontal > before, "leftward finger drag pans map to the right")
	var moved: int = scroll.scroll_horizontal
	game.call("_scroll_campaign_map_by", -120.0)
	_check(scroll.scroll_horizontal < moved, "map scrolls back to the left")

func _test_campaign_level_launch() -> void:
	var scroll: ScrollContainer = game.get("campaign_map_scroll") as ScrollContainer
	if scroll == null:
		_check(false, "campaign map available for launch")
		return
	var buttons: Array[Node] = scroll.find_children("*", "Button", true, false)
	var first: Button = null
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and button.text.begins_with("1"):
			first = button
			break
	_check(first != null, "Level 1 button exists")
	if first != null:
		first.emit_signal("pressed")
		_check(int(game.get("menu_state")) == GAME_MENU_STATE, "Level 1 launches an actual match")
		_check(bool(game.get("single_player_mode")), "campaign starts in single-player mode")
		_check((game.get("level_session") as LevelSession).definition != null, "launched match has a level definition")

func _test_hotseat_weapons_turns_and_fire() -> void:
	game.call("_on_hotseat_pressed")
	_check(int(game.get("menu_state")) == GAME_MENU_STATE, "hotseat opens gameplay")
	_check(bool(game.get("hotseat_turn_start_pending")), "hotseat requires Start Turn handoff")
	_check(int(game.get("current_player")) == 0, "hotseat starts with player 1")
	game.call("_set_selected_weapon_for_current_player", WeaponCatalog.HEAVY)
	_check(str(game.get("selected_weapon")) == WeaponCatalog.HEAVY, "player 1 selects Heavy")
	# Skip a shot to exercise the actual turn-end and runtime/MatchState bridge.
	game.call("_end_turn_without_shot")
	_check(int(game.get("current_player")) == 1, "turn-end advances to player 2")
	_check(str(game.get("selected_weapon")) == WeaponCatalog.STANDARD, "player 2 starts with own Standard choice")
	_check(bool(game.get("hotseat_turn_start_pending")), "player 2 gets Start Turn gate")
	game.call("_set_selected_weapon_for_current_player", WeaponCatalog.CLUSTER)
	game.call("_end_turn_without_shot")
	_check(int(game.get("current_player")) == 0, "second turn-end returns to player 1")
	_check(str(game.get("selected_weapon")) == WeaponCatalog.HEAVY, "player 1 Heavy choice is restored")
	game.call("_end_turn_without_shot")
	_check(str(game.get("selected_weapon")) == WeaponCatalog.CLUSTER, "player 2 Cluster choice is restored")
	game.call("_end_turn_without_shot")
	_check(str(game.get("selected_weapon")) == WeaponCatalog.HEAVY, "player 1 weapon persists over multiple handoffs")

	# Run through real start-turn and shot code, bypassing only the duration
	# of the physical hold-to-charge gesture.
	game.call("_on_hotseat_start_turn_pressed")
	_check(not bool(game.get("hotseat_turn_start_pending")), "Start Turn unlocks actions")
	game.set("hotseat_release_in_progress", true)
	game.call("_on_fire_pressed")
	game.set("hotseat_release_in_progress", false)
	_check(bool(game.get("projectile_active")), "Heavy shot creates a live projectile")
	_check(str(game.get("turn_projectile_weapon")) == WeaponCatalog.HEAVY, "shot uses player 1 selected weapon")
	var initial_position: Vector2 = game.get("projectile_pos")
	game.call("_update_projectile", 0.02)
	var updated_position: Vector2 = game.get("projectile_pos")
	_check(updated_position.distance_to(initial_position) > 0.01, "projectile advances with real weapon physics")

	# Step the actual projectile to impact or world exit. This tests the complete
	# fire -> flight -> explosion path without wall-clock timing.
	var resolved: bool = not bool(game.get("projectile_active"))
	for step: int in range(600):
		if resolved:
			break
		game.call("_update_projectile", 0.02)
		resolved = not bool(game.get("projectile_active"))
	_check(resolved, "fired shell resolves within a bounded simulation")
	if resolved:
		_check(float(game.get("explosion_timer")) > 0.0, "impact starts an explosion")
		_check(bool(game.get("pending_advance_after_explosion_hold")) or bool(game.get("game_over")), "impact queues turn advance or ends match")
		if not bool(game.get("game_over")):
			# The gameplay frame loop normally decreases these timers.
			game.set("explosion_timer", 0.0)
			game.set("cluster_camera_hold_timer", 0.0)
			game.call("_maybe_advance_after_explosion_hold")
			_check(int(game.get("current_player")) == 1, "resolved shot advances to player 2")
			_check(bool(game.get("hotseat_turn_start_pending")), "next turn is gated for hotseat handoff")
	game.call("reset_match")
	_check(int(game.get("current_player")) == 0, "reset returns turn to player 1")
	_check(str(game.get("selected_weapon")) == WeaponCatalog.STANDARD, "reset restores default weapon")

func _test_cluster_split_runtime() -> void:
	# Exercise the legacy runtime entry points after removing their inheritance layer.
	_check(not bool(game.call("_weapon_should_split_on_descent", WeaponCatalog.CLUSTER, false, Vector2(0.0, -20.0))), "cluster waits for descent")
	_check(bool(game.call("_weapon_should_split_on_descent", WeaponCatalog.CLUSTER, false, Vector2(0.0, 20.0))), "cluster splits during descent")
	_check(not bool(game.call("_weapon_should_split_on_descent", WeaponCatalog.CLUSTER, true, Vector2(0.0, 20.0))), "cluster cannot split twice")
	_check(not bool(game.call("_weapon_should_split_on_descent", WeaponCatalog.STANDARD, false, Vector2(0.0, 20.0))), "standard shell does not split")
	var children: Array = game.call("_make_split_children", 0, WeaponCatalog.CLUSTER, Vector2(300.0, 200.0), Vector2(20.0, 10.0))
	_check(children.size() == 3, "cluster definition spawns three child shells")
	var no_children: Array = game.call("_make_split_children", 0, WeaponCatalog.STANDARD, Vector2(300.0, 200.0), Vector2(20.0, 10.0))
	_check(no_children.is_empty(), "non-splitting weapon creates no child projectiles")

	game.call("_on_hotseat_pressed")
	game.call("_on_hotseat_start_turn_pressed")
	game.call("_set_selected_weapon_for_current_player", WeaponCatalog.CLUSTER)
	game.set("hotseat_release_in_progress", true)
	game.call("_on_fire_pressed")
	game.set("hotseat_release_in_progress", false)
	_check(bool(game.get("projectile_active")), "cluster launches as a live shell")
	# Force the projectile into descent and call the actual game update.
	# This deterministically tests cluster splitting without waiting for an apex.
	game.set("projectile_vel", Vector2(120.0, 10.0))
	game.call("_update_projectile", 0.016)
	_check(not bool(game.get("projectile_active")), "descending cluster parent is replaced")
	_check(bool(game.get("turn_projectile_split_done")), "cluster marks split completed")
	var turn_children: Array = game.get("turn_projectiles")
	_check(turn_children.size() == 3, "live cluster creates exactly three turn children")
	_check(game.get("turn_cluster_camera_pos") != Vector2.INF, "cluster split retains camera focus position")

func _test_player_weapon_selection_component() -> void:
	var selections: PlayerWeaponSelection = PlayerWeaponSelection.new()
	selections.reset(WeaponCatalog.STANDARD)
	_check(selections.choices.size() == 2, "new match stores both player weapon slots")
	var registry: Dictionary = WeaponRegistry.build_default_definitions()
	var loadout: WeaponLoadout = WeaponLoadout.from_registry(registry, WeaponCatalog.STANDARD)
	selections.save(0, WeaponCatalog.HEAVY, WeaponCatalog.STANDARD)
	selections.save(1, WeaponCatalog.CLUSTER, WeaponCatalog.STANDARD)
	_check(selections.load(0, loadout, WeaponCatalog.STANDARD) == WeaponCatalog.HEAVY, "player 1 weapon persists")
	_check(selections.load(1, loadout, WeaponCatalog.STANDARD) == WeaponCatalog.CLUSTER, "player 2 weapon persists")
	_check(selections.load(2, loadout, WeaponCatalog.STANDARD) == WeaponCatalog.STANDARD, "missing player defaults to Standard")
	selections.save(-1, WeaponCatalog.HEAVY, WeaponCatalog.STANDARD)
	_check(selections.choices.size() == 2, "negative player index is ignored")
	selections.reset(WeaponCatalog.STANDARD)
	_check(selections.load(0, loadout, WeaponCatalog.STANDARD) == WeaponCatalog.STANDARD, "new match resets per-player loadout")
	_check(game.get("player_weapon_selection") is PlayerWeaponSelection, "active game composes weapon selection component")

func _test_metadata_weapon_overrides() -> void:
	var definitions: Dictionary = game.get("weapon_definitions")
	var heavy_radius: float = float(WeaponRegistry.value(definitions, WeaponCatalog.HEAVY, "explosion_radius", 62.0))
	var heavy_damage: int = int(WeaponRegistry.value(definitions, WeaponCatalog.HEAVY, "direct_damage", 75))
	_check(is_equal_approx(float(game.call("_weapon_explosion_radius", WeaponCatalog.HEAVY)), heavy_radius), "active explosion radius uses weapon registry")
	_check(int(game.call("_weapon_direct_damage", WeaponCatalog.HEAVY)) == heavy_damage, "active direct damage uses weapon registry")
	var cluster_pos: Vector2 = Vector2(400.0, 300.0)
	game.call("_split_turn_cluster_projectile", cluster_pos, Vector2(50.0, 30.0))
	_check(game.get("turn_cluster_camera_pos") == cluster_pos, "split retains cluster camera position")
	_check((game.get("turn_projectiles") as Array).size() == 3, "split retains registry-driven child count")

func _test_runtime_match_health_bridge() -> void:
	game.call("_on_hotseat_pressed")
	var state: MatchState = game.get("match_state") as MatchState
	var controller: MatchController = game.get("match_controller") as MatchController
	_check(state != null and controller != null, "active scene exposes match controller and state")
	var adapter: MatchRuntimeSynchronizer = game.get("match_runtime_sync") as MatchRuntimeSynchronizer
	_check(adapter != null and adapter.state == state and adapter.controller == controller, "game composes match synchronizer instead of inheriting bridge")
	var damaged: Array[int] = [87, 43]
	game.set("tank_health", damaged)
	game.call("_sync_match_state_from_runtime")
	_check(state.tank_health == [87, 43], "live health sync updates both tanks")
	_check(not controller.is_game_over() and state.winner_index == -1, "damage without destruction keeps match alive")
	var host_wins: Array[int] = [87, 0]
	game.set("tank_health", host_wins)
	game.call("_sync_health_state_to_match_controller")
	_check(bool(game.get("game_over")), "runtime game over follows controller")
	_check(controller.winner_index() == 0, "controller selects surviving player 1")
	var draw: Array[int] = [0, 0]
	game.set("tank_health", draw)
	game.call("_sync_match_state_from_runtime")
	_check(controller.is_game_over() and controller.winner_index() == -1, "live simultaneous defeat produces a draw")
	_check(state.tank_health == [0, 0], "controller preserves the complete health snapshot")
	game.call("reset_match")
	_check((game.get("tank_health") as Array) == [100, 100], "runtime reset restores both tank health values")
	_check(state.tank_health == [100, 100], "match state reset restores both tank health values")
	_check(not controller.is_game_over() and controller.winner_index() == -1, "reset clears winner and terminal state")

func _test_runtime_projectile_bridge() -> void:
	game.call("_on_hotseat_pressed")
	var state: MatchState = game.get("match_state") as MatchState
	var flight_pos: Vector2 = Vector2(350.0, 130.0)
	var flight_vel: Vector2 = Vector2(120.0, -30.0)
	game.set("projectile_active", true)
	game.set("projectile_pos", flight_pos)
	game.set("projectile_vel", flight_vel)
	game.call("_sync_projectile_state_to_match_controller")
	_check(state.projectile_active and state.projectile_pos == flight_pos, "active game projectile mirrors into MatchState")
	_check(state.projectile_vel == flight_vel, "active game projectile velocity mirrors into MatchState")
	var impact_pos: Vector2 = Vector2(510.0, 420.0)
	game.set("projectile_active", false)
	game.set("explosion_pos", impact_pos)
	game.set("explosion_timer", 0.45)
	game.call("_sync_projectile_state_to_match_controller")
	_check(not state.projectile_active, "impact clears controller projectile")
	_check(state.explosion_pos == impact_pos and is_equal_approx(state.explosion_timer, 0.45), "impact starts controller explosion state")
	game.set("explosion_pos", Vector2.INF)
	game.set("explosion_timer", 0.0)
	game.call("_sync_projectile_state_to_match_controller")
	_check(state.explosion_pos == Vector2.INF and is_zero_approx(state.explosion_timer), "controller explosion clears when runtime hold ends")
	game.call("reset_match")
	_check(not state.projectile_active and state.explosion_pos == Vector2.INF, "reset clears controller projectile lifecycle")

func _test_runtime_player_frame_bridge() -> void:
	game.call("_on_hotseat_pressed")
	var state: MatchState = game.get("match_state") as MatchState
	var angles: Array[float] = [33.0, 68.0]
	var powers: Array[float] = [710.0, 1080.0]
	var percentages: Array[float] = [25.0, 85.0]
	game.set("player_angles", angles)
	game.set("player_powers", powers)
	game.set("player_power_percents", percentages)
	game.set("wind", -20.0)
	game.set("turn_timer", 9.5)
	game.call("_sync_match_state_from_runtime")
	_check(state.player_angles == angles, "live player angles sync through controller")
	_check(state.player_powers == powers, "live player power sync through controller")
	_check(state.player_power_percents == percentages, "live power percentages sync through controller")
	_check(is_equal_approx(state.wind, -20.0) and is_equal_approx(state.turn_timer, 9.5), "live frame adopts wind and turn timer")
	_check(state.current_player == int(game.get("current_player")), "live frame matches turn owner")
	_check(is_equal_approx(state.active_world_width, float(game.get("active_world_width"))), "live frame captures world width")
	game.call("reset_match")
	_check(state.player_angles == [45.0, 45.0], "live reset resynchronizes default player aim")

func _test_level_and_build_state_bridge() -> void:
	game.call("_on_hotseat_pressed")
	var state: MatchState = game.get("match_state") as MatchState
	game.call("_select_level", LevelRegistry.LEVEL_SNOWY_RIDGE)
	game.call("reset_match")
	_check(is_equal_approx(state.wind, float(game.get("wind"))), "level wind agrees with controller state after reset")
	_check(state.tank_builds.size() >= 2, "reset initializes both tank builds")
	var builds: Array[TankBuildState] = [
		TankProgressionRegistry.default_player_build(0),
		TankProgressionRegistry.default_player_build(1)
	]
	builds[0].credits = 175
	game.set("player_tank_builds", builds)
	game.call("_sync_match_state_tank_builds")
	_check(state.tank_build_for_player(0).credits == 175, "progression build reaches MatchState through controller")
	_check(state.tank_build_for_player(1).tank_class_id == builds[1].tank_class_id, "second player build stays independent")
	game.call("reset_match")
	_check(state.tank_build_for_player(0).credits == 0, "match reset rebuilds default progression credits")
	game.call("_select_level", LevelRegistry.LEVEL_DEFAULT)
	game.call("reset_match")

func _test_runtime_radial_damage() -> void:
	game.call("_on_hotseat_pressed")
	var state: MatchState = game.get("match_state") as MatchState
	var controller: MatchController = game.get("match_controller") as MatchController
	var impact: Vector2 = Vector2(400.0, 150.0)
	var far: Vector2 = Vector2(1300.0, 150.0)
	var base_health: Array[int] = [100, 100]
	var positions: Array[Vector2] = [impact, far]
	game.set("tank_positions", positions)
	game.set("tank_health", base_health)
	var standard_damage: int = int(game.call("_weapon_direct_damage", WeaponCatalog.STANDARD))
	game.call("_apply_weapon_damage", impact, WeaponCatalog.STANDARD)
	_check(int((game.get("tank_health") as Array)[0]) == maxi(0, 100 - standard_damage), "actual standard shell applies registry direct damage")
	_check(int((game.get("tank_health") as Array)[1]) == 100, "actual blast leaves distant tank untouched")
	_check(state.tank_health == game.get("tank_health"), "weapon damage updates runtime and controller identically")

	var direct_radius: float = float(game.call("_weapon_direct_radius", WeaponCatalog.HEAVY))
	var blast_radius: float = float(game.call("_weapon_explosion_radius", WeaponCatalog.HEAVY))
	var midpoint: float = direct_radius + (blast_radius - direct_radius) * 0.5
	var targets: Array[Vector2] = [far, impact + Vector2(midpoint, 0.0)]
	game.set("tank_positions", targets)
	game.set("tank_health", base_health.duplicate())
	var expected_splash: int = MatchDamagePolicy.radial_damage(
		impact, targets[1], direct_radius, blast_radius,
		int(game.call("_weapon_direct_damage", WeaponCatalog.HEAVY)),
		int(game.call("_weapon_splash_damage", WeaponCatalog.HEAVY)), 4
	)
	game.call("_apply_weapon_damage", impact, WeaponCatalog.HEAVY)
	_check(int((game.get("tank_health") as Array)[1]) == 100 - expected_splash, "heavy shell uses defined splash formula")
	_check(state.tank_health == game.get("tank_health"), "heavy splash matches controller health state")
	_check(not controller.is_game_over(), "nonlethal splash keeps the match active")

	var both_positions: Array[Vector2] = [impact, impact]
	var both_health: Array[int] = [1, 1]
	game.set("tank_positions", both_positions)
	game.set("tank_health", both_health)
	game.call("_apply_explosion_damage", impact)
	_check((game.get("tank_health") as Array) == [0, 0], "legacy explosion can destroy both tanks")
	_check(controller.is_game_over() and controller.winner_index() == -1, "live dual destruction is a draw")
	game.call("reset_match")
	_check(state.tank_health == [100, 100] and not controller.is_game_over(), "reset clears damage and draw")

func _test_runtime_turn_completion() -> void:
	game.call("_on_hotseat_pressed")
	var state: MatchState = game.get("match_state") as MatchState
	var expected_charge: float = 63.0
	var expected_angle: float = 36.0
	game.set("angle_deg", expected_angle)
	game.set("power_percent", expected_charge)
	var expected_power: float = float(game.call("_power_from_percent", expected_charge))
	game.set("power", expected_power)
	game.call("_set_selected_weapon_for_current_player", WeaponCatalog.HEAVY)
	game.call("_end_turn_without_shot")
	_check(int(game.get("current_player")) == 1 and state.current_player == 1, "no-shot end hands turn to player 2")
	_check(is_equal_approx(state.player_angles[0], expected_angle), "controller stores outgoing player angle")
	_check(is_equal_approx(state.player_power_percents[0], expected_charge), "controller stores outgoing player charge")
	_check(is_equal_approx(state.player_powers[0], expected_power), "controller stores outgoing player power")
	_check((game.get("player_angles") as Array) == state.player_angles, "legacy aim array matches authoritative MatchState")
	_check((game.get("player_power_percents") as Array) == state.player_power_percents, "legacy charge array matches MatchState")
	game.call("_end_turn_without_shot")
	_check(int(game.get("current_player")) == 0, "turn cycles back to player 1")
	_check(is_equal_approx(float(game.get("angle_deg")), expected_angle), "saved player angle is restored after handoff")
	_check(is_equal_approx(float(game.get("power_percent")), expected_charge), "saved charge is restored after handoff")
	_check(str(game.get("selected_weapon")) == WeaponCatalog.HEAVY, "outgoing weapon choice remains independent of turn controller")

func _test_level_session_configs() -> void:
	game.call("_on_hotseat_pressed")
	var session: LevelSession = game.get("level_session") as LevelSession
	_check(session != null, "active game composes a level session")
	_check(session.definitions.size() == 4, "level session provides all four existing level profiles")

	game.call("_select_level", LevelRegistry.LEVEL_WIDE_HILLS)
	game.call("reset_match")
	_check(session.selected_id == LevelRegistry.LEVEL_WIDE_HILLS, "wide hills selection persists across reset")
	_check(game.call("_active_level_name") == "Wide Hills", "active level name uses level session")
	var width: float = float(game.get("active_world_width"))
	_check(width >= session.definition.world_width_min and width <= session.definition.world_width_max, "world generation respects wide-hills width bounds")
	_check(is_equal_approx(float(game.get("wind")), (game.get("match_state") as MatchState).wind), "wide hills wind remains controller-synchronized")

	game.call("_select_level", LevelRegistry.LEVEL_SNOWY_RIDGE)
	game.call("reset_match")
	_check(session.selected_id == LevelRegistry.LEVEL_SNOWY_RIDGE, "snowy ridge selection persists")
	_check(is_equal_approx(float(game.call("_level_snow_line_y")), session.definition.snow_line_y), "snow line matches selected definition")
	_check(game.call("_active_level_name") == "Snowy Ridge", "snowy level display name preserved")

	game.call("_select_level", LevelRegistry.LEVEL_WATER_BASIN)
	game.call("reset_match")
	_check(is_equal_approx(session.pond_chance(0.0), 1.0), "water basin retains guaranteed pond generation attempt")
	_check(game.call("_active_level_name") == "Water Basin", "water level name preserved")

	game.call("_select_level", LevelRegistry.LEVEL_DEFAULT)
	game.call("reset_match")
	_check(game.call("_active_level_name") == "Default Hills", "default level is restored")
	_check(session.restricted_loadout() == null, "unrestricted default level uses standard weapon set")

	var custom_id: String = "restricted_test"
	session.definitions[custom_id] = LevelDefinition.new({
		"id": custom_id,
		"default_weapon_ids": [WeaponCatalog.STANDARD, WeaponCatalog.HEAVY]
	})
	game.call("_select_level", custom_id)
	var loadout: WeaponLoadout = game.get("active_weapon_loadout") as WeaponLoadout
	_check(loadout.weapon_ids.size() == 2, "custom level applies explicit weapon restrictions")
	_check(not loadout.has_weapon(WeaponCatalog.CLUSTER), "restricted level excludes Cluster")
	game.call("_select_level", LevelRegistry.LEVEL_DEFAULT)
	game.call("reset_match")
	_check((game.get("active_weapon_loadout") as WeaponLoadout).has_weapon(WeaponCatalog.CLUSTER), "default level restores full weapon loadout")
	session.definitions.erase(custom_id)

func _test_composed_weapon_definition_session() -> void:
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	_check(session != null, "active scene composes a weapon-definition session")
	_check(game.get("weapon_definitions") == session.definitions, "legacy weapon registry mirrors session definitions")
	_check(game.get("active_weapon_loadout") == session.loadout, "legacy loadout points to session owner")
	game.call("_select_level", LevelRegistry.LEVEL_DEFAULT)
	_check(session.loadout.has_weapon(WeaponCatalog.CLUSTER), "default level allows Cluster in composed session")
	var level_id: String = "weapon_session_restricted"
	var level_session: LevelSession = game.get("level_session") as LevelSession
	level_session.definitions[level_id] = LevelDefinition.new({
		"id": level_id,
		"default_weapon_ids": [WeaponCatalog.STANDARD, WeaponCatalog.HEAVY]
	})
	game.call("_select_level", level_id)
	_check(not session.loadout.has_weapon(WeaponCatalog.CLUSTER), "restricted level updates composed weapon loadout")
	_check(game.get("active_weapon_loadout") == session.loadout, "legacy menu reads same restricted loadout")
	game.call("_select_level", LevelRegistry.LEVEL_DEFAULT)
	level_session.definitions.erase(level_id)
	_check(session.loadout.has_weapon(WeaponCatalog.CLUSTER), "default level restores composed loadout")

func _test_weapon_bridge_retirement() -> void:
	# The scene must retain its weapon metadata/selection API without
	# inheriting the deleted WeaponDefinitionRuntimeBridge.
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	_check(session != null, "active game owns composed weapon-definition session")
	_check(game.call("_weapon_definition", WeaponCatalog.HEAVY) == session.definition(WeaponCatalog.HEAVY), "compatibility weapon lookup resolves to composed registry")
	_check(game.call("_weapon_display_name", WeaponCatalog.CLUSTER) == session.display_name(WeaponCatalog.CLUSTER), "weapon display names still resolve")
	_check(game.call("_weapon_has_split_behavior", WeaponCatalog.CLUSTER), "legacy cluster split metadata remains available")
	_check(not game.call("_weapon_has_split_behavior", WeaponCatalog.STANDARD), "standard weapon still has no split behavior")
	_check(game.call("_weapon_child_count", WeaponCatalog.CLUSTER) == 3, "cluster child count remains definition-driven")
	_check(game.call("_weapon_should_split_on_descent", WeaponCatalog.CLUSTER, false, Vector2(0.0, 10.0)), "descending cluster split remains available")
	_check(not game.call("_weapon_should_split_on_descent", WeaponCatalog.CLUSTER, true, Vector2(0.0, 10.0)), "repeat split is suppressed")
	game.call("_select_level", LevelRegistry.LEVEL_DEFAULT)
	game.call("_set_selected_weapon_for_current_player", WeaponCatalog.CLUSTER)
	_check(str(game.get("selected_weapon")) == WeaponCatalog.CLUSTER, "normal loadout permits cluster selection")
	var custom: String = "bridge_retire_restricted"
	var level_session: LevelSession = game.get("level_session") as LevelSession
	level_session.definitions[custom] = LevelDefinition.new({
		"id": custom,
		"default_weapon_ids": [WeaponCatalog.STANDARD, WeaponCatalog.HEAVY]
	})
	game.call("_select_level", custom)
	_check(not session.loadout.has_weapon(WeaponCatalog.CLUSTER), "session restricts cluster on custom level")
	_check(str(game.get("selected_weapon")) == WeaponCatalog.STANDARD, "legacy selected weapon is sanitized by new loadout")
	game.call("_select_level", LevelRegistry.LEVEL_DEFAULT)
	level_session.definitions.erase(custom)
	game.call("reset_match")
	_check(game.get("active_weapon_loadout") == session.loadout, "match reset keeps legacy loadout alias synchronized")

func _test_power_percent_layer_retirement() -> void:
	# Exercise the actual scene after retiring MainStablePowerPercent.gd.
	game.call("_on_hotseat_pressed")
	var policy_minimum: float = 400.0
	var policy_maximum: float = 1200.0
	_check(is_equal_approx(float(game.call("_power_from_percent", 0.0)), policy_minimum), "legacy launch method honors minimum power")
	_check(is_equal_approx(float(game.call("_power_from_percent", 100.0)), policy_maximum), "legacy launch method honors maximum power")
	_check(is_equal_approx(float(game.call("_power_from_percent", -20.0)), policy_minimum), "legacy launch method clamps negative power")
	_check(is_equal_approx(float(game.call("_power_from_percent", 150.0)), policy_maximum), "legacy launch method clamps power above 100 percent")
	var charge: float = 64.0
	game.set("power_percent", charge)
	game.set("power", float(game.call("_power_from_percent", charge)))
	game.call("_end_turn_without_shot")
	_check(int(game.get("current_player")) == 1, "power handoff advances to second player")
	game.call("_end_turn_without_shot")
	_check(int(game.get("current_player")) == 0, "power handoff returns to original player")
	_check(is_equal_approx(float(game.get("power_percent")), charge), "legacy power percentage survives roundtrip")
	_check(is_equal_approx(float(game.get("power")), float(game.call("_power_from_percent", charge))), "launch power restored consistently")
	game.call("reset_match")
	_check(is_equal_approx(float(game.get("power_percent")), 50.0), "power percentage resets to default")
	_check((game.get("player_power_percents") as Array) == [50.0, 50.0], "both player power settings reset")

func _test_active_world_movement_policy() -> void:
	game.call("_on_hotseat_pressed")
	game.call("_select_level", LevelRegistry.LEVEL_DEFAULT)
	game.call("reset_match")
	var positions: Array = game.get("tank_positions")
	var before_x: float = (positions[0] as Vector2).x
	var other_x: float = (positions[1] as Vector2).x
	var width: float = float(game.get("active_world_width"))
	game.set("mobile_right_pressed", true)
	game.call("_update_tank_movement", 0.10)
	game.set("mobile_right_pressed", false)
	var after_x: float = ((game.get("tank_positions") as Array)[0] as Vector2).x
	_check(after_x >= before_x, "right movement respects positive input direction")
	_check(after_x <= width - 45.0, "active world movement honors horizontal boundary")
	_check(LegacyInputMotionPolicy.can_move_without_overlap(after_x, other_x), "active world movement keeps tanks separated")
	_check(after_x > before_x, "active movement callback actually moves the tank")
	game.call("reset_match")

func _test_retired_tweaks_runtime_hooks() -> void:
	# Verify live initialization still goes through the former Tweaks
	# engine entry points, now on MainWithMenus.
	var slider: HSlider = game.get("power_slider") as HSlider
	var fire: Button = game.get("fire_button") as Button
	var reset: Button = game.get("reset_button") as Button
	_check(slider != null and is_equal_approx(slider.min_value, 0.0), "main scene retains percent-based slider minimum")
	_check(slider != null and is_equal_approx(slider.max_value, 100.0), "main scene retains percent-based slider maximum")
	_check(fire != null and not fire.visible, "base fire control remains hidden")
	_check(reset != null and not reset.visible, "base reset control remains hidden")
	game.call("_on_hotseat_pressed")
	game.call("reset_match")
	_check((game.get("player_power_percents") as Array) == [50.0, 50.0], "legacy power slots initialize without Tweaks parent")
	_check(is_equal_approx(float(game.call("_power_from_percent", 50.0)), 800.0), "composed power conversion remains on active game")
	game.call("_update_ui")
	_check(game.get("angle_label") != null and game.get("power_label") != null, "base label refresh remains callable")
	_check((game.get("terrain_points") as Array).size() > 50, "active world terrain still generated by TerrainManager")

func _test_menu_layout_policy_live() -> void:
	game.call("_show_main_menu")
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var anchor: Vector2 = Vector2(0.5, 0.54)
	var button_size: Vector2 = Vector2(310.0, 72.0)
	var expected: Vector2 = MainMenuPresentation.anchored_position(viewport_size, anchor, button_size)
	_check(game.call("_anchored_position", anchor, button_size) == expected, "live menu layout delegates to composed presentation policy")
	_check((game.get("menu_buttons") as Array).size() == 3, "main menu still constructs three controls")
	game.call("_show_single_player_menu")
	_check((game.get("menu_buttons") as Array).size() == 3, "single-player menu still constructs three controls")
	game.call("_show_main_menu")
	_check(int(game.get("menu_state")) == 0, "menu navigation returns home after presentation extraction")

func _test_composed_menu_view() -> void:
	game.call("_show_main_menu")
	var view: MainMenuView = game.get("menu_view") as MainMenuView
	_check(view != null, "main game composes an independent menu view")
	_check(game.get("menu_layer") == view.layer, "legacy menu layer shares view-owned canvas")
	_check((game.get("menu_buttons") as Array).size() == view.controls.size(), "legacy menu controls agree with view")
	_check(view.controls.size() == 3, "composed view builds home-menu controls")
	game.call("_show_single_player_menu")
	_check(view.controls.size() == 3, "composed view rebuilds single-player controls")
	game.call("_show_main_menu")
	_check(view.controls.size() == 3, "view clears old controls before home-menu rebuild")
	_check(game.get("menu_buttons") == view.controls, "legacy control array remains linked after clear")
	_check(view.layer != null and is_instance_valid(view.layer), "menu view keeps one attached canvas")

func _test_menu_layer_retirement() -> void:
	# Verify mode runtime now provides all menu contracts without the
	# removed MainWithMenus ancestor.
	game.call("_show_main_menu")
	_check(int(game.get("menu_state")) == 0, "retired menu layer still opens home")
	game.call("_on_single_player_pressed")
	_check(int(game.get("menu_state")) == 1, "single player navigation still works")
	_check((game.get("menu_buttons") as Array).size() == 3, "single player menu retains Quick/Campaign/Back")
	game.call("_show_main_menu")
	game.call("_on_multiplayer_pressed")
	_check(int(game.get("menu_state")) == 3, "multiplayer navigation still works")
	_check((game.get("menu_buttons") as Array).size() == 3, "multiplayer menu preserves three actions")
	game.call("_show_main_menu")
	game.call("_on_options_pressed")
	_check((game.get("menu_buttons") as Array).size() == 3, "options placeholder retains title, notice and back")
	game.call("_show_main_menu")
	game.call("_on_hotseat_pressed")
	_check(int(game.get("menu_state")) == 4, "hotseat still launches through menu coordinator")
	_check(game.get("menu_view") is MainMenuView, "mode runtime composes menu view after inheritance retirement")
	_check((game.get("player_power_percents") as Array) == [50.0, 50.0], "gameplay setup retains charge defaults")

func _test_water_manager_world_delegation() -> void:
	var saved_points: Array[Vector2] = game.get("terrain_points")
	var saved_ponds: Array[Dictionary] = game.get("ponds")
	var points: Array[Vector2] = [
		Vector2(0, 100), Vector2(10, 140), Vector2(20, 160),
		Vector2(30, 140), Vector2(40, 100)
	]
	var ponds: Array[Dictionary] = [
		{"start_i": 0, "end_i": 4, "start_x": 0.0, "end_x": 40.0, "water_y": 120.0}
	]
	game.set("terrain_points", points)
	game.set("ponds", ponds)
	_check(is_equal_approx(float(game.call("_water_volume_for_range", 0, 4, 120.0)), 800.0), "active world adopts WaterManager volume integration")
	_check(absf(float(game.call("_solve_water_level_for_volume", 0, 4, 800.0)) - 120.0) < 0.001, "active world delegates water level solver")
	_check(not (game.call("_pond_at_x", 20.0) as Dictionary).is_empty(), "active world detects pond over deep valley")
	_check((game.call("_pond_at_x", 0.0) as Dictionary).is_empty(), "active world excludes exposed pond boundary")
	_check(bool(game.call("_is_in_pond", Vector2(20, 130))), "active projectile water collision still detects submersion")
	_check(not bool(game.call("_is_in_pond", Vector2(20, 110))), "active projectile does not collide above surface")
	_check(is_equal_approx(float(game.call("_tank_y_for_surface", 0, 20.0)), 128.0), "active floating tank keeps the original submergence")
	_check(is_equal_approx(float(game.call("_movement_speed_mult_at_x", 20.0)), 0.42), "active movement retains water slowdown")
	_check(is_equal_approx(float(game.call("_movement_speed_mult_at_x", 0.0)), 1.0), "active movement retains dry terrain speed")
	game.set("terrain_points", saved_points)
	game.set("ponds", saved_ponds)

func _test_turn_ai_planner_live() -> void:
	game.call("_on_hotseat_pressed")
	var ai_position: Vector2 = (game.get("tank_positions") as Array)[1]
	var rng: RandomNumberGenerator = game.get("rng") as RandomNumberGenerator
	var config: Dictionary = game.call("_turn_ai_search_config")
	_check(config.has("move_offsets") and config.has("score_randomness"), "game exposes current AI search policy")
	rng.seed = 1937
	var plan: Dictionary = game.call("_find_ai_plan")
	_check(plan.has("angle") and plan.has("power_percent") and plan.has("move_x"), "live planner produces complete move and shot")
	_check(float(plan["angle"]) >= 12.0 and float(plan["angle"]) <= 84.0, "live AI aim uses configured limits")
	_check(float(plan["power_percent"]) >= 15.0 and float(plan["power_percent"]) <= 100.0, "live AI power uses configured limits")
	_check(float(plan["move_x"]) >= 70.0 and float(plan["move_x"]) <= float(game.get("active_world_width")) - 70.0, "live AI move stays inside safe bounds")
	_check((game.get("tank_positions") as Array)[1] == ai_position, "AI planning does not move tank before shot")
	rng.seed = 1937
	var repeated: Dictionary = game.call("_find_ai_plan")
	_check(plan == repeated, "same terrain and RNG seed reproduce identical AI plan")
	game.call("reset_match")

func _test_turn_ai_ballistic_scorer_live() -> void:
	game.call("_on_hotseat_pressed")
	var positions: Array = game.get("tank_positions")
	var shooter_pos: Vector2 = positions[1]
	var human_pos: Vector2 = positions[0]
	var rng: RandomNumberGenerator = game.get("rng") as RandomNumberGenerator
	rng.seed = 5512
	var target_pos: Vector2 = human_pos + Vector2(
		rng.randf_range(-28.0, 28.0), rng.randf_range(-8.0, 8.0)
	)
	var config: Dictionary = {
		"cannon_length": 48.0, "sim_dt": 0.055,
		"max_time": 5.5, "gravity": float(game.get("gravity")),
		"wind": float(game.get("wind")),
		"world_width": float(game.get("active_world_width")),
		"floor_y": float(game.call("_bottom_floor_y"))
	}
	var expected: float = TurnAIBallisticScorer.score(
		shooter_pos, target_pos, 45.0,
		float(game.call("_power_from_percent", 55.0)),
		Callable(game, "_ground_y_at_x"), config
	)
	rng.seed = 5512
	var actual: float = float(game.call("_score_ai_shot_from_position", shooter_pos, 45.0, 55.0))
	_check(is_equal_approx(actual, expected), "live AI scorer preserves jittered target and ballistic trajectory")
	rng.seed = 5512
	var repeated: float = float(game.call("_score_ai_shot_from_position", shooter_pos, 45.0, 55.0))
	_check(is_equal_approx(actual, repeated), "live trajectory scoring preserves RNG reproducibility")
	_check(actual >= 0.0 and is_finite(actual), "live scorer returns a finite nonnegative miss distance")
	game.call("reset_match")

func _test_realtime_ai_movement_planner_live() -> void:
	game.call("_on_quick_game_pressed")
	var positions: Array = game.get("tank_positions")
	var ai_pos_before: Vector2 = positions[1]
	var rng: RandomNumberGenerator = game.get("rng") as RandomNumberGenerator
	var config: Dictionary = {
		"move_chance": 0.50, "edge_margin": 70.0,
		"min_human_distance": 160.0, "tank_radius": 16.0
	}
	rng.seed = 20261030
	var expected: float = RealtimeAIMovementPlanner.choose_target_x(
		rng, positions[1], positions[0], float(game.get("active_world_width")),
		Callable(game, "_ground_y_at_x"), Callable(game, "_find_ai_shot_from_position"), config
	)
	var expected_next_random: float = rng.randf()
	rng.seed = 20261030
	game.call("_choose_realtime_ai_move_target")
	_check(is_equal_approx(float(game.get("rt_ai_target_x")), expected),
		"live realtime AI delegates movement-target selection without changing candidate scores")
	_check(is_equal_approx(rng.randf(), expected_next_random),
		"live realtime AI movement preserves shot-search RNG draw sequence")
	_check(ai_pos_before == (game.get("tank_positions") as Array)[1],
		"realtime AI movement planning does not physically move the tank")
	game.call("reset_match")

func _test_steam_puff_effect_live() -> void:
	game.call("_on_quick_game_pressed")
	var puff: Dictionary = {"pos": Vector2(210.0, 310.0), "age": 0.2, "life": 0.95, "drift": -8.0}
	var puffs: Array[Dictionary] = [puff]
	game.set("steam_puffs", puffs)
	game.call("_update_steam_puffs", 0.25)
	var active: Array = game.get("steam_puffs")
	_check(active.size() == 1 and active[0] == puff,
		"active realtime game delegates steam simulation to composed effect")
	_check(is_equal_approx(float(puff["age"]), 0.45),
		"active steam update retains age integration")
	_check((puff["pos"] as Vector2).distance_to(Vector2(208.0, 301.5)) < 0.0001,
		"active steam update retains wind drift and rise")
	game.call("_update_steam_puffs", 0.50)
	_check((game.get("steam_puffs") as Array).is_empty(),
		"active realtime steam expires at original lifetime")
	game.call("reset_match")

func _test_realtime_cooldown_policy_live() -> void:
	game.call("_on_quick_game_pressed")
	game.set("rt_player_fire_cooldown", 0.08)
	game.set("rt_ai_fire_cooldown", 0.50)
	game.set("rt_ai_move_cooldown", 1.0)
	game.set("rt_movement_exhaust_cooldown", 0.05)
	game.set("rt_movement_energy", 0.2)
	game.set("movement_was_overheated", false)
	game.call("_update_realtime_cooldowns", 0.10)
	_check(is_zero_approx(float(game.get("rt_player_fire_cooldown"))) and
		is_equal_approx(float(game.get("rt_ai_fire_cooldown")), 0.4),
		"active realtime fire timers use composed cooldown policy")
	_check(is_equal_approx(float(game.get("rt_ai_move_cooldown")), 0.9),
		"active realtime movement cooldown uses composed policy")
	_check(is_zero_approx(float(game.get("rt_movement_exhaust_cooldown"))) and
		is_equal_approx(float(game.get("rt_movement_energy")), 0.75),
		"active overheat expiry restores one-quarter movement energy")
	_check(bool(game.get("movement_was_overheated")),
		"active runtime preserves overheated marker on expiry frame")
	game.call("_update_realtime_cooldowns", 0.02)
	_check(not bool(game.get("movement_was_overheated")),
		"active runtime clears overheat marker on subsequent frame")
	game.call("reset_match")

func _test_wind_meter_policy_live() -> void:
	game.call("_on_quick_game_pressed")
	var old_wind: float = float(game.get("wind"))
	game.set("wind", -42.5)
	_check(is_equal_approx(float(game.call("_wind_display_value")), -5.0),
		"live game delegates normalized wind readout to composed policy")
	var weak_color: Color = game.call("_wind_strength_color", 0.3)
	var strong_color: Color = game.call("_wind_strength_color", 0.95)
	_check(weak_color.is_equal_approx(WindMeterPolicy.strength_color(0.3)) and
		strong_color.is_equal_approx(WindMeterPolicy.strength_color(0.95)),
		"active wind meter color matches standalone policy")
	game.set("wind", old_wind)
	game.call("reset_match")

func _test_turn_ai_session_live() -> void:
	game.call("_on_hotseat_pressed")
	var session: TurnAITurnSession = game.get("turn_ai_session") as TurnAITurnSession
	_check(session != null, "active game composes turn AI state owner")
	game.set("ai_pending_turn", true)
	game.set("ai_think_timer", 0.6)
	_check(session.pending and is_equal_approx(session.think_timer, 0.6),
		"legacy AI phase properties forward writes into session")
	session.begin(1.75)
	_check(bool(game.get("ai_pending_turn")) and
		is_equal_approx(float(game.get("ai_think_timer")), 1.75),
		"legacy AI phase properties read state from session")
	game.set("game_mode", 1)
	game.set("current_player", 1)
	game.set("projectile_active", false)
	game.set("game_over", false)
	game.set("overlay_open", false)
	game.set("explosion_timer", 0.0)
	_check(bool(game.call("_is_ai_turn_active")),
		"active game routes quick-game AI turn eligibility through session")
	game.set("explosion_timer", 0.3)
	_check(bool(game.call("_is_ai_turn_waiting_for_explosion")),
		"active game delegates AI explosion wait eligibility")
	game.call("_process_ai_turn_waiting_for_explosion", 0.35)
	_check(is_zero_approx(float(game.get("explosion_timer"))) and not session.pending,
		"AI explosion expiry clears composed turn pending state")
	game.call("reset_match")
	_check(not session.pending and is_zero_approx(session.think_timer),
		"runtime reset clears the same composed session")

func _test_menu_navigation_session_live() -> void:
	game.call("_show_main_menu")
	var navigation: MainMenuNavigationSession = game.get("menu_navigation") as MainMenuNavigationSession
	_check(navigation != null and navigation.screen == 0 and not navigation.single_player,
		"active scene composes menu navigation state owner")
	game.call("_show_single_player_menu")
	_check(navigation.screen == 1 and navigation.single_player and
		bool(game.get("single_player_mode")),
		"single-player menu updates composed state and inherited compatibility value")
	game.call("_on_options_pressed")
	_check(navigation.screen == 2 and navigation.single_player,
		"options navigation retains prior single-player selection")
	game.call("_show_multiplayer_menu")
	_check(navigation.screen == 3 and not navigation.single_player,
		"multiplayer menu resets single-player selection")
	game.set("menu_state", 1)
	game.set("single_player_mode", true)
	_check(navigation.screen == 1 and navigation.single_player,
		"legacy menu fields forward external writes to composed owner")
	game.call("_on_hotseat_pressed")
	_check(navigation.screen == 4 and not navigation.single_player and
		int(game.get("menu_state")) == 4,
		"hotseat game entry keeps existing controls and state transition ordering")
	game.call("_show_main_menu")
	_check(navigation.screen == 0 and not navigation.single_player,
		"active scene returns home through composed navigation state")

func _test_composed_menu_screen_layouts_live() -> void:
	var view: MainMenuView = game.get("menu_view") as MainMenuView
	var viewport_size: Vector2 = game.get_viewport_rect().size
	game.call("_show_main_menu")
	_check(view.controls.size() == 3, "composed menu builder creates three home actions")
	_check(view.controls[0].position == MainMenuPresentation.anchored_position(
		viewport_size, Vector2(0.5, 0.54), Vector2(310, 72)),
		"home screen keeps original single-player button placement")
	var single_button: BaseButton = view.controls[0] as BaseButton
	_check(single_button != null, "home menu first control remains clickable")
	if single_button != null:
		single_button.pressed.emit()
	_check(int(game.get("menu_state")) == 1 and view.controls.size() == 3,
		"composed home screen retains single-player callback wiring")
	_check(view.controls[2].position == MainMenuPresentation.anchored_position(
		viewport_size, Vector2(0.5, 0.82), Vector2(210, 58)),
		"single-player screen retains back-button placement")
	var back_button: BaseButton = view.controls[2] as BaseButton
	if back_button != null:
		back_button.pressed.emit()
	_check(int(game.get("menu_state")) == 0,
		"single-player back control still navigates home")
	game.call("_show_multiplayer_menu")
	_check(view.controls.size() == 3 and view.controls[1].position == MainMenuPresentation.anchored_position(
		viewport_size, Vector2(0.5, 0.69), Vector2(310, 72)),
		"composed multiplayer menu retains online option placement")
	# Active online navigation is overridden by the full multiplayer facade.
	# Exercise the reusable fallback placeholder directly.
	game.call("_show_placeholder_menu", "Options")
	_check(view.controls.size() == 3 and (view.controls[0] as Label).text == "Options" and
		(view.controls[1] as Label).text == "Coming soon",
		"composed placeholder retains its title and unavailable notice")
	var placeholder_back: BaseButton = view.controls[2] as BaseButton
	if placeholder_back != null:
		placeholder_back.pressed.emit()
	_check(int(game.get("menu_state")) == 0 and view.controls.size() == 3,
		"composed fallback placeholder back action returns home")
	game.call("_show_main_menu")

func _test_mode_runtime_ancestor_retirement() -> void:
	var active_script: Script = game.get_script() as Script
	var chain: Array[String] = []
	while active_script != null:
		chain.append(active_script.resource_path)
		active_script = active_script.get_base_script()
	_check(chain.size() == 8, "active Godot scene inherits exactly eight script layers")
	_check(not chain.has("res://scripts/modes/ModeRuntimeBridge.gd"),
		"retired ModeRuntimeBridge is not an active parent")
	_check(chain.has("res://scripts/modes/WorldRuntimeBridge.gd") and
		chain.has("res://scripts/Main.gd"),
		"active world runtime extends legacy root directly")
	game.call("_show_main_menu")
	_check(int(game.get("menu_state")) == 0 and (game.get("menu_buttons") as Array).size() == 3,
		"world runtime preserves original main menu initialization")
	game.call("_on_hotseat_pressed")
	_check(int(game.get("menu_state")) == 4 and (game.get("tank_positions") as Array).size() == 2,
		"world runtime preserves hotseat lifecycle and live match state")
	game.call("_show_main_menu")

func _test_destroyed_smoke_session_live() -> void:
	game.call("_on_hotseat_pressed")
	var session: DestroyedTankSmokeSession = game.get("destroyed_smoke_session") as DestroyedTankSmokeSession
	_check(session != null, "active weapon runtime composes destroyed smoke lifecycle owner")
	var destroyed_health: Array[int] = [100, 0]
	game.set("tank_health", destroyed_health)
	_check((game.get("tank_health") as Array) == [100, 0],
		"live test sets typed tank health fixture before smoke begins")
	game.call("_start_destroyed_tank_smoke")
	_check(session.tank_index == 1 and int(game.get("destroyed_tank_index")) == 1,
		"active destroyed tank selection reads through compatibility property")
	_check((game.get("destroyed_smoke_puffs") as Array).size() == 7,
		"active destroyed tank still spawns seven initial puffs")
	game.call("_start_destroyed_tank_smoke")
	_check((game.get("destroyed_smoke_puffs") as Array).size() == 7,
		"repeated smoke start does not duplicate initial burst")
	game.call("_update_destroyed_smoke", 0.05)
	_check((game.get("destroyed_smoke_puffs") as Array).size() == 8 and
		is_equal_approx(float(game.get("destroyed_smoke_timer")), 0.16),
		"first active frame produces one periodic puff with original timer reset")
	game.set("destroyed_smoke_timer", 0.04)
	_check(is_equal_approx(session.spawn_timer, 0.04),
		"compatibility smoke timer forwards writes to session")
	game.call("_update_destroyed_smoke", 0.02)
	_check((game.get("destroyed_smoke_puffs") as Array).size() == 8,
		"active smoke does not generate a puff before timer expiration")
	game.call("_update_destroyed_smoke", 0.03)
	_check((game.get("destroyed_smoke_puffs") as Array).size() == 9,
		"active smoke spawns the next puff when session interval expires")
	game.call("reset_match")
	_check(session.tank_index == -1 and is_zero_approx(session.spawn_timer) and
		(game.get("destroyed_smoke_puffs") as Array).is_empty(),
		"active match reset clears composed smoke state and effect objects")

func _test_turn_ai_visual_aim_session_live() -> void:
	game.call("_on_hotseat_pressed")
	var session: TurnAIVisualAimSession = game.get("turn_ai_visual") as TurnAIVisualAimSession
	_check(session != null and session.plan.is_empty(),
		"active weapon runtime composes turn AI visual session")
	var rng: RandomNumberGenerator = game.get("rng") as RandomNumberGenerator
	rng.seed = 20261030
	game.call("_begin_ai_turn")
	_check(bool(game.get("ai_pending_turn")) and not session.plan.is_empty(),
		"active turn AI begins a timed turn with a stored visual plan")
	_check((game.get("ai_visual_shot_plan") as Dictionary) == session.plan and
		is_equal_approx(float(game.get("ai_visual_target_angle")), session.target_angle),
		"legacy visual aim properties forward to the composed session")
	_check(is_equal_approx(session.target_angle, float(session.plan.get("angle", -1.0))) and
		is_equal_approx(session.target_power_percent, float(session.plan.get("power_percent", -1.0))),
		"active turn visual targets agree with the chosen noisy shot plan")
	var before_angle: float = float((game.get("player_angles") as Array)[1])
	var expected: float = move_toward(before_angle, session.target_angle, 32.0 * 0.25)
	game.call("_update_ai_visual_aim", 0.25)
	_check(is_equal_approx(float((game.get("player_angles") as Array)[1]), expected),
		"active turn AI barrel animation uses composed session slew policy")
	game.call("reset_match")
	_check(session.plan.is_empty(), "match reset clears the composed turn AI visual plan")

func _find_menu_button(text_to_find: String) -> Button:
	var controls: Array = game.get("menu_buttons")
	for control: Variant in controls:
		if control is Button:
			var button: Button = control as Button
			if is_instance_valid(button) and button.text == text_to_find:
				return button
	return null

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: runtime integration (%d assertions)" % checks)
		quit(0)
		return
	printerr("FAIL: runtime integration (%d/%d assertions failed)" % [failures.size(), checks])
	quit(1)
