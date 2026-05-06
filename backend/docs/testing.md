# Backend Testing Notes

Enemy definitions are database-backed static content only. They should not create or update live enemy HP, position, aggro, cooldown, or other runtime state.

Migration steps:

- From `backend/`, run `alembic upgrade head`.
- In Swagger, open `/docs` and inspect `GET /enemy-definitions` and `GET /enemy-definitions/{enemy_key}`.

PowerShell smoke checks:

```powershell
$baseUrl = "http://127.0.0.1:8000"
Invoke-RestMethod "$baseUrl/enemy-definitions"
Invoke-RestMethod "$baseUrl/enemy-definitions/grunt"
Invoke-RestMethod "$baseUrl/enemy-definitions/caster"
```

Expected static-review shape:

- `GET /enemy-definitions` should return active prototype enemies with nested `attacks` and `loot_entries`.
- `GET /enemy-definitions/grunt` should include melee attack data and gold/currency plus item loot entries.
- Currency loot entries should have `payload_type` set to `currency` and `item_key` set to `null`.
- Item loot entries should reference already seeded item definitions such as `slime_gel`, `training_sword`, or `padded_chest`.

Static-review scenarios for inventory instances:

- Add `slime_gel` twice through `POST /characters/{character_id}/inventory/items`; the existing `slime_gel` inventory entry should remain one row and its `quantity` should increase up to `max_stack`.
- Add `training_sword` twice through `POST /characters/{character_id}/inventory/items`; the response should include two separate inventory entries with different `inventory_entry_id` values and `quantity` set to `1`.
- Equip one `training_sword` through `PUT /characters/{character_id}/equipment` using its `inventory_entry_id`; the other `training_sword` entry should remain in inventory and should not be marked equipped.
- Add another `training_sword` while one is equipped; the new sword should create another separate inventory entry and the equipped sword should remain equipped.
