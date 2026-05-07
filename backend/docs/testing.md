# Backend Testing

## Prototype content sync

Run migrations and sync source-controlled prototype content from `backend/`:

```powershell
alembic upgrade head
python .\scripts\sync_content.py
```

The sync prints inserted and updated row counts for each content table. It is designed to be run repeatedly without dropping tables or deleting player-owned data.

## Region patrol paths

Run migrations from `backend/` after activating your local environment:

```powershell
alembic upgrade head
```

Start the backend with your normal local command, then open Swagger:

```powershell
Start-Process "http://localhost:8000/docs"
```

In Swagger, check:

- `GET /regions/starter_field/patrol-paths`
- `GET /regions/starter_field/enemy-spawns`

PowerShell smoke checks:

```powershell
Invoke-RestMethod "http://localhost:8000/regions/starter_field/patrol-paths" | ConvertTo-Json -Depth 10
Invoke-RestMethod "http://localhost:8000/regions/starter_field/enemy-spawns" | ConvertTo-Json -Depth 10
```

Expected patrol path seed:

- `starter_field_grunt_patrol_1`
- ordered points with `point_order` values `1` through `4`

Expected spawn update:

- `starter_field_grunt_west` has `behavior_profile_key` set to `patrol`
- `starter_field_grunt_west` has `patrol_path_key` set to `starter_field_grunt_patrol_1`
