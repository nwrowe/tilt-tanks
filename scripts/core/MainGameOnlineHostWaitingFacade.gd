extends "res://scripts/core/MainGameProgressionFacade.gd"

# Keeps the Online Duel host in a private waiting room until the guest joins.
# Also adds online-only smoothing/animation glue on top of the authoritative host state.

const ONLINE_DUEL_IDLE_SYNC_INTERVAL: float = 0.10
const ONLINE_DUEL_ACTIVE_SYNC_INTERVAL: float = 0.033
const ONLINE_DUEL_TANK_SMOOTH_TIME: float = 0.14
const ONLINE_DUEL_PROJECTILE_SMOOTH_TIME: float = 0.055

var online_host_wait_label: Label = null
var online_host_wait_seconds: float = 0.0
var online_host_wait_port: int = ONLINE_DUEL_DEFAULT_PORT

var online_client_has_authoritative_state: bool = false
var online_client_tank_targets: Array = []
var online_client_projectile_target: Vector2 = Vector2.INF
var online_client_was_projectile_active: bool = false

func _process(delta: float) -> void:
	if _is_online_host_waiting_screen_active():
		_update_online_host_waiting_screen(delta)
		return

	super._process(delta)

	if _is_online_duel_active() and online_is_host:
		_online_maybe_force_pending_turn_advance()
		_online_process_host_sync(delta)

func reset_match() -> void:
	_online_clear_client_smoothing()
	super.reset_match()

func _clear_menu_controls() -> void:
	online_host_wait_label = null
	super._clear_menu_controls()

func _online_disconnect() -> void:
	super._online_disconnect()
	online_host_wait_seconds = 0.0
	online_host_wait_label = null
	_online_clear_client_smoothing()

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

	_update_camera(delta)
	_update_ui()
	_update_muzzle_effects(delta)
	_update_hotseat_start_turn_button()
	queue_redraw()

func _online_process_host_sync(delta: float) -> void:
	if online_remote_peer_id == 0:
		return
	online_sync_timer -= delta
	if online_sync_timer > 0.0:
		return
	var interval: float = ONLINE_DUEL_ACTIVE_SYNC_INTERVAL if _online_has_active_authoritative_motion() else ONLINE_DUEL_IDLE_SYNC_INTERVAL
	online_sync_timer = interval
	_online_send_snapshot(_online_has_active_authoritative_motion())

@rpc("authority", "reliable")
func _online_receive_snapshot(snapshot: Dictionary) -> void:
	if online_is_host:
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
