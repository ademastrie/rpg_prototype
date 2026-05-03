extends Node

@export var server_port: int = 7777

@onready var world_spawner: Node3D = $WorldSpawner

var connected_peers: Array[int] = []


func _ready() -> void:
	print("Server game scene ready.")
	_start_server()


func _start_server() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

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
	world_spawner.register_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: %s" % peer_id)
	connected_peers.erase(peer_id)
	world_spawner.unregister_peer(peer_id)
