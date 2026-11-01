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
	_test_shared_snapshot_fields()
	_test_shared_decoder()
	_test_sequence_ordering()
	_test_weapon_request_validation()
	_test_typed_wire_arrays()
	_test_interpolation_math()
	_test_host_coordinator()
	_test_online_reset_and_disconnect_ownership()
	_test_single_host_sync_owner()
	_test_shared_online_client_frame_ownership()
	_test_shared_online_snapshot_application()
	_test_guest_command_validation()
	_test_sequencer_reset()
	game.queue_free()
	await process_frame
	_finish()

func _test_shared_online_client_frame_ownership() -> void:
	# Online client interpolation and explosion aging remain guest-specific;
	# input gating and post-frame camera/UI/effects must have one owner.
	var parent: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameProgressionFacade.gd"
	)
	var guest: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameOnlineHostWaitingFacade.gd"
	)
	var parent_start: int = parent.find("func _process_online_client(")
	var parent_end: int = parent.find("\nfunc ", parent_start + 4)
	var parent_frame: String = parent.substr(parent_start, parent_end - parent_start)
	var guest_start: int = guest.find("func _process_online_client(")
	var guest_end: int = guest.find("\nfunc ", guest_start + 4)
	var guest_frame: String = guest.substr(guest_start, guest_end - guest_start)
	_check(parent_frame.contains("_online_process_client_input(delta)") and
		parent_frame.contains("_online_finish_client_frame(delta)"),
		"base online client frame composes input and visual stages once")
	_check(guest_frame.contains("_online_update_client_interpolation(delta)") and
		guest_frame.contains("_online_process_client_input(delta)") and
		guest_frame.contains("_online_finish_client_frame(delta)") and
		not guest_frame.contains("_update_camera(delta)") and
		not guest_frame.contains("_update_hotseat_charge(delta)"),
		"online guest adds interpolation/visual aging without duplicating input and UI")
	_check(guest_frame.find("_online_update_client_interpolation(delta)") <
		guest_frame.find("_online_process_client_input(delta)") and
		guest_frame.find("_online_process_client_input(delta)") <
		guest_frame.find("if explosion_timer > 0.0:") and
		guest_frame.find("if explosion_timer > 0.0:") <
		guest_frame.find("_online_finish_client_frame(delta)"),
		"guest interpolation, input, explosion expiry and camera stages keep prior ordering")

func _test_shared_online_snapshot_application() -> void:
	# Verify both network packet paths reuse a single mutable shell-array
	# restoration and a single current-player settings/MatchState publish.
	var progression: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameProgressionFacade.gd"
	)
	var online: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameOnlineHostWaitingFacade.gd"
	)
	_check(progression.split("_online_apply_turn_shell_snapshot(snapshot)").size() == 2 and
		online.contains("_online_apply_turn_shell_snapshot(snapshot)") and
		not online.contains("turn_projectiles.append((shell as Dictionary).duplicate(true))"),
		"full and motion snapshot receivers use one turn-shell restoration implementation")
	_check(progression.split("_online_finish_received_snapshot()").size() == 2 and
		online.contains("_online_finish_received_snapshot()") and
		not online.contains("power_slider.value = power_percent"),
		"full and motion receivers publish local aim/UI and MatchState once")

	var shell_handle: Array[Dictionary] = game.get("turn_projectiles")
	var saved_shells: Array[Dictionary] = shell_handle.duplicate(true)
	var packet_shell: Dictionary = ProjectileFactory.make_shell(
		1, WeaponCatalog.HEAVY, Vector2(420.0, 125.0), Vector2(40.0, -5.0)
	)
	game.call("_online_apply_turn_shell_snapshot", {
		"turn_projectiles": [packet_shell, 123, "invalid"]
	})
	_check(shell_handle.size() == 1 and
		int(shell_handle[0].get("owner", -1)) == 1 and
		str(shell_handle[0].get("weapon", "")) == WeaponCatalog.HEAVY,
		"shared shell receiver preserves typed array identity and filters invalid wire entries")
	packet_shell["owner"] = 0
	_check(int(shell_handle[0].get("owner", -1)) == 1,
		"decoded shell dictionary is deep-copied rather than aliased to a packet")

	var original_player: int = int(game.get("current_player"))
	var original_angles: Array[float] = (game.get("player_angles") as Array[float]).duplicate()
	var original_percents: Array[float] = (game.get("player_power_percents") as Array[float]).duplicate()
	var angles: Array[float] = [20.0, 65.0]
	var percents: Array[float] = [40.0, 78.0]
	game.set("current_player", 1)
	game.set("player_angles", angles)
	game.set("player_power_percents", percents)
	game.set("online_client_waiting_for_authority", true)
	game.call("_online_finish_received_snapshot")
	_check(not bool(game.get("online_client_waiting_for_authority")) and
		is_equal_approx(float(game.get("angle_deg")), 65.0) and
		is_equal_approx(float(game.get("power_percent")), 78.0),
		"shared finish clears guest wait and restores current player's aim/charge")
	_check((game.get("match_state") as MatchState).current_player == 1 and
		is_equal_approx((game.get("match_state") as MatchState).player_angles[1], 65.0),
		"snapshot finish publishes received player settings to authoritative MatchState")
	game.set("current_player", original_player)
	game.set("player_angles", original_angles)
	game.set("player_power_percents", original_percents)
	shell_handle.clear()
	shell_handle.append_array(saved_shells)
	game.call("reset_match")

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

func _test_shared_snapshot_fields() -> void:
	var full: Dictionary = game.call("_online_make_snapshot")
	var motion: Dictionary = game.call("_online_make_motion_snapshot")
	var common_fields: Array[String] = [
		"tank_positions", "tank_health", "player_angles",
		"player_power_percents", "player_powers", "current_player",
		"angle_deg", "power_percent", "power", "wind", "turn_timer",
		"game_over", "selected_weapon", "projectile_active",
		"projectile_pos", "projectile_vel", "turn_projectiles",
		"explosion_pos", "explosion_timer", "hotseat_turn_start_pending",
		"pending_advance_after_explosion_hold",
		"cluster_camera_hold_timer", "cluster_camera_hold_pos"
	]
	for field: String in common_fields:
		_check(full.has(field) and motion.has(field), "both packets retain common field " + field)
		if full.has(field) and motion.has(field):
			_check(full[field] == motion[field], "both packet types agree on " + field)
	_check(full.has("terrain_points") and full.has("ponds"), "full packet includes terrain and ponds")
	_check(not motion.has("terrain_points") and not motion.has("ponds"), "motion packet skips static terrain")
	_check(motion.has("turn_cluster_camera_pos"), "motion packet keeps extra camera target")
	_check(not full.has("turn_cluster_camera_pos"), "full packet retains legacy key set")
	# The packet must not alias mutable gameplay arrays. RPCs may be queued.
	var original_health: int = int((game.get("tank_health") as Array)[0])
	(full["tank_health"] as Array)[0] = original_health - 1
	_check(int((game.get("tank_health") as Array)[0]) == original_health, "full packet health is copied")
	var motion_hp: Array = motion["tank_health"] as Array
	motion_hp[0] = original_health - 1
	_check(int((game.get("tank_health") as Array)[0]) == original_health, "motion packet health is copied")

func _test_shared_decoder() -> void:
	var full: Dictionary = game.call("_online_make_snapshot")
	var motion: Dictionary = game.call("_online_make_motion_snapshot")
	var fallback: Dictionary = game.call("_online_runtime_snapshot_data")
	var decoded_full: Dictionary = OnlineDuelSnapshotDecoder.decode_common(full, fallback)
	var decoded_motion: Dictionary = OnlineDuelSnapshotDecoder.decode_common(motion, fallback)
	for field: String in decoded_full:
		_check(decoded_full[field] == decoded_motion[field], "full/motion decoded " + field + " consistently")
	_check(decoded_full["tank_health"] is Array[int], "health decoder returns typed int array")
	_check(decoded_full["player_angles"] is Array[float], "angle decoder returns typed float array")
	_check(decoded_full["player_powers"] is Array[float], "power decoder returns typed float array")
	_check(decoded_full["explosion_pos"] is Vector2, "explosion target decodes into Vector2")
	var changed: Dictionary = full.duplicate(true)
	changed["tank_health"] = [91, 72]
	changed["player_angles"] = [35.0, 67.0]
	changed["current_player"] = 1
	changed["explosion_pos"] = OnlineDuelCodec.pack_vec2(Vector2(125.0, 250.0))
	var decoded: Dictionary = OnlineDuelSnapshotDecoder.decode_common(changed, fallback)
	_check(decoded["tank_health"] == [91, 72], "decoder preserves changed health")
	_check(decoded["player_angles"] == [35.0, 67.0], "decoder preserves changed aim")
	_check(int(decoded["current_player"]) == 1, "decoder preserves turn owner")
	_check(decoded["explosion_pos"] == Vector2(125.0, 250.0), "decoder unpacks explosion position")
	var missing: Dictionary = OnlineDuelSnapshotDecoder.decode_common({}, fallback)
	_check(missing["tank_health"] == fallback["tank_health"], "missing health retains runtime fallback")
	_check(missing["player_power_percents"] == fallback["player_power_percents"], "missing player power retains fallback")

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

func _test_host_coordinator() -> void:
	var host: OnlineDuelHostCoordinator = OnlineDuelHostCoordinator.new()
	_check(not host.due_for_sync(0.1, false, false, 0.033, 0.1), "host never emits updates without connected peer")
	_check(host.due_for_sync(0.0, true, false, 0.033, 0.1), "host sends immediately on connection")
	_check(not host.due_for_sync(0.05, true, false, 0.033, 0.1), "idle host does not oversend")
	_check(host.due_for_sync(0.06, true, false, 0.033, 0.1), "idle host schedules next snapshot")
	host.force_next_sync()
	_check(host.due_for_sync(0.0, true, true, 0.033, 0.1), "active projectile uses fast snapshot schedule")
	_check(not host.due_for_sync(0.01, true, true, 0.033, 0.1), "active sync respects interval")
	_check(host.due_for_sync(0.03, true, true, 0.033, 0.1), "active sync resumes after interval")
	host.arm_fallback(0, 1.25)
	_check(not host.fallback_due(0.5, 0, true), "fallback never advances before timeout")
	_check(not host.fallback_due(0.75, 0, false), "fallback waits for projectile and explosion clearance")
	_check(host.fallback_due(0.0, 0, true), "fallback advances only when time and safety allow")
	_check(not host.fallback_due(0.0, 0, true), "fallback fires only once")
	host.arm_fallback(0, 1.25)
	_check(not host.fallback_due(0.5, 1, true), "owner change cancels pending fallback")
	_check(host.fallback_owner == -1, "owner switch clears host fallback state")
	_check(OnlineDuelHostCoordinator.can_advance(false, false, false, false, false, 0.0, 0.0), "clear host turn may advance")
	_check(OnlineDuelHostCoordinator.can_advance(false, false, false, false, false, 0.0, 0.0) ==
		WeaponFramePolicy.can_advance_turn(false, false, false, false, false, 0.0, 0.0),
		"host coordinator delegates clearance to the canonical weapon frame policy")
	_check(not OnlineDuelHostCoordinator.can_advance(false, true, false, false, false, 0.0, 0.0), "projectile blocks forced advance")
	_check(not OnlineDuelHostCoordinator.can_advance(false, false, false, true, false, 0.0, 0.0), "machine gun burst blocks advance")
	_check(not OnlineDuelHostCoordinator.can_advance(false, false, false, false, false, 0.1, 0.0), "explosion delay blocks advance")
	_check(not OnlineDuelHostCoordinator.can_advance(true, false, false, false, false, 0.0, 0.0), "game over blocks advance")
	host.reset()
	_check(host.fallback_owner == -1 and host.sync_remaining == 0.0, "disconnect resets host coordination")

func _test_single_host_sync_owner() -> void:
	# _process() in the online facade calls super._process(), so calling
	# _online_process_host_sync() in a lower ancestor double-ticks its
	# shared coordinator through virtual dispatch. A host frame must tick
	# the timer exactly once, after the rest of its gameplay processing.
	var lower: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameProgressionFacade.gd"
	)
	var owner: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameOnlineHostWaitingFacade.gd"
	)
	_check(not lower.contains("_online_process_host_sync("),
		"progression frame does not double-tick the host sync coordinator")
	_check(not lower.contains("ONLINE_DUEL_SNAPSHOT_INTERVAL"),
		"retired progression-level sync interval has no second source of truth")
	_check(owner.contains("super._process(delta)") and
		owner.contains("_online_process_turn_advance_fallback(delta)") and
		owner.contains("_online_maybe_force_pending_turn_advance()"),
		"online facade retains post-gameplay authority/turn-advance ordering")
	_check(owner.split("_online_process_host_sync(delta)").size() == 2 and
		owner.split("func _online_process_host_sync(delta: float)").size() == 2,
		"online facade alone owns one host sync call and implementation")
	_check(owner.contains("ONLINE_DUEL_ACTIVE_SYNC_INTERVAL") and
		owner.contains("ONLINE_DUEL_IDLE_SYNC_INTERVAL"),
		"online facade retains distinct active and idle snapshot periods")

func _test_online_reset_and_disconnect_ownership() -> void:
	# The progression disconnect owns host-coordinator reset; the online
	# facade owns smoothing and sequencing reset. Match reset must clear
	# interpolation and fallback but leave sync scheduling state intact.
	var online_script: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameOnlineHostWaitingFacade.gd"
	)
	var progression_script: String = FileAccess.get_file_as_string(
		"res://scripts/core/MainGameProgressionFacade.gd"
	)
	_check(not online_script.contains("func _online_clear_client_smoothing(") and
		not online_script.contains("func _online_clear_turn_advance_fallback("),
		"online cleanup no longer uses one-line forwarding methods")
	_check(progression_script.contains("online_host_coordinator.reset()"),
		"progression disconnect retains canonical host timer reset")
	var host: OnlineDuelHostCoordinator = game.get(
		"online_host_coordinator") as OnlineDuelHostCoordinator
	var smoothing: OnlineDuelInterpolation = game.get(
		"online_interpolation") as OnlineDuelInterpolation
	var seq: OnlineSnapshotSequencer = game.get(
		"online_snapshot_sequencer") as OnlineSnapshotSequencer
	_check(host != null and smoothing != null and seq != null,
		"online runtime exposes its composed lifecycle owners")
	if host == null or smoothing == null or seq == null:
		return
	host.reset()
	seq.reset()
	_check(host.due_for_sync(0.0, true, false, 0.033, 0.10),
		"host sync timer can be armed before reset")
	host.arm_fallback(0, 1.25)
	smoothing.has_authoritative_state = true
	smoothing.tank_targets = [Vector2(12.0, 13.0)]
	smoothing.projectile_target = Vector2(20.0, 30.0)
	smoothing.was_projectile_active = true
	game.call("reset_match")
	_check(host.fallback_owner == -1 and is_zero_approx(host.fallback_remaining),
		"match reset clears pending online turn fallback through host coordinator")
	_check(is_equal_approx(host.sync_remaining, 0.10),
		"match reset leaves the host sync cadence untouched")
	_check(not smoothing.has_authoritative_state and
		smoothing.tank_targets.is_empty() and smoothing.projectile_target == Vector2.INF and
		not smoothing.was_projectile_active,
		"match reset clears all interpolation targets through the composed owner")
	host.arm_fallback(1, 0.55)
	host.force_next_sync()
	smoothing.has_authoritative_state = true
	smoothing.tank_targets = [Vector2(55.0, 66.0)]
	smoothing.projectile_target = Vector2(77.0, 88.0)
	_check(seq.accept_full({"seq": 10}),
		"sequence tracker accepts a packet before disconnect")
	game.call("_online_disconnect")
	_check(host.fallback_owner == -1 and is_zero_approx(host.fallback_remaining) and
		is_zero_approx(host.sync_remaining),
		"disconnect resets host timer and fallback exactly through the progression owner")
	_check(not smoothing.has_authoritative_state and
		smoothing.tank_targets.is_empty() and smoothing.projectile_target == Vector2.INF,
		"disconnect resets interpolation through online owner")
	_check(seq.last_full_sequence < 0,
		"disconnect resets the online snapshot sequence tracker")

func _test_guest_command_validation() -> void:
	_check(OnlineDuelCommandValidator.can_start_turn(42, 42, 1, 1, true), "connected guest can start its own turn")
	_check(not OnlineDuelCommandValidator.can_start_turn(23, 42, 1, 1, true), "unrecognized sender cannot start turn")
	_check(not OnlineDuelCommandValidator.can_start_turn(0, 0, 1, 1, true), "unset guest peer cannot issue turn commands")
	_check(not OnlineDuelCommandValidator.can_start_turn(42, 42, 0, 1, true), "guest cannot start host turn")
	_check(not OnlineDuelCommandValidator.can_start_turn(42, 42, 1, 1, false), "guest cannot bypass start prompt")
	_check(OnlineDuelCommandValidator.can_fire(42, 42, 1, 1, false), "guest may fire during an unblocked turn")
	_check(not OnlineDuelCommandValidator.can_fire(23, 42, 1, 1, false), "unrecognized sender cannot fire")
	_check(not OnlineDuelCommandValidator.can_fire(42, 42, 0, 1, false), "guest cannot fire during host turn")
	_check(not OnlineDuelCommandValidator.can_fire(42, 42, 1, 1, true), "guest cannot fire over active projectile or overlay")

	var definitions: Dictionary = WeaponRegistry.build_default_definitions()
	var loadout: WeaponLoadout = WeaponLoadout.from_registry(definitions, WeaponCatalog.STANDARD)
	var allowed: Dictionary = OnlineDuelCommandValidator.normalize_fire(
		{"angle": 120.0, "power_percent": -5.0, "weapon": WeaponCatalog.CLUSTER_CHILD},
		45.0, 50.0, 2.0, 94.0, 10.0, 100.0, loadout, WeaponCatalog.STANDARD
	)
	_check(is_equal_approx(float(allowed.get("angle", 0.0)), 94.0), "guest angle is clamped")
	_check(is_equal_approx(float(allowed.get("power_percent", 0.0)), 10.0), "guest power is clamped")
	_check(str(allowed.get("weapon", "")) == WeaponCatalog.STANDARD, "invalid child shell is replaced")
	var defaults: Dictionary = OnlineDuelCommandValidator.normalize_fire(
		{}, 45.0, 50.0, 2.0, 94.0, 10.0, 100.0, loadout, WeaponCatalog.STANDARD
	)
	_check(is_equal_approx(float(defaults.get("angle", 0.0)), 45.0), "guest missing angle uses default")
	_check(is_equal_approx(float(defaults.get("power_percent", 0.0)), 50.0), "guest missing power uses default")
	_check(OnlineDuelCommandValidator.normalize_fire(
		{"angle": "invalid"}, 45.0, 50.0, 2.0, 94.0, 10.0, 100.0, loadout, WeaponCatalog.STANDARD
	).is_empty(), "guest nonnumeric angle is rejected")
	_check(OnlineDuelCommandValidator.normalize_fire(
		{"power_percent": INF}, 45.0, 50.0, 2.0, 94.0, 10.0, 100.0, loadout, WeaponCatalog.STANDARD
	).is_empty(), "guest infinite power is rejected")
	_check(OnlineDuelCommandValidator.normalize_fire(
		{"angle": NAN}, 45.0, 50.0, 2.0, 94.0, 10.0, 100.0, loadout, WeaponCatalog.STANDARD
	).is_empty(), "guest NaN angle is rejected")

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
