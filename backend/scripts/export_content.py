import json
import sys
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
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
    ItemAbilityGrant,
    ItemDefinition,
    ItemStatModifier,
    RegionDefinition,
    RegionEnemySpawn,
    RegionPatrolPath,
    RegionPatrolPoint,
)


JsonRow = dict[str, Any]
ContentTable = tuple[str, type, tuple[str, ...], tuple[str, ...]]


@dataclass(frozen=True)
class ExportResult:
    path: Path
    row_count: int


CONTENT_TABLES: tuple[ContentTable, ...] = (
    (
        "ability_definitions",
        AbilityDefinition,
        ("ability_key",),
        (
            "ability_key",
            "display_name",
            "description",
            "behavior_key",
            "trigger_type",
            "targeting_type",
            "cooldown_seconds",
            "range",
            "radius",
            "arc_angle_degrees",
            "visual_key",
            "is_active",
        ),
    ),
    (
        "ability_effects",
        AbilityEffect,
        ("ability_key", "effect_type", "target_team", "stat_key"),
        (
            "ability_key",
            "effect_type",
            "target_team",
            "stat_key",
            "damage_school",
            "scaling_stat_key",
            "scaling_ratio",
            "value",
            "tick_interval_seconds",
            "duration_seconds",
        ),
    ),
    (
        "item_definitions",
        ItemDefinition,
        ("item_key",),
        (
            "item_key",
            "display_name",
            "description",
            "item_type",
            "equip_slot",
            "stackable",
            "max_stack",
            "icon_key",
            "is_active",
        ),
    ),
    (
        "item_stat_modifiers",
        ItemStatModifier,
        ("item_key", "stat_key", "modifier_type"),
        ("item_key", "stat_key", "value", "modifier_type"),
    ),
    (
        "item_ability_grants",
        ItemAbilityGrant,
        ("item_key", "ability_key", "grant_type"),
        ("item_key", "ability_key", "grant_type", "is_active"),
    ),
    (
        "enemy_archetypes",
        EnemyArchetype,
        ("archetype_key",),
        (
            "archetype_key",
            "display_name",
            "description",
            "default_behavior_profile_key",
            "default_visual_key",
            "loot_table_key",
            "notes",
        ),
    ),
    (
        "enemy_definitions",
        EnemyDefinition,
        ("enemy_key",),
        (
            "enemy_key",
            "archetype_key",
            "display_name",
            "description",
            "level",
            "max_hp",
            "move_speed",
            "base_xp",
            "loot_table_key",
            "tier",
            "aggro_radius",
            "leash_radius",
            "visual_key",
            "is_active",
        ),
    ),
    (
        "enemy_attacks",
        EnemyAttack,
        ("enemy_key", "attack_key"),
        (
            "enemy_key",
            "attack_key",
            "attack_type",
            "damage",
            "range",
            "radius",
            "windup_seconds",
            "recovery_seconds",
            "cooldown_seconds",
            "visual_key",
        ),
    ),
    (
        "enemy_loot_entries",
        EnemyLootEntry,
        ("enemy_key", "payload_type", "item_key"),
        (
            "enemy_key",
            "payload_type",
            "item_key",
            "min_quantity",
            "max_quantity",
            "drop_chance",
            "is_active",
        ),
    ),
    (
        "region_definitions",
        RegionDefinition,
        ("region_key",),
        (
            "region_key",
            "display_name",
            "description",
            "recommended_level_min",
            "recommended_level_max",
            "xp_multiplier",
            "loot_table_key",
            "is_active",
        ),
    ),
    (
        "region_patrol_paths",
        RegionPatrolPath,
        ("patrol_path_key",),
        ("patrol_path_key", "region_key", "display_name", "is_active"),
    ),
    (
        "region_patrol_points",
        RegionPatrolPoint,
        ("patrol_path_key", "point_order"),
        (
            "patrol_path_key",
            "point_order",
            "position_x",
            "position_y",
            "position_z",
            "wait_seconds",
        ),
    ),
    (
        "region_enemy_spawns",
        RegionEnemySpawn,
        ("spawn_key",),
        (
            "spawn_key",
            "region_key",
            "enemy_key",
            "display_name",
            "spawn_type",
            "position_x",
            "position_y",
            "position_z",
            "spawn_radius",
            "max_alive",
            "respawn_seconds",
            "behavior_profile_key",
            "patrol_path_key",
            "leash_radius_override",
            "aggro_radius_override",
            "is_active",
        ),
    ),
)


def sort_value(value: Any) -> tuple[int, Any]:
    if value is None:
        return (0, "")

    return (1, value)


def row_to_json(instance: object, fields: tuple[str, ...]) -> JsonRow:
    return {field: to_json_value(getattr(instance, field)) for field in fields}


def to_json_value(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)

    if isinstance(value, (date, datetime)):
        return value.isoformat()

    return value


def export_table(
    session: Session,
    table_name: str,
    model: type,
    key_fields: tuple[str, ...],
    fields: tuple[str, ...],
) -> ExportResult:
    rows = session.scalars(select(model)).all()
    rows = sorted(
        rows,
        key=lambda row: tuple(sort_value(getattr(row, field)) for field in key_fields),
    )
    data = [row_to_json(row, fields) for row in rows]

    CONTENT_DIR.mkdir(parents=True, exist_ok=True)
    path = CONTENT_DIR / f"{table_name}.json"
    with path.open("w", encoding="utf-8", newline="\n") as file:
        json.dump(data, file, indent=2, sort_keys=False)
        file.write("\n")

    return ExportResult(path=path, row_count=len(data))


def export_content(session: Session) -> dict[str, ExportResult]:
    results: dict[str, ExportResult] = {}

    for table_name, model, key_fields, fields in CONTENT_TABLES:
        results[table_name] = export_table(
            session,
            table_name,
            model,
            key_fields,
            fields,
        )

    return results


def print_results(results: dict[str, ExportResult]) -> None:
    for table_name, result in results.items():
        path = result.path.relative_to(BACKEND_DIR)
        print(f"{path}: exported {result.row_count} rows from {table_name}")


def main() -> int:
    try:
        with SessionLocal() as session:
            results = export_content(session)
    except SQLAlchemyError as exc:
        print(f"Content export failed: {exc}")
        return 1
    except Exception as exc:
        print(f"Content export failed: {exc}")
        return 1

    print_results(results)
    return 0


if __name__ == "__main__":
    sys.exit(main())
