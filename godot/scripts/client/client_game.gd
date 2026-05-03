extends Node3D

@export var server_host: String = "127.0.0.1"
@export var server_port: int = 7777
@export var input_heartbeat_interval: float = 0.25
@export var aim_heartbeat_interval: float = 0.35
@export var aim_change_threshold: float = 0.03
@export var camera_follow_speed: float = 8.0

@onready var status_label: Label = $StatusLabel
@onready var spawn_count_label: Label = $SpawnCountLabel
@onready var world_spawner: Node3D = $WorldSpawner
@onready var active_camera: Camera3D = $Camera3D

var selected_character: Dictionary = {}
var _local_player: Node3D = null
var _camera_follow_offset: Vector3 = Vector3.ZERO
var _fixed_camera_basis: Basis = Basis.IDENTITY
var _last_sent_input := Vector2.ZERO
var _last_sent_aim := Vector2.ZERO
var _input_heartbeat_timer := 0.0
var _aim_heartbeat_timer := 0.0
var _has_sent_input := false
var _has_sent_aim := false
var _is_connected_to_server := false
var _has_sent_join_request := false


func _ready() -> void:
	world_spawner.spawned_player_count_changed.connect(_on_spawned_player_count_changed)
	world_spawner.player_spawned.connect(_on_player_spawned)
	_camera_follow_offset = active_camera.global_position
	_fixed_camera_basis = active_camera.global_transform.basis
	_on_spawned_player_count_changed(0)
	set_selected_character(ClientSession.selected_character)
	_connect_to_server()


func set_selected_character(character_data: Dictionary) -> void:
	selected_character = character_data
	if selected_character.is_empty():
		status_label.text = "No character selected."
		print("Client game loaded without selected character data.")
		return

	var character_name := str(selected_character.get("name", "Unnamed"))
	var level := int(selected_character.get("level", 1))
	var region_id := str(selected_character.get("region_id", "unknown_region"))
	status_label.text = "Character: %s | Level %s | Region: %s" % [character_name, level, region_id]
	print("Client game loaded character: %s" % selected_character)


func _process(delta: float) -> void:
	if not _is_connected_to_server or not _has_sent_join_request:
		return

	_input_heartbeat_timer += delta
	_aim_heartbeat_timer += delta
	var input_direction := _read_movement_input()
	world_spawner.set_local_prediction_input(input_direction)
	if not _has_sent_input or input_direction != _last_sent_input or _input_heartbeat_timer >= input_heartbeat_interval:
		_send_movement_input(input_direction)

	var aim_direction: Vector2 = _read_mouse_aim_direction()
	if aim_direction != Vector2.ZERO and _should_send_aim(aim_direction):
		_send_aim_input(aim_direction)

	_update_camera_follow(delta)


func _connect_to_server() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(server_host, server_port)
	if error != OK:
		print("Failed to start ENet client: %s" % error)
		return

	multiplayer.multiplayer_peer = peer
	print("Connecting to game server at %s:%s" % [server_host, server_port])


func _on_connected_to_server() -> void:
	_is_connected_to_server = true
	print("Connected to game server.")
	_send_join_request()


func _on_connection_failed() -> void:
	_is_connected_to_server = false
	world_spawner.set_local_prediction_input(Vector2.ZERO)
	print("Failed to connect to game server.")


func _on_server_disconnected() -> void:
	_is_connected_to_server = false
	_has_sent_join_request = false
	world_spawner.set_local_prediction_input(Vector2.ZERO)
	print("Disconnected from game server.")


func _on_spawned_player_count_changed(count: int) -> void:
	spawn_count_label.text = "Network Players: %s" % count
	print("Network player count: %s" % count)


func _on_player_spawned(peer_id: int, player: Node3D) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	_local_player = player
	_snap_camera_to_local_player()
	print("Camera following local player peer %s." % peer_id)


func _read_movement_input() -> Vector2:
	var screen_direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		screen_direction.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		screen_direction.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		screen_direction.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		screen_direction.y -= 1.0

	if screen_direction == Vector2.ZERO:
		return Vector2.ZERO

	if screen_direction.length_squared() > 1.0:
		screen_direction = screen_direction.normalized()

	var world_direction := _screen_input_to_world_xz(screen_direction)
	return Vector2(world_direction.x, world_direction.z)


func _screen_input_to_world_xz(screen_direction: Vector2) -> Vector3:
	var camera_right := active_camera.global_transform.basis.x
	var camera_up := active_camera.global_transform.basis.y

	var world_right := Vector3(camera_right.x, 0.0, camera_right.z).normalized()
	var world_up := Vector3(camera_up.x, 0.0, camera_up.z).normalized()
	var world_direction := (world_right * screen_direction.x) + (world_up * -screen_direction.y)

	if world_direction.length_squared() > 1.0:
		world_direction = world_direction.normalized()

	return world_direction


func _read_mouse_aim_direction() -> Vector2:
	if _local_player == null:
		return Vector2.ZERO

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = active_camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = active_camera.project_ray_normal(mouse_position)
	if is_zero_approx(ray_direction.y):
		return Vector2.ZERO

	var distance_to_ground: float = -ray_origin.y / ray_direction.y
	if distance_to_ground < 0.0:
		return Vector2.ZERO

	var ground_position: Vector3 = ray_origin + ray_direction * distance_to_ground
	var aim_world_direction: Vector3 = ground_position - _local_player.global_position
	aim_world_direction.y = 0.0
	if aim_world_direction.length_squared() <= 0.0001:
		return Vector2.ZERO

	# Client computes mouse aim intent; the server stores and rebroadcasts facing.
	aim_world_direction = aim_world_direction.normalized()
	return Vector2(aim_world_direction.x, aim_world_direction.z)


func _should_send_aim(aim_direction: Vector2) -> bool:
	if not _has_sent_aim:
		return true
	if _aim_heartbeat_timer >= aim_heartbeat_interval:
		return true

	return aim_direction.distance_to(_last_sent_aim) >= aim_change_threshold


func _send_movement_input(input_direction: Vector2) -> void:
	world_spawner.rpc_id(1, "submit_movement_input", input_direction)
	_last_sent_input = input_direction
	_input_heartbeat_timer = 0.0
	_has_sent_input = true


func _send_aim_input(aim_direction: Vector2) -> void:
	world_spawner.rpc_id(1, "submit_aim_input", aim_direction)
	_last_sent_aim = aim_direction
	_aim_heartbeat_timer = 0.0
	_has_sent_aim = true


func _update_camera_follow(delta: float) -> void:
	if _local_player == null:
		return

	var target_position: Vector3 = _local_player.global_position + _camera_follow_offset
	var weight: float = clamp(camera_follow_speed * delta, 0.0, 1.0)
	var camera_transform: Transform3D = active_camera.global_transform
	camera_transform.origin = active_camera.global_position.lerp(target_position, weight)
	# Keep the isometric rotation fixed; camera follow only smooths position.
	camera_transform.basis = _fixed_camera_basis
	active_camera.global_transform = camera_transform


func _snap_camera_to_local_player() -> void:
	if _local_player == null:
		return

	var camera_transform: Transform3D = active_camera.global_transform
	# Camera follows the local visual player only; rotation stays locked for the isometric view.
	camera_transform.origin = _local_player.global_position + _camera_follow_offset
	camera_transform.basis = _fixed_camera_basis
	active_camera.global_transform = camera_transform


func _send_join_request() -> void:
	if selected_character.is_empty():
		print("Cannot join game server: no selected character in ClientSession.")
		return

	var character_id: int = int(selected_character.get("id", 0))
	var character_name: String = str(selected_character.get("name", "Unnamed"))
	if character_id <= 0:
		print("Cannot join game server: selected character is missing a valid id.")
		return

	world_spawner.send_join_request(character_id, character_name, ClientSession.access_token)
	_has_sent_join_request = true
	_send_movement_input(Vector2.ZERO)
	_send_aim_input(Vector2(0.0, -1.0))
	print("Sent join request for character %s (%s)." % [character_name, character_id])
