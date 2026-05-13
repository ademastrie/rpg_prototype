# Backend Content

Prototype backend content lives in source-controlled JSON files under `backend/content/`.
Alembic still owns database schema creation and migrations. These scripts only move content between PostgreSQL and JSON files.

The content workflows do not export or sync user accounts, characters, character inventory, character equipment, character abilities, character loadouts, gold, XP, or progression data.

Combat stat modifiers should use the Godot-derived stat keys: `max_hp`, `move_speed`, `physical_power`, `spell_power`, `armor`, and `avoidance`.

When content JSON uses newly added columns, apply migrations before syncing:

```powershell
alembic upgrade head
python .\scripts\sync_content.py
python .\scripts\export_content.py
```

## Content workflow

You can tune durable game content in either pgAdmin/PostgreSQL or the JSON files:

1. Edit or tune content in pgAdmin or JSON.
2. To capture database tuning into JSON, run:

```powershell
python .\scripts\export_content.py
```

3. To apply JSON content into the database, run:

```powershell
python .\scripts\sync_content.py
```

If JSON has new content that is not in the database yet, run `sync_content.py` before `export_content.py`. Export reflects the database as the source of truth and overwrites the JSON files, so exporting first will remove JSON-only content.

## Export DB content to JSON

Run from `backend/` after tuning durable game-content rows directly in PostgreSQL or pgAdmin:

```powershell
python .\scripts\export_content.py
```

The export script reads the current database content and overwrites the matching source-controlled JSON files under `backend/content/`. Use this to capture pgAdmin tuning for enemies, abilities, attacks, spawns, patrols, loot, regions, and items into git. It writes deterministic, pretty-formatted JSON, sorts rows by stable keys so diffs stay readable, and does not modify the database.

## Sync JSON content into DB

Run from `backend/` to apply the source-controlled JSON content back into the database:

```powershell
python .\scripts\sync_content.py
```

The sync script inserts or updates content rows in existing tables from `backend/content/*.json`. It is safe to run repeatedly; it does not drop tables, truncate tables, or delete player-owned data. For renamed prototype stat keys, it may update or remove obsolete content-only modifier/effect rows so old keys do not remain alongside official stat keys.

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
