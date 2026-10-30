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
	_test_weapon_request_validation()
	_test_typed_wire_arrays()
	_test_interpolation_math()
	_test_sequencer_reset()
	game.queue_free()
	await process_frame
	_finish()

func _test_vector_round_trip() -> void:
	var original: Vector2 = Vector2(123.25, -456.5)
	var packed: Variant = OnlineDuelCodec.pack_vec2(original)
	var restored: Vector2 = OnlineDuelCodec.unpack_vec2(packed)
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
	var sequencer: OnlineSnapshotSequencer = game.get("online_snapshot_sequencer") as OnlineSnapshotSequencer
	sequencer.reset()
	_check(bool(game.call("_online_accept_full_snapshot_seq", {"seq": 10})), "initial reliable snapshot accepted")
	_check(not bool(game.call("_online_accept_full_snapshot_seq", {"seq": 9})), "older reliable snapshot rejected")
	_check(bool(game.call("_online_accept_motion_snapshot_seq", {"seq": 11})), "new motion snapshot accepted")
	_check(not bool(game.call("_online_accept_motion_snapshot_seq", {"seq": 10})), "older motion snapshot rejected")
	_check(bool(game.call("_online_accept_full_snapshot_seq", {"seq": 12})), "new reliable snapshot accepted")
	_check(not bool(game.call("_online_accept_motion_snapshot_seq", {"seq": 11})), "late motion cannot overwrite later full state")
	_check(not bool(game.call("_online_accept_fire_event_seq", {"seq": 11})), "late fire event cannot replay before full state")
	_check(bool(game.call("_online_accept_fire_event_seq", {"seq": 13})), "new fire event accepted")
	_check(not bool(game.call("_online_accept_motion_snapshot_seq", {"seq": 12})), "older motion cannot overwrite fire event")

func _test_weapon_request_validation() -> void:
	var definitions: Dictionary = WeaponRegistry.build_default_definitions()
	var loadout: WeaponLoadout = WeaponLoadout.from_registry(definitions, WeaponCatalog.STANDARD)
	_check(OnlineDuelCodec.safe_requested_weapon({"weapon": WeaponCatalog.HEAVY}, loadout, WeaponCatalog.STANDARD) == WeaponCatalog.HEAVY, "valid guest weapon remains selected")
	_check(OnlineDuelCodec.safe_requested_weapon({"weapon": "__invalid__"}, loadout, WeaponCatalog.STANDARD) == WeaponCatalog.STANDARD, "invalid guest weapon falls back to allowed shell")
	_check(OnlineDuelCodec.safe_requested_weapon({"weapon": WeaponCatalog.CLUSTER_CHILD}, loadout, WeaponCatalog.STANDARD) == WeaponCatalog.STANDARD, "unselectable child shell rejected")
	_check(OnlineDuelCodec.safe_requested_weapon({}, loadout, WeaponCatalog.STANDARD) == WeaponCatalog.STANDARD, "missing guest weapon uses default")
	_check(OnlineDuelCodec.safe_requested_weapon({}, null, WeaponCatalog.STANDARD) == WeaponCatalog.STANDARD, "missing loadout uses safe default")

func _test_typed_wire_arrays() -> void:
	var ints: Array[int] = OnlineDuelCodec.int_array([100, 77], [50, 50])
	_check(ints == [100, 77], "network health decodes to typed int array")
	var floats: Array[float] = OnlineDuelCodec.float_array([45, 31.5], [0.0, 0.0])
	_check(floats.size() == 2 and is_equal_approx(floats[1], 31.5), "player aim decodes to typed float array")
	var missing_health: Array[int] = OnlineDuelCodec.int_array(null, [100, 100])
	_check(missing_health == [100, 100], "typed health fallback for missing wire field")

func _test_interpolation_math() -> void:
	var smoother: OnlineDuelInterpolation = OnlineDuelInterpolation.new()
	var positions: Array[Vector2] = [Vector2.ZERO, Vector2(100, 20)]
	smoother.tank_targets = [Vector2(100, 0), Vector2(200, 20)]
	smoother.interpolate_tanks(positions, 0.07, 0.14)
	_check(is_equal_approx(positions[0].x, 50.0), "tank interpolation reaches midpoint in half smooth time")
	_check(is_equal_approx(positions[1].x, 150.0), "tank interpolation applies independently to both tanks")
	smoother.projectile_target = Vector2(200, 0)
	var half_projectile: Vector2 = smoother.interpolate_projectile(Vector2.ZERO, true, 0.025, 0.05)
	_check(is_equal_approx(half_projectile.x, 100.0), "projectile interpolation respects duration")
	var frozen: Vector2 = smoother.interpolate_projectile(Vector2(10, 20), false, 0.025, 0.05)
	_check(frozen == Vector2(10, 20), "inactive projectile is not smoothed")
	smoother.reset()
	_check(smoother.tank_targets.is_empty() and smoother.projectile_target == Vector2.INF, "reset discards client targets")

func _test_sequencer_reset() -> void:
	var seq: OnlineSnapshotSequencer = game.get("online_snapshot_sequencer") as OnlineSnapshotSequencer
	_check(seq.next_outgoing_sequence() == 1, "outgoing sequence starts at 1")
	_check(seq.next_outgoing_sequence() == 2, "outgoing sequence increases")
	seq.reset()
	_check(seq.next_outgoing_sequence() == 1, "reset restarts outgoing sequence")
	_check(seq.accept_full({"seq": 1}), "reset clears received sequence history")
	_check(not seq.accept_motion({"seq": 1}), "motion cannot overwrite same-seq reliable snapshot")

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
