extends SceneTree
## Real-scene realtime-mode and owner-aware explosion camera regression checks.
## Run with godot --headless --path . --script res://tests/realtime_camera_integration.gd

var failures: Array[String] = []
var checks: int = 0
var game: Node2D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	if scene == null:
		_finish_with_failure("main scene cannot load")
		return
	game = scene.instantiate() as Node2D
	if game == null:
		_finish_with_failure("scene could not instantiate")
		return
	root.add_child(game)
	await process_frame
	game.set_process(false)

	game.call("_on_quick_game_pressed")
	_check(int(game.get("menu_state")) == 4, "quick game opens actual game")
	_check(bool(game.call("_is_active_mode", ModeControllerRegistry.MODE_REALTIME_SINGLE_PLAYER)), "quick game activates realtime mode")
	_check(int(game.get("current_player")) == 0, "human is realtime player 1")
	_check((game.get("realtime_ai_aim") as RealtimeAIAimingSession).has_plan, "AI initializes an aiming plan")
	_check((game.get("rt_projectiles") as Array).is_empty(), "realtime match starts without projectiles")
	var aim_session: RealtimeAIAimingSession = game.get("realtime_ai_aim") as RealtimeAIAimingSession
	_check(aim_session != null and aim_session.has_plan, "world runtime composes an active AI aim session")
	_check(
		aim_session != null and
		(aim_session.get_script() as Script).resource_path == "res://scripts/ai/RealtimeAIAimingSession.gd",
		"realtime AI aim session is owned by the AI domain directory"
	)
	_check(is_finite(aim_session.target_angle) and is_finite(aim_session.target_power_percent), "AI session stores finite aim targets")

	game.set("rt_ai_fire_cooldown", 100.0)
	game.call("_update_realtime_ai", 0.016)
	game.call("_clear_realtime_ai_visual_plan")
	_check(not aim_session.has_plan, "AI plan reset clears the composed session")
	game.call("_choose_realtime_ai_visual_plan")
	_check(aim_session.has_plan, "AI plan recomputes through composed session")
	_check((game.get("realtime_ai_aim") as RealtimeAIAimingSession).has_plan, "AI maintains a smooth aiming plan")

	game.call("_fire_realtime_projectile", 0)
	var shots: Array = game.get("rt_projectiles")
	_check(not shots.is_empty(), "human realtime shell launches")
	if not shots.is_empty():
		_check(int((shots[0] as Dictionary).get("owner", -1)) == 0, "human shell retains owner")
		game.call("_update_all_realtime_projectiles", 0.016)
		_check(not (game.get("rt_projectiles") as Array).is_empty(), "human shell advances in realtime")

	var aim_point: Vector2 = Vector2(470.0, 285.0)
	game.set("cluster_camera_hold_timer", 0.0)
	game.set("cluster_camera_hold_pos", Vector2.INF)
	game.call("_start_global_explosion_camera_hold", Vector2.INF)
	_check(is_zero_approx(float(game.get("cluster_camera_hold_timer"))), "invalid camera focus is ignored")

	# Use the owner-aware realtime explosion API from the active special-weapons
	# facade. AI impacts must not steal the camera from the human player.
	game.call("_explode_realtime_weapon", aim_point, WeaponCatalog.STANDARD, 1)
	_check(is_zero_approx(float(game.get("cluster_camera_hold_timer"))), "AI explosion does not trigger human camera hold")
	_check(game.get("cluster_camera_hold_pos") == Vector2.INF, "AI explosion does not move camera target")

	var human_impact: Vector2 = Vector2(560.0, 280.0)
	game.call("_explode_realtime_weapon", human_impact, WeaponCatalog.STANDARD, 0)
	_check(is_equal_approx(float(game.get("cluster_camera_hold_timer")), 0.5), "human explosion starts short camera hold")
	_check(game.get("cluster_camera_hold_pos") == human_impact, "camera follows human explosion")
	_check(not bool(game.get("manual_camera_active")), "camera hold disables manual panning")
	# The former inheritance layer also clamps longer cluster camera holds.
	game.set("cluster_camera_hold_timer", 0.85)
	game.call("_process", 0.0)
	_check(float(game.get("cluster_camera_hold_timer")) <= 0.50001, "legacy global camera hold clamp survives layer retirement")

	game.call("reset_match")
	_check(is_zero_approx(float(game.get("cluster_camera_hold_timer"))), "reset clears explosion hold")

	game.queue_free()
	await process_frame
	_finish()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("FAIL: ", description)

func _finish_with_failure(description: String) -> void:
	_check(false, description)
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("PASS: realtime and camera integration (%d assertions)" % checks)
		quit(0)
	else:
		printerr("FAIL: realtime and camera integration (%d/%d assertions failed)" % [failures.size(), checks])
		quit(1)
