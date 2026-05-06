"""create enemy definitions

Revision ID: 20260506_000007
Revises: 20260506_000006
Create Date: 2026-05-06 00:00:07.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_000007"
down_revision: Union[str, Sequence[str], None] = "20260506_000006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


enemy_definitions = sa.table(
    "enemy_definitions",
    sa.column("enemy_key", sa.String),
    sa.column("display_name", sa.String),
    sa.column("description", sa.String),
    sa.column("level", sa.Integer),
    sa.column("max_hp", sa.Integer),
    sa.column("move_speed", sa.Float),
    sa.column("xp_reward", sa.Integer),
    sa.column("aggro_radius", sa.Float),
    sa.column("leash_radius", sa.Float),
    sa.column("visual_key", sa.String),
    sa.column("is_active", sa.Boolean),
)

enemy_attacks = sa.table(
    "enemy_attacks",
    sa.column("enemy_key", sa.String),
    sa.column("attack_key", sa.String),
    sa.column("attack_type", sa.String),
    sa.column("damage", sa.Integer),
    sa.column("range", sa.Float),
    sa.column("radius", sa.Float),
    sa.column("windup_seconds", sa.Float),
    sa.column("recovery_seconds", sa.Float),
    sa.column("cooldown_seconds", sa.Float),
    sa.column("visual_key", sa.String),
)

enemy_loot_entries = sa.table(
    "enemy_loot_entries",
    sa.column("enemy_key", sa.String),
    sa.column("payload_type", sa.String),
    sa.column("item_key", sa.String),
    sa.column("min_quantity", sa.Integer),
    sa.column("max_quantity", sa.Integer),
    sa.column("drop_chance", sa.Float),
    sa.column("is_active", sa.Boolean),
)


def upgrade() -> None:
    op.create_table(
        "enemy_definitions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("enemy_key", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.String(length=500), nullable=True),
        sa.Column("level", sa.Integer(), server_default="1", nullable=False),
        sa.Column("max_hp", sa.Integer(), nullable=False),
        sa.Column("move_speed", sa.Float(), nullable=False),
        sa.Column("xp_reward", sa.Integer(), nullable=False),
        sa.Column("aggro_radius", sa.Float(), nullable=False),
        sa.Column("leash_radius", sa.Float(), nullable=True),
        sa.Column("visual_key", sa.String(length=100), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("enemy_key", name="uq_enemy_definitions_enemy_key"),
    )

    op.create_table(
        "enemy_attacks",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("enemy_key", sa.String(length=64), nullable=False),
        sa.Column("attack_key", sa.String(length=64), nullable=False),
        sa.Column("attack_type", sa.String(length=50), nullable=False),
        sa.Column("damage", sa.Integer(), nullable=False),
        sa.Column("range", sa.Float(), nullable=False),
        sa.Column("radius", sa.Float(), nullable=True),
        sa.Column("windup_seconds", sa.Float(), nullable=False),
        sa.Column("recovery_seconds", sa.Float(), nullable=False),
        sa.Column("cooldown_seconds", sa.Float(), nullable=False),
        sa.Column("visual_key", sa.String(length=100), nullable=True),
        sa.CheckConstraint(
            "attack_type IN ('melee_circle', 'ranged_line', 'ranged_bolt')",
            name="ck_enemy_attacks_attack_type",
        ),
        sa.ForeignKeyConstraint(["enemy_key"], ["enemy_definitions.enemy_key"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("enemy_key", "attack_key", name="uq_enemy_attacks_enemy_attack"),
    )

    op.create_table(
        "enemy_loot_entries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("enemy_key", sa.String(length=64), nullable=False),
        sa.Column("payload_type", sa.String(length=50), nullable=False),
        sa.Column("item_key", sa.String(length=64), nullable=True),
        sa.Column("min_quantity", sa.Integer(), nullable=False),
        sa.Column("max_quantity", sa.Integer(), nullable=False),
        sa.Column("drop_chance", sa.Float(), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.CheckConstraint(
            "payload_type IN ('currency', 'item')",
            name="ck_enemy_loot_entries_payload_type",
        ),
        sa.ForeignKeyConstraint(["enemy_key"], ["enemy_definitions.enemy_key"]),
        sa.ForeignKeyConstraint(["item_key"], ["item_definitions.item_key"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.bulk_insert(
        enemy_definitions,
        [
            {
                "enemy_key": "grunt",
                "display_name": "Grunt",
                "description": "A basic melee enemy used by the prototype server simulation.",
                "level": 1,
                "max_hp": 30,
                "move_speed": 85.0,
                "xp_reward": 12,
                "aggro_radius": 180.0,
                "leash_radius": 360.0,
                "visual_key": "grunt",
                "is_active": True,
            },
            {
                "enemy_key": "brute",
                "display_name": "Brute",
                "description": "A tougher melee enemy with slower but heavier swings.",
                "level": 3,
                "max_hp": 95,
                "move_speed": 65.0,
                "xp_reward": 32,
                "aggro_radius": 190.0,
                "leash_radius": 380.0,
                "visual_key": "brute",
                "is_active": True,
            },
            {
                "enemy_key": "caster",
                "display_name": "Caster",
                "description": "A ranged prototype enemy that attacks from a distance.",
                "level": 2,
                "max_hp": 45,
                "move_speed": 75.0,
                "xp_reward": 22,
                "aggro_radius": 260.0,
                "leash_radius": 420.0,
                "visual_key": "caster",
                "is_active": True,
            },
        ],
    )

    op.bulk_insert(
        enemy_attacks,
        [
            {
                "enemy_key": "grunt",
                "attack_key": "claw_swipe",
                "attack_type": "melee_circle",
                "damage": 6,
                "range": 34.0,
                "radius": 24.0,
                "windup_seconds": 0.2,
                "recovery_seconds": 0.35,
                "cooldown_seconds": 1.2,
                "visual_key": "claw_swipe",
            },
            {
                "enemy_key": "brute",
                "attack_key": "heavy_slam",
                "attack_type": "melee_circle",
                "damage": 14,
                "range": 42.0,
                "radius": 36.0,
                "windup_seconds": 0.45,
                "recovery_seconds": 0.75,
                "cooldown_seconds": 2.4,
                "visual_key": "heavy_slam",
            },
            {
                "enemy_key": "caster",
                "attack_key": "shadow_bolt",
                "attack_type": "ranged_bolt",
                "damage": 9,
                "range": 240.0,
                "radius": 8.0,
                "windup_seconds": 0.35,
                "recovery_seconds": 0.45,
                "cooldown_seconds": 1.8,
                "visual_key": "shadow_bolt",
            },
        ],
    )

    op.bulk_insert(
        enemy_loot_entries,
        [
            {
                "enemy_key": "grunt",
                "payload_type": "currency",
                "item_key": None,
                "min_quantity": 1,
                "max_quantity": 4,
                "drop_chance": 0.8,
                "is_active": True,
            },
            {
                "enemy_key": "grunt",
                "payload_type": "item",
                "item_key": "slime_gel",
                "min_quantity": 1,
                "max_quantity": 2,
                "drop_chance": 0.35,
                "is_active": True,
            },
            {
                "enemy_key": "brute",
                "payload_type": "currency",
                "item_key": None,
                "min_quantity": 4,
                "max_quantity": 10,
                "drop_chance": 0.9,
                "is_active": True,
            },
            {
                "enemy_key": "brute",
                "payload_type": "item",
                "item_key": "padded_chest",
                "min_quantity": 1,
                "max_quantity": 1,
                "drop_chance": 0.08,
                "is_active": True,
            },
            {
                "enemy_key": "caster",
                "payload_type": "currency",
                "item_key": None,
                "min_quantity": 2,
                "max_quantity": 7,
                "drop_chance": 0.85,
                "is_active": True,
            },
            {
                "enemy_key": "caster",
                "payload_type": "item",
                "item_key": "training_sword",
                "min_quantity": 1,
                "max_quantity": 1,
                "drop_chance": 0.05,
                "is_active": True,
            },
        ],
    )


def downgrade() -> None:
    op.drop_table("enemy_loot_entries")
    op.drop_table("enemy_attacks")
    op.drop_table("enemy_definitions")
