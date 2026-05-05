extends Node

@export var server_port: int = 7777
@export var backend_base_url: String = "http://127.0.0.1:8000"
@export var server_region_id: String = "starting_region"
@export var debug_server_startup_logs: bool = false
@export var debug_join_timing: bool = false

@onready var world_spawner: Node3D = $WorldSpawner
@onready var enemy_spawner: Node = $EnemySpawner

var connected_peers: Array[int] = []
var peer_sessions: Dictionary = {}
var _pending_join_validations: Dictionary = {}
var _session_kill_counts_by_peer: Dictionary = {}
var _join_timing_start_msec_by_peer: Dictionary = {}

const BACKEND_ABILITY_NAME_BY_KEY: Dictionary = {
	"slash": "Slash",
	"hp_regen": "HP Regen",
	"damage_aura": "Damage Aura",
	"firebolt": "Firebolt",
}
const KILL_UNLOCK_REWARDS: Array[Dictionary] = [
	{"kills": 1, "ability_key": "hp_regen"},
	{"kills": 3, "ability_key": "damage_aura"},
]


func _ready() -> void:
	if debug_server_startup_logs:
		print("Server game scene ready.")
	_start_server()


func _start_server() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	world_spawner.join_requested.connect(_on_join_requested)
	world_spawner.ability_loadout_update_requested.connect(_on_ability_loadout_update_requested)
	enemy_spawner.connect("enemy_killed", Callable(self, "_on_enemy_killed"))

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(server_port)
	if error != OK:
		print("Failed to start ENet server on port %s: %s" % [server_port, error])
		return

	multiplayer.multiplayer_peer = peer
	if debug_server_startup_logs:
		print("ENet server started on port %s." % server_port)
	enemy_spawner.call("spawn_initial_enemies")


func _on_peer_connected(peer_id: int) -> void:
	if debug_join_timing:
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
	_session_kill_counts_by_peer.erase(peer_id)
	_join_timing_start_msec_by_peer.erase(peer_id)
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

	_join_timing_start_msec_by_peer[peer_id] = Time.get_ticks_msec()
	_log_join_timing(peer_id, "join request received")
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
	_log_join_timing(peer_id, "backend validate-join request completed")

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
	_log_join_timing(peer_id, "backend ability/loadout fetch completed")

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

	session["unlocked_ability_keys"] = _unlocked_ability_keys(unlocked_abilities)
	session["unlock_attempted_ability_keys"] = []
	peer_sessions[peer_id] = session
	_log_join_timing(peer_id, "player session initialized")
	if debug_join_timing:
		print("Peer %s accepted as character %s (%s) with backend loadout: %s." % [peer_id, character_name, character_id, ", ".join(loadout_names)])
	if _has_saved_position(position_x, position_y):
		world_spawner.register_peer_at_position(peer_id, character_name, Vector3(position_x, 0.0, position_y), loadout, ability_enabled, ability_display_names, ability_keys, unlocked_abilities, ability_slot_indexes)
	else:
		world_spawner.register_peer(peer_id, character_name, loadout, ability_enabled, ability_display_names, ability_keys, unlocked_abilities, ability_slot_indexes)
	_log_join_timing(peer_id, "initial player sync sent")
	enemy_spawner.call("sync_peer", peer_id)
	_log_join_timing(peer_id, "initial enemy sync sent")
	_log_join_timing(peer_id, "total join accept time")
	_join_timing_start_msec_by_peer.erase(peer_id)


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
	session["unlocked_ability_keys"] = _unlocked_ability_keys(loadout_data.get("unlocked_abilities", []) as Array)
	peer_sessions[peer_id] = session


func _on_enemy_killed(attacker_peer_id: int, enemy_id: int) -> void:
	if not connected_peers.has(attacker_peer_id):
		return

	var session: Dictionary = peer_sessions.get(attacker_peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var kill_count: int = int(_session_kill_counts_by_peer.get(attacker_peer_id, 0)) + 1
	_session_kill_counts_by_peer[attacker_peer_id] = kill_count
	print("Peer %s earned kill credit for enemy %s. Session kills=%s." % [attacker_peer_id, enemy_id, kill_count])
	for reward_variant in KILL_UNLOCK_REWARDS:
		var reward: Dictionary = reward_variant as Dictionary
		var required_kills: int = int(reward.get("kills", 0))
		var ability_key: String = str(reward.get("ability_key", "")).strip_edges()
		if required_kills <= 0 or ability_key == "":
			continue
		if kill_count >= required_kills:
			_request_session_unlock(attacker_peer_id, ability_key)


func _request_session_unlock(peer_id: int, ability_key: String) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var attempted_keys: Array = session.get("unlock_attempted_ability_keys", []) as Array
	if attempted_keys.has(ability_key):
		return

	attempted_keys.append(ability_key)
	session["unlock_attempted_ability_keys"] = attempted_keys
	peer_sessions[peer_id] = session

	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Cannot unlock ability '%s' for peer %s: missing validated session data." % [ability_key, peer_id])
		return

	var was_already_unlocked: bool = (session.get("unlocked_ability_keys", []) as Array).has(ability_key)
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_ability_unlock_completed.bind(peer_id, ability_key, was_already_unlocked, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var url: String = "%s/characters/%s/abilities/%s/unlock" % [_normalized_backend_base_url(), character_id, ability_key]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_POST, "")
	if error != OK:
		print("Failed to start ability unlock for peer %s ability '%s': %s" % [peer_id, ability_key, error])
		request.queue_free()


func _on_ability_unlock_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	ability_key: String,
	was_already_unlocked: bool,
	request: HTTPRequest
) -> void:
	request.queue_free()
	if not connected_peers.has(peer_id):
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		print("Ability unlock failed for peer %s ability '%s': result=%s status=%s response=%s" % [peer_id, ability_key, result, response_code, response_text])
		return

	print("Ability unlock confirmed by backend for peer %s ability '%s'." % [peer_id, ability_key])
	_reload_character_abilities_after_unlock(peer_id, ability_key, was_already_unlocked)


func _reload_character_abilities_after_unlock(peer_id: int, ability_key: String, was_already_unlocked: bool) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Cannot reload abilities after unlock for peer %s: missing validated session data." % peer_id)
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_unlock_ability_reload_completed.bind(peer_id, ability_key, was_already_unlocked, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var url: String = "%s/characters/%s/abilities" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("Failed to start ability reload after unlock for peer %s ability '%s': %s" % [peer_id, ability_key, error])
		request.queue_free()


func _on_unlock_ability_reload_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	ability_key: String,
	was_already_unlocked: bool,
	request: HTTPRequest
) -> void:
	request.queue_free()
	if not connected_peers.has(peer_id):
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Ability reload after unlock failed for peer %s: HTTPRequest result %s." % [peer_id, result])
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK or not (json.data is Dictionary):
		print("Ability reload after unlock returned invalid JSON for peer %s. status=%s response=%s" % [peer_id, response_code, response_text])
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Ability reload after unlock rejected peer %s: status=%s response=%s" % [peer_id, response_code, response_data])
		return

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	var loadout_data: Dictionary = _parse_backend_ability_loadout(peer_id, int(session.get("character_id", 0)), response_data)
	if loadout_data.is_empty():
		return

	var unlocked_abilities: Array = loadout_data.get("unlocked_abilities", []) as Array
	world_spawner.call(
		"apply_confirmed_ability_data",
		peer_id,
		loadout_data.get("loadout", []),
		loadout_data.get("ability_enabled", {}),
		loadout_data.get("ability_display_names", {}),
		loadout_data.get("ability_keys", {}),
		unlocked_abilities,
		loadout_data.get("ability_slot_indexes", {})
	)
	session["unlocked_ability_keys"] = _unlocked_ability_keys(unlocked_abilities)
	peer_sessions[peer_id] = session

	if not was_already_unlocked and _has_unlocked_ability(unlocked_abilities, ability_key):
		var display_name: String = _display_name_for_unlocked_ability(unlocked_abilities, ability_key)
		world_spawner.rpc_id(peer_id, "apply_ability_unlock_message", peer_id, display_name)


func _unlocked_ability_keys(unlocked_abilities: Array) -> Array[String]:
	var ability_keys: Array[String] = []
	for ability_variant in unlocked_abilities:
		if not (ability_variant is Dictionary):
			continue

		var ability: Dictionary = ability_variant as Dictionary
		var ability_key: String = str(ability.get("ability_key", "")).strip_edges()
		if ability_key != "":
			ability_keys.append(ability_key)

	return ability_keys


func _has_unlocked_ability(unlocked_abilities: Array, ability_key: String) -> bool:
	return _display_name_for_unlocked_ability(unlocked_abilities, ability_key) != ""


func _display_name_for_unlocked_ability(unlocked_abilities: Array, ability_key: String) -> String:
	for ability_variant in unlocked_abilities:
		if not (ability_variant is Dictionary):
			continue

		var ability: Dictionary = ability_variant as Dictionary
		if str(ability.get("ability_key", "")).strip_edges() != ability_key:
			continue

		var display_name: String = str(ability.get("display_name", "")).strip_edges()
		if display_name != "":
			return display_name
		return str(BACKEND_ABILITY_NAME_BY_KEY.get(ability_key, ability_key))

	return ""


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
	_join_timing_start_msec_by_peer.erase(peer_id)
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _log_join_timing(peer_id: int, event_name: String) -> void:
	if not debug_join_timing:
		return
	if not _join_timing_start_msec_by_peer.has(peer_id):
		return

	var elapsed_msec: int = Time.get_ticks_msec() - int(_join_timing_start_msec_by_peer[peer_id])
	print("Join timing peer=%s event=\"%s\" elapsed_ms=%s" % [peer_id, event_name, elapsed_msec])
