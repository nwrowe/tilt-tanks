extends SceneTree
## Integration test: run two independent Godot processes on loopback.
## Both peers instantiate the REAL gameplay scene and use its ENet callbacks.
## -- --role=host (first process); -- --role=guest (second process)

const TEST_PORT: int = 23587
const TIMEOUT_MS: int = 10000
const HEAVY: String = WeaponCatalog.HEAVY

var game: Node2D
var failures: Array[String] = []
var role: String = ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	if role != "host" and role != "guest":
		printerr("FAIL: supply -- --role=host or --role=guest")
		quit(1)
		return

	var scene: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	if scene == null:
		_fail("main scene could not load")
		_finish()
		return
	game = scene.instantiate() as Node2D
	if game == null:
		_fail("game scene could not instantiate")
		_finish()
		return
	root.add_child(game)
	await process_frame
	game.call("_show_online_duel_menu")
	var port_field: LineEdit = game.get("online_join_port_field") as LineEdit
	if port_field == null:
		_fail("online menu port field missing")
		_finish()
		return
	port_field.text = str(TEST_PORT)
	if role == "host":
		await _run_host()
	else:
		await _run_guest()
	game.call("_online_disconnect")
	var connection: OnlineDuelConnection = game.get("online_connection") as OnlineDuelConnection
	_check(connection != null and connection.peer == null, "online session releases transport after disconnect")
	game.queue_free()
	await process_frame
	_finish()

func _run_host() -> void:
	game.call("_on_online_host_pressed")
	var connection: OnlineDuelConnection = game.get("online_connection") as OnlineDuelConnection
	_check(connection != null and connection.peer != null, "host connection component owns ENet peer")
	_check(game.get("online_peer") == connection.peer, "host legacy peer pointer matches owner")
	_check(bool(game.get("online_is_host")), "host starts as authority")
	_check(bool(game.call("_is_online_host_waiting_screen_active")), "host enters waiting room")
	if not await _until(func() -> bool: return bool(game.get("online_connected")) and int(game.get("online_remote_peer_id")) != 0):
		_fail("host never received the guest connection")
		return
	_check(int(game.get("menu_state")) == 4, "host enters gameplay after guest joins")
	_check(int(game.get("current_player")) == 0, "host has first turn")
	game.call("_on_hotseat_start_turn_pressed")
	_check(not bool(game.get("hotseat_turn_start_pending")), "host starts first turn")
	await create_timer(0.25).timeout
	game.call("_set_selected_weapon_for_current_player", HEAVY)
	game.set("hotseat_release_in_progress", true)
	game.call("_on_fire_pressed")
	game.set("hotseat_release_in_progress", false)
	_check(bool(game.get("projectile_active")), "host fires authoritative Heavy shell")
	# Keep the server alive long enough for guest to receive authoritative
	# motion/full snapshots and the fire event.
	await create_timer(2.0).timeout

func _run_guest() -> void:
	var host_field: LineEdit = game.get("online_join_host_field") as LineEdit
	if host_field == null:
		_fail("online host field missing")
		return
	host_field.text = "127.0.0.1"
	game.call("_on_online_join_pressed")
	var connection: OnlineDuelConnection = game.get("online_connection") as OnlineDuelConnection
	_check(connection != null and connection.peer != null, "guest connection component owns ENet peer")
	_check(game.get("online_peer") == connection.peer, "guest legacy peer pointer matches owner")
	_check(not bool(game.get("online_is_host")), "guest is not authoritative")
	if not await _until(func() -> bool: return bool(game.get("online_connected")) and int(game.get("menu_state")) == 4):
		_fail("guest never joined the live game")
		return
	var seq: OnlineSnapshotSequencer = game.get("online_snapshot_sequencer") as OnlineSnapshotSequencer
	if not await _until(func() -> bool: return seq.last_full_sequence >= 0):
		_fail("guest never received initial authoritative state")
		return
	_check(int(game.get("current_player")) == 0, "guest recognizes host's starting turn")
	var smoother: OnlineDuelInterpolation = game.get("online_interpolation") as OnlineDuelInterpolation
	_check(smoother != null and smoother.has_authoritative_state, "client interpolation stores authoritative tank targets")
	if not await _until(func() -> bool: return str(game.get("selected_weapon")) == HEAVY):
		_fail("guest never observed the host's Heavy weapon")
		return
	_check(str(game.get("selected_weapon")) == HEAVY, "guest receives host's weapon selection")
	_check(seq.last_motion_sequence > seq.last_full_sequence or seq.last_full_sequence > 0, "guest receives host protocol updates")
	# Full snapshots are sent at fire time. Assert a real post-join update,
	# rather than merely verifying that an ENet socket connected.
	_check(seq.last_full_sequence > 0, "guest receives subsequent reliable state")

func _until(predicate: Callable) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < TIMEOUT_MS:
		if predicate.call():
			return true
		await process_frame
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL [", role, "]: ", message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: online ENet two-process integration [", role, "]")
		quit(0)
	else:
		printerr("FAIL: online ENet integration [", role, "] (", failures.size(), " failures)")
		quit(1)
