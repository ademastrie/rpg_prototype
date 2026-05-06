# Testing Notes

## Backend

From `backend/`:

```powershell
.\.venv\Scripts\activate
uvicorn app.main:app --reload
alembic current
alembic upgrade head
```

### Character progression

The character progression migration is:

```powershell
alembic upgrade head
alembic current
```

Swagger:

```powershell
Start-Process http://127.0.0.1:8000/docs
```

In Swagger, log in through `POST /auth/login`, use the returned bearer token with
Authorize, then try `POST /characters/{character_id}/xp` with:

```json
{
  "xp_amount": 25
}
```

The response should include `character_id`, `level`, `xp`, and `xp_to_next`.
With the temporary formula, XP to next level is `level * 100`, and extra XP
rolls into the next level after a level-up.

PowerShell:

```powershell
$BaseUrl = "http://127.0.0.1:8000"
$Auth = Invoke-RestMethod -Method Post "$BaseUrl/auth/login" -ContentType "application/json" -Body '{"email":"dev@example.com","password":"password"}'
$Headers = @{ Authorization = "Bearer $($Auth.access_token)" }

$Characters = Invoke-RestMethod -Method Get "$BaseUrl/characters" -Headers $Headers
$CharacterId = $Characters[0].id

$XpBody = @{ xp_amount = 25 } | ConvertTo-Json
Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/xp" -Headers $Headers -ContentType "application/json" -Body $XpBody

# Ownership check: repeat the request with another user's token and the same character id.
# The expected result is 404 Character not found.
```

### Character currency

The character gold migration is:

```powershell
alembic upgrade head
alembic current
```

Swagger:

```powershell
Start-Process http://127.0.0.1:8000/docs
```

In Swagger, log in through `POST /auth/login`, use the returned bearer token with
Authorize, then try `POST /characters/{character_id}/currency` with:

```json
{
  "gold_amount": 3
}
```

The response should include `character_id` and the updated `gold` total.
Negative `gold_amount` values should return 422.

PowerShell:

```powershell
$BaseUrl = "http://127.0.0.1:8000"
$Auth = Invoke-RestMethod -Method Post "$BaseUrl/auth/login" -ContentType "application/json" -Body '{"email":"dev@example.com","password":"password"}'
$Headers = @{ Authorization = "Bearer $($Auth.access_token)" }

$Characters = Invoke-RestMethod -Method Get "$BaseUrl/characters" -Headers $Headers
$CharacterId = $Characters[0].id

$GoldBody = @{ gold_amount = 3 } | ConvertTo-Json
Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/currency" -Headers $Headers -ContentType "application/json" -Body $GoldBody

$NegativeGoldBody = @{ gold_amount = -1 } | ConvertTo-Json
try {
    Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/currency" -Headers $Headers -ContentType "application/json" -Body $NegativeGoldBody
} catch {
    $_.Exception.Response.StatusCode.value__
}

# Ownership check: repeat the request with another user's token and the same character id.
# The expected result is 404 Character not found.
```

### Character inventory

The item definition and character inventory migration is:

```powershell
alembic upgrade head
alembic current
```

Swagger:

```powershell
Start-Process http://127.0.0.1:8000/docs
```

In Swagger, log in through `POST /auth/login`, use the returned bearer token with
Authorize, then try:

- `GET /characters/{character_id}/inventory`
- `POST /characters/{character_id}/inventory/items`

Use one of the seeded prototype material keys:

```json
{
  "item_key": "slime_gel",
  "quantity": 2
}
```

The response should include `character_id`, inventory item definition display data,
and the updated `quantity`. Zero or negative `quantity` values should return 422.
Unknown or inactive item keys should return 422.

PowerShell:

```powershell
$BaseUrl = "http://127.0.0.1:8000"
$Auth = Invoke-RestMethod -Method Post "$BaseUrl/auth/login" -ContentType "application/json" -Body '{"email":"dev@example.com","password":"password"}'
$Headers = @{ Authorization = "Bearer $($Auth.access_token)" }

$Characters = Invoke-RestMethod -Method Get "$BaseUrl/characters" -Headers $Headers
$CharacterId = $Characters[0].id

Invoke-RestMethod -Method Get "$BaseUrl/characters/$CharacterId/inventory" -Headers $Headers

$ItemBody = @{ item_key = "slime_gel"; quantity = 2 } | ConvertTo-Json
Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/inventory/items" -Headers $Headers -ContentType "application/json" -Body $ItemBody

$MoreItemBody = @{ item_key = "slime_gel"; quantity = 3 } | ConvertTo-Json
Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/inventory/items" -Headers $Headers -ContentType "application/json" -Body $MoreItemBody

$InvalidItemBody = @{ item_key = "slime_gel"; quantity = 0 } | ConvertTo-Json
try {
    Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/inventory/items" -Headers $Headers -ContentType "application/json" -Body $InvalidItemBody
} catch {
    $_.Exception.Response.StatusCode.value__
}

# Ownership check: repeat the GET or POST with another user's token and the same character id.
# The expected result is 404 Character not found.
```

### Character abilities and loadout

The ability endpoints use the same bearer token auth as the other character endpoints.
For characters without ability rows yet, the backend seeds a safe starter ability and
fills the initial loadout from unlocked abilities. New character creation accepts a
starter ability choice and puts that ability in loadout slot `0`.

Swagger:

```powershell
Start-Process http://127.0.0.1:8000/docs
```

In Swagger, log in through `POST /auth/login`, use the returned bearer token with
Authorize, then try:

- `GET /characters/{character_id}/abilities`
- `POST /characters/{character_id}/abilities/{ability_key}/unlock`
- `PUT /characters/{character_id}/ability-loadout`

PowerShell:

```powershell
$BaseUrl = "http://127.0.0.1:8000"
$Auth = Invoke-RestMethod -Method Post "$BaseUrl/auth/login" -ContentType "application/json" -Body '{"email":"dev@example.com","password":"password"}'
$Headers = @{ Authorization = "Bearer $($Auth.access_token)" }

$Characters = Invoke-RestMethod -Method Get "$BaseUrl/characters" -Headers $Headers
$CharacterId = $Characters[0].id

Invoke-RestMethod -Method Get "$BaseUrl/characters/$CharacterId/abilities" -Headers $Headers

# Unlock is idempotent. Re-running this should still return success.
Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/abilities/firebolt/unlock" -Headers $Headers

# Unknown abilities should be rejected.
Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/abilities/not_real/unlock" -Headers $Headers

$Body = @{
    loadout = @(
        @{ slot_index = 0; ability_key = "slash"; enabled = $true },
        @{ slot_index = 1; ability_key = "firebolt"; enabled = $true }
    )
} | ConvertTo-Json -Depth 4

Invoke-RestMethod -Method Put "$BaseUrl/characters/$CharacterId/ability-loadout" -Headers $Headers -ContentType "application/json" -Body $Body
```

### Character deletion

Character deletion uses bearer token auth and only deletes characters owned by the
authenticated user. Character ability rows and loadout rows are removed with the
character; user accounts and global ability definitions remain.

PowerShell:

```powershell
$BaseUrl = "http://127.0.0.1:8000"
$Auth = Invoke-RestMethod -Method Post "$BaseUrl/auth/login" -ContentType "application/json" -Body '{"email":"dev@example.com","password":"password"}'
$Headers = @{ Authorization = "Bearer $($Auth.access_token)" }

$CreateBody = @{ name = "Delete Me"; starter_ability_key = "slash" } | ConvertTo-Json
$Character = Invoke-RestMethod -Method Post "$BaseUrl/characters" -Headers $Headers -ContentType "application/json" -Body $CreateBody

Invoke-RestMethod -Method Delete "$BaseUrl/characters/$($Character.id)" -Headers $Headers
Invoke-RestMethod -Method Get "$BaseUrl/characters" -Headers $Headers

# Ownership check: repeat the delete with another user's token and the same character id.
# The expected result is 404 Character not found.
```

In Godot, log in, select a character on the character select screen, confirm
Delete Character, and confirm that the list refreshes with no selected character.

## Local Environment Rules

- Do not modify `backend/.env`.
- Do not delete, rename, recreate, or replace `backend/.venv`.
- `backend/scripts/setup_dev.ps1` may install or update dependencies inside an existing `.venv`, but must not replace it.
- If sandbox Python launchers fail, do not change `.venv`; tell the developer the local command to run.
- If a sandbox-specific environment is needed, use `backend/.codex_venv`.
