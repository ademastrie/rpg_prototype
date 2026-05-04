# AGENTS.md

## Project goal

This is a learning prototype for a persistent-feeling online action RPG in Godot.

## Architecture rules

- The Godot client never connects directly to PostgreSQL.
- The FastAPI backend owns authentication, account data, character persistence, and durable world state.
- PostgreSQL stores durable state only.
- PostgreSQL is not used for per-frame movement, combat, projectiles, or monster AI.
- The Godot dedicated server owns live gameplay simulation.
- Enemy AI, enemy HP, player HP, damage, ability execution, cooldowns, and respawn are server-authoritative.
- The client owns visuals, input, and UI only; it sends input intent, not final authoritative results.
- Join sync is read-only serialization of current server state and must not reset live enemy/player simulation state.
- Targeted sync to a joining peer must not broadcast full world state to existing peers.
- Client display RPCs should no-op on the server or otherwise avoid mutating server simulation.
- Current hardcoded Godot ability/enemy definitions are temporary prototype structures that should eventually be backend/database-backed.
- Planned persistent gameplay data includes ability definitions/effects, character ability unlocks, character ability loadout, enabled ability state, player/character stats, enemy definitions, region spawn rules, loot tables, gear/items, inventory, and equipment.
- Ability model: ability = trigger + targeting shape + one or more effects. Auras may apply damage, healing, regeneration, defense, movement speed, or other stat effects.
- First persistent gameplay implementation target: ability definitions/effects, character ability unlocks, and character ability loadout/enabled state.
- Godot server still owns live simulation: current HP during the session, cooldowns, active effects, enemy simulation, hit detection, and damage/healing resolution.
- Regions may be capped, channeled, or transferred behind transitions.
- Make small, reviewable changes.
- Do not rewrite the project architecture without explicit approval.

## Backend commands

From `backend/`:

```powershell
.\.venv\Scripts\activate
uvicorn app.main:app --reload
```

## Local Python Environment Rule

- `backend/.venv/` is the developer's local virtual environment.
- Do not delete, rename, or recreate `backend/.venv/`.
- `backend/scripts/setup_dev.ps1` may install or update packages inside an existing `backend/.venv/`, but must not replace it.
- Do not run commands such as:
  - `Remove-Item backend/.venv`
  - `rmdir backend/.venv`
  - `rm -rf backend/.venv`
- If the sandbox cannot run the existing `.venv`, skip execution and tell the developer the local command to run.
- If a sandbox-specific environment is needed, create `backend/.codex_venv/` instead of touching `backend/.venv/`.
- Do not modify `backend/.env`.
