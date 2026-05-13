"""add enemy and region XP fields

Revision ID: 20260513_000013
Revises: 20260508_000012
Create Date: 2026-05-13 00:00:13.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260513_000013"
down_revision: Union[str, Sequence[str], None] = "20260508_000012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


enemy_definitions = sa.table(
    "enemy_definitions",
    sa.column("base_xp", sa.Integer),
    sa.column("xp_reward", sa.Integer),
)


def upgrade() -> None:
    op.add_column(
        "enemy_definitions",
        sa.Column("base_xp", sa.Integer(), server_default="0", nullable=False),
    )
    op.execute(
        enemy_definitions.update().values(
            base_xp=enemy_definitions.c.xp_reward,
        )
    )

    op.add_column(
        "region_definitions",
        sa.Column(
            "recommended_level_min",
            sa.Integer(),
            server_default="1",
            nullable=False,
        ),
    )
    op.add_column(
        "region_definitions",
        sa.Column(
            "recommended_level_max",
            sa.Integer(),
            server_default="1",
            nullable=False,
        ),
    )
    op.add_column(
        "region_definitions",
        sa.Column("xp_multiplier", sa.Float(), server_default="1", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("region_definitions", "xp_multiplier")
    op.drop_column("region_definitions", "recommended_level_max")
    op.drop_column("region_definitions", "recommended_level_min")
    op.drop_column("enemy_definitions", "base_xp")
