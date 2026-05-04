extends Node3D
class_name EnemySpawner

@export var enemy_placeholder_scene: PackedScene
@export var idle_radius: float = 1.2
@export var idle_speed: float = 0.6
@export var snapshot_rate: float = 6.0
@export var interpolation_speed: float = 8.0
@export var enemy_max_hp: int = 30
@export var basic_attack_damage: int = 10
@export var basic_attack_range: float = 4.0
@export var basic_attack_cone_dot: float = 0.65
@export var respawn_delay_seconds: float = 5.0
@export var debug_enemy_return_logs: bool = true
@export var debug_enemy_snap_logs: bool = true
@export var enemy_snap_log_threshold: float = 5.0

var enemies: Dictionary = {}
var _spawned_enemy_nodes: Dictionary = {}
var _enemy_origin_positions: Dictionary = {}
var _enemy_spawn_points: Dictionary = {}
var _target_positions: Dictionary = {}
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
var _enemy_previous_authoritative_positions: Dictionary = {}
var _next_enemy_id: int = 1
var _idle_time: float = 0.0
var _snapshot_accumulator: float = 0.0

const DEFAULT_ENEMY_DEFINITION: Dictionary = {
	"aggro_radius": 8.0,
	"chase_speed": 2.2,
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
}

const INITIAL_ENEMY_POSITIONS: Array[Vector3] = [
	Vector3(6, 0, 2),
	Vector3(8, 0, -2),
	Vector3(5, 0, 5),
]


func spawn_initial_enemies() -> void:
	if not multiplayer.is_server() or not enemies.is_empty():
		return

	for spawn_position in INITIAL_ENEMY_POSITIONS:
		_spawn_enemy(spawn_position)


func sync_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var alive_player_count: int = _get_alive_player_positions().size()
	var enemy_snapshots: Array = []
	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var spawn_position: Vector3 = enemies[enemy_id] as Vector3
		var current_hp: int = int(_enemy_current_hp_by_id.get(enemy_id, enemy_max_hp))
		var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, enemy_max_hp))
		enemy_snapshots.append({
			"enemy_id": enemy_id_int,
			"position": spawn_position,
			"current_hp": current_hp,
			"max_hp": max_hp,
		})

	if not enemy_snapshots.is_empty():
		rpc_id(peer_id, "spawn_enemies", enemy_snapshots)
	print("Join sync targeted to peer %s: enemies=%s broadcast=false." % [peer_id, enemy_snapshots.size()])
	print("Enemy aggro accepted/alive players considered after peer %s join: %s." % [peer_id, alive_player_count])


func get_active_enemy_positions() -> Dictionary:
	return enemies.duplicate()


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


func _spawn_enemy(spawn_position: Vector3) -> void:
	var enemy_id: int = _next_enemy_id
	_next_enemy_id += 1
	enemies[enemy_id] = spawn_position
	_enemy_origin_positions[enemy_id] = spawn_position
	_enemy_spawn_points[enemy_id] = spawn_position
	_enemy_previous_authoritative_positions[enemy_id] = spawn_position
	_enemy_max_hp_by_id[enemy_id] = enemy_max_hp
	_enemy_current_hp_by_id[enemy_id] = enemy_max_hp
	rpc("spawn_enemy", enemy_id, spawn_position, enemy_max_hp, enemy_max_hp)
	print("Spawned enemy %s at %s." % [enemy_id, spawn_position])


func resolve_basic_attack(_attacker_peer_id: int, attack_position: Vector3, facing_direction: Vector2) -> void:
	if not multiplayer.is_server() or facing_direction.length_squared() <= 0.0001:
		return

	var normalized_facing: Vector2 = facing_direction.normalized()
	var best_enemy_id: int = 0
	var best_distance: float = basic_attack_range
	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var enemy_position: Vector3 = enemies[enemy_id] as Vector3
		var offset_xz: Vector2 = Vector2(enemy_position.x - attack_position.x, enemy_position.z - attack_position.z)
		var distance: float = offset_xz.length()
		if distance <= 0.001 or distance > basic_attack_range:
			continue

		var direction_to_enemy: Vector2 = offset_xz / distance
		if normalized_facing.dot(direction_to_enemy) < basic_attack_cone_dot:
			continue
		if distance < best_distance:
			best_distance = distance
			best_enemy_id = enemy_id_int

	if best_enemy_id <= 0:
		return

	_apply_damage_to_enemy(best_enemy_id, _attacker_peer_id, basic_attack_damage)


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


func resolve_firebolt(_attacker_peer_id: int, firebolt_position: Vector3, aim_direction: Vector2, firebolt_range: float, firebolt_width: float, damage: int) -> void:
	if not multiplayer.is_server() or aim_direction.length_squared() <= 0.0001 or firebolt_range <= 0.0 or firebolt_width <= 0.0 or damage <= 0:
		return

	var normalized_aim: Vector2 = aim_direction.normalized()
	var best_enemy_id: int = 0
	var best_distance_along: float = firebolt_range
	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var enemy_position: Vector3 = enemies[enemy_id] as Vector3
		var offset_xz: Vector2 = Vector2(enemy_position.x - firebolt_position.x, enemy_position.z - firebolt_position.z)
		var distance_along: float = normalized_aim.dot(offset_xz)
		if distance_along < 0.0 or distance_along > firebolt_range:
			continue

		var closest_point: Vector2 = normalized_aim * distance_along
		var distance_from_line: float = (offset_xz - closest_point).length()
		if distance_from_line > firebolt_width:
			continue
		if distance_along < best_distance_along:
			best_distance_along = distance_along
			best_enemy_id = enemy_id_int

	if best_enemy_id <= 0:
		return

	_apply_damage_to_enemy(best_enemy_id, _attacker_peer_id, damage)


func _apply_damage_to_enemy(enemy_id: int, attacker_peer_id: int, damage: int) -> void:
	if not enemies.has(enemy_id) or damage <= 0:
		return

	var current_hp: int = int(_enemy_current_hp_by_id.get(enemy_id, enemy_max_hp))
	var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, enemy_max_hp))
	current_hp = max(current_hp - damage, 0)
	_enemy_current_hp_by_id[enemy_id] = current_hp
	rpc("show_enemy_hit", enemy_id, current_hp, max_hp)

	if current_hp <= 0:
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
	_returning_enemy_ids.erase(enemy_id)
	_enemy_return_regen_progress.erase(enemy_id)
	_enemy_return_log_last_seconds.erase(enemy_id)
	_enemy_previous_authoritative_positions.erase(enemy_id)
	_dead_enemy_ids[enemy_id] = true
	rpc("despawn_enemy", enemy_id)
	_schedule_enemy_respawn(enemy_id)


func _schedule_enemy_respawn(enemy_id: int) -> void:
	if not multiplayer.is_server() or not _enemy_spawn_points.has(enemy_id):
		return

	var respawn_timer: Timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = respawn_delay_seconds
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
	enemies[enemy_id] = spawn_position
	_enemy_origin_positions[enemy_id] = spawn_position
	_enemy_previous_authoritative_positions[enemy_id] = spawn_position
	_enemy_max_hp_by_id[enemy_id] = enemy_max_hp
	_enemy_current_hp_by_id[enemy_id] = enemy_max_hp
	_forced_aggro_peer_by_enemy.erase(enemy_id)
	_forced_aggro_until_by_enemy.erase(enemy_id)
	_proximity_aggro_peer_by_enemy.erase(enemy_id)
	_proximity_aggro_until_by_enemy.erase(enemy_id)
	_returning_enemy_ids.erase(enemy_id)
	_enemy_return_regen_progress.erase(enemy_id)
	_enemy_return_log_last_seconds.erase(enemy_id)
	_dead_enemy_ids.erase(enemy_id)
	rpc("spawn_enemy", enemy_id, spawn_position, enemy_max_hp, enemy_max_hp)
	print("Respawned enemy %s at %s." % [enemy_id, spawn_position])


func _update_enemy_positions(delta: float) -> void:
	var alive_player_positions: Dictionary = _get_alive_player_positions()
	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var enemy_position: Vector3 = enemies[enemy_id] as Vector3
		var spawn_position: Vector3 = _enemy_spawn_points.get(enemy_id_int, enemy_position) as Vector3
		if _returning_enemy_ids.has(enemy_id_int):
			var return_position: Vector3 = _return_position(enemy_id_int, enemy_position, spawn_position, delta)
			enemies[enemy_id] = return_position
			_log_server_enemy_snap(enemy_id_int, enemy_position, return_position, delta, "returning", _target_peer_for_enemy(enemy_id_int))
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

			var chase_position: Vector3 = _chase_position(enemy_position, target_position, delta)
			enemies[enemy_id] = chase_position
			_log_server_enemy_snap(enemy_id_int, enemy_position, chase_position, delta, "chasing", target_peer_id)
			continue

		if _should_return_without_target(enemy_position, spawn_position):
			_begin_return_to_spawn(enemy_id_int, "no valid target outside home area", enemy_position, spawn_position, Vector3.ZERO, false)
			var no_target_return_position: Vector3 = _return_position(enemy_id_int, enemy_position, spawn_position, delta)
			enemies[enemy_id] = no_target_return_position
			_log_server_enemy_snap(enemy_id_int, enemy_position, no_target_return_position, delta, "entering_return", 0)
			continue

		var idle_return_distance: float = _enemy_definition_float("idle_return_distance", 5.0)
		var distance_from_spawn: float = _distance_xz(enemy_position, spawn_position)
		if distance_from_spawn > idle_return_distance:
			_begin_return_to_spawn(enemy_id_int, "idle redirected to return because enemy is far from home", enemy_position, spawn_position, Vector3.ZERO, false)
			var idle_return_position: Vector3 = _return_position(enemy_id_int, enemy_position, spawn_position, delta)
			enemies[enemy_id] = idle_return_position
			_log_server_enemy_snap(enemy_id_int, enemy_position, idle_return_position, delta, "idle_redirected_to_return", 0)
			continue

		var origin_position: Vector3 = _enemy_origin_positions[enemy_id] as Vector3
		var angle: float = _idle_time * idle_speed + float(enemy_id_int)
		var idle_target_position: Vector3 = origin_position + Vector3(cos(angle) * idle_radius, 0.0, sin(angle) * idle_radius)
		var idle_position: Vector3 = _move_toward_position(enemy_position, idle_target_position, _enemy_definition_float("idle_move_speed", 0.8), delta)
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

	var nearest_target: Dictionary = _nearest_aggro_player(enemy_position, alive_player_positions)
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
	var aggro_radius: float = _enemy_definition_float("aggro_radius", 8.0)
	if _distance_xz(enemy_position, player_position) <= aggro_radius:
		aggro_until = now_seconds + _enemy_definition_float("proximity_aggro_seconds", 11.0)
		_proximity_aggro_until_by_enemy[enemy_id] = aggro_until

	if now_seconds > aggro_until:
		_proximity_aggro_peer_by_enemy.erase(enemy_id)
		_proximity_aggro_until_by_enemy.erase(enemy_id)
		print("Enemy %s proximity engagement expired for peer %s." % [enemy_id, peer_id])
		return {"has_target": false, "position": Vector3.ZERO}

	return {
		"has_target": true,
		"position": player_position,
		"peer_id": peer_id,
	}


func _nearest_aggro_player(enemy_position: Vector3, alive_player_positions: Dictionary) -> Dictionary:
	var aggro_radius: float = _enemy_definition_float("aggro_radius", 8.0)
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
	_proximity_aggro_until_by_enemy[enemy_id] = now_seconds + _enemy_definition_float("proximity_aggro_seconds", 11.0)
	print("Enemy %s proximity aggro acquired peer %s." % [enemy_id, peer_id])


func _set_forced_aggro(enemy_id: int, attacker_peer_id: int) -> void:
	if attacker_peer_id <= 0 or not _is_peer_alive(attacker_peer_id):
		return

	if _returning_enemy_ids.has(enemy_id) and _is_enemy_beyond_emergency_failsafe(enemy_id):
		return

	var was_returning: bool = _returning_enemy_ids.has(enemy_id)
	_returning_enemy_ids.erase(enemy_id)
	_enemy_return_regen_progress.erase(enemy_id)
	_proximity_aggro_peer_by_enemy.erase(enemy_id)
	_proximity_aggro_until_by_enemy.erase(enemy_id)
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_forced_aggro_peer_by_enemy[enemy_id] = attacker_peer_id
	_forced_aggro_until_by_enemy[enemy_id] = now_seconds + _enemy_definition_float("forced_aggro_seconds", 16.0)
	if was_returning:
		print("Enemy %s re-engaged by damage from peer %s." % [enemy_id, attacker_peer_id])
	else:
		print("Enemy %s forced aggro on peer %s from damage." % [enemy_id, attacker_peer_id])


func _is_peer_alive(peer_id: int) -> bool:
	var alive_player_positions: Dictionary = _get_alive_player_positions()
	return alive_player_positions.has(peer_id)


func _target_peer_for_enemy(enemy_id: int) -> int:
	if _forced_aggro_peer_by_enemy.has(enemy_id):
		return int(_forced_aggro_peer_by_enemy.get(enemy_id, 0))
	if _proximity_aggro_peer_by_enemy.has(enemy_id):
		return int(_proximity_aggro_peer_by_enemy.get(enemy_id, 0))
	return 0


func _should_return_with_target(_enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, target_position: Vector3) -> bool:
	var target_drop_distance: float = _enemy_definition_float("target_drop_distance", 65.0)
	if _distance_xz(enemy_position, target_position) > target_drop_distance:
		return true

	var hard_return_distance: float = _enemy_definition_float("hard_return_distance", 160.0)
	return _distance_xz(enemy_position, spawn_position) > hard_return_distance


func _should_return_without_target(enemy_position: Vector3, spawn_position: Vector3) -> bool:
	var home_return_distance: float = _enemy_definition_float("home_return_distance", 70.0)
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
		print("Enemy %s returning to spawn: %s. distance_from_spawn=%s distance_to_target=%s return_speed=%s" % [enemy_id, reason, distance_from_spawn, distance_to_target, _return_speed()])


func _return_position(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, delta: float) -> Vector3:
	var distance_from_spawn: float = _distance_xz(enemy_position, spawn_position)
	var emergency_failsafe_distance: float = _enemy_definition_float("emergency_failsafe_distance", 1000.0)
	if distance_from_spawn > emergency_failsafe_distance:
		# Failsafe only: normal leash return is smooth and should not snap.
		print("Enemy %s emergency leash failsafe snap from distance %s." % [enemy_id, distance_from_spawn])
		return _emergency_leash_snap(enemy_id, spawn_position)

	_regenerate_enemy_while_returning(enemy_id, delta)
	var reset_distance: float = _enemy_definition_float("leash_reset_distance", 0.75)
	var offset_xz: Vector2 = Vector2(spawn_position.x - enemy_position.x, spawn_position.z - enemy_position.z)
	if offset_xz.length() <= reset_distance:
		_log_return_update(enemy_id, enemy_position, spawn_position, distance_from_spawn, delta, 0.0)
		return _finish_leash_reset(enemy_id, enemy_position)

	var return_speed: float = _return_speed()
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
	var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, enemy_max_hp))
	# Full leash reset restores HP so a pulled enemy returns to its spawn state.
	_enemy_current_hp_by_id[enemy_id] = max_hp
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
	var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, enemy_max_hp))
	_enemy_current_hp_by_id[enemy_id] = max_hp
	rpc("show_enemy_hit", enemy_id, max_hp, max_hp)
	return spawn_position


func _regenerate_enemy_while_returning(enemy_id: int, delta: float) -> void:
	var regen_per_second: float = _enemy_definition_float("return_regen_per_second", 8.0)
	if regen_per_second <= 0.0:
		return

	var max_hp: int = int(_enemy_max_hp_by_id.get(enemy_id, enemy_max_hp))
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
	var emergency_failsafe_distance: float = _enemy_definition_float("emergency_failsafe_distance", 1000.0)
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
	var chase_speed: float = _enemy_definition_float("chase_speed", 2.2)
	var return_speed_multiplier: float = _enemy_definition_float("return_speed_multiplier", 0.75)
	print("Enemy %s return update: current_position=%s spawn_position=%s distance_to_spawn=%s chase_speed=%s return_speed_multiplier=%s return_speed=%s delta=%s step_length=%s" % [
		enemy_id,
		enemy_position,
		spawn_position,
		distance_from_spawn,
		chase_speed,
		return_speed_multiplier,
		_return_speed(),
		delta,
		step_distance,
	])


func _return_speed() -> float:
	var chase_speed: float = _enemy_definition_float("chase_speed", 2.2)
	var return_speed_multiplier: float = _enemy_definition_float("return_speed_multiplier", 0.75)
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


func _chase_position(enemy_position: Vector3, target_position: Vector3, delta: float) -> Vector3:
	var offset: Vector3 = target_position - enemy_position
	offset.y = 0.0
	if offset.length_squared() <= 0.0001:
		return enemy_position

	var chase_speed: float = _enemy_definition_float("chase_speed", 2.2)
	var max_step: float = chase_speed * delta
	var distance: float = offset.length()
	if distance <= max_step:
		return Vector3(target_position.x, enemy_position.y, target_position.z)

	return enemy_position + offset.normalized() * max_step


func _enemy_definition_float(key: String, fallback: float) -> float:
	return float(DEFAULT_ENEMY_DEFINITION.get(key, fallback))


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
func spawn_enemy(enemy_id: int, spawn_position: Vector3, current_hp: int = 30, max_hp: int = 30) -> void:
	if multiplayer.is_server():
		return

	_spawn_enemy_visual(enemy_id, spawn_position, current_hp, max_hp, true, "spawn_enemy")


@rpc("authority", "call_remote", "reliable")
func spawn_enemies(enemy_snapshots: Array) -> void:
	if multiplayer.is_server():
		return

	for snapshot in enemy_snapshots:
		var snapshot_data: Dictionary = snapshot as Dictionary
		var enemy_id: int = int(snapshot_data.get("enemy_id", 0))
		var spawn_position: Vector3 = snapshot_data.get("position", Vector3.ZERO) as Vector3
		var current_hp: int = int(snapshot_data.get("current_hp", enemy_max_hp))
		var max_hp: int = int(snapshot_data.get("max_hp", enemy_max_hp))
		if enemy_id <= 0:
			continue

		_spawn_enemy_visual(enemy_id, spawn_position, current_hp, max_hp, false, "spawn_enemies")
	print("Received targeted enemy sync: enemies=%s broadcast=false." % enemy_snapshots.size())


func _spawn_enemy_visual(enemy_id: int, spawn_position: Vector3, current_hp: int, max_hp: int, print_spawn: bool, source: String) -> void:
	if _spawned_enemy_nodes.has(enemy_id):
		var existing_enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
		_log_client_enemy_snap(enemy_id, existing_enemy.position, spawn_position, source)
		existing_enemy.position = spawn_position
		_target_positions[enemy_id] = spawn_position
		_set_enemy_label(existing_enemy, enemy_id, current_hp, max_hp)
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
	if print_spawn:
		print("Enemy placeholder instantiated on client: enemy_id=%s position=%s node_name=%s" % [enemy_id, spawn_position, enemy.name])


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
	print("Enemy %s hit. HP: %s/%s" % [enemy_id, current_hp, max_hp])


@rpc("authority", "call_remote", "reliable")
func despawn_enemy(enemy_id: int) -> void:
	if not _spawned_enemy_nodes.has(enemy_id):
		return

	var enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
	enemy.queue_free()
	_spawned_enemy_nodes.erase(enemy_id)
	_target_positions.erase(enemy_id)
	print("Enemy %s defeated and removed." % enemy_id)


func _set_enemy_label(enemy: Node, enemy_id: int, current_hp: int, max_hp: int) -> void:
	var enemy_label: Label3D = enemy.get_node_or_null("EnemyLabel") as Label3D
	if enemy_label != null:
		enemy_label.text = "Enemy %s\nHP %s/%s" % [enemy_id, current_hp, max_hp]
