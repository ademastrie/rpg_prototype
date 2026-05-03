extends Node3D
class_name EnemySpawner

@export var enemy_placeholder_scene: PackedScene

var enemies: Dictionary = {}
var _spawned_enemy_nodes: Dictionary = {}
var _next_enemy_id: int = 1

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


func _spawn_enemy(spawn_position: Vector3) -> void:
	var enemy_id: int = _next_enemy_id
	_next_enemy_id += 1
	enemies[enemy_id] = spawn_position
	rpc("spawn_enemy", enemy_id, spawn_position)
	print("Spawned enemy %s at %s." % [enemy_id, spawn_position])


@rpc("authority", "call_remote", "reliable")
func spawn_enemy(enemy_id: int, spawn_position: Vector3) -> void:
	if _spawned_enemy_nodes.has(enemy_id):
		var existing_enemy: Node3D = _spawned_enemy_nodes[enemy_id] as Node3D
		existing_enemy.position = spawn_position
		return

	if enemy_placeholder_scene == null:
		print("Cannot spawn enemy %s: enemy placeholder scene is not set." % enemy_id)
		return

	var enemy: Node3D = enemy_placeholder_scene.instantiate() as Node3D
	enemy.name = "Enemy_%s" % enemy_id
	enemy.position = spawn_position
	add_child(enemy)
	_spawned_enemy_nodes[enemy_id] = enemy
	_set_enemy_label(enemy, enemy_id)
	print("Enemy placeholder instantiated on client: enemy_id=%s position=%s node_name=%s" % [enemy_id, spawn_position, enemy.name])


func _set_enemy_label(enemy: Node, enemy_id: int) -> void:
	var enemy_label: Label3D = enemy.get_node_or_null("EnemyLabel") as Label3D
	if enemy_label != null:
		enemy_label.text = "Enemy %s" % enemy_id
