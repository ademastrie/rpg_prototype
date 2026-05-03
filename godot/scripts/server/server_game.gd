extends Node

@export var server_port: int = 7777
@export var backend_base_url: String = "http://127.0.0.1:8000"
@export var server_region_id: String = "starting_region"

@onready var world_spawner: Node3D = $WorldSpawner
@onready var enemy_spawner: Node = $EnemySpawner

var connected_peers: Array[int] = []
var peer_sessions: Dictionary = {}
var _pending_join_validations: Dictionary = {}


func _ready() -> void:
	print("Server game scene ready.")
	_start_server()


func _start_server() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	world_spawner.join_requested.connect(_on_join_requested)

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(server_port)
	if error != OK:
		print("Failed to start ENet server on port %s: %s" % [server_port, error])
		return

	multiplayer.multiplayer_peer = peer
	print("ENet server started on port %s." % server_port)
	enemy_spawner.call("spawn_initial_enemies")


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
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if bool(session.get("joined", false)):
		var position: Vector3 = world_spawner.get_authoritative_position(peer_id)
		_save_peer_position(peer_id, session, position)

	connected_peers.erase(peer_id)
	peer_sessions.erase(peer_id)
	_pending_join_validations.erase(peer_id)
	world_spawner.unregister_peer(peer_id)


func _on_join_requested(peer_id: int, character_id: int, _character_name: String, access_token: String) -> void:
	if not connected_peers.has(peer_id):
		print("Ignoring join request from unknown peer: %s" % peer_id)
		return

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if bool(session.get("joined", false)):
		print("Ignoring duplicate join request from peer: %s" % peer_id)
		return

	if _pending_join_validations.has(peer_id):
		print("Ignoring join request while validation is pending for peer: %s" % peer_id)
		return
	if access_token.strip_edges() == "":
		print("Rejecting join for peer %s: missing access token." % peer_id)
		_disconnect_peer(peer_id)
		return
	if character_id <= 0:
		print("Rejecting join for peer %s: invalid character id." % peer_id)
		_disconnect_peer(peer_id)
		return

	_validate_join_with_backend(peer_id, character_id, access_token)


func _validate_join_with_backend(peer_id: int, character_id: int, access_token: String) -> void:
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	_pending_join_validations[peer_id] = request

	request.request_completed.connect(_on_join_validation_completed.bind(peer_id, access_token, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var body: String = JSON.stringify({"character_id": character_id})
	var url: String = "%s/game/validate-join" % _normalized_backend_base_url()
	var error: Error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Failed to start backend join validation for peer %s: %s" % [peer_id, error])
		_pending_join_validations.erase(peer_id)
		request.queue_free()
		_disconnect_peer(peer_id)


func _on_join_validation_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	access_token: String,
	request: HTTPRequest
) -> void:
	_pending_join_validations.erase(peer_id)
	request.queue_free()

	if not connected_peers.has(peer_id):
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		print("Join validation failed for peer %s: HTTPRequest result %s." % [peer_id, result])
		_disconnect_peer(peer_id)
		return

	var response_text: String = body.get_string_from_utf8()
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK:
		print("Join validation failed for peer %s: invalid JSON response. status=%s response=%s" % [peer_id, response_code, response_text])
		_disconnect_peer(peer_id)
		return

	if not json.data is Dictionary:
		print("Join validation failed for peer %s: expected JSON object. status=%s response=%s" % [peer_id, response_code, response_text])
		_disconnect_peer(peer_id)
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Join validation rejected peer %s: status=%s response=%s" % [peer_id, response_code, response_data])
		_disconnect_peer(peer_id)
		return

	var character_id: int = int(response_data.get("character_id", 0))
	var character_name: String = str(response_data.get("character_name", ""))
	var region_id: String = str(response_data.get("region_id", ""))
	var position_x: float = float(response_data.get("position_x", 0.0))
	var position_y: float = float(response_data.get("position_y", 0.0))
	if character_id <= 0 or character_name.strip_edges() == "":
		print("Join validation failed for peer %s: missing character data." % peer_id)
		_disconnect_peer(peer_id)
		return
	if region_id != server_region_id:
		print("Rejecting join for peer %s: character region '%s' does not match server region '%s'." % [peer_id, region_id, server_region_id])
		_disconnect_peer(peer_id)
		return

	var session: Dictionary = {
		"peer_id": peer_id,
		"user_id": int(response_data.get("user_id", 0)),
		"character_id": character_id,
		"character_name": character_name,
		"access_token": access_token,
		"region_id": region_id,
		"position_x": position_x,
		"position_y": position_y,
		"joined": true,
	}
	peer_sessions[peer_id] = session
	print("Peer %s validated as character %s (%s)." % [peer_id, character_name, character_id])
	if _has_saved_position(position_x, position_y):
		world_spawner.register_peer_at_position(peer_id, character_name, Vector3(position_x, 0.0, position_y))
	else:
		world_spawner.register_peer(peer_id, character_name)
	enemy_spawner.call("sync_peer", peer_id)


func _save_peer_position(peer_id: int, session: Dictionary, position: Vector3) -> void:
	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Failed to save position for peer %s: missing validated session data." % peer_id)
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_save_position_completed.bind(peer_id, character_id, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var body: String = JSON.stringify({
		"character_id": character_id,
		"region_id": server_region_id,
		"position_x": position.x,
		"position_y": position.z,
	})
	var url: String = "%s/game/save-position" % _normalized_backend_base_url()
	var error: Error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Failed to start save-position request for peer %s: %s" % [peer_id, error])
		request.queue_free()


func _on_save_position_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	character_id: int,
	request: HTTPRequest
) -> void:
	request.queue_free()
	var response_text: String = body.get_string_from_utf8()
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		print("Saved position for peer %s character %s." % [peer_id, character_id])
		return

	print("Failed to save position for peer %s character %s: result=%s status=%s response=%s" % [peer_id, character_id, result, response_code, response_text])


func _has_saved_position(position_x: float, position_y: float) -> bool:
	return is_finite(position_x) and is_finite(position_y) and (not is_zero_approx(position_x) or not is_zero_approx(position_y))


func _normalized_backend_base_url() -> String:
	var normalized: String = backend_base_url.strip_edges()
	while normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


func _disconnect_peer(peer_id: int) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
