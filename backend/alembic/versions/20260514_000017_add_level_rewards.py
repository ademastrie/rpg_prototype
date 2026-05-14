"""add level rewards

Revision ID: 20260514_000017
Revises: 20260514_000016
Create Date: 2026-05-14 00:00:17.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260514_000017"
down_revision: Union[str, Sequence[str], None] = "20260514_000016"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "level_rewards",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("level_required", sa.Integer(), nullable=False),
        sa.Column("reward_type", sa.String(length=50), nullable=False),
        sa.Column("reward_key", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column("description", sa.String(length=500), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "level_required",
            "reward_type",
            "reward_key",
            name="uq_level_rewards_level_type_key",
        ),
    )


def downgrade() -> None:
    op.drop_table("level_rewards")
