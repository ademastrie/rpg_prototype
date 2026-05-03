extends Node3D

signal spawned_player_count_changed(count: int)

@export var player_placeholder_scene: PackedScene

var players: Dictionary = {}
var _spawned_nodes: Dictionary = {}
var _next_spawn_index := 0

const SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(3, 0, 0),
	Vector3(-3, 0, 0),
	Vector3(0, 0, 3),
	Vector3(0, 0, -3),
	Vector3(3, 0, 3),
	Vector3(-3, 0, 3),
	Vector3(3, 0, -3),
	Vector3(-3, 0, -3),
]


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
	players[peer_id] = _spawn_position_for_index(_next_spawn_index)
	_next_spawn_index += 1


func _spawn_position_for_index(spawn_index: int) -> Vector3:
	if spawn_index < SPAWN_POSITIONS.size():
		return SPAWN_POSITIONS[spawn_index]

	var overflow_index := spawn_index - SPAWN_POSITIONS.size()
	var ring := int(overflow_index / 8) + 1
	var slot := overflow_index % 8
	var distance := 6.0 + ring * 3.0
	var offsets: Array[Vector3] = [
		Vector3(distance, 0, 0),
		Vector3(-distance, 0, 0),
		Vector3(0, 0, distance),
		Vector3(0, 0, -distance),
		Vector3(distance, 0, distance),
		Vector3(-distance, 0, distance),
		Vector3(distance, 0, -distance),
		Vector3(-distance, 0, -distance),
	]
	return offsets[slot]


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
	_set_peer_label(player, peer_id)

	print("Network player instantiated on client: peer_id=%s position=%s node_name=%s" % [peer_id, spawn_position, player.name])
	spawned_player_count_changed.emit(_spawned_nodes.size())


@rpc("authority", "call_remote", "reliable")
func despawn_player(peer_id: int) -> void:
	if not _spawned_nodes.has(peer_id):
		return

	_spawned_nodes[peer_id].queue_free()
	_spawned_nodes.erase(peer_id)
	print("Despawned player for peer %s." % peer_id)
	spawned_player_count_changed.emit(_spawned_nodes.size())


func _set_peer_label(player: Node, peer_id: int) -> void:
	var peer_label := player.get_node_or_null("PeerLabel")
	if peer_label != null:
		peer_label.text = "Peer %s" % peer_id
