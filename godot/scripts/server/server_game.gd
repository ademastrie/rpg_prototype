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
var _join_timing_start_msec_by_peer: Dictionary = {}

const BACKEND_ABILITY_NAME_BY_KEY: Dictionary = {
	"slash": "Slash",
	"hp_regen": "HP Regen",
	"damage_aura": "Damage Aura",
	"firebolt": "Firebolt",
}
const LEVEL_UNLOCK_REWARDS: Array[Dictionary] = [
	{"level": 2, "ability_key": "hp_regen"},
	{"level": 3, "ability_key": "damage_aura"},
]
const PROTOTYPE_ITEM_DISPLAY_NAMES: Dictionary = {
	"slime_gel": "Slime Gel",
}
const PROTOTYPE_EQUIP_SLOT_BY_ITEM_KEY: Dictionary = {
	"training_sword": "weapon",
	"apprentice_staff": "weapon",
	"simple_bow": "weapon",
	"padded_chest": "chest",
}
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "head", "chest", "arms", "hands", "legs", "feet"]


func _ready() -> void:
	if debug_server_startup_logs:
		print("Server game scene ready.")
	_start_server()


func _start_server() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	world_spawner.join_requested.connect(_on_join_requested)
	world_spawner.ability_loadout_update_requested.connect(_on_ability_loadout_update_requested)
	world_spawner.equipment_update_requested.connect(_on_equipment_update_requested)
	world_spawner.loot_reward_pickup_requested.connect(_on_loot_reward_pickup_requested)
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
	var level: int = int(response_data.get("level", 1))
	var xp: int = int(response_data.get("xp", 0))
	var gold: int = int(response_data.get("gold", 0))
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
		"level": level,
		"xp": xp,
		"xp_to_next": level * 100,
		"gold": gold,
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
	world_spawner.call("apply_confirmed_character_progression", peer_id, {
		"level": int(session.get("level", 1)),
		"xp": int(session.get("xp", 0)),
		"xp_to_next": int(session.get("xp_to_next", int(session.get("level", 1)) * 100)),
	})
	world_spawner.call("apply_confirmed_character_gold", peer_id, int(session.get("gold", 0)))
	world_spawner.call("apply_confirmed_character_inventory", peer_id, session.get("inventory_items", []) as Array)
	_log_join_timing(peer_id, "initial player sync sent")
	enemy_spawner.call("sync_peer", peer_id)
	_log_join_timing(peer_id, "initial enemy sync sent")
	_log_join_timing(peer_id, "total join accept time")
	_join_timing_start_msec_by_peer.erase(peer_id)
	_fetch_character_inventory_for_session(peer_id)
	_fetch_character_equipment_for_session(peer_id)


func _fetch_character_inventory_for_session(peer_id: int) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Cannot load inventory for peer %s: missing validated session data." % peer_id)
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_character_inventory_completed.bind(peer_id, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var url: String = "%s/characters/%s/inventory" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("Failed to start inventory load for peer %s: %s" % [peer_id, error])
		request.queue_free()


func _on_character_inventory_completed(
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

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Inventory load failed for peer %s: HTTPRequest result %s." % [peer_id, result])
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK or not (json.data is Dictionary):
		print("Inventory load returned invalid JSON for peer %s. status=%s response=%s" % [peer_id, response_code, response_text])
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Inventory load rejected peer %s: status=%s response=%s" % [peer_id, response_code, response_data])
		return

	var confirmed_inventory: Array = _extract_inventory_items(response_data)
	session["inventory_items"] = confirmed_inventory
	peer_sessions[peer_id] = session
	world_spawner.call("apply_confirmed_character_inventory", peer_id, confirmed_inventory)


func _fetch_character_equipment_for_session(peer_id: int) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Cannot load equipment for peer %s: missing validated session data." % peer_id)
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_character_equipment_completed.bind(peer_id, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var url: String = "%s/characters/%s/equipment" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("Failed to start equipment load for peer %s: %s" % [peer_id, error])
		request.queue_free()


func _on_character_equipment_completed(
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

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Equipment load failed for peer %s: HTTPRequest result %s." % [peer_id, result])
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK or not (json.data is Dictionary):
		print("Equipment load returned invalid JSON for peer %s. status=%s response=%s" % [peer_id, response_code, response_text])
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Equipment load rejected peer %s: status=%s response=%s" % [peer_id, response_code, response_data])
		return
	if int(response_data.get("character_id", int(session.get("character_id", 0)))) != int(session.get("character_id", 0)):
		print("Equipment load ignored for peer %s: character id mismatch." % peer_id)
		return

	var confirmed_equipment: Dictionary = _extract_character_equipment(response_data)
	session["equipment"] = confirmed_equipment
	peer_sessions[peer_id] = session
	world_spawner.call("apply_confirmed_character_equipment", peer_id, confirmed_equipment)


func _on_equipment_update_requested(peer_id: int, equipment_entries: Array) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Rejecting equipment update for peer %s: missing validated session data." % peer_id)
		_restore_confirmed_equipment_for_peer(peer_id, "Equipment update failed.")
		return

	var backend_entry: Dictionary = {}
	for entry_variant in equipment_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var slot_name: String = str(entry.get("slot", "")).strip_edges().to_lower()
		if not EQUIPMENT_SLOTS.has(slot_name):
			continue

		var item_key_variant: Variant = entry.get("item_key", null)
		var item_key: String = "" if item_key_variant == null else str(item_key_variant).strip_edges()
		backend_entry = {"equip_slot": slot_name}
		if item_key_variant == null or item_key == "":
			backend_entry["item_key"] = null
		else:
			backend_entry["item_key"] = item_key
		break

	if backend_entry.is_empty():
		_restore_confirmed_equipment_for_peer(peer_id, "Equipment update failed.")
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_equipment_update_completed.bind(peer_id, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var body: String = JSON.stringify(backend_entry)
	print("Equipment update request: character_id=%s equip_slot=%s item_key=%s body=%s" % [
		character_id,
		str(backend_entry.get("equip_slot", "")),
		str(backend_entry.get("item_key", null)),
		body,
	])
	var url: String = "%s/characters/%s/equipment" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_PUT, body)
	if error != OK:
		print("Failed to start backend equipment update for peer %s: %s" % [peer_id, error])
		request.queue_free()
		_restore_confirmed_equipment_for_peer(peer_id, "Equipment update failed.")


func _on_equipment_update_completed(
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

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Backend equipment update failed for peer %s: HTTPRequest result %s." % [peer_id, result])
		_restore_confirmed_equipment_for_peer(peer_id, "Equipment update failed.")
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK or not (json.data is Dictionary):
		print("Backend equipment update returned invalid JSON for peer %s. status=%s response=%s" % [peer_id, response_code, response_text])
		_restore_confirmed_equipment_for_peer(peer_id, "Equipment update failed.")
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Backend equipment update rejected peer %s: status=%s response=%s" % [peer_id, response_code, response_data])
		_restore_confirmed_equipment_for_peer(peer_id, "Equipment update failed.")
		return

	var confirmed_equipment: Dictionary = _extract_character_equipment(response_data)
	session["equipment"] = confirmed_equipment
	peer_sessions[peer_id] = session
	world_spawner.call("apply_confirmed_character_equipment", peer_id, confirmed_equipment)


func _restore_confirmed_equipment_for_peer(peer_id: int, message: String) -> void:
	if not connected_peers.has(peer_id):
		return

	if message.strip_edges() != "":
		world_spawner.rpc_id(peer_id, "apply_status_message", peer_id, message)

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	var confirmed_equipment: Dictionary = {}
	if session.get("equipment", null) is Dictionary:
		confirmed_equipment = (session.get("equipment", {}) as Dictionary).duplicate(true)
	else:
		confirmed_equipment = _empty_character_equipment()
	world_spawner.call("apply_confirmed_character_equipment", peer_id, confirmed_equipment)


func _extract_character_equipment(response_data: Dictionary) -> Dictionary:
	var equipment: Dictionary = _empty_character_equipment()
	for entry_variant in _equipment_entry_candidates(response_data):
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = _normalize_equipment_entry(entry_variant as Dictionary)
		var slot: String = str(entry.get("slot", "")).strip_edges()
		if not EQUIPMENT_SLOTS.has(slot):
			continue

		var item_key: String = str(entry.get("item_key", "")).strip_edges()
		var display_name: String = str(entry.get("display_name", "")).strip_edges()
		if item_key == "" and display_name == "":
			continue

		equipment[slot] = {
			"item_key": item_key,
			"display_name": display_name if display_name != "" else item_key,
		}

	return equipment


func _empty_character_equipment() -> Dictionary:
	var equipment: Dictionary = {}
	for slot_name in EQUIPMENT_SLOTS:
		equipment[slot_name] = {}
	return equipment


func _equipment_entry_candidates(response_data: Dictionary) -> Array:
	if response_data.get("equipment", null) is Array:
		return (response_data.get("equipment", []) as Array).duplicate()
	if response_data.get("slots", null) is Array:
		return (response_data.get("slots", []) as Array).duplicate()

	var equipment_data: Variant = response_data.get("equipment", response_data)
	if equipment_data is Dictionary:
		var equipment_dictionary: Dictionary = equipment_data as Dictionary
		if equipment_dictionary.get("slots", null) is Array:
			return (equipment_dictionary.get("slots", []) as Array).duplicate()

		var entries: Array = []
		for slot_name in EQUIPMENT_SLOTS:
			if not equipment_dictionary.has(slot_name):
				continue

			var slot_value: Variant = equipment_dictionary[slot_name]
			if slot_value is Dictionary:
				var slot_entry: Dictionary = (slot_value as Dictionary).duplicate()
				slot_entry["slot"] = slot_name
				entries.append(slot_entry)
		return entries

	return []


func _normalize_equipment_entry(entry_data: Dictionary) -> Dictionary:
	var slot: String = str(entry_data.get("equip_slot", entry_data.get("slot", entry_data.get("equipment_slot", entry_data.get("slot_key", ""))))).strip_edges()
	var item_key: String = str(entry_data.get("item_key", entry_data.get("key", ""))).strip_edges()
	var display_name: String = str(entry_data.get("display_name", "")).strip_edges()

	if entry_data.get("item", null) is Dictionary:
		var item_data: Dictionary = entry_data.get("item", {}) as Dictionary
		if item_key == "":
			item_key = str(item_data.get("item_key", item_data.get("key", ""))).strip_edges()
		if display_name == "":
			display_name = str(item_data.get("display_name", "")).strip_edges()
		if display_name == "" and item_data.get("definition", null) is Dictionary:
			display_name = str((item_data.get("definition", {}) as Dictionary).get("display_name", "")).strip_edges()

	if display_name == "" and entry_data.get("definition", null) is Dictionary:
		display_name = str((entry_data.get("definition", {}) as Dictionary).get("display_name", "")).strip_edges()

	return {
		"slot": slot,
		"item_key": item_key,
		"display_name": display_name,
	}


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

	print("Peer %s earned kill credit for enemy %s." % [attacker_peer_id, enemy_id])
	var enemy_position: Vector3 = enemy_spawner.call("get_authoritative_enemy_position", enemy_id) as Vector3
	world_spawner.call("spawn_prototype_loot_drop", enemy_position)
	_award_kill_xp(attacker_peer_id, enemy_id)


func _on_loot_reward_pickup_requested(peer_id: int, loot_orb_id: int, reward_payload: Dictionary) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	# Pickup reward payloads are server-owned and intentionally generic. Future
	# rewards should come from backend loot tables, item definitions, inventory,
	# equipment rules, and player/party ownership metadata.
	var reward_type: String = str(reward_payload.get("type", "")).strip_edges()
	if reward_type == "currency":
		_award_loot_currency(peer_id, loot_orb_id, reward_payload)
		return
	if reward_type == "item":
		_award_loot_item(peer_id, loot_orb_id, reward_payload)
		return

	print("Rejecting unsupported loot reward for peer %s orb %s: %s" % [peer_id, loot_orb_id, reward_payload])
	world_spawner.call("reject_loot_pickup", loot_orb_id)


func _award_loot_currency(peer_id: int, loot_orb_id: int, reward_payload: Dictionary) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	var gold_amount: int = int(reward_payload.get("gold_amount", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Cannot award loot currency for peer %s orb %s: missing validated session data." % [peer_id, loot_orb_id])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return
	if gold_amount < 0:
		print("Cannot award loot currency for peer %s orb %s: negative gold amount." % [peer_id, loot_orb_id])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_loot_currency_award_completed.bind(peer_id, loot_orb_id, gold_amount, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var body: String = JSON.stringify({"gold_amount": gold_amount})
	var url: String = "%s/characters/%s/currency" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Failed to start loot currency award for peer %s orb %s: %s" % [peer_id, loot_orb_id, error])
		request.queue_free()
		world_spawner.call("reject_loot_pickup", loot_orb_id)


func _on_loot_currency_award_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	loot_orb_id: int,
	gold_amount: int,
	request: HTTPRequest
) -> void:
	request.queue_free()
	if not connected_peers.has(peer_id):
		world_spawner.call("confirm_loot_pickup", loot_orb_id)
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Loot currency award failed for peer %s orb %s: HTTPRequest result %s." % [peer_id, loot_orb_id, result])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK or not (json.data is Dictionary):
		print("Loot currency award returned invalid JSON for peer %s orb %s. status=%s response=%s" % [peer_id, loot_orb_id, response_code, response_text])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Loot currency award rejected peer %s orb %s: status=%s response=%s" % [peer_id, loot_orb_id, response_code, response_data])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var confirmed_gold: int = int(response_data.get("gold", 0))
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	session["gold"] = confirmed_gold
	peer_sessions[peer_id] = session
	world_spawner.call("apply_confirmed_character_gold", peer_id, confirmed_gold)
	world_spawner.call("confirm_loot_pickup", loot_orb_id)
	world_spawner.rpc_id(peer_id, "apply_status_message", peer_id, "Picked up %s gold" % gold_amount)


func _award_loot_item(peer_id: int, loot_orb_id: int, reward_payload: Dictionary) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	var item_key: String = str(reward_payload.get("item_key", "")).strip_edges()
	var quantity: int = int(reward_payload.get("quantity", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Cannot award loot item for peer %s orb %s: missing validated session data." % [peer_id, loot_orb_id])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return
	if item_key == "" or quantity <= 0:
		print("Cannot award loot item for peer %s orb %s: invalid item payload %s." % [peer_id, loot_orb_id, reward_payload])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_loot_item_award_completed.bind(peer_id, loot_orb_id, item_key, quantity, str(reward_payload.get("display_name", "")), request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	var body: String = JSON.stringify({
		"item_key": item_key,
		"quantity": quantity,
	})
	var url: String = "%s/characters/%s/inventory/items" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Failed to start loot item award for peer %s orb %s: %s" % [peer_id, loot_orb_id, error])
		request.queue_free()
		world_spawner.call("reject_loot_pickup", loot_orb_id)


func _on_loot_item_award_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	loot_orb_id: int,
	item_key: String,
	quantity: int,
	payload_display_name: String,
	request: HTTPRequest
) -> void:
	request.queue_free()
	if not connected_peers.has(peer_id):
		world_spawner.call("confirm_loot_pickup", loot_orb_id)
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Loot item award failed for peer %s orb %s: HTTPRequest result %s." % [peer_id, loot_orb_id, result])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK or not (json.data is Dictionary):
		print("Loot item award returned invalid JSON for peer %s orb %s. status=%s response=%s" % [peer_id, loot_orb_id, response_code, response_text])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("Loot item award rejected peer %s orb %s: status=%s response=%s" % [peer_id, loot_orb_id, response_code, response_data])
		world_spawner.call("reject_loot_pickup", loot_orb_id)
		return

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	var existing_inventory: Array = session.get("inventory_items", []) as Array
	var confirmed_inventory: Array = _confirmed_inventory_from_item_response(response_data, existing_inventory, item_key, quantity, payload_display_name)
	session["inventory_items"] = confirmed_inventory
	peer_sessions[peer_id] = session
	world_spawner.call("apply_confirmed_character_inventory", peer_id, confirmed_inventory)
	world_spawner.call("confirm_loot_pickup", loot_orb_id)
	var display_name: String = _display_name_for_item_payload(item_key, payload_display_name)
	world_spawner.rpc_id(peer_id, "apply_status_message", peer_id, "Picked up %s x%s" % [display_name, quantity])


func _confirmed_inventory_from_item_response(response_data: Dictionary, existing_inventory: Array, item_key: String, quantity: int, payload_display_name: String) -> Array:
	var response_items: Array = _extract_inventory_items(response_data)
	if not response_items.is_empty():
		return response_items

	var confirmed_item: Dictionary = _normalize_inventory_item(response_data)
	if confirmed_item.is_empty():
		confirmed_item = {
			"item_key": item_key,
			"display_name": _display_name_for_item_payload(item_key, payload_display_name),
			"quantity": quantity,
		}
	return _merge_confirmed_inventory_item(existing_inventory, confirmed_item, item_key, quantity, payload_display_name)


func _extract_inventory_items(response_data: Dictionary) -> Array:
	var candidates: Array = []
	if response_data.get("items", null) is Array:
		candidates = response_data.get("items", []) as Array
	elif response_data.get("inventory_items", null) is Array:
		candidates = response_data.get("inventory_items", []) as Array
	elif response_data.get("inventory", null) is Array:
		candidates = response_data.get("inventory", []) as Array
	elif response_data.get("inventory", null) is Dictionary:
		var inventory: Dictionary = response_data.get("inventory", {}) as Dictionary
		if inventory.get("items", null) is Array:
			candidates = inventory.get("items", []) as Array

	var items: Array = []
	for item_variant in candidates:
		if not (item_variant is Dictionary):
			continue

		var item: Dictionary = _normalize_inventory_item(item_variant as Dictionary)
		if not item.is_empty():
			items.append(item)
	return items


func _merge_confirmed_inventory_item(existing_inventory: Array, confirmed_item: Dictionary, fallback_item_key: String, fallback_quantity: int, fallback_display_name: String) -> Array:
	var merged_by_key: Dictionary = {}
	for item_variant in existing_inventory:
		if not (item_variant is Dictionary):
			continue

		var existing_item: Dictionary = _normalize_inventory_item(item_variant as Dictionary)
		var existing_key: String = str(existing_item.get("item_key", "")).strip_edges()
		if existing_key != "":
			merged_by_key[existing_key] = existing_item

	var item_key: String = str(confirmed_item.get("item_key", fallback_item_key)).strip_edges()
	if item_key == "":
		return merged_by_key.values()

	var quantity: int = int(confirmed_item.get("quantity", fallback_quantity))
	var display_name: String = str(confirmed_item.get("display_name", _display_name_for_item_payload(item_key, fallback_display_name))).strip_edges()
	var equip_slot: String = str(confirmed_item.get("equip_slot", "")).strip_edges().to_lower()
	var item_type: String = str(confirmed_item.get("item_type", "")).strip_edges().to_lower()
	if equip_slot == "":
		equip_slot = _fallback_equip_slot_for_item_key(item_key)
	merged_by_key[item_key] = {
		"item_key": item_key,
		"display_name": display_name if display_name != "" else _display_name_for_item_payload(item_key, fallback_display_name),
		"quantity": max(quantity, 0),
		"equip_slot": equip_slot,
		"item_type": item_type,
	}
	return merged_by_key.values()


func _normalize_inventory_item(item_data: Dictionary) -> Dictionary:
	var item_key: String = str(item_data.get("item_key", item_data.get("key", ""))).strip_edges()
	if item_key == "" and item_data.get("item", null) is Dictionary:
		var nested_item: Dictionary = item_data.get("item", {}) as Dictionary
		item_key = str(nested_item.get("item_key", nested_item.get("key", ""))).strip_edges()
	if item_key == "":
		return {}

	var display_name: String = str(item_data.get("display_name", "")).strip_edges()
	if display_name == "" and item_data.get("definition", null) is Dictionary:
		display_name = str((item_data.get("definition", {}) as Dictionary).get("display_name", "")).strip_edges()
	if display_name == "" and item_data.get("item", null) is Dictionary:
		var nested_item: Dictionary = item_data.get("item", {}) as Dictionary
		display_name = str(nested_item.get("display_name", "")).strip_edges()
	var quantity: int = max(int(item_data.get("quantity", item_data.get("count", 0))), 0)
	var equip_slot: String = ""
	var item_type: String = ""
	if item_data.get("equip_slot", null) != null:
		equip_slot = str(item_data.get("equip_slot", "")).strip_edges().to_lower()
	elif item_data.get("equipment_slot", null) != null:
		equip_slot = str(item_data.get("equipment_slot", "")).strip_edges().to_lower()
	elif item_data.get("slot", null) != null:
		equip_slot = str(item_data.get("slot", "")).strip_edges().to_lower()
	if item_data.get("item_type", null) != null:
		item_type = str(item_data.get("item_type", "")).strip_edges().to_lower()

	var definition: Dictionary = _inventory_item_definition(item_data)
	if equip_slot == "":
		equip_slot = str(definition.get("equip_slot", definition.get("equipment_slot", definition.get("slot", "")))).strip_edges().to_lower()
	if item_type == "":
		item_type = str(definition.get("item_type", "")).strip_edges().to_lower()
	if display_name == "":
		display_name = str(definition.get("display_name", "")).strip_edges()
	if quantity <= 0:
		var nested_item_data: Dictionary = item_data.get("item", {}) as Dictionary
		quantity = max(int(nested_item_data.get("quantity", nested_item_data.get("count", 0))), 0)
	if equip_slot == "":
		equip_slot = _fallback_equip_slot_for_item_key(item_key)

	return {
		"item_key": item_key,
		"display_name": display_name if display_name != "" else _display_name_for_item_payload(item_key, ""),
		"quantity": quantity,
		"equip_slot": equip_slot,
		"item_type": item_type,
	}


func _inventory_item_definition(item_data: Dictionary) -> Dictionary:
	if item_data.get("definition", null) is Dictionary:
		return item_data.get("definition", {}) as Dictionary

	if item_data.get("item", null) is Dictionary:
		var nested_item: Dictionary = item_data.get("item", {}) as Dictionary
		if nested_item.get("definition", null) is Dictionary:
			return nested_item.get("definition", {}) as Dictionary

	return {}


func _fallback_equip_slot_for_item_key(item_key: String) -> String:
	return str(PROTOTYPE_EQUIP_SLOT_BY_ITEM_KEY.get(item_key, "")).strip_edges().to_lower()


func _display_name_for_item_payload(item_key: String, fallback_display_name: String) -> String:
	var display_name: String = fallback_display_name.strip_edges()
	if display_name != "":
		return display_name
	if PROTOTYPE_ITEM_DISPLAY_NAMES.has(item_key):
		return str(PROTOTYPE_ITEM_DISPLAY_NAMES[item_key])
	return item_key.replace("_", " ").capitalize()


func _award_kill_xp(peer_id: int, enemy_id: int) -> void:
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	if not bool(session.get("joined", false)):
		return

	var access_token: String = str(session.get("access_token", ""))
	var character_id: int = int(session.get("character_id", 0))
	if access_token.strip_edges() == "" or character_id <= 0:
		print("Cannot award XP for peer %s enemy %s: missing validated session data." % [peer_id, enemy_id])
		return

	var xp_reward: int = int(enemy_spawner.call("get_enemy_xp_reward", enemy_id))
	if xp_reward <= 0:
		print("Cannot award XP for peer %s enemy %s: missing prototype enemy XP reward." % [peer_id, enemy_id])
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_award_xp_completed.bind(peer_id, enemy_id, request))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	# Prototype only: future XP scaling should consider player level versus enemy
	# level and backend/database-backed enemy definitions.
	var body: String = JSON.stringify({"xp_amount": xp_reward})
	var url: String = "%s/characters/%s/xp" % [_normalized_backend_base_url(), character_id]
	var error: Error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Failed to start XP award for peer %s enemy %s: %s" % [peer_id, enemy_id, error])
		request.queue_free()


func _on_award_xp_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	peer_id: int,
	enemy_id: int,
	request: HTTPRequest
) -> void:
	request.queue_free()
	if not connected_peers.has(peer_id):
		return

	var response_text: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		print("XP award failed for peer %s enemy %s: HTTPRequest result %s." % [peer_id, enemy_id, result])
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(response_text)
	if parse_error != OK or not (json.data is Dictionary):
		print("XP award returned invalid JSON for peer %s enemy %s. status=%s response=%s" % [peer_id, enemy_id, response_code, response_text])
		return

	var response_data: Dictionary = json.data as Dictionary
	if response_code < 200 or response_code >= 300:
		print("XP award rejected peer %s enemy %s: status=%s response=%s" % [peer_id, enemy_id, response_code, response_data])
		return

	var progression: Dictionary = {
		"level": int(response_data.get("level", 1)),
		"xp": int(response_data.get("xp", 0)),
		"xp_to_next": int(response_data.get("xp_to_next", int(response_data.get("level", 1)) * 100)),
	}
	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	session["level"] = int(progression.get("level", 1))
	session["xp"] = int(progression.get("xp", 0))
	session["xp_to_next"] = int(progression.get("xp_to_next", int(session["level"]) * 100))
	peer_sessions[peer_id] = session
	world_spawner.call("apply_confirmed_character_progression", peer_id, progression)
	_request_level_unlocks(peer_id, int(session["level"]))


func _request_level_unlocks(peer_id: int, confirmed_level: int) -> void:
	if confirmed_level <= 0:
		return

	var session: Dictionary = peer_sessions.get(peer_id, {}) as Dictionary
	var unlocked_keys: Array = session.get("unlocked_ability_keys", []) as Array
	# Prototype-only rules. Future unlock rules may come from backend quest,
	# achievement, or level progression data instead of hardcoded Godot data.
	for reward_variant in LEVEL_UNLOCK_REWARDS:
		var reward: Dictionary = reward_variant as Dictionary
		var required_level: int = int(reward.get("level", 0))
		var ability_key: String = str(reward.get("ability_key", "")).strip_edges()
		if required_level <= 0 or required_level > confirmed_level or ability_key == "":
			continue
		if unlocked_keys.has(ability_key):
			continue
		_request_session_unlock(peer_id, ability_key)


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
