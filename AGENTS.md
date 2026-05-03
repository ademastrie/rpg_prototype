# AGENTS.md

## Project goal

This is a learning prototype for a persistent-feeling online action RPG in Godot.

## Architecture rules

- The Godot client never connects directly to PostgreSQL.
- The FastAPI backend owns authentication, account data, character persistence, and durable world state.
- PostgreSQL stores durable state only.
- PostgreSQL is not used for per-frame movement, combat, projectiles, or monster AI.
- The Godot dedicated server owns live gameplay simulation.
- The client sends input intent, not final authoritative results.
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
