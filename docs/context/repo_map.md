# Repo Map

## Top-Level Shape

- `godot/`: Godot 4.5 client/server project.
- `backend/`: FastAPI backend with SQLAlchemy/Alembic persistence.
- `docs/`: Human-authored architecture notes.
- `scripts/`: helper launch scripts.
- `tools/`: lightweight local tooling for repo summaries.

## Durable Architecture Rules

- Backend/PostgreSQL owns accounts, characters, progression, unlocks, loadout, and future durable game definitions.
- Godot dedicated server owns live simulation: movement authority, enemies, HP, combat, cooldowns, active effects, respawn, and sync.
- Godot client owns login/character select, visual interpolation, camera, HUD, input collection, and intent submission.
- Clients send intent; they do not send authoritative combat/gameplay results.

## Godot Entry Points

- `godot/project.godot`: project config; main scene currently `res://scenes/dev/backend_api_test.tscn`.
- Autoload: `ClientSession` from `godot/scripts/client/client_session.gd`.

## Godot Client Files

- `godot/scripts/client/login_character_select.gd`: login/register/create/list character UI. Owns selected character flow into game scene.
- `godot/scripts/backend_api_client.gd`: reusable HTTP client for backend JSON requests.
- `godot/scripts/client/client_session.gd`: small autoload storing selected session data.
- `godot/scripts/client/client_game.gd`: multiplayer client runtime. Connects to dedicated server, sends input/aim/combat/ability intent, owns local camera/HUD updates, applies server RPC state.
- `godot/scripts/client/game_hud.gd`: local-only HUD for health, progression, combat toggle, ability loadout, ability states, status messages.
- `godot/scripts/client/isometric_camera.gd`: simple camera setup.

## Godot Server/Shared Files

- `godot/scripts/server/server_game.gd`: dedicated server runtime and server-authoritative gameplay. Handles join validation with backend, character ability loading, player/enemy state, combat, cooldowns, XP/unlocks, position snapshots, and RPC sync.
- `godot/scripts/shared/world_spawner.gd`: player visual spawning/tracking and RPC-facing shared world helpers.
- `godot/scripts/shared/enemy_spawner.gd`: enemy placeholder spawning/state helpers used by server/client world scenes.

## Backend Files

- `backend/app/main.py`: FastAPI app setup and health endpoint.
- `backend/app/config.py`: settings loaded from environment.
- `backend/app/db.py`: SQLAlchemy session dependency.
- `backend/app/auth/*`: registration, login, token creation/validation, current-user dependency.
- `backend/app/characters/*`: character CRUD, XP/leveling, ability unlocks, ability loadout.
- `backend/app/game/router.py`: game-server-facing endpoints for join validation and saving position.
- `backend/app/models/*`: SQLAlchemy models for users, characters, ability definitions/effects/unlocks/loadout.
- `backend/alembic/versions/*`: database migrations.

## Context Selection Hints

- Login/character issues: `login_character_select.gd`, `backend_api_client.gd`, `ClientSession`, `backend/app/auth/*`, `backend/app/characters/*`.
- Join/spawn issues: `client_game.gd`, `server_game.gd`, `world_spawner.gd`, `backend/app/game/router.py`.
- Combat/ability issues: `server_game.gd`, `game_hud.gd`, `backend/app/characters/router.py`, `docs/ability_model.md`.
- Persistence/backend issues: backend routers/models/migrations first; Godot only if API call shape is involved.
- Enemy sync/performance issues: `server_game.gd`, `enemy_spawner.gd`, `client_game.gd`.
