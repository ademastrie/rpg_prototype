import json
import sys
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session


BACKEND_DIR = Path(__file__).resolve().parents[1]
CONTENT_DIR = BACKEND_DIR / "content"
sys.path.insert(0, str(BACKEND_DIR))

from app.db import SessionLocal  # noqa: E402
from app.models import (  # noqa: E402
    AbilityDefinition,
    AbilityEffect,
    EnemyArchetype,
    EnemyAttack,
    EnemyDefinition,
    EnemyLootEntry,
    ItemDefinition,
    ItemStatModifier,
    RegionDefinition,
    RegionEnemySpawn,
    RegionPatrolPath,
    RegionPatrolPoint,
)


JsonRow = dict[str, Any]
ContentTable = tuple[str, type, tuple[str, ...]]
LegacyStatKeyRename = tuple[JsonRow, str, str]


CONTENT_ROW_DEFAULTS: dict[str, JsonRow] = {
    "ability_effects": {
        "damage_school": None,
        "scaling_stat_key": None,
        "scaling_ratio": 0.0,
    },
    "region_definitions": {
        "recommended_level_min": 1,
        "recommended_level_max": 1,
        "xp_multiplier": 1.0,
    },
}


OFFICIAL_EQUIPMENT_STAT_KEYS = {
    "max_hp",
    "move_speed",
    "physical_power",
    "spell_power",
    "armor",
    "avoidance",
}


CONTENT_LEGACY_STAT_KEY_RENAMES: dict[str, tuple[LegacyStatKeyRename, ...]] = {
    "ability_effects": (
        (
            {
                "ability_key": "slash",
                "effect_type": "stat_modifier",
                "target_team": "self",
            },
            "damage_reduction",
            "armor",
        ),
    ),
    "item_stat_modifiers": (
        (
            {"item_key": "training_sword", "modifier_type": "flat"},
            "attack_power",
            "physical_power",
        ),
        (
            {"item_key": "simple_bow", "modifier_type": "flat"},
            "attack_power",
            "physical_power",
        ),
        (
            {"item_key": "padded_chest", "modifier_type": "flat"},
            "damage_reduction",
            "armor",
        ),
        (
            {"item_key": "training_gloves", "modifier_type": "flat"},
            "damage_reduction",
            "armor",
        ),
    ),
}


CONTENT_TABLES: tuple[ContentTable, ...] = (
    ("ability_definitions", AbilityDefinition, ("ability_key",)),
    (
        "ability_effects",
        AbilityEffect,
        ("ability_key", "effect_type", "target_team", "stat_key"),
    ),
    ("item_definitions", ItemDefinition, ("item_key",)),
    (
        "item_stat_modifiers",
        ItemStatModifier,
        ("item_key", "stat_key", "modifier_type"),
    ),
    ("enemy_archetypes", EnemyArchetype, ("archetype_key",)),
    ("enemy_definitions", EnemyDefinition, ("enemy_key",)),
    ("enemy_attacks", EnemyAttack, ("enemy_key", "attack_key")),
    ("enemy_loot_entries", EnemyLootEntry, ("enemy_key", "payload_type", "item_key")),
    ("region_definitions", RegionDefinition, ("region_key",)),
    ("region_patrol_paths", RegionPatrolPath, ("patrol_path_key",)),
    (
        "region_patrol_points",
        RegionPatrolPoint,
        ("patrol_path_key", "point_order"),
    ),
    ("region_enemy_spawns", RegionEnemySpawn, ("spawn_key",)),
)


def load_rows(filename: str) -> list[JsonRow]:
    path = CONTENT_DIR / filename
    with path.open(encoding="utf-8") as file:
        rows = json.load(file)

    if not isinstance(rows, list):
        raise ValueError(f"{path} must contain a JSON array.")

    return rows


def apply_row_defaults(table_name: str, rows: Iterable[JsonRow]) -> list[JsonRow]:
    defaults = CONTENT_ROW_DEFAULTS.get(table_name)
    prepared_rows = list(rows)
    if table_name == "enemy_definitions":
        return [apply_enemy_definition_defaults(row) for row in prepared_rows]

    if defaults is None:
        return prepared_rows

    return [{**defaults, **row} for row in prepared_rows]


def apply_enemy_definition_defaults(row: JsonRow) -> JsonRow:
    prepared_row = dict(row)
    if "base_xp" not in prepared_row:
        prepared_row["base_xp"] = prepared_row.get("xp_reward", 0)
    if "xp_reward" not in prepared_row:
        prepared_row["xp_reward"] = prepared_row.get("base_xp", 0)

    return prepared_row


def set_values(instance: object, row: JsonRow) -> None:
    for key, value in row.items():
        setattr(instance, key, value)


def find_all(session: Session, model: type, keys: JsonRow) -> list[object]:
    statement = select(model)
    for column_name, value in keys.items():
        statement = statement.where(getattr(model, column_name) == value)

    return list(session.scalars(statement).all())


def find_primary_for_upsert(
    session: Session,
    model: type,
    keys: JsonRow,
) -> object | None:
    rows = find_all(session, model, keys)
    if not rows:
        return None

    rows = sorted(rows, key=lambda row: getattr(row, "id"))
    primary_row = rows[0]
    for duplicate_row in rows[1:]:
        session.delete(duplicate_row)

    return primary_row


def row_matches(row: JsonRow, values: JsonRow) -> bool:
    return all(row.get(key) == value for key, value in values.items())


def apply_legacy_stat_key_renames(
    session: Session,
    table_name: str,
    model: type,
    rows: Iterable[JsonRow],
) -> list[JsonRow]:
    prepared_rows = list(rows)
    renames = CONTENT_LEGACY_STAT_KEY_RENAMES.get(table_name)
    if renames is None:
        return prepared_rows

    for base_keys, old_stat_key, new_stat_key in renames:
        desired_keys = {**base_keys, "stat_key": new_stat_key}
        if not any(row_matches(row, desired_keys) for row in prepared_rows):
            continue

        legacy_rows = find_all(
            session,
            model,
            {**base_keys, "stat_key": old_stat_key},
        )
        if not legacy_rows:
            continue

        existing_new_rows = find_all(session, model, desired_keys)
        if existing_new_rows:
            for legacy_row in legacy_rows:
                session.delete(legacy_row)
            continue

        setattr(legacy_rows[0], "stat_key", new_stat_key)
        for duplicate_legacy_row in legacy_rows[1:]:
            session.delete(duplicate_legacy_row)

    return prepared_rows


def validate_content_rows(table_name: str, rows: Iterable[JsonRow]) -> list[JsonRow]:
    prepared_rows = list(rows)
    if table_name != "item_stat_modifiers":
        return prepared_rows

    for row in prepared_rows:
        stat_key = row.get("stat_key")
        if stat_key not in OFFICIAL_EQUIPMENT_STAT_KEYS:
            raise ValueError(
                "item_stat_modifiers contains unsupported stat_key "
                f"{stat_key!r} for item_key {row.get('item_key')!r}."
            )

    return prepared_rows


def prune_missing_item_stat_modifiers(
    session: Session,
    model: type,
    rows: Iterable[JsonRow],
    key_fields: tuple[str, ...],
) -> None:
    prepared_rows = list(rows)
    managed_item_keys = {row["item_key"] for row in prepared_rows}
    desired_keys = {
        tuple(row[field] for field in key_fields)
        for row in prepared_rows
    }

    if not managed_item_keys:
        return

    existing_rows = session.scalars(
        select(model).where(model.item_key.in_(managed_item_keys))
    ).all()
    for existing_row in existing_rows:
        existing_key = tuple(getattr(existing_row, field) for field in key_fields)
        if existing_key not in desired_keys:
            session.delete(existing_row)


def upsert_rows(
    session: Session,
    model: type,
    rows: Iterable[JsonRow],
    key_fields: tuple[str, ...],
) -> tuple[int, int]:
    inserted = 0
    updated = 0

    for row in rows:
        keys = {field: row[field] for field in key_fields}
        existing = find_primary_for_upsert(session, model, keys)

        if existing is None:
            session.add(model(**row))
            inserted += 1
        else:
            set_values(existing, row)
            updated += 1

    return inserted, updated


def sync_content(session: Session) -> dict[str, tuple[int, int]]:
    results: dict[str, tuple[int, int]] = {}

    for table_name, model, key_fields in CONTENT_TABLES:
        rows = validate_content_rows(
            table_name,
            apply_legacy_stat_key_renames(
                session,
                table_name,
                model,
                apply_row_defaults(table_name, load_rows(f"{table_name}.json")),
            ),
        )
        if table_name == "item_stat_modifiers":
            prune_missing_item_stat_modifiers(
                session,
                model,
                rows,
                key_fields,
            )

        results[table_name] = upsert_rows(
            session,
            model,
            rows,
            key_fields,
        )

    return results


def print_results(results: dict[str, tuple[int, int]]) -> None:
    for table_name, (inserted, updated) in results.items():
        print(f"{table_name}: inserted {inserted}, updated {updated}")


def main() -> int:
    try:
        with SessionLocal() as session:
            with session.begin():
                results = sync_content(session)
    except SQLAlchemyError as exc:
        print(f"Content sync failed: {exc}")
        return 1
    except Exception as exc:
        print(f"Content sync failed: {exc}")
        return 1

    print_results(results)
    return 0


if __name__ == "__main__":
    sys.exit(main())
