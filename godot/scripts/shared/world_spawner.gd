extends Node3D

signal spawned_player_count_changed(count: int)
signal player_spawned(peer_id: int, player: Node3D)
signal player_health_updated(peer_id: int, current_hp: int, max_hp: int)
signal player_down_state_updated(peer_id: int, is_down: bool)
signal combat_mode_updated(peer_id: int, combat_enabled: bool, loadout_text: String)
signal ability_enabled_updated(peer_id: int, ability_name: String, enabled: bool)
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
@export var basic_attack_cooldown_seconds: float = 0.75
@export var player_max_hp: int = 100
@export var enemy_contact_range: float = 1.75
@export var enemy_contact_damage: int = 10
@export var enemy_contact_damage_interval: float = 1.0
@export var player_respawn_delay_seconds: float = 3.0

var players: Dictionary = {}
var _spawned_nodes: Dictionary = {}
var _target_positions: Dictionary = {}
var _target_facing_directions: Dictionary = {}
var _last_input_by_peer: Dictionary = {}
var _aim_direction_by_peer: Dictionary = {}
var _last_attack_time_by_peer: Dictionary = {}
var _player_max_hp_by_peer: Dictionary = {}
var _player_current_hp_by_peer: Dictionary = {}
var _player_is_down_by_peer: Dictionary = {}
var _player_respawn_positions: Dictionary = {}
var _last_contact_damage_time_by_peer: Dictionary = {}
var _combat_enabled_by_peer: Dictionary = {}
var _loadout_by_peer: Dictionary = {}
var _ability_enabled_by_peer: Dictionary = {}
var _last_ability_time_by_peer: Dictionary = {}
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

const DEFAULT_LOADOUT: Array[String] = ["Slash", "HP Regen"]
const ABILITY_DEFINITIONS: Dictionary = {
	"Slash": {
		"cooldown": 1.25,
	},
	"HP Regen": {
		"cooldown": 2.0,
		"heal": 8,
	},
}


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
	_last_attack_time_by_peer.erase(peer_id)
	_player_max_hp_by_peer.erase(peer_id)
	_player_current_hp_by_peer.erase(peer_id)
	_player_is_down_by_peer.erase(peer_id)
	_player_respawn_positions.erase(peer_id)
	_last_contact_damage_time_by_peer.erase(peer_id)
	_combat_enabled_by_peer.erase(peer_id)
	_loadout_by_peer.erase(peer_id)
	_ability_enabled_by_peer.erase(peer_id)
	_last_ability_time_by_peer.erase(peer_id)
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
	_player_max_hp_by_peer[peer_id] = player_max_hp
	_player_current_hp_by_peer[peer_id] = player_max_hp
	_player_is_down_by_peer[peer_id] = false
	_player_respawn_positions[peer_id] = players[peer_id]
	_combat_enabled_by_peer[peer_id] = false
	_loadout_by_peer[peer_id] = DEFAULT_LOADOUT.duplicate()
	_ability_enabled_by_peer[peer_id] = _default_ability_enabled_state()
	_last_ability_time_by_peer[peer_id] = {}
	rpc("apply_player_health_update", peer_id, player_max_hp, player_max_hp)
	rpc("apply_player_down_state", peer_id, false)
	rpc("apply_combat_mode_update", peer_id, false, _loadout_text(peer_id))
	_send_ability_enabled_states(peer_id)
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
		_apply_enemy_contact_damage(tick_delta)
		_process_combat_abilities()
		_simulation_accumulator -= tick_delta

	var snapshot_delta := 1.0 / snapshot_rate
	if _snapshot_accumulator >= snapshot_delta:
		_broadcast_position_snapshots()
		_snapshot_accumulator = 0.0


func _simulate(delta: float) -> void:
	for peer_id in players:
		if bool(_player_is_down_by_peer.get(peer_id, false)):
			continue

		var input_direction: Vector2 = _last_input_by_peer.get(peer_id, Vector2.ZERO) as Vector2
		if input_direction.length_squared() > 1.0:
			input_direction = input_direction.normalized()

		var position: Vector3 = players[peer_id] as Vector3
		position.x += input_direction.x * movement_speed * delta
		position.z += input_direction.y * movement_speed * delta
		players[peer_id] = position


func _apply_enemy_contact_damage(_delta: float) -> void:
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner == null:
		return

	var enemy_positions: Dictionary = enemy_spawner.call("get_active_enemy_positions") as Dictionary
	if enemy_positions.is_empty():
		return

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	for peer_id in players:
		var peer_id_int: int = int(peer_id)
		var current_hp: int = int(_player_current_hp_by_peer.get(peer_id, player_max_hp))
		if current_hp <= 0:
			continue

		var last_damage_time: float = float(_last_contact_damage_time_by_peer.get(peer_id, -enemy_contact_damage_interval))
		if now_seconds - last_damage_time < enemy_contact_damage_interval:
			continue

		var player_position: Vector3 = players[peer_id] as Vector3
		if _is_enemy_in_contact_range(player_position, enemy_positions):
			current_hp = max(current_hp - enemy_contact_damage, 0)
			_player_current_hp_by_peer[peer_id] = current_hp
			_last_contact_damage_time_by_peer[peer_id] = now_seconds
			var max_hp: int = int(_player_max_hp_by_peer.get(peer_id, player_max_hp))
			rpc("apply_player_health_update", peer_id_int, current_hp, max_hp)
			if current_hp <= 0:
				_mark_player_down(peer_id_int)


func _mark_player_down(peer_id: int) -> void:
	if bool(_player_is_down_by_peer.get(peer_id, false)):
		return

	_player_is_down_by_peer[peer_id] = true
	_last_input_by_peer[peer_id] = Vector2.ZERO
	rpc("apply_player_down_state", peer_id, true)
	print("Player peer %s is down." % peer_id)
	_schedule_player_respawn(peer_id)


func _schedule_player_respawn(peer_id: int) -> void:
	var respawn_timer: Timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = player_respawn_delay_seconds
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_player_respawn_timer_timeout.bind(peer_id, respawn_timer))
	respawn_timer.start()


func _on_player_respawn_timer_timeout(peer_id: int, respawn_timer: Timer) -> void:
	respawn_timer.queue_free()
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var respawn_position: Vector3 = _player_respawn_positions.get(peer_id, Vector3.ZERO) as Vector3
	var max_hp: int = int(_player_max_hp_by_peer.get(peer_id, player_max_hp))
	players[peer_id] = respawn_position
	_last_input_by_peer[peer_id] = Vector2.ZERO
	_player_current_hp_by_peer[peer_id] = max_hp
	_player_is_down_by_peer[peer_id] = false
	_last_contact_damage_time_by_peer[peer_id] = float(Time.get_ticks_msec()) / 1000.0
	rpc("spawn_player", peer_id, respawn_position, str(_character_names_by_peer.get(peer_id, "")))
	rpc("apply_position_snapshot", peer_id, respawn_position, _aim_direction_by_peer.get(peer_id, Vector2(0.0, -1.0)) as Vector2)
	rpc("apply_player_health_update", peer_id, max_hp, max_hp)
	rpc("apply_player_down_state", peer_id, false)
	print("Player peer %s respawned." % peer_id)


func _is_enemy_in_contact_range(player_position: Vector3, enemy_positions: Dictionary) -> bool:
	for enemy_id in enemy_positions:
		var enemy_position: Vector3 = enemy_positions[enemy_id] as Vector3
		var offset_xz: Vector2 = Vector2(enemy_position.x - player_position.x, enemy_position.z - player_position.z)
		if offset_xz.length() <= enemy_contact_range:
			return true

	return false


func _process_combat_abilities() -> void:
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	for peer_id in players:
		var peer_id_int: int = int(peer_id)
		if not bool(_combat_enabled_by_peer.get(peer_id, false)):
			continue
		if bool(_player_is_down_by_peer.get(peer_id, false)):
			continue

		var loadout: Array = _loadout_by_peer.get(peer_id, []) as Array
		if loadout.has("Slash") and _is_ability_enabled(peer_id_int, "Slash") and _is_ability_ready(peer_id_int, "Slash", now_seconds):
			_set_ability_used(peer_id_int, "Slash", now_seconds)
			_perform_slash(peer_id_int)
		if loadout.has("HP Regen") and _is_ability_enabled(peer_id_int, "HP Regen") and _is_ability_ready(peer_id_int, "HP Regen", now_seconds):
			_set_ability_used(peer_id_int, "HP Regen", now_seconds)
			_apply_hp_regen(peer_id_int)


func _default_ability_enabled_state() -> Dictionary:
	var ability_state: Dictionary = {}
	for ability_name in DEFAULT_LOADOUT:
		ability_state[ability_name] = true

	return ability_state


func _is_ability_enabled(peer_id: int, ability_name: String) -> bool:
	var ability_state: Dictionary = _ability_enabled_by_peer.get(peer_id, {}) as Dictionary
	return bool(ability_state.get(ability_name, true))


func _send_ability_enabled_states(peer_id: int) -> void:
	var ability_state: Dictionary = _ability_enabled_by_peer.get(peer_id, {}) as Dictionary
	for ability_name in ability_state:
		rpc_id(peer_id, "apply_ability_enabled_update", peer_id, str(ability_name), bool(ability_state[ability_name]))


func _is_ability_ready(peer_id: int, ability_name: String, now_seconds: float) -> bool:
	var ability_state: Dictionary = _last_ability_time_by_peer.get(peer_id, {}) as Dictionary
	var last_used: float = float(ability_state.get(ability_name, -_ability_cooldown(ability_name)))
	return now_seconds - last_used >= _ability_cooldown(ability_name)


func _set_ability_used(peer_id: int, ability_name: String, now_seconds: float) -> void:
	var ability_state: Dictionary = _last_ability_time_by_peer.get(peer_id, {}) as Dictionary
	ability_state[ability_name] = now_seconds
	_last_ability_time_by_peer[peer_id] = ability_state


func _ability_cooldown(ability_name: String) -> float:
	var ability_definition: Dictionary = ABILITY_DEFINITIONS.get(ability_name, {}) as Dictionary
	return float(ability_definition.get("cooldown", 1.0))


func _ability_heal_amount(ability_name: String) -> int:
	var ability_definition: Dictionary = ABILITY_DEFINITIONS.get(ability_name, {}) as Dictionary
	return int(ability_definition.get("heal", 0))


func _apply_hp_regen(peer_id: int) -> void:
	var current_hp: int = int(_player_current_hp_by_peer.get(peer_id, player_max_hp))
	var max_hp: int = int(_player_max_hp_by_peer.get(peer_id, player_max_hp))
	if current_hp <= 0 or current_hp >= max_hp:
		return

	current_hp = int(min(current_hp + _ability_heal_amount("HP Regen"), max_hp))
	_player_current_hp_by_peer[peer_id] = current_hp
	rpc("apply_player_health_update", peer_id, current_hp, max_hp)


func _loadout_text(peer_id: int) -> String:
	var loadout: Array = _loadout_by_peer.get(peer_id, DEFAULT_LOADOUT) as Array
	var names: PackedStringArray = PackedStringArray()
	for ability_name in loadout:
		names.append(str(ability_name))

	return ", ".join(names)


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


@rpc("authority", "call_remote", "reliable")
func apply_player_health_update(peer_id: int, current_hp: int, max_hp: int) -> void:
	player_health_updated.emit(peer_id, current_hp, max_hp)


@rpc("authority", "call_remote", "reliable")
func apply_player_down_state(peer_id: int, is_down: bool) -> void:
	player_down_state_updated.emit(peer_id, is_down)


@rpc("authority", "call_remote", "reliable")
func apply_combat_mode_update(peer_id: int, combat_enabled: bool, loadout_text: String) -> void:
	combat_mode_updated.emit(peer_id, combat_enabled, loadout_text)


@rpc("authority", "call_remote", "reliable")
func apply_ability_enabled_update(peer_id: int, ability_name: String, enabled: bool) -> void:
	ability_enabled_updated.emit(peer_id, ability_name, enabled)


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
	if bool(_player_is_down_by_peer.get(peer_id, false)):
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


@rpc("any_peer", "call_remote", "reliable")
func request_toggle_combat_mode() -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = int(multiplayer.get_remote_sender_id())
	if not players.has(peer_id):
		return

	var combat_enabled: bool = not bool(_combat_enabled_by_peer.get(peer_id, false))
	_combat_enabled_by_peer[peer_id] = combat_enabled
	# Server owns combat mode and the temporary prototype loadout.
	rpc("apply_combat_mode_update", peer_id, combat_enabled, _loadout_text(peer_id))


@rpc("any_peer", "call_remote", "reliable")
func request_set_ability_enabled(ability_name: String, enabled: bool) -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = int(multiplayer.get_remote_sender_id())
	if not players.has(peer_id):
		return
	if bool(_player_is_down_by_peer.get(peer_id, false)):
		return

	var loadout: Array = _loadout_by_peer.get(peer_id, []) as Array
	if not loadout.has(ability_name):
		return

	var ability_state: Dictionary = _ability_enabled_by_peer.get(peer_id, {}) as Dictionary
	ability_state[ability_name] = enabled
	_ability_enabled_by_peer[peer_id] = ability_state
	# Server confirms final enabled state; clients display this value only after confirmation.
	rpc_id(peer_id, "apply_ability_enabled_update", peer_id, ability_name, enabled)


@rpc("any_peer", "call_remote", "reliable")
func submit_basic_attack() -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = int(multiplayer.get_remote_sender_id())
	if not players.has(peer_id):
		return
	if bool(_player_is_down_by_peer.get(peer_id, false)):
		return

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var last_attack_time: float = float(_last_attack_time_by_peer.get(peer_id, -basic_attack_cooldown_seconds))
	if now_seconds - last_attack_time < basic_attack_cooldown_seconds:
		return

	_last_attack_time_by_peer[peer_id] = now_seconds
	_perform_slash(peer_id)


func _perform_slash(peer_id: int) -> void:
	var attack_position: Vector3 = players[peer_id] as Vector3
	var facing_direction: Vector2 = _aim_direction_by_peer.get(peer_id, Vector2(0.0, -1.0)) as Vector2
	if facing_direction.length_squared() <= 0.0001:
		facing_direction = Vector2(0.0, -1.0)

	# Slash/basic attack uses server-owned position and facing; clients never decide hits.
	var normalized_facing: Vector2 = facing_direction.normalized()
	rpc("show_basic_attack", peer_id, attack_position, normalized_facing)
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner != null:
		enemy_spawner.call("resolve_basic_attack", peer_id, attack_position, normalized_facing)


@rpc("authority", "call_remote", "reliable")
func show_basic_attack(peer_id: int, attack_position: Vector3, facing_direction: Vector2) -> void:
	if facing_direction.length_squared() <= 0.0001:
		return

	var normalized_facing: Vector2 = facing_direction.normalized()
	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: BoxMesh = BoxMesh.new()
	marker_mesh.size = Vector3(0.7, 0.18, 1.4)
	marker.mesh = marker_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.75, 0.05, 0.75)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = material
	marker.name = "BasicAttack_%s" % peer_id
	marker.position = attack_position + Vector3(normalized_facing.x, 0.0, normalized_facing.y) * 1.2 + Vector3(0.0, 0.25, 0.0)
	marker.rotation.y = atan2(-normalized_facing.x, -normalized_facing.y)
	add_child(marker)

	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 0.18
	marker.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(marker.queue_free)
	cleanup_timer.start()


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
