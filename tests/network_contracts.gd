extends SceneTree
## Tests the active host/client snapshot protocol without starting ENet peers.
## This is intentionally not a two-device connectivity or latency test.

var failures: Array[String] = []
var checks: int = 0
var game: Node2D = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	if scene == null:
		_check(false, "main scene loads")
		_finish()
		return
	game = scene.instantiate() as Node2D
	if game == null:
		_check(false, "main scene instantiates")
		_finish()
		return
	root.add_child(game)
	await process_frame
	game.set_process(false)
	_test_vector_round_trip()
	_test_snapshot_shape()
	_test_sequence_ordering()
	game.queue_free()
	await process_frame
	_finish()

func _test_vector_round_trip() -> void:
	var original: Vector2 = Vector2(123.25, -456.5)
	var packed: Variant = game.call("_online_pack_vec2", original)
	var restored: Vector2 = game.call("_online_unpack_vec2", packed)
	_check(restored.distance_to(original) < 0.001, "network Vec2 pack/unpack round-trip")

func _test_snapshot_shape() -> void:
	var snapshot: Dictionary = game.call("_online_make_snapshot")
	for field: String in ["terrain_points", "tank_positions", "tank_health", "current_player", "selected_weapon", "projectile_active", "explosion_timer", "hotseat_turn_start_pending"]:
		_check(snapshot.has(field), "full snapshot includes " + field)
	var motion: Dictionary = game.call("_online_make_motion_snapshot")
	_check(motion.has("projectile_pos"), "motion snapshot includes projectile position")
	_check(motion.has("tank_positions"), "motion snapshot includes tank positions")
	_check(not motion.has("terrain_points"), "lightweight motion snapshot omits terrain")

func _test_sequence_ordering() -> void:
	game.set("online_client_last_full_snapshot_seq", -1)
	game.set("online_client_last_motion_snapshot_seq", -1)
	_check(bool(game.call("_online_accept_full_snapshot_seq", {"seq": 10})), "initial reliable snapshot accepted")
	_check(not bool(game.call("_online_accept_full_snapshot_seq", {"seq": 9})), "older reliable snapshot rejected")
	_check(bool(game.call("_online_accept_motion_snapshot_seq", {"seq": 11})), "new motion snapshot accepted")
	_check(not bool(game.call("_online_accept_motion_snapshot_seq", {"seq": 10})), "older motion snapshot rejected")
	_check(bool(game.call("_online_accept_full_snapshot_seq", {"seq": 12})), "new reliable snapshot accepted")
	_check(not bool(game.call("_online_accept_motion_snapshot_seq", {"seq": 11})), "late motion cannot overwrite later full state")
	_check(not bool(game.call("_online_accept_fire_event_seq", {"seq": 11})), "late fire event cannot replay before full state")
	_check(bool(game.call("_online_accept_fire_event_seq", {"seq": 13})), "new fire event accepted")
	_check(not bool(game.call("_online_accept_motion_snapshot_seq", {"seq": 12})), "older motion cannot overwrite fire event")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: online snapshot contracts (%d assertions)" % checks)
		quit(0)
		return
	printerr("FAIL: online snapshot contracts (%d/%d assertions failed)" % [failures.size(), checks])
	quit(1)
