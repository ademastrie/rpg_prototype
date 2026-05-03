extends Node3D

signal spawned_player_count_changed(count: int)
signal player_spawned(peer_id: int, player: Node3D)
signal join_requested(peer_id: int, character_id: int, character_name: String, access_token: String)

@export var player_placeholder_scene: PackedScene
@export var movement_speed: float = 4.0
@export var simulation_tick_rate: float = 30.0
@export var snapshot_rate: float = 10.0
@export var interpolation_speed: float = 12.0
@export var local_prediction_enabled: bool = true
@export var local_prediction_correction_deadzone: float = 0.2
@export var local_prediction_snap_distance: float = 3.0
@export var local_prediction_correction_speed: float = 4.0

var players: Dictionary = {}
var _spawned_nodes: Dictionary = {}
var _target_positions: Dictionary = {}
var _target_facing_directions: Dictionary = {}
var _last_input_by_peer: Dictionary = {}
var _aim_direction_by_peer: Dictionary = {}
var _local_prediction_input: Vector2 = Vector2.ZERO
var _simulation_accumulator := 0.0
var _snapshot_accumulator := 0.0
var _next_spawn_index := 0
var _character_names_by_peer: Dictionary = {}

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


func send_join_request(character_id: int, character_name: String, access_token: String) -> void:
	rpc_id(1, "request_join", character_id, character_name, access_token)


func set_local_prediction_input(input_direction: Vector2) -> void:
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()

	_local_prediction_input = input_direction


func register_peer(peer_id: int, character_name: String = "") -> void:
	_register_peer(peer_id, character_name, false, Vector3.ZERO)


func register_peer_at_position(peer_id: int, character_name: String, spawn_position: Vector3) -> void:
	_register_peer(peer_id, character_name, true, spawn_position)


func _register_peer(peer_id: int, character_name: String, use_custom_spawn: bool, custom_spawn_position: Vector3) -> void:
	for existing_peer_id in players:
		var existing_peer_id_int: int = int(existing_peer_id)
		var spawn_position: Vector3 = players[existing_peer_id] as Vector3
		var existing_character_name: String = str(_character_names_by_peer.get(existing_peer_id, ""))
		rpc_id(peer_id, "spawn_player", existing_peer_id_int, spawn_position, existing_character_name)

	_register_player(peer_id, use_custom_spawn, custom_spawn_position)
	_character_names_by_peer[peer_id] = character_name
	var peer_position: Vector3 = players[peer_id] as Vector3
	rpc("spawn_player", peer_id, peer_position, character_name)
	_broadcast_position_snapshots()


func unregister_peer(peer_id: int) -> void:
	players.erase(peer_id)
	_target_positions.erase(peer_id)
	_target_facing_directions.erase(peer_id)
	_last_input_by_peer.erase(peer_id)
	_aim_direction_by_peer.erase(peer_id)
	_character_names_by_peer.erase(peer_id)
	rpc("despawn_player", peer_id)


func get_authoritative_position(peer_id: int) -> Vector3:
	if not players.has(peer_id):
		return Vector3.ZERO

	return players[peer_id] as Vector3


func get_spawned_player(peer_id: int) -> Node3D:
	if not _spawned_nodes.has(peer_id):
		return null

	return _spawned_nodes[peer_id] as Node3D


func _register_player(peer_id: int, use_custom_spawn: bool = false, custom_spawn_position: Vector3 = Vector3.ZERO) -> void:
	if use_custom_spawn:
		players[peer_id] = custom_spawn_position
	else:
		players[peer_id] = _spawn_position_for_index(_next_spawn_index)

	_last_input_by_peer[peer_id] = Vector2.ZERO
	_aim_direction_by_peer[peer_id] = Vector2(0.0, -1.0)
	_next_spawn_index += 1


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		_smooth_spawned_players(delta)
		return

	_simulation_accumulator += delta
	_snapshot_accumulator += delta

	var tick_delta := 1.0 / simulation_tick_rate
	while _simulation_accumulator >= tick_delta:
		_simulate(tick_delta)
		_simulation_accumulator -= tick_delta

	var snapshot_delta := 1.0 / snapshot_rate
	if _snapshot_accumulator >= snapshot_delta:
		_broadcast_position_snapshots()
		_snapshot_accumulator = 0.0


func _simulate(delta: float) -> void:
	for peer_id in players:
		var input_direction: Vector2 = _last_input_by_peer.get(peer_id, Vector2.ZERO) as Vector2
		if input_direction.length_squared() > 1.0:
			input_direction = input_direction.normalized()

		var position: Vector3 = players[peer_id] as Vector3
		position.x += input_direction.x * movement_speed * delta
		position.z += input_direction.y * movement_speed * delta
		players[peer_id] = position


func _broadcast_position_snapshots() -> void:
	for peer_id in players:
		var peer_id_int: int = int(peer_id)
		var position: Vector3 = players[peer_id] as Vector3
		var facing_direction: Vector2 = _aim_direction_by_peer.get(peer_id, Vector2(0.0, -1.0)) as Vector2
		rpc("apply_position_snapshot", peer_id_int, position, facing_direction)


func _smooth_spawned_players(delta: float) -> void:
	var weight: float = clamp(interpolation_speed * delta, 0.0, 1.0)
	for peer_id in _spawned_nodes:
		var peer_id_int: int = int(peer_id)
		var player: Node3D = _spawned_nodes[peer_id] as Node3D
		if _is_local_player_peer(peer_id_int):
			# Local player uses visual prediction plus reconciliation.
			_predict_and_reconcile_local_player(player, peer_id_int, delta)
		elif _target_positions.has(peer_id):
			var target_position: Vector3 = _target_positions[peer_id] as Vector3
			# Remote players use interpolation only; server snapshots remain authoritative.
			player.position = player.position.lerp(target_position, weight)

		if _target_facing_directions.has(peer_id):
			var facing_direction: Vector2 = _target_facing_directions[peer_id] as Vector2
			_apply_player_facing(player, facing_direction)


func _predict_and_reconcile_local_player(player: Node3D, peer_id: int, delta: float) -> void:
	if local_prediction_enabled:
		# Local prediction is visual only. The server still owns authoritative movement.
		player.position.x += _local_prediction_input.x * movement_speed * delta
		player.position.z += _local_prediction_input.y * movement_speed * delta

	if not _target_positions.has(peer_id):
		return

	var authoritative_position: Vector3 = _target_positions[peer_id] as Vector3
	var error_distance: float = player.position.distance_to(authoritative_position)
	if error_distance > local_prediction_snap_distance:
		player.position = authoritative_position
	elif error_distance > local_prediction_correction_deadzone:
		var correction_weight: float = clamp(local_prediction_correction_speed * delta, 0.0, 1.0)
		player.position = player.position.lerp(authoritative_position, correction_weight)


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
func spawn_player(peer_id: int, spawn_position: Vector3, character_name: String = "") -> void:
	if _spawned_nodes.has(peer_id):
		_spawned_nodes[peer_id].position = spawn_position
		_target_positions[peer_id] = spawn_position
		_set_peer_label(_spawned_nodes[peer_id] as Node, peer_id, character_name)
		return

	if player_placeholder_scene == null:
		print("Cannot spawn player %s: player placeholder scene is not set." % peer_id)
		return

	var player: Node3D = player_placeholder_scene.instantiate() as Node3D
	player.name = "Player_%s" % peer_id
	var initial_position: Vector3 = spawn_position
	if _target_positions.has(peer_id):
		initial_position = _target_positions[peer_id] as Vector3

	player.position = initial_position
	add_child(player)
	_spawned_nodes[peer_id] = player
	_target_positions[peer_id] = initial_position
	_set_peer_label(player, peer_id, character_name)

	print("Network player instantiated on client: peer_id=%s position=%s node_name=%s" % [peer_id, spawn_position, player.name])
	player_spawned.emit(peer_id, player)
	spawned_player_count_changed.emit(_spawned_nodes.size())


@rpc("authority", "call_remote", "unreliable")
func apply_position_snapshot(peer_id: int, authoritative_position: Vector3, facing_direction: Vector2 = Vector2(0.0, -1.0)) -> void:
	# Authoritative positions and facing are received here and stored as visual targets.
	_target_positions[peer_id] = authoritative_position
	_target_facing_directions[peer_id] = facing_direction
	if _spawned_nodes.has(peer_id):
		var player: Node3D = _spawned_nodes[peer_id] as Node3D
		_apply_player_facing(player, facing_direction)


@rpc("any_peer", "call_remote", "reliable")
func request_join(character_id: int, character_name: String, access_token: String) -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = int(multiplayer.get_remote_sender_id())
	join_requested.emit(peer_id, character_id, character_name, access_token)


@rpc("any_peer", "call_remote", "unreliable")
func submit_movement_input(input_direction: Vector2) -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = int(multiplayer.get_remote_sender_id())
	if not players.has(peer_id):
		return

	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()

	_last_input_by_peer[peer_id] = input_direction


@rpc("any_peer", "call_remote", "unreliable")
func submit_aim_input(aim_direction: Vector2) -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = int(multiplayer.get_remote_sender_id())
	if not players.has(peer_id):
		return

	if aim_direction.length_squared() > 1.0:
		aim_direction = aim_direction.normalized()
	if aim_direction.length_squared() <= 0.0001:
		return

	# The server stores authoritative facing intent for snapshots.
	_aim_direction_by_peer[peer_id] = aim_direction


@rpc("authority", "call_remote", "reliable")
func despawn_player(peer_id: int) -> void:
	if not _spawned_nodes.has(peer_id):
		return

	var player: Node3D = _spawned_nodes[peer_id] as Node3D
	player.queue_free()
	_spawned_nodes.erase(peer_id)
	_target_positions.erase(peer_id)
	_target_facing_directions.erase(peer_id)
	print("Despawned player for peer %s." % peer_id)
	spawned_player_count_changed.emit(_spawned_nodes.size())


func _set_peer_label(player: Node, peer_id: int, character_name: String = "") -> void:
	var peer_label: Label3D = player.get_node_or_null("PeerLabel") as Label3D
	if peer_label != null:
		if character_name.strip_edges() == "":
			peer_label.text = "Peer %s" % peer_id
		else:
			peer_label.text = "%s\nPeer %s" % [character_name, peer_id]


func _apply_player_facing(player: Node3D, facing_direction: Vector2) -> void:
	if facing_direction.length_squared() <= 0.0001:
		return

	var normalized_facing: Vector2 = facing_direction.normalized()
	player.rotation.y = atan2(-normalized_facing.x, -normalized_facing.y)


func _is_local_player_peer(peer_id: int) -> bool:
	return not multiplayer.is_server() and peer_id == multiplayer.get_unique_id()
