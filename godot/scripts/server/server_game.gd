extends Node

@export var server_port: int = 7777

@onready var world_spawner: Node3D = $WorldSpawner

var connected_peers: Array[int] = []
var peer_sessions: Dictionary = {}


func _ready() -> void:
	print("Server game scene ready.")
	_start_server()


func _start_server() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	world_spawner.join_requested.connect(_on_join_requested)

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(server_port)
	if error != OK:
		print("Failed to start ENet server on port %s: %s" % [server_port, error])
		return

	multiplayer.multiplayer_peer = peer
	print("ENet server started on port %s." % server_port)


func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: %s" % peer_id)
	connected_peers.append(peer_id)
	peer_sessions[peer_id] = {
		"peer_id": peer_id,
		"character_id": 0,
		"character_name": "",
		"joined": false,
	}


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: %s" % peer_id)
	connected_peers.erase(peer_id)
	peer_sessions.erase(peer_id)
	world_spawner.unregister_peer(peer_id)


func _on_join_requested(peer_id: int, character_id: int, character_name: String, _access_token: String) -> void:
	if not connected_peers.has(peer_id):
		print("Ignoring join request from unknown peer: %s" % peer_id)
		return

	var session: Dictionary = peer_sessions.get(peer_id, {})
	if bool(session.get("joined", false)):
		print("Ignoring duplicate join request from peer: %s" % peer_id)
		return

	session = {
		"peer_id": peer_id,
		"character_id": character_id,
		"character_name": character_name,
		"joined": true,
	}
	peer_sessions[peer_id] = session
	print("Peer %s joined as character %s (%s)." % [peer_id, character_name, character_id])
	world_spawner.register_peer(peer_id, character_name)
