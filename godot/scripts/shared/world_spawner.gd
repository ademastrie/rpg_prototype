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
@export var prototype_loot_drop_chance: float = 1.0
@export var prototype_loot_pickup_radius: float = 1.5
@export var prototype_loot_reward_type: String = "item"
@export var prototype_loot_gold_amount: int = 3
@export var prototype_loot_item_key: String = "slime_gel"
@export var prototype_loot_item_display_name: String = "Slime Gel"
@export var prototype_loot_item_quantity: int = 1
@export var prototype_equipment_drop_chance: float = 0.15
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
var _loot_orbs: Dictionary = {}
var _spawned_loot_orb_nodes: Dictionary = {}
var _local_prediction_input: Vector2 = Vector2.ZERO
var _simulation_accumulator := 0.0
var _snapshot_accumulator := 0.0
var _next_spawn_index := 0
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
const PROTOTYPE_EQUIPMENT_DROP_ITEMS: Array[Dictionary] = [
	{"item_key": "training_sword", "display_name": "Training Sword"},
	{"item_key": "padded_chest", "display_name": "Padded Chest"},
	{"item_key": "cloth_hood", "display_name": "Cloth Hood"},
	{"item_key": "worn_boots", "display_name": "Worn Boots"},
]
const ABILITY_DEFINITIONS: Dictionary = {
	"Slash": {
		"cooldown": 1.25,
	},
	"HP Regen": {
		"cooldown": 2.0,
		"heal": 8,
	},
	"Damage Aura": {
		"cooldown": 1.0,
		"damage": 5,
		"radius": 4.0,
	},
	"Firebolt": {
		"cooldown": 1.3,
		"damage": 12,
		"range": 8.0,
		"width": 0.7,
	},
}
const PLAYER_DAMAGE_REDUCTION_CAP: float = 0.80
const SUPPORTED_EQUIPMENT_STAT_KEYS: Array[String] = ["max_hp", "damage_reduction", "attack_power", "spell_power", "move_speed"]


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


func spawn_prototype_loot_drop(drop_position: Vector3) -> void:
	if not multiplayer.is_server():
		return

	# Prototype world-drop flow only. Each pickup stays generic and server-owned:
	# future loot should come from backend/database-backed loot tables, item
	# rarity, affixes, inventory/equipment rules, and player/party ownership metadata.
	var reward_payloads: Array = _prototype_loot_reward_payloads()
	var equipment_payload: Dictionary = _prototype_equipment_reward_payload()
	if not equipment_payload.is_empty():
		reward_payloads.append(equipment_payload)
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
			"reward_payload": reward_payload,
		}
		_loot_orbs[loot_orb_id] = loot_data
		rpc("spawn_loot_orb", loot_orb_id, loot_position)


func _prototype_loot_reward_payloads() -> Array:
	var reward_payloads: Array = []
	if prototype_loot_drop_chance <= 0.0:
		return reward_payloads
	if prototype_loot_drop_chance < 1.0 and randf() > prototype_loot_drop_chance:
		return reward_payloads

	var gold_amount: int = max(prototype_loot_gold_amount, 1)
	reward_payloads.append({
			"type": "currency",
			"gold_amount": gold_amount,
	})

	var item_key: String = prototype_loot_item_key.strip_edges()
	if item_key != "":
		reward_payloads.append({
			"type": "item",
			"item_key": item_key,
			"display_name": prototype_loot_item_display_name.strip_edges(),
			"quantity": max(prototype_loot_item_quantity, 1),
		})

	return reward_payloads


func _prototype_equipment_reward_payload() -> Dictionary:
	if prototype_equipment_drop_chance <= 0.0 or PROTOTYPE_EQUIPMENT_DROP_ITEMS.is_empty():
		return {}
	if prototype_equipment_drop_chance < 1.0 and randf() > prototype_equipment_drop_chance:
		return {}

	var item_index: int = randi_range(0, PROTOTYPE_EQUIPMENT_DROP_ITEMS.size() - 1)
	var item_data: Dictionary = PROTOTYPE_EQUIPMENT_DROP_ITEMS[item_index] as Dictionary
	var item_key: String = str(item_data.get("item_key", "")).strip_edges()
	if item_key == "":
		return {}

	return {
		"type": "item",
		"item_key": item_key,
		"display_name": str(item_data.get("display_name", "")).strip_edges(),
		"quantity": 1,
	}


func _prototype_loot_position_offset(reward_index: int, reward_count: int) -> Vector3:
	if reward_count <= 1:
		return Vector3.ZERO

	var angle: float = (TAU / float(reward_count)) * float(reward_index)
	var offset_radius: float = 0.45
	return Vector3(cos(angle) * offset_radius, 0.0, sin(angle) * offset_radius)


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
		_process_prototype_loot_pickups()
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
		if _is_enemy_in_contact_range(player_position, enemy_positions):
			if apply_enemy_damage_to_player(peer_id_int, enemy_contact_damage):
				_last_contact_damage_time_by_peer[peer_id] = now_seconds


func apply_enemy_melee_damage(peer_id: int, damage: int) -> bool:
	return apply_enemy_damage_to_player(peer_id, damage)


func apply_enemy_damage_to_player(peer_id: int, raw_damage: int) -> bool:
	if not multiplayer.is_server() or raw_damage <= 0 or not players.has(peer_id):
		return false
	if bool(_player_is_down_by_peer.get(peer_id, false)):
		return false

	var current_hp: int = int(_player_current_hp_by_peer.get(peer_id, player_max_hp))
	if current_hp <= 0:
		return false

	var final_damage: int = _modified_player_damage_taken(peer_id, raw_damage)
	current_hp = max(current_hp - final_damage, 0)
	_player_current_hp_by_peer[peer_id] = current_hp
	var max_hp: int = int(_player_max_hp_by_peer.get(peer_id, player_max_hp))
	rpc("apply_player_health_update", peer_id, current_hp, max_hp)
	if current_hp <= 0:
		_mark_player_down(peer_id)

	return true


func _modified_player_damage_taken(peer_id: int, raw_damage: int) -> int:
	var combat_stats: Dictionary = _player_combat_stats_by_peer.get(peer_id, _default_player_combat_stats()) as Dictionary
	var damage_reduction: float = clamp(float(combat_stats.get("damage_reduction", 0.0)), 0.0, PLAYER_DAMAGE_REDUCTION_CAP)
	return max(int(round(float(raw_damage) * (1.0 - damage_reduction))), 1)


func _default_player_combat_stats() -> Dictionary:
	return {
		"max_hp": player_max_hp,
		"damage_reduction": 0.0,
		"attack_power": 0.0,
		"spell_power": 0.0,
		"move_speed": movement_speed,
	}


func _recalculate_player_combat_stats(peer_id: int, restore_current_hp_to_max: bool = false) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return

	var combat_stats: Dictionary = _default_player_combat_stats()
	var loadout: Array = _loadout_by_peer.get(peer_id, []) as Array
	# Temporary prototype modifiers: Slash grants damage reduction and max HP while slotted.
	# Future stats should be assembled from backend base stats, backend ability
	# effects, gear, buffs/debuffs, and other server-owned simulation state.
	if loadout.has("Slash"):
		combat_stats["damage_reduction"] = float(combat_stats["damage_reduction"]) + 0.20
		combat_stats["max_hp"] = int(combat_stats["max_hp"]) + 25

	_apply_equipped_item_stat_modifiers(peer_id, combat_stats)
	combat_stats["damage_reduction"] = clamp(float(combat_stats.get("damage_reduction", 0.0)), 0.0, PLAYER_DAMAGE_REDUCTION_CAP)
	combat_stats["max_hp"] = max(int(round(float(combat_stats.get("max_hp", player_max_hp)))), 1)
	_player_combat_stats_by_peer[peer_id] = combat_stats
	_apply_computed_player_max_hp(peer_id, int(combat_stats.get("max_hp", player_max_hp)), restore_current_hp_to_max)
	rpc_id(peer_id, "apply_player_combat_stats_update", peer_id, combat_stats)


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
	var stat_key: String = str(modifier.get("stat_key", modifier.get("key", modifier.get("stat", "")))).strip_edges().to_lower()
	if not SUPPORTED_EQUIPMENT_STAT_KEYS.has(stat_key):
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
		"damage_reduction":
			var reduction_delta: float = _percent_modifier_value(value)
			combat_stats["damage_reduction"] = float(combat_stats.get("damage_reduction", 0.0)) + reduction_delta
		"attack_power", "spell_power", "move_speed":
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


func _is_enemy_in_contact_range(player_position: Vector3, enemy_positions: Dictionary) -> bool:
	for enemy_id in enemy_positions:
		var enemy_position: Vector3 = enemy_positions[enemy_id] as Vector3
		var offset_xz: Vector2 = Vector2(enemy_position.x - player_position.x, enemy_position.z - player_position.z)
		if offset_xz.length() <= enemy_contact_range:
			return true

	return false


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
		keys[ability_name_text] = str(ability_keys.get(ability_name_text, ability_name_text))

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
	var ability_definition: Dictionary = ABILITY_DEFINITIONS.get(ability_name, {}) as Dictionary
	return float(ability_definition.get("cooldown", 1.0))


func _ability_heal_amount(ability_name: String) -> int:
	var ability_definition: Dictionary = ABILITY_DEFINITIONS.get(ability_name, {}) as Dictionary
	return int(ability_definition.get("heal", 0))


func _ability_damage_amount(ability_name: String) -> int:
	var ability_definition: Dictionary = ABILITY_DEFINITIONS.get(ability_name, {}) as Dictionary
	return int(ability_definition.get("damage", 0))


func _ability_radius(ability_name: String) -> float:
	var ability_definition: Dictionary = ABILITY_DEFINITIONS.get(ability_name, {}) as Dictionary
	return float(ability_definition.get("radius", 0.0))


func _ability_range(ability_name: String) -> float:
	var ability_definition: Dictionary = ABILITY_DEFINITIONS.get(ability_name, {}) as Dictionary
	return float(ability_definition.get("range", 0.0))


func _ability_width(ability_name: String) -> float:
	var ability_definition: Dictionary = ABILITY_DEFINITIONS.get(ability_name, {}) as Dictionary
	return float(ability_definition.get("width", 0.0))


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
	var radius: float = _ability_radius("Damage Aura")
	var damage: int = _ability_damage_amount("Damage Aura")
	if radius <= 0.0 or damage <= 0:
		return

	rpc("show_damage_aura", peer_id, aura_position, radius)
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner != null:
		enemy_spawner.call("resolve_damage_aura", peer_id, aura_position, radius, damage)


func _perform_firebolt(peer_id: int) -> void:
	var firebolt_position: Vector3 = players[peer_id] as Vector3
	var aim_direction: Vector2 = _aim_direction_by_peer.get(peer_id, Vector2(0.0, -1.0)) as Vector2
	if aim_direction.length_squared() <= 0.0001:
		aim_direction = Vector2(0.0, -1.0)

	var normalized_aim: Vector2 = aim_direction.normalized()
	var firebolt_range: float = _ability_range("Firebolt")
	var firebolt_width: float = _ability_width("Firebolt")
	var damage: int = _ability_damage_amount("Firebolt")
	if firebolt_range <= 0.0 or firebolt_width <= 0.0 or damage <= 0:
		return

	rpc("show_firebolt", peer_id, firebolt_position, normalized_aim, firebolt_range)
	var enemy_spawner: Node = get_node_or_null("../EnemySpawner")
	if enemy_spawner != null:
		enemy_spawner.call("resolve_firebolt", peer_id, firebolt_position, normalized_aim, firebolt_range, firebolt_width, damage)


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
			"ability_key": str(ability_keys.get(ability_name_text, ability_name_text)),
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

		var loot_position: Vector3 = loot_data.get("position", Vector3.ZERO) as Vector3
		rpc_id(peer_id, "spawn_loot_orb", int(loot_orb_id), loot_position)


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
		var item_key_variant: Variant = entry.get("item_key", null)
		var item_key: String = "" if item_key_variant == null else str(item_key_variant).strip_edges()
		var is_unequip: bool = bool(entry.get("unequip", false)) or item_key_variant == null
		if not allowed_slots.has(slot_name):
			return false
		if seen_slots.has(slot_name):
			return false
		if item_key == "" and not is_unequip:
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
func show_damage_aura(peer_id: int, aura_position: Vector3, radius: float) -> void:
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
	marker.name = "DamageAura_%s" % peer_id
	marker.position = aura_position + Vector3(0.0, 0.06, 0.0)
	add_child(marker)

	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 0.25
	marker.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(marker.queue_free)
	cleanup_timer.start()


@rpc("authority", "call_remote", "reliable")
func show_firebolt(peer_id: int, firebolt_position: Vector3, aim_direction: Vector2, firebolt_range: float) -> void:
	if aim_direction.length_squared() <= 0.0001 or firebolt_range <= 0.0:
		return

	var normalized_aim: Vector2 = aim_direction.normalized()
	var marker: MeshInstance3D = MeshInstance3D.new()
	var marker_mesh: BoxMesh = BoxMesh.new()
	marker_mesh.size = Vector3(0.18, 0.18, firebolt_range)
	marker.mesh = marker_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.25, 0.05, 0.85)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.22, 0.02, 1.0)
	material.emission_energy_multiplier = 0.8
	marker.material_override = material
	marker.name = "Firebolt_%s" % peer_id
	var forward: Vector3 = Vector3(normalized_aim.x, 0.0, normalized_aim.y)
	marker.position = firebolt_position + forward * (firebolt_range * 0.5) + Vector3(0.0, 0.45, 0.0)
	marker.rotation.y = atan2(-normalized_aim.x, -normalized_aim.y)
	add_child(marker)

	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 0.18
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
