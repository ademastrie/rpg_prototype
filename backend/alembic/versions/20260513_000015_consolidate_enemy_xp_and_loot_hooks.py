"""consolidate enemy XP and add loot table hooks

Revision ID: 20260513_000015
Revises: 20260513_000014
Create Date: 2026-05-13 00:00:15.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260513_000015"
down_revision: Union[str, Sequence[str], None] = "20260513_000014"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


enemy_definitions = sa.table(
    "enemy_definitions",
    sa.column("base_xp", sa.Integer),
    sa.column("xp_reward", sa.Integer),
)


def upgrade() -> None:
    op.execute(
        enemy_definitions.update()
        .where(enemy_definitions.c.base_xp.is_(None))
        .values(base_xp=enemy_definitions.c.xp_reward)
    )
    op.drop_column("enemy_definitions", "xp_reward")

    op.add_column(
        "region_definitions",
        sa.Column("loot_table_key", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "enemy_archetypes",
        sa.Column("loot_table_key", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "enemy_definitions",
        sa.Column("loot_table_key", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "enemy_definitions",
        sa.Column("tier", sa.String(length=32), server_default="normal", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("enemy_definitions", "tier")
    op.drop_column("enemy_definitions", "loot_table_key")
    op.drop_column("enemy_archetypes", "loot_table_key")
    op.drop_column("region_definitions", "loot_table_key")

    op.add_column(
        "enemy_definitions",
        sa.Column("xp_reward", sa.Integer(), server_default="0", nullable=False),
    )
    op.execute(
        enemy_definitions.update().values(
            xp_reward=enemy_definitions.c.base_xp,
        )
    )
