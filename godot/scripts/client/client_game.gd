extends Node3D

@export var server_host: String = "127.0.0.1"
@export var server_port: int = 7777
@export var input_heartbeat_interval: float = 0.25

@onready var status_label: Label = $StatusLabel
@onready var spawn_count_label: Label = $SpawnCountLabel
@onready var world_spawner: Node3D = $WorldSpawner
@onready var active_camera: Camera3D = $Camera3D

var selected_character: Dictionary = {}
var _last_sent_input := Vector2.ZERO
var _input_heartbeat_timer := 0.0
var _has_sent_input := false
var _is_connected_to_server := false
var _has_sent_join_request := false


func _ready() -> void:
	world_spawner.spawned_player_count_changed.connect(_on_spawned_player_count_changed)
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
	var input_direction := _read_movement_input()
	if not _has_sent_input or input_direction != _last_sent_input or _input_heartbeat_timer >= input_heartbeat_interval:
		_send_movement_input(input_direction)


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
	print("Failed to connect to game server.")


func _on_server_disconnected() -> void:
	_is_connected_to_server = false
	_has_sent_join_request = false
	print("Disconnected from game server.")


func _on_spawned_player_count_changed(count: int) -> void:
	spawn_count_label.text = "Network Players: %s" % count
	print("Network player count: %s" % count)


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


func _send_movement_input(input_direction: Vector2) -> void:
	world_spawner.rpc_id(1, "submit_movement_input", input_direction)
	_last_sent_input = input_direction
	_input_heartbeat_timer = 0.0
	_has_sent_input = true


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
	print("Sent join request for character %s (%s)." % [character_name, character_id])
