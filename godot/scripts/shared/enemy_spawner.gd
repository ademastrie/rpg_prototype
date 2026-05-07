extends Node3D
class_name EnemySpawner

signal enemy_killed(attacker_peer_id: int, enemy_id: int)
signal initial_enemy_batch_received(count: int)

@export var enemy_placeholder_scene: PackedScene
@export var idle_radius: float = 1.2
@export var idle_speed: float = 0.6
@export var snapshot_rate: float = 6.0
@export var interpolation_speed: float = 8.0
@export var respawn_delay_seconds: float = 5.0
@export var debug_enemy_lifecycle_logs: bool = false
@export var debug_enemy_join_sync_logs: bool = false
@export var debug_enemy_return_logs: bool = false
@export var debug_enemy_snap_logs: bool = false
@export var enemy_snap_log_threshold: float = 5.0

var enemies: Dictionary = {}
var _spawned_enemy_nodes: Dictionary = {}
var _enemy_origin_positions: Dictionary = {}
var _enemy_spawn_points: Dictionary = {}
var _target_positions: Dictionary = {}
var _enemy_type_by_id: Dictionary = {}
var _enemy_display_name_by_id: Dictionary = {}
var _enemy_max_hp_by_id: Dictionary = {}
var _enemy_current_hp_by_id: Dictionary = {}
var _dead_enemy_ids: Dictionary = {}
var _forced_aggro_peer_by_enemy: Dictionary = {}
var _forced_aggro_until_by_enemy: Dictionary = {}
var _proximity_aggro_peer_by_enemy: Dictionary = {}
var _proximity_aggro_until_by_enemy: Dictionary = {}
var _returning_enemy_ids: Dictionary = {}
var _enemy_return_regen_progress: Dictionary = {}
var _enemy_return_log_last_seconds: Dictionary = {}
var _enemy_suspicious_movement_log_last_seconds: Dictionary = {}
var _enemy_previous_authoritative_positions: Dictionary = {}
var _enemy_melee_windup_until: Dictionary = {}
var _enemy_melee_recovery_until: Dictionary = {}
var _enemy_melee_target_peer: Dictionary = {}
var _enemy_melee_attack_positions: Dictionary = {}
var _enemy_ranged_windup_until: Dictionary = {}
var _enemy_ranged_recovery_until: Dictionary = {}
var _enemy_ranged_target_peer: Dictionary = {}
var _enemy_next_allowed_attack_time_by_key: Dictionary = {}
var _next_enemy_id: int = 1
var _idle_time: float = 0.0
var _snapshot_accumulator: float = 0.0
var _server_enemy_definitions: Dictionary = {}
var _server_region_enemy_spawns: Array[Dictionary] = []
var _server_region_patrol_paths_by_key: Dictionary = {}
var _enemy_definition_overrides_by_id: Dictionary = {}
var _enemy_spawn_respawn_seconds_by_id: Dictionary = {}
var _enemy_region_spawn_key_by_id: Dictionary = {}
var _enemy_patrol_path_key_by_id: Dictionary = {}
var _enemy_patrol_points_by_id: Dictionary = {}
var _enemy_patrol_point_index_by_id: Dictionary = {}
var _enemy_patrol_wait_until_by_id: Dictionary = {}

const DEFAULT_ENEMY_TYPE: String = "grunt"
const SUSPICIOUS_MOVEMENT_STEP: float = 6.0
const DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS: float = 1.0
const DEFAULT_BEHAVIOR_PROFILE_KEY: String = "wander"
const BEHAVIOR_PROFILE_STATIONARY: String = "stationary"
const BEHAVIOR_PROFILE_WANDER: String = "wander"
const BEHAVIOR_PROFILE_PATROL: String = "patrol"
const BEHAVIOR_PROFILE_RANGED_GUARD: String = "ranged_guard"
const BEHAVIOR_PROFILE_AGGRESSIVE: String = "aggressive"
const SUPPORTED_BEHAVIOR_PROFILE_KEYS: Array[String] = [
	BEHAVIOR_PROFILE_STATIONARY,
	BEHAVIOR_PROFILE_WANDER,
	BEHAVIOR_PROFILE_PATROL,
	BEHAVIOR_PROFILE_RANGED_GUARD,
	BEHAVIOR_PROFILE_AGGRESSIVE,
]

# Fallback prototype definitions. Backend enemy definitions are durable data;
# Godot caches them at startup and owns only live simulation state such as HP,
# position, targets, cooldowns, attacks, and leash/respawn state.
const SERVER_PROTOTYPE_ENEMY_DEFINITIONS: Dictionary = {
	"grunt": {
		"enemy_type": "grunt",
		"display_name": "Grunt",
		"level": 1,
		"xp_reward": 25,
		"max_hp": 30,
		"move_speed": 2.2,
		"aggro_radius": 8.0,
		# Damage refreshes this timer so ranged hits can hold threat outside normal aggro radius.
		"forced_aggro_seconds": 16.0,
		"proximity_aggro_seconds": 11.0,
		"home_return_distance": 70.0,
		"target_drop_distance": 65.0,
		"hard_return_distance": 160.0,
		"emergency_failsafe_distance": 1000.0,
		"leash_reset_distance": 0.75,
		"idle_return_distance": 5.0,
		"idle_move_speed": 0.8,
		"return_speed_multiplier": 0.75,
		"return_regen_per_second": 8.0,
		"contact_damage": 0,
		"attack_type": "melee",
		"melee_attack_enabled": true,
		"melee_attack_damage": 15,
		"melee_attack_range": 2.0,
		"melee_attack_radius": 1.75,
		"melee_attack_windup_seconds": 0.65,
		"melee_attack_recovery_seconds": 0.75,
		"melee_attack_cooldown_seconds": DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS,
		"visual_key": "red_placeholder",
		"visual_color": Color(1.0, 0.18, 0.08, 1.0),
	},
	"brute": {
		"enemy_type": "brute",
		"display_name": "Brute",
		"level": 2,
		"xp_reward": 50,
		"max_hp": 75,
		"move_speed": 1.55,
		"aggro_radius": 9.5,
		"forced_aggro_seconds": 16.0,
		"proximity_aggro_seconds": 11.0,
		"home_return_distance": 70.0,
		"target_drop_distance": 65.0,
		"hard_return_distance": 160.0,
		"emergency_failsafe_distance": 1000.0,
		"leash_reset_distance": 0.75,
		"idle_return_distance": 5.0,
		"idle_move_speed": 0.65,
		"return_speed_multiplier": 0.75,
		"return_regen_per_second": 10.0,
		"contact_damage": 0,
		"attack_type": "melee",
		"melee_attack_enabled": true,
		"melee_attack_damage": 22,
		"melee_attack_range": 2.35,
		"melee_attack_radius": 2.2,
		"melee_attack_windup_seconds": 0.85,
		"melee_attack_recovery_seconds": 1.05,
		"melee_attack_cooldown_seconds": DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS,
		"visual_key": "brute_placeholder",
		"visual_color": Color(0.75, 0.14, 0.08, 1.0),
	},
	"caster": {
		"enemy_type": "caster",
		"display_name": "Caster",
		"level": 1,
		"xp_reward": 30,
		"max_hp": 24,
		"move_speed": 1.8,
		"aggro_radius": 10.5,
		"forced_aggro_seconds": 16.0,
		"proximity_aggro_seconds": 11.0,
		"home_return_distance": 70.0,
		"target_drop_distance": 65.0,
		"hard_return_distance": 160.0,
		"emergency_failsafe_distance": 1000.0,
		"leash_reset_distance": 0.75,
		"idle_return_distance": 5.0,
		"idle_move_speed": 0.7,
		"return_speed_multiplier": 0.75,
		"return_regen_per_second": 7.0,
		"contact_damage": 0,
		"attack_type": "ranged",
		"melee_attack_enabled": false,
		"ranged_attack_enabled": true,
		"ranged_attack_damage": 12,
		"ranged_attack_range": 8.0,
		"ranged_attack_preferred_distance": 6.0,
		"ranged_attack_windup_seconds": 0.75,
		"ranged_attack_recovery_seconds": 1.35,
		"ranged_attack_cooldown_seconds": DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS,
		"ranged_attack_width": 0.22,
		"visual_key": "caster_placeholder",
		"visual_color": Color(0.25, 0.45, 1.0, 1.0),
	},
}

const INITIAL_ENEMY_SPAWNS: Array[Dictionary] = [
	{"position": Vector3(6, 0, 2), "enemy_type": DEFAULT_ENEMY_TYPE},
	{"position": Vector3(8, 0, -2), "enemy_type": DEFAULT_ENEMY_TYPE},
	{"position": Vector3(5, 0, 5), "enemy_type": DEFAULT_ENEMY_TYPE},
	{"position": Vector3(10, 0, 4), "enemy_type": "caster"},
]


func spawn_initial_enemies() -> void:
	if not multiplayer.is_server() or not enemies.is_empty():
		return

	if not _server_region_enemy_spawns.is_empty():
		# Backend stores durable spawn definitions. Godot expands them into
		# server-owned live enemy instances and keeps runtime state in memory.
		for spawn_data in _server_region_enemy_spawns:
			var spawn_position: Vector3 = spawn_data.get("position", Vector3.ZERO) as Vector3
			var enemy_type: String = str(spawn_data.get("enemy_type", DEFAULT_ENEMY_TYPE))
			var spawn_key: String = str(spawn_data.get("spawn_key", ""))
			var max_alive: int = max(int(spawn_data.get("max_alive", 1)), 1)
			for spawn_index in range(max_alive):
				_spawn_enemy(_spawn_position_for_index(spawn_position, float(spawn_data.get("spawn_radius", 0.0)), spawn_index, max_alive), enemy_type, spawn_data, spawn_key)
		return

	for spawn_data in INITIAL_ENEMY_SPAWNS:
		var spawn_position: Vector3 = spawn_data.get("position", Vector3.ZERO) as Vector3
		var enemy_type: String = str(spawn_data.get("enemy_type", DEFAULT_ENEMY_TYPE))
		_spawn_enemy(spawn_position, enemy_type)


func load_backend_enemy_definitions(data: Variant) -> bool:
	print("Backend enemy definitions response root type: %s." % type_string(typeof(data)))
	var definitions_array: Array = _extract_backend_enemy_definition_array(data)
	print("Backend enemy definitions raw count found: %s." % definitions_array.size())
	if definitions_array.is_empty():
		print("Backend enemy definitions response did not include any definitions.")
		return false

	var loaded_definitions: Dictionary = {}
	for definition_variant in definitions_array:
		if not (definition_variant is Dictionary):
			continue

		var definition: Dictionary = _normalize_backend_enemy_definition(definition_variant as Dictionary)
		var enemy_type: String = str(definition.get("enemy_type", "")).strip_edges()
		if enemy_type == "":
			continue

		loaded_definitions[enemy_type] = definition

	if loaded_definitions.is_empty():
		print("Backend enemy definitions usable count: 0.")
		print("Backend enemy definitions response had no usable definitions.")
		return false
	print("Backend enemy definitions usable count: %s." % loaded_definitions.size())
	var backend_enemy_keys: Array = loaded_definitions.keys()
	backend_enemy_keys.sort()
	print("Backend enemy keys loaded: %s." % ", ".join(backend_enemy_keys))
	for prototype_enemy_type in SERVER_PROTOTYPE_ENEMY_DEFINITIONS:
		if loaded_definitions.has(prototype_enemy_type):
			continue

		loaded_definitions[prototype_enemy_type] = (SERVER_PROTOTYPE_ENEMY_DEFINITIONS[prototype_enemy_type] as Dictionary).duplicate(true)
		loaded_definitions[prototype_enemy_type]["backend_loaded"] = false
		print("Backend enemy definitions did not include '%s'; using prototype fallback for that type." % prototype_enemy_type)

	# Backend definitions are durable data. This cache is read during simulation;
	# live enemy state remains server-owned in Godot and is never persisted here.
	_server_enemy_definitions = loaded_definitions
	print("Loaded %s backend enemy definitions into Godot server cache." % _server_enemy_definitions.size())
	return true


func use_prototype_enemy_definitions() -> void:
	_server_enemy_definitions = {}
	print("Using fallback Godot prototype enemy definitions.")


func load_backend_region_enemy_spawns(data: Variant) -> bool:
	var spawns_array: Array = _extract_backend_region_enemy_spawn_array(data)
	if spawns_array.is_empty():
		print("Backend region enemy spawns response did not include any spawns.")
		return false

	var loaded_spawns: Array[Dictionary] = []
	for spawn_variant in spawns_array:
		if not (spawn_variant is Dictionary):
			continue

		var spawn_definition: Dictionary = _normalize_backend_region_enemy_spawn(spawn_variant as Dictionary)
		if spawn_definition.is_empty():
			continue

		loaded_spawns.append(spawn_definition)

	if loaded_spawns.is_empty():
		print("Backend region enemy spawns response had no usable spawns.")
		return false

	# Backend stores durable spawn definitions only. Live enemy HP, position,
	# target, cooldown, leash, and respawn state remains server-owned in Godot.
	_server_region_enemy_spawns = loaded_spawns
	print("Loaded %s backend region enemy spawns into Godot server cache." % _server_region_enemy_spawns.size())
	return true


func use_prototype_region_enemy_spawns() -> void:
	_server_region_enemy_spawns = []
	print("Using fallback Godot prototype enemy spawns.")


func load_backend_region_patrol_paths(data: Variant) -> bool:
	var paths_array: Array = _extract_backend_region_patrol_path_array(data)
	var loaded_paths: Dictionary = {}
	for path_variant in paths_array:
		if not (path_variant is Dictionary):
			continue

		var patrol_path: Dictionary = _normalize_backend_region_patrol_path(path_variant as Dictionary)
		if patrol_path.is_empty():
			continue

		loaded_paths[str(patrol_path.get("patrol_path_key", ""))] = patrol_path

	_server_region_patrol_paths_by_key = loaded_paths
	print("Loaded %s backend region patrol paths into Godot server cache." % _server_region_patrol_paths_by_key.size())
	for patrol_path_key in _server_region_patrol_paths_by_key:
		var patrol_path_data: Dictionary = _server_region_patrol_paths_by_key[patrol_path_key] as Dictionary
		var points: Array = patrol_path_data.get("points", []) as Array
		print("Backend patrol path loaded: patrol_path_key=%s point_count=%s." % [patrol_path_key, points.size()])
	return not _server_region_patrol_paths_by_key.is_empty()


func clear_backend_region_patrol_paths() -> void:
	_server_region_patrol_paths_by_key = {}
	print("Loaded 0 backend region patrol paths into Godot server cache.")


func sync_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var alive_player_count: int = _get_alive_player_positions().size()
	var enemy_snapshots: Array = []
	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var spawn_position: Vector3 = enemies[enemy_id] as Vector3
		var current_hp: int = int(_enemy_current_hp_by_id.get(enemy_id, _max_hp_for_enemy(enemy_id_int)))
		var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, _max_hp_for_enemy(enemy_id_int)))
		enemy_snapshots.append({
			"enemy_id": enemy_id_int,
			"position": spawn_position,
			"current_hp": current_hp,
			"max_hp": max_hp,
			"enemy_type": _enemy_type_for_enemy(enemy_id_int),
			"display_name": _enemy_display_name(enemy_id_int),
			"visual_color": _enemy_visual_color(enemy_id_int),
		})

	if not enemy_snapshots.is_empty():
		rpc_id(peer_id, "spawn_enemies", enemy_snapshots)
	if debug_enemy_join_sync_logs:
		print("Join sync targeted to peer %s: enemies=%s broadcast=false." % [peer_id, enemy_snapshots.size()])
		print("Enemy aggro accepted/alive players considered after peer %s join: %s." % [peer_id, alive_player_count])


func get_active_enemy_positions() -> Dictionary:
	return enemies.duplicate()


func get_enemy_xp_reward(enemy_id: int) -> int:
	return _enemy_definition_int(enemy_id, "xp_reward", 0)


func get_enemy_level(enemy_id: int) -> int:
	return _enemy_definition_int(enemy_id, "level", 1)


func get_enemy_loot_table(enemy_id: int) -> Array:
	var definition: Dictionary = _enemy_definition_for_enemy(enemy_id)
	var loot_table: Array = definition.get("loot_table_entries", []) as Array
	return loot_table.duplicate(true)


func get_enemy_type(enemy_id: int) -> String:
	return _enemy_type_for_enemy(enemy_id)


func get_authoritative_enemy_position(enemy_id: int) -> Vector3:
	if not multiplayer.is_server() or not enemies.has(enemy_id):
		return Vector3.ZERO

	return enemies[enemy_id] as Vector3


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		_smooth_spawned_enemies(delta)
		return

	_idle_time += delta
	_snapshot_accumulator += delta
	_update_enemy_positions(delta)

	var safe_snapshot_rate: float = snapshot_rate
	if safe_snapshot_rate <= 0.0:
		safe_snapshot_rate = 0.001

	var snapshot_delta: float = 1.0 / safe_snapshot_rate
	if _snapshot_accumulator >= snapshot_delta:
		_broadcast_enemy_position_snapshots()
		_snapshot_accumulator = 0.0


func _spawn_enemy(spawn_position: Vector3, enemy_type: String = DEFAULT_ENEMY_TYPE, spawn_definition: Dictionary = {}, spawn_key: String = "") -> void:
	var enemy_id: int = _next_enemy_id
	_next_enemy_id += 1
	var resolved_enemy_type: String = _resolved_enemy_type(enemy_type)
	var max_hp: int = _max_hp_for_type(resolved_enemy_type)
	enemies[enemy_id] = spawn_position
	_enemy_origin_positions[enemy_id] = spawn_position
	_enemy_spawn_points[enemy_id] = spawn_position
	_enemy_previous_authoritative_positions[enemy_id] = spawn_position
	_enemy_type_by_id[enemy_id] = resolved_enemy_type
	_enemy_max_hp_by_id[enemy_id] = max_hp
	_enemy_current_hp_by_id[enemy_id] = max_hp
	if not spawn_definition.is_empty():
		_enemy_region_spawn_key_by_id[enemy_id] = spawn_key
		_enemy_spawn_respawn_seconds_by_id[enemy_id] = max(float(spawn_definition.get("respawn_seconds", respawn_delay_seconds)), 0.0)
		_assign_patrol_path_to_enemy(enemy_id, spawn_definition)
		var definition_overrides: Dictionary = spawn_definition.get("definition_overrides", {}) as Dictionary
		if not definition_overrides.is_empty():
			_enemy_definition_overrides_by_id[enemy_id] = definition_overrides.duplicate(true)
	_log_backend_enemy_spawn_tuning(enemy_id, spawn_position)
	rpc("spawn_enemy", enemy_id, spawn_position, max_hp, max_hp, resolved_enemy_type, _enemy_display_name(enemy_id), _enemy_visual_color(enemy_id))
	if debug_enemy_lifecycle_logs:
		print("Spawned enemy %s type=%s at %s." % [enemy_id, resolved_enemy_type, spawn_position])


func resolve_basic_attack(_attacker_peer_id: int, attack_position: Vector3, facing_direction: Vector2, slash_range: float, slash_arc_angle: float, damage: int) -> int:
	if not multiplayer.is_server() or facing_direction.length_squared() <= 0.0001 or slash_range <= 0.0 or slash_arc_angle <= 0.0 or damage <= 0:
		return 0

	var normalized_facing: Vector2 = facing_direction.normalized()
	var min_arc_dot: float = cos(deg_to_rad(clamp(slash_arc_angle, 0.0, 360.0) * 0.5))
	var enemies_hit: int = 0
	for enemy_id in enemies.keys():
		var enemy_id_int: int = int(enemy_id)
		if not enemies.has(enemy_id_int):
			continue

		var enemy_position: Vector3 = enemies[enemy_id_int] as Vector3
		var offset_xz: Vector2 = Vector2(enemy_position.x - attack_position.x, enemy_position.z - attack_position.z)
		var distance: float = offset_xz.length()
		if distance <= 0.001 or distance > slash_range:
			continue

		var direction_to_enemy: Vector2 = offset_xz / distance
		if normalized_facing.dot(direction_to_enemy) < min_arc_dot:
			continue

		_apply_damage_to_enemy(enemy_id_int, _attacker_peer_id, damage)
		enemies_hit += 1

	return enemies_hit


func resolve_damage_aura(_attacker_peer_id: int, aura_position: Vector3, radius: float, damage: int) -> void:
	if not multiplayer.is_server() or radius <= 0.0 or damage <= 0:
		return

	for enemy_id in enemies.keys():
		var enemy_id_int: int = int(enemy_id)
		if not enemies.has(enemy_id_int):
			continue

		var enemy_position: Vector3 = enemies[enemy_id_int] as Vector3
		var offset_xz: Vector2 = Vector2(enemy_position.x - aura_position.x, enemy_position.z - aura_position.z)
		if offset_xz.length() > radius:
			continue

		_apply_damage_to_enemy(enemy_id_int, _attacker_peer_id, damage)


func resolve_fireball_aoe(_attacker_peer_id: int, impact_position: Vector3, radius: float, damage: int) -> int:
	if not multiplayer.is_server() or radius <= 0.0 or damage <= 0:
		return 0

	var enemies_hit: int = 0
	for enemy_id in enemies.keys():
		var enemy_id_int: int = int(enemy_id)
		if not enemies.has(enemy_id_int):
			continue

		var enemy_position: Vector3 = enemies[enemy_id_int] as Vector3
		var offset_xz: Vector2 = Vector2(enemy_position.x - impact_position.x, enemy_position.z - impact_position.z)
		if offset_xz.length() > radius:
			continue

		_apply_damage_to_enemy(enemy_id_int, _attacker_peer_id, damage)
		enemies_hit += 1

	return enemies_hit


func _apply_damage_to_enemy(enemy_id: int, attacker_peer_id: int, damage: int) -> void:
	if not enemies.has(enemy_id) or damage <= 0:
		return

	var current_hp: int = int(_enemy_current_hp_by_id.get(enemy_id, _max_hp_for_enemy(enemy_id)))
	var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, _max_hp_for_enemy(enemy_id)))
	current_hp = max(current_hp - damage, 0)
	_enemy_current_hp_by_id[enemy_id] = current_hp
	rpc("show_enemy_hit", enemy_id, current_hp, max_hp)

	if current_hp <= 0:
		enemy_killed.emit(attacker_peer_id, enemy_id)
		_despawn_enemy(enemy_id)
		return

	_set_forced_aggro(enemy_id, attacker_peer_id)


func _despawn_enemy(enemy_id: int) -> void:
	enemies.erase(enemy_id)
	_enemy_origin_positions.erase(enemy_id)
	_target_positions.erase(enemy_id)
	_forced_aggro_peer_by_enemy.erase(enemy_id)
	_forced_aggro_until_by_enemy.erase(enemy_id)
	_proximity_aggro_peer_by_enemy.erase(enemy_id)
	_proximity_aggro_until_by_enemy.erase(enemy_id)
	_clear_enemy_attacks(enemy_id)
	_returning_enemy_ids.erase(enemy_id)
	_enemy_return_regen_progress.erase(enemy_id)
	_enemy_return_log_last_seconds.erase(enemy_id)
	_enemy_suspicious_movement_log_last_seconds.erase(enemy_id)
	_enemy_previous_authoritative_positions.erase(enemy_id)
	_enemy_patrol_point_index_by_id.erase(enemy_id)
	_enemy_patrol_wait_until_by_id.erase(enemy_id)
	_dead_enemy_ids[enemy_id] = true
	rpc("despawn_enemy", enemy_id)
	_schedule_enemy_respawn(enemy_id)


func _schedule_enemy_respawn(enemy_id: int) -> void:
	if not multiplayer.is_server() or not _enemy_spawn_points.has(enemy_id):
		return

	var respawn_timer: Timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = max(float(_enemy_spawn_respawn_seconds_by_id.get(enemy_id, respawn_delay_seconds)), 0.0)
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_enemy_respawn_timer_timeout.bind(enemy_id, respawn_timer))
	respawn_timer.start()


func _on_enemy_respawn_timer_timeout(enemy_id: int, respawn_timer: Timer) -> void:
	respawn_timer.queue_free()
	if not multiplayer.is_server() or not _dead_enemy_ids.has(enemy_id):
		return

	var spawn_position: Vector3 = _enemy_spawn_points[enemy_id] as Vector3
	_respawn_enemy(enemy_id, spawn_position)


func _respawn_enemy(enemy_id: int, spawn_position: Vector3) -> void:
	# Respawns keep stable enemy ids; the server owns timing and state.
	var enemy_type: String = _enemy_type_for_enemy(enemy_id)
	var max_hp: int = _max_hp_for_enemy(enemy_id)
	enemies[enemy_id] = spawn_position
	_enemy_origin_positions[enemy_id] = spawn_position
	_enemy_previous_authoritative_positions[enemy_id] = spawn_position
	_enemy_type_by_id[enemy_id] = enemy_type
	_enemy_max_hp_by_id[enemy_id] = max_hp
	_enemy_current_hp_by_id[enemy_id] = max_hp
	_forced_aggro_peer_by_enemy.erase(enemy_id)
	_forced_aggro_until_by_enemy.erase(enemy_id)
	_proximity_aggro_peer_by_enemy.erase(enemy_id)
	_proximity_aggro_until_by_enemy.erase(enemy_id)
	_clear_enemy_attacks(enemy_id)
	_returning_enemy_ids.erase(enemy_id)
	_enemy_return_regen_progress.erase(enemy_id)
	_enemy_return_log_last_seconds.erase(enemy_id)
	_enemy_patrol_wait_until_by_id.erase(enemy_id)
	_dead_enemy_ids.erase(enemy_id)
	rpc("spawn_enemy", enemy_id, spawn_position, max_hp, max_hp, enemy_type, _enemy_display_name(enemy_id), _enemy_visual_color(enemy_id))
	if debug_enemy_lifecycle_logs:
		print("Respawned enemy %s type=%s at %s." % [enemy_id, enemy_type, spawn_position])


func _update_enemy_positions(delta: float) -> void:
	var alive_player_positions: Dictionary = _get_alive_player_positions()
	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var enemy_position: Vector3 = enemies[enemy_id] as Vector3
		var spawn_position: Vector3 = _enemy_spawn_points.get(enemy_id_int, enemy_position) as Vector3
		if _returning_enemy_ids.has(enemy_id_int):
			_clear_enemy_attacks(enemy_id_int)
			var return_position: Vector3 = _return_position(enemy_id_int, enemy_position, spawn_position, delta)
			enemies[enemy_id] = return_position
			_log_server_enemy_snap(enemy_id_int, enemy_position, return_position, delta, "returning", _target_peer_for_enemy(enemy_id_int))
			continue

		if _update_enemy_melee_windup(enemy_id_int):
			_log_server_enemy_snap(enemy_id_int, enemy_position, enemy_position, delta, "melee_windup", _target_peer_for_enemy(enemy_id_int))
			continue

		if _update_enemy_ranged_windup(enemy_id_int):
			_log_server_enemy_snap(enemy_id_int, enemy_position, enemy_position, delta, "ranged_windup", _target_peer_for_enemy(enemy_id_int))
			continue

		var target: Dictionary = _aggro_target_for_enemy(enemy_id_int, enemy_position, alive_player_positions)
		if bool(target.get("has_target", false)):
			var target_position: Vector3 = target.get("position", Vector3.ZERO) as Vector3
			var target_peer_id: int = int(target.get("peer_id", _target_peer_for_enemy(enemy_id_int)))
			if _should_return_with_target(enemy_id_int, enemy_position, spawn_position, target_position):
				_begin_return_to_spawn(enemy_id_int, "target or hard home distance exceeded", enemy_position, spawn_position, target_position, true)
				var target_return_position: Vector3 = _return_position(enemy_id_int, enemy_position, spawn_position, delta)
				enemies[enemy_id] = target_return_position
				_log_server_enemy_snap(enemy_id_int, enemy_position, target_return_position, delta, "entering_return", target_peer_id)
				continue

			if _can_start_enemy_ranged_attack(enemy_id_int, enemy_position, target_position):
				_start_enemy_ranged_attack(enemy_id_int, enemy_position, target_position, target_peer_id)
				_log_server_enemy_snap(enemy_id_int, enemy_position, enemy_position, delta, "ranged_start", target_peer_id)
				continue

			if _can_start_enemy_melee_attack(enemy_id_int, enemy_position, target_position):
				_start_enemy_melee_attack(enemy_id_int, enemy_position, target_peer_id)
				_log_server_enemy_snap(enemy_id_int, enemy_position, enemy_position, delta, "melee_start", target_peer_id)
				continue

			if _should_hold_melee_recovery_position(enemy_id_int, enemy_position, target_position):
				_log_server_enemy_snap(enemy_id_int, enemy_position, enemy_position, delta, "melee_recovery_hold", target_peer_id)
				continue

			if _should_hold_ranged_position(enemy_id_int, enemy_position, target_position):
				_log_server_enemy_snap(enemy_id_int, enemy_position, enemy_position, delta, "ranged_hold", target_peer_id)
				continue

			if _should_ranged_guard_hold_near_spawn(enemy_id_int, enemy_position, target_position):
				_log_server_enemy_snap(enemy_id_int, enemy_position, enemy_position, delta, "ranged_guard_hold", target_peer_id)
				continue

			var chase_position: Vector3 = _chase_position(enemy_id_int, enemy_position, target_position, delta)
			enemies[enemy_id] = chase_position
			_log_server_enemy_snap(enemy_id_int, enemy_position, chase_position, delta, "chasing", target_peer_id)
			continue

		if _should_return_without_target(enemy_id_int, enemy_position, spawn_position):
			_begin_return_to_spawn(enemy_id_int, "no valid target outside home area", enemy_position, spawn_position, Vector3.ZERO, false)
			var no_target_return_position: Vector3 = _return_position(enemy_id_int, enemy_position, spawn_position, delta)
			enemies[enemy_id] = no_target_return_position
			_log_server_enemy_snap(enemy_id_int, enemy_position, no_target_return_position, delta, "entering_return", 0)
			continue

		var idle_return_distance: float = _enemy_definition_float(enemy_id_int, "idle_return_distance", 5.0)
		var distance_from_spawn: float = _distance_xz(enemy_position, spawn_position)
		if not _enemy_has_valid_patrol(enemy_id_int) and distance_from_spawn > idle_return_distance:
			_begin_return_to_spawn(enemy_id_int, "idle redirected to return because enemy is far from home", enemy_position, spawn_position, Vector3.ZERO, false)
			var idle_return_position: Vector3 = _return_position(enemy_id_int, enemy_position, spawn_position, delta)
			enemies[enemy_id] = idle_return_position
			_log_server_enemy_snap(enemy_id_int, enemy_position, idle_return_position, delta, "idle_redirected_to_return", 0)
			continue

		var idle_position: Vector3 = _profile_idle_position(enemy_id_int, enemy_position, spawn_position, delta)
		enemies[enemy_id] = idle_position
		_log_server_enemy_snap(enemy_id_int, enemy_position, idle_position, delta, "idle", 0)


func _get_alive_player_positions() -> Dictionary:
	var world_spawner: Node = get_node_or_null("../WorldSpawner")
	if world_spawner == null:
		return {}

	return world_spawner.call("get_alive_player_positions") as Dictionary


func _aggro_target_for_enemy(enemy_id: int, enemy_position: Vector3, alive_player_positions: Dictionary) -> Dictionary:
	var forced_target: Dictionary = _forced_aggro_target(enemy_id, alive_player_positions)
	if bool(forced_target.get("has_target", false)):
		return forced_target

	var proximity_target: Dictionary = _proximity_aggro_target(enemy_id, enemy_position, alive_player_positions)
	if bool(proximity_target.get("has_target", false)):
		return proximity_target

	var nearest_target: Dictionary = _nearest_aggro_player(enemy_id, enemy_position, alive_player_positions)
	if bool(nearest_target.get("has_target", false)):
		var peer_id: int = int(nearest_target.get("peer_id", 0))
		_set_proximity_aggro(enemy_id, peer_id)
		return nearest_target

	return {"has_target": false, "position": Vector3.ZERO}


func _forced_aggro_target(enemy_id: int, alive_player_positions: Dictionary) -> Dictionary:
	if not _forced_aggro_peer_by_enemy.has(enemy_id):
		return {"has_target": false, "position": Vector3.ZERO}

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var aggro_until: float = float(_forced_aggro_until_by_enemy.get(enemy_id, 0.0))
	var peer_id: int = int(_forced_aggro_peer_by_enemy.get(enemy_id, 0))
	if now_seconds > aggro_until or not alive_player_positions.has(peer_id):
		_forced_aggro_peer_by_enemy.erase(enemy_id)
		_forced_aggro_until_by_enemy.erase(enemy_id)
		return {"has_target": false, "position": Vector3.ZERO}

	return {
		"has_target": true,
		"position": alive_player_positions[peer_id] as Vector3,
		"peer_id": peer_id,
	}


func _proximity_aggro_target(enemy_id: int, enemy_position: Vector3, alive_player_positions: Dictionary) -> Dictionary:
	if not _proximity_aggro_peer_by_enemy.has(enemy_id):
		return {"has_target": false, "position": Vector3.ZERO}

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var aggro_until: float = float(_proximity_aggro_until_by_enemy.get(enemy_id, 0.0))
	var peer_id: int = int(_proximity_aggro_peer_by_enemy.get(enemy_id, 0))
	if not alive_player_positions.has(peer_id):
		_proximity_aggro_peer_by_enemy.erase(enemy_id)
		_proximity_aggro_until_by_enemy.erase(enemy_id)
		return {"has_target": false, "position": Vector3.ZERO}

	var player_position: Vector3 = alive_player_positions[peer_id] as Vector3
	var aggro_radius: float = _profile_aggro_radius(enemy_id)
	if _distance_xz(enemy_position, player_position) <= aggro_radius:
		aggro_until = now_seconds + _profile_proximity_aggro_seconds(enemy_id)
		_proximity_aggro_until_by_enemy[enemy_id] = aggro_until

	if now_seconds > aggro_until:
		_proximity_aggro_peer_by_enemy.erase(enemy_id)
		_proximity_aggro_until_by_enemy.erase(enemy_id)
		return {"has_target": false, "position": Vector3.ZERO}

	return {
		"has_target": true,
		"position": player_position,
		"peer_id": peer_id,
	}


func _nearest_aggro_player(enemy_id: int, enemy_position: Vector3, alive_player_positions: Dictionary) -> Dictionary:
	var aggro_radius: float = _profile_aggro_radius(enemy_id)
	var nearest_position: Vector3 = Vector3.ZERO
	var nearest_distance: float = aggro_radius
	var nearest_peer_id: int = 0
	var has_target: bool = false
	for peer_id in alive_player_positions:
		var peer_id_int: int = int(peer_id)
		var player_position: Vector3 = alive_player_positions[peer_id] as Vector3
		var offset_xz: Vector2 = Vector2(player_position.x - enemy_position.x, player_position.z - enemy_position.z)
		var distance: float = offset_xz.length()
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_position = player_position
			nearest_peer_id = peer_id_int
			has_target = true

	return {
		"has_target": has_target,
		"position": nearest_position,
		"peer_id": nearest_peer_id,
	}


func _set_proximity_aggro(enemy_id: int, peer_id: int) -> void:
	if peer_id <= 0:
		return

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_proximity_aggro_peer_by_enemy[enemy_id] = peer_id
	_proximity_aggro_until_by_enemy[enemy_id] = now_seconds + _profile_proximity_aggro_seconds(enemy_id)


func _set_forced_aggro(enemy_id: int, attacker_peer_id: int) -> void:
	if attacker_peer_id <= 0 or not _is_peer_alive(attacker_peer_id):
		return

	if _returning_enemy_ids.has(enemy_id) and _is_enemy_beyond_emergency_failsafe(enemy_id):
		return

	_returning_enemy_ids.erase(enemy_id)
	_enemy_return_regen_progress.erase(enemy_id)
	_proximity_aggro_peer_by_enemy.erase(enemy_id)
	_proximity_aggro_until_by_enemy.erase(enemy_id)
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_forced_aggro_peer_by_enemy[enemy_id] = attacker_peer_id
	_forced_aggro_until_by_enemy[enemy_id] = now_seconds + _profile_forced_aggro_seconds(enemy_id)


func _can_start_enemy_melee_attack(enemy_id: int, enemy_position: Vector3, target_position: Vector3) -> bool:
	if _enemy_attack_type(enemy_id) != "melee":
		return false

	var melee_attack_range: float = _enemy_definition_float(enemy_id, "melee_attack_range", 2.0)
	var melee_attack_radius: float = _enemy_definition_float(enemy_id, "melee_attack_radius", 1.75)
	var melee_attack_damage: int = _enemy_definition_int(enemy_id, "melee_attack_damage", 15)
	if not _enemy_definition_bool(enemy_id, "melee_attack_enabled", true) or melee_attack_damage <= 0 or melee_attack_range <= 0.0 or melee_attack_radius <= 0.0:
		return false
	if _enemy_melee_windup_until.has(enemy_id):
		return false

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var recovery_until: float = float(_enemy_melee_recovery_until.get(enemy_id, 0.0))
	if now_seconds < recovery_until:
		return false
	var attack_key: String = _enemy_melee_attack_key(enemy_id)
	if now_seconds < _next_allowed_attack_time(enemy_id, attack_key):
		return false

	return _distance_xz(enemy_position, target_position) <= melee_attack_range


func _start_enemy_melee_attack(enemy_id: int, enemy_position: Vector3, target_peer_id: int) -> void:
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var attack_key: String = _enemy_melee_attack_key(enemy_id)
	var windup_seconds: float = max(_enemy_definition_float(enemy_id, "melee_attack_windup_seconds", 0.65), 0.01)
	var recovery_seconds: float = max(_enemy_definition_float(enemy_id, "melee_attack_recovery_seconds", 0.75), 0.0)
	var cooldown_seconds: float = _enemy_attack_cooldown_seconds(enemy_id, "melee_attack_cooldown_seconds")
	var next_allowed_attack_time: float = now_seconds + cooldown_seconds
	_set_next_allowed_attack_time(enemy_id, attack_key, next_allowed_attack_time)
	_enemy_melee_windup_until[enemy_id] = now_seconds + windup_seconds
	_enemy_melee_target_peer[enemy_id] = target_peer_id
	_enemy_melee_attack_positions[enemy_id] = enemy_position
	_log_enemy_attack_started(enemy_id, attack_key, windup_seconds, recovery_seconds, cooldown_seconds, next_allowed_attack_time)
	rpc("show_enemy_melee_telegraph", enemy_id, enemy_position, _enemy_definition_float(enemy_id, "melee_attack_radius", 1.75), windup_seconds)


func _update_enemy_melee_windup(enemy_id: int) -> bool:
	if not _enemy_melee_windup_until.has(enemy_id):
		return false

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	if now_seconds < float(_enemy_melee_windup_until.get(enemy_id, 0.0)):
		return true

	_resolve_enemy_melee_attack(enemy_id)
	return false


func _resolve_enemy_melee_attack(enemy_id: int) -> void:
	var target_peer_id: int = int(_enemy_melee_target_peer.get(enemy_id, 0))
	var attack_position: Vector3 = _enemy_melee_attack_positions.get(enemy_id, Vector3.ZERO) as Vector3
	_clear_enemy_melee_windup(enemy_id)
	_enemy_melee_recovery_until[enemy_id] = float(Time.get_ticks_msec()) / 1000.0 + max(_enemy_definition_float(enemy_id, "melee_attack_recovery_seconds", 0.75), 0.0)

	if target_peer_id <= 0:
		return

	var alive_player_positions: Dictionary = _get_alive_player_positions()
	if not alive_player_positions.has(target_peer_id):
		return

	var target_position: Vector3 = alive_player_positions[target_peer_id] as Vector3
	var melee_attack_radius: float = _enemy_definition_float(enemy_id, "melee_attack_radius", 1.75)
	if _distance_xz(attack_position, target_position) > melee_attack_radius:
		return

	var world_spawner: Node = get_node_or_null("../WorldSpawner")
	if world_spawner != null:
		world_spawner.call("apply_enemy_damage_to_player", target_peer_id, _enemy_definition_int(enemy_id, "melee_attack_damage", 15))


func _clear_enemy_melee_windup(enemy_id: int) -> void:
	_enemy_melee_windup_until.erase(enemy_id)
	_enemy_melee_target_peer.erase(enemy_id)
	_enemy_melee_attack_positions.erase(enemy_id)


func _clear_enemy_melee_attack(enemy_id: int) -> void:
	_clear_enemy_melee_windup(enemy_id)
	_enemy_melee_recovery_until.erase(enemy_id)


func _can_start_enemy_ranged_attack(enemy_id: int, enemy_position: Vector3, target_position: Vector3) -> bool:
	if not _enemy_can_use_ranged_attack(enemy_id):
		return false

	var ranged_attack_range: float = _enemy_definition_float(enemy_id, "ranged_attack_range", 8.0)
	var ranged_attack_damage: int = _enemy_definition_int(enemy_id, "ranged_attack_damage", 12)
	if not _enemy_definition_bool(enemy_id, "ranged_attack_enabled", false) or ranged_attack_damage <= 0 or ranged_attack_range <= 0.0:
		return false
	if _enemy_ranged_windup_until.has(enemy_id):
		return false

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var recovery_until: float = float(_enemy_ranged_recovery_until.get(enemy_id, 0.0))
	if now_seconds < recovery_until:
		return false
	var attack_key: String = _enemy_ranged_attack_key(enemy_id)
	if now_seconds < _next_allowed_attack_time(enemy_id, attack_key):
		return false

	return _distance_xz(enemy_position, target_position) <= ranged_attack_range


func _start_enemy_ranged_attack(enemy_id: int, enemy_position: Vector3, target_position: Vector3, target_peer_id: int) -> void:
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var attack_key: String = _enemy_ranged_attack_key(enemy_id)
	var windup_seconds: float = max(_enemy_definition_float(enemy_id, "ranged_attack_windup_seconds", 0.75), 0.01)
	var recovery_seconds: float = max(_enemy_definition_float(enemy_id, "ranged_attack_recovery_seconds", 1.35), 0.0)
	var cooldown_seconds: float = _enemy_attack_cooldown_seconds(enemy_id, "ranged_attack_cooldown_seconds")
	var next_allowed_attack_time: float = now_seconds + cooldown_seconds
	_set_next_allowed_attack_time(enemy_id, attack_key, next_allowed_attack_time)
	_enemy_ranged_windup_until[enemy_id] = now_seconds + windup_seconds
	_enemy_ranged_target_peer[enemy_id] = target_peer_id
	_log_enemy_attack_started(enemy_id, attack_key, windup_seconds, recovery_seconds, cooldown_seconds, next_allowed_attack_time)
	rpc("show_enemy_ranged_telegraph", enemy_id, enemy_position, target_position, _enemy_definition_float(enemy_id, "ranged_attack_width", 0.22), windup_seconds)


func _update_enemy_ranged_windup(enemy_id: int) -> bool:
	if not _enemy_ranged_windup_until.has(enemy_id):
		return false

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	if now_seconds < float(_enemy_ranged_windup_until.get(enemy_id, 0.0)):
		return true

	_resolve_enemy_ranged_attack(enemy_id)
	return false


func _resolve_enemy_ranged_attack(enemy_id: int) -> void:
	var target_peer_id: int = int(_enemy_ranged_target_peer.get(enemy_id, 0))
	_clear_enemy_ranged_windup(enemy_id)
	_enemy_ranged_recovery_until[enemy_id] = float(Time.get_ticks_msec()) / 1000.0 + max(_enemy_definition_float(enemy_id, "ranged_attack_recovery_seconds", 1.35), 0.0)

	if target_peer_id <= 0 or not enemies.has(enemy_id):
		return

	var alive_player_positions: Dictionary = _get_alive_player_positions()
	if not alive_player_positions.has(target_peer_id):
		return

	var enemy_position: Vector3 = enemies[enemy_id] as Vector3
	var target_position: Vector3 = alive_player_positions[target_peer_id] as Vector3
	if _distance_xz(enemy_position, target_position) > _enemy_definition_float(enemy_id, "ranged_attack_range", 8.0):
		return

	var world_spawner: Node = get_node_or_null("../WorldSpawner")
	if world_spawner != null:
		world_spawner.call("apply_enemy_damage_to_player", target_peer_id, _enemy_definition_int(enemy_id, "ranged_attack_damage", 12))


func _clear_enemy_ranged_windup(enemy_id: int) -> void:
	_enemy_ranged_windup_until.erase(enemy_id)
	_enemy_ranged_target_peer.erase(enemy_id)


func _clear_enemy_ranged_attack(enemy_id: int) -> void:
	_clear_enemy_ranged_windup(enemy_id)
	_enemy_ranged_recovery_until.erase(enemy_id)


func _clear_enemy_attacks(enemy_id: int) -> void:
	_clear_enemy_melee_attack(enemy_id)
	_clear_enemy_ranged_attack(enemy_id)
	_clear_enemy_attack_cooldowns(enemy_id)


func _enemy_melee_attack_key(enemy_id: int) -> String:
	var attack_key: String = str(_enemy_definition_for_enemy(enemy_id).get("melee_attack_key", "melee")).strip_edges()
	if attack_key == "":
		return "melee"
	return attack_key


func _enemy_ranged_attack_key(enemy_id: int) -> String:
	var attack_key: String = str(_enemy_definition_for_enemy(enemy_id).get("ranged_attack_key", "ranged")).strip_edges()
	if attack_key == "":
		return "ranged"
	return attack_key


func _enemy_attack_cooldown_seconds(enemy_id: int, definition_key: String) -> float:
	var cooldown_seconds: float = _enemy_definition_float(enemy_id, definition_key, DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS)
	if cooldown_seconds <= 0.0:
		return DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS
	return cooldown_seconds


func _next_allowed_attack_time(enemy_id: int, attack_key: String) -> float:
	return float(_enemy_next_allowed_attack_time_by_key.get(_enemy_attack_cooldown_state_key(enemy_id, attack_key), 0.0))


func _set_next_allowed_attack_time(enemy_id: int, attack_key: String, next_allowed_attack_time: float) -> void:
	_enemy_next_allowed_attack_time_by_key[_enemy_attack_cooldown_state_key(enemy_id, attack_key)] = next_allowed_attack_time


func _clear_enemy_attack_cooldowns(enemy_id: int) -> void:
	var state_key_prefix: String = "%s:" % enemy_id
	for state_key in _enemy_next_allowed_attack_time_by_key.keys():
		if str(state_key).begins_with(state_key_prefix):
			_enemy_next_allowed_attack_time_by_key.erase(state_key)


func _enemy_attack_cooldown_state_key(enemy_id: int, attack_key: String) -> String:
	return "%s:%s" % [enemy_id, attack_key]


func _log_enemy_attack_started(enemy_id: int, attack_key: String, windup_seconds: float, recovery_seconds: float, cooldown_seconds: float, next_allowed_attack_time: float) -> void:
	print("Enemy attack started: enemy_id=%s attack_key=%s windup_seconds=%s recovery_seconds=%s cooldown_seconds=%s next_allowed_attack_time=%s." % [
		enemy_id,
		attack_key,
		windup_seconds,
		recovery_seconds,
		cooldown_seconds,
		next_allowed_attack_time,
	])


func _should_hold_ranged_position(enemy_id: int, enemy_position: Vector3, target_position: Vector3) -> bool:
	if not _enemy_can_use_ranged_attack(enemy_id):
		return false
	if not _enemy_definition_bool(enemy_id, "ranged_attack_enabled", false):
		return false

	var preferred_distance: float = _enemy_definition_float(enemy_id, "ranged_attack_preferred_distance", 6.0)
	var ranged_attack_range: float = _enemy_definition_float(enemy_id, "ranged_attack_range", 8.0)
	if preferred_distance <= 0.0:
		preferred_distance = ranged_attack_range

	return _distance_xz(enemy_position, target_position) <= min(preferred_distance, ranged_attack_range)


func _should_ranged_guard_hold_near_spawn(enemy_id: int, enemy_position: Vector3, target_position: Vector3) -> bool:
	if _enemy_behavior_profile_key(enemy_id) != BEHAVIOR_PROFILE_RANGED_GUARD:
		return false
	if not _enemy_can_use_ranged_attack(enemy_id) or not _enemy_definition_bool(enemy_id, "ranged_attack_enabled", false):
		return false

	var ranged_attack_range: float = _enemy_definition_float(enemy_id, "ranged_attack_range", 8.0)
	if ranged_attack_range <= 0.0:
		return false

	var distance_to_target: float = _distance_xz(enemy_position, target_position)
	if distance_to_target > ranged_attack_range:
		return false

	return true


func _should_hold_melee_recovery_position(enemy_id: int, enemy_position: Vector3, target_position: Vector3) -> bool:
	if _enemy_attack_type(enemy_id) != "melee":
		return false

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	if now_seconds >= float(_enemy_melee_recovery_until.get(enemy_id, 0.0)):
		return false

	var melee_attack_range: float = _enemy_definition_float(enemy_id, "melee_attack_range", 2.0)
	if melee_attack_range <= 0.0:
		return false

	return _distance_xz(enemy_position, target_position) <= melee_attack_range


func _is_peer_alive(peer_id: int) -> bool:
	var alive_player_positions: Dictionary = _get_alive_player_positions()
	return alive_player_positions.has(peer_id)


func _target_peer_for_enemy(enemy_id: int) -> int:
	if _forced_aggro_peer_by_enemy.has(enemy_id):
		return int(_forced_aggro_peer_by_enemy.get(enemy_id, 0))
	if _proximity_aggro_peer_by_enemy.has(enemy_id):
		return int(_proximity_aggro_peer_by_enemy.get(enemy_id, 0))
	return 0


func _should_return_with_target(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, target_position: Vector3) -> bool:
	var target_drop_distance: float = _profile_target_drop_distance(enemy_id)
	if _distance_xz(enemy_position, target_position) > target_drop_distance:
		return true

	var hard_return_distance: float = _profile_hard_return_distance(enemy_id)
	return _distance_xz(enemy_position, spawn_position) > hard_return_distance


func _should_return_without_target(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3) -> bool:
	var home_return_distance: float = _profile_home_return_distance(enemy_id)
	return _distance_xz(enemy_position, spawn_position) > home_return_distance


func _begin_return_to_spawn(enemy_id: int, reason: String, enemy_position: Vector3, spawn_position: Vector3, target_position: Vector3, has_target: bool) -> void:
	if _returning_enemy_ids.has(enemy_id):
		return

	_returning_enemy_ids[enemy_id] = true
	_forced_aggro_peer_by_enemy.erase(enemy_id)
	_forced_aggro_until_by_enemy.erase(enemy_id)
	_proximity_aggro_peer_by_enemy.erase(enemy_id)
	_proximity_aggro_until_by_enemy.erase(enemy_id)
	var distance_from_spawn: float = _distance_xz(enemy_position, spawn_position)
	var distance_to_target: float = -1.0
	if has_target:
		distance_to_target = _distance_xz(enemy_position, target_position)
	if debug_enemy_return_logs:
		print("Enemy %s returning to spawn: %s. distance_from_spawn=%s distance_to_target=%s return_speed=%s" % [enemy_id, reason, distance_from_spawn, distance_to_target, _return_speed(enemy_id)])


func _return_position(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, delta: float) -> Vector3:
	var distance_from_spawn: float = _distance_xz(enemy_position, spawn_position)
	var emergency_failsafe_distance: float = _enemy_definition_float(enemy_id, "emergency_failsafe_distance", 1000.0)
	if distance_from_spawn > emergency_failsafe_distance:
		# Failsafe only: normal leash return is smooth and should not snap.
		print("Enemy %s emergency leash failsafe snap from distance %s." % [enemy_id, distance_from_spawn])
		return _emergency_leash_snap(enemy_id, spawn_position)

	_regenerate_enemy_while_returning(enemy_id, delta)
	var reset_distance: float = _enemy_definition_float(enemy_id, "leash_reset_distance", 0.75)
	var offset_xz: Vector2 = Vector2(spawn_position.x - enemy_position.x, spawn_position.z - enemy_position.z)
	if offset_xz.length() <= reset_distance:
		_log_return_update(enemy_id, enemy_position, spawn_position, distance_from_spawn, delta, 0.0)
		return _finish_leash_reset(enemy_id, enemy_position)

	var return_speed: float = _return_speed(enemy_id)
	var direction_to_spawn: Vector3 = Vector3(offset_xz.x, 0.0, offset_xz.y).normalized()
	var movement_step: Vector3 = direction_to_spawn * return_speed * delta
	var step_distance: float = min(movement_step.length(), offset_xz.length())
	_log_return_update(enemy_id, enemy_position, spawn_position, distance_from_spawn, delta, step_distance)
	return enemy_position + direction_to_spawn * step_distance


func _finish_leash_reset(enemy_id: int, enemy_position: Vector3) -> Vector3:
	_returning_enemy_ids.erase(enemy_id)
	_forced_aggro_peer_by_enemy.erase(enemy_id)
	_forced_aggro_until_by_enemy.erase(enemy_id)
	_proximity_aggro_peer_by_enemy.erase(enemy_id)
	_proximity_aggro_until_by_enemy.erase(enemy_id)
	_enemy_return_regen_progress.erase(enemy_id)
	_enemy_return_log_last_seconds.erase(enemy_id)
	_enemy_origin_positions[enemy_id] = enemy_position
	var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, _max_hp_for_enemy(enemy_id)))
	# Full leash reset restores HP so a pulled enemy returns to its spawn state.
	_enemy_current_hp_by_id[enemy_id] = max_hp
	_resume_patrol_near_position(enemy_id, enemy_position)
	rpc("show_enemy_hit", enemy_id, max_hp, max_hp)
	return enemy_position


func _emergency_leash_snap(enemy_id: int, spawn_position: Vector3) -> Vector3:
	_returning_enemy_ids.erase(enemy_id)
	_forced_aggro_peer_by_enemy.erase(enemy_id)
	_forced_aggro_until_by_enemy.erase(enemy_id)
	_proximity_aggro_peer_by_enemy.erase(enemy_id)
	_proximity_aggro_until_by_enemy.erase(enemy_id)
	_enemy_return_regen_progress.erase(enemy_id)
	_enemy_return_log_last_seconds.erase(enemy_id)
	var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, _max_hp_for_enemy(enemy_id)))
	_enemy_current_hp_by_id[enemy_id] = max_hp
	_resume_patrol_near_position(enemy_id, spawn_position)
	rpc("show_enemy_hit", enemy_id, max_hp, max_hp)
	return spawn_position


func _regenerate_enemy_while_returning(enemy_id: int, delta: float) -> void:
	var regen_per_second: float = _enemy_definition_float(enemy_id, "return_regen_per_second", 8.0)
	if regen_per_second <= 0.0:
		return

	var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, _max_hp_for_enemy(enemy_id)))
	var current_hp: int = int(_enemy_current_hp_by_id.get(enemy_id, max_hp))
	if current_hp >= max_hp:
		_enemy_return_regen_progress.erase(enemy_id)
		return

	var pending_regen: float = float(_enemy_return_regen_progress.get(enemy_id, 0.0)) + regen_per_second * delta
	var healed_amount: int = int(floor(pending_regen))
	if healed_amount <= 0:
		_enemy_return_regen_progress[enemy_id] = pending_regen
		return

	_enemy_return_regen_progress[enemy_id] = pending_regen - float(healed_amount)
	_enemy_current_hp_by_id[enemy_id] = min(max_hp, current_hp + healed_amount)


func _is_enemy_beyond_emergency_failsafe(enemy_id: int) -> bool:
	if not enemies.has(enemy_id):
		return false
	var enemy_position: Vector3 = enemies[enemy_id] as Vector3
	var spawn_position: Vector3 = _enemy_spawn_points.get(enemy_id, enemy_position) as Vector3
	var emergency_failsafe_distance: float = _enemy_definition_float(enemy_id, "emergency_failsafe_distance", 1000.0)
	return _distance_xz(enemy_position, spawn_position) > emergency_failsafe_distance


func _distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _log_server_enemy_snap(enemy_id: int, fallback_previous_position: Vector3, new_position: Vector3, delta: float, behavior: String, target_peer_id: int) -> void:
	if not debug_enemy_snap_logs:
		_enemy_previous_authoritative_positions[enemy_id] = new_position
		return

	var previous_position: Vector3 = fallback_previous_position
	if _enemy_previous_authoritative_positions.has(enemy_id):
		previous_position = _enemy_previous_authoritative_positions[enemy_id] as Vector3

	_enemy_previous_authoritative_positions[enemy_id] = new_position
	var distance_moved: float = previous_position.distance_to(new_position)
	if distance_moved <= enemy_snap_log_threshold:
		return

	print("Server enemy snap: enemy_id=%s previous_position=%s new_position=%s distance_moved=%s behavior=%s target_peer=%s returning=%s leashing=%s dead=%s respawning=%s delta=%s" % [
		enemy_id,
		previous_position,
		new_position,
		distance_moved,
		behavior,
		target_peer_id,
		_returning_enemy_ids.has(enemy_id),
		_returning_enemy_ids.has(enemy_id),
		_dead_enemy_ids.has(enemy_id),
		_dead_enemy_ids.has(enemy_id),
		delta,
	])


func _log_return_update(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, distance_from_spawn: float, delta: float, step_distance: float) -> void:
	if not debug_enemy_return_logs:
		return

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var last_log_seconds: float = float(_enemy_return_log_last_seconds.get(enemy_id, -999.0))
	if now_seconds - last_log_seconds < 1.0:
		return

	_enemy_return_log_last_seconds[enemy_id] = now_seconds
	var chase_speed: float = _enemy_definition_float(enemy_id, "move_speed", 2.2)
	var return_speed_multiplier: float = _enemy_definition_float(enemy_id, "return_speed_multiplier", 0.75)
	print("Enemy %s return update: current_position=%s spawn_position=%s distance_to_spawn=%s chase_speed=%s return_speed_multiplier=%s return_speed=%s delta=%s step_length=%s" % [
		enemy_id,
		enemy_position,
		spawn_position,
		distance_from_spawn,
		chase_speed,
		return_speed_multiplier,
		_return_speed(enemy_id),
		delta,
		step_distance,
	])


func _return_speed(enemy_id: int) -> float:
	var chase_speed: float = _enemy_definition_float(enemy_id, "move_speed", 2.2)
	var return_speed_multiplier: float = _enemy_definition_float(enemy_id, "return_speed_multiplier", 0.75)
	return chase_speed * clamp(return_speed_multiplier, 0.01, 1.0)


func _move_toward_position(current_position: Vector3, target_position: Vector3, speed: float, delta: float) -> Vector3:
	var offset: Vector3 = target_position - current_position
	offset.y = 0.0
	if offset.length_squared() <= 0.0001:
		return current_position

	var max_step: float = max(speed, 0.0) * delta
	var distance: float = offset.length()
	if distance <= max_step:
		return Vector3(target_position.x, current_position.y, target_position.z)

	return current_position + offset.normalized() * max_step


func _chase_position(enemy_id: int, enemy_position: Vector3, target_position: Vector3, delta: float) -> Vector3:
	var offset: Vector3 = target_position - enemy_position
	offset.y = 0.0
	if offset.length_squared() <= 0.0001:
		return enemy_position

	var chase_speed: float = _enemy_definition_float(enemy_id, "move_speed", 2.2)
	var max_step: float = chase_speed * delta
	var distance: float = offset.length()
	if max_step > SUSPICIOUS_MOVEMENT_STEP:
		_log_suspicious_movement_step(enemy_id, chase_speed, delta, max_step, distance)
	if distance <= max_step:
		return Vector3(target_position.x, enemy_position.y, target_position.z)

	return enemy_position + offset.normalized() * max_step


func _profile_idle_position(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, delta: float) -> Vector3:
	var behavior_profile_key: String = _enemy_behavior_profile_key(enemy_id)
	if behavior_profile_key == BEHAVIOR_PROFILE_STATIONARY:
		if _distance_xz(enemy_position, spawn_position) <= _enemy_definition_float(enemy_id, "leash_reset_distance", 0.75):
			return enemy_position
		return _move_toward_position(enemy_position, spawn_position, _enemy_definition_float(enemy_id, "idle_move_speed", 0.8), delta)
	if behavior_profile_key == BEHAVIOR_PROFILE_PATROL and _enemy_has_valid_patrol(enemy_id):
		return _patrol_idle_position(enemy_id, enemy_position, delta)

	var origin_position: Vector3 = _enemy_origin_positions[enemy_id] as Vector3
	var profile_idle_radius: float = idle_radius
	if behavior_profile_key == BEHAVIOR_PROFILE_RANGED_GUARD:
		profile_idle_radius = min(idle_radius, max(_profile_aggro_radius(enemy_id) * 0.25, 0.75))
	elif behavior_profile_key == BEHAVIOR_PROFILE_AGGRESSIVE:
		profile_idle_radius = idle_radius * 1.25
	var angle: float = _idle_time * idle_speed + float(enemy_id)
	var idle_target_position: Vector3 = origin_position + Vector3(cos(angle) * profile_idle_radius, 0.0, sin(angle) * profile_idle_radius)
	return _move_toward_position(enemy_position, idle_target_position, _enemy_definition_float(enemy_id, "idle_move_speed", 0.8), delta)


func _assign_patrol_path_to_enemy(enemy_id: int, spawn_definition: Dictionary) -> void:
	var behavior_profile_key: String = str(spawn_definition.get("behavior_profile_key", DEFAULT_BEHAVIOR_PROFILE_KEY)).strip_edges().to_lower()
	var patrol_path_key: String = str(spawn_definition.get("patrol_path_key", "")).strip_edges()
	if behavior_profile_key != BEHAVIOR_PROFILE_PATROL:
		return
	if patrol_path_key == "":
		print("Warning: patrol enemy missing patrol_path_key; falling back to wander. enemy_id=%s spawn_key=%s." % [enemy_id, str(spawn_definition.get("spawn_key", ""))])
		return
	if not _server_region_patrol_paths_by_key.has(patrol_path_key):
		print("Warning: patrol path not found; falling back to wander. enemy_id=%s patrol_path_key=%s." % [enemy_id, patrol_path_key])
		return

	var patrol_path: Dictionary = _server_region_patrol_paths_by_key[patrol_path_key] as Dictionary
	var points: Array = patrol_path.get("points", []) as Array
	if points.size() < 2:
		print("Warning: patrol path invalid; falling back to wander. enemy_id=%s patrol_path_key=%s point_count=%s." % [enemy_id, patrol_path_key, points.size()])
		return

	_enemy_patrol_path_key_by_id[enemy_id] = patrol_path_key
	_enemy_patrol_points_by_id[enemy_id] = points.duplicate(true)
	_resume_patrol_near_position(enemy_id, enemies.get(enemy_id, Vector3.ZERO) as Vector3)
	print("Enemy patrol assigned: enemy_id=%s patrol_path_key=%s point_count=%s." % [enemy_id, patrol_path_key, points.size()])


func _enemy_has_valid_patrol(enemy_id: int) -> bool:
	if not _enemy_patrol_points_by_id.has(enemy_id):
		return false

	var points: Array = _enemy_patrol_points_by_id[enemy_id] as Array
	return points.size() >= 2


func _patrol_idle_position(enemy_id: int, enemy_position: Vector3, delta: float) -> Vector3:
	var points: Array = _enemy_patrol_points_by_id[enemy_id] as Array
	if points.size() < 2:
		return enemy_position

	var point_index: int = int(_enemy_patrol_point_index_by_id.get(enemy_id, 0))
	point_index = clampi(point_index, 0, points.size() - 1)
	var patrol_point: Dictionary = points[point_index] as Dictionary
	var target_position: Vector3 = patrol_point.get("position", enemy_position) as Vector3
	var arrive_distance: float = max(_enemy_definition_float(enemy_id, "leash_reset_distance", 0.75), 0.1)
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0

	if _distance_xz(enemy_position, target_position) <= arrive_distance:
		if not _enemy_patrol_wait_until_by_id.has(enemy_id):
			var wait_seconds: float = max(float(patrol_point.get("wait_seconds", 0.0)), 0.0)
			if wait_seconds > 0.0:
				_enemy_patrol_wait_until_by_id[enemy_id] = now_seconds + wait_seconds
				return enemy_position
		elif now_seconds < float(_enemy_patrol_wait_until_by_id.get(enemy_id, 0.0)):
			return enemy_position

		_enemy_patrol_wait_until_by_id.erase(enemy_id)
		_enemy_patrol_point_index_by_id[enemy_id] = (point_index + 1) % points.size()
		return enemy_position

	return _move_toward_position(enemy_position, target_position, _enemy_definition_float(enemy_id, "idle_move_speed", 0.8), delta)


func _resume_patrol_near_position(enemy_id: int, position: Vector3) -> void:
	if not _enemy_has_valid_patrol(enemy_id):
		return

	var points: Array = _enemy_patrol_points_by_id[enemy_id] as Array
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for index in range(points.size()):
		var patrol_point: Dictionary = points[index] as Dictionary
		var point_position: Vector3 = patrol_point.get("position", position) as Vector3
		var distance: float = _distance_xz(position, point_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	_enemy_patrol_point_index_by_id[enemy_id] = nearest_index
	_enemy_patrol_wait_until_by_id.erase(enemy_id)


func _profile_aggro_radius(enemy_id: int) -> float:
	var aggro_radius: float = _enemy_definition_float(enemy_id, "aggro_radius", 8.0)
	if _enemy_behavior_profile_key(enemy_id) == BEHAVIOR_PROFILE_AGGRESSIVE:
		return aggro_radius * 1.35
	return aggro_radius


func _profile_forced_aggro_seconds(enemy_id: int) -> float:
	var aggro_seconds: float = _enemy_definition_float(enemy_id, "forced_aggro_seconds", 16.0)
	if _enemy_behavior_profile_key(enemy_id) == BEHAVIOR_PROFILE_AGGRESSIVE:
		return aggro_seconds * 1.25
	return aggro_seconds


func _profile_proximity_aggro_seconds(enemy_id: int) -> float:
	var aggro_seconds: float = _enemy_definition_float(enemy_id, "proximity_aggro_seconds", 11.0)
	if _enemy_behavior_profile_key(enemy_id) == BEHAVIOR_PROFILE_AGGRESSIVE:
		return aggro_seconds * 1.25
	return aggro_seconds


func _profile_home_return_distance(enemy_id: int) -> float:
	var home_return_distance: float = _enemy_definition_float(enemy_id, "home_return_distance", 70.0)
	var aggro_radius: float = _profile_aggro_radius(enemy_id)
	var behavior_profile_key: String = _enemy_behavior_profile_key(enemy_id)
	if behavior_profile_key == BEHAVIOR_PROFILE_STATIONARY:
		return min(home_return_distance, max(aggro_radius * 1.25, 4.0))
	if behavior_profile_key == BEHAVIOR_PROFILE_RANGED_GUARD:
		var ranged_range: float = _enemy_definition_float(enemy_id, "ranged_attack_range", aggro_radius)
		return min(home_return_distance, max(ranged_range + 3.0, aggro_radius))
	if behavior_profile_key == BEHAVIOR_PROFILE_AGGRESSIVE:
		return home_return_distance * 1.3
	return home_return_distance


func _profile_target_drop_distance(enemy_id: int) -> float:
	var target_drop_distance: float = _enemy_definition_float(enemy_id, "target_drop_distance", 65.0)
	var aggro_radius: float = _profile_aggro_radius(enemy_id)
	var behavior_profile_key: String = _enemy_behavior_profile_key(enemy_id)
	if behavior_profile_key == BEHAVIOR_PROFILE_STATIONARY:
		return min(target_drop_distance, max(aggro_radius * 1.5, 5.0))
	if behavior_profile_key == BEHAVIOR_PROFILE_RANGED_GUARD:
		var ranged_range: float = _enemy_definition_float(enemy_id, "ranged_attack_range", aggro_radius)
		return min(target_drop_distance, max(ranged_range + 4.0, aggro_radius * 1.25))
	if behavior_profile_key == BEHAVIOR_PROFILE_AGGRESSIVE:
		return target_drop_distance * 1.35
	return target_drop_distance


func _profile_hard_return_distance(enemy_id: int) -> float:
	var hard_return_distance: float = _enemy_definition_float(enemy_id, "hard_return_distance", 160.0)
	var aggro_radius: float = _profile_aggro_radius(enemy_id)
	var behavior_profile_key: String = _enemy_behavior_profile_key(enemy_id)
	if behavior_profile_key == BEHAVIOR_PROFILE_STATIONARY:
		return min(hard_return_distance, max(aggro_radius * 2.0, 8.0))
	if behavior_profile_key == BEHAVIOR_PROFILE_RANGED_GUARD:
		var ranged_range: float = _enemy_definition_float(enemy_id, "ranged_attack_range", aggro_radius)
		return min(hard_return_distance, max(ranged_range + 6.0, aggro_radius * 1.5))
	if behavior_profile_key == BEHAVIOR_PROFILE_AGGRESSIVE:
		return hard_return_distance * 1.35
	return hard_return_distance


func _enemy_behavior_profile_key(enemy_id: int) -> String:
	var profile_key: String = str(_enemy_definition_for_enemy(enemy_id).get("behavior_profile_key", DEFAULT_BEHAVIOR_PROFILE_KEY)).strip_edges().to_lower()
	if SUPPORTED_BEHAVIOR_PROFILE_KEYS.has(profile_key):
		return profile_key
	return DEFAULT_BEHAVIOR_PROFILE_KEY


func _log_suspicious_movement_step(enemy_id: int, chase_speed: float, delta: float, max_step: float, distance_to_target: float) -> void:
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var last_log_seconds: float = float(_enemy_suspicious_movement_log_last_seconds.get(enemy_id, -999.0))
	if now_seconds - last_log_seconds < 2.0:
		return

	_enemy_suspicious_movement_log_last_seconds[enemy_id] = now_seconds
	print("Warning: enemy %s suspicious movement step. enemy_key=%s chase_speed=%s delta=%s step=%s distance_to_target=%s." % [
		enemy_id,
		_enemy_type_for_enemy(enemy_id),
		chase_speed,
		delta,
		max_step,
		distance_to_target,
	])


func _enemy_definition_float(enemy_id: int, key: String, fallback: float) -> float:
	return float(_enemy_definition_for_enemy(enemy_id).get(key, fallback))


func _enemy_definition_int(enemy_id: int, key: String, fallback: int) -> int:
	return int(_enemy_definition_for_enemy(enemy_id).get(key, fallback))


func _enemy_definition_bool(enemy_id: int, key: String, fallback: bool) -> bool:
	return bool(_enemy_definition_for_enemy(enemy_id).get(key, fallback))


func _enemy_can_use_ranged_attack(enemy_id: int) -> bool:
	if _enemy_attack_type(enemy_id) == "ranged":
		return true
	return _enemy_behavior_profile_key(enemy_id) == BEHAVIOR_PROFILE_RANGED_GUARD and _enemy_definition_bool(enemy_id, "ranged_attack_enabled", false)


func _enemy_attack_type(enemy_id: int) -> String:
	return str(_enemy_definition_for_enemy(enemy_id).get("attack_type", "melee"))


func _enemy_definition_for_enemy(enemy_id: int) -> Dictionary:
	var definition: Dictionary = _enemy_definition_for_type(_enemy_type_for_enemy(enemy_id)).duplicate(true)
	if _enemy_definition_overrides_by_id.has(enemy_id):
		var overrides: Dictionary = _enemy_definition_overrides_by_id[enemy_id] as Dictionary
		for key in overrides:
			definition[key] = overrides[key]
	return definition


func _enemy_definition_for_type(enemy_type: String) -> Dictionary:
	var definitions: Dictionary = _active_enemy_definitions()
	return definitions.get(_resolved_enemy_type(enemy_type), definitions[DEFAULT_ENEMY_TYPE]) as Dictionary


func _resolved_enemy_type(enemy_type: String) -> String:
	var resolved_enemy_type: String = enemy_type.strip_edges()
	var definitions: Dictionary = _active_enemy_definitions()
	if definitions.has(resolved_enemy_type):
		return resolved_enemy_type
	return DEFAULT_ENEMY_TYPE


func _resolved_behavior_profile_key(profile_key: String, spawn_key: String, enemy_key: String) -> String:
	var resolved_profile_key: String = profile_key.strip_edges().to_lower()
	if resolved_profile_key == "":
		print("Warning: region enemy spawn missing behavior_profile_key; defaulting to wander. spawn_key=%s enemy_key=%s." % [spawn_key, enemy_key])
		return DEFAULT_BEHAVIOR_PROFILE_KEY
	if SUPPORTED_BEHAVIOR_PROFILE_KEYS.has(resolved_profile_key):
		return resolved_profile_key

	print("Warning: unknown region enemy behavior_profile_key '%s'; defaulting to wander. spawn_key=%s enemy_key=%s." % [profile_key, spawn_key, enemy_key])
	return DEFAULT_BEHAVIOR_PROFILE_KEY


func _active_enemy_definitions() -> Dictionary:
	if _server_enemy_definitions.has(DEFAULT_ENEMY_TYPE):
		return _server_enemy_definitions
	return SERVER_PROTOTYPE_ENEMY_DEFINITIONS


func _extract_backend_enemy_definition_array(data: Variant) -> Array:
	if data is Array:
		return data as Array
	if not (data is Dictionary):
		return []

	var response_data: Dictionary = data as Dictionary
	for key in ["value", "enemy_definitions", "definitions", "items", "results", "enemies"]:
		if response_data.get(key, null) is Array:
			return response_data.get(key, []) as Array
	if response_data.get("data", null) is Dictionary:
		return _extract_backend_enemy_definition_array(response_data.get("data", {}) as Dictionary)
	if _looks_like_backend_enemy_definition(response_data):
		return [response_data]
	return []


func _extract_backend_region_enemy_spawn_array(data: Variant) -> Array:
	if data is Array:
		return data as Array
	if not (data is Dictionary):
		return []

	var response_data: Dictionary = data as Dictionary
	for key in ["enemy_spawns", "spawns", "items", "results", "region_enemy_spawns"]:
		if response_data.get(key, null) is Array:
			return response_data.get(key, []) as Array
	if response_data.get("data", null) is Dictionary:
		return _extract_backend_region_enemy_spawn_array(response_data.get("data", {}) as Dictionary)
	return []


func _extract_backend_region_patrol_path_array(data: Variant) -> Array:
	if data is Array:
		return data as Array
	if not (data is Dictionary):
		return []

	var response_data: Dictionary = data as Dictionary
	for key in ["patrol_paths", "paths", "items", "results", "region_patrol_paths"]:
		if response_data.get(key, null) is Array:
			return response_data.get(key, []) as Array
	if response_data.get("data", null) is Dictionary:
		return _extract_backend_region_patrol_path_array(response_data.get("data", {}) as Dictionary)
	return []


func _normalize_backend_region_patrol_path(source: Dictionary) -> Dictionary:
	var patrol_path_key: String = str(source.get("patrol_path_key", source.get("key", source.get("id", "")))).strip_edges()
	if patrol_path_key == "":
		print("Warning: skipping backend patrol path with missing patrol_path_key.")
		return {}

	var raw_points: Array = []
	if source.get("points", null) is Array:
		raw_points = source.get("points", []) as Array
	elif source.get("patrol_points", null) is Array:
		raw_points = source.get("patrol_points", []) as Array
	elif source.get("region_patrol_points", null) is Array:
		raw_points = source.get("region_patrol_points", []) as Array

	var points: Array = []
	for point_variant in raw_points:
		if not (point_variant is Dictionary):
			continue

		var point: Dictionary = _normalize_backend_region_patrol_point(point_variant as Dictionary)
		if point.is_empty():
			continue

		points.append(point)

	points.sort_custom(Callable(self, "_sort_patrol_points_by_order"))
	if points.size() < 2:
		print("Warning: backend patrol path '%s' has fewer than 2 usable points." % patrol_path_key)
		return {}

	return {
		"patrol_path_key": patrol_path_key,
		"points": points,
	}


func _normalize_backend_region_patrol_point(source: Dictionary) -> Dictionary:
	var point_order: int = int(source.get("point_order", source.get("order", source.get("sort_order", source.get("index", 0)))))
	var position_x: float = _optional_float_value(source.get("position_x", source.get("x", 0.0)), "position_x", 0.0)
	var position_y: float = _optional_float_value(source.get("position_y", source.get("y", 0.0)), "position_y", 0.0)
	var position_z: float = _optional_float_value(source.get("position_z", source.get("z", 0.0)), "position_z", 0.0)
	return {
		"point_order": point_order,
		"position": Vector3(position_x, position_y, position_z),
		"wait_seconds": max(_optional_float_value(source.get("wait_seconds", 0.0), "wait_seconds", 0.0), 0.0),
	}


func _sort_patrol_points_by_order(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("point_order", 0)) < int(b.get("point_order", 0))


func _normalize_backend_region_enemy_spawn(source: Dictionary) -> Dictionary:
	var spawn_key: String = str(source.get("spawn_key", source.get("key", source.get("id", "")))).strip_edges()
	var enemy_type: String = str(source.get("enemy_key", source.get("enemy_type", source.get("enemy_definition_key", "")))).strip_edges()
	if enemy_type == "":
		print("Skipping backend region enemy spawn with missing enemy_key: %s" % source)
		return {}

	var position_x: float = _optional_float_value(source.get("position_x", source.get("x", 0.0)), "position_x", 0.0)
	var position_y: float = _optional_float_value(source.get("position_y", source.get("y", 0.0)), "position_y", 0.0)
	var position_z: float = _optional_float_value(source.get("position_z", source.get("z", 0.0)), "position_z", 0.0)
	var spawn_radius: float = max(_optional_float_value(source.get("spawn_radius", 0.0), "spawn_radius", 0.0), 0.0)
	var respawn_seconds: float = max(_optional_float_value(source.get("respawn_seconds", respawn_delay_seconds), "respawn_seconds", respawn_delay_seconds), 0.0)
	var behavior_profile_key: String = _resolved_behavior_profile_key(str(source.get("behavior_profile_key", "")).strip_edges(), spawn_key, enemy_type)
	var patrol_path_key: String = str(source.get("patrol_path_key", "")).strip_edges()
	var definition_overrides: Dictionary = _backend_region_spawn_definition_overrides(source)
	definition_overrides["behavior_profile_key"] = behavior_profile_key
	var position: Vector3 = Vector3(
		position_x,
		position_y,
		position_z
	)
	var spawn_definition: Dictionary = {
		"spawn_key": spawn_key,
		"enemy_type": enemy_type,
		"position": position,
		"spawn_radius": spawn_radius,
		"max_alive": max(int(source.get("max_alive", 1)), 1),
		"respawn_seconds": respawn_seconds,
		"behavior_profile_key": behavior_profile_key,
		"patrol_path_key": patrol_path_key,
		"definition_overrides": definition_overrides,
	}
	return spawn_definition


func _backend_region_spawn_definition_overrides(source: Dictionary) -> Dictionary:
	var overrides: Dictionary = {}
	_copy_float_definition_value(source, overrides, "aggro_radius", ["aggro_radius", "aggro_radius_override", "override_aggro_radius"])
	_copy_float_definition_value(source, overrides, "forced_aggro_seconds", ["forced_aggro_seconds", "forced_aggro_seconds_override", "override_forced_aggro_seconds"])
	_copy_float_definition_value(source, overrides, "proximity_aggro_seconds", ["proximity_aggro_seconds", "proximity_aggro_seconds_override", "override_proximity_aggro_seconds"])
	_copy_float_definition_value(source, overrides, "home_return_distance", ["home_return_distance", "leash_distance", "leash_radius", "home_return_distance_override", "override_home_return_distance"])
	_copy_float_definition_value(source, overrides, "target_drop_distance", ["target_drop_distance", "target_drop_distance_override", "override_target_drop_distance"])
	_copy_float_definition_value(source, overrides, "hard_return_distance", ["hard_return_distance", "hard_return_distance_override", "override_hard_return_distance"])
	_copy_float_definition_value(source, overrides, "emergency_failsafe_distance", ["emergency_failsafe_distance", "emergency_failsafe_distance_override", "override_emergency_failsafe_distance"])
	_copy_float_definition_value(source, overrides, "leash_reset_distance", ["leash_reset_distance", "leash_reset_distance_override", "override_leash_reset_distance"])
	_copy_float_definition_value(source, overrides, "idle_return_distance", ["idle_return_distance", "idle_return_distance_override", "override_idle_return_distance"])
	return overrides


func _spawn_position_for_index(center_position: Vector3, spawn_radius: float, spawn_index: int, spawn_count: int) -> Vector3:
	if spawn_radius <= 0.0 or spawn_count <= 1:
		return center_position

	var angle: float = (TAU * float(spawn_index)) / float(spawn_count)
	return center_position + Vector3(cos(angle) * spawn_radius, 0.0, sin(angle) * spawn_radius)


func _normalize_backend_enemy_definition(source: Dictionary) -> Dictionary:
	if source.has("is_active") and not bool(source.get("is_active", true)):
		return {}

	var enemy_type: String = str(source.get("enemy_key", source.get("enemy_type", source.get("key", source.get("type", source.get("id", "")))))).strip_edges()
	if enemy_type == "":
		return {}

	var fallback_type: String = enemy_type if SERVER_PROTOTYPE_ENEMY_DEFINITIONS.has(enemy_type) else DEFAULT_ENEMY_TYPE
	var definition: Dictionary = (SERVER_PROTOTYPE_ENEMY_DEFINITIONS[fallback_type] as Dictionary).duplicate(true)
	definition["enemy_type"] = enemy_type
	definition["backend_loaded"] = true
	_copy_string_definition_value(source, definition, "display_name", ["display_name", "name"])
	_copy_string_definition_value(source, definition, "behavior_profile_key", ["behavior_profile_key"])
	_copy_string_definition_value(source, definition, "visual_key", ["visual_key"])
	_copy_int_definition_value(source, definition, "level", ["level"])
	_copy_int_definition_value(source, definition, "xp_reward", ["xp_reward", "xp", "experience_reward"])
	_copy_int_definition_value(source, definition, "max_hp", ["max_hp", "max_health", "hp"])
	_copy_float_definition_value(source, definition, "move_speed", ["move_speed", "movement_speed", "speed"])

	for key in [
		"aggro_radius",
		"forced_aggro_seconds",
		"proximity_aggro_seconds",
	]:
		_copy_float_definition_value(source, definition, key, [key])
	_copy_float_definition_value(source, definition, "home_return_distance", ["home_return_distance", "leash_radius"])
	_copy_float_definition_value(source, definition, "target_drop_distance", ["target_drop_distance", "leash_radius"])
	for key in [
		"hard_return_distance",
		"emergency_failsafe_distance",
		"leash_reset_distance",
		"idle_return_distance",
		"idle_move_speed",
		"return_speed_multiplier",
		"return_regen_per_second",
	]:
		_copy_float_definition_value(source, definition, key, [key])

	_copy_int_definition_value(source, definition, "contact_damage", ["contact_damage"])
	_copy_string_definition_value(source, definition, "attack_type", ["attack_type"])
	_copy_backend_attack_fields(source, definition)
	_apply_backend_attack_type_defaults(definition)
	_normalize_backend_definition_tuning(definition, source)
	_log_backend_enemy_definition_tuning(definition)
	definition["loot_table_entries"] = _extract_backend_loot_table_entries(source)
	return definition


func _apply_backend_attack_type_defaults(definition: Dictionary) -> void:
	var attack_type: String = str(definition.get("attack_type", "melee")).strip_edges().to_lower()
	if attack_type == "ranged":
		definition["attack_type"] = "ranged"
		definition["ranged_attack_enabled"] = bool(definition.get("ranged_attack_enabled", true))
		definition["melee_attack_enabled"] = bool(definition.get("melee_attack_enabled", false))
		return

	definition["attack_type"] = "melee"
	definition["melee_attack_enabled"] = bool(definition.get("melee_attack_enabled", true))


func _copy_backend_attack_fields(source: Dictionary, definition: Dictionary) -> void:
	var attacks: Array = []
	if source.get("enemy_attacks", null) is Array:
		attacks = source.get("enemy_attacks", []) as Array
	elif source.get("attacks", null) is Array:
		attacks = source.get("attacks", []) as Array
	elif source.get("attack", null) is Dictionary:
		attacks = [source.get("attack", {}) as Dictionary]

	for attack_variant in attacks:
		if not (attack_variant is Dictionary):
			continue

		var attack: Dictionary = attack_variant as Dictionary
		var attack_type: String = str(attack.get("attack_type", attack.get("type", ""))).strip_edges().to_lower()
		if attack_type.contains("melee"):
			attack_type = "melee"
		elif attack_type.contains("ranged") or attack_type.contains("projectile"):
			attack_type = "ranged"
		if attack_type == "melee":
			definition["attack_type"] = "melee"
			definition["melee_attack_enabled"] = true
			_copy_string_definition_value(attack, definition, "melee_attack_key", ["attack_key", "key", "id", "slug", "melee_attack_key"])
			_copy_int_definition_value(attack, definition, "melee_attack_damage", ["damage", "damage_amount", "attack_damage", "melee_attack_damage"])
			_copy_float_definition_value(attack, definition, "melee_attack_range", ["range", "max_range", "range_radius", "attack_range", "melee_attack_range"])
			_copy_float_definition_value(attack, definition, "melee_attack_radius", ["radius", "attack_radius", "hit_radius", "impact_radius", "effect_radius", "melee_attack_radius"])
			_copy_float_definition_value(attack, definition, "melee_attack_windup_seconds", ["windup_seconds", "windup", "melee_attack_windup_seconds"])
			_copy_float_definition_value(attack, definition, "melee_attack_recovery_seconds", ["recovery_seconds", "recovery", "melee_attack_recovery_seconds"])
			_copy_float_definition_value(attack, definition, "melee_attack_cooldown_seconds", ["cooldown_seconds", "cooldown", "melee_attack_cooldown_seconds"])
		elif attack_type == "ranged":
			definition["attack_type"] = "ranged"
			definition["ranged_attack_enabled"] = true
			definition["melee_attack_enabled"] = false
			_copy_string_definition_value(attack, definition, "ranged_attack_key", ["attack_key", "key", "id", "slug", "ranged_attack_key"])
			_copy_int_definition_value(attack, definition, "ranged_attack_damage", ["damage", "damage_amount", "attack_damage", "ranged_attack_damage"])
			_copy_float_definition_value(attack, definition, "ranged_attack_range", ["range", "max_range", "range_radius", "attack_range", "ranged_attack_range"])
			_copy_float_definition_value(attack, definition, "ranged_attack_preferred_distance", ["preferred_distance", "ranged_attack_preferred_distance"])
			_copy_float_definition_value(attack, definition, "ranged_attack_windup_seconds", ["windup_seconds", "windup", "ranged_attack_windup_seconds"])
			_copy_float_definition_value(attack, definition, "ranged_attack_recovery_seconds", ["recovery_seconds", "recovery", "ranged_attack_recovery_seconds"])
			_copy_float_definition_value(attack, definition, "ranged_attack_cooldown_seconds", ["cooldown_seconds", "cooldown", "ranged_attack_cooldown_seconds"])
			_copy_float_definition_value(attack, definition, "ranged_attack_width", ["width", "radius", "attack_radius", "projectile_width", "ranged_attack_width"])

	for key in [
		"melee_attack_damage",
		"ranged_attack_damage",
	]:
		_copy_int_definition_value(source, definition, key, [key])
	for key in [
		"melee_attack_range",
		"melee_attack_radius",
		"melee_attack_windup_seconds",
		"melee_attack_recovery_seconds",
		"melee_attack_cooldown_seconds",
		"ranged_attack_range",
		"ranged_attack_preferred_distance",
		"ranged_attack_windup_seconds",
		"ranged_attack_recovery_seconds",
		"ranged_attack_cooldown_seconds",
		"ranged_attack_width",
	]:
		_copy_float_definition_value(source, definition, key, [key])
	for key in ["melee_attack_enabled", "ranged_attack_enabled"]:
		_copy_bool_definition_value(source, definition, key, [key])


func _normalize_backend_definition_tuning(definition: Dictionary, source: Dictionary) -> void:
	var enemy_type: String = str(definition.get("enemy_type", DEFAULT_ENEMY_TYPE))

	var attack_type: String = str(definition.get("attack_type", "melee"))
	if attack_type == "melee":
		_warn_if_missing_or_zero_attack_value(definition, source, enemy_type, "melee_attack_range", ["range", "max_range", "range_radius", "attack_range", "melee_attack_range"])
		_warn_if_missing_or_zero_attack_value(definition, source, enemy_type, "melee_attack_radius", ["radius", "attack_radius", "hit_radius", "impact_radius", "effect_radius", "melee_attack_radius"])
	elif attack_type == "ranged":
		_warn_if_missing_or_zero_attack_value(definition, source, enemy_type, "ranged_attack_range", ["range", "max_range", "range_radius", "attack_range", "ranged_attack_range"])
		_warn_if_missing_or_zero_attack_value(definition, source, enemy_type, "ranged_attack_width", ["width", "radius", "attack_radius", "projectile_width", "ranged_attack_width"])


func _warn_if_missing_or_zero_attack_value(definition: Dictionary, source: Dictionary, enemy_type: String, key: String, source_keys: Array) -> void:
	if not definition.has(key) or not _backend_has_any_attack_key(source, source_keys):
		print("Warning: backend enemy '%s' missing %s; prototype default may be used." % [enemy_type, key])
		return

	if float(definition.get(key, 0.0)) <= 0.0:
		print("Warning: backend enemy '%s' has zero %s." % [enemy_type, key])


func _backend_has_any_key(source: Dictionary, keys: Array) -> bool:
	for key in keys:
		if source.has(key):
			return true
	return false


func _backend_has_any_attack_key(source: Dictionary, keys: Array) -> bool:
	if _backend_has_any_key(source, keys):
		return true

	var attacks: Array = []
	if source.get("enemy_attacks", null) is Array:
		attacks = source.get("enemy_attacks", []) as Array
	elif source.get("attacks", null) is Array:
		attacks = source.get("attacks", []) as Array
	elif source.get("attack", null) is Dictionary:
		attacks = [source.get("attack", {}) as Dictionary]

	for attack_variant in attacks:
		if not (attack_variant is Dictionary):
			continue
		if _backend_has_any_key(attack_variant as Dictionary, keys):
			return true
	return false


func _log_backend_enemy_definition_tuning(definition: Dictionary) -> void:
	var enemy_type: String = str(definition.get("enemy_type", DEFAULT_ENEMY_TYPE))
	var attack_type: String = str(definition.get("attack_type", "melee"))
	var attack_range: float = _definition_attack_range(definition)
	var attack_radius: float = _definition_attack_radius(definition)
	var windup: float = _definition_attack_windup(definition)
	var recovery: float = _definition_attack_recovery(definition)
	var cooldown: float = _definition_attack_cooldown(definition)
	print("Backend enemy definition tuning: enemy_key=%s move_speed=%s attack_type=%s attack_range=%s attack_radius=%s windup=%s recovery=%s cooldown=%s aggro_radius=%s leash_radius=%s behavior_profile_key=%s." % [
		enemy_type,
		float(definition.get("move_speed", 0.0)),
		attack_type,
		attack_range,
		attack_radius,
		windup,
		recovery,
		cooldown,
		float(definition.get("aggro_radius", 0.0)),
		float(definition.get("home_return_distance", 0.0)),
		str(definition.get("behavior_profile_key", "")),
	])


func _log_backend_enemy_spawn_tuning(enemy_id: int, spawn_position: Vector3) -> void:
	var definition: Dictionary = _enemy_definition_for_enemy(enemy_id)
	var spawn_key: String = str(_enemy_region_spawn_key_by_id.get(enemy_id, ""))
	if spawn_key == "" and not bool(definition.get("backend_loaded", false)):
		return

	var attack_type: String = str(definition.get("attack_type", "melee"))
	print("Backend enemy spawned: enemy_id=%s enemy_key=%s spawn_key=%s behavior_profile_key=%s patrol_path_key=%s." % [
		enemy_id,
		_enemy_type_for_enemy(enemy_id),
		spawn_key,
		_enemy_behavior_profile_key(enemy_id),
		str(_enemy_patrol_path_key_by_id.get(enemy_id, "")),
	])
	if debug_enemy_lifecycle_logs:
		print("Backend enemy spawn tuning: enemy_id=%s attack_type=%s attack_range=%s attack_radius=%s aggro_radius=%s leash_radius=%s spawn_position=%s." % [
			enemy_id,
			attack_type,
			_definition_attack_range(definition),
			_definition_attack_radius(definition),
			_profile_aggro_radius(enemy_id),
			_profile_home_return_distance(enemy_id),
			spawn_position,
		])


func _definition_attack_range(definition: Dictionary) -> float:
	if str(definition.get("attack_type", "melee")) == "ranged":
		return float(definition.get("ranged_attack_range", 0.0))
	return float(definition.get("melee_attack_range", 0.0))


func _definition_attack_radius(definition: Dictionary) -> float:
	if str(definition.get("attack_type", "melee")) == "ranged":
		return float(definition.get("ranged_attack_width", 0.0))
	return float(definition.get("melee_attack_radius", 0.0))


func _definition_attack_windup(definition: Dictionary) -> float:
	if str(definition.get("attack_type", "melee")) == "ranged":
		return float(definition.get("ranged_attack_windup_seconds", 0.0))
	return float(definition.get("melee_attack_windup_seconds", 0.0))


func _definition_attack_recovery(definition: Dictionary) -> float:
	if str(definition.get("attack_type", "melee")) == "ranged":
		return float(definition.get("ranged_attack_recovery_seconds", 0.0))
	return float(definition.get("melee_attack_recovery_seconds", 0.0))


func _definition_attack_cooldown(definition: Dictionary) -> float:
	if str(definition.get("attack_type", "melee")) == "ranged":
		var ranged_cooldown: float = float(definition.get("ranged_attack_cooldown_seconds", DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS))
		if ranged_cooldown <= 0.0:
			return DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS
		return ranged_cooldown

	var melee_cooldown: float = float(definition.get("melee_attack_cooldown_seconds", DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS))
	if melee_cooldown <= 0.0:
		return DEFAULT_ENEMY_ATTACK_COOLDOWN_SECONDS
	return melee_cooldown


func _extract_backend_loot_table_entries(source: Dictionary) -> Array:
	for key in ["loot_table_entries", "loot_entries", "loot_table", "loot"]:
		if source.get(key, null) is Array:
			return (source.get(key, []) as Array).duplicate(true)
	return []


func _looks_like_backend_enemy_definition(source: Dictionary) -> bool:
	for key in ["enemy_key", "enemy_type", "max_hp", "xp_reward", "enemy_attacks", "attacks", "loot_entries"]:
		if source.has(key):
			return true
	return false


func _copy_string_definition_value(source: Dictionary, target: Dictionary, target_key: String, source_keys: Array) -> void:
	for source_key in source_keys:
		if not source.has(source_key):
			continue

		var value: String = str(source.get(source_key, "")).strip_edges()
		if value != "":
			target[target_key] = value
			return


func _copy_int_definition_value(source: Dictionary, target: Dictionary, target_key: String, source_keys: Array) -> void:
	for source_key in source_keys:
		if source.has(source_key):
			target[target_key] = int(source.get(source_key, target.get(target_key, 0)))
			return


func _copy_float_definition_value(source: Dictionary, target: Dictionary, target_key: String, source_keys: Array) -> void:
	for source_key in source_keys:
		if not source.has(source_key):
			continue

		var raw_value: Variant = source.get(source_key)
		var parsed_value: Variant = _try_parse_float_value(raw_value, source_key)
		if parsed_value == null:
			continue

		target[target_key] = parsed_value
		return


func _optional_float_value(value: Variant, source_key: String, fallback: float) -> float:
	var parsed_value: Variant = _try_parse_float_value(value, source_key)
	if parsed_value == null:
		return fallback

	return parsed_value


func _try_parse_float_value(value: Variant, source_key: String) -> Variant:
	if value == null:
		return null
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String:
		var text_value: String = (value as String).strip_edges()
		if text_value == "":
			return null
		if text_value.is_valid_float():
			return text_value.to_float()

	print("Skipping backend float field '%s': invalid value '%s'." % [source_key, str(value)])
	return null


func _copy_bool_definition_value(source: Dictionary, target: Dictionary, target_key: String, source_keys: Array) -> void:
	for source_key in source_keys:
		if source.has(source_key):
			target[target_key] = bool(source.get(source_key, target.get(target_key, false)))
			return


func _enemy_type_for_enemy(enemy_id: int) -> String:
	return _resolved_enemy_type(str(_enemy_type_by_id.get(enemy_id, DEFAULT_ENEMY_TYPE)))


func _max_hp_for_enemy(enemy_id: int) -> int:
	return _max_hp_for_type(_enemy_type_for_enemy(enemy_id))


func _max_hp_for_type(enemy_type: String) -> int:
	return int(_enemy_definition_for_type(enemy_type).get("max_hp", 30))


func _enemy_display_name(enemy_id: int) -> String:
	return str(_enemy_definition_for_enemy(enemy_id).get("display_name", "Enemy"))


func _enemy_visual_color(enemy_id: int) -> Color:
	return _enemy_definition_for_enemy(enemy_id).get("visual_color", Color(1.0, 0.18, 0.08, 1.0)) as Color


func _broadcast_enemy_position_snapshots() -> void:
	var snapshots: Array = []
	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var position: Vector3 = enemies[enemy_id] as Vector3
		snapshots.append({
			"enemy_id": enemy_id_int,
			"position": position,
		})

	if not snapshots.is_empty():
		rpc("apply_enemy_position_snapshots", snapshots)


func _smooth_spawned_enemies(delta: float) -> void:
	var weight: float = clamp(interpolation_speed * delta, 0.0, 1.0)
	for enemy_id in _spawned_enemy_nodes:
		if not _target_positions.has(enemy_id):
			continue

		var enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
		var target_position: Vector3 = _target_positions[enemy_id] as Vector3
		enemy.position = enemy.position.lerp(target_position, weight)


func _log_client_enemy_snap(enemy_id: int, previous_position: Vector3, new_position: Vector3, source: String) -> void:
	if not debug_enemy_snap_logs:
		return

	var distance_moved: float = previous_position.distance_to(new_position)
	if distance_moved <= enemy_snap_log_threshold:
		return

	print("Client enemy snap: enemy_id=%s previous_visual_position=%s new_visual_or_target_position=%s distance=%s source=%s" % [
		enemy_id,
		previous_position,
		new_position,
		distance_moved,
		source,
	])


@rpc("authority", "call_remote", "reliable")
func spawn_enemy(enemy_id: int, spawn_position: Vector3, current_hp: int = 30, max_hp: int = 30, enemy_type: String = DEFAULT_ENEMY_TYPE, display_name: String = "", visual_color: Color = Color(1.0, 0.18, 0.08, 1.0)) -> void:
	if multiplayer.is_server():
		return

	_spawn_enemy_visual(enemy_id, spawn_position, current_hp, max_hp, enemy_type, display_name, visual_color, true, "spawn_enemy")


@rpc("authority", "call_remote", "reliable")
func spawn_enemies(enemy_snapshots: Array) -> void:
	if multiplayer.is_server():
		return

	var received_count: int = 0
	for snapshot in enemy_snapshots:
		var snapshot_data: Dictionary = snapshot as Dictionary
		var enemy_id: int = int(snapshot_data.get("enemy_id", 0))
		var spawn_position: Vector3 = snapshot_data.get("position", Vector3.ZERO) as Vector3
		var enemy_type: String = str(snapshot_data.get("enemy_type", DEFAULT_ENEMY_TYPE))
		var current_hp: int = int(snapshot_data.get("current_hp", 30))
		var max_hp: int = int(snapshot_data.get("max_hp", 30))
		var display_name: String = str(snapshot_data.get("display_name", "Enemy"))
		var visual_color: Color = snapshot_data.get("visual_color", Color(1.0, 0.18, 0.08, 1.0)) as Color
		if enemy_id <= 0:
			continue

		_spawn_enemy_visual(enemy_id, spawn_position, current_hp, max_hp, enemy_type, display_name, visual_color, false, "spawn_enemies")
		received_count += 1
	if debug_enemy_join_sync_logs:
		print("Received targeted enemy sync: enemies=%s broadcast=false." % received_count)
	initial_enemy_batch_received.emit(received_count)


func _spawn_enemy_visual(enemy_id: int, spawn_position: Vector3, current_hp: int, max_hp: int, enemy_type: String, display_name: String, visual_color: Color, print_spawn: bool, source: String) -> void:
	_enemy_type_by_id[enemy_id] = _resolved_enemy_type(enemy_type)
	_enemy_display_name_by_id[enemy_id] = display_name if not display_name.is_empty() else "Enemy"
	if _spawned_enemy_nodes.has(enemy_id):
		var existing_enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
		_log_client_enemy_snap(enemy_id, existing_enemy.position, spawn_position, source)
		existing_enemy.position = spawn_position
		_target_positions[enemy_id] = spawn_position
		_set_enemy_label(existing_enemy, enemy_id, current_hp, max_hp)
		_apply_enemy_visual_color(existing_enemy, visual_color)
		return

	if enemy_placeholder_scene == null:
		print("Cannot spawn enemy %s: enemy placeholder scene is not set." % enemy_id)
		return

	var enemy: Node3D = enemy_placeholder_scene.instantiate() as Node3D
	enemy.name = "Enemy_%s" % enemy_id
	var initial_position: Vector3 = spawn_position
	if _target_positions.has(enemy_id):
		initial_position = _target_positions[enemy_id] as Vector3

	enemy.position = initial_position
	add_child(enemy)
	_spawned_enemy_nodes[enemy_id] = enemy
	_target_positions[enemy_id] = initial_position
	_set_enemy_label(enemy, enemy_id, current_hp, max_hp)
	_apply_enemy_visual_color(enemy, visual_color)
	if print_spawn and debug_enemy_lifecycle_logs:
		print("Enemy placeholder instantiated on client: enemy_id=%s type=%s position=%s node_name=%s" % [enemy_id, enemy_type, spawn_position, enemy.name])


@rpc("authority", "call_remote", "unreliable")
func apply_enemy_position_snapshots(snapshots: Array) -> void:
	for snapshot in snapshots:
		var snapshot_data: Dictionary = snapshot as Dictionary
		var enemy_id: int = int(snapshot_data.get("enemy_id", 0))
		var authoritative_position: Vector3 = snapshot_data.get("position", Vector3.ZERO) as Vector3
		if enemy_id <= 0:
			continue

		var previous_position: Vector3 = authoritative_position
		var has_previous_position: bool = false
		if _spawned_enemy_nodes.has(enemy_id) and not _target_positions.has(enemy_id):
			var enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
			previous_position = enemy.position
			has_previous_position = true
			enemy.position = authoritative_position
		elif _target_positions.has(enemy_id):
			previous_position = _target_positions[enemy_id] as Vector3
			has_previous_position = true
		elif _spawned_enemy_nodes.has(enemy_id):
			var existing_enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
			previous_position = existing_enemy.position
			has_previous_position = true

		if has_previous_position:
			_log_client_enemy_snap(enemy_id, previous_position, authoritative_position, "position snapshot")
		_target_positions[enemy_id] = authoritative_position


@rpc("authority", "call_remote", "reliable")
func show_enemy_hit(enemy_id: int, current_hp: int, max_hp: int) -> void:
	if not _spawned_enemy_nodes.has(enemy_id):
		return

	var enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
	_set_enemy_label(enemy, enemy_id, current_hp, max_hp)
	if debug_enemy_lifecycle_logs:
		print("Enemy %s hit. HP: %s/%s" % [enemy_id, current_hp, max_hp])


@rpc("authority", "call_remote", "reliable")
func show_enemy_melee_telegraph(enemy_id: int, attack_position: Vector3, radius: float, windup_seconds: float) -> void:
	if radius <= 0.0:
		return

	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: CylinderMesh = CylinderMesh.new()
	marker_mesh.top_radius = radius
	marker_mesh.bottom_radius = radius
	marker_mesh.height = 0.08
	marker.mesh = marker_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.1, 0.05, 0.35)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	marker.name = "EnemyMeleeTelegraph_%s" % enemy_id
	marker.position = attack_position + Vector3(0.0, 0.1, 0.0)
	add_child(marker)

	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = max(windup_seconds, 0.05)
	marker.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(marker.queue_free)
	cleanup_timer.start()


@rpc("authority", "call_remote", "reliable")
func show_enemy_ranged_telegraph(enemy_id: int, start_position: Vector3, target_position: Vector3, width: float, windup_seconds: float) -> void:
	var offset_xz: Vector2 = Vector2(target_position.x - start_position.x, target_position.z - start_position.z)
	var length: float = offset_xz.length()
	if length <= 0.001:
		return

	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: BoxMesh = BoxMesh.new()
	marker_mesh.size = Vector3(max(width, 0.08), 0.12, length)
	marker.mesh = marker_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.7, 1.0, 0.55)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.2, 0.55, 1.0, 1.0)
	material.emission_energy_multiplier = 0.7
	marker.material_override = material
	marker.name = "EnemyRangedTelegraph_%s" % enemy_id
	marker.position = start_position.lerp(target_position, 0.5) + Vector3(0.0, 0.45, 0.0)
	marker.rotation.y = atan2(-offset_xz.x, -offset_xz.y)
	add_child(marker)

	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = max(windup_seconds, 0.05)
	marker.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(marker.queue_free)
	cleanup_timer.start()


@rpc("authority", "call_remote", "reliable")
func despawn_enemy(enemy_id: int) -> void:
	if not _spawned_enemy_nodes.has(enemy_id):
		return

	var enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
	enemy.queue_free()
	_spawned_enemy_nodes.erase(enemy_id)
	_target_positions.erase(enemy_id)
	_enemy_type_by_id.erase(enemy_id)
	_enemy_display_name_by_id.erase(enemy_id)
	if debug_enemy_lifecycle_logs:
		print("Enemy %s defeated and removed." % enemy_id)


func _set_enemy_label(enemy: Node, enemy_id: int, current_hp: int, max_hp: int) -> void:
	var enemy_label: Label3D = enemy.get_node_or_null("EnemyLabel") as Label3D
	if enemy_label != null:
		var display_name: String = str(_enemy_display_name_by_id.get(enemy_id, "Enemy"))
		enemy_label.text = "%s %s\nHP %s/%s" % [display_name, enemy_id, current_hp, max_hp]


func _apply_enemy_visual_color(enemy: Node, visual_color: Color) -> void:
	var body: MeshInstance3D = enemy.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = visual_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.emission_enabled = true
	material.emission = visual_color
	material.emission_energy_multiplier = 0.45
	body.set_surface_override_material(0, material)
