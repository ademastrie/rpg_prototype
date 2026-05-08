"""add ability effect scaling fields

Revision ID: 20260508_000012
Revises: 20260506_000011
Create Date: 2026-05-08 00:00:12.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260508_000012"
down_revision: Union[str, Sequence[str], None] = "20260506_000011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


ability_effects = sa.table(
    "ability_effects",
    sa.column("ability_key", sa.String),
    sa.column("effect_type", sa.String),
    sa.column("target_team", sa.String),
    sa.column("stat_key", sa.String),
    sa.column("damage_school", sa.String),
    sa.column("scaling_stat_key", sa.String),
    sa.column("scaling_ratio", sa.Float),
)


def upgrade() -> None:
    op.add_column(
        "ability_effects",
        sa.Column("damage_school", sa.String(length=50), nullable=True),
    )
    op.add_column(
        "ability_effects",
        sa.Column("scaling_stat_key", sa.String(length=50), nullable=True),
    )
    op.add_column(
        "ability_effects",
        sa.Column("scaling_ratio", sa.Float(), server_default="0", nullable=True),
    )

    _update_ability_effect_scaling(
        "slash",
        "damage",
        "enemy",
        "hp",
        damage_school="physical",
        scaling_stat_key=None,
        scaling_ratio=0.0,
    )
    _update_ability_effect_scaling(
        "shoot",
        "damage",
        "enemy",
        "hp",
        damage_school="physical",
        scaling_stat_key=None,
        scaling_ratio=0.0,
    )
    _update_ability_effect_scaling(
        "firebolt",
        "damage",
        "enemy",
        "hp",
        damage_school="magic",
        scaling_stat_key="spell_power",
        scaling_ratio=0.5,
    )
    _update_ability_effect_scaling(
        "damage_aura",
        "damage",
        "enemy",
        "hp",
        damage_school="magic",
        scaling_stat_key="spell_power",
        scaling_ratio=0.25,
    )


def downgrade() -> None:
    op.drop_column("ability_effects", "scaling_ratio")
    op.drop_column("ability_effects", "scaling_stat_key")
    op.drop_column("ability_effects", "damage_school")


def _update_ability_effect_scaling(
    ability_key: str,
    effect_type: str,
    target_team: str,
    stat_key: str | None,
    *,
    damage_school: str,
    scaling_stat_key: str | None,
    scaling_ratio: float,
) -> None:
    op.execute(
        ability_effects.update()
        .where(
            ability_effects.c.ability_key == ability_key,
            ability_effects.c.effect_type == effect_type,
            ability_effects.c.target_team == target_team,
            ability_effects.c.stat_key == stat_key,
        )
        .values(
            damage_school=damage_school,
            scaling_stat_key=scaling_stat_key,
            scaling_ratio=scaling_ratio,
        )
    )
