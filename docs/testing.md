# Testing Notes

## Backend

From `backend/`:

```powershell
.\.venv\Scripts\activate
uvicorn app.main:app --reload
alembic current
```

### Character abilities and loadout

The ability endpoints use the same bearer token auth as the other character endpoints.
For characters without ability rows yet, the backend seeds the active prototype ability
definitions as starter abilities and fills the initial loadout in slots `0` through `4`
in ability definition order.

Swagger:

```powershell
Start-Process http://127.0.0.1:8000/docs
```

PowerShell:

```powershell
$BaseUrl = "http://127.0.0.1:8000"
$Auth = Invoke-RestMethod -Method Post "$BaseUrl/auth/login" -ContentType "application/json" -Body '{"email":"dev@example.com","password":"password"}'
$Headers = @{ Authorization = "Bearer $($Auth.access_token)" }

$Characters = Invoke-RestMethod -Method Get "$BaseUrl/characters" -Headers $Headers
$CharacterId = $Characters[0].id

Invoke-RestMethod -Method Get "$BaseUrl/characters/$CharacterId/abilities" -Headers $Headers

$Body = @{
    loadout = @(
        @{ slot_index = 0; ability_key = "slash"; enabled = $true },
        @{ slot_index = 1; ability_key = "firebolt"; enabled = $true }
    )
} | ConvertTo-Json -Depth 4

Invoke-RestMethod -Method Put "$BaseUrl/characters/$CharacterId/ability-loadout" -Headers $Headers -ContentType "application/json" -Body $Body
```

## Local Environment Rules

- Do not modify `backend/.env`.
- Do not delete, rename, recreate, or replace `backend/.venv`.
- `backend/scripts/setup_dev.ps1` may install or update dependencies inside an existing `.venv`, but must not replace it.
- If sandbox Python launchers fail, do not change `.venv`; tell the developer the local command to run.
- If a sandbox-specific environment is needed, use `backend/.codex_venv`.
