"""initial empty migration

Revision ID: ff7aa4ae1042
Revises: 
Create Date: 2026-05-03 08:20:51.186330

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'ff7aa4ae1042'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
