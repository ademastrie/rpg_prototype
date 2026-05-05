# Godot Symbol Summary

Generated-style human summary. Regenerate with `tools/summarize_repo.py` when source changes.

## `godot/scripts/backend_api_client.gd`

- `class_name BackendApiClient`, extends `Node`.
- Role: Queued JSON HTTP client for Godot-to-FastAPI calls.
- Signals: `request_succeeded(request_id, endpoint, data)`, `request_failed(request_id, endpoint, status_code, message)`.
- Exported config: `base_url`.
- Main functions: `configure`, `register`, `login`, `get_current_user`, `list_characters`, `create_character`, `_queue_json_request`, `_process_next_request`, `_on_request_completed`.

## `godot/scripts/client/client_session.gd`

- Extends `Node`; autoloaded as `ClientSession`.
- Role: Stores selected session/character data between login UI and game scene.
- Main function: `clear`.

## `godot/scripts/client/login_character_select.gd`

- Extends `Control`.
- Role: Login/register/create/list/select character UI and transition into game scene.
- Uses `BackendApiClient` child and `ClientSession` autoload.
- Main functions: button handlers for register/login/create/refresh/enter-game, request success/failure routing, character list display, starter ability option setup.

## `godot/scripts/client/client_game.gd`

- Extends `Node3D`.
- Role: Runtime multiplayer client. Connects to server, sends input/aim/combat/ability intent, handles local camera/HUD, applies server updates.
- Important exports: server host/port, input and aim heartbeat intervals, aim threshold, camera follow speed, startup debug toggles.
- Key groups: connection lifecycle, spawn/health/progression/combat/HUD update handlers, movement/aim/basic attack input readers, RPC intent senders, camera follow.

## `godot/scripts/client/game_hud.gd`

- Extends `CanvasLayer`.
- Role: Local-only HUD for health, XP/level, down state, combat mode, combat stats, ability loadout, ability enabled/active/cooldown state, and status messages.
- Signals to client runtime: `combat_toggle_requested`, `ability_toggle_requested`, `loadout_save_requested`.
- Key groups: update display methods, ability panel build/refresh methods, button/checkbox handlers.

## `godot/scripts/client/isometric_camera.gd`

- Extends `Camera3D`.
- Role: Configures isometric camera position/look target/orthographic size.

## `godot/scripts/server/server_game.gd`

- Extends `Node`.
- Role: Dedicated-server runtime and main server-authoritative gameplay script.
- Important exports: server port, backend base URL, region id, startup/join debug toggles.
- Key groups: server startup/peer lifecycle, backend join validation, backend ability/loadout fetch/update, XP/unlock flow, live player state, ability cooldown/effect resolution, enemy kill handling, position snapshots, player spawning/despawning, client display RPCs, client intent RPCs.
- RPC directions:
  - Authority-to-client display/sync: spawn players, position snapshots, health/down/combat/progression/ability states, visual attack/aura/firebolt effects, despawn.
  - Client-to-server intent: join, movement input, aim input, combat toggle, ability enabled toggle, loadout update, basic attack.

## `godot/scripts/shared/world_spawner.gd`

- Role: Shared player/world spawning helpers used by client/server scenes.
- Context hint: inspect with `client_game.gd` and `server_game.gd` for spawn or sync bugs.

## `godot/scripts/shared/enemy_spawner.gd`

- Role: Shared enemy placeholder spawning/state helpers.
- Context hint: inspect with `server_game.gd` for enemy authority/performance/sync bugs.
