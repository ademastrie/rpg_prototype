"""create items and character inventory

Revision ID: 20260506_000004
Revises: 20260505_000003
Create Date: 2026-05-06 00:00:04.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_000004"
down_revision: Union[str, Sequence[str], None] = "20260505_000003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


item_definitions = sa.table(
    "item_definitions",
    sa.column("item_key", sa.String),
    sa.column("display_name", sa.String),
    sa.column("description", sa.String),
    sa.column("item_type", sa.String),
    sa.column("stackable", sa.Boolean),
    sa.column("max_stack", sa.Integer),
    sa.column("icon_key", sa.String),
    sa.column("is_active", sa.Boolean),
)


def upgrade() -> None:
    op.create_table(
        "item_definitions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_key", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.String(length=500), nullable=True),
        sa.Column("item_type", sa.String(length=50), nullable=False),
        sa.Column("stackable", sa.Boolean(), server_default="true", nullable=False),
        sa.Column("max_stack", sa.Integer(), server_default="99", nullable=False),
        sa.Column("icon_key", sa.String(length=100), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("item_key", name="uq_item_definitions_item_key"),
    )

    op.create_table(
        "character_inventory",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("character_id", sa.Integer(), nullable=False),
        sa.Column("item_key", sa.String(length=64), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["character_id"], ["characters.id"]),
        sa.ForeignKeyConstraint(["item_key"], ["item_definitions.item_key"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("character_id", "item_key", name="uq_character_inventory_character_item"),
    )

    op.bulk_insert(
        item_definitions,
        [
            {
                "item_key": "slime_gel",
                "display_name": "Slime Gel",
                "description": "A sticky glob from a defeated slime.",
                "item_type": "material",
                "stackable": True,
                "max_stack": 99,
                "icon_key": "slime_gel",
                "is_active": True,
            },
            {
                "item_key": "cracked_bone",
                "display_name": "Cracked Bone",
                "description": "A brittle bone fragment from a roaming skeleton.",
                "item_type": "material",
                "stackable": True,
                "max_stack": 99,
                "icon_key": "cracked_bone",
                "is_active": True,
            },
            {
                "item_key": "wolf_pelt",
                "display_name": "Wolf Pelt",
                "description": "A rough pelt gathered from a wild wolf.",
                "item_type": "material",
                "stackable": True,
                "max_stack": 99,
                "icon_key": "wolf_pelt",
                "is_active": True,
            },
        ],
    )


def downgrade() -> None:
    op.drop_table("character_inventory")
    op.drop_table("item_definitions")
