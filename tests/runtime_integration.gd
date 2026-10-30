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

	game.queue_free()
	await process_frame
	_finish()

func _test_campaign_navigation() -> void:
	game.call("_show_single_player_menu")
	_check(int(game.get("menu_state")) == SINGLE_PLAYER_MENU_STATE, "single-player menu opens")
	game.call("_on_campaign_pressed")
	var scroll: ScrollContainer = game.get("campaign_map_scroll") as ScrollContainer
	_check(scroll != null, "campaign creates a scrollable map")
	if scroll != null:
		var nodes: Array[Node] = scroll.find_children("*", "Button", true, false)
		var ready_count: int = 0
		var locked_count: int = 0
		for node: Node in nodes:
			var button: Button = node as Button
			if button == null:
				continue
			if button.text.begins_with("1\\n") and not button.disabled:
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
		if button != null and button.text.begins_with("1\\n"):
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
	game.call("reset_match")
	_check(int(game.get("current_player")) == 0, "reset returns turn to player 1")
	_check(str(game.get("selected_weapon")) == WeaponCatalog.STANDARD, "reset restores default weapon")

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
