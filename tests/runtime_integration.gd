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
		_check(game.get("active_level_definition") != null, "launched match has a level definition")

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
