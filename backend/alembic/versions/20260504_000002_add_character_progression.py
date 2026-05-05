"""add character progression

Revision ID: 20260504_000002
Revises: 20260504_000001
Create Date: 2026-05-04 00:00:02.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260504_000002"
down_revision: Union[str, Sequence[str], None] = "20260504_000001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_columns = {column["name"] for column in inspector.get_columns("characters")}

    if "level" not in existing_columns:
        op.add_column(
            "characters",
            sa.Column("level", sa.Integer(), server_default="1", nullable=False),
        )
    if "xp" not in existing_columns:
        op.add_column(
            "characters",
            sa.Column("xp", sa.Integer(), server_default="0", nullable=False),
        )


def downgrade() -> None:
    # Existing prototype databases may already have these columns from the original
    # create-table migration, so do not drop potentially pre-existing character data.
    pass
