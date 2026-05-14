extends Node3D

@export var server_host: String = "127.0.0.1"
@export var server_port: int = 7777
@export var input_heartbeat_interval: float = 0.25
@export var aim_heartbeat_interval: float = 0.35
@export var aim_change_threshold: float = 0.03
@export var camera_follow_speed: float = 8.0
@export var debug_client_startup_logs: bool = false
@export var debug_client_startup_timing: bool = false

@onready var game_hud: Node = $GameHUD
@onready var world_spawner: Node3D = $WorldSpawner
@onready var enemy_spawner: Node = $EnemySpawner
@onready var active_camera: Camera3D = $Camera3D

var selected_character: Dictionary = {}
var _local_player: Node3D = null
var _camera_follow_offset: Vector3 = Vector3.ZERO
var _fixed_camera_basis: Basis = Basis.IDENTITY
var _character_status_text: String = ""
var _last_sent_input := Vector2.ZERO
var _last_sent_aim := Vector2.ZERO
var _input_heartbeat_timer := 0.0
var _aim_heartbeat_timer := 0.0
var _has_sent_input := false
var _has_sent_aim := false
var _is_connected_to_server := false
var _has_sent_join_request := false
var _was_combat_toggle_pressed := false
var _was_character_panel_toggle_pressed := false
var _was_ability_panel_toggle_pressed := false
var _was_inventory_panel_toggle_pressed := false
var _is_local_player_down := false
var _window_has_focus: bool = true
var _confirmed_ability_names: Array[String] = []
var _client_startup_timing_start_msec: int = 0
var _has_logged_camera_target_set: bool = false
var _has_logged_hud_loadout_update: bool = false
var _has_logged_hud_unlocked_update: bool = false


func _ready() -> void:
	_client_startup_timing_start_msec = Time.get_ticks_msec()
	world_spawner.spawned_player_count_changed.connect(_on_spawned_player_count_changed)
	world_spawner.player_spawned.connect(_on_player_spawned)
	world_spawner.player_health_updated.connect(_on_player_health_updated)
	world_spawner.player_down_state_updated.connect(_on_player_down_state_updated)
	world_spawner.player_combat_stats_updated.connect(_on_player_combat_stats_updated)
	world_spawner.character_progression_updated.connect(_on_character_progression_updated)
	world_spawner.character_gold_updated.connect(_on_character_gold_updated)
	world_spawner.character_inventory_updated.connect(_on_character_inventory_updated)
	world_spawner.character_equipment_updated.connect(_on_character_equipment_updated)
	world_spawner.combat_mode_updated.connect(_on_combat_mode_updated)
	world_spawner.ability_enabled_updated.connect(_on_ability_enabled_updated)
	world_spawner.ability_state_updated.connect(_on_ability_state_updated)
	world_spawner.ability_catalog_updated.connect(_on_ability_catalog_updated)
	world_spawner.weapon_primary_ability_updated.connect(_on_weapon_primary_ability_updated)
	world_spawner.ability_unlock_message_received.connect(_on_ability_unlock_message_received)
	world_spawner.status_message_received.connect(_on_status_message_received)
	enemy_spawner.connect("initial_enemy_batch_received", Callable(self, "_on_initial_enemy_batch_received"))
	game_hud.connect("combat_toggle_requested", Callable(self, "_send_combat_toggle_request"))
	game_hud.connect("ability_toggle_requested", Callable(self, "_send_ability_toggle_request"))
	game_hud.connect("weapon_primary_requested", Callable(self, "_send_weapon_primary_request"))
	game_hud.connect("loadout_save_requested", Callable(self, "_send_loadout_save_request"))
	game_hud.connect("equipment_change_requested", Callable(self, "_send_equipment_change_request"))
	_camera_follow_offset = active_camera.global_position
	_fixed_camera_basis = active_camera.global_transform.basis
	_on_spawned_player_count_changed(0)
	_on_player_health_updated(multiplayer.get_unique_id(), 100, 100)
	_on_combat_mode_updated(multiplayer.get_unique_id(), false, [])
	set_selected_character(ClientSession.selected_character)
	_connect_to_server()


func set_selected_character(character_data: Dictionary) -> void:
	selected_character = character_data
	if selected_character.is_empty():
		game_hud.call("show_status_message", "No character selected.")
		print("Client game loaded without selected character data.")
		return

	var character_name := str(selected_character.get("name", "Unnamed"))
	var level := int(selected_character.get("level", 1))
	var xp := int(selected_character.get("xp", 0))
	var xp_to_next := int(selected_character.get("xp_to_next", selected_character.get("xp_to_next_level", 0)))
	var gold := int(selected_character.get("gold", 0))
	var region_id := str(selected_character.get("region_id", "unknown_region"))
	_character_status_text = "Character: %s | Level %s | Region: %s" % [character_name, level, region_id]
	game_hud.call("update_progression", level, xp, xp_to_next)
	game_hud.call("update_gold", gold)
	if debug_client_startup_logs:
		print("Client game loaded character: %s" % selected_character)


func _process(delta: float) -> void:
	if not _is_connected_to_server or not _has_sent_join_request:
		return

	_input_heartbeat_timer += delta
	_aim_heartbeat_timer += delta
	var input_direction := _read_movement_input()
	if _is_local_player_down:
		input_direction = Vector2.ZERO

	world_spawner.set_local_prediction_input(input_direction)
	if not _has_sent_input or input_direction != _last_sent_input or _input_heartbeat_timer >= input_heartbeat_interval:
		_send_movement_input(input_direction)

	if _window_has_focus:
		var aim_direction: Vector2 = _read_mouse_aim_direction()
		if aim_direction != Vector2.ZERO and _should_send_aim(aim_direction):
			_send_aim_input(aim_direction)

	_read_combat_toggle_input()
	_read_character_panel_toggle_input()
	_read_ability_panel_toggle_input()
	_read_inventory_panel_toggle_input()
	_update_camera_follow(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_has_focus = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Keep the last known aim direction; do not sample mouse or send aim while unfocused.
		_window_has_focus = false


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
	if debug_client_startup_logs:
		print("Connecting to game server at %s:%s" % [server_host, server_port])


func _on_connected_to_server() -> void:
	_is_connected_to_server = true
	if debug_client_startup_logs:
		print("Connected to game server.")
	_send_join_request()


func _on_connection_failed() -> void:
	_is_connected_to_server = false
	_is_local_player_down = false
	world_spawner.set_local_prediction_input(Vector2.ZERO)
	_was_combat_toggle_pressed = false
	_was_character_panel_toggle_pressed = false
	_was_ability_panel_toggle_pressed = false
	_was_inventory_panel_toggle_pressed = false
	game_hud.call("show_status_message", "Failed to connect to game server.")
	print("Failed to connect to game server.")


func _on_server_disconnected() -> void:
	_is_connected_to_server = false
	_has_sent_join_request = false
	_is_local_player_down = false
	world_spawner.set_local_prediction_input(Vector2.ZERO)
	_was_combat_toggle_pressed = false
	_was_character_panel_toggle_pressed = false
	_was_ability_panel_toggle_pressed = false
	_was_inventory_panel_toggle_pressed = false
	game_hud.call("show_status_message", "Disconnected from game server.")
	print("Disconnected from game server.")


func _on_spawned_player_count_changed(count: int) -> void:
	if debug_client_startup_logs:
		print("Network player count: %s" % count)


func _on_player_spawned(peer_id: int, player: Node3D) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	_local_player = player
	_snap_camera_to_local_player()
	_log_client_startup_timing("local player spawn received")
	if debug_client_startup_logs:
		print("Camera following local player peer %s." % peer_id)


func _on_player_health_updated(peer_id: int, current_hp: int, max_hp: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("update_health", current_hp, max_hp)
	if current_hp <= 0:
		print("Local player is down.")


func _on_player_combat_stats_updated(peer_id: int, combat_stats: Dictionary) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("update_combat_stats", combat_stats)


func _on_character_progression_updated(peer_id: int, progression: Dictionary) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	var level: int = int(progression.get("level", 1))
	var xp: int = int(progression.get("xp", 0))
	var xp_to_next: int = int(progression.get("xp_to_next", 0))
	var xp_awarded: int = int(progression.get("xp_awarded", 0))
	var leveled_up: bool = bool(progression.get("leveled_up", false))
	var levels_gained: int = int(progression.get("levels_gained", 0))
	game_hud.call("update_progression", level, xp, xp_to_next, xp_awarded, leveled_up, levels_gained)
	selected_character["level"] = level
	selected_character["xp"] = xp
	selected_character["xp_to_next"] = xp_to_next
	ClientSession.selected_character["level"] = level
	ClientSession.selected_character["xp"] = xp
	ClientSession.selected_character["xp_to_next"] = xp_to_next
	if leveled_up:
		game_hud.call("show_status_message", "Level Up! %s" % level)
	elif xp_awarded > 0:
		game_hud.call("show_status_message", "+%s XP" % xp_awarded)
	_character_status_text = "Character: %s | Level %s | Region: %s" % [
		str(selected_character.get("name", "Unnamed")),
		level,
		str(selected_character.get("region_id", "unknown_region")),
	]


func _on_character_gold_updated(peer_id: int, gold: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	var confirmed_gold: int = max(gold, 0)
	game_hud.call("update_gold", confirmed_gold)
	selected_character["gold"] = confirmed_gold
	ClientSession.selected_character["gold"] = confirmed_gold


func _on_character_inventory_updated(peer_id: int, inventory_items: Array) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("update_inventory_items", inventory_items)


func _on_character_equipment_updated(peer_id: int, equipment: Dictionary) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("update_equipment", equipment)


func _on_player_down_state_updated(peer_id: int, is_down: bool) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	if is_down:
		_is_local_player_down = true
		world_spawner.set_local_prediction_input(Vector2.ZERO)
	else:
		_is_local_player_down = false
	game_hud.call("update_down_state", is_down)


func _on_combat_mode_updated(peer_id: int, combat_enabled: bool, loadout_entries: Array) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	_confirmed_ability_names.clear()
	for entry_variant in loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var ability_name: String = str(entry.get("ability_name", "")).strip_edges()
		if ability_name != "":
			_confirmed_ability_names.append(ability_name)

	game_hud.call("update_combat_mode", combat_enabled)
	game_hud.call("update_loadout", loadout_entries)
	if _has_sent_join_request and not _has_logged_hud_loadout_update:
		_has_logged_hud_loadout_update = true
		_log_client_startup_timing("HUD loadout update", {"ability_count": _confirmed_ability_names.size()})


func _on_ability_enabled_updated(peer_id: int, ability_name: String, enabled: bool) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("update_ability_enabled", ability_name, enabled)


func _on_ability_state_updated(peer_id: int, ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("update_ability_state", ability_name, enabled, active, cooldown_remaining)


func _on_ability_catalog_updated(peer_id: int, unlocked_abilities: Array) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("update_unlocked_abilities", unlocked_abilities)
	if _has_sent_join_request and not _has_logged_hud_unlocked_update:
		_has_logged_hud_unlocked_update = true
		_log_client_startup_timing("HUD unlocked ability update", {"ability_count": unlocked_abilities.size()})


func _on_weapon_primary_ability_updated(peer_id: int, weapon_primary_ability: Dictionary) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("update_weapon_primary_ability", weapon_primary_ability)


func _on_initial_enemy_batch_received(enemy_count: int) -> void:
	_log_client_startup_timing("initial enemy batch received", {"enemy_count": enemy_count})


func _on_ability_unlock_message_received(peer_id: int, display_name: String) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("show_status_message", "Unlocked ability: %s" % display_name)
	print("Unlocked ability: %s" % display_name)


func _on_status_message_received(peer_id: int, message: String) -> void:
	if peer_id != multiplayer.get_unique_id():
		return

	game_hud.call("show_status_message", message)
	print(message)


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


func _read_combat_toggle_input() -> void:
	var is_toggle_pressed: bool = Input.is_key_pressed(KEY_Q)
	if is_toggle_pressed and not _was_combat_toggle_pressed:
		_send_combat_toggle_request()

	_was_combat_toggle_pressed = is_toggle_pressed


func _read_character_panel_toggle_input() -> void:
	var is_toggle_pressed: bool = Input.is_key_pressed(KEY_C)
	if is_toggle_pressed and not _was_character_panel_toggle_pressed:
		game_hud.call("toggle_character_panel")

	_was_character_panel_toggle_pressed = is_toggle_pressed


func _read_ability_panel_toggle_input() -> void:
	var is_toggle_pressed: bool = Input.is_key_pressed(KEY_B)
	if is_toggle_pressed and not _was_ability_panel_toggle_pressed:
		game_hud.call("toggle_ability_panel")

	_was_ability_panel_toggle_pressed = is_toggle_pressed


func _read_inventory_panel_toggle_input() -> void:
	var is_toggle_pressed: bool = Input.is_key_pressed(KEY_I)
	if is_toggle_pressed and not _was_inventory_panel_toggle_pressed:
		game_hud.call("toggle_inventory_panel")

	_was_inventory_panel_toggle_pressed = is_toggle_pressed


func _send_combat_toggle_request() -> void:
	# Client only requests a toggle; the server owns the actual combat mode state.
	world_spawner.rpc_id(1, "request_toggle_combat_mode")


func _send_ability_toggle_request(ability_name: String, enabled: bool) -> void:
	if not _confirmed_ability_names.has(ability_name):
		return

	# Client requests ability state; the server confirms the final enabled value.
	world_spawner.rpc_id(1, "request_set_ability_enabled", ability_name, enabled)


func _send_weapon_primary_request() -> void:
	world_spawner.rpc_id(1, "submit_basic_attack")


func _send_loadout_save_request(loadout_entries: Array) -> void:
	world_spawner.rpc_id(1, "request_update_ability_loadout", loadout_entries)


func _send_equipment_change_request(equipment_entries: Array) -> void:
	world_spawner.rpc_id(1, "request_update_equipment", equipment_entries)


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
	if not _has_logged_camera_target_set:
		_has_logged_camera_target_set = true
		_log_client_startup_timing("first camera target set")


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
	if debug_client_startup_logs:
		print("Sent join request for character %s (%s)." % [character_name, character_id])


func _log_client_startup_timing(event_name: String, counts: Dictionary = {}) -> void:
	if not debug_client_startup_timing:
		return

	var elapsed_msec: int = Time.get_ticks_msec() - _client_startup_timing_start_msec
	var count_parts: PackedStringArray = PackedStringArray()
	for count_name in counts:
		count_parts.append("%s=%s" % [str(count_name), counts[count_name]])

	var count_text: String = ""
	if not count_parts.is_empty():
		count_text = " " + " ".join(count_parts)
	print("Client startup timing event=\"%s\" elapsed_ms=%s%s" % [event_name, elapsed_msec, count_text])
