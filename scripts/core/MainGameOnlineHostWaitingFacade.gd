extends "res://scripts/core/MainGameProgressionFacade.gd"

# Keeps the Online Duel host in a private waiting room until the guest joins.

var online_host_wait_label: Label = null
var online_host_wait_seconds: float = 0.0
var online_host_wait_port: int = ONLINE_DUEL_DEFAULT_PORT

func _process(delta: float) -> void:
	if _is_online_host_waiting_screen_active():
		_update_online_host_waiting_screen(delta)
		return
	super._process(delta)

func _clear_menu_controls() -> void:
	online_host_wait_label = null
	super._clear_menu_controls()

func _online_disconnect() -> void:
	super._online_disconnect()
	online_host_wait_seconds = 0.0
	online_host_wait_label = null

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
		"Waiting for an opponent to join this private match. Give them your device IP and port %d.",
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
