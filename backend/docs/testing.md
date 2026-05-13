# Backend Testing

## Prototype content sync

Run migrations and sync source-controlled prototype content from `backend/`:

```powershell
alembic upgrade head
python .\scripts\sync_content.py
```

The sync prints inserted and updated row counts for each content table. It is designed to be run repeatedly without dropping tables or deleting player-owned data.

For XP/content changes, run migrations and round-trip content from `backend/`:

```powershell
alembic upgrade head
python .\scripts\sync_content.py
python .\scripts\export_content.py
```

Enemy kill XP is awarded through the server-only endpoint. Configure `GAME_SERVER_SECRET` in your local backend environment, start the backend normally, then smoke check with a matching `X-Game-Server-Secret` header:

```powershell
$headers = @{ "X-Game-Server-Secret" = "<local-game-server-secret>" }
$body = @{
  character_id = 1
  enemy_key = "grunt"
  region_key = "starter_field"
} | ConvertTo-Json
Invoke-RestMethod -Method Post "http://localhost:8000/game/server/award-enemy-xp" -Headers $headers -Body $body -ContentType "application/json"
```

The response confirms `character_id`, `level`, `current_xp`, `xp_to_next_level`, `xp_awarded`, `leveled_up`, and `levels_gained`. XP uses enemy `base_xp`, enemy/player level delta, and region `xp_multiplier`; no level cap is implemented yet.

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
