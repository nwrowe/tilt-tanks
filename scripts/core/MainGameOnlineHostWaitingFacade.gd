extends "res://scripts/core/MainGameProgressionFacade.gd"

# Keeps the Online Duel host in a private waiting room until the guest joins.
# Also adds online-only smoothing/animation glue on top of the authoritative host state.

const ONLINE_DUEL_IDLE_SYNC_INTERVAL: float = 0.10
const ONLINE_DUEL_ACTIVE_SYNC_INTERVAL: float = 0.033
const ONLINE_DUEL_TANK_SMOOTH_TIME: float = 0.14
const ONLINE_DUEL_PROJECTILE_SMOOTH_TIME: float = 0.055
const ONLINE_DUEL_TURN_ADVANCE_FALLBACK_DELAY: float = 1.25

var online_host_wait_label: Label = null
var online_host_wait_seconds: float = 0.0
var online_host_wait_port: int = ONLINE_DUEL_DEFAULT_PORT

var online_client_has_authoritative_state: bool = false
var online_client_tank_targets: Array = []
var online_client_projectile_target: Vector2 = Vector2.INF
var online_client_was_projectile_active: bool = false
var online_snapshot_seq: int = 0
var online_client_last_full_snapshot_seq: int = -1
var online_client_last_motion_snapshot_seq: int = -1
var online_turn_advance_fallback_timer: float = 0.0
var online_turn_advance_fallback_owner: int = -1

func _process(delta: float) -> void:
	if _is_online_host_waiting_screen_active():
		_update_online_host_waiting_screen(delta)
		return

	super._process(delta)

	if _is_online_duel_active() and online_is_host:
		_online_process_turn_advance_fallback(delta)
		_online_maybe_force_pending_turn_advance()
		_online_process_host_sync(delta)

func reset_match() -> void:
	_online_clear_client_smoothing()
	_online_clear_turn_advance_fallback()
	super.reset_match()

func _clear_menu_controls() -> void:
	online_host_wait_label = null
	super._clear_menu_controls()

func _online_disconnect() -> void:
	super._online_disconnect()
	online_host_wait_seconds = 0.0
	online_host_wait_label = null
	online_snapshot_seq = 0
	online_client_last_full_snapshot_seq = -1
	online_client_last_motion_snapshot_seq = -1
	_online_clear_client_smoothing()
	_online_clear_turn_advance_fallback()

func _on_online_host_pressed() -> void:
	_online_disconnect()
	_online_connect_multiplayer_signals()
	online_peer = ENetMultiplayerPeer.new()
	online_host_wait_port = _online_menu_port()
	var err: int = online_peer.create_server(online_host_wait_port, ONLINE_DUEL_MAX_CLIENTS)
	if err != OK:
		_show_online_status_menu("Could not host Online Duel on port %d. Error: %d" % [online_host_wait_port, err])
		return

	multiplayer.multiplayer_peer = online_peer
	online_is_host = true
	online_connected = false
	online_local_player = ONLINE_DUEL_HOST_PLAYER
	online_remote_peer_id = 0
	online_status_text = "Waiting for opponent to join..."
	game_mode = GAME_MODE_ONLINE_DUEL
	online_host_wait_seconds = 0.0
	_show_online_host_waiting_screen()

func _show_online_host_waiting_screen() -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label("Online Duel", Vector2(0.5, 0.24), Vector2(460, 48), 32)
	online_host_wait_label = _add_text_label(_online_host_waiting_label_text(), Vector2(0.5, 0.40), Vector2(620, 48), 24)
	_add_multiline_menu_label(
		"Waiting for an opponent to join this private match. Give them your device IP and port %d." % online_host_wait_port,
		Vector2(0.5, 0.52),
		Vector2(700, 72),
		17
	)
	_add_plain_menu_button("Cancel", Vector2(0.5, 0.70), Vector2(210, 56), _cancel_online_host_waiting_screen)
	queue_redraw()

func _cancel_online_host_waiting_screen() -> void:
	_online_disconnect()
	_show_online_duel_menu()

func _is_online_host_waiting_screen_active() -> bool:
	return (
		menu_state == MENU_STATE_MULTIPLAYER
		and online_is_host
		and online_peer != null
		and online_remote_peer_id == 0
	)

func _update_online_host_waiting_screen(delta: float) -> void:
	online_host_wait_seconds += delta
	if online_host_wait_label != null:
		online_host_wait_label.text = _online_host_waiting_label_text()
	queue_redraw()

func _online_host_waiting_label_text() -> String:
	return "Waiting for opponent to join... %02ds" % int(floor(online_host_wait_seconds))

func _on_online_peer_connected(peer_id: int) -> void:
	if not online_is_host:
		super._on_online_peer_connected(peer_id)
		return
	online_remote_peer_id = peer_id
	online_connected = true
	online_status_text = "Guest connected. Host is Player 1. Guest is Player 2."
	game_mode = GAME_MODE_ONLINE_DUEL
	_start_game(false)
	_online_send_snapshot(true)

func _process_online_client(delta: float) -> void:
	if menu_state != MENU_STATE_GAME:
		queue_redraw()
		return

	_online_update_client_interpolation(delta)

	if _online_is_local_turn() and not _is_hotseat_turn_start_prompt_active() and not online_client_waiting_for_authority:
		_update_angle_from_input(delta)
		_update_hotseat_charge(delta)
	else:
		_clear_hotseat_handoff_input_state()

	if explosion_timer > 0.0:
		explosion_timer = maxf(0.0, explosion_timer - delta)
		if explosion_timer <= 0.0:
			explosion_pos = Vector2.INF

	_update_camera(delta)
	_update_ui()
	_update_muzzle_effects(delta)
	_update_hotseat_start_turn_button()
	queue_redraw()

func _on_fire_pressed() -> void:
	var send_fire_event: bool = (
		_is_online_duel_active()
		and online_is_host
		and _online_is_local_turn()
		and not projectile_active
		and turn_projectiles.is_empty()
		and not game_over
		and not overlay_open
		and not _is_hotseat_turn_start_prompt_active()
	)
	var firing_player: int = current_player
	var firing_angle: float = angle_deg
	var firing_power_percent: float = power_percent
	var firing_weapon: String = selected_weapon

	super._on_fire_pressed()

	if send_fire_event and projectile_active and online_remote_peer_id != 0:
		_online_send_fire_event(firing_player, firing_angle, firing_power_percent, firing_weapon, projectile_pos)
		_online_send_snapshot(true)

func _advance_turn() -> void:
	super._advance_turn()
	_online_clear_turn_advance_fallback()
	if _is_online_duel_active() and online_is_host:
		online_sync_timer = 0.0
		_online_send_snapshot(true)

func _explode_turn_weapon(pos: Vector2, weapon: String, advance_after: bool) -> void:
	var owner_before_explosion: int = current_player
	super._explode_turn_weapon(pos, weapon, advance_after)
	if _is_online_duel_active() and online_is_host:
		_online_send_snapshot(true)
		if advance_after and not game_over and current_player == owner_before_explosion:
			online_turn_advance_fallback_owner = owner_before_explosion
			online_turn_advance_fallback_timer = ONLINE_DUEL_TURN_ADVANCE_FALLBACK_DELAY

func _maybe_advance_after_explosion_hold() -> void:
	var player_before: int = current_player
	var pending_before: bool = pending_advance_after_explosion_hold
	super._maybe_advance_after_explosion_hold()
	if _is_online_duel_active() and online_is_host:
		if player_before != current_player or (pending_before and not pending_advance_after_explosion_hold):
			_online_clear_turn_advance_fallback()
			_online_send_snapshot(true)

func _online_process_host_sync(delta: float) -> void:
	if online_remote_peer_id == 0:
		return
	online_sync_timer -= delta
	if online_sync_timer > 0.0:
		return
	var active_motion: bool = _online_has_active_authoritative_motion()
	online_sync_timer = ONLINE_DUEL_ACTIVE_SYNC_INTERVAL if active_motion else ONLINE_DUEL_IDLE_SYNC_INTERVAL
	_online_send_snapshot(false)

func _online_send_snapshot(force: bool) -> void:
	if not _is_online_duel_active() or not online_is_host:
		return
	if online_remote_peer_id == 0:
		return
	var snapshot: Dictionary
	if force:
		snapshot = _online_make_snapshot()
		snapshot["seq"] = _online_next_snapshot_seq()
		_online_receive_snapshot.rpc_id(online_remote_peer_id, snapshot)
	else:
		snapshot = _online_make_motion_snapshot()
		snapshot["seq"] = _online_next_snapshot_seq()
		_online_receive_motion_snapshot.rpc_id(online_remote_peer_id, snapshot)

func _online_make_motion_snapshot() -> Dictionary:
	return {
		"tank_positions": _online_pack_vec2_array(tank_positions),
		"tank_health": tank_health.duplicate(),
		"player_angles": player_angles.duplicate(),
		"player_power_percents": player_power_percents.duplicate(),
		"player_powers": player_powers.duplicate(),
		"current_player": current_player,
		"angle_deg": angle_deg,
		"power_percent": power_percent,
		"power": power,
		"wind": wind,
		"turn_timer": turn_timer,
		"game_over": game_over,
		"selected_weapon": selected_weapon,
		"projectile_active": projectile_active,
		"projectile_pos": _online_pack_vec2(projectile_pos),
		"projectile_vel": _online_pack_vec2(projectile_vel),
		"turn_projectiles": turn_projectiles.duplicate(true),
		"explosion_pos": _online_pack_vec2(explosion_pos),
		"explosion_timer": explosion_timer,
		"hotseat_turn_start_pending": hotseat_turn_start_pending,
		"pending_advance_after_explosion_hold": pending_advance_after_explosion_hold,
		"cluster_camera_hold_timer": cluster_camera_hold_timer,
		"cluster_camera_hold_pos": _online_pack_vec2(cluster_camera_hold_pos),
		"turn_cluster_camera_pos": _online_pack_vec2(turn_cluster_camera_pos)
	}

func _online_next_snapshot_seq() -> int:
	online_snapshot_seq += 1
	return online_snapshot_seq

func _online_accept_full_snapshot_seq(snapshot: Dictionary) -> bool:
	var seq: int = int(snapshot.get("seq", -1))
	if seq < 0:
		return true
	if seq <= online_client_last_full_snapshot_seq:
		return false
	online_client_last_full_snapshot_seq = seq
	online_client_last_motion_snapshot_seq = maxi(online_client_last_motion_snapshot_seq, seq)
	return true

func _online_accept_motion_snapshot_seq(snapshot: Dictionary) -> bool:
	var seq: int = int(snapshot.get("seq", -1))
	if seq < 0:
		return true
	if seq <= online_client_last_motion_snapshot_seq:
		return false
	online_client_last_motion_snapshot_seq = seq
	return true

func _online_accept_fire_event_seq(event: Dictionary) -> bool:
	var seq: int = int(event.get("seq", -1))
	if seq < 0:
		return true
	if seq <= online_client_last_full_snapshot_seq:
		return false
	online_client_last_motion_snapshot_seq = maxi(online_client_last_motion_snapshot_seq, seq)
	return true

@rpc("authority", "reliable")
func _online_receive_snapshot(snapshot: Dictionary) -> void:
	if online_is_host:
		return
	if not _online_accept_full_snapshot_seq(snapshot):
		return

	var previous_tanks: Array = tank_positions.duplicate()
	var previous_projectile_pos: Vector2 = projectile_pos
	var was_projectile_active: bool = projectile_active
	var previous_turn_projectile_count: int = turn_projectiles.size()

	super._online_receive_snapshot(snapshot)

	var authoritative_tanks: Array = tank_positions.duplicate()
	online_client_tank_targets = authoritative_tanks.duplicate()
	if online_client_has_authoritative_state and previous_tanks.size() == authoritative_tanks.size():
		tank_positions = previous_tanks.duplicate()
	else:
		tank_positions = authoritative_tanks.duplicate()
		online_client_has_authoritative_state = true

	if projectile_active:
		online_client_projectile_target = projectile_pos
		if not was_projectile_active:
			_trigger_fire_fx(current_player, angle_deg)
		else:
			projectile_pos = previous_projectile_pos
	elif not turn_projectiles.is_empty() and previous_turn_projectile_count == 0:
		_trigger_fire_fx(current_player, angle_deg)
		online_client_projectile_target = Vector2.INF
	else:
		online_client_projectile_target = Vector2.INF

	online_client_was_projectile_active = projectile_active
	queue_redraw()

@rpc("authority", "reliable")
func _online_receive_motion_snapshot(snapshot: Dictionary) -> void:
	if online_is_host:
		return
	if not _online_accept_motion_snapshot_seq(snapshot):
		return

	var was_projectile_active: bool = projectile_active
	var previous_turn_projectile_count: int = turn_projectiles.size()

	var authoritative_tanks: Array = []
	for packed_tank: Variant in snapshot.get("tank_positions", []):
		authoritative_tanks.append(_online_unpack_vec2(packed_tank))
	if authoritative_tanks.size() == tank_positions.size():
		online_client_tank_targets = authoritative_tanks.duplicate()
		if not online_client_has_authoritative_state:
			tank_positions = authoritative_tanks.duplicate()
			online_client_has_authoritative_state = true

	tank_health = _online_int_array(snapshot.get("tank_health", tank_health), tank_health)
	player_angles = _online_float_array(snapshot.get("player_angles", player_angles), player_angles)
	player_power_percents = _online_float_array(snapshot.get("player_power_percents", player_power_percents), player_power_percents)
	player_powers = _online_float_array(snapshot.get("player_powers", player_powers), player_powers)
	current_player = int(snapshot.get("current_player", current_player))
	angle_deg = float(snapshot.get("angle_deg", angle_deg))
	power_percent = float(snapshot.get("power_percent", power_percent))
	power = float(snapshot.get("power", power))
	wind = float(snapshot.get("wind", wind))
	turn_timer = float(snapshot.get("turn_timer", turn_timer))
	game_over = bool(snapshot.get("game_over", game_over))
	selected_weapon = str(snapshot.get("selected_weapon", selected_weapon))

	projectile_active = bool(snapshot.get("projectile_active", projectile_active))
	var authoritative_projectile_pos: Vector2 = _online_unpack_vec2(snapshot.get("projectile_pos", _online_pack_vec2(projectile_pos)))
	var authoritative_projectile_vel: Vector2 = _online_unpack_vec2(snapshot.get("projectile_vel", _online_pack_vec2(projectile_vel)))
	if projectile_active:
		online_client_projectile_target = authoritative_projectile_pos
		projectile_vel = authoritative_projectile_vel
		if not was_projectile_active:
			projectile_pos = authoritative_projectile_pos
			_trigger_fire_fx(current_player, angle_deg)
	else:
		online_client_projectile_target = Vector2.INF
		projectile_pos = authoritative_projectile_pos
		projectile_vel = authoritative_projectile_vel

	turn_projectiles.clear()
	for shell: Variant in snapshot.get("turn_projectiles", []):
		if shell is Dictionary:
			turn_projectiles.append((shell as Dictionary).duplicate(true))
	if not turn_projectiles.is_empty() and previous_turn_projectile_count == 0:
		_trigger_fire_fx(current_player, angle_deg)

	explosion_pos = _online_unpack_vec2(snapshot.get("explosion_pos", _online_pack_vec2(explosion_pos)))
	explosion_timer = float(snapshot.get("explosion_timer", explosion_timer))
	hotseat_turn_start_pending = bool(snapshot.get("hotseat_turn_start_pending", hotseat_turn_start_pending))
	pending_advance_after_explosion_hold = bool(snapshot.get("pending_advance_after_explosion_hold", pending_advance_after_explosion_hold))
	cluster_camera_hold_timer = float(snapshot.get("cluster_camera_hold_timer", cluster_camera_hold_timer))
	cluster_camera_hold_pos = _online_unpack_vec2(snapshot.get("cluster_camera_hold_pos", _online_pack_vec2(cluster_camera_hold_pos)))
	turn_cluster_camera_pos = _online_unpack_vec2(snapshot.get("turn_cluster_camera_pos", _online_pack_vec2(turn_cluster_camera_pos)))
	online_client_waiting_for_authority = false

	if current_player >= 0 and current_player < player_angles.size():
		angle_deg = player_angles[current_player]
	if current_player >= 0 and current_player < player_power_percents.size():
		power_percent = player_power_percents[current_player]
		power = _power_from_percent(power_percent)
	if power_slider != null:
		power_slider.value = power_percent

	_sync_match_state_from_runtime()
	_update_hotseat_start_turn_button()
	queue_redraw()

func _online_send_fire_event(owner: int, shot_angle: float, shot_power_percent: float, weapon: String, pos: Vector2) -> void:
	if online_remote_peer_id == 0:
		return
	var event: Dictionary = {
		"seq": _online_next_snapshot_seq(),
		"owner": owner,
		"angle": shot_angle,
		"power_percent": shot_power_percent,
		"power": _power_from_percent(shot_power_percent),
		"weapon": weapon,
		"projectile_pos": _online_pack_vec2(pos),
		"wind": wind
	}
	_online_receive_fire_event.rpc_id(online_remote_peer_id, event)

@rpc("authority", "reliable")
func _online_receive_fire_event(event: Dictionary) -> void:
	if online_is_host:
		return
	if not _online_accept_fire_event_seq(event):
		return
	var owner: int = int(event.get("owner", current_player))
	var shot_angle: float = float(event.get("angle", angle_deg))
	var shot_power_percent: float = float(event.get("power_percent", power_percent))
	var shot_power: float = float(event.get("power", _power_from_percent(shot_power_percent)))
	current_player = owner
	angle_deg = shot_angle
	power_percent = shot_power_percent
	power = shot_power
	selected_weapon = str(event.get("weapon", selected_weapon))
	wind = float(event.get("wind", wind))
	if owner >= 0 and owner < player_angles.size():
		player_angles[owner] = shot_angle
		player_power_percents[owner] = shot_power_percent
		player_powers[owner] = shot_power
	projectile_pos = _online_unpack_vec2(event.get("projectile_pos", _online_pack_vec2(projectile_pos)))
	projectile_vel = _online_projectile_velocity_for(owner, shot_angle, shot_power)
	projectile_active = true
	turn_projectiles.clear()
	online_client_projectile_target = projectile_pos
	_trigger_fire_fx(owner, shot_angle)
	queue_redraw()

func _online_projectile_velocity_for(owner: int, shot_angle: float, shot_power: float) -> Vector2:
	var facing: float = 1.0 if owner == ONLINE_DUEL_HOST_PLAYER else -1.0
	var rad: float = deg_to_rad(shot_angle)
	return Vector2(facing * shot_power * cos(rad), -shot_power * sin(rad))

func _online_update_client_interpolation(delta: float) -> void:
	if not _is_online_duel_active() or online_is_host:
		return

	if online_client_tank_targets.size() == tank_positions.size():
		var tank_alpha: float = clampf(delta / ONLINE_DUEL_TANK_SMOOTH_TIME, 0.0, 1.0)
		for i: int in range(tank_positions.size()):
			var target: Vector2 = online_client_tank_targets[i]
			tank_positions[i] = tank_positions[i].lerp(target, tank_alpha)

	if projectile_active and online_client_projectile_target != Vector2.INF:
		var projectile_alpha: float = clampf(delta / ONLINE_DUEL_PROJECTILE_SMOOTH_TIME, 0.0, 1.0)
		projectile_pos = projectile_pos.lerp(online_client_projectile_target, projectile_alpha)

func _online_clear_client_smoothing() -> void:
	online_client_has_authoritative_state = false
	online_client_tank_targets.clear()
	online_client_projectile_target = Vector2.INF
	online_client_was_projectile_active = false

func _online_has_active_authoritative_motion() -> bool:
	return (
		projectile_active
		or not turn_projectiles.is_empty()
		or machine_gun_active
		or machine_gun_turn_waiting_for_shells
		or pending_advance_after_explosion_hold
		or explosion_timer > 0.0
		or cluster_camera_hold_timer > 0.0
	)

func _online_process_turn_advance_fallback(delta: float) -> void:
	if online_turn_advance_fallback_owner < 0:
		return
	if current_player != online_turn_advance_fallback_owner:
		_online_clear_turn_advance_fallback()
		return
	online_turn_advance_fallback_timer = maxf(0.0, online_turn_advance_fallback_timer - delta)
	if online_turn_advance_fallback_timer > 0.0:
		return
	if game_over or projectile_active or not turn_projectiles.is_empty() or machine_gun_active or machine_gun_turn_waiting_for_shells:
		return
	if explosion_timer > 0.0 or cluster_camera_hold_timer > 0.0:
		return
	pending_advance_after_explosion_hold = false
	machine_gun_camera_active = false
	machine_gun_camera_pos = Vector2.INF
	_advance_turn()
	_online_send_snapshot(true)

func _online_clear_turn_advance_fallback() -> void:
	online_turn_advance_fallback_timer = 0.0
	online_turn_advance_fallback_owner = -1

func _online_maybe_force_pending_turn_advance() -> void:
	if not _is_online_duel_active() or not online_is_host:
		return
	if not pending_advance_after_explosion_hold:
		return
	if game_over or projectile_active or not turn_projectiles.is_empty() or machine_gun_active or machine_gun_turn_waiting_for_shells:
		return
	if explosion_timer > 0.0 or cluster_camera_hold_timer > 0.0:
		return
	pending_advance_after_explosion_hold = false
	machine_gun_camera_active = false
	machine_gun_camera_pos = Vector2.INF
	_advance_turn()
	_online_send_snapshot(true)
