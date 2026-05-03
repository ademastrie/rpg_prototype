extends Node3D

@export var server_host: String = "127.0.0.1"
@export var server_port: int = 7777

@onready var status_label: Label = $StatusLabel
@onready var spawn_count_label: Label = $SpawnCountLabel
@onready var world_spawner: Node3D = $WorldSpawner

var selected_character: Dictionary = {}


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
	print("Connected to game server.")


func _on_connection_failed() -> void:
	print("Failed to connect to game server.")


func _on_server_disconnected() -> void:
	print("Disconnected from game server.")


func _on_spawned_player_count_changed(count: int) -> void:
	spawn_count_label.text = "Network Players: %s" % count
	print("Network player count: %s" % count)
