"""create ability persistence tables

Revision ID: 20260504_000001
Revises: 20260503_081900
Create Date: 2026-05-04 00:00:01.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260504_000001"
down_revision: Union[str, Sequence[str], None] = "20260503_081900"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


ability_definitions = sa.table(
    "ability_definitions",
    sa.column("ability_key", sa.String),
    sa.column("display_name", sa.String),
    sa.column("description", sa.String),
    sa.column("trigger_type", sa.String),
    sa.column("targeting_type", sa.String),
    sa.column("cooldown_seconds", sa.Float),
    sa.column("range", sa.Float),
    sa.column("radius", sa.Float),
    sa.column("visual_key", sa.String),
    sa.column("is_active", sa.Boolean),
)

ability_effects = sa.table(
    "ability_effects",
    sa.column("ability_key", sa.String),
    sa.column("effect_type", sa.String),
    sa.column("target_team", sa.String),
    sa.column("stat_key", sa.String),
    sa.column("value", sa.Float),
    sa.column("tick_interval_seconds", sa.Float),
    sa.column("duration_seconds", sa.Float),
)


def upgrade() -> None:
    op.create_table(
        "ability_definitions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("ability_key", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.String(length=500), nullable=True),
        sa.Column("trigger_type", sa.String(length=50), nullable=False),
        sa.Column("targeting_type", sa.String(length=50), nullable=False),
        sa.Column("cooldown_seconds", sa.Float(), server_default="0", nullable=False),
        sa.Column("range", sa.Float(), nullable=True),
        sa.Column("radius", sa.Float(), nullable=True),
        sa.Column("visual_key", sa.String(length=100), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("ability_key", name="uq_ability_definitions_ability_key"),
    )

    op.create_table(
        "ability_effects",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("ability_key", sa.String(length=64), nullable=False),
        sa.Column("effect_type", sa.String(length=50), nullable=False),
        sa.Column("target_team", sa.String(length=50), nullable=False),
        sa.Column("stat_key", sa.String(length=50), nullable=True),
        sa.Column("value", sa.Float(), nullable=False),
        sa.Column("tick_interval_seconds", sa.Float(), nullable=True),
        sa.Column("duration_seconds", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["ability_key"], ["ability_definitions.ability_key"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "character_abilities",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("character_id", sa.Integer(), nullable=False),
        sa.Column("ability_key", sa.String(length=64), nullable=False),
        sa.Column("unlocked", sa.Boolean(), server_default="true", nullable=False),
        sa.Column("ability_level", sa.Integer(), server_default="1", nullable=False),
        sa.Column("ability_xp", sa.Integer(), server_default="0", nullable=False),
        sa.ForeignKeyConstraint(["ability_key"], ["ability_definitions.ability_key"]),
        sa.ForeignKeyConstraint(["character_id"], ["characters.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("character_id", "ability_key", name="uq_character_abilities_character_ability"),
    )

    op.create_table(
        "character_ability_loadout",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("character_id", sa.Integer(), nullable=False),
        sa.Column("slot_index", sa.Integer(), nullable=False),
        sa.Column("ability_key", sa.String(length=64), nullable=False),
        sa.Column("enabled", sa.Boolean(), server_default="true", nullable=False),
        sa.ForeignKeyConstraint(["ability_key"], ["ability_definitions.ability_key"]),
        sa.ForeignKeyConstraint(["character_id"], ["characters.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("character_id", "slot_index", name="uq_character_ability_loadout_character_slot"),
        sa.UniqueConstraint("character_id", "ability_key", name="uq_character_ability_loadout_character_ability"),
    )

    op.bulk_insert(
        ability_definitions,
        [
            {
                "ability_key": "slash",
                "display_name": "Slash",
                "description": "A short-range weapon attack in the aimed direction.",
                "trigger_type": "cooldown",
                "targeting_type": "aimed_cone",
                "cooldown_seconds": 0.75,
                "range": 4.0,
                "radius": None,
                "visual_key": "slash",
                "is_active": True,
            },
            {
                "ability_key": "hp_regen",
                "display_name": "HP Regen",
                "description": "Periodically restores health while active.",
                "trigger_type": "periodic",
                "targeting_type": "self",
                "cooldown_seconds": 2.0,
                "range": None,
                "radius": None,
                "visual_key": "hp_regen",
                "is_active": True,
            },
            {
                "ability_key": "damage_aura",
                "display_name": "Damage Aura",
                "description": "Damages nearby enemies around the character.",
                "trigger_type": "periodic",
                "targeting_type": "radius_around_self",
                "cooldown_seconds": 1.0,
                "range": None,
                "radius": 4.0,
                "visual_key": "damage_aura",
                "is_active": True,
            },
            {
                "ability_key": "firebolt",
                "display_name": "Firebolt",
                "description": "A ranged attack that hits the first enemy in an aimed line.",
                "trigger_type": "cooldown",
                "targeting_type": "aimed_line",
                "cooldown_seconds": 1.2,
                "range": 10.0,
                "radius": None,
                "visual_key": "firebolt",
                "is_active": True,
            },
        ],
    )

    op.bulk_insert(
        ability_effects,
        [
            {
                "ability_key": "slash",
                "effect_type": "damage",
                "target_team": "enemy",
                "stat_key": "hp",
                "value": 10.0,
                "tick_interval_seconds": None,
                "duration_seconds": None,
            },
            {
                "ability_key": "hp_regen",
                "effect_type": "healing",
                "target_team": "self",
                "stat_key": "hp",
                "value": 5.0,
                "tick_interval_seconds": 2.0,
                "duration_seconds": None,
            },
            {
                "ability_key": "damage_aura",
                "effect_type": "damage",
                "target_team": "enemy",
                "stat_key": "hp",
                "value": 4.0,
                "tick_interval_seconds": 1.0,
                "duration_seconds": None,
            },
            {
                "ability_key": "firebolt",
                "effect_type": "damage",
                "target_team": "enemy",
                "stat_key": "hp",
                "value": 8.0,
                "tick_interval_seconds": None,
                "duration_seconds": None,
            },
        ],
    )


def downgrade() -> None:
    op.drop_table("character_ability_loadout")
    op.drop_table("character_abilities")
    op.drop_table("ability_effects")
    op.drop_table("ability_definitions")
