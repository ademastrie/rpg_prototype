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

### Character equipment

The character equipment migration is:

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

- `GET /characters/{character_id}/equipment`
- `PUT /characters/{character_id}/equipment`

Equip requests use `equip_slot` and `item_key`. Send `null` or an empty string for
`item_key` to unequip that slot.

```json
{
  "equip_slot": "weapon",
  "item_key": "training_sword"
}
```

Seeded prototype equipment keys are `training_sword`, `apprentice_staff`,
`simple_bow`, `cloth_hood`, `padded_chest`, `cloth_wraps`, `training_gloves`,
`cloth_pants`, and `worn_boots`. A character must have the item in inventory before
equipping it.

PowerShell:

```powershell
$BaseUrl = "http://127.0.0.1:8000"
$Auth = Invoke-RestMethod -Method Post "$BaseUrl/auth/login" -ContentType "application/json" -Body '{"email":"dev@example.com","password":"password"}'
$Headers = @{ Authorization = "Bearer $($Auth.access_token)" }

$Characters = Invoke-RestMethod -Method Get "$BaseUrl/characters" -Headers $Headers
$CharacterId = $Characters[0].id

Invoke-RestMethod -Method Get "$BaseUrl/characters/$CharacterId/equipment" -Headers $Headers

$GrantSwordBody = @{ item_key = "training_sword"; quantity = 1 } | ConvertTo-Json
Invoke-RestMethod -Method Post "$BaseUrl/characters/$CharacterId/inventory/items" -Headers $Headers -ContentType "application/json" -Body $GrantSwordBody

$EquipSwordBody = @{ equip_slot = "weapon"; item_key = "training_sword" } | ConvertTo-Json
Invoke-RestMethod -Method Put "$BaseUrl/characters/$CharacterId/equipment" -Headers $Headers -ContentType "application/json" -Body $EquipSwordBody

$UnequipWeaponBody = @{ equip_slot = "weapon"; item_key = $null } | ConvertTo-Json
Invoke-RestMethod -Method Put "$BaseUrl/characters/$CharacterId/equipment" -Headers $Headers -ContentType "application/json" -Body $UnequipWeaponBody

$WrongSlotBody = @{ equip_slot = "head"; item_key = "training_sword" } | ConvertTo-Json
try {
    Invoke-RestMethod -Method Put "$BaseUrl/characters/$CharacterId/equipment" -Headers $Headers -ContentType "application/json" -Body $WrongSlotBody
} catch {
    $_.Exception.Response.StatusCode.value__
}

# Ownership check: repeat the GET or PUT with another user's token and the same character id.
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

### Enemy and region spawn tuning

The prototype enemy and `starter_field` spawn tuning migration is:

```powershell
cd backend
alembic upgrade head
alembic current
```

Smoke check the static backend values:

```powershell
$BaseUrl = "http://127.0.0.1:8000"
Invoke-RestMethod "$BaseUrl/enemy-definitions/grunt"
Invoke-RestMethod "$BaseUrl/enemy-definitions/brute"
Invoke-RestMethod "$BaseUrl/enemy-definitions/caster"
Invoke-RestMethod "$BaseUrl/regions/starter_field/enemy-spawns"
```

Expected shape: enemy movement, aggro, leash, and attack ranges are already in
Godot world units, and `starter_field` spawn positions are near the origin.

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


# Backend Testing Notes

Enemy definitions are database-backed static content only. They should not create or update live enemy HP, position, aggro, cooldown, or other runtime state.

Region definitions and region enemy spawn definitions are also database-backed static content only. They describe where enemies may spawn, but they should not store live enemy HP, position, target, cooldown, aggro, or respawn runtime state.

Migration steps:

- From `backend/`, run `alembic upgrade head`.
- In Swagger, open `/docs` and inspect `GET /enemy-definitions`, `GET /enemy-definitions/{enemy_key}`, `GET /regions`, `GET /regions/{region_key}`, `GET /regions/{region_key}/enemy-spawns`, and `GET /characters/{character_id}/abilities`.
- For ability runtime fields, create or use a character, authorize Swagger with a bearer token, and call `GET /characters/{character_id}/abilities`.

PowerShell smoke checks:

```powershell
$baseUrl = "http://127.0.0.1:8000"
Invoke-RestMethod "$baseUrl/enemy-definitions"
Invoke-RestMethod "$baseUrl/enemy-definitions/grunt"
Invoke-RestMethod "$baseUrl/enemy-definitions/caster"
Invoke-RestMethod "$baseUrl/regions"
Invoke-RestMethod "$baseUrl/regions/starter_field"
Invoke-RestMethod "$baseUrl/regions/starter_field/enemy-spawns"

$token = "<access token>"
$characterId = 1
$headers = @{ Authorization = "Bearer $token" }
Invoke-RestMethod "$baseUrl/characters/$characterId/abilities" -Headers $headers
```

Expected static-review shape:

- `GET /enemy-definitions` should return active prototype enemies with nested `attacks` and `loot_entries`.
- `GET /enemy-definitions/grunt` should include melee attack data and gold/currency plus item loot entries.
- Currency loot entries should have `payload_type` set to `currency` and `item_key` set to `null`.
- Item loot entries should reference already seeded item definitions such as `slime_gel`, `training_sword`, or `padded_chest`.
- `GET /regions/starter_field` should return `Starter Field` with active static enemy spawn definitions.
- `GET /regions/starter_field/enemy-spawns` should include `grunt`, `brute`, and `caster` spawn definitions with referenced enemy display names when those enemy definitions are active.
- Region enemy spawn definitions should include only static spawn config such as spawn position, radius, max alive count, respawn seconds, behavior profile, patrol path key, and optional leash/aggro overrides.
- `GET /characters/{character_id}/abilities` should keep unlock/loadout behavior unchanged while each nested ability `definition` includes runtime fields: `behavior_key`, `visual_key`, `damage`, `healing`, `range`, `radius`, `arc_angle_degrees`, `tick_seconds`, and `cooldown_seconds`.
- Current prototype ability definitions should be keyed by `slash`, `hp_regen`, `damage_aura`, and `firebolt`; display names remain UI labels, while `ability_key` remains the stable identifier.
- `slash` should include `behavior_key` `melee_arc_damage`, `visual_key` `slash_arc`, `damage` `10.0`, `range` `3.5`, `arc_angle_degrees` `90.0`, and `cooldown_seconds` `1.25`.
- `hp_regen` should include `behavior_key` `periodic_heal`, `visual_key` `hp_regen`, `healing` `8.0`, `tick_seconds` `2.0`, and `cooldown_seconds` `2.0`.
- `damage_aura` should include `behavior_key` `point_blank_aoe_damage`, `visual_key` `damage_aura`, `damage` `5.0`, `radius` `4.0`, `tick_seconds` `1.0`, and `cooldown_seconds` `1.0`.
- `firebolt` should include `behavior_key` `line_projectile_damage`, `visual_key` `firebolt`, `damage` `12.0`, `range` `8.0`, and `cooldown_seconds` `1.3`.

Static-review scenarios for inventory instances:

- Add `slime_gel` twice through `POST /characters/{character_id}/inventory/items`; the existing `slime_gel` inventory entry should remain one row and its `quantity` should increase up to `max_stack`.
- Add `training_sword` twice through `POST /characters/{character_id}/inventory/items`; the response should include two separate inventory entries with different `inventory_entry_id` values and `quantity` set to `1`.
- Equip one `training_sword` through `PUT /characters/{character_id}/equipment` using its `inventory_entry_id`; the other `training_sword` entry should remain in inventory and should not be marked equipped.
- Add another `training_sword` while one is equipped; the new sword should create another separate inventory entry and the equipped sword should remain equipped.
