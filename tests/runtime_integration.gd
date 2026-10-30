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
	_test_runtime_match_health_bridge()
	_test_runtime_projectile_bridge()
	_test_runtime_player_frame_bridge()
	_test_level_and_build_state_bridge()
	_test_level_session_configs()
	_test_runtime_radial_damage()
	_test_runtime_turn_completion()

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
