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
	_test_single_weapon_metadata_owner()
	_test_pruned_weapon_collision_dispatch_live()
	_test_shared_shell_impact_policy_live()
	_test_legacy_turn_contact_matches_shells_live()
	_test_retired_world_mode_helpers_live()
	_test_composed_weapon_definition_session()
	_test_canonical_weapon_alias_forwarding_live()
	_test_weapon_bridge_retirement()
	_test_runtime_match_health_bridge()
	_test_runtime_projectile_bridge()
	_test_turn_projectile_session_reset_live()
	_test_shadowed_bridge_removal_live()
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
	_test_weapon_startup_layout_live()
	_test_mode_power_ui_single_owner_live()
	_test_composed_weapon_menu_view_live()
	_test_weapon_menu_owner_migration_live()
	_test_weapon_frame_policy_live()
	_test_weapon_lifecycle_consolidation_live()
	_test_six_layer_weapon_domain_ownership_live()
	_test_scene_adapter_domain_grouping_live()
	_test_rendering_owner_migration_live()
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
	_test_destroyed_smoke_game_ownership_live()
	_test_turn_ai_visual_aim_session_live()
	_test_canonical_match_charge_and_ai_reset()
	_test_turn_ai_world_ownership_live()
	_test_identical_method_override_cleanup()
	_test_canonical_pond_reflow_live()
	_test_shared_projectile_motion_live()
	_test_single_realtime_shell_launch_owner_live()
	_test_shared_realtime_charge_release_live()
	_test_shared_projectile_launch_geometry_live()
	_test_bouncer_weapon_policy_live()
	_test_shared_turn_realtime_bouncer_contact_live()
	_test_metadata_bouncer_profile_dispatch()
	_test_machine_gun_projectile_camera_focus()
	_test_composed_weapon_burst_session_live()
	_test_metadata_burst_profile_dispatch()
	_test_shared_turn_advance_clearance_live()
	_test_shared_scene_weapon_impact_lifecycle()
	_test_shadowed_mode_explosion_hooks_retired()
	_test_special_weapon_terrain_delegation_live()
	_test_laser_controller_authority_live()
	_test_metadata_laser_profile_fire_dispatch()

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
	# Split policy comes from the canonical session; only live spawning needs
	# to remain a scene-facing compatibility callback.
	var weapon_session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	_check(not weapon_session.should_split_on_descent(WeaponCatalog.CLUSTER, false, Vector2(0.0, -20.0)), "cluster waits for descent")
	_check(weapon_session.should_split_on_descent(WeaponCatalog.CLUSTER, false, Vector2(0.0, 20.0)), "cluster splits during descent")
	_check(not weapon_session.should_split_on_descent(WeaponCatalog.CLUSTER, true, Vector2(0.0, 20.0)), "cluster cannot split twice")
	_check(not weapon_session.should_split_on_descent(WeaponCatalog.STANDARD, false, Vector2(0.0, 20.0)), "standard shell does not split")
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
	var active_builds: Array[TankBuildState] = game.get("player_tank_builds")
	_check(active_builds.size() == 2 and
		state.tank_build_for_player(0) == active_builds[0] and
		state.tank_build_for_player(1) == active_builds[1],
		"one post-parent publish installs the progression-owned builds in MatchState")
	var progression_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameProgressionFacade.gd"
	)
	var construction_start: int = progression_source.find(
		"\nfunc _initialize_player_tank_builds() -> void:")
	var construction_end: int = progression_source.find(
		"\nfunc ", construction_start + 2)
	var construction_body: String = progression_source.substr(
		construction_start, construction_end - construction_start)
	_check(construction_start > 0 and
		not construction_body.contains("_sync_match_state_tank_builds()"),
		"build construction has no early MatchState writes before parent reset")
	var startup_start: int = progression_source.find(
		"\nfunc _initialize_progression_state() -> void:")
	var startup_end: int = progression_source.find(
		"\nfunc ", startup_start + 2)
	var startup_body: String = progression_source.substr(
		startup_start, startup_end - startup_start)
	_check(startup_body.contains("_initialize_player_tank_builds()") and
		startup_body.contains("_sync_match_state_tank_builds()"),
		"initial progression setup still publishes the default builds")
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
	# Exercise the active special-weapons explosion dispatch and UI result:
	# the controller, not another scene health check, owns winner selection.
	game.call("reset_match")
	game.set("tank_positions", both_positions)
	game.set("tank_health", both_health)
	game.call("_explode_turn_weapon", impact, WeaponCatalog.STANDARD, false)
	_check(bool(game.get("game_over")) and controller.winner_index() == -1,
		"live turn explosion preserves the controller's draw outcome")
	var popup: Label = game.get("end_label") as Label
	_check(popup != null and popup.text.begins_with("Draw!"),
		"game-over popup reports simultaneous defeat as a draw")
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
	_check(game.call("_weapon_display_name", WeaponCatalog.CLUSTER) == session.display_name(WeaponCatalog.CLUSTER), "weapon display names still resolve")
	_check(game.call("_weapon_has_split_behavior", WeaponCatalog.CLUSTER), "legacy cluster split metadata remains available")
	_check(not game.call("_weapon_has_split_behavior", WeaponCatalog.STANDARD), "standard weapon still has no split behavior")
	_check(game.call("_weapon_child_count", WeaponCatalog.CLUSTER) == 3, "cluster child count remains definition-driven")
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
	# The world runtime is the one scene owner of the water draw adapters.
	var world_draw_source: String = FileAccess.get_file_as_string(
		"res://scripts/modes/WorldRuntimeBridge.gd"
	)
	for method_name: String in [
		"_draw_ponds_under_ground", "_draw_water_surfaces", "_draw_water_surface_segment_world"
	]:
		_check(world_draw_source.contains("\nfunc " + method_name + "("),
			"world runtime owns water drawing: " + method_name)
	# The active scene resolves these through the existing WorldRuntimeBridge,
	# not duplicate MainGame adapters.
	var main_source: String = FileAccess.get_file_as_string("res://scripts/core/MainGame.gd")
	for name: String in [
		"_pond_at_x", "_is_in_pond", "_tank_y_for_surface",
		"_movement_speed_mult_at_x", "_water_volume_for_range",
		"_solve_water_level_for_volume"
	]:
		_check(not main_source.contains("\nfunc " + name + "("),
			"water callback is singly owned by WorldRuntimeBridge: " + name)
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
	_check(chain.size() == 6, "active Godot scene inherits exactly six script layers")
	_check(not chain.has("res://scripts/weapons/WeaponRuntimeBridge.gd"),
		"retired weapon bridge no longer appears in the active chain")
	_check(not chain.has("res://scripts/modes/ModeRuntimeBridge.gd"),
		"retired ModeRuntimeBridge is not an active parent")
	_check(chain.has("res://scripts/modes/WorldRuntimeBridge.gd") and
		not chain.has("res://scripts/Main.gd"),
		"active world runtime no longer inherits the legacy prototype")
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
	_check((game.get("destroyed_smoke_puffs") as Array) == session.puffs,
		"legacy smoke puff property reads the session-owned collection")
	var replacement_puffs: Array[Dictionary] = [
		EffectsManager.make_puff(Vector2(40.0, 60.0), 1.0, 0.0)
	]
	game.set("destroyed_smoke_puffs", replacement_puffs)
	_check(session.puffs == replacement_puffs,
		"legacy smoke puff property writes reach the same composed session")
	game.set("destroyed_smoke_timer", 0.02)
	game.call("_update_destroyed_smoke", 0.1)
	_check(session.puffs.size() == 2 and
		(game.get("destroyed_smoke_puffs") as Array) == session.puffs,
		"live smoke update ages session-owned puffs and preserves compatibility alias")
	game.call("reset_match")
	_check(session.tank_index == -1 and is_zero_approx(session.spawn_timer) and
		(game.get("destroyed_smoke_puffs") as Array).is_empty() and session.puffs.is_empty(),
		"active match reset clears composed smoke state and effect objects")

func _test_turn_ai_visual_aim_session_live() -> void:
	game.call("_on_hotseat_pressed")
	var session: TurnAIVisualAimSession = game.get("turn_ai_visual") as TurnAIVisualAimSession
	var turn_session: TurnAITurnSession = game.get("turn_ai_session") as TurnAITurnSession
	_check(session != null and turn_session != null and
		session == turn_session.visual and session.plan.is_empty(),
		"bridge visual AI aliases the same world-owned turn session")
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
	var staged_shot: Dictionary = session.shot_settings(
		float((game.get("tank_positions") as Array)[1].x), 0.0, 90.0
	)
	_check(is_equal_approx(float(staged_shot["move_x"]),
		float(session.plan.get("move_x", (game.get("tank_positions") as Array)[1].x))) and
		is_equal_approx(float(staged_shot["power_percent"]),
		clampf(float(session.plan.get("power_percent", 55.0)), 0.0, 100.0)),
		"live AI shot interpretation reads the same composed visual plan without mutation")
	game.call("reset_match")
	_check(session.plan.is_empty() and not turn_session.pending and
		is_zero_approx(turn_session.think_timer),
		"one inherited reset clears the world AI timer and bridge visual plan")

func _test_canonical_match_charge_and_ai_reset() -> void:
	# Seed stale states and invoke the complete inherited reset dispatch.
	# Charge lifecycles should use their existing reset hooks; the world AI
	# session should reset both timer and visual plan only once.
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	var world_source: String = FileAccess.get_file_as_string(
		"res://scripts/modes/WorldRuntimeBridge.gd"
	)
	var main_reset_start: int = main_source.find("\nfunc reset_match() -> void:")
	var main_reset_end: int = main_source.find("\nfunc ", main_reset_start + 2)
	var main_reset: String = main_source.substr(
		main_reset_start, main_reset_end - main_reset_start
	)
	_check(main_reset.contains("_reset_hotseat_charge()") and
		not main_reset.contains("turn_ai_visual.clear_plan()"),
		"MainGame reset delegates hotseat charging and leaves turn-AI visual to session reset")
	var world_reset_start: int = world_source.find("\nfunc reset_match() -> void:")
	var world_reset_end: int = world_source.find("\nfunc ", world_reset_start + 2)
	var world_reset: String = world_source.substr(
		world_reset_start, world_reset_end - world_reset_start
	)
	_check(world_reset.contains("_reset_realtime_charge_state()") and
		world_source.contains("turn_ai_session.reset()"),
		"world reset delegates realtime charge and owns single turn-AI session reset")
	game.call("_on_hotseat_pressed")
	var turn: TurnAITurnSession = game.get("turn_ai_session") as TurnAITurnSession
	var visual: TurnAIVisualAimSession = game.get("turn_ai_visual") as TurnAIVisualAimSession
	_check(turn != null and visual == turn.visual,
		"match reset exercises the same composed turn-AI session")
	if turn == null or visual == null:
		return
	turn.begin(1.8)
	visual.plan = {"angle": 63.0, "power_percent": 73.0}
	game.set("hotseat_fire_button_held", true)
	game.set("hotseat_keyboard_fire_held", true)
	game.set("hotseat_charge_time", 0.8)
	game.set("hotseat_charge_percent", 76.0)
	game.set("rt_fire_button_held", true)
	game.set("rt_keyboard_fire_held", true)
	game.set("rt_fire_charge_time", 0.75)
	game.set("rt_fire_charge_percent", 72.0)
	game.set("rt_player_shell_active", true)
	game.call("reset_match")
	_check(not turn.pending and is_zero_approx(turn.think_timer) and
		visual.plan.is_empty(), "one inherited reset clears both timer and visual AI plan")
	_check(not bool(game.get("hotseat_fire_button_held")) and
		not bool(game.get("hotseat_keyboard_fire_held")) and
		is_zero_approx(float(game.get("hotseat_charge_time"))) and
		is_zero_approx(float(game.get("hotseat_charge_percent"))),
		"hotseat charging resets through the original release-state owner")
	_check(not bool(game.get("rt_fire_button_held")) and
		not bool(game.get("rt_keyboard_fire_held")) and
		not bool(game.get("rt_player_shell_active")) and
		is_zero_approx(float(game.get("rt_fire_charge_time"))) and
		is_zero_approx(float(game.get("rt_fire_charge_percent"))),
		"realtime charging and active shell state reset together")
	var mobile_fire: Button = game.get("mobile_fire_button") as Button
	_check(mobile_fire != null and
		(mobile_fire.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.is_equal_approx(
			MobileControls.fire_charge_color(0.0)),
		"match reset restores original uncharged mobile FIRE appearance")
	game.call("_on_quick_game_pressed")
	game.set("rt_fire_button_held", true)
	game.set("rt_keyboard_fire_held", true)
	game.set("rt_fire_charge_time", 0.6)
	game.set("rt_fire_charge_percent", 82.0)
	game.call("_setup_realtime_single_player")
	_check(not bool(game.get("rt_fire_button_held")) and
		not bool(game.get("rt_keyboard_fire_held")) and
		is_zero_approx(float(game.get("rt_fire_charge_time"))) and
		is_zero_approx(float(game.get("rt_fire_charge_percent"))),
		"realtime mode setup and match reset use the same canonical charge reset")
	game.call("reset_match")

func _test_identical_method_override_cleanup() -> void:
	# MainGame now owns compatibility hooks previously inherited via the
	# retired weapon bridge; the original projectile behavior must remain intact.
	var main_script: Script = load("res://scripts/core/MainGame.gd") as Script
	_check(main_script != null, "six-layer MainGame script remains loadable")
	if main_script == null:
		return
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	for name: String in [
		"_update_projectile", "_weapon_direct_damage",
		"_weapon_explosion_radius", "_has_active_realtime_shell_for_owner"
	]:
		_check(main_source.contains("\nfunc " + name + "("),
			"MainGame exposes the former bridge compatibility hook " + name)
	_check(not FileAccess.file_exists("res://scripts/weapons/WeaponRuntimeBridge.gd"),
		"retired WeaponRuntimeBridge file is absent")
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var heavy: WeaponDefinition = session.definition(WeaponCatalog.HEAVY)
	var old_damage: int = heavy.direct_damage
	heavy.direct_damage = old_damage + 17
	_check(int(game.call("_weapon_direct_damage", WeaponCatalog.HEAVY)) == old_damage + 17,
		"active weapon stats still resolve from mutable definition session, not legacy catalog")
	heavy.direct_damage = old_damage

	game.call("_on_hotseat_pressed")
	var initial_pos: Vector2 = Vector2(320.0, 30.0)
	var initial_vel: Vector2 = Vector2(40.0, -20.0)
	var delta: float = 0.016
	var expected: Dictionary = ProjectileManager.step_legacy_projectile(
		initial_pos, initial_vel, float(game.get("gravity")), float(game.get("wind")), delta
	)
	game.set("current_player", 0)
	game.set("projectile_active", true)
	game.set("turn_projectile_weapon", WeaponCatalog.STANDARD)
	game.set("turn_projectile_split_done", false)
	game.set("projectile_pos", initial_pos)
	game.set("projectile_vel", initial_vel)
	game.call("_update_projectile", delta)
	_check((game.get("projectile_pos") as Vector2).is_equal_approx(expected["pos"]) and
		(game.get("projectile_vel") as Vector2).is_equal_approx(expected["vel"]),
		"special-weapons super call reaches identical inherited projectile integrator")
	_check(bool(game.get("projectile_active")),
		"deduplicated projectile update does not prematurely terminate a shell")
	game.call("reset_match")

func _test_canonical_pond_reflow_live() -> void:
	# This synthetic basin has a fixed stored volume and a deeper cell after
	# a terrain change. Both the inherited hook and the live-game path must
	# reach the exact same connected-basin WaterManager algorithm.
	game.call("_on_hotseat_pressed")
	var previous_points: Array[Vector2] = game.get("terrain_points")
	var previous_ponds: Array[Dictionary] = game.get("ponds")
	var points: Array[Vector2] = [
		Vector2(0.0, 100.0), Vector2(10.0, 140.0),
		Vector2(20.0, 170.0), Vector2(30.0, 140.0),
		Vector2(40.0, 100.0)
	]
	var pond: Dictionary = {
		"start_i": 0, "end_i": 4, "start_x": 0.0, "end_x": 40.0,
		"water_y": 120.0, "volume": 800.0
	}
	game.set("terrain_points", points)
	var expected: Dictionary = WaterManager.reflow_single_pond(points, pond, 10.0, 2.0, 3.0, 28)
	var observed: Dictionary = game.call("_reflow_single_pond", pond.duplicate(true), 20.0)
	_check(observed == expected, "live pond reflow matches the authoritative connected-basin manager")
	var far_change: Dictionary = game.call("_reflow_single_pond", pond.duplicate(true), 1000.0)
	_check(far_change == expected, "reflow ignores changed-X search bias as the prior active scene did")
	_check(is_equal_approx(float(observed.get("volume", 0.0)), 800.0),
		"pond reflow preserves its stored water-volume target")
	if observed.has("water_y"):
		var actual_volume: float = WaterManager.water_volume_for_range(
			points, int(observed.get("start_i", 0)), int(observed.get("end_i", 4)),
			float(observed["water_y"]), 10.0
		)
		_check(absf(actual_volume - 800.0) < 0.05,
			"connected-basin surface conserves actual synthetic basin volume")
	var ponds: Array[Dictionary] = [pond.duplicate(true)]
	game.set("ponds", ponds)
	game.call("_reflow_water_after_terrain_change", 20.0)
	var updated: Array = game.get("ponds")
	_check(updated.size() == 1 and (updated[0] as Dictionary) == expected,
		"terrain reflow loop delegates through the one canonical pond implementation")
	game.set("terrain_points", previous_points)
	game.set("ponds", previous_ponds)
	game.call("reset_match")

func _test_shared_projectile_motion_live() -> void:
	game.call("_on_hotseat_pressed")
	var safe_pos: Vector2 = Vector2(540.0, 100.0)
	var initial_vel: Vector2 = Vector2(90.0, -60.0)
	var gravity: float = float(game.get("gravity"))
	var wind: float = float(game.get("wind"))
	var delta: float = 0.025
	var expected: Dictionary = ProjectileManager.step_legacy_projectile(
		safe_pos, initial_vel, gravity, wind, delta
	)
	game.set("projectile_active", true)
	game.set("projectile_pos", safe_pos)
	game.set("projectile_vel", initial_vel)
	game.set("turn_projectile_weapon", WeaponCatalog.STANDARD)
	game.call("_update_projectile", delta)
	_check(game.get("projectile_pos") == expected["pos"] and
		game.get("projectile_vel") == expected["vel"] and
		bool(game.get("projectile_active")),
		"active turn scene uses the canonical numerical motion step")
	game.call("reset_match")

func _test_single_realtime_shell_launch_owner_live() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	var start: int = source.find("func _fire_realtime_projectile(")
	var finish: int = source.find("\nfunc ", start + 4)
	var fire_body: String = source.substr(start, finish - start)
	_check(fire_body.contains("_spawn_weapon_shell(owner, weapon, shot_angle, shot_power_percent, true)") and
		not fire_body.contains("ProjectileFactory.make_fired_shell(") and
		not fire_body.contains("rt_projectiles.pop_front()") and
		not fire_body.contains("_trigger_fire_fx(") and
		source.contains("func _spawn_weapon_shell("),
		"one launch owner handles normal, custom and burst shells without redundant factory paths")

	game.call("_on_quick_game_pressed")
	var dummy: Array[Dictionary] = []
	var positions: Array = game.get("tank_positions")
	var human_shell: Dictionary = ProjectileFactory.make_shell(
		0, WeaponCatalog.HEAVY, Vector2(260.0, 50.0), Vector2(25.0, -10.0)
	)
	# Six shells at capacity: first one should be evicted when the AI fires.
	dummy.append(ProjectileFactory.make_shell(
		1, WeaponCatalog.STANDARD, Vector2(180.0, 20.0), Vector2.ZERO
	))
	dummy.append(human_shell)
	for j: int in range(4):
		dummy.append(ProjectileFactory.make_shell(
			1, WeaponCatalog.STANDARD, Vector2(370.0 + j, 20.0), Vector2.ZERO
		))
	game.set("rt_projectiles", dummy)
	game.set("rt_player_shell_active", true)
	var ai_angle: float = 32.0
	var ai_percent: float = 56.0
	var player_angles: Array[float] = game.get("player_angles")
	var player_percents: Array[float] = game.get("player_power_percents")
	player_angles[1] = ai_angle
	player_percents[1] = ai_percent
	var expected: Dictionary = ProjectileFactory.make_fired_shell(
		1, WeaponCatalog.STANDARD, positions[1], -1.0, ai_angle,
		float(game.call("_power_from_percent", ai_percent)), 48.0
	)
	game.call("_fire_realtime_projectile", 1)
	var after: Array = game.get("rt_projectiles")
	_check(after.size() == 6 and
		(after[0] as Dictionary).get("weapon", "") == WeaponCatalog.HEAVY and
		(after.back() as Dictionary).get("pos", Vector2.INF) == expected["pos"] and
		(after.back() as Dictionary).get("vel", Vector2.INF) == expected["vel"],
		"normal AI shot uses shared geometry and evicts oldest shell at capacity")
	_check(bool(game.get("rt_player_shell_active")),
		"AI launch does not clear active human shell availability")
	# Removing the last human shell via capacity eviction clears only the
	# human flag; AI rounds remain in flight.
	var ai_only: Array[Dictionary] = []
	ai_only.append(human_shell)
	for j: int in range(5):
		ai_only.append(ProjectileFactory.make_shell(
			1, WeaponCatalog.STANDARD, Vector2(500.0 + j, 20.0), Vector2.ZERO
		))
	game.set("rt_projectiles", ai_only)
	game.call("_fire_realtime_projectile", 1)
	_check((game.get("rt_projectiles") as Array).size() == 6 and
		not bool(game.get("rt_player_shell_active")),
		"capacity eviction recomputes human availability when last human shell is dropped")
	game.call("reset_match")

func _test_shared_realtime_charge_release_live() -> void:
	var base_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	var special_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	_check(base_source.contains("func _release_realtime_charged_shot()") and
		not special_source.contains("func _release_realtime_charged_shot()") and
		base_source.contains("ProjectileManager.has_shell_for_owner("),
		"one charge-release scene owner handles Laser, Machine Gun and ordinary shells")

	game.call("_on_quick_game_pressed")
	game.set("selected_weapon", WeaponRegistry.WEAPON_LASER)
	game.set("angle_deg", 75.0)
	game.set("rt_fire_charge_percent", 68.0)
	game.call("_release_realtime_charged_shot")
	var player_angles: Array[float] = game.get("player_angles")
	var player_powers: Array[float] = game.get("player_power_percents")
	_check(not bool(game.get("rt_player_shell_active")) and
		(game.get("rt_projectiles") as Array).is_empty() and
		bool(game.get("quickgame_player_shot_hide_trajectory")) and
		is_zero_approx(float(game.get("rt_fire_charge_percent"))),
		"instant Laser clears charge and hides trajectory without occupying a shell slot")
	_check(is_equal_approx(player_angles[0], 75.0) and
		is_equal_approx(player_powers[0], 68.0),
		"Laser charge now commits same player aim/power state as an ordinary shot")

	game.call("reset_match")
	game.call("_on_quick_game_pressed")
	game.set("selected_weapon", WeaponRegistry.WEAPON_MACHINE_GUN)
	game.set("angle_deg", 42.0)
	game.set("rt_fire_charge_percent", 63.0)
	game.call("_release_realtime_charged_shot")
	player_angles = game.get("player_angles")
	player_powers = game.get("player_power_percents")
	var burst: WeaponBurstSession = game.get("weapon_burst") as WeaponBurstSession
	_check(burst.active and (game.get("rt_projectiles") as Array).size() == 1 and
		bool(game.get("rt_player_shell_active")) and
		bool(game.get("quickgame_player_shot_hide_trajectory")) and
		is_zero_approx(float(game.get("rt_fire_charge_percent"))),
		"Machine Gun charge starts one burst and occupies the human fire slot")
	_check(is_equal_approx(player_angles[0], 42.0) and
		is_equal_approx(player_powers[0], 63.0),
		"Machine Gun charge shares canonical player angle and power commit")
	game.call("reset_match")

func _test_shared_projectile_launch_geometry_live() -> void:
	game.call("_on_quick_game_pressed")
	game.set("selected_weapon", WeaponCatalog.STANDARD)
	var positions: Array = game.get("tank_positions")
	var angle: float = float(game.get("angle_deg"))
	var power_percent: float = float(game.get("power_percent"))
	var force: float = float(game.call("_power_from_percent", power_percent))
	var cannon_length: float = 48.0
	var baseline: Dictionary = ProjectileFactory.make_fired_shell(
		0, WeaponCatalog.STANDARD, positions[0], 1.0, angle, force, cannon_length
	)
	game.call("_fire_realtime_projectile", 0)
	var ordinary: Array = game.get("rt_projectiles")
	_check(not ordinary.is_empty(), "realtime standard shot still launches through shared factory")
	if not ordinary.is_empty():
		_check((ordinary.back() as Dictionary).get("pos") == baseline.get("pos") and
			(ordinary.back() as Dictionary).get("vel") == baseline.get("vel"),
			"standard realtime shot preserves muzzle placement and launch velocity")
	var special_angle: float = 40.0
	var special_percent: float = 71.0
	var special_force: float = float(game.call("_power_from_percent", special_percent))
	var expected_special: Dictionary = ProjectileFactory.make_fired_shell(
		0, WeaponRegistry.WEAPON_BOUNCER, positions[0], 1.0,
		special_angle, special_force, cannon_length
	)
	game.call("_spawn_weapon_shell", 0, WeaponRegistry.WEAPON_BOUNCER, special_angle, special_percent, true)
	var projectiles: Array = game.get("rt_projectiles")
	_check(projectiles.size() >= 2, "special realtime shell still launches from shared factory")
	if projectiles.size() >= 2:
		var special: Dictionary = projectiles.back() as Dictionary
		_check(special["weapon"] == WeaponRegistry.WEAPON_BOUNCER and
			special["pos"] == expected_special["pos"] and
			special["vel"] == expected_special["vel"],
			"special realtime shot uses same exact owner and launch geometry")
	game.call("reset_match")
	game.call("_on_hotseat_pressed")
	game.call("_on_hotseat_start_turn_pressed")
	game.call("_set_selected_weapon_for_current_player", WeaponCatalog.HEAVY)
	var hotseat_positions: Array = game.get("tank_positions")
	var turn_angle: float = float(game.get("angle_deg"))
	var turn_force: float = float(game.get("power"))
	var expected_turn: Dictionary = ProjectileFactory.make_fired_shell(
		0, WeaponCatalog.HEAVY, hotseat_positions[0], 1.0, turn_angle, turn_force,
		cannon_length
	)
	game.set("hotseat_release_in_progress", true)
	game.call("_on_fire_pressed")
	game.set("hotseat_release_in_progress", false)
	_check(bool(game.get("projectile_active")) and
		str(game.get("turn_projectile_weapon")) == WeaponCatalog.HEAVY,
		"hotseat firing retains chosen weapon and live shell")
	_check(game.get("projectile_pos") == expected_turn["pos"] and
		game.get("projectile_vel") == expected_turn["vel"],
		"hotseat turn launch matches canonical muzzle and velocity geometry")
	var world_source: String = FileAccess.get_file_as_string(
		"res://scripts/modes/WorldRuntimeBridge.gd"
	)
	_check(not world_source.contains("func _realtime_projectile_should_explode("),
		"shadowed world collision fallback is retired; MainGame owns the canonical hook")
	_check(world_source.contains("func _on_fire_pressed(") and
		world_source.contains("ProjectileFactory.make_fired_shell("),
		"world compatibility launch delegates to canonical shell factory")
	game.call("reset_match")

func _test_machine_gun_projectile_camera_focus() -> void:
	# Machine-gun camera geometry is a reusable projectile collection
	# calculation, not stateful scene or weapon-facade logic.
	var round_id: String = WeaponRegistry.WEAPON_MACHINE_GUN_ROUND
	var shots: Array[Dictionary] = [
		ProjectileFactory.make_shell(0, round_id, Vector2(110.0, 80.0), Vector2.ZERO),
		ProjectileFactory.make_shell(0, round_id, Vector2(220.0, 120.0), Vector2.ZERO),
		ProjectileFactory.make_shell(0, round_id, Vector2(160.0, 90.0), Vector2.ZERO),
		ProjectileFactory.make_shell(0, WeaponCatalog.HEAVY, Vector2(900.0, 400.0), Vector2.ZERO)
	]
	var before: Array[Dictionary] = shots.duplicate(true)
	var avg: Vector2 = (Vector2(110.0, 80.0) + Vector2(220.0, 120.0) + Vector2(160.0, 90.0)) / 3.0
	var forward: Vector2 = ProjectileManager.leading_shell_focus_for_weapon(
		shots, round_id, false, 0.72
	)
	var reverse: Vector2 = ProjectileManager.leading_shell_focus_for_weapon(
		shots, round_id, true, 0.72
	)
	_check(forward.is_equal_approx(avg.lerp(Vector2(220.0, 120.0), 0.72)),
		"right-facing machine-gun camera biases average toward the forward-most round")
	_check(reverse.is_equal_approx(avg.lerp(Vector2(110.0, 80.0), 0.72)),
		"left-facing machine-gun camera biases average toward the left-most round")
	_check(shots == before,
		"machine-gun camera focus never mutates the live projectile dictionaries")
	_check(ProjectileManager.leading_shell_focus_for_weapon(
		shots, "__missing_weapon__", false, 0.72) == Vector2.INF,
		"no matching rounds yields the sentinel for retaining previous camera focus")

	game.call("_on_hotseat_pressed")
	game.set("machine_gun_camera_pos", Vector2(40.0, 60.0))
	game.call("_update_machine_gun_camera_from_shells", shots, 0)
	_check((game.get("machine_gun_camera_pos") as Vector2).is_equal_approx(forward),
		"active scene's machine-gun camera delegates to canonical projectile focus")
	var no_rounds: Array[Dictionary] = []
	game.call("_update_machine_gun_camera_from_shells", no_rounds, 0)
	_check((game.get("machine_gun_camera_pos") as Vector2).is_equal_approx(forward),
		"active camera retains focus when the last burst round has disappeared")
	game.call("_update_machine_gun_camera_from_shells", shots, 1)
	_check((game.get("machine_gun_camera_pos") as Vector2).is_equal_approx(reverse),
		"active camera handles opposite owner direction")
	game.set("machine_gun_camera_active", true)
	game.call("reset_match")
	_check(not bool(game.get("machine_gun_camera_active")) and
		game.get("machine_gun_camera_pos") == Vector2.INF,
		"match reset clears camera state through the existing burst reset hook")

func _test_composed_weapon_burst_session_live() -> void:
	# Exercise burst timing and RNG in isolation, then the live game adapter.
	# It must consume exactly two jitter draws per emitted round, retain
	# overshoot across frames, and never mutate camera or projectile arrays.
	var burst: WeaponBurstSession = WeaponBurstSession.new()
	burst.begin(1, 42.0, 63.0, true, 3, 0.1)
	_check(burst.active and burst.realtime and burst.owner == 1 and
		not burst.turn_waiting_for_shells and burst.round_due(),
		"burst session initializes realtime shot ownership and immediate first round")
	var expected_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var shot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	expected_rng.seed = 20261101
	shot_rng.seed = 20261101
	var expected_angle: float = clampf(
		42.0 + expected_rng.randf_range(-3.0, 3.0), 0.0, 90.0
	)
	var expected_power: float = clampf(
		63.0 + expected_rng.randf_range(-7.0, 7.0), 0.0, 100.0
	)
	var shot: Dictionary = burst.shot_settings(shot_rng, 3.0, 7.0, 0.0, 90.0)
	_check(is_equal_approx(float(shot["angle"]), expected_angle) and
		is_equal_approx(float(shot["power_percent"]), expected_power),
		"burst jitter consumes exactly one angle then one power RNG draw")
	burst.round_fired()
	_check(burst.remaining == 2 and is_equal_approx(burst.timer, 0.1) and
		not burst.round_due(), "burst session accounts for fired round without oversending")
	burst.advance(0.25)
	_check(burst.round_due() and is_equal_approx(burst.timer, -0.15),
		"variable-frame update preserves negative timer overshoot")
	burst.round_fired()
	burst.round_fired()
	_check(burst.remaining == 0 and is_equal_approx(burst.timer, 0.05),
		"large-frame burst emits due rounds and carries residual cadence")
	_check(burst.finish() and not burst.active,
		"realtime burst completion returns its mode and disables further firing")
	burst.begin(0, 45.0, 50.0, false, 2, 0.1)
	burst.round_fired()
	_check(not burst.can_finish_turn(false, true, 0.0, 0.0) and
		not burst.can_finish_turn(false, false, 0.1, 0.0),
		"hotseat burst cannot finish while rounds or explosion hold remain")
	burst.finish()
	_check(burst.can_finish_turn(false, false, 0.0, 0.0),
		"hotseat burst waits for all projectiles and effects before turn handoff")
	burst.clear_active()
	_check(not burst.active and not burst.turn_waiting_for_shells and
		burst.remaining == 0 and is_zero_approx(burst.timer),
		"burst session resets its state without touching external camera owners")

	game.call("_on_hotseat_pressed")
	var live: WeaponBurstSession = game.get("weapon_burst") as WeaponBurstSession
	_check(live != null, "active scene composes the reusable burst lifecycle owner")
	if live == null:
		return
	var def_session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var definition: WeaponDefinition = def_session.definition(WeaponRegistry.WEAPON_MACHINE_GUN)
	var count_before: Variant = definition.extra_fields.get("burst_count", 10)
	var interval_before: Variant = definition.extra_fields.get("burst_interval", 0.1)
	definition.extra_fields["burst_count"] = 3
	definition.extra_fields["burst_interval"] = 0.1
	game.call("_begin_machine_gun_burst", 0, 45.0, 63.0, false)
	_check(live.active and live.turn_waiting_for_shells and
		live.remaining == 2 and bool(game.get("machine_gun_active")),
		"live Machine Gun consumes its first metadata-configured round immediately")
	_check((game.get("turn_projectiles") as Array).size() == 1,
		"live burst creates a real turn projectile, not a synthetic counter")
	game.call("_update_machine_gun_burst", 0.25)
	_check(not live.active and live.remaining == 0 and
		(game.get("turn_projectiles") as Array).size() == 3,
		"live burst emits all due rounds with correct metadata-driven count and timing")
	_check(bool(game.get("machine_gun_turn_waiting_for_shells")) and
		not live.can_finish_turn(false, true, 0.0, 0.0),
		"turn waits for actual burst shells after schedule completes")
	game.call("reset_match")
	_check(not live.active and not live.turn_waiting_for_shells and
		live.remaining == 0 and (game.get("turn_projectiles") as Array).is_empty(),
		"match reset clears both the burst session and all fired turn projectiles")

	game.call("_on_quick_game_pressed")
	game.call("_begin_machine_gun_burst", 0, 48.0, 72.0, true)
	_check(live.active and live.realtime and
		not live.turn_waiting_for_shells and
		(game.get("rt_projectiles") as Array).size() == 1,
		"realtime burst launches its first shell without turn handoff state")
	game.call("_update_machine_gun_burst", 0.25)
	_check(not live.active and live.remaining == 0 and
		(game.get("rt_projectiles") as Array).size() == 3 and
		bool(game.get("rt_player_shell_active")),
		"realtime burst completion leaves the fired human shells active")
	game.set("machine_gun_active", true)
	_check(live.active,
		"online facade compatibility property writes through to canonical burst session")
	game.set("machine_gun_active", false)
	game.set("machine_gun_turn_waiting_for_shells", true)
	_check(live.turn_waiting_for_shells,
		"online turn-wait compatibility property also has one canonical owner")
	definition.extra_fields["burst_count"] = count_before
	definition.extra_fields["burst_interval"] = interval_before
	game.call("reset_match")
	_check(not live.active and not live.turn_waiting_for_shells and
		(game.get("rt_projectiles") as Array).is_empty() and
		not bool(game.get("rt_player_shell_active")),
		"realtime reset clears burst and projectile lifecycle without stale aliases")

func _test_shared_turn_advance_clearance_live() -> void:
	# Both the frame/camera and online host are obliged to use the same
	# turn-clearance predicate; only their external triggers differ.
	_check(WeaponFramePolicy.can_advance_turn(
		false, false, false, false, false, 0.0, 0.0),
		"clear turn may advance with no shell, burst or visual hold")
	_check(not WeaponFramePolicy.can_advance_turn(
		true, false, false, false, false, 0.0, 0.0),
		"game over blocks pending turn advance")
	_check(not WeaponFramePolicy.can_advance_turn(
		false, true, false, false, false, 0.0, 0.0),
		"live projectile blocks pending turn advance")
	_check(not WeaponFramePolicy.can_advance_turn(
		false, false, true, false, false, 0.0, 0.0),
		"multi-round shells block pending turn advance")
	_check(not WeaponFramePolicy.can_advance_turn(
		false, false, false, true, false, 0.0, 0.0),
		"active burst blocks pending turn advance")
	_check(not WeaponFramePolicy.can_advance_turn(
		false, false, false, false, true, 0.0, 0.0),
		"waiting for final burst shells blocks turn advance")
	_check(not WeaponFramePolicy.can_advance_turn(
		false, false, false, false, false, 0.1, 0.0),
		"explosion hold blocks pending turn advance")
	_check(not WeaponFramePolicy.can_advance_turn(
		false, false, false, false, false, 0.0, 0.1),
		"camera hold blocks pending turn advance")
	var special_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	var network_source: String = FileAccess.get_file_as_string(
		"res://scripts/network/OnlineDuelHostCoordinator.gd"
	)
	_check(special_source.split("WeaponFramePolicy.can_advance_turn(").size() == 3 and
		network_source.contains("WeaponFramePolicy.can_advance_turn("),
		"hotseat camera, delayed turn completion, and online host share one safety rule")

	game.call("_on_hotseat_pressed")
	game.call("_on_hotseat_start_turn_pressed")
	game.set("pending_advance_after_explosion_hold", true)
	game.set("explosion_timer", 0.15)
	game.set("cluster_camera_hold_timer", 0.0)
	_check(not bool(game.call("_should_freeze_camera_until_pending_hotseat_advance_runs")),
		"camera does not freeze prematurely during explosion")
	game.call("_maybe_advance_after_explosion_hold")
	_check(int(game.get("current_player")) == 0 and
		bool(game.get("pending_advance_after_explosion_hold")),
		"live turn remains with firing player until explosion finishes")
	game.set("explosion_timer", 0.0)
	game.set("machine_gun_active", true)
	_check(not bool(game.call("_should_freeze_camera_until_pending_hotseat_advance_runs")),
		"camera freeze is gated by active machine-gun burst")
	game.call("_maybe_advance_after_explosion_hold")
	_check(int(game.get("current_player")) == 0,
		"active machine-gun burst cannot advance turn")
	game.set("machine_gun_active", false)
	game.set("machine_gun_turn_waiting_for_shells", true)
	game.call("_maybe_advance_after_explosion_hold")
	_check(int(game.get("current_player")) == 0,
		"waiting-for-shells state prevents premature turn switch")
	game.set("machine_gun_turn_waiting_for_shells", false)
	_check(bool(game.call("_should_freeze_camera_until_pending_hotseat_advance_runs")),
		"camera retains firing-player view on the frame a turn becomes safe")
	game.call("_maybe_advance_after_explosion_hold")
	_check(int(game.get("current_player")) == 1 and
		not bool(game.get("pending_advance_after_explosion_hold")),
		"live turn advances once, after all burst and explosion gates clear")
	game.call("reset_match")

func _test_special_weapon_terrain_delegation_live() -> void:
	# Test actual scene dispatch with metadata-driven geometry. Preserve the
	# historical difference: laser reflows water, Ground Bomb only refreshes.
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	_check(source.contains("TerrainManager.apply_laser_cut(") and
		source.contains("TerrainManager.apply_ground_mound(") and
		not source.contains("func _point_to_segment_distance("),
		"special weapon facade delegates numerical terrain geometry to existing owners")
	game.call("_on_hotseat_pressed")
	var definitions: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var laser: WeaponDefinition = definitions.definition(WeaponRegistry.WEAPON_LASER)
	var ground: WeaponDefinition = definitions.definition(WeaponRegistry.WEAPON_GROUND_BOMB)
	var old_cut_depth: Variant = laser.extra_fields.get("laser_cut_depth", 180.0)
	var old_cut_width: Variant = laser.extra_fields.get("laser_cut_width", 18.0)
	var old_raise: Variant = ground.extra_fields.get("ground_raise_amount", 174.0)
	var old_radius: float = ground.crater_radius
	var saved_points: Array[Vector2] = game.get("terrain_points")
	var saved_ponds: Array[Dictionary] = game.get("ponds")
	var points: Array[Vector2] = [
		Vector2(0.0, 360.0), Vector2(10.0, 360.0),
		Vector2(20.0, 360.0), Vector2(30.0, 360.0),
		Vector2(40.0, 360.0), Vector2(50.0, 360.0)
	]
	game.set("terrain_points", points)
	var no_ponds: Array[Dictionary] = []
	game.set("ponds", no_ponds)
	laser.extra_fields["laser_cut_depth"] = 35.0
	laser.extra_fields["laser_cut_width"] = 0.5
	game.call("_cut_laser_path", Vector2(10.0, 360.0), Vector2(40.0, 360.0))
	_check(points[0].y == 360.0 and points[1].y == 395.0 and
		points[2].y == 395.0 and points[3].y == 395.0 and
		points[4].y == 395.0 and points[5].y == 360.0,
		"live Laser uses registry depth and width to cut finite terrain segment")
	ground.extra_fields["ground_raise_amount"] = 35.0
	ground.crater_radius = 20.0
	game.call("_apply_ground_bomb", Vector2(20.0, 400.0), WeaponRegistry.WEAPON_GROUND_BOMB)
	_check(points[2].y == 360.0 and points[1].y < 395.0 and
		points[0].y == 360.0 and points[5].y == 360.0,
		"live Ground Bomb uses mutable definition radius and raise amount")
	laser.extra_fields["laser_cut_depth"] = old_cut_depth
	laser.extra_fields["laser_cut_width"] = old_cut_width
	ground.extra_fields["ground_raise_amount"] = old_raise
	ground.crater_radius = old_radius
	game.set("terrain_points", saved_points)
	game.set("ponds", saved_ponds)
	game.call("_refresh_terrain_line")
	game.call("reset_match")

func _test_laser_controller_authority_live() -> void:
	# Laser damage is point-to-ray direct damage, not radial splash. The
	# MatchController and outgoing network snapshot must agree immediately,
	# even before the next game _process() synchronizes its frame.
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	_check(source.contains("match_runtime_sync.apply_direct_damage(") and
		not source.contains("tank_health[target] ="),
		"Laser direct damage no longer writes a separate scene-only health value")
	game.call("_on_hotseat_pressed")
	var state: MatchState = game.get("match_state") as MatchState
	var controller: MatchController = game.get("match_controller") as MatchController
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var laser: WeaponDefinition = session.definition(WeaponRegistry.WEAPON_LASER)
	var prior_damage: int = laser.direct_damage
	laser.direct_damage = 35
	var positions: Array[Vector2] = [
		Vector2(200.0, 320.0), Vector2(450.0, 320.0)
	]
	var full_health: Array[int] = [100, 100]
	game.set("tank_positions", positions)
	game.set("tank_health", full_health)
	game.call("_apply_laser_damage", 0, Vector2(200.0, 320.0), Vector2(500.0, 320.0))
	_check((game.get("tank_health") as Array) == [100, 65] and
		state.tank_health == [100, 65] and not controller.is_game_over(),
		"live Laser damages only opponent and publishes health immediately")
	var packet: Dictionary = game.call("_online_make_snapshot")
	_check((packet["tank_health"] as Array) == [100, 65],
		"same-frame authoritative online snapshot contains Laser damage")

	game.call("reset_match")
	game.set("tank_positions", positions)
	game.set("tank_health", full_health.duplicate())
	game.call("_sync_match_state_from_runtime")
	game.call("_apply_laser_damage", 0, Vector2(200.0, 100.0), Vector2(500.0, 100.0))
	_check((game.get("tank_health") as Array) == [100, 100] and
		state.tank_health == [100, 100],
		"Laser near-miss leaves both runtime and controller health untouched")
	var wounded: Array[int] = [100, 20]
	game.set("tank_health", wounded)
	game.call("_apply_laser_damage", 0, Vector2(200.0, 320.0), Vector2(500.0, 320.0))
	_check((game.get("tank_health") as Array) == [100, 0] and
		state.tank_health == [100, 0] and state.game_over and
		controller.winner_index() == 0 and bool(game.get("game_over")),
		"lethal Laser clamps health and publishes winner before subsequent frame")
	laser.direct_damage = prior_damage
	game.call("reset_match")

func _test_metadata_laser_profile_fire_dispatch() -> void:
	# Register a second Laser profile only in test memory. It must use the
	# existing laser_cut behavior without another weapon-specific branch,
	# preserve charge/realtime routes and resolve its own metadata.
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	_check(source.split('_weapon_behavior(selected_weapon) == "laser_cut"').size() == 2 and
		source.contains('_weapon_behavior(weapon) == "laser_cut"'),
		"hotseat selection and the common realtime launcher dispatch Laser metadata")
	game.call("_on_hotseat_pressed")
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var old_loadout: WeaponLoadout = game.get("active_weapon_loadout") as WeaponLoadout
	var id: String = "test_laser_profile"
	session.definitions[id] = WeaponDefinition.new({
		"id": id, "display_name": "Test Laser Profile",
		"player_selectable": true, "menu_order": 100,
		"behavior": "laser_cut", "direct_damage": 46,
		"direct_radius": 12.0, "laser_cut_width": 3.0,
		"laser_cut_depth": 42.0
	})
	var ids: Array[String] = old_loadout.weapon_ids.duplicate()
	ids.append(id)
	game.call("_set_active_weapon_loadout", WeaponLoadout.new(ids, old_loadout.default_weapon_id))
	game.call("_set_selected_weapon_for_current_player", id)
	_check(str(game.get("selected_weapon")) == id,
		"new laser profile is selectable via the existing weapon loadout")
	var positions: Array[Vector2] = [
		Vector2(200.0, 320.0), Vector2(450.0, 320.0)
	]
	var full_health: Array[int] = [100, 100]
	game.set("tank_positions", positions)
	game.set("tank_health", full_health)
	game.set("angle_deg", 0.0)
	game.set("power_percent", 60.0)
	game.set("hotseat_release_in_progress", true)
	game.call("_on_fire_pressed")
	game.set("hotseat_release_in_progress", false)
	var state: MatchState = game.get("match_state") as MatchState
	_check((game.get("tank_health") as Array) == [100, 54] and
		state.tank_health == [100, 54],
		"new Laser profile uses its own damage metadata through real hotseat firing")
	_check(not bool(game.get("projectile_active")) and
		bool(game.get("pending_advance_after_explosion_hold")),
		"behavior-dispatched Laser still performs instantaneous fire and delayed turn handoff")
	var packet: Dictionary = game.call("_online_make_snapshot")
	_check((packet["tank_health"] as Array) == [100, 54],
		"custom Laser profile is reflected in same-frame online snapshot")
	game.call("reset_match")
	game.call("_on_quick_game_pressed")
	game.call("_set_active_weapon_loadout", WeaponLoadout.new(ids, old_loadout.default_weapon_id))
	game.call("_set_selected_weapon_for_current_player", id)
	_check(str(game.get("selected_weapon")) == id and
		bool(game.call("_player_can_fire")) and not bool(game.get("overlay_open")),
		"realtime profile selected and charge can begin before firing")
	# The prior hotseat Laser settles its tank positions in place, so the
	# realtime case must use a fresh horizontal sightline rather than the
	# array that the previous match's terrain has already changed.
	var realtime_positions: Array[Vector2] = [
		Vector2(200.0, 320.0), Vector2(450.0, 320.0)
	]
	game.set("tank_positions", realtime_positions)
	game.set("tank_health", full_health.duplicate())
	game.set("angle_deg", 0.0)
	game.set("rt_fire_charge_percent", 72.0)
	game.call("_release_realtime_charged_shot")
	_check((game.get("tank_health") as Array) == [100, 54],
		"charged realtime Laser uses custom profile direct damage")
	_check(not bool(game.get("rt_player_shell_active")),
		"instant charged realtime Laser does not allocate an active shell")
	_check(not bool(game.get("rt_fire_button_held")) and
		is_zero_approx(float(game.get("rt_fire_charge_percent"))),
		"charged realtime Laser clears charge input after firing")
	game.call("_set_active_weapon_loadout", old_loadout)
	session.definitions.erase(id)
	game.call("reset_match")

func _test_metadata_bouncer_profile_dispatch() -> void:
	# Register a second Bouncer in the canonical definition session. The
	# existing physics/turn dispatch must use this profile's bounce metadata
	# rather than the default Bouncer ID and its hard-coded values.
	var special_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	var mode_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameModeFacade.gd"
	)
	_check(special_source.contains('_weapon_behavior(turn_projectile_weapon) == "bounce"') and
		special_source.contains('_weapon_behavior(str(shell.get("weapon", ""))) != "bounce"') and
		mode_source.contains("_realtime_special_shell_step(stepped, owner)") and
		not special_source.contains("MACHINE_GUN_CAMERA_MIN_UPWARD_SPEED"),
		"turn Bouncer dispatch and unified realtime contact hook use canonical behavior")
	game.call("_on_hotseat_pressed")
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var original_loadout: WeaponLoadout = game.get("active_weapon_loadout") as WeaponLoadout
	var profile: String = "test_spring_bouncer"
	session.definitions[profile] = WeaponDefinition.new({
		"id": profile, "display_name": "Test Spring Bouncer",
		"behavior": "bounce", "player_selectable": true, "menu_order": 110,
		"max_bounces": 1, "bounce_damping_x": 0.18, "bounce_damping_y": 0.34
	})
	var ids: Array[String] = original_loadout.weapon_ids.duplicate()
	ids.append(profile)
	game.call("_set_active_weapon_loadout", WeaponLoadout.new(ids, original_loadout.default_weapon_id))
	game.call("_set_selected_weapon_for_current_player", profile)
	_check(str(game.get("selected_weapon")) == profile,
		"new Bouncer profile is selectable without a second weapon registry")
	var dry_ponds: Array[Dictionary] = []
	game.set("ponds", dry_ponds)
	var x: float = 720.0
	var ground_y: float = float(game.call("_ground_y_at_x", x))
	var vel: Vector2 = Vector2(110.0, 140.0)
	var reflected: Vector2 = WeaponBounceLogic.reflect_velocity(
		vel, float(game.call("_terrain_slope_at_x", x)), 0.18, 0.34, 95.0
	)
	# First permitted ground contact changes only the turn projectile and
	# its bounce counter, using the new profile's damping coefficients.
	game.set("projectile_active", true)
	game.set("turn_projectile_weapon", profile)
	game.set("projectile_pos", Vector2(x, ground_y + 2.0))
	game.set("projectile_vel", vel)
	game.set("turn_bouncer_bounce_count", 0)
	game.call("_update_projectile", 0.0)
	_check(bool(game.get("projectile_active")) and
		int(game.get("turn_bouncer_bounce_count")) == 1 and
		(game.get("projectile_vel") as Vector2).is_equal_approx(reflected),
		"hotseat custom Bouncer rebounds using its own damping profile")
	# With max_bounces == 1, the next contact detonates without bouncing.
	game.set("projectile_pos", Vector2(x, ground_y + 2.0))
	game.set("projectile_vel", vel)
	game.call("_update_projectile", 0.0)
	_check(not bool(game.get("projectile_active")) and
		(game.get("explosion_pos") as Vector2).is_equal_approx(Vector2(x, ground_y)),
		"hotseat custom Bouncer obeys its own maximum bounce count")
	game.call("reset_match")
	game.call("_on_quick_game_pressed")
	game.set("ponds", dry_ponds)
	ground_y = float(game.call("_ground_y_at_x", x))
	var shell: Dictionary = ProjectileFactory.make_shell(
		0, profile, Vector2(x, ground_y + 2.0), vel
	)
	var shells: Array[Dictionary] = [shell]
	game.set("rt_projectiles", shells)
	game.call("_update_all_realtime_projectiles", 0.0)
	var stepped: Array = game.get("rt_projectiles")
	_check(stepped.size() == 1 and
		str((stepped[0] as Dictionary).get("weapon", "")) == profile and
		int((stepped[0] as Dictionary).get("bounces", 0)) == 1 and
		((stepped[0] as Dictionary).get("vel", Vector2.ZERO) as Vector2).is_equal_approx(
			WeaponBounceLogic.reflect_velocity(
				vel, float(game.call("_terrain_slope_at_x", x)), 0.18, 0.34, 95.0
			)),
		"realtime custom Bouncer uses same profile metadata through active shell dispatch")
	game.call("_set_active_weapon_loadout", original_loadout)
	session.definitions.erase(profile)
	game.call("reset_match")

func _test_metadata_burst_profile_dispatch() -> void:
	# An additional profile must reuse WeaponBurstSession, firing a distinct
	# child-round ID with independent count/jitter/camera/turn semantics.
	var facade_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	_check(facade_source.split('_weapon_behavior(selected_weapon) == "machine_gun"').size() == 2 and
		facade_source.contains('_weapon_behavior(weapon) == "machine_gun"') and
		facade_source.contains("_burst_round_weapon()"),
		"burst dispatch uses behavior metadata and the session-owned child round")
	game.call("_on_hotseat_pressed")
	var definitions: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var original_loadout: WeaponLoadout = game.get("active_weapon_loadout") as WeaponLoadout
	var parent_id: String = "test_burst_profile"
	var child_id: String = "test_burst_round"
	definitions.definitions[child_id] = WeaponDefinition.new({
		"id": child_id, "display_name": "Test Burst Round",
		"player_selectable": false, "behavior": "standard",
		"direct_damage": 3, "explosion_radius": 9.0
	})
	definitions.definitions[parent_id] = WeaponDefinition.new({
		"id": parent_id, "display_name": "Test Burst Profile",
		"player_selectable": true, "menu_order": 120,
		"behavior": "machine_gun", "burst_count": 2,
		"burst_interval": 0.07, "burst_angle_jitter": 0.0,
		"burst_power_jitter": 0.0, "child_weapon_id": child_id
	})
	var ids: Array[String] = original_loadout.weapon_ids.duplicate()
	ids.append(parent_id)
	game.call("_set_active_weapon_loadout", WeaponLoadout.new(ids, original_loadout.default_weapon_id))
	game.call("_set_selected_weapon_for_current_player", parent_id)
	_check(str(game.get("selected_weapon")) == parent_id,
		"second burst profile is selected by the regular loadout")
	game.set("hotseat_release_in_progress", true)
	game.call("_on_fire_pressed")
	game.set("hotseat_release_in_progress", false)
	var burst: WeaponBurstSession = game.get("weapon_burst") as WeaponBurstSession
	var shells: Array = game.get("turn_projectiles")
	_check(burst.active and burst.weapon_id == parent_id and
		burst.child_weapon_id == child_id and burst.remaining == 1 and
		shells.size() == 1 and str((shells[0] as Dictionary).get("weapon", "")) == child_id,
		"hotseat custom burst starts with correct profile, child and one instant round")
	game.call("_update_machine_gun_burst", 0.08)
	shells = game.get("turn_projectiles")
	_check(not burst.active and burst.remaining == 0 and shells.size() == 2 and
		str((shells[1] as Dictionary).get("weapon", "")) == child_id and
		bool(game.get("machine_gun_turn_waiting_for_shells")),
		"custom burst completes metadata-driven cadence but waits for live shells")
	var focus: Vector2 = ProjectileManager.leading_shell_focus_for_weapon(
		game.get("turn_projectiles"), child_id, false, 0.72
	)
	game.call("_update_machine_gun_camera_from_shells", game.get("turn_projectiles"), 0)
	_check((game.get("machine_gun_camera_pos") as Vector2).is_equal_approx(focus) and
		not bool(game.call("_is_burst_round", WeaponCatalog.HEAVY)),
		"camera follows custom child rounds and excludes non-burst weapons")
	_check(bool(game.call("_is_burst_round", child_id)) and
		not bool(game.call("_is_burst_round", parent_id)),
		"burst child identification is independent of the parent weapon ID")
	game.call("reset_match")
	_check(burst.weapon_id.is_empty() and burst.child_weapon_id.is_empty() and
		(game.get("turn_projectiles") as Array).is_empty(),
		"match reset removes prior burst profile identity and shells")
	game.call("_on_quick_game_pressed")
	game.call("_set_active_weapon_loadout", WeaponLoadout.new(ids, original_loadout.default_weapon_id))
	game.call("_set_selected_weapon_for_current_player", parent_id)
	game.set("rt_fire_charge_percent", 68.0)
	game.call("_release_realtime_charged_shot")
	_check(burst.active and burst.realtime and burst.child_weapon_id == child_id and
		(game.get("rt_projectiles") as Array).size() == 1 and
		str(((game.get("rt_projectiles") as Array)[0] as Dictionary).get("weapon", "")) == child_id,
		"charged realtime fire launches custom burst child without a parent-ID branch")
	game.call("_update_machine_gun_burst", 0.08)
	_check(not burst.active and
		(game.get("rt_projectiles") as Array).size() == 2 and
		bool(game.call("_realtime_special_projectiles_active")),
		"realtime custom burst remains in special processing after last round emits")
	# Burst child rounds must retain their original no-eviction exception,
	# including when the active burst has completed and the pool is full.
	var full: Array[Dictionary] = []
	for i: int in range(6):
		full.append(ProjectileFactory.make_shell(
			0, WeaponCatalog.STANDARD, Vector2(100.0 + i, 50.0), Vector2.ZERO
		))
	game.set("rt_projectiles", full)
	var first: Dictionary = full[0].duplicate(true)
	game.call("_spawn_weapon_shell", 0, child_id, 45.0, 70.0, true)
	var after_child: Array = game.get("rt_projectiles")
	_check(after_child.size() == 7 and
		(after_child[0] as Dictionary) == first and
		str((after_child.back() as Dictionary).get("weapon", "")) == child_id,
		"custom burst child bypasses realtime cap without evicting existing shells")
	game.call("_spawn_weapon_shell", 0, WeaponCatalog.HEAVY, 45.0, 70.0, true)
	var after_regular: Array = game.get("rt_projectiles")
	_check(after_regular.size() == 7 and
		(after_regular[0] as Dictionary) != first and
		str((after_regular.back() as Dictionary).get("weapon", "")) == WeaponCatalog.HEAVY,
		"ordinary realtime shell still evicts the oldest shell at capacity")
	game.call("_set_active_weapon_loadout", original_loadout)
	definitions.definitions.erase(parent_id)
	definitions.definitions.erase(child_id)
	game.call("reset_match")

func _test_shared_scene_weapon_impact_lifecycle() -> void:
	# Same weapon/impact + same initial world must produce the same damage,
	# crater and explosion presentation regardless of turn/realtime mode.
	# Mode-specific camera ownership remains separate.
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	_check(source.split("_apply_weapon_impact(pos, weapon)").size() == 3,
		"turn and realtime weapons call exactly one shared impact sequence")
	game.call("_on_hotseat_pressed")
	var empty_ponds: Array[Dictionary] = []
	game.set("ponds", empty_ponds)
	var initial_points: Array[Vector2] = (game.get("terrain_points") as Array[Vector2]).duplicate()
	var initial_positions: Array[Vector2] = (game.get("tank_positions") as Array[Vector2]).duplicate()
	var initial_health: Array[int] = [100, 100]
	var impact: Vector2 = initial_positions[0]
	game.set("tank_health", initial_health.duplicate())
	game.call("_sync_health_state_to_match_controller")
	game.call("_explode_turn_weapon", impact, WeaponCatalog.STANDARD, false)
	var turn_health: Array[int] = (game.get("tank_health") as Array[int]).duplicate()
	var turn_points: Array[Vector2] = (game.get("terrain_points") as Array[Vector2]).duplicate()
	var turn_positions: Array[Vector2] = (game.get("tank_positions") as Array[Vector2]).duplicate()
	var turn_timer: float = float(game.get("explosion_timer"))
	var turn_radius: float = float(game.get("last_explosion_visual_radius"))
	_check(turn_health[0] < 100 and turn_health[1] == 100 and
		float(game.get("cluster_camera_hold_timer")) > 0.0,
		"turn impact applies direct damage and retains its own camera hold")
	game.call("reset_match")
	game.call("_on_quick_game_pressed")
	game.set("terrain_points", initial_points.duplicate())
	game.set("tank_positions", initial_positions.duplicate())
	game.set("tank_health", initial_health.duplicate())
	game.set("ponds", empty_ponds)
	game.call("_refresh_terrain_line")
	game.call("_sync_health_state_to_match_controller")
	game.call("_explode_realtime_weapon", impact, WeaponCatalog.STANDARD, 1)
	_check((game.get("tank_health") as Array[int]) == turn_health and
		(game.get("terrain_points") as Array[Vector2]) == turn_points and
		(game.get("tank_positions") as Array[Vector2]) == turn_positions,
		"same projectile impact yields identical health, terrain and tank settlement in both modes")
	_check(is_equal_approx(float(game.get("explosion_timer")), turn_timer) and
		is_equal_approx(float(game.get("last_explosion_visual_radius")), turn_radius) and
		game.get("explosion_pos") == impact,
		"realtime and turn use the same visual timer, radius and impact location")
	_check(is_zero_approx(float(game.get("cluster_camera_hold_timer"))) and
		(game.get("match_state") as MatchState).tank_health == turn_health,
		"AI realtime impact does not steal human camera yet publishes authoritative damage")
	game.call("reset_match")

func _test_shadowed_mode_explosion_hooks_retired() -> void:
	# SpecialWeaponsFacade owns both active impact hooks without super
	# delegation. The formerly duplicate ModeFacade overrides never ran
	# and risked adding a second camera hold if accidentally reused.
	var mode_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameModeFacade.gd"
	)
	var special_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	_check(not mode_source.contains("\nfunc _explode_turn_weapon(") and
		not mode_source.contains("\nfunc _explode_realtime_weapon("),
		"shadowed turn and realtime ModeFacade explosion hooks are retired")
	_check(special_source.contains("\nfunc _explode_turn_weapon(") and
		special_source.contains("\nfunc _explode_realtime_weapon(") and
		not special_source.contains("super._explode_turn_weapon(") and
		not special_source.contains("super._explode_realtime_weapon("),
		"SpecialWeaponsFacade remains the active impact owner for both modes")
	_check(mode_source.contains("\nfunc _explode(pos: Vector2)") and
		mode_source.contains("\nfunc _start_global_explosion_camera_hold("),
		"legacy explosion and shared camera-hold scene hooks remain available")

func _test_bouncer_weapon_policy_live() -> void:
	game.call("_on_hotseat_pressed")
	# Avoid a random level pond occupying the deterministic bounce contact.
	var dry_ponds: Array[Dictionary] = []
	game.set("ponds", dry_ponds)
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var definition: WeaponDefinition = session.definition(WeaponRegistry.WEAPON_BOUNCER)
	var old_x: float = float(definition.extra_fields.get("bounce_damping_x", 0.78))
	var old_y: float = float(definition.extra_fields.get("bounce_damping_y", 0.66))
	definition.extra_fields["bounce_damping_x"] = 0.42
	definition.extra_fields["bounce_damping_y"] = 0.58
	var contact_x: float = 720.0
	var incoming: Vector2 = Vector2(125.0, 85.0)
	var expected_reflection: Vector2 = WeaponBounceLogic.reflect_velocity(
		incoming, float(game.call("_terrain_slope_at_x", contact_x)),
		0.42, 0.58, 95.0
	)
	var actual_reflection: Vector2 = game.call("_reflect_bouncer_velocity", contact_x, incoming)
	_check(actual_reflection.is_equal_approx(expected_reflection),
		"active Bouncer reflection resolves live registry damping metadata through pure policy")
	var ground_y: float = float(game.call("_ground_y_at_x", contact_x))
	var shell: Dictionary = ProjectileFactory.make_shell(
		0, WeaponRegistry.WEAPON_BOUNCER,
		Vector2(contact_x, ground_y + 2.0), incoming
	)
	var result: Dictionary = game.call("_step_bouncer_shell", shell, 0)
	_check(not bool(result.get("explode", true)) and int(shell.get("bounces", 0)) == 1,
		"active realtime Bouncer uses shared policy for first permitted bounce")
	_check((shell.get("pos", Vector2.ZERO) as Vector2).is_equal_approx(
		Vector2(contact_x, ground_y - 5.0)) and
		(shell.get("vel", Vector2.ZERO) as Vector2).is_equal_approx(expected_reflection),
		"active realtime Bouncer keeps contact position and velocity exactly")
	shell["bounces"] = 3
	shell["pos"] = Vector2(contact_x, ground_y + 2.0)
	var before: Dictionary = shell.duplicate(true)
	var expired: Dictionary = game.call("_step_bouncer_shell", shell, 0)
	_check(bool(expired.get("explode", false)) and shell == before,
		"active Bouncer explodes at the stored maximum without modifying shell")
	definition.extra_fields["bounce_damping_x"] = old_x
	definition.extra_fields["bounce_damping_y"] = old_y
	game.call("reset_match")

func _test_single_weapon_metadata_owner() -> void:
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	_check(session != null and game.get("weapon_definitions") == session.definitions,
		"runtime and compatibility registry share a single definition-session owner")
	var heavy: WeaponDefinition = session.definition(WeaponCatalog.HEAVY)
	var probes: Array[Dictionary] = [
		{"key": "explosion_radius", "getter": "_weapon_explosion_radius", "increment": 11.0},
		{"key": "direct_radius", "getter": "_weapon_direct_radius", "increment": 5.0},
		{"key": "direct_damage", "getter": "_weapon_direct_damage", "increment": 7.0},
		{"key": "splash_damage", "getter": "_weapon_splash_damage", "increment": 9.0},
		{"key": "crater_radius", "getter": "_weapon_crater_radius", "increment": 13.0},
		{"key": "crater_depth", "getter": "_weapon_crater_depth", "increment": 17.0},
		{"key": "projectile_scale", "getter": "_weapon_projectile_scale", "increment": 0.25}
	]
	for probe: Dictionary in probes:
		var key: String = str(probe["key"])
		var getter: String = str(probe["getter"])
		var original: Variant = heavy.get(key)
		var new_value: Variant
		if key == "direct_damage" or key == "splash_damage":
			new_value = int(original) + int(probe["increment"])
		else:
			new_value = float(original) + float(probe["increment"])
		heavy.set(key, new_value)
		_check(is_equal_approx(float(game.call(getter, WeaponCatalog.HEAVY)), float(new_value)),
			"canonical inherited weapon getter reflects registry updates: " + key)
		heavy.set(key, original)
	var bouncer: WeaponDefinition = session.definition(WeaponRegistry.WEAPON_BOUNCER)
	var original_damping: Variant = bouncer.extra_fields.get("bounce_damping_x", 0.78)
	bouncer.extra_fields["bounce_damping_x"] = 0.31
	_check(is_equal_approx(float(game.call("_weapon_value",
		WeaponRegistry.WEAPON_BOUNCER, "bounce_damping_x", 0.78)), 0.31),
		"canonical metadata session also owns special weapon extension values")
	bouncer.extra_fields["bounce_damping_x"] = original_damping

func _test_shared_turn_realtime_bouncer_contact_live() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	var start: int = source.find("func _update_bouncing_turn_projectile(")
	var finish: int = source.find("\nfunc ", start + 4)
	var turn_update: String = source.substr(start, finish - start)
	_check(turn_update.contains("_step_bouncer_shell(shell, current_player)") and
		not turn_update.contains("WeaponBounceLogic.reached_limit(") and
		not turn_update.contains("_is_in_pond(projectile_pos)"),
		"turn Bouncer delegates contact and bounce limit to shared shell routine")

	game.call("_on_hotseat_pressed")
	var dry_ponds: Array[Dictionary] = []
	game.set("ponds", dry_ponds)
	var x: float = 720.0
	var y: float = float(game.call("_ground_y_at_x", x))
	var launch: Vector2 = Vector2(x, y + 2.0)
	var velocity: Vector2 = Vector2(110.0, 140.0)
	var weapon: String = WeaponRegistry.WEAPON_BOUNCER
	var reference: Dictionary = ProjectileFactory.make_shell(0, weapon, launch, velocity)
	var result: Dictionary = game.call("_step_bouncer_shell", reference, 0)
	_check(not bool(result.get("explode", true)) and
		int(reference.get("bounces", 0)) == 1,
		"realtime Bouncer permits the first ground reflection")
	game.set("projectile_active", true)
	game.set("turn_projectile_weapon", weapon)
	game.set("projectile_pos", launch)
	game.set("projectile_vel", velocity)
	game.set("turn_bouncer_bounce_count", 0)
	game.call("_update_projectile", 0.0)
	_check(bool(game.get("projectile_active")) and
		(game.get("projectile_pos") as Vector2).is_equal_approx(
			reference.get("pos", Vector2.INF)) and
		(game.get("projectile_vel") as Vector2).is_equal_approx(
			reference.get("vel", Vector2.INF)) and
		int(game.get("turn_bouncer_bounce_count")) == int(reference["bounces"]),
		"turn and realtime Bouncer share exact ground contact, damping and counter")

	reference["pos"] = launch
	reference["vel"] = velocity
	reference["bounces"] = 3
	var terminal: Dictionary = game.call("_step_bouncer_shell", reference, 0)
	_check(bool(terminal.get("explode", false)) and
		terminal.get("impact_pos", Vector2.INF) == Vector2(x, y) and
		reference["pos"] == launch,
		"shared terminal ground contact retains realtime shell and returns snapped turn impact")
	game.set("projectile_pos", launch)
	game.set("projectile_vel", velocity)
	game.set("turn_bouncer_bounce_count", 3)
	game.call("_update_projectile", 0.0)
	_check(not bool(game.get("projectile_active")) and
		(game.get("explosion_pos") as Vector2).is_equal_approx(Vector2(x, y)),
		"turn terminal Bouncer uses ground-snapped impact without a second collision algorithm")

	game.call("reset_match")
	game.call("_on_hotseat_pressed")
	game.set("ponds", dry_ponds)
	var positions: Array[Vector2] = game.get("tank_positions")
	for owner: int in [0, 1]:
		var hit: Vector2 = positions[1 - owner]
		var shell: Dictionary = ProjectileFactory.make_shell(owner, weapon, hit, velocity)
		var collision: Dictionary = game.call("_step_bouncer_shell", shell, owner)
		_check(bool(collision.get("explode", false)) and
			collision.get("impact_pos", hit) == hit,
			"both Bouncer owners detect opponent tank before terrain: " + str(owner))
	game.call("reset_match")

func _test_pruned_weapon_collision_dispatch_live() -> void:
	# Both turn and realtime shell checks are now scene adapters on MainGame.
	# Higher overrides still own mode-specific realtime firing and splitting.
	var main_source: String = FileAccess.get_file_as_string("res://scripts/core/MainGame.gd")
	_check(not main_source.is_empty(), "MainGame source is available for local override guard")
	for method_name: String in [
		"_fire_realtime_projectile", "_spawn_realtime_cluster_children"
	]:
		_check(not main_source.contains("\nfunc " + method_name + "("),
			"MainGame does not redeclare shadowed weapon override " + method_name)

	game.call("_on_hotseat_pressed")
	var old_ponds: Array[Dictionary] = game.get("ponds")
	var dry_ponds: Array[Dictionary] = []
	game.set("ponds", dry_ponds)
	var positions: Array[Vector2] = game.get("tank_positions")
	for owner: int in [0, 1]:
		var target: int = 1 - owner
		var hit: Vector2 = positions[target]
		_check(bool(game.call("_turn_shell_should_explode", owner, hit)),
			"turn-based projectile detects target tank for owner " + str(owner))
		_check(bool(game.call("_realtime_projectile_should_explode", owner, hit)),
			"realtime projectile detects target tank for owner " + str(owner))
	var x: float = 510.0
	var ground_y: float = float(game.call("_ground_y_at_x", x))
	var airborne: Vector2 = Vector2(x, ground_y - 180.0)
	var surface: Vector2 = Vector2(x, ground_y + 3.0)
	var offscreen: Vector2 = Vector2(-150.0, -250.0)
	for name: String in ["_turn_shell_should_explode", "_realtime_projectile_should_explode"]:
		_check(not bool(game.call(name, 0, airborne)), name + " allows an airborne shell")
		_check(bool(game.call(name, 0, surface)), name + " detonates on terrain")
		_check(bool(game.call(name, 0, offscreen)), name + " detonates out of world")
	game.set("ponds", old_ponds)
	game.call("reset_match")

func _test_retired_world_mode_helpers_live() -> void:
	# These former compatibility helpers have no callers in the live scene.
	# Retaining their source-level declarations would reintroduce stale policy
	# paths that bypass the current composed AI/menu services.
	var source: String = FileAccess.get_file_as_string("res://scripts/modes/WorldRuntimeBridge.gd")
	_check(not source.is_empty(), "world script available for compatibility guard")
	for unused: String in [
		"_find_ai_shot", "_score_ai_shot",
		"_prepare_realtime_ai_shot", "_load_texture_if_exists",
		"_draw_realtime_cooldown_widgets", "_mode_runtime_draw"
	]:
		_check(not source.contains("\nfunc " + unused + "("),
			"world no longer declares obsolete compatibility hook " + unused)
	# The scene only drew the old mode-runtime fallback in menu state.
	# Its dead gameplay branch is retired; menus go straight to the same
	# composed view-background delegate from the real world draw path.
	_check(source.contains("\t_draw_menu_background()\n"),
		"world menu draw path still calls composed background renderer")
	game.call("_show_main_menu")
	_check(int(game.get("menu_state")) == 0,
		"main menu remains reachable with direct background drawing")
	game.queue_redraw()
	game.call("_on_quick_game_pressed")
	game.call("_choose_realtime_ai_visual_plan")
	var aim: RealtimeAIAimingSession = game.get("realtime_ai_aim") as RealtimeAIAimingSession
	_check(aim != null and aim.has_plan, "active realtime AI still plans through composed session")
	_check(is_finite(aim.target_angle) and is_finite(aim.target_power_percent),
		"active realtime AI plan targets stay finite after dead-path cleanup")
	game.call("_on_hotseat_pressed")
	_check(int(game.get("menu_state")) == GAME_MENU_STATE,
		"mode transitions still work after deleting unused world compatibility code")
	game.call("reset_match")

func _test_mode_power_ui_single_owner_live() -> void:
	# The mode layer previously called MainGame._update_ui() and then
	# immediately recalculated the same hotseat/realtime charge labels.
	# Keep one label owner and exercise its behavior via the real scene.
	var mode_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameModeFacade.gd"
	)
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	_check(not mode_source.contains("\nfunc _update_ui(") and
		main_source.contains("\nfunc _update_ui("),
		"MainGame is the sole active hotseat/realtime charge-label owner")
	var power: Label = game.get("power_label") as Label
	_check(power != null, "power label is present for mode handoff")
	if power == null:
		return

	game.call("_on_hotseat_pressed")
	game.call("_on_hotseat_start_turn_pressed")
	game.set("hotseat_fire_button_held", false)
	game.set("hotseat_keyboard_fire_held", false)
	game.call("_update_ui")
	_check(power.text == "Hold FIRE",
		"unheld hotseat fire keeps the normal prompt without the mode override")
	game.set("hotseat_charge_percent", 72.0)
	game.set("hotseat_fire_button_held", true)
	game.call("_update_ui")
	_check(power.text == "Charge: 72%",
		"hotseat charge label keeps its percentage after mode deduplication")

	game.call("_on_quick_game_pressed")
	game.set("rt_player_shell_active", true)
	game.set("rt_fire_button_held", false)
	game.set("rt_keyboard_fire_held", false)
	game.call("_update_ui")
	_check(power.text == "Shell in flight",
		"realtime mode still presents an active projectile label")
	game.set("rt_player_shell_active", false)
	game.set("rt_fire_charge_percent", 67.0)
	game.set("rt_fire_button_held", true)
	game.call("_update_ui")
	_check(power.text == "Charge: 67%",
		"realtime mode still presents live charging percentage")
	game.call("reset_match")

func _test_weapon_startup_layout_live() -> void:
	# WorldRuntimeBridge's old prototype layout is overridden through
	# MainGame in both the ready and reset dispatch chains.
	var left: Button = game.get("mobile_left_button") as Button
	var right: Button = game.get("mobile_right_button") as Button
	var fire: Button = game.get("mobile_fire_button") as Button
	var weapon: Button = game.get("weapon_button") as Button
	_check(left != null and right != null and fire != null and weapon != null,
		"active startup creates all mobile and weapon action controls")
	if left == null or right == null or fire == null or weapon == null:
		return
	_check(left.position == Vector2(16, 430) and left.size == Vector2(92, 88),
		"active left mobile button has original gameplay layout")
	_check(right.position == Vector2(122, 430) and right.size == Vector2(92, 88),
		"active right mobile button has original gameplay layout")
	_check(fire.position == Vector2(696, 448) and fire.size == Vector2(188, 70),
		"active FIRE button retains weapon-bridge position after World startup")
	_check(weapon.position == WeaponSelectMenu.BUTTON_POS and
		weapon.size == WeaponSelectMenu.BUTTON_SIZE,
		"weapon button keeps the menu-helper placement")
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	_check(not source.contains("\nfunc _add_main_menu_controls(") and
		not source.contains("\nfunc _relabel_quit_buttons("),
		"MainGame has no dead startup menu hooks")
	game.call("reset_match")
	_check(fire.position == Vector2(696, 448) and
		weapon.position == WeaponSelectMenu.BUTTON_POS,
		"reset_match still applies active button layout through the inherited hook")

func _test_weapon_frame_policy_live() -> void:
	# Validate the priority policy against the real scene's runtime state,
	# without invoking the whole inherited process chain manually.
	game.call("_on_hotseat_pressed")
	var shells: Array[Dictionary] = [
		ProjectileFactory.make_shell(0, "standard", Vector2(350, 90), Vector2(40, -50))
	]
	var in_game: bool = int(game.get("menu_state")) == GAME_MENU_STATE
	var is_realtime: bool = int(game.get("game_mode")) == 2
	_check(WeaponFramePolicy.select_stage(
		in_game, false, false, is_realtime, not shells.is_empty()
	) == WeaponFramePolicy.Stage.TURN_SHELLS,
		"live hotseat mode with a pending shell uses turn-projectile stage")
	_check(WeaponFramePolicy.select_stage(
		in_game, false, true, is_realtime, not shells.is_empty()
	) == WeaponFramePolicy.Stage.WEAPON_MENU,
		"live hotseat menu overlays turn-shell stage without moving shells")
	_check(WeaponFramePolicy.select_stage(
		in_game, true, true, is_realtime, not shells.is_empty()
	) == WeaponFramePolicy.Stage.GAME_OVER,
		"live game-over visuals outrank paused weapon menu")
	game.call("_on_quick_game_pressed")
	_check(WeaponFramePolicy.select_stage(
		int(game.get("menu_state")) == GAME_MENU_STATE,
		false, false, true, true
	) == WeaponFramePolicy.Stage.NORMAL,
		"live realtime mode keeps normal update stage even with stored turn shells")
	game.call("reset_match")

func _test_turn_projectile_session_reset_live() -> void:
	game.call("_on_hotseat_pressed")
	var session: TurnProjectileSession = game.get("turn_projectile_session") as TurnProjectileSession
	_check(session != null, "active weapon bridge composes turn projectile state owner")
	if session == null:
		return
	var active_shells: Array[Dictionary] = [
		ProjectileFactory.make_shell(
			0, WeaponCatalog.CLUSTER_CHILD, Vector2(310.0, 140.0), Vector2(35.0, -65.0)
		)
	]
	game.set("turn_projectiles", active_shells)
	game.set("turn_projectile_weapon", WeaponCatalog.CLUSTER)
	game.set("turn_projectile_split_done", true)
	_check(session.shells.size() == 1 and session.weapon == WeaponCatalog.CLUSTER and
		session.split_done, "legacy turn shell properties write into the composed session")
	var retained_shells: Array[Dictionary] = session.shells
	game.call("reset_match")
	_check(session.shells.is_empty() and retained_shells.is_empty() and
		(game.get("turn_projectiles") as Array).is_empty(),
		"reset clears active shells before world gameplay resumes, preserving array handles")
	_check(session.weapon == str(game.get("selected_weapon")) and
		str(game.get("turn_projectile_weapon")) == session.weapon and
		not session.split_done and not bool(game.get("turn_projectile_split_done")),
		"reset preserves mode-selected weapon and clears split flag via legacy aliases")
	retained_shells.append(ProjectileFactory.make_shell(
		0, WeaponCatalog.STANDARD, Vector2(150.0, 100.0), Vector2(0.0, 40.0)
	))
	_check((game.get("turn_projectiles") as Array).size() == 1,
		"online and hotseat holders of the old shell array still see the composed owner")
	game.call("reset_match")
	_check(session.shells.is_empty(),
		"subsequent inherited match resets clear the same composed turn-shell array")
	_check(not bool(game.get("weapon_menu_open")),
		"post-parent weapon menu closing still occurs after projectile reset")
	var fire_button: Button = game.get("mobile_fire_button") as Button
	_check(fire_button != null and fire_button.position == Vector2(696, 448),
		"post-parent mobile layout still runs after projectile reset")

func _test_shadowed_bridge_removal_live() -> void:
	# The bridge is retired. Compiler-visible scene methods are consolidated
	# in MainGame; higher special/mode dispatch remains unchanged.
	_check(not FileAccess.file_exists("res://scripts/weapons/WeaponRuntimeBridge.gd"),
		"retired weapon bridge is absent from the scene's source tree")
	var mode_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameModeFacade.gd"
	)
	var special_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameSpecialWeaponsFacade.gd"
	)
	var world_source: String = FileAccess.get_file_as_string(
		"res://scripts/modes/WorldRuntimeBridge.gd"
	)
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	for name: String in [
		"_split_turn_cluster_projectile", "_update_turn_weapon_projectiles",
		"_apply_weapon_damage", "_build_weapon_ui", "_toggle_weapon_menu"
	]:
		_check(main_source.contains("\nfunc " + name + "("),
			"six-layer game retains compiler-visible method " + name)
	_check(mode_source.contains("\nfunc _update_all_realtime_projectiles(") and
		special_source.contains("super._update_all_realtime_projectiles(delta)") and
		not mode_source.contains("super._update_all_realtime_projectiles(delta)"),
		"special realtime super dispatch stops at the active mode facade")
	_check(world_source.contains("\nfunc _fire_realtime_projectile(") and
		world_source.contains("\nfunc _update_all_realtime_projectiles("),
		"world prototype still provides lower realtime compatibility signatures")
	game.call("_on_hotseat_pressed")
	var weapon_button: Button = game.get("weapon_button") as Button
	var weapon_panel: Panel = game.get("weapon_panel") as Panel
	_check(weapon_button != null and weapon_panel != null,
		"active mode still builds the loadout weapon menu")
	game.call("_toggle_weapon_menu")
	_check(bool(game.get("weapon_menu_open")) and weapon_panel.visible,
		"active weapon selector opens via derived MainGame handler")
	game.call("_toggle_weapon_menu")
	_check(not bool(game.get("weapon_menu_open")) and not weapon_panel.visible,
		"active weapon selector closes via derived MainGame handler")
	game.call("reset_match")

func _test_composed_weapon_menu_view_live() -> void:
	game.call("_on_hotseat_pressed")
	var panel: Panel = game.get("weapon_panel") as Panel
	var weapon_button: Button = game.get("weapon_button") as Button
	_check(panel != null and weapon_button != null,
		"composed weapon view exists after active scene startup")
	if panel == null or weapon_button == null:
		return
	game.call("_open_weapon_menu")
	_check(panel.visible and bool(game.get("weapon_menu_open")) and
		bool(game.get("overlay_open")),
		"opening weapon menu updates active panel and overlay state together")
	_check(not bool(game.get("mobile_left_pressed")) and
		not bool(game.get("mobile_right_pressed")),
		"weapon menu preserves mobile movement release on open")
	game.call("_close_weapon_menu")
	_check(not panel.visible and not bool(game.get("weapon_menu_open")),
		"closing selector hides composed panel and clears menu flag")
	game.call("_open_weapon_menu")
	game.call("_hide_overlays")
	_check(not panel.visible and not bool(game.get("weapon_menu_open")),
		"global overlay hide still dismisses the composed weapon menu")
	game.call("_open_weapon_menu")
	game.call("_return_to_main_menu")
	_check(not panel.visible and not bool(game.get("weapon_menu_open")),
		"return to main menu hides composed selector")
	game.call("reset_match")

func _test_legacy_turn_contact_matches_shells_live() -> void:
	game.call("_on_hotseat_pressed")
	var dry_ponds: Array[Dictionary] = []
	game.set("ponds", dry_ponds)
	var x: float = 540.0
	var ground_y: float = float(game.call("_ground_y_at_x", x))
	var contact: Vector2 = Vector2(x, ground_y + 2.0)
	_check(bool(game.call("_turn_shell_should_explode", 0, contact)) and
		bool(game.call("_realtime_projectile_should_explode", 0, contact)) and
		game.call("_shell_impact_position", 0, contact, true) == Vector2(x, ground_y),
		"legacy and ordinary shells agree on terrain collision, only legacy snaps impact")
	game.set("projectile_active", true)
	game.set("turn_projectile_weapon", WeaponCatalog.STANDARD)
	game.set("projectile_pos", contact)
	game.set("projectile_vel", Vector2.ZERO)
	game.call("_update_projectile", 0.0)
	_check(not bool(game.get("projectile_active")) and
		(game.get("explosion_pos") as Vector2) == Vector2(x, ground_y),
		"real legacy turn update detonates at resolved ground-snapped impact")
	game.call("reset_match")

func _test_shared_shell_impact_policy_live() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	_check(source.contains("func _turn_shell_should_explode(") and
		source.contains("func _realtime_projectile_should_explode("),
		"both compile-time collision hooks remain in MainGame")
	var count: int = source.split("ProjectileManager.impact_position(").size() - 1
	_check(count == 1 and
		source.contains("func _shell_impact_position(") and
		source.contains("return _shell_impact_position(owner, pos) != Vector2.INF") and
		source.split("return _shell_should_explode(owner, pos)").size() == 3,
		"legacy turn, spawned turn and realtime share one scene impact resolver")
	game.call("_on_hotseat_pressed")
	var old_ponds: Array[Dictionary] = game.get("ponds")
	var empty_ponds: Array[Dictionary] = []
	game.set("ponds", empty_ponds)
	var positions: Array[Vector2] = game.get("tank_positions")
	for owner: int in [0, 1]:
		var enemy: Vector2 = positions[1 - owner]
		_check(bool(game.call("_turn_shell_should_explode", owner, enemy)),
			"turn shell collision retains target ownership " + str(owner))
		_check(bool(game.call("_realtime_projectile_should_explode", owner, enemy)),
			"realtime shell collision retains target ownership " + str(owner))
	var safe_x: float = 540.0
	var ground: float = float(game.call("_ground_y_at_x", safe_x))
	for name: String in ["_turn_shell_should_explode", "_realtime_projectile_should_explode"]:
		_check(not bool(game.call(name, 0, Vector2(safe_x, ground - 130.0))),
			name + " allows safe airborne shells")
		_check(bool(game.call(name, 0, Vector2(safe_x, ground + 2.0))),
			name + " detects ground contact")
		_check(bool(game.call(name, 0, Vector2(-150.0, -200.0))),
			name + " detects world boundary")
	game.set("ponds", old_ponds)
	game.call("reset_match")

func _test_canonical_weapon_alias_forwarding_live() -> void:
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	_check(session != null, "canonical weapon metadata session exists")
	if session == null:
		return
	var original_definitions: Dictionary = session.definitions
	var original_loadout: WeaponLoadout = session.loadout
	var replacement: Dictionary = original_definitions.duplicate()
	game.set("weapon_definitions", replacement)
	_check(session.definitions == replacement and
		game.get("weapon_definitions") == session.definitions,
		"legacy weapon registry writes forward to canonical session")
	var restricted: WeaponLoadout = WeaponLoadout.from_registry(
		session.definitions, WeaponCatalog.STANDARD
	)
	game.set("active_weapon_loadout", restricted)
	_check(session.loadout == restricted and
		game.get("active_weapon_loadout") == session.loadout,
		"legacy active loadout writes update the canonical session")
	game.set("active_weapon_loadout", null)
	_check(session.loadout == restricted,
		"null loadout cannot clobber canonical session through legacy property")
	game.call("_reset_default_weapon_loadout")
	_check(session.loadout == game.get("active_weapon_loadout"),
		"default loadout reset requires no manual copy-back synchronization")
	game.set("weapon_definitions", original_definitions)
	game.set("active_weapon_loadout", original_loadout)
	_check(game.get("weapon_definitions") == session.definitions and
		game.get("active_weapon_loadout") == session.loadout,
		"restored legacy metadata still shares one canonical owner")

func _test_weapon_lifecycle_consolidation_live() -> void:
	_check(not FileAccess.file_exists("res://scripts/weapons/WeaponRuntimeBridge.gd"),
		"retired weapon bridge is absent from the scene's source tree")
	var game_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	for name: String in ["_ready", "_process", "reset_match"]:
		_check(game_source.contains("\nfunc " + name + "("),
			"MainGame retains direct " + name + " lifecycle ownership")
	var ready_start: int = game_source.find("\nfunc _ready(")
	var reset_start: int = game_source.find("\nfunc reset_match(")
	var process_start: int = game_source.find("\nfunc _process(")
	var ready_end: int = game_source.find("\nfunc ", ready_start + 2)
	var reset_end: int = game_source.find("\nfunc ", reset_start + 2)
	var process_end: int = game_source.find("\nfunc ", process_start + 2)
	var ready_code: String = game_source.substr(ready_start, ready_end - ready_start)
	var reset_code: String = game_source.substr(reset_start, reset_end - reset_start)
	var process_code: String = game_source.substr(process_start, process_end - process_start)
	_check(ready_code.find("super._ready()") < ready_code.find("_build_weapon_ui()") and
		ready_code.find("_build_weapon_ui()") < ready_code.find("_on_hotseat_fire_button_down"),
		"merged startup retains world, weapon UI, then MainGame fire-button ordering")
	_check(reset_code.find("turn_projectile_session.reset_for_match(selected_weapon)") <
		reset_code.find("super.reset_match()") and
		reset_code.find("super.reset_match()") <
		reset_code.find("_close_weapon_menu()") and
		reset_code.find("_close_weapon_menu()") <
		reset_code.find("_initialize_match_controller_from_runtime_reset()"),
		"merged reset retains pre-world weapon cleanup and post-world UI before match sync")
	_check(process_code.find("_update_hotseat_charge(delta)") <
		process_code.find("WeaponFramePolicy.select_stage(") and
		process_code.find("WeaponFramePolicy.select_stage(") <
		process_code.find("_sync_match_state_from_runtime()"),
		"merged frame still brackets weapon stage with MainGame pre/post processing")
	game.call("_on_hotseat_pressed")
	game.call("_open_weapon_menu")
	var shells: Array[Dictionary] = [
		ProjectileFactory.make_shell(0, WeaponCatalog.CLUSTER_CHILD,
			Vector2(290.0, 140.0), Vector2(40.0, -70.0))
	]
	game.set("turn_projectiles", shells)
	game.set("turn_projectile_split_done", true)
	game.call("reset_match")
	var session: TurnProjectileSession = game.get("turn_projectile_session") as TurnProjectileSession
	var panel: Panel = game.get("weapon_panel") as Panel
	_check(session != null and session.shells.is_empty() and
		not session.split_done and (game.get("turn_projectiles") as Array).is_empty(),
		"merged reset retains existing session-owned projectile cleanup")
	_check(not bool(game.get("weapon_menu_open")) and panel != null and
		not panel.visible and
		(game.get("mobile_fire_button") as Button).position == Vector2(696, 448),
		"merged post-world reset still closes weapon menu and restores mobile layout")

func _test_turn_ai_world_ownership_live() -> void:
	var world_source: String = FileAccess.get_file_as_string(
		"res://scripts/modes/WorldRuntimeBridge.gd"
	)
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	for name: String in [
		"_begin_ai_turn", "_make_ai_visual_shot_plan",
		"_process_ai_turn", "_update_ai_visual_aim", "_take_ai_shot"
	]:
		_check(world_source.contains("\nfunc " + name + "(") and
			not main_source.contains("\nfunc " + name + "("),
			"world runtime now solely declares active turn AI hook " + name)
	_check(world_source.contains("var turn_ai_visual: TurnAIVisualAimSession:") and
		not main_source.contains("var turn_ai_visual:"),
		"turn AI visual compatibility property is owned alongside world timer")
	game.call("_on_hotseat_pressed")
	game.call("reset_match")
	var session: TurnAITurnSession = game.get("turn_ai_session") as TurnAITurnSession
	var visual: TurnAIVisualAimSession = game.get("turn_ai_visual") as TurnAIVisualAimSession
	_check(session != null and visual == session.visual and visual.plan.is_empty(),
		"active scene exposes one shared world-owned timer and visual plan")
	var rng: RandomNumberGenerator = game.get("rng") as RandomNumberGenerator
	rng.seed = 20261101
	game.call("_begin_ai_turn")
	_check(session.pending and not session.visual.plan.is_empty() and
		bool(game.get("ai_pending_turn")),
		"world-owned AI turn start still prepares timed and visual aiming together")
	var old_angle: float = float((game.get("player_angles") as Array)[1])
	var expected: float = move_toward(
		old_angle, visual.target_angle, 32.0 * 0.20
	)
	game.call("_update_ai_visual_aim", 0.20)
	_check(is_equal_approx(float((game.get("player_angles") as Array)[1]), expected),
		"world AI animation preserves original barrel slew rate")
	game.call("reset_match")
	_check(not session.pending and session.visual.plan.is_empty(),
		"parent reset still clears both turn AI timer and shot plan")

func _test_rendering_owner_migration_live() -> void:
	_check(not FileAccess.file_exists("res://scripts/weapons/WeaponRuntimeBridge.gd"),
		"retired weapon bridge is absent from the scene's source tree")
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	for name: String in [
		"_draw", "_draw_tank", "_draw_destroyed_smoke_puffs",
		"_draw_realtime_projectiles", "_draw_explosion", "_camera_target_x"
	]:
		_check(main_source.contains("\nfunc " + name + "("),
			"MainGame owns active rendering/camera method " + name)
	var drawing: String = main_source.get_slice("\nfunc _draw() -> void:", 1)
	var draw_end: int = drawing.find("\nfunc ")
	if draw_end >= 0:
		drawing = drawing.substr(0, draw_end)
	_check(drawing.find("super._draw()") < drawing.find("_draw_destroyed_smoke_puffs()") and
		drawing.find("_draw_destroyed_smoke_puffs()") <
		drawing.find("_draw_recoil_barrels()") and
		drawing.find("_draw_recoil_barrels()") <
		drawing.find("_draw_muzzle_smoke_puffs()"),
		"world, destroyed-smoke, recoil and muzzle draw order remains unchanged")
	game.call("_on_hotseat_pressed")
	game.call("reset_match")
	var tank_positions: Array[Vector2] = game.get("tank_positions")
	var target_x: float = tank_positions[0].x
	game.set("game_over", true)
	game.set("destroyed_tank_index", 0)
	game.set("manual_camera_active", false)
	game.set("realtime_cluster_focus_pos", Vector2.INF)
	game.set("turn_cluster_camera_pos", Vector2.INF)
	game.set("cluster_camera_hold_pos", Vector2.INF)
	# Main.gd uses VIEW_SIZE.x=900 and CAMERA_SCALE=0.66.
	var view_width: float = 900.0 / 0.66
	var max_camera_x: float = maxf(0.0, float(game.get("active_world_width")) - view_width)
	var expected_focus: float = clampf(target_x - 0.5 * view_width, 0.0, max_camera_x)
	_check(is_equal_approx(float(game.call("_camera_target_x")), expected_focus),
		"merged camera fallback still centers on destroyed tank after game over")
	game.set("game_over", false)
	game.set("destroyed_tank_index", -1)
	game.call("reset_match")

func _test_weapon_menu_owner_migration_live() -> void:
	_check(not FileAccess.file_exists("res://scripts/weapons/WeaponRuntimeBridge.gd"),
		"retired weapon bridge is absent from the scene's source tree")
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	for name: String in [
		"_build_weapon_ui", "_make_weapon_menu_button", "_toggle_weapon_menu",
		"_resize_mobile_action_buttons", "_open_weapon_menu",
		"_close_weapon_menu", "_hide_overlays", "_quit_game",
		"_return_to_main_menu"
	]:
		_check(main_source.contains("\nfunc " + name + "("),
			"active MainGame exclusively owns weapon menu lifecycle " + name)
	var mode_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameModeFacade.gd"
	)
	_check(main_source.contains("\nfunc _build_weapon_ui() -> void:\n\tpass") and
		mode_source.contains("\nfunc _build_weapon_ui(") and
		mode_source.contains("for weapon_id: String in active_weapon_loadout.weapon_ids") and
		main_source.contains("\nfunc _toggle_weapon_menu("),
		"MainGame retains the virtual hook while only the mode facade builds the loadout-driven selector")
	game.call("_on_hotseat_pressed")
	var panel: Panel = game.get("weapon_panel") as Panel
	var left: Button = game.get("mobile_left_button") as Button
	var right: Button = game.get("mobile_right_button") as Button
	var fire: Button = game.get("mobile_fire_button") as Button
	game.set("mobile_left_pressed", true)
	game.set("mobile_right_pressed", true)
	game.call("_open_weapon_menu")
	_check(panel != null and panel.visible and
		not bool(game.get("mobile_left_pressed")) and
		not bool(game.get("mobile_right_pressed")),
		"migrated menu open still stops both mobile movement inputs")
	game.call("_close_weapon_menu")
	_check(panel != null and not panel.visible and
		not bool(game.get("weapon_menu_open")),
		"migrated menu close still hides overlay and clears open flag")
	game.call("_open_weapon_menu")
	game.call("_hide_overlays")
	_check(not panel.visible and not bool(game.get("weapon_menu_open")),
		"migrated global overlay hook still clears selector view")
	game.call("_resize_mobile_action_buttons")
	_check(left.position == Vector2(16, 430) and
		right.position == Vector2(122, 430) and
		fire.position == Vector2(696, 448),
		"migrated active mobile layout retains enlarged controls")
	game.call("_quit_game")
	_check(int(game.get("menu_state")) == 0 and
		 not panel.visible, "migrated quit hook still returns to main menu")
	game.call("reset_match")

func _test_destroyed_smoke_game_ownership_live() -> void:
	_check(not FileAccess.file_exists("res://scripts/weapons/WeaponRuntimeBridge.gd"),
		"retired weapon bridge is absent from the scene's source tree")
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	for name: String in [
		"_process_game_over_visuals", "_show_end_popup",
		"_start_destroyed_tank_smoke", "_update_destroyed_smoke",
		"_spawn_destroyed_smoke_puff"
	]:
		_check(main_source.contains("\nfunc " + name + "("),
			"MainGame owns scene-facing destroyed-smoke hook " + name)
	_check(main_source.contains("var destroyed_smoke_session: DestroyedTankSmokeSession"),
		"destroyed smoke session sits with the game effects state")
	game.call("reset_match")
	var smoke: DestroyedTankSmokeSession = game.get("destroyed_smoke_session") as DestroyedTankSmokeSession
	_check(smoke != null and smoke.tank_index == -1,
		"scene retains original composed smoke session")
	var tank_hp: Array[int] = game.get("tank_health")
	tank_hp[1] = 0
	game.call("_start_destroyed_tank_smoke")
	_check(smoke.tank_index == 1 and smoke.puffs.size() == 7,
		"game smoke effect still creates seven seeded opening puffs")
	game.call("reset_match")
	_check(smoke.tank_index == -1 and smoke.puffs.is_empty(),
		"world and scene resets continue clearing effect state")

func _test_six_layer_weapon_domain_ownership_live() -> void:
	var main_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	_check(main_source.begins_with(
		"extends \"res://scripts/modes/WorldRuntimeBridge.gd\""
	), "active MainGame now directly extends world runtime")
	_check(not FileAccess.file_exists(
		"res://scripts/weapons/WeaponRuntimeBridge.gd"
	), "weapon bridge ancestor is deleted rather than left dormant")
	var scene_script: Script = game.get_script()
	var layers: int = 0
	while scene_script != null:
		layers += 1
		scene_script = scene_script.get_base_script()
	_check(layers == 6, "active scene has exactly six GDScript inheritance layers")
	var session: WeaponDefinitionSession = game.get("weapon_definition_session") as WeaponDefinitionSession
	var shells: TurnProjectileSession = game.get("turn_projectile_session") as TurnProjectileSession
	var smoke: DestroyedTankSmokeSession = game.get("destroyed_smoke_session") as DestroyedTankSmokeSession
	_check(session != null and shells != null and smoke != null,
		"six-layer scene keeps existing domain services without introducing adapters")
	for name: String in [
		"_update_projectile", "_split_turn_cluster_projectile",
		"_update_turn_weapon_projectiles", "_turn_shell_should_explode",
		"_realtime_projectile_should_explode", "_explode_realtime_weapon",
		"_apply_weapon_crater", "_weapon_explosion_radius",
		"_weapon_direct_damage", "_weapon_projectile_scale"
	]:
		_check(main_source.contains("\nfunc " + name + "("),
			"scene retains the required weapon compatibility hook " + name)

func _test_scene_adapter_domain_grouping_live() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGame.gd"
	)
	# Rendering and movement now share one snow-line policy per mode.
	var snow_mode_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameModeFacade.gd"
	)
	_check(source.contains("\nfunc _active_snow_line_y(") and
		snow_mode_source.contains("\nfunc _active_snow_line_y("),
		"active snow line is the only mode-specific override")
	for snow_function: String in ["_draw_snow_faces", "_draw_snow_surface_highlights",
		"_snow_adjusted_direction_and_speed", "_is_snow_at_x"]:
		_check(not snow_mode_source.contains("\nfunc " + snow_function + "("),
			"mode facade reuses MainGame SnowManager implementation: " + snow_function)

	_check(not source.contains("\nfunc _update_realtime_fire_charge(")
		and not source.contains("\nfunc _draw_turn_widget("),
		"shadowed charging and turn-widget bodies live in the mode facade")

	var firing: int = source.find("\nfunc _on_fire_pressed(")
	var projectile: int = source.find("\nfunc _update_projectile(")
	var mode_source: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameModeFacade.gd"
	)
	_check(firing >= 0 and firing < projectile and
		mode_source.contains("\nfunc _update_realtime_fire_charge(") and
		mode_source.contains("\nfunc _update_hotseat_charge("),
		"fire and projectile adapters stay ordered while mode facade owns charging")
	var realtime_explosion: int = source.find("\nfunc _explode_realtime(")
	var turn_explosion: int = source.find("\nfunc _explode_turn_weapon(")
	_check(realtime_explosion >= 0 and realtime_explosion < turn_explosion,
		"realtime and turn explosion hooks remain grouped")
	var crater: int = source.find("\nfunc _apply_weapon_crater(")
	var damage: int = source.find("\nfunc _apply_weapon_damage(")
	_check(crater >= 0 and crater < damage,
		"crater and radial damage effects remain adjacent")
	var stat: int = source.find("\nfunc _weapon_value(")
	var display_name: int = source.find("\nfunc _weapon_display_name(")
	_check(stat >= 0 and stat < display_name and
		source.find("\nfunc _weapon_projectile_scale(") < display_name,
		"legacy stat getters stay beside canonical weapon-definition adapters")
	_check(not FileAccess.file_exists(
		"res://scripts/weapons/WeaponRuntimeBridge.gd"
	), "grouping adds no new bridge or service layer")

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
