extends Node

@export var server_port: int = 7777
@export var backend_base_url: String = "http://127.0.0.1:8000"
@export var server_region_id: String = "starting_region"

@onready var world_spawner: Node3D = $WorldSpawner
@onready var enemy_spawner: Node = $EnemySpawner

var connected_peers: Array[int] = []
var peer_sessions: Dictionary = {}
var _pending_join_validations: Dictionary = {}

const BACKEND_ABILITY_NAME_BY_KEY: Dictionary = {
	"slash": "Slash",
	"hp_regen": "HP Regen",
	"damage_aura": "Damage Aura",
	"firebolt": "Firebolt",
}


func _ready() -> void:
	print("Server game scene ready.")
	_start_server()


func _start_server() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	world_spawner.join_requested.connect(_on_join_requested)
	world_spawner.ability_loadout_update_requested.connect(_on_ability_loadout_update_requested)

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
	print("Peer joined pending validation: %s." % peer_id)
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
	_fetch_character_abilities_with_backend(peer_id, access_token, session)


func _fetch_character_abilities_with_backend(peer_id: int, access_token: String, session: Dictionary) -> void:
	var character_id: int = int(session.get("character_id", 0))
	if character_id <= 0:
		print("Rejecting join for peer %s: missing character id before ability loadout fetch." % peer_id)
		_disconnect_peer(peer_id)
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	_pending_join_validations[peer_id] = request

	request.request_completed.connect(_on_character_abilities_completed.bind(peer_id, access_token, session, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var url: String = "%s/characters/%s/abilities" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("Rejecting join for peer %s: failed to start backend ability loadout fetch: %s" % [peer_id, error])
		_pending_join_validations.erase(peer_id)
		request.queue_free()
		_disconnect_peer(peer_id)


func _on_character_abilities_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	_access_token: String,
	session: Dictionary,
	request: HTTPRequest
) -> void:
	_pending_join_validations.erase(peer_id)
	request.queue_free()

	if not connected_peers.has(peer_id):
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		print("Rejecting join for peer %s: ability loadout fetch failed with HTTPRequest result %s." % [peer_id, result])
		_disconnect_peer(peer_id)
		return

	var response_text: String = body.get_string_from_utf8()
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK:
		print("Rejecting join for peer %s: invalid ability loadout JSON. status=%s response=%s" % [peer_id, response_code, response_text])
		_disconnect_peer(peer_id)
		return

	if not json.data is Dictionary:
		print("Rejecting join for peer %s: expected ability loadout JSON object. status=%s response=%s" % [peer_id, response_code, response_text])
		_disconnect_peer(peer_id)
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Rejecting join for peer %s: backend ability loadout request failed. status=%s response=%s" % [peer_id, response_code, response_data])
		_disconnect_peer(peer_id)
		return

	var loadout_data: Dictionary = _parse_backend_ability_loadout(peer_id, int(session.get("character_id", 0)), response_data)
	if loadout_data.is_empty():
		_disconnect_peer(peer_id)
		return

	_complete_validated_join(peer_id, session, loadout_data)


func _complete_validated_join(peer_id: int, session: Dictionary, loadout_data: Dictionary) -> void:
	var character_id: int = int(session.get("character_id", 0))
	var character_name: String = str(session.get("character_name", ""))
	var position_x: float = float(session.get("position_x", 0.0))
	var position_y: float = float(session.get("position_y", 0.0))
	var raw_loadout: Array = loadout_data.get("loadout", []) as Array
	var loadout: Array[String] = []
	var loadout_names: PackedStringArray = PackedStringArray()
	for ability_name in raw_loadout:
		var ability_name_text: String = str(ability_name)
		loadout.append(ability_name_text)
		loadout_names.append(ability_name_text)
	var ability_enabled: Dictionary = loadout_data.get("ability_enabled", {}) as Dictionary
	var ability_display_names: Dictionary = loadout_data.get("ability_display_names", {}) as Dictionary
	var ability_keys: Dictionary = loadout_data.get("ability_keys", {}) as Dictionary
	var ability_slot_indexes: Dictionary = loadout_data.get("ability_slot_indexes", {}) as Dictionary
	var unlocked_abilities: Array = loadout_data.get("unlocked_abilities", []) as Array

	peer_sessions[peer_id] = session
	print("Peer %s accepted as character %s (%s) with backend loadout: %s." % [peer_id, character_name, character_id, ", ".join(loadout_names)])
	if _has_saved_position(position_x, position_y):
		world_spawner.register_peer_at_position(peer_id, character_name, Vector3(position_x, 0.0, position_y), loadout, ability_enabled, ability_display_names, ability_keys, unlocked_abilities, ability_slot_indexes)
	else:
		world_spawner.register_peer(peer_id, character_name, loadout, ability_enabled, ability_display_names, ability_keys, unlocked_abilities, ability_slot_indexes)
	enemy_spawner.call("sync_peer", peer_id)


func _parse_backend_ability_loadout(peer_id: int, character_id: int, response_data: Dictionary) -> Dictionary:
	if int(response_data.get("character_id", 0)) != character_id:
		print("Rejecting join for peer %s: ability response character id mismatch." % peer_id)
		return {}

	var raw_loadout: Variant = response_data.get("loadout", [])
	if not raw_loadout is Array:
		print("Rejecting join for peer %s: ability response loadout is not an array." % peer_id)
		return {}

	var display_names_by_key: Dictionary = _backend_ability_display_names(response_data)
	var unlocked_abilities: Array = _backend_unlocked_abilities(response_data)
	var loadout_entries: Array = (raw_loadout as Array).duplicate()
	for entry_variant in loadout_entries:
		if not entry_variant is Dictionary:
			print("Rejecting join for peer %s: ability loadout entry is not an object." % peer_id)
			return {}

	loadout_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_entry: Dictionary = left as Dictionary
		var right_entry: Dictionary = right as Dictionary
		return int(left_entry.get("slot_index", 0)) < int(right_entry.get("slot_index", 0))
	)

	var loadout: Array[String] = []
	var ability_enabled: Dictionary = {}
	var ability_display_names: Dictionary = {}
	var ability_keys: Dictionary = {}
	var ability_slot_indexes: Dictionary = {}
	for entry_variant in loadout_entries:
		var entry: Dictionary = entry_variant as Dictionary
		var ability_key: String = str(entry.get("ability_key", "")).strip_edges()
		var ability_name: String = str(BACKEND_ABILITY_NAME_BY_KEY.get(ability_key, display_names_by_key.get(ability_key, "")))
		var display_name: String = str(display_names_by_key.get(ability_key, ability_key)).strip_edges()
		if ability_name == "" or not _is_supported_godot_ability(ability_name):
			print("Rejecting join for peer %s: unsupported backend ability '%s'." % [peer_id, ability_key])
			return {}
		if loadout.has(ability_name):
			print("Rejecting join for peer %s: duplicate backend ability '%s'." % [peer_id, ability_key])
			return {}

		loadout.append(ability_name)
		ability_enabled[ability_name] = bool(entry.get("enabled", true))
		ability_display_names[ability_name] = display_name if display_name != "" else ability_name
		ability_keys[ability_name] = ability_key
		ability_slot_indexes[ability_name] = int(entry.get("slot_index", loadout.size() - 1))

	if loadout.is_empty():
		print("Rejecting join for peer %s: backend ability loadout is empty." % peer_id)
		return {}

	return {
		"loadout": loadout,
		"ability_enabled": ability_enabled,
		"ability_display_names": ability_display_names,
		"ability_keys": ability_keys,
		"ability_slot_indexes": ability_slot_indexes,
		"unlocked_abilities": unlocked_abilities,
	}


func _backend_unlocked_abilities(response_data: Dictionary) -> Array:
	var unlocked_abilities: Array = []
	var raw_abilities: Variant = response_data.get("unlocked_abilities", [])
	if not raw_abilities is Array:
		return unlocked_abilities

	var abilities: Array = raw_abilities as Array
	for ability_variant in abilities:
		if not ability_variant is Dictionary:
			continue

		var ability: Dictionary = ability_variant as Dictionary
		var ability_key: String = str(ability.get("ability_key", "")).strip_edges()
		var definition: Variant = ability.get("definition", {})
		if ability_key == "" or not definition is Dictionary:
			continue

		var ability_name: String = str(BACKEND_ABILITY_NAME_BY_KEY.get(ability_key, ""))
		if ability_name == "" or not _is_supported_godot_ability(ability_name):
			continue

		var display_name: String = str((definition as Dictionary).get("display_name", "")).strip_edges()
		unlocked_abilities.append({
			"ability_key": ability_key,
			"ability_name": ability_name,
			"display_name": display_name if display_name != "" else ability_key,
		})

	return unlocked_abilities


func _backend_ability_display_names(response_data: Dictionary) -> Dictionary:
	var display_names_by_key: Dictionary = {}
	var raw_abilities: Variant = response_data.get("unlocked_abilities", [])
	if not raw_abilities is Array:
		return display_names_by_key

	var abilities: Array = raw_abilities as Array
	for ability_variant in abilities:
		if not ability_variant is Dictionary:
			continue

		var ability: Dictionary = ability_variant as Dictionary
		var ability_key: String = str(ability.get("ability_key", "")).strip_edges()
		var definition: Variant = ability.get("definition", {})
		if ability_key == "" or not definition is Dictionary:
			continue

		var display_name: String = str((definition as Dictionary).get("display_name", "")).strip_edges()
		if display_name != "":
			display_names_by_key[ability_key] = display_name

	return display_names_by_key


func _is_supported_godot_ability(ability_name: String) -> bool:
	return ability_name == "Slash" or ability_name == "HP Regen" or ability_name == "Damage Aura" or ability_name == "Firebolt"


func _on_ability_loadout_update_requested(peer_id: int, loadout_entries: Array) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Rejecting loadout update for peer %s: missing validated session data." % peer_id)
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_ability_loadout_update_completed.bind(peer_id, request))

	var backend_loadout: Array = []
	for entry_variant in loadout_entries:
		var entry: Dictionary = entry_variant as Dictionary
		backend_loadout.append({
			"slot_index": int(entry.get("slot_index", 0)),
			"ability_key": str(entry.get("ability_key", "")),
			"enabled": bool(entry.get("enabled", true)),
		})

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var body: String = JSON.stringify({"loadout": backend_loadout})
	var url: String = "%s/characters/%s/ability-loadout" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_PUT, body)
	if error != OK:
		print("Failed to start backend loadout update for peer %s: %s" % [peer_id, error])
		request.queue_free()


func _on_ability_loadout_update_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	request: HTTPRequest
) -> void:
	request.queue_free()
	if not connected_peers.has(peer_id):
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Backend loadout update failed for peer %s: HTTPRequest result %s." % [peer_id, result])
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK or not (json.data is Dictionary):
		print("Backend loadout update returned invalid JSON for peer %s. status=%s response=%s" % [peer_id, response_code, response_text])
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Backend loadout update rejected peer %s: status=%s response=%s" % [peer_id, response_code, response_data])
		return

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	var loadout_data: Dictionary = _parse_backend_ability_loadout(peer_id, int(session.get("character_id", 0)), response_data)
	if loadout_data.is_empty():
		return

	world_spawner.call(
		"apply_confirmed_ability_data",
		peer_id,
		loadout_data.get("loadout", []),
		loadout_data.get("ability_enabled", {}),
		loadout_data.get("ability_display_names", {}),
		loadout_data.get("ability_keys", {}),
		loadout_data.get("unlocked_abilities", []),
		loadout_data.get("ability_slot_indexes", {})
	)


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
