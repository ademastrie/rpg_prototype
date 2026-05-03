extends Node3D

@export var player_placeholder_scene: PackedScene

var players: Dictionary = {}
var _spawned_nodes: Dictionary = {}


func register_peer(peer_id: int) -> void:
	for existing_peer_id in players:
		var spawn_position: Vector3 = players[existing_peer_id]
		rpc_id(peer_id, "spawn_player", existing_peer_id, spawn_position)

	_register_player(peer_id)
	var peer_position: Vector3 = players[peer_id]
	rpc("spawn_player", peer_id, peer_position)


func unregister_peer(peer_id: int) -> void:
	players.erase(peer_id)
	rpc("despawn_player", peer_id)


func _register_player(peer_id: int) -> void:
	players[peer_id] = _spawn_position_for_peer(peer_id)


func _spawn_position_for_peer(peer_id: int) -> Vector3:
	return Vector3((peer_id % 8) * 2.0, 0.0, int(peer_id / 8) * 2.0)


@rpc("authority", "call_remote", "reliable")
func spawn_player(peer_id: int, spawn_position: Vector3) -> void:
	if _spawned_nodes.has(peer_id):
		_spawned_nodes[peer_id].position = spawn_position
		return

	if player_placeholder_scene == null:
		print("Cannot spawn player %s: player placeholder scene is not set." % peer_id)
		return

	var player := player_placeholder_scene.instantiate()
	player.name = "Player_%s" % peer_id
	player.position = spawn_position
	add_child(player)
	_spawned_nodes[peer_id] = player

	print("Spawned player for peer %s at %s." % [peer_id, spawn_position])


@rpc("authority", "call_remote", "reliable")
func despawn_player(peer_id: int) -> void:
	if not _spawned_nodes.has(peer_id):
		return

	_spawned_nodes[peer_id].queue_free()
	_spawned_nodes.erase(peer_id)
	print("Despawned player for peer %s." % peer_id)
