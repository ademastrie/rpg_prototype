"""add character equipment

Revision ID: 20260506_000005
Revises: 20260506_000004
Create Date: 2026-05-06 00:00:05.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_000005"
down_revision: Union[str, Sequence[str], None] = "20260506_000004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


item_definitions = sa.table(
    "item_definitions",
    sa.column("item_key", sa.String),
    sa.column("display_name", sa.String),
    sa.column("description", sa.String),
    sa.column("item_type", sa.String),
    sa.column("equip_slot", sa.String),
    sa.column("stackable", sa.Boolean),
    sa.column("max_stack", sa.Integer),
    sa.column("icon_key", sa.String),
    sa.column("is_active", sa.Boolean),
)

item_stat_modifiers = sa.table(
    "item_stat_modifiers",
    sa.column("item_key", sa.String),
    sa.column("stat_key", sa.String),
    sa.column("value", sa.Float),
    sa.column("modifier_type", sa.String),
)


def upgrade() -> None:
    op.add_column(
        "item_definitions",
        sa.Column("equip_slot", sa.String(length=50), nullable=True),
    )

    op.create_table(
        "item_stat_modifiers",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_key", sa.String(length=64), nullable=False),
        sa.Column("stat_key", sa.String(length=64), nullable=False),
        sa.Column("value", sa.Float(), nullable=False),
        sa.Column("modifier_type", sa.String(length=32), server_default="flat", nullable=False),
        sa.ForeignKeyConstraint(["item_key"], ["item_definitions.item_key"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "character_equipment",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("character_id", sa.Integer(), nullable=False),
        sa.Column("equip_slot", sa.String(length=50), nullable=False),
        sa.Column("item_key", sa.String(length=64), nullable=False),
        sa.ForeignKeyConstraint(["character_id"], ["characters.id"]),
        sa.ForeignKeyConstraint(["item_key"], ["item_definitions.item_key"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("character_id", "equip_slot", name="uq_character_equipment_character_slot"),
    )

    op.bulk_insert(
        item_definitions,
        [
            {
                "item_key": "training_sword",
                "display_name": "Training Sword",
                "description": "A blunt practice blade balanced for beginner drills.",
                "item_type": "equipment",
                "equip_slot": "weapon",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "training_sword",
                "is_active": True,
            },
            {
                "item_key": "apprentice_staff",
                "display_name": "Apprentice Staff",
                "description": "A simple focus used by new spellcasters.",
                "item_type": "equipment",
                "equip_slot": "weapon",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "apprentice_staff",
                "is_active": True,
            },
            {
                "item_key": "simple_bow",
                "display_name": "Simple Bow",
                "description": "A plain shortbow suitable for field practice.",
                "item_type": "equipment",
                "equip_slot": "weapon",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "simple_bow",
                "is_active": True,
            },
            {
                "item_key": "cloth_hood",
                "display_name": "Cloth Hood",
                "description": "A soft hood with light padding.",
                "item_type": "equipment",
                "equip_slot": "head",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "cloth_hood",
                "is_active": True,
            },
            {
                "item_key": "padded_chest",
                "display_name": "Padded Chest",
                "description": "A stitched chest piece for basic protection.",
                "item_type": "equipment",
                "equip_slot": "chest",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "padded_chest",
                "is_active": True,
            },
            {
                "item_key": "cloth_wraps",
                "display_name": "Cloth Wraps",
                "description": "Layered wraps that soften glancing blows.",
                "item_type": "equipment",
                "equip_slot": "arms",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "cloth_wraps",
                "is_active": True,
            },
            {
                "item_key": "training_gloves",
                "display_name": "Training Gloves",
                "description": "Light gloves made for weapon practice.",
                "item_type": "equipment",
                "equip_slot": "hands",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "training_gloves",
                "is_active": True,
            },
            {
                "item_key": "cloth_pants",
                "display_name": "Cloth Pants",
                "description": "Plain pants reinforced at the knees.",
                "item_type": "equipment",
                "equip_slot": "legs",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "cloth_pants",
                "is_active": True,
            },
            {
                "item_key": "worn_boots",
                "display_name": "Worn Boots",
                "description": "Scuffed boots that still have a little road left in them.",
                "item_type": "equipment",
                "equip_slot": "feet",
                "stackable": False,
                "max_stack": 1,
                "icon_key": "worn_boots",
                "is_active": True,
            },
        ],
    )

    op.bulk_insert(
        item_stat_modifiers,
        [
            {"item_key": "training_sword", "stat_key": "attack_power", "value": 2.0, "modifier_type": "flat"},
            {"item_key": "apprentice_staff", "stat_key": "spell_power", "value": 2.0, "modifier_type": "flat"},
            {"item_key": "simple_bow", "stat_key": "attack_power", "value": 1.0, "modifier_type": "flat"},
            {"item_key": "simple_bow", "stat_key": "move_speed", "value": 0.02, "modifier_type": "percent"},
            {"item_key": "cloth_hood", "stat_key": "max_hp", "value": 3.0, "modifier_type": "flat"},
            {"item_key": "padded_chest", "stat_key": "max_hp", "value": 8.0, "modifier_type": "flat"},
            {"item_key": "padded_chest", "stat_key": "damage_reduction", "value": 1.0, "modifier_type": "flat"},
            {"item_key": "cloth_wraps", "stat_key": "max_hp", "value": 4.0, "modifier_type": "flat"},
            {"item_key": "training_gloves", "stat_key": "damage_reduction", "value": 0.5, "modifier_type": "flat"},
            {"item_key": "cloth_pants", "stat_key": "max_hp", "value": 5.0, "modifier_type": "flat"},
            {"item_key": "worn_boots", "stat_key": "max_hp", "value": 3.0, "modifier_type": "flat"},
        ],
    )


def downgrade() -> None:
    op.drop_table("character_equipment")
    op.drop_table("item_stat_modifiers")
    op.execute(
        "DELETE FROM character_inventory WHERE item_key IN ("
        "'training_sword', "
        "'apprentice_staff', "
        "'simple_bow', "
        "'cloth_hood', "
        "'padded_chest', "
        "'cloth_wraps', "
        "'training_gloves', "
        "'cloth_pants', "
        "'worn_boots'"
        ")"
    )
    op.execute(
        "DELETE FROM item_definitions WHERE item_key IN ("
        "'training_sword', "
        "'apprentice_staff', "
        "'simple_bow', "
        "'cloth_hood', "
        "'padded_chest', "
        "'cloth_wraps', "
        "'training_gloves', "
        "'cloth_pants', "
        "'worn_boots'"
        ")"
    )
    op.drop_column("item_definitions", "equip_slot")
