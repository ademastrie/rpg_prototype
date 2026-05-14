"""add item ability grants

Revision ID: 20260514_000016
Revises: 20260513_000015
Create Date: 2026-05-14 00:00:16.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260514_000016"
down_revision: Union[str, Sequence[str], None] = "20260513_000015"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


item_ability_grants = sa.table(
    "item_ability_grants",
    sa.column("item_key", sa.String),
    sa.column("ability_key", sa.String),
    sa.column("grant_type", sa.String),
    sa.column("is_active", sa.Boolean),
)


def upgrade() -> None:
    op.create_table(
        "item_ability_grants",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_key", sa.String(length=64), nullable=False),
        sa.Column("ability_key", sa.String(length=64), nullable=False),
        sa.Column("grant_type", sa.String(length=32), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.CheckConstraint(
            "grant_type IN ('weapon_primary', 'granted_active')",
            name="ck_item_ability_grants_grant_type",
        ),
        sa.ForeignKeyConstraint(["ability_key"], ["ability_definitions.ability_key"]),
        sa.ForeignKeyConstraint(["item_key"], ["item_definitions.item_key"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "item_key",
            "ability_key",
            "grant_type",
            name="uq_item_ability_grants_item_ability_type",
        ),
    )

    op.bulk_insert(
        item_ability_grants,
        [
            {
                "item_key": "training_sword",
                "ability_key": "slash",
                "grant_type": "weapon_primary",
                "is_active": True,
            },
            {
                "item_key": "training_bow",
                "ability_key": "shoot",
                "grant_type": "weapon_primary",
                "is_active": True,
            },
            {
                "item_key": "training_staff",
                "ability_key": "firebolt",
                "grant_type": "weapon_primary",
                "is_active": True,
            },
        ],
    )


def downgrade() -> None:
    op.drop_table("item_ability_grants")
