# Backend Content

Prototype backend content lives in source-controlled JSON files under `backend/content/`.
Alembic still owns database schema creation and migrations. These scripts only move content between PostgreSQL and JSON files.

The content workflows do not export or sync user accounts, characters, character inventory, character equipment, character abilities, character loadouts, gold, XP, or progression data.

## Export DB content to JSON

Use this after tuning durable game-content rows directly in PostgreSQL:

```powershell
python .\scripts\export_content.py
```

The export script reads current content rows and writes deterministic, pretty-formatted JSON under `backend/content/`. It sorts rows by stable keys so git diffs stay readable. It does not modify the database.

## Sync JSON content into DB

Run from `backend/` after applying migrations:

```powershell
alembic upgrade head
python .\scripts\sync_content.py
```

The sync is safe to run repeatedly. It inserts or updates content rows in existing tables; it does not drop tables, truncate tables, or delete player-owned data.

The script upserts rows by stable keys:

- `ability_definitions`: `ability_key`
- `ability_effects`: `ability_key`, `effect_type`, `target_team`, `stat_key`
- `item_definitions`: `item_key`
- `item_stat_modifiers`: `item_key`, `stat_key`, `modifier_type`
- `enemy_definitions`: `enemy_key`
- `enemy_attacks`: `enemy_key`, `attack_key`
- `enemy_loot_entries`: `enemy_key`, `payload_type`, `item_key`
- `region_definitions`: `region_key`
- `region_patrol_paths`: `patrol_path_key`
- `region_patrol_points`: `patrol_path_key`, `point_order`
- `region_enemy_spawns`: `spawn_key`

To change prototype content, edit the matching JSON file and rerun:

```powershell
python .\scripts\sync_content.py
```
