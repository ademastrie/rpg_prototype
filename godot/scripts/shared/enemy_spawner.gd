extends Node3D
class_name EnemySpawner

@export var enemy_placeholder_scene: PackedScene
@export var idle_radius: float = 1.2
@export var idle_speed: float = 0.6
@export var snapshot_rate: float = 6.0
@export var interpolation_speed: float = 8.0

var enemies: Dictionary = {}
var _spawned_enemy_nodes: Dictionary = {}
var _enemy_origin_positions: Dictionary = {}
var _target_positions: Dictionary = {}
var _next_enemy_id: int = 1
var _idle_time: float = 0.0
var _snapshot_accumulator: float = 0.0

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

	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var spawn_position: Vector3 = enemies[enemy_id] as Vector3
		rpc_id(peer_id, "spawn_enemy", enemy_id_int, spawn_position)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		_smooth_spawned_enemies(delta)
		return

	_idle_time += delta
	_snapshot_accumulator += delta
	_update_enemy_idle_positions()

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
	rpc("spawn_enemy", enemy_id, spawn_position)
	print("Spawned enemy %s at %s." % [enemy_id, spawn_position])


func _update_enemy_idle_positions() -> void:
	for enemy_id in enemies:
		var enemy_id_int: int = int(enemy_id)
		var origin_position: Vector3 = _enemy_origin_positions[enemy_id] as Vector3
		var angle: float = _idle_time * idle_speed + float(enemy_id_int)
		enemies[enemy_id] = origin_position + Vector3(cos(angle) * idle_radius, 0.0, sin(angle) * idle_radius)


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


@rpc("authority", "call_remote", "reliable")
func spawn_enemy(enemy_id: int, spawn_position: Vector3) -> void:
	if _spawned_enemy_nodes.has(enemy_id):
		var existing_enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
		existing_enemy.position = spawn_position
		_target_positions[enemy_id] = spawn_position
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
	_set_enemy_label(enemy, enemy_id)
	print("Enemy placeholder instantiated on client: enemy_id=%s position=%s node_name=%s" % [enemy_id, spawn_position, enemy.name])


@rpc("authority", "call_remote", "unreliable")
func apply_enemy_position_snapshots(snapshots: Array) -> void:
	for snapshot in snapshots:
		var snapshot_data: Dictionary = snapshot as Dictionary
		var enemy_id: int = int(snapshot_data.get("enemy_id", 0))
		var authoritative_position: Vector3 = snapshot_data.get("position", Vector3.ZERO) as Vector3
		if enemy_id <= 0:
			continue

		if _spawned_enemy_nodes.has(enemy_id) and not _target_positions.has(enemy_id):
			var enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
			enemy.position = authoritative_position
		_target_positions[enemy_id] = authoritative_position


func _set_enemy_label(enemy: Node, enemy_id: int) -> void:
	var enemy_label: Label3D = enemy.get_node_or_null("EnemyLabel") as Label3D
	if enemy_label != null:
		enemy_label.text = "Enemy %s" % enemy_id
