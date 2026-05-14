# Backend Content

Prototype backend content lives in source-controlled JSON files under `backend/content/`.
Alembic still owns database schema creation and migrations. These scripts only move content between PostgreSQL and JSON files.

The content workflows do not export or sync user accounts, characters, character inventory, character equipment, character abilities, character loadouts, gold, XP, or progression data.

Equipment definitions currently support the slots `weapon`, `head`, `chest`, `arms`, `hands`, `legs`, and `feet`.

Equipment stat modifiers should use only the official derived combat stat keys: `max_hp`, `move_speed`, `physical_power`, `spell_power`, `armor`, and `avoidance`.

Future equipment stats may include `ability_haste` or `healing_power`; they are not implemented yet. Hands/gloves are a natural future source for ability haste or cooldown reduction when that system exists.

Ability availability is split between permanent character unlocks and temporary item grants:

- Permanent character abilities live in `character_abilities`. These are known by the character independent of gear and must not be removed when content sync runs.
- Item-granted abilities live in `item_ability_grants`. These are content rows keyed by `item_key`, `ability_key`, and `grant_type`, and are available only while the granting item is equipped.
- Starter weapons grant the first weapon-primary ability: `training_sword` grants `slash`, `training_bow` grants `shoot`, and `training_staff` grants `firebolt`.

Current grant types are `weapon_primary` and `granted_active`. Stable keys are the runtime identity; display names are presentation only.

Future permanent unlock sources can include level reward, quest reward, achievement, ability mastery, and item grant promotion rules. Those systems are not implemented yet.

Enemy content is split into archetypes, definitions, and spawns:

- Enemy archetypes describe shared creature identity and future behavior/visual defaults. They are where content teaches what kind of enemy something is.
- Enemy definitions are tuned variants. They keep the Godot-facing `enemy_key` and own concrete level, stats, XP rewards, combat tuning, visual keys, and variant loot hooks.
- Region enemy spawns place a specific variant in the world. Spawns still reference `region_enemy_spawns.enemy_key`, which points to an `enemy_definitions.enemy_key` variant.

Enemy definitions support `level` and `base_xp` for backend XP awards. `base_xp` is the canonical enemy XP field; archetypes do not own XP rewards. Final kill XP is calculated from enemy variant `base_xp`, the enemy/player level delta multiplier, and the region `xp_multiplier`.

Region definitions support `recommended_level_min`, `recommended_level_max`, `xp_multiplier`, and optional `loot_table_key`. Keep normal zone pacing in enemy levels and base XP; region XP multipliers are for explicit special cases such as events, dungeons, or other clearly surfaced reward rules, not hidden zone balancing. Current regions use `xp_multiplier = 1.0`.

Loot is still resolved through the existing enemy-key-specific `enemy_loot_entries` content. The optional `loot_table_key` fields are structure hooks for a later layered resolver and may be null:

- Global loot tables will cover broad world, event, or account-wide drop rules.
- Region loot tables will cover zone-themed drops.
- Archetype loot tables will cover creature-family drops.
- Variant loot tables will cover drops specific to one enemy definition.
- Enemy definition `tier` defaults to `normal` and is reserved for future normal, elite, rare, or boss modifiers.

Future loot can come from multiple layers, but this content pass only adds hooks and preserves current enemy-specific loot behavior.

Character XP has no level cap yet. Level-up ability unlocks, party XP, and global event multipliers are not implemented yet.

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
- `item_ability_grants`: `item_key`, `ability_key`, `grant_type`
- `enemy_archetypes`: `archetype_key`
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
