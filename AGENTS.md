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

If backend virtualenv launchers fail because they point at a missing Python executable, recreate `backend/.venv` from `backend/requirements.txt` using:

```powershell
.\backend\scripts\setup_dev.ps1
```
