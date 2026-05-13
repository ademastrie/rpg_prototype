extends Node3D

signal spawned_player_count_changed(count: int)
signal player_spawned(peer_id: int, player: Node3D)
signal player_health_updated(peer_id: int, current_hp: int, max_hp: int)
signal player_down_state_updated(peer_id: int, is_down: bool)
signal player_combat_stats_updated(peer_id: int, combat_stats: Dictionary)
signal character_progression_updated(peer_id: int, progression: Dictionary)
signal character_gold_updated(peer_id: int, gold: int)
signal character_inventory_updated(peer_id: int, inventory_items: Array)
signal character_equipment_updated(peer_id: int, equipment: Dictionary)
signal combat_mode_updated(peer_id: int, combat_enabled: bool, loadout_entries: Array)
signal ability_enabled_updated(peer_id: int, ability_name: String, enabled: bool)
signal ability_state_updated(peer_id: int, ability_name: String, enabled: bool, active: bool, cooldown_remaining: float)
signal ability_catalog_updated(peer_id: int, unlocked_abilities: Array)
signal ability_unlock_message_received(peer_id: int, display_name: String)
signal status_message_received(peer_id: int, message: String)
signal join_requested(peer_id: int, character_id: int, character_name: String, access_token: String)
signal ability_loadout_update_requested(peer_id: int, loadout_entries: Array)
signal equipment_update_requested(peer_id: int, equipment_entries: Array)
signal loot_reward_pickup_requested(peer_id: int, loot_orb_id: int, reward_payload: Dictionary)

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
@export var enemy_contact_damage_enabled: bool = false
@export var enemy_contact_range: float = 1.75
@export var enemy_contact_damage: int = 10
@export var enemy_contact_damage_interval: float = 1.0
@export var player_respawn_delay_seconds: float = 3.0
@export var prototype_loot_pickup_radius: float = 1.5
@export var debug_join_sync_logs: bool = false

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
var _player_combat_stats_by_peer: Dictionary = {}
var _character_progression_by_peer: Dictionary = {}
var _character_gold_by_peer: Dictionary = {}
var _character_inventory_items_by_peer: Dictionary = {}
var _character_equipment_by_peer: Dictionary = {}
var _player_respawn_positions: Dictionary = {}
var _last_contact_damage_time_by_peer: Dictionary = {}
var _combat_enabled_by_peer: Dictionary = {}
var _loadout_by_peer: Dictionary = {}
var _ability_keys_by_peer: Dictionary = {}
var _ability_slot_indexes_by_peer: Dictionary = {}
var _ability_display_names_by_peer: Dictionary = {}
var _unlocked_abilities_by_peer: Dictionary = {}
var _ability_enabled_by_peer: Dictionary = {}
var _last_ability_time_by_peer: Dictionary = {}
var _server_ability_configs: Dictionary = {}
var _server_projectiles: Dictionary = {}
var _spawned_projectile_nodes: Dictionary = {}
var _loot_orbs: Dictionary = {}
var _spawned_loot_orb_nodes: Dictionary = {}
var _local_prediction_input: Vector2 = Vector2.ZERO
var _simulation_accumulator := 0.0
var _snapshot_accumulator := 0.0
var _next_spawn_index := 0
var _next_projectile_id := 1
var _next_loot_orb_id := 1
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

const DEFAULT_LOADOUT: Array[String] = ["Slash", "HP Regen", "Damage Aura", "Firebolt"]

# Fallback prototype loot tables. Backend enemy definitions are durable data;
# Godot keeps spawned loot orbs and pickup state server-owned as live simulation.
const SERVER_PROTOTYPE_LOOT_TABLES: Dictionary = {
	"grunt": [
		{"payload_type": "currency", "min_quantity": 3, "max_quantity": 3, "drop_chance": 1.0},
		{"payload_type": "item", "item_key": "slime_gel", "min_quantity": 1, "max_quantity": 1, "drop_chance": 1.0},
		{"payload_type": "item", "item_key": "training_sword", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.0375},
		{"payload_type": "item", "item_key": "padded_chest", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.0375},
		{"payload_type": "item", "item_key": "cloth_hood", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.0375},
		{"payload_type": "item", "item_key": "worn_boots", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.0375},
	],
	"brute": [
		{"payload_type": "currency", "min_quantity": 5, "max_quantity": 8, "drop_chance": 1.0},
		{"payload_type": "item", "item_key": "slime_gel", "min_quantity": 1, "max_quantity": 2, "drop_chance": 1.0},
		{"payload_type": "item", "item_key": "training_sword", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.05},
		{"payload_type": "item", "item_key": "padded_chest", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.05},
	],
	"caster": [
		{"payload_type": "currency", "min_quantity": 3, "max_quantity": 5, "drop_chance": 1.0},
		{"payload_type": "item", "item_key": "slime_gel", "min_quantity": 1, "max_quantity": 1, "drop_chance": 1.0},
		{"payload_type": "item", "item_key": "cloth_hood", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.075},
		{"payload_type": "item", "item_key": "worn_boots", "min_quantity": 1, "max_quantity": 1, "drop_chance": 0.075},
	],
}
const ABILITY_KEY_BY_DISPLAY_NAME: Dictionary = {
	"Slash": "slash",
	"HP Regen": "hp_regen",
	"Damage Aura": "damage_aura",
	"Firebolt": "firebolt",
	"Shoot": "shoot",
}

# Safe fallback prototype ability config. Backend runtime values can override
# this server-owned cache, while Godot keeps combat execution authoritative.
const SERVER_ABILITY_CONFIGS: Dictionary = {
	"slash": {
		"behavior_key": "melee_arc_damage",
		"visual_key": "slash_arc",
		"cooldown_seconds": 1.25,
		"damage": 10,
		"range": 3.5,
		"arc_angle": 90.0,
		"stat_modifiers": [
			{"stat_key": "max_hp", "modifier_type": "flat", "value": 25.0},
			{"stat_key": "armor", "modifier_type": "flat", "value": 0.20},
		],
	},
	"hp_regen": {
		"behavior_key": "periodic_heal",
		"visual_key": "hp_regen",
		"tick_seconds": 2.0,
		"cooldown_seconds": 2.0,
		"heal": 8,
	},
	"damage_aura": {
		"behavior_key": "point_blank_aoe_damage",
		"visual_key": "damage_aura",
		"tick_seconds": 1.0,
		"cooldown_seconds": 1.0,
		"damage": 5,
		"radius": 4.0,
	},
	"firebolt": {
		"behavior_key": "projectile_aoe_damage",
		"visual_key": "firebolt",
		"cooldown_seconds": 1.3,
		"damage": 12,
		"range": 8.0,
		"radius": 2.0,
		# Godot-side fallback until projectile_speed is added to backend ability runtime fields.
		"projectile_speed": 12.0,
		"stat_modifiers": [
			{"stat_key": "spell_power", "modifier_type": "flat", "value": 4.0},
		],
	},
	"shoot": {
		"behavior_key": "projectile_single_target",
		"visual_key": "arrow",
		"cooldown_seconds": 1.0,
		"damage": 9,
		"range": 12.0,
		"radius": 0.35,
		# Godot-side fallback until projectile_speed is added to backend ability runtime fields.
		"projectile_speed": 22.0,
		"stat_modifiers": [
			{"stat_key": "move_speed", "modifier_type": "flat", "value": 2.0},
		],
	},
}
const FIREBALL_COLLISION_RADIUS: float = 0.45
const MIN_PLAYER_MOVE_SPEED: float = 1.0
const MAX_PLAYER_MOVE_SPEED: float = 10.0
const PLAYER_AVOIDANCE_CAP: float = 0.30
const PLAYER_ARMOR_CAP: float = 0.80
const PLAYER_COMPUTED_STAT_DEFINITIONS: Dictionary = {
	"max_hp": {"base": 100.0, "min": 1.0},
	"move_speed": {"base": 4.0, "min": 1.0, "max": 10.0},
	"physical_power": {"base": 0.0},
	"spell_power": {"base": 0.0},
	"armor": {"base": 0.0, "min": 0.0, "max": 0.80},
	"avoidance": {"base": 0.0, "min": 0.0, "max": 0.30},
}
const PLAYER_STAT_ALIASES: Dictionary = {
	"attack_power": "physical_power",
	"damage_reduction": "armor",
}
const SUPPORTED_PLAYER_STAT_KEYS: Array[String] = ["max_hp", "move_speed", "physical_power", "spell_power", "armor", "avoidance"]


func _ready() -> void:
	_use_fallback_ability_runtime_configs()


func send_join_request(character_id: int, character_name: String, access_token: String) -> void:
	rpc_id(1, "request_join", character_id, character_name, access_token)


func set_local_prediction_input(input_direction: Vector2) -> void:
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()

	_local_prediction_input = input_direction


func register_peer(peer_id: int, character_name: String = "", loadout: Array = [], ability_enabled: Dictionary = {}, ability_display_names: Dictionary = {}, ability_keys: Dictionary = {}, unlocked_abilities: Array = [], ability_slot_indexes: Dictionary = {}) -> void:
	_register_peer(peer_id, character_name, false, Vector3.ZERO, loadout, ability_enabled, ability_display_names, ability_keys, unlocked_abilities, ability_slot_indexes)


func register_peer_at_position(peer_id: int, character_name: String, spawn_position: Vector3, loadout: Array = [], ability_enabled: Dictionary = {}, ability_display_names: Dictionary = {}, ability_keys: Dictionary = {}, unlocked_abilities: Array = [], ability_slot_indexes: Dictionary = {}) -> void:
	_register_peer(peer_id, character_name, true, spawn_position, loadout, ability_enabled, ability_display_names, ability_keys, unlocked_abilities, ability_slot_indexes)


func _register_peer(peer_id: int, character_name: String, use_custom_spawn: bool, custom_spawn_position: Vector3, loadout: Array, ability_enabled: Dictionary, ability_display_names: Dictionary, ability_keys: Dictionary, unlocked_abilities: Array, ability_slot_indexes: Dictionary) -> void:
	_sync_existing_players_to_peer(peer_id)

	_register_player(peer_id, use_custom_spawn, custom_spawn_position, loadout, ability_enabled, ability_display_names, ability_keys, unlocked_abilities, ability_slot_indexes)
	_character_names_by_peer[peer_id] = character_name
	var peer_position: Vector3 = players[peer_id] as Vector3
	rpc("spawn_player", peer_id, peer_position, character_name)
	_broadcast_hp_regen_active_state(peer_id)
	_send_position_snapshots(peer_id)
	_sync_loot_orbs_to_peer(peer_id)
	_sync_projectiles_to_peer(peer_id)


func _sync_existing_players_to_peer(peer_id: int) -> void:
	var player_snapshots: Array = []
	for existing_peer_id in players:
		var existing_peer_id_int: int = int(existing_peer_id)
		var spawn_position: Vector3 = players[existing_peer_id] as Vector3
		var existing_character_name: String = str(_character_names_by_peer.get(existing_peer_id, ""))
		player_snapshots.append({
			"peer_id": existing_peer_id_int,
			"position": spawn_position,
			"character_name": existing_character_name,
			"hp_regen_active": _is_hp_regen_active(existing_peer_id_int),
		})

	if not player_snapshots.is_empty():
		rpc_id(peer_id, "spawn_players", player_snapshots)
	if debug_join_sync_logs:
		print("Join sync targeted to peer %s: players=%s broadcast=false." % [peer_id, player_snapshots.size()])


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
	_player_combat_stats_by_peer.erase(peer_id)
	_character_progression_by_peer.erase(peer_id)
	_character_gold_by_peer.erase(peer_id)
	_character_inventory_items_by_peer.erase(peer_id)
	_character_equipment_by_peer.erase(peer_id)
	_player_respawn_positions.erase(peer_id)
	_last_contact_damage_time_by_peer.erase(peer_id)
	_combat_enabled_by_peer.erase(peer_id)
	_loadout_by_peer.erase(peer_id)
	_ability_keys_by_peer.erase(peer_id)
	_ability_slot_indexes_by_peer.erase(peer_id)
	_ability_display_names_by_peer.erase(peer_id)
	_unlocked_abilities_by_peer.erase(peer_id)
	_ability_enabled_by_peer.erase(peer_id)
	_last_ability_time_by_peer.erase(peer_id)
	_character_names_by_peer.erase(peer_id)
	_clear_projectiles_for_peer(peer_id)
	rpc("despawn_player", peer_id)


func get_authoritative_position(peer_id: int) -> Vector3:
	if not players.has(peer_id):
		return Vector3.ZERO

	return players[peer_id] as Vector3


func get_alive_player_positions() -> Dictionary:
	var alive_positions: Dictionary = {}
	for peer_id in players:
		var peer_id_int: int = int(peer_id)
		if bool(_player_is_down_by_peer.get(peer_id, false)):
			continue

		var current_hp: int = int(_player_current_hp_by_peer.get(peer_id, player_max_hp))
		if current_hp <= 0:
			continue

		alive_positions[peer_id_int] = players[peer_id] as Vector3

	return alive_positions


func get_spawned_player(peer_id: int) -> Node3D:
	if not _spawned_nodes.has(peer_id):
		return null

	return _spawned_nodes[peer_id] as Node3D


func _register_player(peer_id: int, use_custom_spawn: bool = false, custom_spawn_position: Vector3 = Vector3.ZERO, loadout: Array = [], ability_enabled: Dictionary = {}, ability_display_names: Dictionary = {}, ability_keys: Dictionary = {}, unlocked_abilities: Array = [], ability_slot_indexes: Dictionary = {}) -> void:
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
	_character_equipment_by_peer[peer_id] = {}
	var effective_loadout: Array = loadout.duplicate()
	if effective_loadout.is_empty():
		effective_loadout = DEFAULT_LOADOUT.duplicate()
	_loadout_by_peer[peer_id] = effective_loadout
	_ability_keys_by_peer[peer_id] = _ability_keys_for_loadout(effective_loadout, ability_keys)
	_ability_slot_indexes_by_peer[peer_id] = _ability_slot_indexes_for_loadout(effective_loadout, ability_slot_indexes)
	_ability_display_names_by_peer[peer_id] = _ability_display_names_for_loadout(effective_loadout, ability_display_names)
	_unlocked_abilities_by_peer[peer_id] = unlocked_abilities.duplicate()
	_ability_enabled_by_peer[peer_id] = _ability_enabled_state_for_loadout(effective_loadout, ability_enabled)
	_last_ability_time_by_peer[peer_id] = {}
	_recalculate_player_combat_stats(peer_id, true)
	_character_progression_by_peer[peer_id] = {"level": 1, "xp": 0, "xp_to_next": 100}
	_character_gold_by_peer[peer_id] = 0
	var max_hp: int = int(_player_max_hp_by_peer.get(peer_id, player_max_hp))
	rpc("apply_player_health_update", peer_id, max_hp, max_hp)
	rpc("apply_player_down_state", peer_id, false)
	rpc_id(peer_id, "apply_ability_catalog_update", peer_id, _unlocked_abilities_by_peer[peer_id] as Array)
	rpc("apply_combat_mode_update", peer_id, false, _loadout_entries(peer_id))
	_send_ability_enabled_states(peer_id)
	_send_ability_states(peer_id)
	_broadcast_hp_regen_active_state(peer_id)
	_next_spawn_index += 1


func apply_confirmed_character_progression(peer_id: int, progression: Dictionary) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var confirmed_progression: Dictionary = {
		"level": int(progression.get("level", 1)),
		"xp": int(progression.get("xp", 0)),
		"xp_to_next": int(progression.get("xp_to_next", int(progression.get("level", 1)) * 100)),
	}
	_character_progression_by_peer[peer_id] = confirmed_progression
	rpc_id(peer_id, "apply_character_progression_update", peer_id, confirmed_progression)


func apply_confirmed_character_gold(peer_id: int, gold: int) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var confirmed_gold: int = max(gold, 0)
	_character_gold_by_peer[peer_id] = confirmed_gold
	rpc_id(peer_id, "apply_character_gold_update", peer_id, confirmed_gold)


func apply_confirmed_character_inventory(peer_id: int, inventory_items: Array) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var confirmed_items: Array = inventory_items.duplicate(true)
	_character_inventory_items_by_peer[peer_id] = confirmed_items
	rpc_id(peer_id, "apply_character_inventory_update", peer_id, confirmed_items)


func apply_confirmed_character_equipment(peer_id: int, equipment: Dictionary) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var confirmed_equipment: Dictionary = equipment.duplicate(true)
	_character_equipment_by_peer[peer_id] = confirmed_equipment
	_recalculate_player_combat_stats(peer_id)
	rpc_id(peer_id, "apply_character_equipment_update", peer_id, confirmed_equipment)


func spawn_prototype_loot_drop(enemy_type: String, drop_position: Vector3, owner_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not players.has(owner_peer_id):
		return

	var reward_payloads: Array = _prototype_loot_reward_payloads_for_enemy_type(enemy_type)
	if reward_payloads.is_empty():
		return

	for reward_index in reward_payloads.size():
		var reward_payload: Dictionary = reward_payloads[reward_index] as Dictionary
		if reward_payload.is_empty():
			continue

		var loot_position: Vector3 = drop_position + _prototype_loot_position_offset(reward_index, reward_payloads.size())
		var loot_orb_id: int = _next_loot_orb_id
		_next_loot_orb_id += 1
		var loot_data: Dictionary = {
			"loot_orb_id": loot_orb_id,
			"position": loot_position,
			"active": true,
			"owner_peer_id": owner_peer_id,
			"reward_payload": reward_payload,
		}
		_loot_orbs[loot_orb_id] = loot_data
		# Prototype ownership is server-local only. Future loot ownership should
		# support parties, public timeout, trade rules, and backend persistence if needed.
		rpc_id(owner_peer_id, "spawn_loot_orb", loot_orb_id, loot_position)


func spawn_loot_drop_from_entries(loot_table_entries: Array, enemy_type: String, drop_position: Vector3, owner_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not players.has(owner_peer_id):
		return

	var reward_payloads: Array = _loot_reward_payloads_from_entries(loot_table_entries, enemy_type)
	if reward_payloads.is_empty():
		return

	for reward_index in reward_payloads.size():
		var reward_payload: Dictionary = reward_payloads[reward_index] as Dictionary
		if reward_payload.is_empty():
			continue

		var loot_position: Vector3 = drop_position + _prototype_loot_position_offset(reward_index, reward_payloads.size())
		var loot_orb_id: int = _next_loot_orb_id
		_next_loot_orb_id += 1
		var loot_data: Dictionary = {
			"loot_orb_id": loot_orb_id,
			"position": loot_position,
			"active": true,
			"owner_peer_id": owner_peer_id,
			"reward_payload": reward_payload,
		}
		_loot_orbs[loot_orb_id] = loot_data
		# Loot definitions are durable backend data; the orb lifetime and pickup
		# authorization remain live server simulation in Godot.
		rpc_id(owner_peer_id, "spawn_loot_orb", loot_orb_id, loot_position)


func _prototype_loot_reward_payloads_for_enemy_type(enemy_type: String) -> Array:
	var reward_payloads: Array = []
	var resolved_enemy_type: String = enemy_type.strip_edges()
	if resolved_enemy_type == "":
		print("Cannot spawn prototype loot: missing enemy type.")
		return reward_payloads

	if not SERVER_PROTOTYPE_LOOT_TABLES.has(resolved_enemy_type):
		print("No prototype loot table for enemy type '%s'; no loot spawned." % resolved_enemy_type)
		return reward_payloads

	var loot_table: Array = SERVER_PROTOTYPE_LOOT_TABLES[resolved_enemy_type] as Array
	for entry_variant in loot_table:
		if not (entry_variant is Dictionary):
			continue

		var reward_payload: Dictionary = _prototype_loot_payload_from_entry(entry_variant as Dictionary)
		if not reward_payload.is_empty():
			reward_payloads.append(reward_payload)

	return reward_payloads


func _loot_reward_payloads_from_entries(loot_table_entries: Array, enemy_type: String) -> Array:
	if loot_table_entries.is_empty():
		return _prototype_loot_reward_payloads_for_enemy_type(enemy_type)

	var reward_payloads: Array = []
	for entry_variant in loot_table_entries:
		if not (entry_variant is Dictionary):
			continue

		var reward_payload: Dictionary = _prototype_loot_payload_from_entry(entry_variant as Dictionary)
		if not reward_payload.is_empty():
			reward_payloads.append(reward_payload)

	return reward_payloads


func _prototype_loot_payload_from_entry(entry: Dictionary) -> Dictionary:
	var drop_chance: float = clamp(float(entry.get("drop_chance", entry.get("chance", 1.0))), 0.0, 1.0)
	if drop_chance <= 0.0:
		return {}
	if drop_chance < 1.0 and randf() > drop_chance:
		return {}

	var min_quantity: int = max(int(entry.get("min_quantity", entry.get("min_amount", entry.get("quantity", entry.get("gold_amount", 1))))), 1)
	var max_quantity: int = max(int(entry.get("max_quantity", entry.get("max_amount", entry.get("quantity", entry.get("gold_amount", min_quantity))))), min_quantity)
	var quantity: int = randi_range(min_quantity, max_quantity)
	var payload_type: String = str(entry.get("payload_type", entry.get("type", ""))).strip_edges().to_lower()
	if payload_type == "currency" or payload_type == "gold":
		return {
			"type": "currency",
			"gold_amount": quantity,
		}

	if payload_type == "item":
		var item_key: String = str(entry.get("item_key", "")).strip_edges()
		if item_key == "":
			print("Skipping prototype loot item entry with missing item_key: %s" % entry)
			return {}

		return {
			"type": "item",
			"item_key": item_key,
			"quantity": quantity,
		}

	print("Skipping unsupported prototype loot payload type '%s': %s" % [payload_type, entry])
	return {}


func _prototype_loot_position_offset(reward_index: int, reward_count: int) -> Vector3:
	if reward_count <= 1:
		return Vector3.ZERO

	var angle: float = (TAU / float(reward_count)) * float(reward_index)
	var offset_radius: float = 0.45
	return Vector3(cos(angle) * offset_radius, 0.0, sin(angle) * offset_radius)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		_smooth_spawned_players(delta)
		_animate_projectile_visuals(delta)
		return

	_simulation_accumulator += delta
	_snapshot_accumulator += delta

	var tick_delta := 1.0 / simulation_tick_rate
	while _simulation_accumulator >= tick_delta:
		_simulate(tick_delta)
		_apply_enemy_contact_damage(tick_delta)
		_process_prototype_loot_pickups()
		_process_fireball_projectiles(tick_delta)
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
		var confirmed_move_speed: float = _computed_player_move_speed(int(peer_id))
		position.x += input_direction.x * confirmed_move_speed * delta
		position.z += input_direction.y * confirmed_move_speed * delta
		players[peer_id] = position


func _apply_enemy_contact_damage(_delta: float) -> void:
	if not enemy_contact_damage_enabled or enemy_contact_damage <= 0 or enemy_contact_range <= 0.0:
		return

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
		var contact_enemy_id: int = _enemy_contact_id_in_range(player_position, enemy_positions)
		if contact_enemy_id > 0:
			if apply_enemy_damage_to_player(peer_id_int, enemy_contact_damage, contact_enemy_id, "contact"):
				_last_contact_damage_time_by_peer[peer_id] = now_seconds


func apply_enemy_melee_damage(peer_id: int, damage: int) -> bool:
	return apply_enemy_damage_to_player(peer_id, damage, 0, "melee")


func apply_enemy_damage_to_player(peer_id: int, raw_damage: int, enemy_id: int = 0, source_label: String = "enemy") -> bool:
	if not multiplayer.is_server() or raw_damage <= 0 or not players.has(peer_id):
		return false
	if bool(_player_is_down_by_peer.get(peer_id, false)):
		return false

	var current_hp: int = int(_player_current_hp_by_peer.get(peer_id, player_max_hp))
	if current_hp <= 0:
		return false

	if _roll_player_avoidance(peer_id, source_label, enemy_id):
		return true

	var final_damage: int = _modified_player_damage_taken(peer_id, raw_damage)
	current_hp = max(current_hp - final_damage, 0)
	_player_current_hp_by_peer[peer_id] = current_hp
	var max_hp: int = int(_player_max_hp_by_peer.get(peer_id, player_max_hp))
	rpc("apply_player_health_update", peer_id, current_hp, max_hp)
	if current_hp <= 0:
		_mark_player_down(peer_id)

	return true


func _roll_player_avoidance(peer_id: int, source_label: String, enemy_id: int = 0) -> bool:
	var combat_stats: Dictionary = _player_combat_stats_by_peer.get(peer_id, _default_player_combat_stats()) as Dictionary
	var avoidance_chance: float = clamp(float(combat_stats.get("avoidance", 0.0)), 0.0, PLAYER_AVOIDANCE_CAP)
	if avoidance_chance <= 0.0:
		return false

	var roll: float = randf()
	if roll >= avoidance_chance:
		return false

	print("Enemy attack avoided: peer_id=%s enemy_id=%s source=%s avoidance=%s roll=%s" % [
		peer_id,
		enemy_id,
		source_label,
		avoidance_chance,
		roll,
	])
	rpc_id(peer_id, "apply_status_message", peer_id, "Avoided")
	return true


func _modified_player_damage_taken(peer_id: int, raw_damage: int) -> int:
	var combat_stats: Dictionary = _player_combat_stats_by_peer.get(peer_id, _default_player_combat_stats()) as Dictionary
	var armor: float = clamp(float(combat_stats.get("armor", combat_stats.get("damage_reduction", 0.0))), 0.0, PLAYER_ARMOR_CAP)
	return max(int(round(float(raw_damage) * (1.0 - armor))), 1)


func _default_player_combat_stats() -> Dictionary:
	var stats: Dictionary = {}
	for stat_key in PLAYER_COMPUTED_STAT_DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_COMPUTED_STAT_DEFINITIONS[stat_key] as Dictionary
		stats[stat_key] = float(definition.get("base", 0.0))
	stats["max_hp"] = player_max_hp
	stats["move_speed"] = movement_speed
	return _finalize_player_combat_stats(stats)


func _recalculate_player_combat_stats(peer_id: int, restore_current_hp_to_max: bool = false) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var combat_stats: Dictionary = _default_player_combat_stats()
	_apply_ability_stat_modifiers(peer_id, combat_stats)
	_apply_equipped_item_stat_modifiers(peer_id, combat_stats)
	combat_stats = _finalize_player_combat_stats(combat_stats)
	_player_combat_stats_by_peer[peer_id] = combat_stats
	_apply_computed_player_max_hp(peer_id, int(combat_stats.get("max_hp", player_max_hp)), restore_current_hp_to_max)
	rpc_id(peer_id, "apply_player_combat_stats_update", peer_id, combat_stats)
	print("Player stats recomputed: peer_id=%s max_hp=%s move_speed=%s physical_power=%s spell_power=%s armor=%s avoidance=%s" % [
		peer_id,
		int(combat_stats.get("max_hp", player_max_hp)),
		float(combat_stats.get("move_speed", movement_speed)),
		float(combat_stats.get("physical_power", 0.0)),
		float(combat_stats.get("spell_power", 0.0)),
		float(combat_stats.get("armor", 0.0)),
		float(combat_stats.get("avoidance", 0.0)),
	])


func _computed_player_move_speed(peer_id: int) -> float:
	var combat_stats: Dictionary = _player_combat_stats_by_peer.get(peer_id, _default_player_combat_stats()) as Dictionary
	return clamp(float(combat_stats.get("move_speed", movement_speed)), MIN_PLAYER_MOVE_SPEED, MAX_PLAYER_MOVE_SPEED)


func _finalize_player_combat_stats(combat_stats: Dictionary) -> Dictionary:
	for stat_key in PLAYER_COMPUTED_STAT_DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_COMPUTED_STAT_DEFINITIONS[stat_key] as Dictionary
		if not combat_stats.has(stat_key):
			combat_stats[stat_key] = float(definition.get("base", 0.0))

	combat_stats["max_hp"] = max(int(round(float(combat_stats.get("max_hp", player_max_hp)))), 1)
	combat_stats["move_speed"] = clamp(float(combat_stats.get("move_speed", movement_speed)), MIN_PLAYER_MOVE_SPEED, MAX_PLAYER_MOVE_SPEED)
	combat_stats["physical_power"] = float(combat_stats.get("physical_power", 0.0))
	combat_stats["spell_power"] = float(combat_stats.get("spell_power", 0.0))
	combat_stats["armor"] = clamp(float(combat_stats.get("armor", 0.0)), 0.0, PLAYER_ARMOR_CAP)
	combat_stats["avoidance"] = clamp(float(combat_stats.get("avoidance", 0.0)), 0.0, PLAYER_AVOIDANCE_CAP)
	combat_stats["attack_power"] = combat_stats["physical_power"]
	combat_stats["damage_reduction"] = combat_stats["armor"]
	return combat_stats


func _canonical_player_stat_key(raw_stat_key: String) -> String:
	var stat_key: String = raw_stat_key.strip_edges().to_lower()
	return str(PLAYER_STAT_ALIASES.get(stat_key, stat_key))


func _apply_ability_stat_modifiers(peer_id: int, combat_stats: Dictionary) -> void:
	var loadout: Array = _loadout_by_peer.get(peer_id, []) as Array
	var ability_keys: Dictionary = _ability_keys_by_peer.get(peer_id, {}) as Dictionary
	for ability_name in loadout:
		var ability_name_text: String = str(ability_name)
		var ability_key: String = str(ability_keys.get(ability_name_text, _server_ability_key(ability_name_text))).strip_edges().to_lower()
		var stat_modifiers: Array = _ability_stat_modifiers(ability_key)
		for modifier_variant in stat_modifiers:
			if not (modifier_variant is Dictionary):
				continue

			_apply_stat_modifier_to_combat_stats(combat_stats, modifier_variant as Dictionary)


func _apply_equipped_item_stat_modifiers(peer_id: int, combat_stats: Dictionary) -> void:
	var equipment: Dictionary = _character_equipment_by_peer.get(peer_id, {}) as Dictionary
	for slot_name in equipment.keys():
		var slot_data: Variant = equipment[slot_name]
		if not (slot_data is Dictionary):
			continue

		var equipment_item: Dictionary = slot_data as Dictionary
		var stat_modifiers: Array = _equipment_item_stat_modifiers(equipment_item)
		for modifier_variant in stat_modifiers:
			if not (modifier_variant is Dictionary):
				continue

			_apply_stat_modifier_to_combat_stats(combat_stats, modifier_variant as Dictionary)


func _equipment_item_stat_modifiers(equipment_item: Dictionary) -> Array:
	var raw_modifiers: Variant = equipment_item.get("stat_modifiers", [])
	if raw_modifiers is Array:
		return (raw_modifiers as Array).duplicate(true)
	if raw_modifiers is Dictionary:
		var modifiers: Array = []
		var raw_modifier_dictionary: Dictionary = raw_modifiers as Dictionary
		for stat_key in raw_modifier_dictionary.keys():
			modifiers.append({
				"stat_key": str(stat_key),
				"modifier_type": "flat",
				"value": raw_modifier_dictionary[stat_key],
			})
		return modifiers

	return []


func _apply_stat_modifier_to_combat_stats(combat_stats: Dictionary, modifier: Dictionary) -> void:
	var stat_key: String = _canonical_player_stat_key(str(modifier.get("stat_key", modifier.get("key", modifier.get("stat", "")))))
	if not SUPPORTED_PLAYER_STAT_KEYS.has(stat_key):
		return

	var modifier_type: String = str(modifier.get("modifier_type", modifier.get("type", "flat"))).strip_edges().to_lower()
	var value: float = float(modifier.get("value", modifier.get("amount", 0.0)))
	if modifier_type == "":
		modifier_type = "flat"

	match stat_key:
		"max_hp":
			if _is_percent_modifier(modifier_type):
				combat_stats["max_hp"] = int(round(float(combat_stats.get("max_hp", player_max_hp)) * (1.0 + _percent_modifier_value(value))))
			else:
				combat_stats["max_hp"] = int(round(float(combat_stats.get("max_hp", player_max_hp)) + value))
		"armor", "avoidance":
			var chance_delta: float = _percent_modifier_value(value)
			combat_stats[stat_key] = float(combat_stats.get(stat_key, 0.0)) + chance_delta
		"physical_power", "spell_power", "move_speed":
			if _is_percent_modifier(modifier_type):
				combat_stats[stat_key] = float(combat_stats.get(stat_key, 0.0)) * (1.0 + _percent_modifier_value(value))
			else:
				combat_stats[stat_key] = float(combat_stats.get(stat_key, 0.0)) + value


func _is_percent_modifier(modifier_type: String) -> bool:
	return modifier_type == "percent" or modifier_type == "percentage" or modifier_type == "pct"


func _percent_modifier_value(value: float) -> float:
	if abs(value) > 1.0:
		return value / 100.0

	return value


func _apply_computed_player_max_hp(peer_id: int, computed_max_hp: int, restore_current_hp_to_max: bool = false) -> void:
	if not players.has(peer_id):
		return

	var new_max_hp: int = max(computed_max_hp, 1)
	var old_max_hp: int = int(_player_max_hp_by_peer.get(peer_id, player_max_hp))
	var current_hp: int = int(_player_current_hp_by_peer.get(peer_id, old_max_hp))
	var old_current_hp: int = current_hp
	if restore_current_hp_to_max:
		current_hp = new_max_hp
	else:
		current_hp = min(current_hp, new_max_hp)

	_player_max_hp_by_peer[peer_id] = new_max_hp
	_player_current_hp_by_peer[peer_id] = current_hp
	if new_max_hp != old_max_hp or current_hp != old_current_hp:
		rpc("apply_player_health_update", peer_id, current_hp, new_max_hp)


func _mark_player_down(peer_id: int) -> void:
	if bool(_player_is_down_by_peer.get(peer_id, false)):
		return

	_player_is_down_by_peer[peer_id] = true
	_last_input_by_peer[peer_id] = Vector2.ZERO
	rpc("apply_player_down_state", peer_id, true)
	_send_ability_states(peer_id)
	_broadcast_hp_regen_active_state(peer_id)
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
	_recalculate_player_combat_stats(peer_id, true)
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
	_send_ability_states(peer_id)
	_broadcast_hp_regen_active_state(peer_id)
	print("Player peer %s respawned." % peer_id)


func _enemy_contact_id_in_range(player_position: Vector3, enemy_positions: Dictionary) -> int:
	for enemy_id in enemy_positions:
		var enemy_position: Vector3 = enemy_positions[enemy_id] as Vector3
		var offset_xz: Vector2 = Vector2(enemy_position.x - player_position.x, enemy_position.z - player_position.z)
		if offset_xz.length() <= enemy_contact_range:
			return int(enemy_id)

	return 0


func _process_prototype_loot_pickups() -> void:
	if _loot_orbs.is_empty() or prototype_loot_pickup_radius <= 0.0:
		return

	for peer_id in players:
		var peer_id_int: int = int(peer_id)
		for loot_orb_id in _loot_orbs.keys():
			if _validate_prototype_loot_pickup(peer_id_int, int(loot_orb_id)):
				_complete_prototype_loot_pickup(peer_id_int, int(loot_orb_id))
				break


func _validate_prototype_loot_pickup(peer_id: int, loot_orb_id: int) -> bool:
	# A peer appears in players only after server-side join validation/register.
	if not players.has(peer_id):
		return false
	if bool(_player_is_down_by_peer.get(peer_id, false)):
		return false

	var current_hp: int = int(_player_current_hp_by_peer.get(peer_id, player_max_hp))
	if current_hp <= 0:
		return false
	if not _loot_orbs.has(loot_orb_id):
		return false

	var loot_data: Dictionary = _loot_orbs[loot_orb_id] as Dictionary
	if not bool(loot_data.get("active", false)):
		return false
	if int(loot_data.get("owner_peer_id", 0)) != peer_id:
		return false

	var player_position: Vector3 = players[peer_id] as Vector3
	var loot_position: Vector3 = loot_data.get("position", Vector3.ZERO) as Vector3
	return _distance_xz(player_position, loot_position) <= prototype_loot_pickup_radius


func _complete_prototype_loot_pickup(peer_id: int, loot_orb_id: int) -> void:
	if not _loot_orbs.has(loot_orb_id):
		return

	var loot_data: Dictionary = _loot_orbs[loot_orb_id] as Dictionary
	loot_data["active"] = false
	_loot_orbs[loot_orb_id] = loot_data
	var reward_payload: Dictionary = loot_data.get("reward_payload", {}) as Dictionary
	loot_reward_pickup_requested.emit(peer_id, loot_orb_id, reward_payload.duplicate(true))


func confirm_loot_pickup(loot_orb_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not _loot_orbs.has(loot_orb_id):
		return

	_loot_orbs.erase(loot_orb_id)
	rpc("despawn_loot_orb", loot_orb_id)


func reject_loot_pickup(loot_orb_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not _loot_orbs.has(loot_orb_id):
		return

	var loot_data: Dictionary = _loot_orbs[loot_orb_id] as Dictionary
	loot_data["active"] = true
	_loot_orbs[loot_orb_id] = loot_data


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
			_send_ability_state(peer_id_int, "Slash")
			_perform_slash(peer_id_int)
		if loadout.has("HP Regen") and _is_ability_enabled(peer_id_int, "HP Regen") and _is_ability_ready(peer_id_int, "HP Regen", now_seconds):
			_set_ability_used(peer_id_int, "HP Regen", now_seconds)
			_send_ability_state(peer_id_int, "HP Regen")
			_apply_hp_regen(peer_id_int)
		if loadout.has("Damage Aura") and _is_ability_enabled(peer_id_int, "Damage Aura") and _is_ability_ready(peer_id_int, "Damage Aura", now_seconds):
			_set_ability_used(peer_id_int, "Damage Aura", now_seconds)
			_send_ability_state(peer_id_int, "Damage Aura")
			_perform_damage_aura(peer_id_int)
		if loadout.has("Firebolt") and _is_ability_enabled(peer_id_int, "Firebolt") and _is_ability_ready(peer_id_int, "Firebolt", now_seconds):
			_set_ability_used(peer_id_int, "Firebolt", now_seconds)
			_send_ability_state(peer_id_int, "Firebolt")
			_perform_firebolt(peer_id_int)
		if loadout.has("Shoot") and _is_ability_enabled(peer_id_int, "Shoot") and _is_ability_ready(peer_id_int, "Shoot", now_seconds):
			_set_ability_used(peer_id_int, "Shoot", now_seconds)
			_send_ability_state(peer_id_int, "Shoot")
			_perform_shoot(peer_id_int)


func _default_ability_enabled_state() -> Dictionary:
	var ability_state: Dictionary = {}
	for ability_name in DEFAULT_LOADOUT:
		ability_state[ability_name] = true

	return ability_state


func _ability_enabled_state_for_loadout(loadout: Array, ability_enabled: Dictionary) -> Dictionary:
	var ability_state: Dictionary = {}
	for ability_name in loadout:
		ability_state[ability_name] = bool(ability_enabled.get(ability_name, true))

	return ability_state


func _ability_keys_for_loadout(loadout: Array, ability_keys: Dictionary) -> Dictionary:
	var keys: Dictionary = {}
	for ability_name in loadout:
		var ability_name_text: String = str(ability_name)
		keys[ability_name_text] = str(ability_keys.get(ability_name_text, _server_ability_key(ability_name_text))).strip_edges().to_lower()

	return keys


func _ability_slot_indexes_for_loadout(loadout: Array, ability_slot_indexes: Dictionary) -> Dictionary:
	var slot_indexes: Dictionary = {}
	for slot_index in range(loadout.size()):
		var ability_name_text: String = str(loadout[slot_index])
		slot_indexes[ability_name_text] = int(ability_slot_indexes.get(ability_name_text, slot_index))

	return slot_indexes


func _ability_display_names_for_loadout(loadout: Array, ability_display_names: Dictionary) -> Dictionary:
	var display_names: Dictionary = {}
	for ability_name in loadout:
		var ability_name_text: String = str(ability_name)
		display_names[ability_name_text] = str(ability_display_names.get(ability_name_text, ability_name_text))

	return display_names


func load_backend_ability_runtime_configs(response_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var backend_abilities: Array = _extract_backend_runtime_abilities(response_data)
	if backend_abilities.is_empty():
		print("Backend ability runtime config response had no usable ability entries. Using fallback Godot ability configs.")
		_use_fallback_ability_runtime_configs()
		_log_ability_runtime_config_status([], _supported_ability_config_keys())
		return

	var loaded_configs: Dictionary = SERVER_ABILITY_CONFIGS.duplicate(true)
	var loaded_keys: Array[String] = []
	var fallback_keys: Array[String] = []
	for ability_variant in backend_abilities:
		if not ability_variant is Dictionary:
			continue

		var backend_ability: Dictionary = ability_variant as Dictionary
		var ability_key: String = str(backend_ability.get("ability_key", "")).strip_edges()
		if ability_key == "" or not SERVER_ABILITY_CONFIGS.has(ability_key):
			continue

		var fallback_config: Dictionary = SERVER_ABILITY_CONFIGS[ability_key] as Dictionary
		var merged_config: Dictionary = (loaded_configs[ability_key] as Dictionary).duplicate(true)
		var used_fallback: bool = false

		used_fallback = not _copy_valid_backend_string(backend_ability, merged_config, "behavior_key", "behavior_key") or used_fallback
		used_fallback = not _copy_valid_backend_string(backend_ability, merged_config, "visual_key", "visual_key") or used_fallback
		used_fallback = not _copy_valid_backend_float(backend_ability, merged_config, "cooldown_seconds", "cooldown_seconds") or used_fallback

		var loaded_damage_effect: Dictionary = _extract_ability_damage_effect(backend_ability)
		if fallback_config.has("damage") and loaded_damage_effect.is_empty():
			used_fallback = not _copy_valid_backend_int(backend_ability, merged_config, "damage", "damage") or used_fallback
		elif not loaded_damage_effect.is_empty():
			merged_config["damage_effect"] = loaded_damage_effect
			merged_config["damage"] = int(loaded_damage_effect.get("value", merged_config.get("damage", 0)))
		if fallback_config.has("heal"):
			used_fallback = not _copy_valid_backend_int(backend_ability, merged_config, "healing", "heal") or used_fallback
		if fallback_config.has("range"):
			used_fallback = not _copy_valid_backend_float(backend_ability, merged_config, "range", "range") or used_fallback
		if fallback_config.has("radius"):
			used_fallback = not _copy_valid_backend_float(backend_ability, merged_config, "radius", "radius") or used_fallback
		if fallback_config.has("projectile_speed"):
			used_fallback = not _copy_valid_backend_float(backend_ability, merged_config, "projectile_speed", "projectile_speed") or used_fallback
		var loaded_stat_modifiers: Array = _extract_ability_stat_modifiers(backend_ability)
		if loaded_stat_modifiers.is_empty():
			if fallback_config.has("stat_modifiers"):
				used_fallback = true
		else:
			merged_config["stat_modifiers"] = loaded_stat_modifiers
		if fallback_config.has("width"):
			used_fallback = not _copy_valid_backend_float(backend_ability, merged_config, "radius", "width") or used_fallback
		if fallback_config.has("arc_angle"):
			used_fallback = not _copy_valid_backend_float(backend_ability, merged_config, "arc_angle_degrees", "arc_angle") or used_fallback
		if fallback_config.has("tick_seconds"):
			var loaded_tick: bool = _copy_valid_backend_float(backend_ability, merged_config, "tick_seconds", "tick_seconds")
			used_fallback = not loaded_tick or used_fallback
			if loaded_tick:
				merged_config["cooldown_seconds"] = float(merged_config.get("tick_seconds", fallback_config.get("tick_seconds", 1.0)))

		loaded_configs[ability_key] = merged_config
		if not loaded_keys.has(ability_key):
			loaded_keys.append(ability_key)
		if used_fallback and not fallback_keys.has(ability_key):
			fallback_keys.append(ability_key)

	for fallback_key in SERVER_ABILITY_CONFIGS.keys():
		var fallback_key_text: String = str(fallback_key)
		if not loaded_keys.has(fallback_key_text):
			fallback_keys.append(fallback_key_text)

	_server_ability_configs = loaded_configs
	_log_ability_runtime_config_status(loaded_keys, fallback_keys)


func _use_fallback_ability_runtime_configs() -> void:
	_server_ability_configs = SERVER_ABILITY_CONFIGS.duplicate(true)


func _supported_ability_config_keys() -> Array[String]:
	var ability_keys: Array[String] = []
	for ability_key in SERVER_ABILITY_CONFIGS.keys():
		ability_keys.append(str(ability_key))
	return ability_keys


func _extract_backend_runtime_abilities(response_data: Dictionary) -> Array:
	var abilities: Array = []
	var raw_abilities: Variant = response_data.get("unlocked_abilities", [])
	if not raw_abilities is Array:
		return abilities

	for ability_variant in (raw_abilities as Array):
		if not ability_variant is Dictionary:
			continue

		var ability: Dictionary = ability_variant as Dictionary
		var definition: Variant = ability.get("definition", {})
		var runtime_ability: Dictionary = {}
		if definition is Dictionary:
			runtime_ability = (definition as Dictionary).duplicate(true)
		for key in ability.keys():
			if str(key) == "definition":
				continue
			runtime_ability[key] = ability[key]
		abilities.append(runtime_ability)

	return abilities


func _copy_valid_backend_string(source: Dictionary, target: Dictionary, source_key: String, target_key: String) -> bool:
	if not source.has(source_key) or source[source_key] == null:
		return false

	var value: String = str(source[source_key]).strip_edges()
	if value == "":
		return false

	target[target_key] = value
	return true


func _copy_valid_backend_int(source: Dictionary, target: Dictionary, source_key: String, target_key: String) -> bool:
	var parsed_value: Variant = _valid_backend_float_value(source, source_key)
	if parsed_value == null:
		return false

	var value: int = int(parsed_value)
	if value <= 0:
		return false

	target[target_key] = value
	return true


func _copy_valid_backend_float(source: Dictionary, target: Dictionary, source_key: String, target_key: String) -> bool:
	var parsed_value: Variant = _valid_backend_float_value(source, source_key)
	if parsed_value == null:
		return false

	var value: float = float(parsed_value)
	if value <= 0.0:
		return false

	target[target_key] = value
	return true


func _valid_backend_float_value(source: Dictionary, source_key: String) -> Variant:
	if not source.has(source_key) or source[source_key] == null:
		return null

	var value: Variant = source[source_key]
	if value is int or value is float:
		return value
	if value is String:
		var text: String = str(value).strip_edges()
		if text.is_valid_float():
			return text.to_float()

	return null


func _log_ability_runtime_config_status(loaded_keys: Array, fallback_keys: Array = []) -> void:
	loaded_keys.sort()
	fallback_keys.sort()
	print("Backend ability runtime configs loaded for keys: %s." % _format_key_list(loaded_keys))
	if fallback_keys.is_empty():
		print("Backend ability runtime configs supplied all supported fallback fields.")
	else:
		print("Using fallback ability runtime values for keys: %s." % _format_key_list(fallback_keys))


func _format_key_list(keys: Array) -> String:
	if keys.is_empty():
		return "(none)"

	var packed_keys: PackedStringArray = PackedStringArray()
	for key in keys:
		packed_keys.append(str(key))
	return ", ".join(packed_keys)


func _is_ability_enabled(peer_id: int, ability_name: String) -> bool:
	var ability_state: Dictionary = _ability_enabled_by_peer.get(peer_id, {}) as Dictionary
	return bool(ability_state.get(ability_name, false))


func _is_hp_regen_active(peer_id: int) -> bool:
	var combat_enabled: bool = bool(_combat_enabled_by_peer.get(peer_id, false))
	var hp_regen_enabled: bool = _is_ability_enabled(peer_id, "HP Regen")
	var is_down: bool = bool(_player_is_down_by_peer.get(peer_id, false))
	return combat_enabled and hp_regen_enabled and not is_down


func _broadcast_hp_regen_active_state(peer_id: int) -> void:
	rpc("apply_hp_regen_active_state", peer_id, _is_hp_regen_active(peer_id))


func _send_ability_enabled_states(peer_id: int) -> void:
	var loadout: Array = _loadout_by_peer.get(peer_id, DEFAULT_LOADOUT) as Array
	var ability_state: Dictionary = _ability_enabled_by_peer.get(peer_id, {}) as Dictionary
	for ability_name in loadout:
		var ability_name_text: String = str(ability_name)
		rpc_id(peer_id, "apply_ability_enabled_update", peer_id, ability_name_text, bool(ability_state.get(ability_name_text, true)))


func _send_ability_states(peer_id: int) -> void:
	var loadout: Array = _loadout_by_peer.get(peer_id, DEFAULT_LOADOUT) as Array
	for ability_name in loadout:
		_send_ability_state(peer_id, str(ability_name))


func apply_confirmed_ability_data(peer_id: int, loadout: Array, ability_enabled: Dictionary, ability_display_names: Dictionary, ability_keys: Dictionary, unlocked_abilities: Array, ability_slot_indexes: Dictionary) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	_loadout_by_peer[peer_id] = loadout.duplicate()
	_ability_keys_by_peer[peer_id] = _ability_keys_for_loadout(loadout, ability_keys)
	_ability_slot_indexes_by_peer[peer_id] = _ability_slot_indexes_for_loadout(loadout, ability_slot_indexes)
	_ability_display_names_by_peer[peer_id] = _ability_display_names_for_loadout(loadout, ability_display_names)
	_unlocked_abilities_by_peer[peer_id] = unlocked_abilities.duplicate()
	_ability_enabled_by_peer[peer_id] = _ability_enabled_state_for_loadout(loadout, ability_enabled)
	_last_ability_time_by_peer[peer_id] = {}
	_recalculate_player_combat_stats(peer_id)
	rpc_id(peer_id, "apply_ability_catalog_update", peer_id, _unlocked_abilities_by_peer[peer_id] as Array)
	rpc("apply_combat_mode_update", peer_id, bool(_combat_enabled_by_peer.get(peer_id, false)), _loadout_entries(peer_id))
	_send_ability_enabled_states(peer_id)
	_send_ability_states(peer_id)
	_broadcast_hp_regen_active_state(peer_id)


func _send_ability_state(peer_id: int, ability_name: String) -> void:
	if not players.has(peer_id):
		return

	var enabled: bool = _is_ability_enabled(peer_id, ability_name)
	var active: bool = bool(_combat_enabled_by_peer.get(peer_id, false)) and enabled and not bool(_player_is_down_by_peer.get(peer_id, false))
	var cooldown_remaining: float = _ability_cooldown_remaining(peer_id, ability_name)
	rpc_id(peer_id, "apply_ability_state_update", peer_id, ability_name, enabled, active, cooldown_remaining)


func _is_ability_ready(peer_id: int, ability_name: String, now_seconds: float) -> bool:
	var ability_state: Dictionary = _last_ability_time_by_peer.get(peer_id, {}) as Dictionary
	var last_used: float = float(ability_state.get(ability_name, -_ability_cooldown(ability_name)))
	return now_seconds - last_used >= _ability_cooldown(ability_name)


func _ability_cooldown_remaining(peer_id: int, ability_name: String) -> float:
	var ability_state: Dictionary = _last_ability_time_by_peer.get(peer_id, {}) as Dictionary
	var last_used: float = float(ability_state.get(ability_name, -_ability_cooldown(ability_name)))
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	return max(_ability_cooldown(ability_name) - (now_seconds - last_used), 0.0)


func _set_ability_used(peer_id: int, ability_name: String, now_seconds: float) -> void:
	var ability_state: Dictionary = _last_ability_time_by_peer.get(peer_id, {}) as Dictionary
	ability_state[ability_name] = now_seconds
	_last_ability_time_by_peer[peer_id] = ability_state


func _ability_cooldown(ability_name: String) -> float:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return float(ability_config.get("cooldown_seconds", 1.0))


func _ability_heal_amount(ability_name: String) -> int:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return int(ability_config.get("heal", 0))


func _ability_damage_amount(peer_id: int, ability_name: String) -> int:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	var ability_key: String = _server_ability_key(ability_name)
	var damage_effect: Dictionary = _ability_damage_effect(ability_config)
	var base_damage: float = float(damage_effect.get("value", ability_config.get("damage", 0)))
	var scaling_stat_key: String = _canonical_player_stat_key(str(damage_effect.get("scaling_stat_key", "")))
	var scaling_ratio: float = float(damage_effect.get("scaling_ratio", 0.0))
	var final_damage: float = base_damage
	if scaling_stat_key != "" and scaling_ratio > 0.0:
		var combat_stats: Dictionary = _player_combat_stats_by_peer.get(peer_id, _default_player_combat_stats()) as Dictionary
		var scaling_stat_value: float = float(combat_stats.get(scaling_stat_key, 0.0))
		final_damage = base_damage + scaling_stat_value * scaling_ratio
		var rounded_damage: int = max(int(round(final_damage)), 0)
		print("Ability damage scaled: peer_id=%s ability_key=%s base_damage=%s scaling_stat_key=%s scaling_stat_value=%s scaling_ratio=%s final_damage=%s" % [
			peer_id,
			ability_key,
			int(round(base_damage)),
			scaling_stat_key,
			scaling_stat_value,
			scaling_ratio,
			rounded_damage,
		])
		return rounded_damage

	return max(int(round(final_damage)), 0)


func _ability_damage_effect(ability_config: Dictionary) -> Dictionary:
	var raw_damage_effect: Variant = ability_config.get("damage_effect", {})
	if raw_damage_effect is Dictionary:
		return (raw_damage_effect as Dictionary).duplicate(true)

	return {"value": float(ability_config.get("damage", 0))}


func _extract_ability_damage_effect(ability_data: Dictionary) -> Dictionary:
	for container_variant in _ability_effect_containers(ability_data):
		if not (container_variant is Dictionary):
			continue

		var damage_effect: Dictionary = _normalize_damage_effect(container_variant as Dictionary)
		if not damage_effect.is_empty():
			return damage_effect

	return {}


func _ability_effect_containers(ability_data: Dictionary) -> Array:
	var containers: Array = [ability_data]
	var effects: Variant = ability_data.get("effects", ability_data.get("ability_effects", []))
	if effects is Array:
		for effect_variant in (effects as Array):
			if effect_variant is Dictionary:
				containers.append(effect_variant as Dictionary)
	elif effects is Dictionary:
		containers.append(effects as Dictionary)
	return containers


func _normalize_damage_effect(effect_data: Dictionary) -> Dictionary:
	var effect_type: String = str(effect_data.get("effect_type", effect_data.get("type", ""))).strip_edges().to_lower()
	if effect_type == "stat_modifier":
		return {}

	var has_damage_metadata: bool = effect_data.has("damage_school") or effect_data.has("scaling_stat_key") or effect_data.has("scaling_ratio")
	var is_damage_effect: bool = effect_type == "damage" or effect_type == "direct_damage" or effect_type == "area_damage" or effect_type == "aoe_damage" or has_damage_metadata
	if not is_damage_effect:
		return {}

	var raw_value: Variant = _first_present_value(effect_data, ["value", "damage", "amount", "damage_amount", "base_damage"])
	if raw_value == null:
		return {}

	var value: float = _variant_to_float(raw_value, -1.0)
	if value <= 0.0:
		return {}

	var damage_effect: Dictionary = {
		"value": value,
	}
	var damage_school: String = str(effect_data.get("damage_school", "")).strip_edges().to_lower()
	if damage_school != "":
		damage_effect["damage_school"] = damage_school
	var scaling_stat_key: String = str(effect_data.get("scaling_stat_key", "")).strip_edges().to_lower()
	if scaling_stat_key != "":
		damage_effect["scaling_stat_key"] = scaling_stat_key
	damage_effect["scaling_ratio"] = max(_variant_to_float(effect_data.get("scaling_ratio", 0.0), 0.0), 0.0)
	return damage_effect


func _first_present_value(source: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if source.has(key) and source[key] != null:
			return source[key]

	return null


func _variant_to_float(value: Variant, fallback: float = 0.0) -> float:
	if value is int or value is float:
		return float(value)
	if value is String:
		var text: String = str(value).strip_edges()
		if text.is_valid_float():
			return text.to_float()

	return fallback


func _ability_radius(ability_name: String) -> float:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return float(ability_config.get("radius", 0.0))


func _ability_range(ability_name: String) -> float:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return float(ability_config.get("range", 0.0))


func _ability_arc_angle(ability_name: String) -> float:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return float(ability_config.get("arc_angle", 0.0))


func _ability_width(ability_name: String) -> float:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return float(ability_config.get("width", 0.0))


func _ability_projectile_speed(ability_name: String) -> float:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return float(ability_config.get("projectile_speed", 12.0))


func _ability_stat_modifiers(ability_name: String) -> Array:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return _extract_ability_stat_modifiers(ability_config)


func _extract_ability_stat_modifiers(ability_data: Dictionary) -> Array:
	var modifier_candidates: Array = []
	for container_variant in _ability_stat_modifier_containers(ability_data):
		if not (container_variant is Dictionary):
			continue

		var container: Dictionary = container_variant as Dictionary
		if _is_stat_modifier_data(container):
			modifier_candidates.append(container)
		var raw_modifiers: Variant = container.get("stat_modifiers", container.get("modifiers", container.get("stats", [])))
		if raw_modifiers is Array:
			modifier_candidates.append_array(raw_modifiers as Array)
		elif raw_modifiers is Dictionary:
			var raw_modifier_dictionary: Dictionary = raw_modifiers as Dictionary
			for stat_key in raw_modifier_dictionary.keys():
				modifier_candidates.append({
					"stat_key": str(stat_key),
					"modifier_type": "flat",
					"value": raw_modifier_dictionary[stat_key],
				})

	var modifiers: Array = []
	for modifier_variant in modifier_candidates:
		if not (modifier_variant is Dictionary):
			continue

		var modifier: Dictionary = _normalize_stat_modifier(modifier_variant as Dictionary)
		if not modifier.is_empty():
			modifiers.append(modifier)
	return modifiers


func _is_stat_modifier_data(modifier_data: Dictionary) -> bool:
	var effect_type: String = str(modifier_data.get("effect_type", "")).strip_edges().to_lower()
	if effect_type != "" and effect_type != "stat_modifier":
		return false
	var target_team: String = str(modifier_data.get("target_team", "")).strip_edges().to_lower()
	if target_team != "" and target_team != "self":
		return false

	return (
		modifier_data.has("stat_key")
		or modifier_data.has("key")
		or modifier_data.has("stat")
		or modifier_data.has("stat_name")
		or modifier_data.has("attribute")
		or modifier_data.has("effect_key")
	)


func _ability_stat_modifier_containers(ability_data: Dictionary) -> Array:
	return _ability_effect_containers(ability_data)


func _normalize_stat_modifier(modifier_data: Dictionary) -> Dictionary:
	var raw_stat_key: Variant = modifier_data.get(
		"stat_key",
		modifier_data.get(
			"key",
			modifier_data.get(
				"stat",
				modifier_data.get(
					"stat_name",
					modifier_data.get("attribute", modifier_data.get("effect_key", ""))
				)
			)
		)
	)
	var stat_key: String = _canonical_player_stat_key(str(raw_stat_key))
	var modifier_type: String = str(modifier_data.get("modifier_type", modifier_data.get("type", "flat"))).strip_edges().to_lower()
	var value: float = float(modifier_data.get("value", modifier_data.get("amount", 0.0)))
	if stat_key == "" or is_zero_approx(value):
		return {}
	if modifier_type == "":
		modifier_type = "flat"

	return {
		"stat_key": stat_key,
		"modifier_type": modifier_type,
		"value": value,
	}


func _ability_visual_key(ability_name: String) -> String:
	var ability_config: Dictionary = _server_ability_config(ability_name)
	return str(ability_config.get("visual_key", ""))


func _server_ability_config(ability_name: String) -> Dictionary:
	var ability_key: String = _server_ability_key(ability_name)
	return _server_ability_configs.get(ability_key, SERVER_ABILITY_CONFIGS.get(ability_key, {})) as Dictionary


func _server_ability_key(ability_name: String) -> String:
	var normalized_name: String = ability_name.strip_edges()
	if _server_ability_configs.has(normalized_name) or SERVER_ABILITY_CONFIGS.has(normalized_name):
		return normalized_name

	return str(ABILITY_KEY_BY_DISPLAY_NAME.get(normalized_name, normalized_name.to_snake_case()))


func _apply_hp_regen(peer_id: int) -> void:
	var current_hp: int = int(_player_current_hp_by_peer.get(peer_id, player_max_hp))
	var max_hp: int = int(_player_max_hp_by_peer.get(peer_id, player_max_hp))
	if current_hp <= 0 or current_hp >= max_hp:
		return

	current_hp = int(min(current_hp + _ability_heal_amount("HP Regen"), max_hp))
	_player_current_hp_by_peer[peer_id] = current_hp
	rpc("apply_player_health_update", peer_id, current_hp, max_hp)


func _perform_damage_aura(peer_id: int) -> void:
	var aura_position: Vector3 = players[peer_id] as Vector3
	var ability_config: Dictionary = _server_ability_config("Damage Aura")
	var radius: float = float(ability_config.get("radius", 0.0))
	var damage: int = _ability_damage_amount(peer_id, "Damage Aura")
	if radius <= 0.0 or damage <= 0:
		return

	rpc("show_damage_aura", peer_id, aura_position, radius, _ability_visual_key("Damage Aura"))
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner != null:
		enemy_spawner.call("resolve_damage_aura", peer_id, aura_position, radius, damage)


func _perform_firebolt(peer_id: int) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var player_position: Vector3 = players[peer_id] as Vector3
	var aim_direction: Vector2 = _aim_direction_by_peer.get(peer_id, Vector2(0.0, -1.0)) as Vector2
	if aim_direction.length_squared() <= 0.0001:
		aim_direction = Vector2(0.0, -1.0)

	var fixed_direction: Vector2 = aim_direction.normalized()
	var ability_config: Dictionary = _server_ability_config("Firebolt")
	var projectile_range: float = float(ability_config.get("range", 0.0))
	var explosion_radius: float = float(ability_config.get("radius", 0.0))
	var projectile_speed: float = _ability_projectile_speed("Firebolt")
	var damage: int = _ability_damage_amount(peer_id, "Firebolt")
	if projectile_range <= 0.0 or explosion_radius <= 0.0 or projectile_speed <= 0.0 or damage <= 0:
		return

	var projectile_id: int = _next_projectile_id
	_next_projectile_id += 1
	var start_position: Vector3 = player_position + Vector3(fixed_direction.x, 0.0, fixed_direction.y) * 0.65
	var visual_key: String = _ability_visual_key("Firebolt")
	_server_projectiles[projectile_id] = {
		"projectile_id": projectile_id,
		"owner_peer_id": peer_id,
		"ability_name": "Firebolt",
		"behavior_key": "projectile_aoe_damage",
		"position": start_position,
		"fixed_direction": fixed_direction,
		"speed": projectile_speed,
		"max_range": projectile_range,
		"radius": explosion_radius,
		"damage": damage,
		"visual_key": visual_key,
		"distance_traveled": 0.0,
	}
	rpc("spawn_fireball_projectile", projectile_id, start_position, fixed_direction, projectile_speed, projectile_range, visual_key)
	print("Fireball spawned: peer_id=%s projectile_id=%s start_position=%s fixed_direction=%s speed=%s range=%s radius=%s" % [peer_id, projectile_id, start_position, fixed_direction, projectile_speed, projectile_range, explosion_radius])


func _perform_shoot(peer_id: int) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var player_position: Vector3 = players[peer_id] as Vector3
	var aim_direction: Vector2 = _aim_direction_by_peer.get(peer_id, Vector2(0.0, -1.0)) as Vector2
	if aim_direction.length_squared() <= 0.0001:
		aim_direction = Vector2(0.0, -1.0)

	var fixed_direction: Vector2 = aim_direction.normalized()
	var ability_config: Dictionary = _server_ability_config("Shoot")
	var behavior_key: String = str(ability_config.get("behavior_key", "projectile_single_target")).strip_edges()
	var projectile_range: float = float(ability_config.get("range", 0.0))
	var hit_radius: float = float(ability_config.get("radius", 0.0))
	var projectile_speed: float = _ability_projectile_speed("Shoot")
	var damage: int = _ability_damage_amount(peer_id, "Shoot")
	if behavior_key != "projectile_single_target" or projectile_range <= 0.0 or hit_radius <= 0.0 or projectile_speed <= 0.0 or damage <= 0:
		return

	var projectile_id: int = _next_projectile_id
	_next_projectile_id += 1
	var start_position: Vector3 = player_position + Vector3(fixed_direction.x, 0.0, fixed_direction.y) * 0.65
	var visual_key: String = _ability_visual_key("Shoot")
	_server_projectiles[projectile_id] = {
		"projectile_id": projectile_id,
		"owner_peer_id": peer_id,
		"ability_name": "Shoot",
		"behavior_key": behavior_key,
		"position": start_position,
		"fixed_direction": fixed_direction,
		"speed": projectile_speed,
		"max_range": projectile_range,
		"radius": hit_radius,
		"damage": damage,
		"visual_key": visual_key,
		"distance_traveled": 0.0,
	}
	rpc("spawn_fireball_projectile", projectile_id, start_position, fixed_direction, projectile_speed, projectile_range, visual_key)
	print("Shoot fired: peer_id=%s projectile_id=%s damage=%s range=%s speed=%s fixed_direction=%s" % [peer_id, projectile_id, damage, projectile_range, projectile_speed, fixed_direction])


func _process_fireball_projectiles(delta: float) -> void:
	if _server_projectiles.is_empty():
		return

	var projectile_ids: Array = _server_projectiles.keys()
	for projectile_id_variant in projectile_ids:
		var projectile_id: int = int(projectile_id_variant)
		if not _server_projectiles.has(projectile_id):
			continue

		var projectile: Dictionary = _server_projectiles[projectile_id] as Dictionary
		var fixed_direction: Vector2 = projectile.get("fixed_direction", Vector2.ZERO) as Vector2
		var speed: float = float(projectile.get("speed", 0.0))
		var max_range: float = float(projectile.get("max_range", 0.0))
		if fixed_direction.length_squared() <= 0.0001 or speed <= 0.0 or max_range <= 0.0:
			_expire_projectile(projectile_id, projectile.get("position", Vector3.ZERO) as Vector3)
			continue

		var previous_position: Vector3 = projectile.get("position", Vector3.ZERO) as Vector3
		var step_distance: float = speed * delta
		var distance_traveled: float = float(projectile.get("distance_traveled", 0.0))
		var remaining_distance: float = max(max_range - distance_traveled, 0.0)
		if remaining_distance <= 0.0:
			_expire_projectile(projectile_id, previous_position)
			continue

		step_distance = min(step_distance, remaining_distance)
		var direction_3d: Vector3 = Vector3(fixed_direction.x, 0.0, fixed_direction.y).normalized()
		var next_position: Vector3 = previous_position + direction_3d * step_distance
		var behavior_key: String = str(projectile.get("behavior_key", "projectile_aoe_damage"))
		var projectile_collision_radius: float = float(projectile.get("radius", FIREBALL_COLLISION_RADIUS)) if behavior_key == "projectile_single_target" else FIREBALL_COLLISION_RADIUS
		var collision: Dictionary = _first_projectile_collision(previous_position, next_position, projectile_collision_radius)
		if not collision.is_empty():
			if behavior_key == "projectile_single_target":
				_impact_single_target_projectile(projectile_id, projectile, collision.get("position", next_position) as Vector3, int(collision.get("enemy_id", 0)))
			else:
				_impact_fireball_projectile(projectile_id, projectile, collision.get("position", next_position) as Vector3)
			continue

		distance_traveled += step_distance
		if distance_traveled >= max_range:
			_expire_projectile(projectile_id, next_position)
			continue

		projectile["position"] = next_position
		projectile["distance_traveled"] = distance_traveled
		_server_projectiles[projectile_id] = projectile


func _first_projectile_collision(previous_position: Vector3, next_position: Vector3, collision_radius: float = FIREBALL_COLLISION_RADIUS) -> Dictionary:
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner == null:
		return {}

	var enemy_positions: Dictionary = enemy_spawner.call("get_active_enemy_positions") as Dictionary
	if enemy_positions.is_empty():
		return {}

	var start_xz: Vector2 = Vector2(previous_position.x, previous_position.z)
	var end_xz: Vector2 = Vector2(next_position.x, next_position.z)
	var segment: Vector2 = end_xz - start_xz
	var segment_length_squared: float = segment.length_squared()
	var safe_collision_radius: float = max(collision_radius, 0.01)
	var best_t: float = 1.0
	var best_position: Vector3 = Vector3.ZERO
	var best_enemy_id: int = 0
	var has_collision: bool = false
	for enemy_id in enemy_positions:
		var enemy_id_int: int = int(enemy_id)
		var enemy_position: Vector3 = enemy_positions[enemy_id] as Vector3
		var enemy_xz: Vector2 = Vector2(enemy_position.x, enemy_position.z)
		var t: float = 0.0
		if segment_length_squared > 0.0001:
			t = clamp((enemy_xz - start_xz).dot(segment) / segment_length_squared, 0.0, 1.0)

		var closest_xz: Vector2 = start_xz + segment * t
		if closest_xz.distance_to(enemy_xz) > safe_collision_radius:
			continue
		if has_collision and t >= best_t:
			continue

		best_t = t
		best_position = enemy_position
		best_enemy_id = enemy_id_int
		has_collision = true

	if not has_collision:
		return {}

	return {"position": best_position, "enemy_id": best_enemy_id}


func _impact_fireball_projectile(projectile_id: int, projectile: Dictionary, impact_position: Vector3) -> void:
	if not _server_projectiles.has(projectile_id):
		return

	_server_projectiles.erase(projectile_id)
	var owner_peer_id: int = int(projectile.get("owner_peer_id", 0))
	var radius: float = float(projectile.get("radius", 0.0))
	var damage: int = int(projectile.get("damage", 0))
	var visual_key: String = str(projectile.get("visual_key", _ability_visual_key("Firebolt")))
	var enemies_hit: int = 0
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner != null and radius > 0.0 and damage > 0:
		enemies_hit = int(enemy_spawner.call("resolve_fireball_aoe", owner_peer_id, impact_position, radius, damage))

	rpc("despawn_fireball_projectile", projectile_id, impact_position, radius, visual_key)
	print("Fireball impacted: peer_id=%s projectile_id=%s impact_position=%s enemies_hit=%s" % [owner_peer_id, projectile_id, impact_position, enemies_hit])


func _impact_single_target_projectile(projectile_id: int, projectile: Dictionary, impact_position: Vector3, enemy_id: int) -> void:
	if not _server_projectiles.has(projectile_id):
		return

	_server_projectiles.erase(projectile_id)
	var owner_peer_id: int = int(projectile.get("owner_peer_id", 0))
	var damage: int = int(projectile.get("damage", 0))
	var visual_key: String = str(projectile.get("visual_key", _ability_visual_key("Shoot")))
	var hit_enemy_id: int = 0
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner != null and enemy_id > 0 and damage > 0:
		if bool(enemy_spawner.call("resolve_projectile_single_target", owner_peer_id, enemy_id, damage)):
			hit_enemy_id = enemy_id

	rpc("despawn_fireball_projectile", projectile_id, impact_position, 0.0, visual_key)
	print("Shoot impacted: peer_id=%s projectile_id=%s hit_enemy_id=%s impact_position=%s" % [owner_peer_id, projectile_id, hit_enemy_id, impact_position])


func _expire_fireball_projectile(projectile_id: int, expire_position: Vector3) -> void:
	_expire_projectile(projectile_id, expire_position)


func _expire_projectile(projectile_id: int, expire_position: Vector3) -> void:
	if not _server_projectiles.has(projectile_id):
		return

	var projectile: Dictionary = _server_projectiles[projectile_id] as Dictionary
	_server_projectiles.erase(projectile_id)
	var owner_peer_id: int = int(projectile.get("owner_peer_id", 0))
	var visual_key: String = str(projectile.get("visual_key", _ability_visual_key("Firebolt")))
	rpc("despawn_fireball_projectile", projectile_id, expire_position, 0.0, visual_key)
	if str(projectile.get("behavior_key", "")) == "projectile_single_target":
		print("Shoot expired: peer_id=%s projectile_id=%s hit_enemy_id=0 expire_position=%s" % [owner_peer_id, projectile_id, expire_position])
	else:
		print("Fireball expired: peer_id=%s projectile_id=%s expire_position=%s enemies_hit=0" % [owner_peer_id, projectile_id, expire_position])


func _clear_projectiles_for_peer(peer_id: int) -> void:
	if _server_projectiles.is_empty():
		return

	var projectile_ids: Array = _server_projectiles.keys()
	for projectile_id_variant in projectile_ids:
		var projectile_id: int = int(projectile_id_variant)
		if not _server_projectiles.has(projectile_id):
			continue

		var projectile: Dictionary = _server_projectiles[projectile_id] as Dictionary
		if int(projectile.get("owner_peer_id", 0)) != peer_id:
			continue

		_expire_fireball_projectile(projectile_id, projectile.get("position", Vector3.ZERO) as Vector3)


func _loadout_entries(peer_id: int) -> Array:
	var loadout: Array = _loadout_by_peer.get(peer_id, DEFAULT_LOADOUT) as Array
	var ability_keys: Dictionary = _ability_keys_by_peer.get(peer_id, {}) as Dictionary
	var ability_slot_indexes: Dictionary = _ability_slot_indexes_by_peer.get(peer_id, {}) as Dictionary
	var display_names: Dictionary = _ability_display_names_by_peer.get(peer_id, {}) as Dictionary
	var ability_state: Dictionary = _ability_enabled_by_peer.get(peer_id, {}) as Dictionary
	var entries: Array = []
	for slot_index in range(loadout.size()):
		var ability_name = loadout[slot_index]
		var ability_name_text: String = str(ability_name)
		entries.append({
			"slot_index": int(ability_slot_indexes.get(ability_name_text, slot_index)),
			"ability_key": str(ability_keys.get(ability_name_text, _server_ability_key(ability_name_text))).strip_edges().to_lower(),
			"ability_name": ability_name_text,
			"display_name": str(display_names.get(ability_name_text, ability_name_text)),
			"enabled": bool(ability_state.get(ability_name_text, true)),
		})

	return entries


func _broadcast_position_snapshots() -> void:
	for peer_id in players:
		var peer_id_int: int = int(peer_id)
		var position: Vector3 = players[peer_id] as Vector3
		var facing_direction: Vector2 = _aim_direction_by_peer.get(peer_id, Vector2(0.0, -1.0)) as Vector2
		rpc("apply_position_snapshot", peer_id_int, position, facing_direction)


func _send_position_snapshots(target_peer_id: int) -> void:
	for peer_id in players:
		var peer_id_int: int = int(peer_id)
		var position: Vector3 = players[peer_id] as Vector3
		var facing_direction: Vector2 = _aim_direction_by_peer.get(peer_id, Vector2(0.0, -1.0)) as Vector2
		rpc_id(target_peer_id, "apply_position_snapshot", peer_id_int, position, facing_direction)


func _sync_loot_orbs_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	for loot_orb_id in _loot_orbs:
		var loot_data: Dictionary = _loot_orbs[loot_orb_id] as Dictionary
		if not bool(loot_data.get("active", false)):
			continue
		if int(loot_data.get("owner_peer_id", 0)) != peer_id:
			continue

		var loot_position: Vector3 = loot_data.get("position", Vector3.ZERO) as Vector3
		rpc_id(peer_id, "spawn_loot_orb", int(loot_orb_id), loot_position)


func _sync_projectiles_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	for projectile_id in _server_projectiles:
		var projectile: Dictionary = _server_projectiles[projectile_id] as Dictionary
		var projectile_position: Vector3 = projectile.get("position", Vector3.ZERO) as Vector3
		var fixed_direction: Vector2 = projectile.get("fixed_direction", Vector2.ZERO) as Vector2
		var remaining_range: float = max(float(projectile.get("max_range", 0.0)) - float(projectile.get("distance_traveled", 0.0)), 0.0)
		var visual_key: String = str(projectile.get("visual_key", _ability_visual_key("Firebolt")))
		rpc_id(
			peer_id,
			"spawn_fireball_projectile",
			int(projectile_id),
			projectile_position,
			fixed_direction,
			float(projectile.get("speed", 0.0)),
			remaining_range,
			visual_key
		)


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


func _animate_projectile_visuals(delta: float) -> void:
	for projectile_id in _spawned_projectile_nodes.keys():
		var projectile_data: Dictionary = _spawned_projectile_nodes[projectile_id] as Dictionary
		var projectile_node: Node3D = projectile_data.get("node", null) as Node3D
		if projectile_node == null:
			_spawned_projectile_nodes.erase(projectile_id)
			continue

		var fixed_direction: Vector2 = projectile_data.get("fixed_direction", Vector2.ZERO) as Vector2
		var speed: float = float(projectile_data.get("speed", 0.0))
		if fixed_direction.length_squared() <= 0.0001 or speed <= 0.0:
			continue

		var direction_3d: Vector3 = Vector3(fixed_direction.x, 0.0, fixed_direction.y).normalized()
		projectile_node.position += direction_3d * speed * delta


func _predict_and_reconcile_local_player(player: Node3D, peer_id: int, delta: float) -> void:
	if local_prediction_enabled and _player_combat_stats_by_peer.has(peer_id):
		# Local prediction is visual only. The server still owns authoritative movement.
		var confirmed_move_speed: float = _computed_player_move_speed(peer_id)
		player.position.x += _local_prediction_input.x * confirmed_move_speed * delta
		player.position.z += _local_prediction_input.y * confirmed_move_speed * delta

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
	if multiplayer.is_server():
		return

	_spawn_player_visual(peer_id, spawn_position, character_name, true)


func _spawn_player_visual(peer_id: int, spawn_position: Vector3, character_name: String, print_spawn: bool) -> void:
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

	if print_spawn and debug_join_sync_logs:
		print("Network player instantiated on client: peer_id=%s position=%s node_name=%s" % [peer_id, spawn_position, player.name])
	player_spawned.emit(peer_id, player)
	spawned_player_count_changed.emit(_spawned_nodes.size())


@rpc("authority", "call_remote", "reliable")
func spawn_players(player_snapshots: Array) -> void:
	if multiplayer.is_server():
		return

	for snapshot in player_snapshots:
		var snapshot_data: Dictionary = snapshot as Dictionary
		var peer_id: int = int(snapshot_data.get("peer_id", 0))
		var spawn_position: Vector3 = snapshot_data.get("position", Vector3.ZERO) as Vector3
		var character_name: String = str(snapshot_data.get("character_name", ""))
		var hp_regen_active: bool = bool(snapshot_data.get("hp_regen_active", false))
		if peer_id <= 0:
			continue

		_spawn_player_visual(peer_id, spawn_position, character_name, false)
		_update_hp_regen_visual(peer_id, hp_regen_active)
	if debug_join_sync_logs:
		print("Received targeted player sync: players=%s broadcast=false." % player_snapshots.size())


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
	_player_is_down_by_peer[peer_id] = is_down
	player_down_state_updated.emit(peer_id, is_down)


@rpc("authority", "call_remote", "reliable")
func apply_player_combat_stats_update(peer_id: int, combat_stats: Dictionary) -> void:
	_player_combat_stats_by_peer[peer_id] = combat_stats.duplicate()
	player_combat_stats_updated.emit(peer_id, combat_stats)


@rpc("authority", "call_remote", "reliable")
func apply_character_progression_update(peer_id: int, progression: Dictionary) -> void:
	_character_progression_by_peer[peer_id] = progression.duplicate()
	character_progression_updated.emit(peer_id, progression)


@rpc("authority", "call_remote", "reliable")
func apply_character_gold_update(peer_id: int, gold: int) -> void:
	_character_gold_by_peer[peer_id] = max(gold, 0)
	character_gold_updated.emit(peer_id, max(gold, 0))


@rpc("authority", "call_remote", "reliable")
func apply_character_inventory_update(peer_id: int, inventory_items: Array) -> void:
	var confirmed_items: Array = inventory_items.duplicate(true)
	_character_inventory_items_by_peer[peer_id] = confirmed_items
	character_inventory_updated.emit(peer_id, confirmed_items)


@rpc("authority", "call_remote", "reliable")
func apply_character_equipment_update(peer_id: int, equipment: Dictionary) -> void:
	var confirmed_equipment: Dictionary = equipment.duplicate(true)
	_character_equipment_by_peer[peer_id] = confirmed_equipment
	character_equipment_updated.emit(peer_id, confirmed_equipment)


@rpc("authority", "call_remote", "reliable")
func apply_combat_mode_update(peer_id: int, combat_enabled: bool, loadout_entries: Array) -> void:
	_combat_enabled_by_peer[peer_id] = combat_enabled
	var loadout: Array = []
	var ability_keys: Dictionary = {}
	var ability_slot_indexes: Dictionary = {}
	var display_names: Dictionary = {}
	for entry_variant in loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var ability_name: String = str(entry.get("ability_name", "")).strip_edges()
		if ability_name != "":
			loadout.append(ability_name)
			ability_keys[ability_name] = str(entry.get("ability_key", ability_name))
			ability_slot_indexes[ability_name] = int(entry.get("slot_index", loadout.size() - 1))
			display_names[ability_name] = str(entry.get("display_name", ability_name))
	_loadout_by_peer[peer_id] = loadout
	_ability_keys_by_peer[peer_id] = ability_keys
	_ability_slot_indexes_by_peer[peer_id] = ability_slot_indexes
	_ability_display_names_by_peer[peer_id] = display_names
	combat_mode_updated.emit(peer_id, combat_enabled, loadout_entries)


@rpc("authority", "call_remote", "reliable")
func apply_ability_catalog_update(peer_id: int, unlocked_abilities: Array) -> void:
	_unlocked_abilities_by_peer[peer_id] = unlocked_abilities.duplicate()
	ability_catalog_updated.emit(peer_id, unlocked_abilities)


@rpc("authority", "call_remote", "reliable")
func apply_ability_unlock_message(peer_id: int, display_name: String) -> void:
	ability_unlock_message_received.emit(peer_id, display_name)


@rpc("authority", "call_remote", "reliable")
func apply_status_message(peer_id: int, message: String) -> void:
	status_message_received.emit(peer_id, message)


@rpc("authority", "call_remote", "reliable")
func apply_ability_enabled_update(peer_id: int, ability_name: String, enabled: bool) -> void:
	var ability_state: Dictionary = _ability_enabled_by_peer.get(peer_id, {}) as Dictionary
	ability_state[ability_name] = enabled
	_ability_enabled_by_peer[peer_id] = ability_state
	ability_enabled_updated.emit(peer_id, ability_name, enabled)


@rpc("authority", "call_remote", "reliable")
func apply_ability_state_update(peer_id: int, ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:
	ability_state_updated.emit(peer_id, ability_name, enabled, active, cooldown_remaining)


@rpc("authority", "call_remote", "reliable")
func apply_hp_regen_active_state(peer_id: int, active: bool) -> void:
	_update_hp_regen_visual(peer_id, active)


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
	# Server owns combat mode and the validated loadout.
	rpc("apply_combat_mode_update", peer_id, combat_enabled, _loadout_entries(peer_id))
	_send_ability_states(peer_id)
	_broadcast_hp_regen_active_state(peer_id)


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
	_send_ability_state(peer_id, ability_name)
	_broadcast_hp_regen_active_state(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_update_ability_loadout(loadout_entries: Array) -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = int(multiplayer.get_remote_sender_id())
	if not players.has(peer_id):
		return
	if not _is_valid_loadout_request(peer_id, loadout_entries):
		return

	ability_loadout_update_requested.emit(peer_id, loadout_entries)


@rpc("any_peer", "call_remote", "reliable")
func request_update_equipment(equipment_entries: Array) -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = int(multiplayer.get_remote_sender_id())
	if not players.has(peer_id):
		return
	if not _is_valid_equipment_request(equipment_entries):
		return

	equipment_update_requested.emit(peer_id, equipment_entries)


func _is_valid_equipment_request(equipment_entries: Array) -> bool:
	var allowed_slots: Array[String] = ["weapon", "head", "chest", "arms", "hands", "legs", "feet"]
	var seen_slots: Array[String] = []
	for entry_variant in equipment_entries:
		if not (entry_variant is Dictionary):
			return false

		var entry: Dictionary = entry_variant as Dictionary
		var slot_name: String = str(entry.get("slot", "")).strip_edges().to_lower()
		var inventory_entry_id_variant: Variant = entry.get("inventory_entry_id", null)
		var inventory_entry_id: String = "" if inventory_entry_id_variant == null else str(inventory_entry_id_variant).strip_edges()
		var is_unequip: bool = bool(entry.get("unequip", false)) or inventory_entry_id_variant == null
		if not allowed_slots.has(slot_name):
			return false
		if seen_slots.has(slot_name):
			return false
		if inventory_entry_id == "" and not is_unequip:
			return false

		seen_slots.append(slot_name)

	return true


func _is_valid_loadout_request(peer_id: int, loadout_entries: Array) -> bool:
	if loadout_entries.is_empty() or loadout_entries.size() > 5:
		return false

	var unlocked_keys: Array[String] = []
	var unlocked_abilities: Array = _unlocked_abilities_by_peer.get(peer_id, []) as Array
	for ability_variant in unlocked_abilities:
		if not (ability_variant is Dictionary):
			continue

		var ability: Dictionary = ability_variant as Dictionary
		var ability_key: String = str(ability.get("ability_key", "")).strip_edges()
		if ability_key != "":
			unlocked_keys.append(ability_key)

	var seen_slots: Array[int] = []
	var seen_keys: Array[String] = []
	for entry_variant in loadout_entries:
		if not (entry_variant is Dictionary):
			return false

		var entry: Dictionary = entry_variant as Dictionary
		var slot_index: int = int(entry.get("slot_index", -1))
		var ability_key: String = str(entry.get("ability_key", "")).strip_edges()
		if slot_index < 0 or slot_index >= 5:
			return false
		if ability_key == "" or not unlocked_keys.has(ability_key):
			return false
		if seen_slots.has(slot_index) or seen_keys.has(ability_key):
			return false

		seen_slots.append(slot_index)
		seen_keys.append(ability_key)

	return true


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
	var slash_cooldown_seconds: float = _ability_cooldown("Slash")
	var last_attack_time: float = float(_last_attack_time_by_peer.get(peer_id, -slash_cooldown_seconds))
	if now_seconds - last_attack_time < slash_cooldown_seconds:
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
	var ability_config: Dictionary = _server_ability_config("Slash")
	var slash_range: float = float(ability_config.get("range", 0.0))
	var slash_arc_angle: float = float(ability_config.get("arc_angle", 0.0))
	var slash_damage: int = _ability_damage_amount(peer_id, "Slash")
	if slash_range <= 0.0 or slash_arc_angle <= 0.0 or slash_damage <= 0:
		return

	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	var enemies_hit: int = 0
	if enemy_spawner != null:
		enemies_hit = int(enemy_spawner.call("resolve_basic_attack", peer_id, attack_position, normalized_facing, slash_range, slash_arc_angle, slash_damage))

	rpc("show_basic_attack", peer_id, attack_position, normalized_facing, slash_range, slash_arc_angle, _ability_visual_key("Slash"))
	print("Slash resolved: peer_id=%s range=%s arc_angle=%s enemies_hit=%s" % [peer_id, slash_range, slash_arc_angle, enemies_hit])


@rpc("authority", "call_remote", "reliable")
func show_basic_attack(peer_id: int, attack_position: Vector3, facing_direction: Vector2, slash_range: float, slash_arc_angle: float, visual_key: String = "slash_arc") -> void:
	if facing_direction.length_squared() <= 0.0001 or slash_range <= 0.0 or slash_arc_angle <= 0.0:
		return

	var normalized_facing: Vector2 = facing_direction.normalized()
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = _build_slash_arc_mesh(slash_range, slash_arc_angle)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.75, 0.05, 0.75)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker.material_override = material
	marker.name = "%s_%s" % [visual_key, peer_id]
	marker.position = attack_position + Vector3(0.0, 0.25, 0.0)
	marker.rotation.y = atan2(-normalized_facing.x, -normalized_facing.y)
	add_child(marker)

	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 0.18
	marker.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(marker.queue_free)
	cleanup_timer.start()


func _build_slash_arc_mesh(slash_range: float, slash_arc_angle: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var segment_count: int = max(int(ceil(slash_arc_angle / 6.0)), 4)
	var half_angle: float = deg_to_rad(slash_arc_angle * 0.5)
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	vertices.append(Vector3.ZERO)

	for segment_index in range(segment_count + 1):
		var t: float = float(segment_index) / float(segment_count)
		var angle: float = lerp(-half_angle, half_angle, t)
		vertices.append(Vector3(sin(angle) * slash_range, 0.0, -cos(angle) * slash_range))

	for segment_index in range(1, segment_count + 1):
		indices.append(0)
		indices.append(segment_index)
		indices.append(segment_index + 1)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


@rpc("authority", "call_remote", "reliable")
func show_damage_aura(peer_id: int, aura_position: Vector3, radius: float, visual_key: String = "damage_aura") -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: CylinderMesh = CylinderMesh.new()
	marker_mesh.top_radius = radius
	marker_mesh.bottom_radius = radius
	marker_mesh.height = 0.08
	marker.mesh = marker_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.2, 1.0, 0.35)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	marker.name = "%s_%s" % [visual_key, peer_id]
	marker.position = aura_position + Vector3(0.0, 0.06, 0.0)
	add_child(marker)

	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 0.25
	marker.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(marker.queue_free)
	cleanup_timer.start()


@rpc("authority", "call_remote", "reliable")
func spawn_fireball_projectile(projectile_id: int, start_position: Vector3, fixed_direction: Vector2, speed: float, max_range: float, visual_key: String = "firebolt") -> void:
	if fixed_direction.length_squared() <= 0.0001 or speed <= 0.0 or max_range <= 0.0:
		return
	if _spawned_projectile_nodes.has(projectile_id):
		var existing_data: Dictionary = _spawned_projectile_nodes[projectile_id] as Dictionary
		var existing_node: Node3D = existing_data.get("node", null) as Node3D
		if existing_node != null:
			existing_node.position = start_position + Vector3(0.0, 0.45, 0.0)
		return

	var normalized_direction: Vector2 = fixed_direction.normalized()
	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: Mesh
	if visual_key == "arrow":
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = Vector3(0.12, 0.12, 0.8)
		marker_mesh = box_mesh
	else:
		var sphere_mesh: SphereMesh = SphereMesh.new()
		sphere_mesh.radius = 0.18
		sphere_mesh.height = 0.36
		marker_mesh = sphere_mesh
	marker.mesh = marker_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.54, 0.24, 0.95) if visual_key == "arrow" else Color(1.0, 0.28, 0.04, 0.95)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.55, 0.36, 0.16, 1.0) if visual_key == "arrow" else Color(1.0, 0.22, 0.02, 1.0)
	material.emission_energy_multiplier = 0.6 if visual_key == "arrow" else 1.2
	marker.material_override = material
	marker.name = "%s_projectile_%s" % [visual_key, projectile_id]
	marker.position = start_position + Vector3(0.0, 0.45, 0.0)
	marker.rotation.y = atan2(-normalized_direction.x, -normalized_direction.y)
	add_child(marker)
	_spawned_projectile_nodes[projectile_id] = {
		"node": marker,
		"fixed_direction": normalized_direction,
		"speed": speed,
		"max_range": max_range,
	}


@rpc("authority", "call_remote", "reliable")
func despawn_fireball_projectile(projectile_id: int, impact_position: Vector3, radius: float, visual_key: String = "firebolt") -> void:
	if _spawned_projectile_nodes.has(projectile_id):
		var projectile_data: Dictionary = _spawned_projectile_nodes[projectile_id] as Dictionary
		var projectile_node: Node3D = projectile_data.get("node", null) as Node3D
		if projectile_node != null:
			projectile_node.queue_free()
		_spawned_projectile_nodes.erase(projectile_id)

	if radius <= 0.0:
		return

	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: CylinderMesh = CylinderMesh.new()
	marker_mesh.top_radius = radius
	marker_mesh.bottom_radius = radius
	marker_mesh.height = 0.08
	marker.mesh = marker_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.32, 0.04, 0.35)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.18, 0.02, 1.0)
	material.emission_energy_multiplier = 0.7
	marker.material_override = material
	marker.name = "%s_impact_%s" % [visual_key, projectile_id]
	marker.position = impact_position + Vector3(0.0, 0.08, 0.0)
	add_child(marker)

	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 0.25
	marker.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(marker.queue_free)
	cleanup_timer.start()


@rpc("authority", "call_remote", "reliable")
func spawn_loot_orb(loot_orb_id: int, loot_position: Vector3) -> void:
	if multiplayer.is_server():
		return
	if _spawned_loot_orb_nodes.has(loot_orb_id):
		var existing_orb: Node3D = _spawned_loot_orb_nodes[loot_orb_id] as Node3D
		existing_orb.position = loot_position + Vector3(0.0, 0.45, 0.0)
		return

	var orb: MeshInstance3D = MeshInstance3D.new()
	var orb_mesh: SphereMesh = SphereMesh.new()
	orb_mesh.radius = 0.35
	orb_mesh.height = 0.7
	orb.mesh = orb_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.86, 0.18, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.7, 0.1, 1.0)
	material.emission_energy_multiplier = 0.8
	orb.material_override = material
	orb.name = "LootOrb_%s" % loot_orb_id
	orb.position = loot_position + Vector3(0.0, 0.45, 0.0)
	add_child(orb)
	_spawned_loot_orb_nodes[loot_orb_id] = orb


@rpc("authority", "call_remote", "reliable")
func despawn_loot_orb(loot_orb_id: int) -> void:
	if not _spawned_loot_orb_nodes.has(loot_orb_id):
		return

	var orb: Node3D = _spawned_loot_orb_nodes[loot_orb_id] as Node3D
	orb.queue_free()
	_spawned_loot_orb_nodes.erase(loot_orb_id)


@rpc("authority", "call_remote", "reliable")
func despawn_player(peer_id: int) -> void:
	if not _spawned_nodes.has(peer_id):
		return

	var player: Node3D = _spawned_nodes[peer_id] as Node3D
	player.queue_free()
	_spawned_nodes.erase(peer_id)
	_target_positions.erase(peer_id)
	_target_facing_directions.erase(peer_id)
	_combat_enabled_by_peer.erase(peer_id)
	_loadout_by_peer.erase(peer_id)
	_ability_keys_by_peer.erase(peer_id)
	_ability_slot_indexes_by_peer.erase(peer_id)
	_ability_display_names_by_peer.erase(peer_id)
	_unlocked_abilities_by_peer.erase(peer_id)
	_ability_enabled_by_peer.erase(peer_id)
	_character_progression_by_peer.erase(peer_id)
	_character_gold_by_peer.erase(peer_id)
	_character_inventory_items_by_peer.erase(peer_id)
	_character_equipment_by_peer.erase(peer_id)
	_player_is_down_by_peer.erase(peer_id)
	print("Despawned player for peer %s." % peer_id)
	spawned_player_count_changed.emit(_spawned_nodes.size())


func _set_peer_label(player: Node, peer_id: int, character_name: String = "") -> void:
	var peer_label: Label3D = player.get_node_or_null("PeerLabel") as Label3D
	if peer_label != null:
		if character_name.strip_edges() == "":
			peer_label.text = "Peer %s" % peer_id
		else:
			peer_label.text = "%s\nPeer %s" % [character_name, peer_id]


func _update_hp_regen_visual(peer_id: int, active: bool) -> void:
	if not _spawned_nodes.has(peer_id):
		return

	var player: Node3D = _spawned_nodes[peer_id] as Node3D
	var regen_visual: Node3D = player.get_node_or_null("HPRegenVisual") as Node3D
	if regen_visual == null:
		return

	# This is visual-only; the server confirms whether HP Regen is active.
	regen_visual.visible = active


func _apply_player_facing(player: Node3D, facing_direction: Vector2) -> void:
	if facing_direction.length_squared() <= 0.0001:
		return

	var normalized_facing: Vector2 = facing_direction.normalized()
	player.rotation.y = atan2(-normalized_facing.x, -normalized_facing.y)


func _distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _is_local_player_peer(peer_id: int) -> bool:
	return not multiplayer.is_server() and peer_id == multiplayer.get_unique_id()
