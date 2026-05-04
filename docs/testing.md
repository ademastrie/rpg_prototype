# Testing Notes

## Backend

From `backend/`:

```powershell
.\.venv\Scripts\activate
uvicorn app.main:app --reload
alembic current
```

## Local Environment Rules

- Do not modify `backend/.env`.
- Do not delete, rename, recreate, or replace `backend/.venv`.
- `backend/scripts/setup_dev.ps1` may install or update dependencies inside an existing `.venv`, but must not replace it.
- If sandbox Python launchers fail, do not change `.venv`; tell the developer the local command to run.
- If a sandbox-specific environment is needed, use `backend/.codex_venv`.
