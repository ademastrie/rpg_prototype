# Backend Testing

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
