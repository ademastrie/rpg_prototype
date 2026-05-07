"""add ability runtime fields

Revision ID: 20260506_000010
Revises: 20260506_000009
Create Date: 2026-05-06 00:00:10.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_000010"
down_revision: Union[str, Sequence[str], None] = "20260506_000009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


ability_definitions = sa.table(
    "ability_definitions",
    sa.column("ability_key", sa.String),
    sa.column("behavior_key", sa.String),
    sa.column("cooldown_seconds", sa.Float),
    sa.column("range", sa.Float),
    sa.column("radius", sa.Float),
    sa.column("arc_angle_degrees", sa.Float),
    sa.column("visual_key", sa.String),
)

ability_effects = sa.table(
    "ability_effects",
    sa.column("ability_key", sa.String),
    sa.column("effect_type", sa.String),
    sa.column("value", sa.Float),
    sa.column("tick_interval_seconds", sa.Float),
)


def upgrade() -> None:
    op.add_column(
        "ability_definitions",
        sa.Column("behavior_key", sa.String(length=100), nullable=True),
    )
    op.add_column(
        "ability_definitions",
        sa.Column("arc_angle_degrees", sa.Float(), nullable=True),
    )

    _update_ability_definition(
        "slash",
        behavior_key="melee_arc_damage",
        cooldown_seconds=1.25,
        range_value=3.5,
        radius=None,
        arc_angle_degrees=90.0,
        visual_key="slash_arc",
    )
    _update_ability_definition(
        "hp_regen",
        behavior_key="periodic_heal",
        cooldown_seconds=2.0,
        range_value=None,
        radius=None,
        arc_angle_degrees=None,
        visual_key="hp_regen",
    )
    _update_ability_definition(
        "damage_aura",
        behavior_key="point_blank_aoe_damage",
        cooldown_seconds=1.0,
        range_value=None,
        radius=4.0,
        arc_angle_degrees=None,
        visual_key="damage_aura",
    )
    _update_ability_definition(
        "firebolt",
        behavior_key="line_projectile_damage",
        cooldown_seconds=1.3,
        range_value=8.0,
        radius=None,
        arc_angle_degrees=None,
        visual_key="firebolt",
    )

    _update_ability_effect("slash", "damage", value=10.0, tick_interval_seconds=None)
    _update_ability_effect("hp_regen", "healing", value=8.0, tick_interval_seconds=2.0)
    _update_ability_effect("damage_aura", "damage", value=5.0, tick_interval_seconds=1.0)
    _update_ability_effect("firebolt", "damage", value=12.0, tick_interval_seconds=None)


def downgrade() -> None:
    _update_ability_definition(
        "slash",
        behavior_key=None,
        cooldown_seconds=0.75,
        range_value=4.0,
        radius=None,
        arc_angle_degrees=None,
        visual_key="slash",
    )
    _update_ability_definition(
        "hp_regen",
        behavior_key=None,
        cooldown_seconds=2.0,
        range_value=None,
        radius=None,
        arc_angle_degrees=None,
        visual_key="hp_regen",
    )
    _update_ability_definition(
        "damage_aura",
        behavior_key=None,
        cooldown_seconds=1.0,
        range_value=None,
        radius=4.0,
        arc_angle_degrees=None,
        visual_key="damage_aura",
    )
    _update_ability_definition(
        "firebolt",
        behavior_key=None,
        cooldown_seconds=1.2,
        range_value=10.0,
        radius=None,
        arc_angle_degrees=None,
        visual_key="firebolt",
    )

    _update_ability_effect("slash", "damage", value=10.0, tick_interval_seconds=None)
    _update_ability_effect("hp_regen", "healing", value=5.0, tick_interval_seconds=2.0)
    _update_ability_effect("damage_aura", "damage", value=4.0, tick_interval_seconds=1.0)
    _update_ability_effect("firebolt", "damage", value=8.0, tick_interval_seconds=None)

    op.drop_column("ability_definitions", "arc_angle_degrees")
    op.drop_column("ability_definitions", "behavior_key")


def _update_ability_definition(
    ability_key: str,
    *,
    behavior_key: str | None,
    cooldown_seconds: float,
    range_value: float | None,
    radius: float | None,
    arc_angle_degrees: float | None,
    visual_key: str,
) -> None:
    op.execute(
        ability_definitions.update()
        .where(ability_definitions.c.ability_key == ability_key)
        .values(
            behavior_key=behavior_key,
            cooldown_seconds=cooldown_seconds,
            range=range_value,
            radius=radius,
            arc_angle_degrees=arc_angle_degrees,
            visual_key=visual_key,
        )
    )


def _update_ability_effect(
    ability_key: str,
    effect_type: str,
    *,
    value: float,
    tick_interval_seconds: float | None,
) -> None:
    op.execute(
        ability_effects.update()
        .where(
            ability_effects.c.ability_key == ability_key,
            ability_effects.c.effect_type == effect_type,
        )
        .values(value=value, tick_interval_seconds=tick_interval_seconds)
    )
