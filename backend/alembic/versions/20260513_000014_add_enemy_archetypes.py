"""add enemy archetypes

Revision ID: 20260513_000014
Revises: 20260513_000013
Create Date: 2026-05-13 00:00:14.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260513_000014"
down_revision: Union[str, Sequence[str], None] = "20260513_000013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


enemy_archetypes = sa.table(
    "enemy_archetypes",
    sa.column("archetype_key", sa.String),
    sa.column("display_name", sa.String),
    sa.column("description", sa.String),
    sa.column("default_behavior_profile_key", sa.String),
    sa.column("default_visual_key", sa.String),
    sa.column("notes", sa.String),
)

enemy_definitions = sa.table(
    "enemy_definitions",
    sa.column("enemy_key", sa.String),
    sa.column("archetype_key", sa.String),
)


def upgrade() -> None:
    op.create_table(
        "enemy_archetypes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("archetype_key", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.String(length=500), nullable=True),
        sa.Column("default_behavior_profile_key", sa.String(length=64), nullable=True),
        sa.Column("default_visual_key", sa.String(length=100), nullable=True),
        sa.Column("notes", sa.String(length=1000), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("archetype_key", name="uq_enemy_archetypes_archetype_key"),
    )
    op.add_column(
        "enemy_definitions",
        sa.Column("archetype_key", sa.String(length=64), nullable=True),
    )
    op.create_foreign_key(
        "fk_enemy_definitions_archetype_key",
        "enemy_definitions",
        "enemy_archetypes",
        ["archetype_key"],
        ["archetype_key"],
    )

    op.bulk_insert(
        enemy_archetypes,
        [
            {
                "archetype_key": "brute",
                "display_name": "Brute",
                "description": "Large melee creature identity for slow, heavy combatants.",
                "default_behavior_profile_key": "wander",
                "default_visual_key": "brute",
                "notes": "Initial archetype for the prototype brute variant.",
            },
            {
                "archetype_key": "caster",
                "display_name": "Caster",
                "description": "Ranged creature identity for spell or projectile attackers.",
                "default_behavior_profile_key": "wander",
                "default_visual_key": "caster",
                "notes": "Initial archetype for the prototype caster variant.",
            },
            {
                "archetype_key": "humanoid_grunt",
                "display_name": "Humanoid Grunt",
                "description": "Basic humanoid melee creature identity.",
                "default_behavior_profile_key": "wander",
                "default_visual_key": "grunt",
                "notes": "Initial archetype for the prototype grunt variant.",
            },
        ],
    )

    for enemy_key, archetype_key in (
        ("brute", "brute"),
        ("caster", "caster"),
        ("grunt", "humanoid_grunt"),
    ):
        op.execute(
            enemy_definitions.update()
            .where(enemy_definitions.c.enemy_key == enemy_key)
            .values(archetype_key=archetype_key)
        )


def downgrade() -> None:
    op.drop_constraint(
        "fk_enemy_definitions_archetype_key",
        "enemy_definitions",
        type_="foreignkey",
    )
    op.drop_column("enemy_definitions", "archetype_key")
    op.drop_table("enemy_archetypes")
