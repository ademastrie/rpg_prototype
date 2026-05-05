"""add character gold

Revision ID: 20260505_000003
Revises: 20260504_000002
Create Date: 2026-05-05 00:00:03.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260505_000003"
down_revision: Union[str, Sequence[str], None] = "20260504_000002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_columns = {column["name"] for column in inspector.get_columns("characters")}

    if "gold" not in existing_columns:
        op.add_column(
            "characters",
            sa.Column("gold", sa.Integer(), server_default="0", nullable=False),
        )


def downgrade() -> None:
    op.drop_column("characters", "gold")
