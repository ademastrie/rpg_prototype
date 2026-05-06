"""create region definitions

Revision ID: 20260506_000008
Revises: 20260506_000007
Create Date: 2026-05-06 00:00:08.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_000008"
down_revision: Union[str, Sequence[str], None] = "20260506_000007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


region_definitions = sa.table(
    "region_definitions",
    sa.column("region_key", sa.String),
    sa.column("display_name", sa.String),
    sa.column("description", sa.String),
    sa.column("is_active", sa.Boolean),
)

region_enemy_spawns = sa.table(
    "region_enemy_spawns",
    sa.column("spawn_key", sa.String),
    sa.column("region_key", sa.String),
    sa.column("enemy_key", sa.String),
    sa.column("display_name", sa.String),
    sa.column("spawn_type", sa.String),
    sa.column("position_x", sa.Float),
    sa.column("position_y", sa.Float),
    sa.column("position_z", sa.Float),
    sa.column("spawn_radius", sa.Float),
    sa.column("max_alive", sa.Integer),
    sa.column("respawn_seconds", sa.Float),
    sa.column("behavior_profile_key", sa.String),
    sa.column("patrol_path_key", sa.String),
    sa.column("leash_radius_override", sa.Float),
    sa.column("aggro_radius_override", sa.Float),
    sa.column("is_active", sa.Boolean),
)


def upgrade() -> None:
    op.create_table(
        "region_definitions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("region_key", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.String(length=500), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("region_key", name="uq_region_definitions_region_key"),
    )

    op.create_table(
        "region_enemy_spawns",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("spawn_key", sa.String(length=64), nullable=False),
        sa.Column("region_key", sa.String(length=64), nullable=False),
        sa.Column("enemy_key", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=True),
        sa.Column(
            "spawn_type",
            sa.String(length=50),
            server_default="point",
            nullable=False,
        ),
        sa.Column("position_x", sa.Float(), nullable=False),
        sa.Column("position_y", sa.Float(), server_default="0", nullable=False),
        sa.Column("position_z", sa.Float(), nullable=False),
        sa.Column("spawn_radius", sa.Float(), server_default="0", nullable=False),
        sa.Column("max_alive", sa.Integer(), server_default="1", nullable=False),
        sa.Column("respawn_seconds", sa.Float(), server_default="10", nullable=False),
        sa.Column(
            "behavior_profile_key",
            sa.String(length=64),
            server_default="wander",
            nullable=False,
        ),
        sa.Column("patrol_path_key", sa.String(length=64), nullable=True),
        sa.Column("leash_radius_override", sa.Float(), nullable=True),
        sa.Column("aggro_radius_override", sa.Float(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.ForeignKeyConstraint(["enemy_key"], ["enemy_definitions.enemy_key"]),
        sa.ForeignKeyConstraint(["region_key"], ["region_definitions.region_key"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("spawn_key", name="uq_region_enemy_spawns_spawn_key"),
    )

    op.bulk_insert(
        region_definitions,
        [
            {
                "region_key": "starter_field",
                "display_name": "Starter Field",
                "description": "Prototype outdoor field used for early combat testing.",
                "is_active": True,
            },
        ],
    )

    op.bulk_insert(
        region_enemy_spawns,
        [
            {
                "spawn_key": "starter_field_grunt_west",
                "region_key": "starter_field",
                "enemy_key": "grunt",
                "display_name": "West Grunt",
                "spawn_type": "point",
                "position_x": -120.0,
                "position_y": 0.0,
                "position_z": 80.0,
                "spawn_radius": 24.0,
                "max_alive": 1,
                "respawn_seconds": 10.0,
                "behavior_profile_key": "wander",
                "patrol_path_key": None,
                "leash_radius_override": None,
                "aggro_radius_override": None,
                "is_active": True,
            },
            {
                "spawn_key": "starter_field_grunt_east",
                "region_key": "starter_field",
                "enemy_key": "grunt",
                "display_name": "East Grunt",
                "spawn_type": "point",
                "position_x": 160.0,
                "position_y": 0.0,
                "position_z": 120.0,
                "spawn_radius": 24.0,
                "max_alive": 1,
                "respawn_seconds": 10.0,
                "behavior_profile_key": "wander",
                "patrol_path_key": None,
                "leash_radius_override": None,
                "aggro_radius_override": None,
                "is_active": True,
            },
            {
                "spawn_key": "starter_field_brute_north",
                "region_key": "starter_field",
                "enemy_key": "brute",
                "display_name": "North Brute",
                "spawn_type": "point",
                "position_x": 260.0,
                "position_y": 0.0,
                "position_z": -80.0,
                "spawn_radius": 32.0,
                "max_alive": 1,
                "respawn_seconds": 15.0,
                "behavior_profile_key": "wander",
                "patrol_path_key": None,
                "leash_radius_override": None,
                "aggro_radius_override": None,
                "is_active": True,
            },
            {
                "spawn_key": "starter_field_caster_south",
                "region_key": "starter_field",
                "enemy_key": "caster",
                "display_name": "South Caster",
                "spawn_type": "point",
                "position_x": -220.0,
                "position_y": 0.0,
                "position_z": -140.0,
                "spawn_radius": 28.0,
                "max_alive": 1,
                "respawn_seconds": 12.0,
                "behavior_profile_key": "wander",
                "patrol_path_key": None,
                "leash_radius_override": None,
                "aggro_radius_override": None,
                "is_active": True,
            },
        ],
    )


def downgrade() -> None:
    op.drop_table("region_enemy_spawns")
    op.drop_table("region_definitions")
