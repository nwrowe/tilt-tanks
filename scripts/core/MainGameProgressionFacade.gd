extends "res://scripts/core/MainGameSpecialWeaponsFacade.gd"

# Thin runtime hook for tank progression UI/state.
# This intentionally exposes read-only tank summaries first; combat math and
# purchasing/training flows should be integrated in later, smaller passes.

const TANK_PANEL_SIZE: Vector2 = Vector2(330.0, 318.0)
const TANK_PANEL_POS: Vector2 = Vector2(548.0, 58.0)
const TANK_SETUP_BUTTON_POS: Vector2 = Vector2(698.0, 12.0)
const TANK_SETUP_BUTTON_SIZE: Vector2 = Vector2(76.0, 38.0)
const HOTSEAT_START_TURN_BUTTON_SIZE: Vector2 = Vector2(300.0, 68.0)
const HOTSEAT_START_TURN_BUTTON_POS: Vector2 = Vector2(300.0, 238.0)

const GAME_MODE_ONLINE_DUEL: int = 3
const ONLINE_DUEL_DEFAULT_HOST: String = "127.0.0.1"
const ONLINE_DUEL_DEFAULT_PORT: int = 23458
const ONLINE_DUEL_MAX_CLIENTS: int = 1
const ONLINE_DUEL_HOST_PLAYER: int = 0
const ONLINE_DUEL_CLIENT_PLAYER: int = 1
const ONLINE_DUEL_SNAPSHOT_INTERVAL: float = 0.10

var tank_classes: Dictionary = {}
var tank_upgrades: Dictionary = {}
var tank_crew: Dictionary = {}
var player_tank_builds: Array[TankBuildState] = []
var tank_panel: Panel = null
var tank_summary_label: Label = null
var tank_setup_button: Button = null
var tank_panel_player_index: int = 0
var campaign_map_scroll: ScrollContainer = null
var hotseat_turn_start_pending: bool = false
var hotseat_start_turn_button: Button = null

var online_connection: OnlineDuelConnection = OnlineDuelConnection.new()
var online_peer: ENetMultiplayerPeer = null
var online_is_host: bool = false
var online_connected: bool = false
var online_local_player: int = ONLINE_DUEL_HOST_PLAYER
var online_remote_peer_id: int = 0
var online_status_text: String = ""
var online_sync_timer: float = 0.0
var online_client_waiting_for_authority: bool = false
var online_join_host_field: LineEdit = null
var online_join_port_field: LineEdit = null

func _ready() -> void:
	_initialize_progression_state()
	super._ready()
	_update_tank_setup_button_visibility()

func reset_match() -> void:
	hotseat_turn_start_pending = false
	online_client_waiting_for_authority = false
	_initialize_player_tank_builds()
	super.reset_match()
	_sync_match_state_tank_builds()
	_update_tank_setup_button_visibility()
	_refresh_tank_summary_panel()
	_arm_hotseat_turn_start_prompt()
	if _is_online_duel_active() and online_is_host:
		_online_send_snapshot(true)

func _initialize_progression_state() -> void:
	if tank_classes.is_empty():
		tank_classes = TankProgressionRegistry.build_default_tank_classes()
	if tank_upgrades.is_empty():
		tank_upgrades = TankProgressionRegistry.build_default_upgrades()
	if tank_crew.is_empty():
		tank_crew = TankProgressionRegistry.build_default_crew()
	_initialize_player_tank_builds()

func _initialize_player_tank_builds() -> void:
	player_tank_builds = [
		TankProgressionRegistry.default_player_build(0),
		TankProgressionRegistry.default_player_build(1)
	]
	_sync_match_state_tank_builds()

func _sync_match_state_tank_builds() -> void:
	if match_state == null:
		return
	for i: int in range(player_tank_builds.size()):
		match_state.set_tank_build_for_player(i, player_tank_builds[i])

func _build_overlay_ui() -> void:
	super._build_overlay_ui()
	_build_tank_setup_button()
	_build_tank_summary_panel()
	_build_hotseat_start_turn_button()
	_update_tank_setup_button_visibility()

func _show_game_ui() -> void:
	super._show_game_ui()
	_update_tank_setup_button_visibility()

func _return_to_main_menu() -> void:
	hotseat_turn_start_pending = false
	_update_hotseat_start_turn_button()
	_close_tank_summary_panel()
	_online_disconnect()
	super._return_to_main_menu()
	_update_tank_setup_button_visibility()
	_update_hotseat_start_turn_button()

func _clear_menu_controls() -> void:
	campaign_map_scroll = null
	online_join_host_field = null
	online_join_port_field = null
	super._clear_menu_controls()

func _advance_turn() -> void:
	super._advance_turn()
	_arm_hotseat_turn_start_prompt()
	if _is_online_duel_active() and online_is_host:
		_online_send_snapshot(true)

func _process(delta: float) -> void:
	if _is_online_duel_active() and not online_is_host:
		_process_online_client(delta)
		return

	if _should_hold_for_hotseat_turn_start():
		_process_hotseat_turn_start_wait(delta)
		return

	super._process(delta)
	_update_hotseat_start_turn_button()
	if _is_online_duel_active() and online_is_host:
		_online_process_host_sync(delta)

func _process_online_client(delta: float) -> void:
	if menu_state != MENU_STATE_GAME:
		queue_redraw()
		return
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

func _hotseat_can_begin_charge() -> bool:
	if _is_hotseat_turn_start_prompt_active():
		return false
	if _is_online_duel_active():
		if not _online_is_local_turn() or online_client_waiting_for_authority:
			return false
	return super._hotseat_can_begin_charge()

func _on_fire_pressed() -> void:
	if _is_online_duel_active():
		if not _online_is_local_turn():
			_reset_hotseat_charge()
			return
		if not online_is_host:
			_online_submit_fire_request()
			return
	super._on_fire_pressed()
	if _is_online_duel_active() and online_is_host:
		_online_send_snapshot(true)

func _update_ui() -> void:
	super._update_ui()
	if _is_online_duel_active() and menu_state == MENU_STATE_GAME:
		_update_online_duel_status_ui()
		return
	if _is_hotseat_turn_start_prompt_active() and not game_over:
		status_label.text = "Pass phone to Player %d" % (current_player + 1)
		power_label.text = "Press START"

func _show_multiplayer_menu() -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Hotseat", BUTTON_HOTSEAT_PATH, Vector2(0.5, 0.58), Vector2(310, 72), _on_hotseat_pressed)
	_add_menu_button("Online Duel", BUTTON_ONLINE_PATH, Vector2(0.5, 0.69), Vector2(310, 72), _on_online_pressed)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.82), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _on_campaign_pressed() -> void:
	_show_campaign_hub_menu()

func _on_online_pressed() -> void:
	_show_online_duel_menu()

func _show_online_duel_menu() -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label("Online Duel", Vector2(0.5, 0.16), Vector2(460, 48), 32)
	_add_multiline_menu_label("Private, turn-based, host-authoritative duel. Host a match, then have your opponent join by IP and port on the same network or through port forwarding.", Vector2(0.5, 0.27), Vector2(700, 72), 17)
	_add_plain_menu_button("Host Private Duel", Vector2(0.5, 0.42), Vector2(310, 60), _on_online_host_pressed)
	_add_text_label("Join Host", Vector2(0.5, 0.52), Vector2(240, 34), 20)
	online_join_host_field = _add_menu_line_edit(ONLINE_DUEL_DEFAULT_HOST, "Host IP", Vector2(0.43, 0.60), Vector2(260, 44))
	online_join_port_field = _add_menu_line_edit(str(ONLINE_DUEL_DEFAULT_PORT), "Port", Vector2(0.67, 0.60), Vector2(120, 44))
	_add_plain_menu_button("Join Duel", Vector2(0.5, 0.71), Vector2(310, 58), _on_online_join_pressed)
	_add_plain_menu_button("Back", Vector2(0.5, 0.84), Vector2(210, 54), _show_multiplayer_menu)
	queue_redraw()

func _add_menu_line_edit(text: String, placeholder: String, anchor: Vector2, size: Vector2) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.text = text
	field.placeholder_text = placeholder
	field.size = size
	field.position = _anchored_position(anchor, size)
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 18)
	menu_layer.add_child(field)
	menu_buttons.append(field)
	return field

func _on_online_host_pressed() -> void:
	_online_disconnect()
	_online_connect_multiplayer_signals()
	var port: int = _online_menu_port()
	var err: int = online_connection.host(multiplayer, port, ONLINE_DUEL_MAX_CLIENTS)
	online_peer = online_connection.peer
	if err != OK:
		_show_online_status_menu("Could not host Online Duel on port %d. Error: %d" % [port, err])
		return
	online_is_host = true
	online_connected = true
	online_local_player = ONLINE_DUEL_HOST_PLAYER
	online_remote_peer_id = 0
	online_status_text = "Hosting private duel on port %d. Waiting for guest..." % port
	game_mode = GAME_MODE_ONLINE_DUEL
	_start_game(false)

func _on_online_join_pressed() -> void:
	_online_disconnect()
	_online_connect_multiplayer_signals()
	var host: String = ONLINE_DUEL_DEFAULT_HOST
	if online_join_host_field != null:
		host = online_join_host_field.text.strip_edges()
	if host.is_empty():
		host = ONLINE_DUEL_DEFAULT_HOST
	var port: int = _online_menu_port()
	var err: int = online_connection.join(multiplayer, host, port)
	online_peer = online_connection.peer
	if err != OK:
		_show_online_status_menu("Could not join %s:%d. Error: %d" % [host, port, err])
		return
	online_is_host = false
	online_connected = false
	online_local_player = ONLINE_DUEL_CLIENT_PLAYER
	online_remote_peer_id = 1
	online_status_text = "Connecting to %s:%d..." % [host, port]
	_show_online_status_menu(online_status_text)

func _show_online_status_menu(message: String) -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label("Online Duel", Vector2(0.5, 0.40), Vector2(460, 48), 30)
	_add_multiline_menu_label(message, Vector2(0.5, 0.53), Vector2(680, 92), 18)
	_add_plain_menu_button("Back", Vector2(0.5, 0.74), Vector2(210, 54), _show_online_duel_menu)
	queue_redraw()

func _online_menu_port() -> int:
	if online_join_port_field == null:
		return ONLINE_DUEL_DEFAULT_PORT
	var parsed: int = int(online_join_port_field.text.strip_edges())
	if parsed <= 0:
		return ONLINE_DUEL_DEFAULT_PORT
	return parsed

func _online_connect_multiplayer_signals() -> void:
	online_connection.connect_signals(
		multiplayer,
		_on_online_peer_connected,
		_on_online_peer_disconnected,
		_on_online_connected_to_server,
		_on_online_connection_failed,
		_on_online_server_disconnected
	)

func _online_disconnect() -> void:
	online_connection.close_peer(multiplayer)
	online_peer = null
	online_is_host = false
	online_connected = false
	online_remote_peer_id = 0
	online_status_text = ""
	online_sync_timer = 0.0
	online_client_waiting_for_authority = false

func _on_online_peer_connected(peer_id: int) -> void:
	if not online_is_host:
		return
	online_remote_peer_id = peer_id
	online_connected = true
	online_status_text = "Guest connected. Host is Player 1. Guest is Player 2."
	_online_send_snapshot(true)

func _on_online_peer_disconnected(peer_id: int) -> void:
	if peer_id == online_remote_peer_id or not online_is_host:
		online_remote_peer_id = 0
		online_connected = false
		online_status_text = "Opponent disconnected."
		_update_hotseat_start_turn_button()

func _on_online_connected_to_server() -> void:
	online_connected = true
	online_is_host = false
	online_local_player = ONLINE_DUEL_CLIENT_PLAYER
	online_remote_peer_id = 1
	online_status_text = "Connected. You are Player 2. Waiting for host state..."
	game_mode = GAME_MODE_ONLINE_DUEL
	_start_game(false)

func _on_online_connection_failed() -> void:
	online_status_text = "Connection failed."
	_show_online_status_menu(online_status_text)
	_online_disconnect()

func _on_online_server_disconnected() -> void:
	online_status_text = "Host disconnected."
	_show_online_status_menu(online_status_text)
	_online_disconnect()

func _is_online_duel_active() -> bool:
	return menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_ONLINE_DUEL

func _online_is_local_turn() -> bool:
	if not _is_online_duel_active():
		return true
	return current_player == online_local_player

func _online_can_use_turn_button() -> bool:
	if not _is_online_duel_active():
		return true
	return _online_is_local_turn() and not online_client_waiting_for_authority

func _online_process_host_sync(delta: float) -> void:
	if online_remote_peer_id == 0:
		return
	online_sync_timer -= delta
	if online_sync_timer <= 0.0:
		online_sync_timer = ONLINE_DUEL_SNAPSHOT_INTERVAL
		_online_send_snapshot(false)

func _online_submit_fire_request() -> void:
	if not _is_online_duel_active() or online_is_host:
		return
	if not _online_is_local_turn() or online_client_waiting_for_authority or _is_hotseat_turn_start_prompt_active():
		_reset_hotseat_charge()
		return
	online_client_waiting_for_authority = true
	var payload: Dictionary = {
		"angle": angle_deg,
		"power_percent": power_percent,
		"weapon": selected_weapon
	}
	_online_request_fire.rpc_id(1, payload)
	_reset_hotseat_charge()
	_update_hotseat_start_turn_button()

@rpc("any_peer", "reliable")
func _online_request_start_turn() -> void:
	if not _is_online_duel_active() or not online_is_host:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != online_remote_peer_id:
		return
	if current_player != ONLINE_DUEL_CLIENT_PLAYER or not _is_hotseat_turn_start_prompt_active():
		return
	_start_pending_turn_locally()
	_online_send_snapshot(true)

@rpc("any_peer", "reliable")
func _online_request_fire(payload: Dictionary) -> void:
	if not _is_online_duel_active() or not online_is_host:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != online_remote_peer_id:
		return
	if current_player != ONLINE_DUEL_CLIENT_PLAYER:
		return
	if projectile_active or not turn_projectiles.is_empty() or game_over or overlay_open or _is_hotseat_turn_start_prompt_active():
		return
	angle_deg = clampf(float(payload.get("angle", 45.0)), MOBILE_MIN_ANGLE, MOBILE_MAX_ANGLE)
	power_percent = clampf(float(payload.get("power_percent", POWER_PERCENT_DEFAULT)), HOTSEAT_CHARGE_MIN_PERCENT, HOTSEAT_CHARGE_MAX_PERCENT)
	power = _power_from_percent(power_percent)
	selected_weapon = OnlineDuelCodec.safe_requested_weapon(payload, active_weapon_loadout, WEAPON_STANDARD)
	player_angles[current_player] = angle_deg
	player_power_percents[current_player] = power_percent
	player_powers[current_player] = power
	hotseat_release_in_progress = true
	super._on_fire_pressed()
	hotseat_release_in_progress = false
	_reset_hotseat_charge()
	_online_send_snapshot(true)

@rpc("authority", "reliable")
func _online_receive_snapshot(snapshot: Dictionary) -> void:
	if online_is_host:
		return
	_online_apply_snapshot(snapshot)

func _online_send_snapshot(force: bool) -> void:
	if not _is_online_duel_active() or not online_is_host:
		return
	if online_remote_peer_id == 0:
		return
	_online_receive_snapshot.rpc_id(online_remote_peer_id, _online_make_snapshot())

func _online_make_snapshot() -> Dictionary:
	return {
		"active_world_width": active_world_width,
		"active_right_start_x": active_right_start_x,
		"terrain_points": OnlineDuelCodec.pack_vec2_array(terrain_points),
		"ponds": ponds.duplicate(true),
		"tank_positions": OnlineDuelCodec.pack_vec2_array(tank_positions),
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
		"projectile_pos": OnlineDuelCodec.pack_vec2(projectile_pos),
		"projectile_vel": OnlineDuelCodec.pack_vec2(projectile_vel),
		"turn_projectiles": turn_projectiles.duplicate(true),
		"explosion_pos": OnlineDuelCodec.pack_vec2(explosion_pos),
		"explosion_timer": explosion_timer,
		"hotseat_turn_start_pending": hotseat_turn_start_pending,
		"pending_advance_after_explosion_hold": pending_advance_after_explosion_hold,
		"cluster_camera_hold_timer": cluster_camera_hold_timer,
		"cluster_camera_hold_pos": OnlineDuelCodec.pack_vec2(cluster_camera_hold_pos)
	}

func _online_apply_snapshot(snapshot: Dictionary) -> void:
	active_world_width = float(snapshot.get("active_world_width", active_world_width))
	active_right_start_x = float(snapshot.get("active_right_start_x", active_right_start_x))
	terrain_points.clear()
	for packed_point: Variant in snapshot.get("terrain_points", []):
		terrain_points.append(OnlineDuelCodec.unpack_vec2(packed_point))
	if not terrain_points.is_empty():
		_refresh_terrain_line()
	ponds.clear()
	for pond: Variant in snapshot.get("ponds", []):
		if pond is Dictionary:
			ponds.append((pond as Dictionary).duplicate(true))
	tank_positions.clear()
	for packed_tank: Variant in snapshot.get("tank_positions", []):
		tank_positions.append(OnlineDuelCodec.unpack_vec2(packed_tank))
	if tank_positions.size() < 2:
		tank_positions = [Vector2(TANK_START_LEFT_X, 0.0), Vector2(active_right_start_x, 0.0)]
	tank_health = OnlineDuelCodec.int_array(snapshot.get("tank_health", tank_health), tank_health)
	player_angles = OnlineDuelCodec.float_array(snapshot.get("player_angles", player_angles), player_angles)
	player_power_percents = OnlineDuelCodec.float_array(snapshot.get("player_power_percents", player_power_percents), player_power_percents)
	player_powers = OnlineDuelCodec.float_array(snapshot.get("player_powers", player_powers), player_powers)
	current_player = int(snapshot.get("current_player", current_player))
	angle_deg = float(snapshot.get("angle_deg", angle_deg))
	power_percent = float(snapshot.get("power_percent", power_percent))
	power = float(snapshot.get("power", power))
	wind = float(snapshot.get("wind", wind))
	turn_timer = float(snapshot.get("turn_timer", turn_timer))
	game_over = bool(snapshot.get("game_over", game_over))
	selected_weapon = str(snapshot.get("selected_weapon", selected_weapon))
	projectile_active = bool(snapshot.get("projectile_active", projectile_active))
	projectile_pos = OnlineDuelCodec.unpack_vec2(snapshot.get("projectile_pos", projectile_pos))
	projectile_vel = OnlineDuelCodec.unpack_vec2(snapshot.get("projectile_vel", projectile_vel))
	turn_projectiles.clear()
	for shell: Variant in snapshot.get("turn_projectiles", []):
		if shell is Dictionary:
			turn_projectiles.append((shell as Dictionary).duplicate(true))
	explosion_pos = OnlineDuelCodec.unpack_vec2(snapshot.get("explosion_pos", explosion_pos))
	explosion_timer = float(snapshot.get("explosion_timer", explosion_timer))
	hotseat_turn_start_pending = bool(snapshot.get("hotseat_turn_start_pending", hotseat_turn_start_pending))
	pending_advance_after_explosion_hold = bool(snapshot.get("pending_advance_after_explosion_hold", pending_advance_after_explosion_hold))
	cluster_camera_hold_timer = float(snapshot.get("cluster_camera_hold_timer", cluster_camera_hold_timer))
	cluster_camera_hold_pos = OnlineDuelCodec.unpack_vec2(snapshot.get("cluster_camera_hold_pos", cluster_camera_hold_pos))
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

func _update_online_duel_status_ui() -> void:
	if status_label == null or power_label == null:
		return
	if game_over:
		return
	var role: String = "Host P1" if online_is_host else "Guest P2"
	var connection: String = "connected" if online_connected else "waiting"
	if _is_hotseat_turn_start_prompt_active():
		if _online_is_local_turn():
			status_label.text = "Online Duel %s (%s): your turn" % [role, connection]
			power_label.text = "Press START"
		else:
			status_label.text = "Online Duel %s (%s): opponent turn" % [role, connection]
			power_label.text = "Waiting"
		return
	if _online_is_local_turn():
		status_label.text = "Online Duel %s (%s): aim and hold FIRE" % [role, connection]
		if online_client_waiting_for_authority:
			power_label.text = "Waiting for host"
	elif online_status_text.is_empty():
		status_label.text = "Online Duel %s (%s): opponent turn" % [role, connection]
		power_label.text = "Waiting"
	else:
		status_label.text = online_status_text
		power_label.text = "Waiting"

func _show_campaign_hub_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_close_tank_summary_panel()
	_clear_menu_controls()
	_build_campaign_map_scroll()
	_add_text_label("Campaign", Vector2(0.5, 0.08), Vector2(460, 48), 32)
	_add_multiline_menu_label("Swipe horizontally to follow the campaign route. Tap a level node to launch it.", Vector2(0.5, 0.155), Vector2(680, 40), 17)
	_add_plain_menu_button("Tank Garage", Vector2(0.78, 0.91), Vector2(220, 52), _show_tank_garage_menu)
	_add_plain_menu_button("Back", Vector2(0.22, 0.91), Vector2(180, 52), _show_single_player_menu)
	queue_redraw()

func _build_campaign_map_scroll() -> void:
	# Own only the navigation callback and menu lifecycle; all map UI and input
	# behavior are implemented by CampaignMapView.
	var view: CampaignMapView = CampaignMapView.new()
	menu_layer.add_child(view)
	view.configure(get_viewport_rect().size, _start_campaign_level)
	campaign_map_scroll = view
	menu_buttons.append(view)

func _on_campaign_map_scroll_gui_input(event: InputEvent) -> void:
	# Compatibility seam for callers/tests that still invoke the root hook.
	if campaign_map_scroll is CampaignMapView:
		(campaign_map_scroll as CampaignMapView).handle_scroll_input(event)

func _scroll_campaign_map_by(delta_x: float) -> void:
	if campaign_map_scroll is CampaignMapView:
		(campaign_map_scroll as CampaignMapView).scroll_by(delta_x)

func _show_tank_garage_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_close_tank_summary_panel()
	_clear_menu_controls()
	# Menu controls are kept in the root cleanup registry, but their presentation
	# and data formatting live in the standalone garage builder.
	var controls: Array[Control] = TankGarageView.build_ui(
		menu_layer,
		get_viewport_rect().size,
		0,
		_tank_build_for_player(0),
		tank_classes,
		tank_upgrades,
		tank_crew,
		_show_campaign_hub_menu
	)
	menu_buttons.append_array(controls)
	queue_redraw()

func _start_campaign_level(level_index: int) -> void:
	_select_campaign_mode()
	_start_game(true)

func _add_plain_menu_button(text: String, anchor: Vector2, size: Vector2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.size = size
	button.position = _anchored_position(anchor, size)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	_style_menu_button(button)
	menu_layer.add_child(button)
	menu_buttons.append(button)
	return button

func _add_multiline_menu_label(text: String, anchor: Vector2, size: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = size
	label.position = _anchored_position(anchor, size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	menu_layer.add_child(label)
	menu_buttons.append(label)
	return label

func _build_tank_setup_button() -> void:
	if ui_layer == null or tank_setup_button != null:
		return
	tank_setup_button = MobileControls.make_button("Tank", TANK_SETUP_BUTTON_POS, TANK_SETUP_BUTTON_SIZE, ui_layer)
	tank_setup_button.pressed.connect(_toggle_tank_summary_panel)

func _update_tank_setup_button_visibility() -> void:
	if tank_setup_button != null:
		tank_setup_button.visible = menu_state == MENU_STATE_GAME and not game_over

func _build_tank_summary_panel() -> void:
	if ui_layer == null or tank_panel != null:
		return
	tank_panel = Panel.new()
	tank_panel.visible = false
	tank_panel.position = TANK_PANEL_POS
	tank_panel.size = TANK_PANEL_SIZE
	ui_layer.add_child(tank_panel)

	var title: Label = Label.new()
	title.text = "Tank Setup"
	title.position = Vector2(16.0, 12.0)
	title.size = Vector2(220.0, 24.0)
	tank_panel.add_child(title)

	tank_summary_label = Label.new()
	tank_summary_label.position = Vector2(16.0, 44.0)
	tank_summary_label.size = Vector2(298.0, 210.0)
	tank_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tank_panel.add_child(tank_summary_label)

	var player_toggle_button: Button = MobileControls.make_button("Switch Player", Vector2(16.0, 260.0), Vector2(142.0, 36.0), tank_panel)
	player_toggle_button.pressed.connect(_toggle_tank_summary_player)

	var close_button: Button = MobileControls.make_button("Close", Vector2(172.0, 260.0), Vector2(142.0, 36.0), tank_panel)
	close_button.pressed.connect(_close_tank_summary_panel)

func _toggle_tank_summary_panel() -> void:
	if tank_setup_button != null:
		tank_setup_button.release_focus()
	if tank_panel == null:
		return
	if weapon_menu_open:
		_close_weapon_menu()
	if menu_panel != null and menu_panel.visible:
		menu_panel.visible = false
	tank_panel_player_index = clampi(current_player, 0, 1)
	tank_panel.visible = not tank_panel.visible
	if tank_panel.visible:
		_refresh_tank_summary_panel()
	overlay_open = _any_overlay_open()

func _close_tank_summary_panel() -> void:
	if tank_panel != null:
		tank_panel.visible = false
	overlay_open = _any_overlay_open()

func _toggle_tank_summary_player() -> void:
	tank_panel_player_index = 1 - clampi(tank_panel_player_index, 0, 1)
	_refresh_tank_summary_panel()

func _refresh_tank_summary_panel() -> void:
	if tank_summary_label == null:
		return
	tank_summary_label.text = _tank_summary_text(tank_panel_player_index)

func _tank_summary_text(player_index: int) -> String:
	var build: TankBuildState = _tank_build_for_player(player_index)
	var tank_class: TankClassDefinition = TankProgressionRegistry.get_tank_class(tank_classes, build.tank_class_id)
	var stats: Dictionary = TankProgressionRegistry.effective_stats(build, tank_classes, tank_upgrades, tank_crew)
	var lines: Array[String] = []
	lines.append("Player %d" % (player_index + 1))
	lines.append("Class: %s  (Tier %d)" % [tank_class.display_name, tank_class.tier])
	lines.append("Credits: %d" % build.credits)
	lines.append("")
	lines.append("Health: %.0f" % float(stats.get(TankProgressionRegistry.STAT_MAX_HEALTH, 100.0)))
	lines.append("Armor: %.0f%%" % (100.0 * float(stats.get(TankProgressionRegistry.STAT_DAMAGE_RESIST, 0.0))))
	lines.append("Fire Power: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_FIRE_POWER, 1.0)))
	lines.append("Aim Stability: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_AIM_STABILITY, 1.0)))
	lines.append("Reload: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_RELOAD_SPEED, 1.0)))
	lines.append("Engine: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_ENGINE_POWER, 1.0)))
	lines.append("Tracks: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_TRACK_GRIP, 1.0)))
	lines.append("")
	lines.append("Crew: %s" % _crew_summary(build))
	lines.append("Upgrades: %s" % _upgrade_summary(build))
	lines.append("")
	lines.append("Read-only for now; purchase/training flow comes next.")
	return "\n".join(lines)

func _tank_build_for_player(player_index: int) -> TankBuildState:
	if player_index >= 0 and player_index < player_tank_builds.size():
		return player_tank_builds[player_index]
	return TankProgressionRegistry.default_player_build(player_index)

func _crew_summary(build: TankBuildState) -> String:
	if build.assigned_crew_ids.is_empty():
		return "None"
	var names: Array[String] = []
	for crew_id: String in build.assigned_crew_ids:
		var member: CrewMemberDefinition = TankProgressionRegistry.get_crew_member(tank_crew, crew_id)
		if member != null:
			names.append("%s L%d" % [member.display_name, member.level])
	return ", ".join(names) if not names.is_empty() else "None"

func _upgrade_summary(build: TankBuildState) -> String:
	if build.installed_upgrade_ids.is_empty():
		return "None"
	var names: Array[String] = []
	for upgrade_id: String in build.installed_upgrade_ids:
		var upgrade: TankUpgradeDefinition = TankProgressionRegistry.get_upgrade(tank_upgrades, upgrade_id)
		if upgrade != null:
			names.append(upgrade.display_name)
	return ", ".join(names) if not names.is_empty() else "None"

func _build_hotseat_start_turn_button() -> void:
	if hotseat_start_turn_button != null:
		return
	hotseat_start_turn_button = MobileControls.make_button(
		"Start Turn",
		HOTSEAT_START_TURN_BUTTON_POS,
		HOTSEAT_START_TURN_BUTTON_SIZE,
		ui_layer
	)
	hotseat_start_turn_button.visible = false
	hotseat_start_turn_button.pressed.connect(_on_hotseat_start_turn_pressed)

func _arm_hotseat_turn_start_prompt() -> void:
	if _is_hotseat_turn_start_prompt_mode() and not game_over:
		hotseat_turn_start_pending = true
		turn_timer = TURN_TIME_LIMIT
		_reset_hotseat_charge()
		_clear_hotseat_handoff_input_state()
	else:
		hotseat_turn_start_pending = false
	_update_hotseat_start_turn_button()

func _on_hotseat_start_turn_pressed() -> void:
	if hotseat_start_turn_button != null:
		hotseat_start_turn_button.release_focus()
	if not _is_hotseat_turn_start_prompt_active():
		hotseat_turn_start_pending = false
		_update_hotseat_start_turn_button()
		return
	if _is_online_duel_active() and not online_is_host:
		if _online_is_local_turn() and not online_client_waiting_for_authority:
			online_client_waiting_for_authority = true
			_online_request_start_turn.rpc_id(1)
			_update_hotseat_start_turn_button()
		return
	if _is_online_duel_active() and not _online_is_local_turn():
		return
	_start_pending_turn_locally()
	if _is_online_duel_active() and online_is_host:
		_online_send_snapshot(true)

func _start_pending_turn_locally() -> void:
	hotseat_turn_start_pending = false
	turn_timer = TURN_TIME_LIMIT
	if match_state != null:
		match_state.turn_timer = turn_timer
	_reset_hotseat_charge()
	_clear_hotseat_handoff_input_state()
	_update_hotseat_start_turn_button()
	queue_redraw()

func _process_hotseat_turn_start_wait(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_match()
		return

	_clear_hotseat_handoff_input_state()
	_update_camera(delta)
	_update_ui()
	_update_muzzle_effects(delta)
	_update_hotseat_start_turn_button()
	queue_redraw()

func _should_hold_for_hotseat_turn_start() -> bool:
	return (
		_is_hotseat_turn_start_prompt_active()
		and not overlay_open
		and not projectile_active
		and turn_projectiles.is_empty()
		and not machine_gun_active
		and not machine_gun_turn_waiting_for_shells
		and not pending_advance_after_explosion_hold
		and explosion_timer <= 0.0
		and cluster_camera_hold_timer <= 0.0
	)

func _is_hotseat_turn_start_prompt_active() -> bool:
	return hotseat_turn_start_pending and _is_hotseat_turn_start_prompt_mode() and not game_over

func _is_hotseat_turn_start_prompt_mode() -> bool:
	return menu_state == MENU_STATE_GAME and not single_player_mode and (game_mode == GAME_MODE_HOTSEAT or game_mode == GAME_MODE_ONLINE_DUEL)

func _clear_hotseat_handoff_input_state() -> void:
	mobile_left_pressed = false
	mobile_right_pressed = false
	hotseat_fire_button_held = false
	hotseat_keyboard_fire_held = false
	if mobile_left_button != null:
		mobile_left_button.release_focus()
	if mobile_right_button != null:
		mobile_right_button.release_focus()
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _update_hotseat_start_turn_button() -> void:
	if hotseat_start_turn_button == null:
		return
	var should_show: bool = _is_hotseat_turn_start_prompt_active() and not overlay_open and _online_can_use_turn_button()
	hotseat_start_turn_button.visible = should_show
	hotseat_start_turn_button.disabled = not should_show or online_client_waiting_for_authority
	if should_show:
		hotseat_start_turn_button.text = "Start P%d Turn" % (current_player + 1)

func _toggle_menu() -> void:
	if tank_panel != null and tank_panel.visible:
		tank_panel.visible = false
	super._toggle_menu()
	overlay_open = _any_overlay_open()
	_update_hotseat_start_turn_button()

func _toggle_weapon_menu() -> void:
	if tank_panel != null and tank_panel.visible:
		tank_panel.visible = false
	super._toggle_weapon_menu()
	overlay_open = _any_overlay_open()
	_update_hotseat_start_turn_button()

func _show_end_popup() -> void:
	_close_tank_summary_panel()
	hotseat_turn_start_pending = false
	_update_hotseat_start_turn_button()
	super._show_end_popup()
	_update_tank_setup_button_visibility()
	if _is_online_duel_active() and online_is_host:
		_online_send_snapshot(true)

func _handle_outside_menu_tap(event: InputEvent) -> bool:
	var handled: bool = super._handle_outside_menu_tap(event)
	if handled:
		_update_hotseat_start_turn_button()
		return true
	if menu_state != MENU_STATE_GAME or tank_panel == null or not tank_panel.visible:
		return false
	var click_pos: Vector2 = Vector2.INF
	var is_press: bool = false
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		is_press = touch.pressed
		click_pos = touch.position
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		is_press = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		click_pos = mb.position
	if not is_press:
		return false
	if not _point_inside_control(tank_panel, click_pos) and not _point_inside_control(tank_setup_button, click_pos):
		tank_panel.visible = false
		overlay_open = _any_overlay_open()
		_update_hotseat_start_turn_button()
		return true
	return false

func _any_overlay_open() -> bool:
	return (menu_panel != null and menu_panel.visible) or (weapon_panel != null and weapon_panel.visible) or (end_panel != null and end_panel.visible) or (tank_panel != null and tank_panel.visible)
