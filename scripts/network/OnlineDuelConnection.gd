extends RefCounted
class_name OnlineDuelConnection

## Encapsulates ENet transport lifecycle and multiplayer signal hookup.
## The game node remains the owner of RPC methods and gameplay state.
var peer: ENetMultiplayerPeer = null

func connect_signals(
	api: MultiplayerAPI,
	on_peer_connected: Callable,
	on_peer_disconnected: Callable,
	on_connected_to_server: Callable,
	on_connection_failed: Callable,
	on_server_disconnected: Callable
) -> void:
	if not api.peer_connected.is_connected(on_peer_connected):
		api.peer_connected.connect(on_peer_connected)
	if not api.peer_disconnected.is_connected(on_peer_disconnected):
		api.peer_disconnected.connect(on_peer_disconnected)
	if not api.connected_to_server.is_connected(on_connected_to_server):
		api.connected_to_server.connect(on_connected_to_server)
	if not api.connection_failed.is_connected(on_connection_failed):
		api.connection_failed.connect(on_connection_failed)
	if not api.server_disconnected.is_connected(on_server_disconnected):
		api.server_disconnected.connect(on_server_disconnected)

func host(api: MultiplayerAPI, port: int, max_clients: int) -> int:
	disconnect(api)
	var candidate: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = candidate.create_server(port, max_clients)
	if err != OK:
		candidate.close()
		return err
	peer = candidate
	api.multiplayer_peer = peer
	return OK

func join(api: MultiplayerAPI, host_address: String, port: int) -> int:
	disconnect(api)
	var candidate: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = candidate.create_client(host_address, port)
	if err != OK:
		candidate.close()
		return err
	peer = candidate
	api.multiplayer_peer = peer
	return OK

func disconnect(api: MultiplayerAPI) -> void:
	if api.multiplayer_peer != null:
		api.multiplayer_peer.close()
		api.multiplayer_peer = null
	peer = null
