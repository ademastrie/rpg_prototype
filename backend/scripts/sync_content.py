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


def set_values(instance: object, row: JsonRow) -> None:
    for key, value in row.items():
        setattr(instance, key, value)


def find_one(session: Session, model: type, keys: JsonRow) -> object | None:
    statement = select(model)
    for column_name, value in keys.items():
        statement = statement.where(getattr(model, column_name) == value)

    return session.scalars(statement).one_or_none()


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
        existing = find_one(session, model, keys)

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
        results[table_name] = upsert_rows(
            session,
            model,
            load_rows(f"{table_name}.json"),
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
