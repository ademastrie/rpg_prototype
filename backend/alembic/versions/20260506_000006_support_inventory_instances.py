"""support stackable inventory and equipment instances

Revision ID: 20260506_000006
Revises: 20260506_000005
Create Date: 2026-05-06 00:00:06.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_000006"
down_revision: Union[str, Sequence[str], None] = "20260506_000005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint(
        "uq_character_inventory_character_item",
        "character_inventory",
        type_="unique",
    )
    op.add_column(
        "character_equipment",
        sa.Column("inventory_entry_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_character_equipment_inventory_entry_id",
        "character_equipment",
        "character_inventory",
        ["inventory_entry_id"],
        ["id"],
    )

    op.execute(
        """
        UPDATE character_equipment AS ce
        SET inventory_entry_id = ci.id
        FROM character_inventory AS ci
        WHERE ci.character_id = ce.character_id
          AND ci.item_key = ce.item_key
          AND ci.id = (
              SELECT min(ci2.id)
              FROM character_inventory AS ci2
              WHERE ci2.character_id = ce.character_id
                AND ci2.item_key = ce.item_key
          )
        """
    )

    op.execute(
        """
        UPDATE item_definitions
        SET stackable = true, max_stack = 99
        WHERE item_key IN ('slime_gel', 'cracked_bone', 'wolf_pelt')
        """
    )
    op.execute(
        """
        UPDATE item_definitions
        SET stackable = false, max_stack = 1
        WHERE item_key IN (
            'training_sword',
            'apprentice_staff',
            'simple_bow',
            'cloth_hood',
            'padded_chest',
            'cloth_wraps',
            'training_gloves',
            'cloth_pants',
            'worn_boots'
        )
        """
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_character_equipment_inventory_entry_id",
        "character_equipment",
        type_="foreignkey",
    )
    op.drop_column("character_equipment", "inventory_entry_id")

    op.execute(
        """
        DELETE FROM character_inventory AS duplicate
        USING character_inventory AS keep
        WHERE duplicate.character_id = keep.character_id
          AND duplicate.item_key = keep.item_key
          AND duplicate.id > keep.id
        """
    )
    op.create_unique_constraint(
        "uq_character_inventory_character_item",
        "character_inventory",
        ["character_id", "item_key"],
    )
