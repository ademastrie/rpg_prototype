# Generated Godot Symbol Summary

## `godot/scripts/backend_api_client.gd`

### Class Name
- `BackendApiClient`

### Extends
- `Node`

### Signals
- `request_succeeded(request_id: int, endpoint: String, data: Variant)`
- `request_failed(request_id: int, endpoint: String, status_code: int, message: String)`

### Exports
- `base_url: String = "http://127.0.0.1:8000"`

### Functions
- `_ready() -> void:`
- `configure(new_base_url: String) -> void:`
- `register(email: String, password: String) -> int:`
- `login(email: String, password: String) -> int:`
- `get_current_user(access_token: String) -> int:`
- `list_characters(access_token: String) -> int:`
- `create_character(access_token: String, name: String, starter_ability_key: String = "slash") -> int:`
- `delete_character(access_token: String, character_id: int) -> int:`
- `_queue_json_request(`
- `_process_next_request() -> void:`
- `_on_request_completed(`
- `_ensure_http_request() -> void:`
- `_build_url(endpoint: String) -> String:`
- `_normalize_base_url(value: String) -> String:`
- `_get_error_message(data: Variant) -> String:`

### Rpcs
- None found

## `godot/scripts/client/client_game.gd`

### Class Name
- None found

### Extends
- `Node3D`

### Signals
- None found

### Exports
- `server_host: String = "127.0.0.1"`
- `server_port: int = 7777`
- `input_heartbeat_interval: float = 0.25`
- `aim_heartbeat_interval: float = 0.35`
- `aim_change_threshold: float = 0.03`
- `camera_follow_speed: float = 8.0`
- `debug_client_startup_logs: bool = false`
- `debug_client_startup_timing: bool = false`

### Functions
- `_ready() -> void:`
- `set_selected_character(character_data: Dictionary) -> void:`
- `_process(delta: float) -> void:`
- `_notification(what: int) -> void:`
- `_connect_to_server() -> void:`
- `_on_connected_to_server() -> void:`
- `_on_connection_failed() -> void:`
- `_on_server_disconnected() -> void:`
- `_on_spawned_player_count_changed(count: int) -> void:`
- `_on_player_spawned(peer_id: int, player: Node3D) -> void:`
- `_on_player_health_updated(peer_id: int, current_hp: int, max_hp: int) -> void:`
- `_on_player_combat_stats_updated(peer_id: int, combat_stats: Dictionary) -> void:`
- `_on_character_progression_updated(peer_id: int, progression: Dictionary) -> void:`
- `_on_character_gold_updated(peer_id: int, gold: int) -> void:`
- `_on_character_inventory_updated(peer_id: int, inventory_items: Array) -> void:`
- `_on_character_equipment_updated(peer_id: int, equipment: Dictionary) -> void:`
- `_on_player_down_state_updated(peer_id: int, is_down: bool) -> void:`
- `_on_combat_mode_updated(peer_id: int, combat_enabled: bool, loadout_entries: Array) -> void:`
- `_on_ability_enabled_updated(peer_id: int, ability_name: String, enabled: bool) -> void:`
- `_on_ability_state_updated(peer_id: int, ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:`
- `_on_ability_catalog_updated(peer_id: int, unlocked_abilities: Array) -> void:`
- `_on_initial_enemy_batch_received(enemy_count: int) -> void:`
- `_on_ability_unlock_message_received(peer_id: int, display_name: String) -> void:`
- `_on_status_message_received(peer_id: int, message: String) -> void:`
- `_read_movement_input() -> Vector2:`
- `_screen_input_to_world_xz(screen_direction: Vector2) -> Vector3:`
- `_read_mouse_aim_direction() -> Vector2:`
- `_should_send_aim(aim_direction: Vector2) -> bool:`
- `_send_movement_input(input_direction: Vector2) -> void:`
- `_send_aim_input(aim_direction: Vector2) -> void:`
- `_read_combat_toggle_input() -> void:`
- `_read_character_panel_toggle_input() -> void:`
- `_read_ability_panel_toggle_input() -> void:`
- `_read_inventory_panel_toggle_input() -> void:`
- `_send_combat_toggle_request() -> void:`
- `_send_ability_toggle_request(ability_name: String, enabled: bool) -> void:`
- `_send_loadout_save_request(loadout_entries: Array) -> void:`
- `_send_equipment_change_request(equipment_entries: Array) -> void:`
- `_update_camera_follow(delta: float) -> void:`
- `_snap_camera_to_local_player() -> void:`
- `_send_join_request() -> void:`
- `_log_client_startup_timing(event_name: String, counts: Dictionary = {}) -> void:`

### Rpcs
- None found

## `godot/scripts/client/client_session.gd`

### Class Name
- None found

### Extends
- `Node`

### Signals
- None found

### Exports
- None found

### Functions
- `clear() -> void:`

### Rpcs
- None found

## `godot/scripts/client/game_hud.gd`

### Class Name
- None found

### Extends
- `CanvasLayer`

### Signals
- `combat_toggle_requested`
- `ability_toggle_requested(ability_name: String, enabled: bool)`
- `loadout_save_requested(loadout_entries: Array)`
- `equipment_change_requested(equipment_entries: Array)`

### Exports
- None found

### Functions
- `_ready() -> void:`
- `_process(delta: float) -> void:`
- `update_health(current_hp: int, max_hp: int) -> void:`
- `update_progression(level: int, xp: int, xp_to_next: int) -> void:`
- `update_gold(gold: int) -> void:`
- `update_inventory_items(inventory_items: Array) -> void:`
- `update_equipment(equipment: Dictionary) -> void:`
- `update_down_state(is_down: bool) -> void:`
- `update_combat_mode(combat_enabled: bool) -> void:`
- `update_combat_stats(combat_stats: Dictionary) -> void:`
- `update_loadout(loadout_entries: Array) -> void:`
- `update_unlocked_abilities(unlocked_abilities: Array) -> void:`
- `show_status_message(message: String) -> void:`
- `toggle_character_panel() -> void:`
- `toggle_ability_panel() -> void:`
- `toggle_inventory_panel() -> void:`
- `update_ability_enabled(ability_name: String, enabled: bool) -> void:`
- `update_ability_state(ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:`
- `_build_layout() -> void:`
- `_build_hud() -> void:`
- `_build_hotbar() -> void:`
- `_build_character_panel() -> void:`
- `_build_ability_panel() -> void:`
- `_build_inventory_panel() -> void:`
- `_add_label(parent: Control, text: String) -> Label:`
- `_add_title_label(parent: Control, text: String) -> Label:`
- `_add_button(parent: Control, text: String) -> Button:`
- `_apply_panel_style(panel: PanelContainer) -> void:`
- `_apply_button_text_colors(button: BaseButton) -> void:`
- `_rebuild_ability_controls() -> void:`
- `_refresh_hotbar() -> void:`
- `_refresh_character_panel() -> void:`
- `_equipment_display_text(slot_name: String) -> String:`
- `_format_stat_number(value: float) -> String:`
- `_refresh_equipment_slot_options() -> void:`
- `_confirmed_inventory_entry_id_for_slot(slot_name: String) -> String:`
- `_confirmed_item_key_for_slot(slot_name: String) -> String:`
- `_confirmed_equipment_item_for_slot(slot_name: String) -> Dictionary:`
- `_add_equipment_option(option: OptionButton, item: Dictionary, quantity: int) -> void:`
- `_equipment_item_display_name(item: Dictionary, item_key: String) -> String:`
- `_eligible_inventory_items_for_slot(slot_name: String) -> Array:`
- `_inventory_entry_id(item: Dictionary) -> String:`
- `_inventory_item_equip_slot(item: Dictionary) -> String:`
- `_select_equipment_option(option: OptionButton, inventory_entry_id: String, item_key: String = "") -> void:`
- `_equipment_metadata_matches_item(metadata: Variant, inventory_entry_id: String, item_key: String) -> bool:`
- `_equipment_metadata_inventory_entry_id(metadata: Variant) -> String:`
- `_equipment_metadata_item_key(metadata: Variant) -> String:`
- `_refresh_inventory_panel() -> void:`
- `_confirmed_equipped_inventory_entry_ids() -> Array[String]:`
- `_confirmed_equipped_inventory_entry_ids_except(excluded_slot_name: String) -> Array[String]:`
- `_refresh_ability_panel_options() -> void:`
- `_refresh_ability_panel_rows() -> void:`
- `_select_ability_option(option: OptionButton, ability_key: String) -> void:`
- `_selected_ability_keys_by_slot() -> Dictionary:`
- `_blocked_ability_keys_for_slot(slot_index: int, selected_keys_by_slot: Dictionary) -> Array[String]:`
- `_update_confirmed_loadout_entry_enabled(ability_name: String, enabled: bool) -> void:`
- `_update_ability_display(ability_name: String) -> void:`
- `_ability_hotbar_text(slot_index: int, ability_name: String) -> String:`
- `_loadout_entry_for_slot(slot_index: int) -> Dictionary:`
- `_panel_loadout_entry_for_slot(slot_index: int) -> Dictionary:`
- `_draft_loadout_entry_for_slot(slot_index: int) -> Dictionary:`
- `_begin_loadout_draft() -> void:`
- `_cancel_loadout_draft() -> void:`
- `_initialize_loadout_draft_from_confirmed() -> void:`
- `_duplicate_loadout_entries(loadout_entries: Array) -> Array:`
- `_set_draft_loadout_entry(slot_index: int, ability_key: String, enabled: bool) -> void:`
- `_draft_entry_for_ability_key(slot_index: int, ability_key: String, enabled: bool) -> Dictionary:`
- `_unlocked_ability_for_key(ability_key: String) -> Dictionary:`
- `_loadout_entries_match(left_entries: Array, right_entries: Array) -> bool:`
- `_loadout_entries_by_slot(loadout_entries: Array) -> Dictionary:`
- `_on_loadout_option_selected(item_index: int, slot_index: int) -> void:`
- `_on_loadout_enabled_toggled(enabled: bool, slot_index: int) -> void:`
- `_on_cancel_loadout_pressed() -> void:`
- `_on_panel_drag_handle_input(event: InputEvent, panel: Control) -> void:`
- `_move_dragged_panel() -> void:`
- `_on_combat_toggle_button_pressed() -> void:`
- `_on_hotbar_slot_pressed(slot_index: int) -> void:`
- `_on_ability_check_box_toggled(enabled: bool, ability_name: String) -> void:`
- `_on_save_loadout_pressed() -> void:`
- `_on_equipment_option_selected(_item_index: int, _slot_name: String) -> void:`
- `_on_message_timer_timeout(timer: SceneTreeTimer) -> void:`

### Rpcs
- None found

## `godot/scripts/client/isometric_camera.gd`

### Class Name
- None found

### Extends
- `Camera3D`

### Signals
- None found

### Exports
- `camera_position: Vector3 = Vector3(20, 20, 20)`
- `look_at_target: Vector3 = Vector3.ZERO`
- `orthographic_size: float = 30.0`

### Functions
- `_ready() -> void:`

### Rpcs
- None found

## `godot/scripts/client/login_character_select.gd`

### Class Name
- None found

### Extends
- `Control`

### Signals
- None found

### Exports
- `base_url: String = "http://127.0.0.1:8000"`

### Functions
- `_ready() -> void:`
- `_on_register_pressed() -> void:`
- `_on_login_pressed() -> void:`
- `_on_open_create_character_pressed() -> void:`
- `_on_confirm_create_character_pressed() -> void:`
- `_on_cancel_create_character_pressed() -> void:`
- `_on_refresh_characters_pressed() -> void:`
- `_on_delete_character_pressed() -> void:`
- `_on_confirm_delete_character_pressed() -> void:`
- `_on_cancel_delete_character_pressed() -> void:`
- `_on_enter_game_pressed() -> void:`
- `_on_character_selected(index: int) -> void:`
- `_on_request_succeeded(request_id: int, _endpoint: String, data: Variant) -> void:`
- `_on_request_failed(request_id: int, _endpoint: String, status_code: int, message: String) -> void:`
- `_refresh_characters() -> void:`
- `_show_characters(data: Variant) -> void:`
- `_setup_starter_ability_options() -> void:`
- `_selected_starter_ability_key() -> String:`
- `_show_selected_character_info(character: Dictionary) -> void:`
- `_clear_selected_character_info() -> void:`
- `_clear_create_character_fields() -> void:`
- `_track_request(request_id: int, action: String, email: String = "") -> void:`
- `_load_saved_login_email() -> void:`
- `_save_login_email(email: String) -> void:`
- `_has_token() -> bool:`
- `_set_status(message: String) -> void:`
- `_selected_character() -> Dictionary:`
- `_update_character_actions(has_selected_character: bool) -> void:`

### Rpcs
- None found

## `godot/scripts/dev/backend_api_test.gd`

### Class Name
- None found

### Extends
- `Node`

### Signals
- None found

### Exports
- `base_url: String = "http://127.0.0.1:8000"`
- `email: String = "test@example.com"`
- `password: String = "secret123"`
- `character_name: String = "DevHero"`
- `login_on_ready: bool = false`
- `list_characters_after_login: bool = true`

### Functions
- `_ready() -> void:`
- `run_login_test() -> void:`
- `run_list_characters_test() -> void:`
- `run_current_user_test() -> void:`
- `run_create_character_test() -> void:`
- `_on_request_succeeded(request_id: int, endpoint: String, data: Variant) -> void:`
- `_on_request_failed(_request_id: int, endpoint: String, status_code: int, message: String) -> void:`

### Rpcs
- None found

## `godot/scripts/server/server_game.gd`

### Class Name
- None found

### Extends
- `Node`

### Signals
- None found

### Exports
- `server_port: int = 7777`
- `backend_base_url: String = "http://127.0.0.1:8000"`
- `server_region_id: String = "starting_region"`
- `debug_server_startup_logs: bool = false`
- `debug_join_timing: bool = false`

### Functions
- `_ready() -> void:`
- `_start_server() -> void:`
- `_on_peer_connected(peer_id: int) -> void:`
- `_on_peer_disconnected(peer_id: int) -> void:`
- `_on_join_requested(peer_id: int, character_id: int, _character_name: String, access_token: String) -> void:`
- `_validate_join_with_backend(peer_id: int, character_id: int, access_token: String) -> void:`
- `_on_join_validation_completed(`
- `_fetch_character_abilities_with_backend(peer_id: int, access_token: String, session: Dictionary) -> void:`
- `_on_character_abilities_completed(`
- `_complete_validated_join(peer_id: int, session: Dictionary, loadout_data: Dictionary) -> void:`
- `_fetch_character_inventory_for_session(peer_id: int) -> void:`
- `_on_character_inventory_completed(`
- `_fetch_character_equipment_for_session(peer_id: int) -> void:`
- `_on_character_equipment_completed(`
- `_on_equipment_update_requested(peer_id: int, equipment_entries: Array) -> void:`
- `_on_equipment_update_completed(`
- `_restore_confirmed_equipment_for_peer(peer_id: int, message: String) -> void:`
- `_extract_character_equipment(response_data: Dictionary) -> Dictionary:`
- `_empty_character_equipment() -> Dictionary:`
- `_equipment_entry_candidates(response_data: Dictionary) -> Array:`
- `_normalize_equipment_entry(entry_data: Dictionary) -> Dictionary:`
- `_extract_inventory_entry_id(item_data: Dictionary) -> String:`
- `_extract_stat_modifiers_from_item(item_data: Dictionary) -> Array:`
- `_stat_modifier_containers(item_data: Dictionary) -> Array:`
- `_normalize_stat_modifier(modifier_data: Dictionary) -> Dictionary:`
- `_parse_backend_ability_loadout(peer_id: int, character_id: int, response_data: Dictionary) -> Dictionary:`
- `_backend_unlocked_abilities(response_data: Dictionary) -> Array:`
- `_backend_ability_display_names(response_data: Dictionary) -> Dictionary:`
- `_is_supported_godot_ability(ability_name: String) -> bool:`
- `_on_ability_loadout_update_requested(peer_id: int, loadout_entries: Array) -> void:`
- `_on_ability_loadout_update_completed(`
- `_on_enemy_killed(attacker_peer_id: int, enemy_id: int) -> void:`
- `_on_loot_reward_pickup_requested(peer_id: int, loot_orb_id: int, reward_payload: Dictionary) -> void:`
- `_award_loot_currency(peer_id: int, loot_orb_id: int, reward_payload: Dictionary) -> void:`
- `_on_loot_currency_award_completed(`
- `_award_loot_item(peer_id: int, loot_orb_id: int, reward_payload: Dictionary) -> void:`
- `_on_loot_item_award_completed(`
- `_confirmed_inventory_from_item_response(response_data: Dictionary, existing_inventory: Array, item_key: String, quantity: int, payload_display_name: String) -> Array:`
- `_extract_inventory_items(response_data: Dictionary) -> Array:`
- `_merge_confirmed_inventory_item(existing_inventory: Array, confirmed_item: Dictionary, fallback_item_key: String, fallback_quantity: int, fallback_display_name: String) -> Array:`
- `_normalize_inventory_item(item_data: Dictionary) -> Dictionary:`
- `_inventory_item_definition(item_data: Dictionary) -> Dictionary:`
- `_fallback_equip_slot_for_item_key(item_key: String) -> String:`
- `_display_name_for_item_payload(item_key: String, fallback_display_name: String) -> String:`
- `_award_kill_xp(peer_id: int, enemy_id: int) -> void:`
- `_on_award_xp_completed(`
- `_request_level_unlocks(peer_id: int, confirmed_level: int) -> void:`
- `_request_session_unlock(peer_id: int, ability_key: String) -> void:`
- `_on_ability_unlock_completed(`
- `_reload_character_abilities_after_unlock(peer_id: int, ability_key: String, was_already_unlocked: bool) -> void:`
- `_on_unlock_ability_reload_completed(`
- `_unlocked_ability_keys(unlocked_abilities: Array) -> Array[String]:`
- `_has_unlocked_ability(unlocked_abilities: Array, ability_key: String) -> bool:`
- `_display_name_for_unlocked_ability(unlocked_abilities: Array, ability_key: String) -> String:`
- `_save_peer_position(peer_id: int, session: Dictionary, position: Vector3) -> void:`
- `_on_save_position_completed(`
- `_has_saved_position(position_x: float, position_y: float) -> bool:`
- `_normalized_backend_base_url() -> String:`
- `_disconnect_peer(peer_id: int) -> void:`
- `_log_join_timing(peer_id: int, event_name: String) -> void:`

### Rpcs
- None found

## `godot/scripts/shared/enemy_spawner.gd`

### Class Name
- `EnemySpawner`

### Extends
- `Node3D`

### Signals
- `enemy_killed(attacker_peer_id: int, enemy_id: int)`
- `initial_enemy_batch_received(count: int)`

### Exports
- `enemy_placeholder_scene: PackedScene`
- `idle_radius: float = 1.2`
- `idle_speed: float = 0.6`
- `snapshot_rate: float = 6.0`
- `interpolation_speed: float = 8.0`
- `basic_attack_damage: int = 10`
- `basic_attack_range: float = 4.0`
- `basic_attack_cone_dot: float = 0.65`
- `respawn_delay_seconds: float = 5.0`
- `debug_enemy_lifecycle_logs: bool = false`
- `debug_enemy_join_sync_logs: bool = false`
- `debug_enemy_return_logs: bool = false`
- `debug_enemy_snap_logs: bool = false`
- `enemy_snap_log_threshold: float = 5.0`

### Functions
- `spawn_initial_enemies() -> void:`
- `sync_peer(peer_id: int) -> void:`
- `get_active_enemy_positions() -> Dictionary:`
- `get_enemy_xp_reward(enemy_id: int) -> int:`
- `get_authoritative_enemy_position(enemy_id: int) -> Vector3:`
- `_process(delta: float) -> void:`
- `_spawn_enemy(spawn_position: Vector3, enemy_type: String = DEFAULT_ENEMY_TYPE) -> void:`
- `resolve_basic_attack(_attacker_peer_id: int, attack_position: Vector3, facing_direction: Vector2) -> void:`
- `resolve_damage_aura(_attacker_peer_id: int, aura_position: Vector3, radius: float, damage: int) -> void:`
- `resolve_firebolt(_attacker_peer_id: int, firebolt_position: Vector3, aim_direction: Vector2, firebolt_range: float, firebolt_width: float, damage: int) -> void:`
- `_apply_damage_to_enemy(enemy_id: int, attacker_peer_id: int, damage: int) -> void:`
- `_despawn_enemy(enemy_id: int) -> void:`
- `_schedule_enemy_respawn(enemy_id: int) -> void:`
- `_on_enemy_respawn_timer_timeout(enemy_id: int, respawn_timer: Timer) -> void:`
- `_respawn_enemy(enemy_id: int, spawn_position: Vector3) -> void:`
- `_update_enemy_positions(delta: float) -> void:`
- `_get_alive_player_positions() -> Dictionary:`
- `_aggro_target_for_enemy(enemy_id: int, enemy_position: Vector3, alive_player_positions: Dictionary) -> Dictionary:`
- `_forced_aggro_target(enemy_id: int, alive_player_positions: Dictionary) -> Dictionary:`
- `_proximity_aggro_target(enemy_id: int, enemy_position: Vector3, alive_player_positions: Dictionary) -> Dictionary:`
- `_nearest_aggro_player(enemy_id: int, enemy_position: Vector3, alive_player_positions: Dictionary) -> Dictionary:`
- `_set_proximity_aggro(enemy_id: int, peer_id: int) -> void:`
- `_set_forced_aggro(enemy_id: int, attacker_peer_id: int) -> void:`
- `_can_start_enemy_melee_attack(enemy_id: int, enemy_position: Vector3, target_position: Vector3) -> bool:`
- `_start_enemy_melee_attack(enemy_id: int, enemy_position: Vector3, target_peer_id: int) -> void:`
- `_update_enemy_melee_windup(enemy_id: int) -> bool:`
- `_resolve_enemy_melee_attack(enemy_id: int) -> void:`
- `_clear_enemy_melee_windup(enemy_id: int) -> void:`
- `_clear_enemy_melee_attack(enemy_id: int) -> void:`
- `_can_start_enemy_ranged_attack(enemy_id: int, enemy_position: Vector3, target_position: Vector3) -> bool:`
- `_start_enemy_ranged_attack(enemy_id: int, enemy_position: Vector3, target_position: Vector3, target_peer_id: int) -> void:`
- `_update_enemy_ranged_windup(enemy_id: int) -> bool:`
- `_resolve_enemy_ranged_attack(enemy_id: int) -> void:`
- `_clear_enemy_ranged_windup(enemy_id: int) -> void:`
- `_clear_enemy_ranged_attack(enemy_id: int) -> void:`
- `_clear_enemy_attacks(enemy_id: int) -> void:`
- `_should_hold_ranged_position(enemy_id: int, enemy_position: Vector3, target_position: Vector3) -> bool:`
- `_is_peer_alive(peer_id: int) -> bool:`
- `_target_peer_for_enemy(enemy_id: int) -> int:`
- `_should_return_with_target(_enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, target_position: Vector3) -> bool:`
- `_should_return_without_target(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3) -> bool:`
- `_begin_return_to_spawn(enemy_id: int, reason: String, enemy_position: Vector3, spawn_position: Vector3, target_position: Vector3, has_target: bool) -> void:`
- `_return_position(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, delta: float) -> Vector3:`
- `_finish_leash_reset(enemy_id: int, enemy_position: Vector3) -> Vector3:`
- `_emergency_leash_snap(enemy_id: int, spawn_position: Vector3) -> Vector3:`
- `_regenerate_enemy_while_returning(enemy_id: int, delta: float) -> void:`
- `_is_enemy_beyond_emergency_failsafe(enemy_id: int) -> bool:`
- `_distance_xz(a: Vector3, b: Vector3) -> float:`
- `_log_server_enemy_snap(enemy_id: int, fallback_previous_position: Vector3, new_position: Vector3, delta: float, behavior: String, target_peer_id: int) -> void:`
- `_log_return_update(enemy_id: int, enemy_position: Vector3, spawn_position: Vector3, distance_from_spawn: float, delta: float, step_distance: float) -> void:`
- `_return_speed(enemy_id: int) -> float:`
- `_move_toward_position(current_position: Vector3, target_position: Vector3, speed: float, delta: float) -> Vector3:`
- `_chase_position(enemy_id: int, enemy_position: Vector3, target_position: Vector3, delta: float) -> Vector3:`
- `_enemy_definition_float(enemy_id: int, key: String, fallback: float) -> float:`
- `_enemy_definition_int(enemy_id: int, key: String, fallback: int) -> int:`
- `_enemy_definition_bool(enemy_id: int, key: String, fallback: bool) -> bool:`
- `_enemy_attack_type(enemy_id: int) -> String:`
- `_enemy_definition_for_enemy(enemy_id: int) -> Dictionary:`
- `_enemy_definition_for_type(enemy_type: String) -> Dictionary:`
- `_resolved_enemy_type(enemy_type: String) -> String:`
- `_enemy_type_for_enemy(enemy_id: int) -> String:`
- `_max_hp_for_enemy(enemy_id: int) -> int:`
- `_max_hp_for_type(enemy_type: String) -> int:`
- `_enemy_display_name(enemy_id: int) -> String:`
- `_enemy_visual_color(enemy_id: int) -> Color:`
- `_broadcast_enemy_position_snapshots() -> void:`
- `_smooth_spawned_enemies(delta: float) -> void:`
- `_log_client_enemy_snap(enemy_id: int, previous_position: Vector3, new_position: Vector3, source: String) -> void:`
- `spawn_enemy(enemy_id: int, spawn_position: Vector3, current_hp: int = 30, max_hp: int = 30, enemy_type: String = DEFAULT_ENEMY_TYPE, display_name: String = "", visual_color: Color = Color(1.0, 0.18, 0.08, 1.0)) -> void:`
- `spawn_enemies(enemy_snapshots: Array) -> void:`
- `_spawn_enemy_visual(enemy_id: int, spawn_position: Vector3, current_hp: int, max_hp: int, enemy_type: String, display_name: String, visual_color: Color, print_spawn: bool, source: String) -> void:`
- `apply_enemy_position_snapshots(snapshots: Array) -> void:`
- `show_enemy_hit(enemy_id: int, current_hp: int, max_hp: int) -> void:`
- `show_enemy_melee_telegraph(enemy_id: int, attack_position: Vector3, radius: float, windup_seconds: float) -> void:`
- `show_enemy_ranged_telegraph(enemy_id: int, start_position: Vector3, target_position: Vector3, width: float, windup_seconds: float) -> void:`
- `despawn_enemy(enemy_id: int) -> void:`
- `_set_enemy_label(enemy: Node, enemy_id: int, current_hp: int, max_hp: int) -> void:`
- `_apply_enemy_visual_color(enemy: Node, visual_color: Color) -> void:`

### Rpcs
- `@rpc("authority", "call_remote", "reliable") func spawn_enemy(enemy_id: int, spawn_position: Vector3, current_hp: int = 30, max_hp: int = 30, enemy_type: String = DEFAULT_ENEMY_TYPE, display_name: String = "", visual_color: Color = Color(1.0, 0.18, 0.08, 1.0)) -> void:`
- `@rpc("authority", "call_remote", "reliable") func spawn_enemies(enemy_snapshots: Array) -> void:`
- `@rpc("authority", "call_remote", "unreliable") func apply_enemy_position_snapshots(snapshots: Array) -> void:`
- `@rpc("authority", "call_remote", "reliable") func show_enemy_hit(enemy_id: int, current_hp: int, max_hp: int) -> void:`
- `@rpc("authority", "call_remote", "reliable") func show_enemy_melee_telegraph(enemy_id: int, attack_position: Vector3, radius: float, windup_seconds: float) -> void:`
- `@rpc("authority", "call_remote", "reliable") func show_enemy_ranged_telegraph(enemy_id: int, start_position: Vector3, target_position: Vector3, width: float, windup_seconds: float) -> void:`
- `@rpc("authority", "call_remote", "reliable") func despawn_enemy(enemy_id: int) -> void:`

## `godot/scripts/shared/world_spawner.gd`

### Class Name
- None found

### Extends
- `Node3D`

### Signals
- `spawned_player_count_changed(count: int)`
- `player_spawned(peer_id: int, player: Node3D)`
- `player_health_updated(peer_id: int, current_hp: int, max_hp: int)`
- `player_down_state_updated(peer_id: int, is_down: bool)`
- `player_combat_stats_updated(peer_id: int, combat_stats: Dictionary)`
- `character_progression_updated(peer_id: int, progression: Dictionary)`
- `character_gold_updated(peer_id: int, gold: int)`
- `character_inventory_updated(peer_id: int, inventory_items: Array)`
- `character_equipment_updated(peer_id: int, equipment: Dictionary)`
- `combat_mode_updated(peer_id: int, combat_enabled: bool, loadout_entries: Array)`
- `ability_enabled_updated(peer_id: int, ability_name: String, enabled: bool)`
- `ability_state_updated(peer_id: int, ability_name: String, enabled: bool, active: bool, cooldown_remaining: float)`
- `ability_catalog_updated(peer_id: int, unlocked_abilities: Array)`
- `ability_unlock_message_received(peer_id: int, display_name: String)`
- `status_message_received(peer_id: int, message: String)`
- `join_requested(peer_id: int, character_id: int, character_name: String, access_token: String)`
- `ability_loadout_update_requested(peer_id: int, loadout_entries: Array)`
- `equipment_update_requested(peer_id: int, equipment_entries: Array)`
- `loot_reward_pickup_requested(peer_id: int, loot_orb_id: int, reward_payload: Dictionary)`

### Exports
- `player_placeholder_scene: PackedScene`
- `movement_speed: float = 4.0`
- `simulation_tick_rate: float = 30.0`
- `snapshot_rate: float = 10.0`
- `interpolation_speed: float = 12.0`
- `local_prediction_enabled: bool = true`
- `local_prediction_correction_deadzone: float = 0.2`
- `local_prediction_snap_distance: float = 3.0`
- `local_prediction_correction_speed: float = 4.0`
- `basic_attack_cooldown_seconds: float = 0.75`
- `player_max_hp: int = 100`
- `enemy_contact_damage_enabled: bool = false`
- `enemy_contact_range: float = 1.75`
- `enemy_contact_damage: int = 10`
- `enemy_contact_damage_interval: float = 1.0`
- `player_respawn_delay_seconds: float = 3.0`
- `prototype_loot_drop_chance: float = 1.0`
- `prototype_loot_pickup_radius: float = 1.5`
- `prototype_loot_reward_type: String = "item"`
- `prototype_loot_gold_amount: int = 3`
- `prototype_loot_item_key: String = "slime_gel"`
- `prototype_loot_item_display_name: String = "Slime Gel"`
- `prototype_loot_item_quantity: int = 1`
- `prototype_equipment_drop_chance: float = 0.15`
- `debug_join_sync_logs: bool = false`

### Functions
- `send_join_request(character_id: int, character_name: String, access_token: String) -> void:`
- `set_local_prediction_input(input_direction: Vector2) -> void:`
- `register_peer(peer_id: int, character_name: String = "", loadout: Array = [], ability_enabled: Dictionary = {}, ability_display_names: Dictionary = {}, ability_keys: Dictionary = {}, unlocked_abilities: Array = [], ability_slot_indexes: Dictionary = {}) -> void:`
- `register_peer_at_position(peer_id: int, character_name: String, spawn_position: Vector3, loadout: Array = [], ability_enabled: Dictionary = {}, ability_display_names: Dictionary = {}, ability_keys: Dictionary = {}, unlocked_abilities: Array = [], ability_slot_indexes: Dictionary = {}) -> void:`
- `_register_peer(peer_id: int, character_name: String, use_custom_spawn: bool, custom_spawn_position: Vector3, loadout: Array, ability_enabled: Dictionary, ability_display_names: Dictionary, ability_keys: Dictionary, unlocked_abilities: Array, ability_slot_indexes: Dictionary) -> void:`
- `_sync_existing_players_to_peer(peer_id: int) -> void:`
- `unregister_peer(peer_id: int) -> void:`
- `get_authoritative_position(peer_id: int) -> Vector3:`
- `get_alive_player_positions() -> Dictionary:`
- `get_spawned_player(peer_id: int) -> Node3D:`
- `_register_player(peer_id: int, use_custom_spawn: bool = false, custom_spawn_position: Vector3 = Vector3.ZERO, loadout: Array = [], ability_enabled: Dictionary = {}, ability_display_names: Dictionary = {}, ability_keys: Dictionary = {}, unlocked_abilities: Array = [], ability_slot_indexes: Dictionary = {}) -> void:`
- `apply_confirmed_character_progression(peer_id: int, progression: Dictionary) -> void:`
- `apply_confirmed_character_gold(peer_id: int, gold: int) -> void:`
- `apply_confirmed_character_inventory(peer_id: int, inventory_items: Array) -> void:`
- `apply_confirmed_character_equipment(peer_id: int, equipment: Dictionary) -> void:`
- `spawn_prototype_loot_drop(drop_position: Vector3) -> void:`
- `_prototype_loot_reward_payloads() -> Array:`
- `_prototype_equipment_reward_payload() -> Dictionary:`
- `_prototype_loot_position_offset(reward_index: int, reward_count: int) -> Vector3:`
- `_process(delta: float) -> void:`
- `_simulate(delta: float) -> void:`
- `_apply_enemy_contact_damage(_delta: float) -> void:`
- `apply_enemy_melee_damage(peer_id: int, damage: int) -> bool:`
- `apply_enemy_damage_to_player(peer_id: int, raw_damage: int) -> bool:`
- `_modified_player_damage_taken(peer_id: int, raw_damage: int) -> int:`
- `_default_player_combat_stats() -> Dictionary:`
- `_recalculate_player_combat_stats(peer_id: int, restore_current_hp_to_max: bool = false) -> void:`
- `_apply_equipped_item_stat_modifiers(peer_id: int, combat_stats: Dictionary) -> void:`
- `_equipment_item_stat_modifiers(equipment_item: Dictionary) -> Array:`
- `_apply_stat_modifier_to_combat_stats(combat_stats: Dictionary, modifier: Dictionary) -> void:`
- `_is_percent_modifier(modifier_type: String) -> bool:`
- `_percent_modifier_value(value: float) -> float:`
- `_apply_computed_player_max_hp(peer_id: int, computed_max_hp: int, restore_current_hp_to_max: bool = false) -> void:`
- `_mark_player_down(peer_id: int) -> void:`
- `_schedule_player_respawn(peer_id: int) -> void:`
- `_on_player_respawn_timer_timeout(peer_id: int, respawn_timer: Timer) -> void:`
- `_is_enemy_in_contact_range(player_position: Vector3, enemy_positions: Dictionary) -> bool:`
- `_process_prototype_loot_pickups() -> void:`
- `_validate_prototype_loot_pickup(peer_id: int, loot_orb_id: int) -> bool:`
- `_complete_prototype_loot_pickup(peer_id: int, loot_orb_id: int) -> void:`
- `confirm_loot_pickup(loot_orb_id: int) -> void:`
- `reject_loot_pickup(loot_orb_id: int) -> void:`
- `_process_combat_abilities() -> void:`
- `_default_ability_enabled_state() -> Dictionary:`
- `_ability_enabled_state_for_loadout(loadout: Array, ability_enabled: Dictionary) -> Dictionary:`
- `_ability_keys_for_loadout(loadout: Array, ability_keys: Dictionary) -> Dictionary:`
- `_ability_slot_indexes_for_loadout(loadout: Array, ability_slot_indexes: Dictionary) -> Dictionary:`
- `_ability_display_names_for_loadout(loadout: Array, ability_display_names: Dictionary) -> Dictionary:`
- `_is_ability_enabled(peer_id: int, ability_name: String) -> bool:`
- `_is_hp_regen_active(peer_id: int) -> bool:`
- `_broadcast_hp_regen_active_state(peer_id: int) -> void:`
- `_send_ability_enabled_states(peer_id: int) -> void:`
- `_send_ability_states(peer_id: int) -> void:`
- `apply_confirmed_ability_data(peer_id: int, loadout: Array, ability_enabled: Dictionary, ability_display_names: Dictionary, ability_keys: Dictionary, unlocked_abilities: Array, ability_slot_indexes: Dictionary) -> void:`
- `_send_ability_state(peer_id: int, ability_name: String) -> void:`
- `_is_ability_ready(peer_id: int, ability_name: String, now_seconds: float) -> bool:`
- `_ability_cooldown_remaining(peer_id: int, ability_name: String) -> float:`
- `_set_ability_used(peer_id: int, ability_name: String, now_seconds: float) -> void:`
- `_ability_cooldown(ability_name: String) -> float:`
- `_ability_heal_amount(ability_name: String) -> int:`
- `_ability_damage_amount(ability_name: String) -> int:`
- `_ability_radius(ability_name: String) -> float:`
- `_ability_range(ability_name: String) -> float:`
- `_ability_width(ability_name: String) -> float:`
- `_apply_hp_regen(peer_id: int) -> void:`
- `_perform_damage_aura(peer_id: int) -> void:`
- `_perform_firebolt(peer_id: int) -> void:`
- `_loadout_entries(peer_id: int) -> Array:`
- `_broadcast_position_snapshots() -> void:`
- `_send_position_snapshots(target_peer_id: int) -> void:`
- `_sync_loot_orbs_to_peer(peer_id: int) -> void:`
- `_smooth_spawned_players(delta: float) -> void:`
- `_predict_and_reconcile_local_player(player: Node3D, peer_id: int, delta: float) -> void:`
- `_spawn_position_for_index(spawn_index: int) -> Vector3:`
- `spawn_player(peer_id: int, spawn_position: Vector3, character_name: String = "") -> void:`
- `_spawn_player_visual(peer_id: int, spawn_position: Vector3, character_name: String, print_spawn: bool) -> void:`
- `spawn_players(player_snapshots: Array) -> void:`
- `apply_position_snapshot(peer_id: int, authoritative_position: Vector3, facing_direction: Vector2 = Vector2(0.0, -1.0)) -> void:`
- `apply_player_health_update(peer_id: int, current_hp: int, max_hp: int) -> void:`
- `apply_player_down_state(peer_id: int, is_down: bool) -> void:`
- `apply_player_combat_stats_update(peer_id: int, combat_stats: Dictionary) -> void:`
- `apply_character_progression_update(peer_id: int, progression: Dictionary) -> void:`
- `apply_character_gold_update(peer_id: int, gold: int) -> void:`
- `apply_character_inventory_update(peer_id: int, inventory_items: Array) -> void:`
- `apply_character_equipment_update(peer_id: int, equipment: Dictionary) -> void:`
- `apply_combat_mode_update(peer_id: int, combat_enabled: bool, loadout_entries: Array) -> void:`
- `apply_ability_catalog_update(peer_id: int, unlocked_abilities: Array) -> void:`
- `apply_ability_unlock_message(peer_id: int, display_name: String) -> void:`
- `apply_status_message(peer_id: int, message: String) -> void:`
- `apply_ability_enabled_update(peer_id: int, ability_name: String, enabled: bool) -> void:`
- `apply_ability_state_update(peer_id: int, ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:`
- `apply_hp_regen_active_state(peer_id: int, active: bool) -> void:`
- `request_join(character_id: int, character_name: String, access_token: String) -> void:`
- `submit_movement_input(input_direction: Vector2) -> void:`
- `submit_aim_input(aim_direction: Vector2) -> void:`
- `request_toggle_combat_mode() -> void:`
- `request_set_ability_enabled(ability_name: String, enabled: bool) -> void:`
- `request_update_ability_loadout(loadout_entries: Array) -> void:`
- `request_update_equipment(equipment_entries: Array) -> void:`
- `_is_valid_equipment_request(equipment_entries: Array) -> bool:`
- `_is_valid_loadout_request(peer_id: int, loadout_entries: Array) -> bool:`
- `submit_basic_attack() -> void:`
- `_perform_slash(peer_id: int) -> void:`
- `show_basic_attack(peer_id: int, attack_position: Vector3, facing_direction: Vector2) -> void:`
- `show_damage_aura(peer_id: int, aura_position: Vector3, radius: float) -> void:`
- `show_firebolt(peer_id: int, firebolt_position: Vector3, aim_direction: Vector2, firebolt_range: float) -> void:`
- `spawn_loot_orb(loot_orb_id: int, loot_position: Vector3) -> void:`
- `despawn_loot_orb(loot_orb_id: int) -> void:`
- `despawn_player(peer_id: int) -> void:`
- `_set_peer_label(player: Node, peer_id: int, character_name: String = "") -> void:`
- `_update_hp_regen_visual(peer_id: int, active: bool) -> void:`
- `_apply_player_facing(player: Node3D, facing_direction: Vector2) -> void:`
- `_distance_xz(a: Vector3, b: Vector3) -> float:`
- `_is_local_player_peer(peer_id: int) -> bool:`

### Rpcs
- `@rpc("authority", "call_remote", "reliable") func spawn_player(peer_id: int, spawn_position: Vector3, character_name: String = "") -> void:`
- `@rpc("authority", "call_remote", "reliable") func spawn_players(player_snapshots: Array) -> void:`
- `@rpc("authority", "call_remote", "unreliable") func apply_position_snapshot(peer_id: int, authoritative_position: Vector3, facing_direction: Vector2 = Vector2(0.0, -1.0)) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_player_health_update(peer_id: int, current_hp: int, max_hp: int) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_player_down_state(peer_id: int, is_down: bool) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_player_combat_stats_update(peer_id: int, combat_stats: Dictionary) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_character_progression_update(peer_id: int, progression: Dictionary) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_character_gold_update(peer_id: int, gold: int) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_character_inventory_update(peer_id: int, inventory_items: Array) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_character_equipment_update(peer_id: int, equipment: Dictionary) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_combat_mode_update(peer_id: int, combat_enabled: bool, loadout_entries: Array) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_ability_catalog_update(peer_id: int, unlocked_abilities: Array) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_ability_unlock_message(peer_id: int, display_name: String) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_status_message(peer_id: int, message: String) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_ability_enabled_update(peer_id: int, ability_name: String, enabled: bool) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_ability_state_update(peer_id: int, ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:`
- `@rpc("authority", "call_remote", "reliable") func apply_hp_regen_active_state(peer_id: int, active: bool) -> void:`
- `@rpc("any_peer", "call_remote", "reliable") func request_join(character_id: int, character_name: String, access_token: String) -> void:`
- `@rpc("any_peer", "call_remote", "unreliable") func submit_movement_input(input_direction: Vector2) -> void:`
- `@rpc("any_peer", "call_remote", "unreliable") func submit_aim_input(aim_direction: Vector2) -> void:`
- `@rpc("any_peer", "call_remote", "reliable") func request_toggle_combat_mode() -> void:`
- `@rpc("any_peer", "call_remote", "reliable") func request_set_ability_enabled(ability_name: String, enabled: bool) -> void:`
- `@rpc("any_peer", "call_remote", "reliable") func request_update_ability_loadout(loadout_entries: Array) -> void:`
- `@rpc("any_peer", "call_remote", "reliable") func request_update_equipment(equipment_entries: Array) -> void:`
- `@rpc("any_peer", "call_remote", "reliable") func submit_basic_attack() -> void:`
- `@rpc("authority", "call_remote", "reliable") func show_basic_attack(peer_id: int, attack_position: Vector3, facing_direction: Vector2) -> void:`
- `@rpc("authority", "call_remote", "reliable") func show_damage_aura(peer_id: int, aura_position: Vector3, radius: float) -> void:`
- `@rpc("authority", "call_remote", "reliable") func show_firebolt(peer_id: int, firebolt_position: Vector3, aim_direction: Vector2, firebolt_range: float) -> void:`
- `@rpc("authority", "call_remote", "reliable") func spawn_loot_orb(loot_orb_id: int, loot_position: Vector3) -> void:`
- `@rpc("authority", "call_remote", "reliable") func despawn_loot_orb(loot_orb_id: int) -> void:`
- `@rpc("authority", "call_remote", "reliable") func despawn_player(peer_id: int) -> void:`

