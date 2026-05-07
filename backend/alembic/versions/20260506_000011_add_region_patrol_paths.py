"""add region patrol path definitions

Revision ID: 20260506_000011
Revises: 20260506_000010
Create Date: 2026-05-06 00:00:11.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_000011"
down_revision: Union[str, Sequence[str], None] = "20260506_000010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


region_patrol_paths = sa.table(
    "region_patrol_paths",
    sa.column("patrol_path_key", sa.String),
    sa.column("region_key", sa.String),
    sa.column("display_name", sa.String),
    sa.column("is_active", sa.Boolean),
)

region_patrol_points = sa.table(
    "region_patrol_points",
    sa.column("patrol_path_key", sa.String),
    sa.column("point_order", sa.Integer),
    sa.column("position_x", sa.Float),
    sa.column("position_y", sa.Float),
    sa.column("position_z", sa.Float),
    sa.column("wait_seconds", sa.Float),
)

region_enemy_spawns = sa.table(
    "region_enemy_spawns",
    sa.column("spawn_key", sa.String),
    sa.column("behavior_profile_key", sa.String),
    sa.column("patrol_path_key", sa.String),
)


def upgrade() -> None:
    op.create_table(
        "region_patrol_paths",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("patrol_path_key", sa.String(length=64), nullable=False),
        sa.Column("region_key", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.ForeignKeyConstraint(["region_key"], ["region_definitions.region_key"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "patrol_path_key",
            name="uq_region_patrol_paths_patrol_path_key",
        ),
    )

    op.create_table(
        "region_patrol_points",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("patrol_path_key", sa.String(length=64), nullable=False),
        sa.Column("point_order", sa.Integer(), nullable=False),
        sa.Column("position_x", sa.Float(), nullable=False),
        sa.Column("position_y", sa.Float(), server_default="0", nullable=False),
        sa.Column("position_z", sa.Float(), nullable=False),
        sa.Column("wait_seconds", sa.Float(), server_default="0", nullable=False),
        sa.ForeignKeyConstraint(
            ["patrol_path_key"],
            ["region_patrol_paths.patrol_path_key"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "patrol_path_key",
            "point_order",
            name="uq_region_patrol_points_path_order",
        ),
    )

    op.create_foreign_key(
        "fk_region_enemy_spawns_patrol_path_key",
        "region_enemy_spawns",
        "region_patrol_paths",
        ["patrol_path_key"],
        ["patrol_path_key"],
    )

    op.bulk_insert(
        region_patrol_paths,
        [
            {
                "patrol_path_key": "starter_field_grunt_patrol_1",
                "region_key": "starter_field",
                "display_name": "Starter Field Grunt Patrol 1",
                "is_active": True,
            },
        ],
    )

    op.bulk_insert(
        region_patrol_points,
        [
            {
                "patrol_path_key": "starter_field_grunt_patrol_1",
                "point_order": 1,
                "position_x": -8.0,
                "position_y": 0.0,
                "position_z": 8.0,
                "wait_seconds": 1.0,
            },
            {
                "patrol_path_key": "starter_field_grunt_patrol_1",
                "point_order": 2,
                "position_x": -2.0,
                "position_y": 0.0,
                "position_z": 10.0,
                "wait_seconds": 0.5,
            },
            {
                "patrol_path_key": "starter_field_grunt_patrol_1",
                "point_order": 3,
                "position_x": 3.0,
                "position_y": 0.0,
                "position_z": 6.0,
                "wait_seconds": 1.0,
            },
            {
                "patrol_path_key": "starter_field_grunt_patrol_1",
                "point_order": 4,
                "position_x": -4.0,
                "position_y": 0.0,
                "position_z": 4.0,
                "wait_seconds": 0.5,
            },
        ],
    )

    op.execute(
        region_enemy_spawns.update()
        .where(region_enemy_spawns.c.spawn_key == "starter_field_grunt_west")
        .values(
            behavior_profile_key="patrol",
            patrol_path_key="starter_field_grunt_patrol_1",
        )
    )


def downgrade() -> None:
    op.execute(
        region_enemy_spawns.update()
        .where(region_enemy_spawns.c.spawn_key == "starter_field_grunt_west")
        .values(behavior_profile_key="wander", patrol_path_key=None)
    )

    op.drop_constraint(
        "fk_region_enemy_spawns_patrol_path_key",
        "region_enemy_spawns",
        type_="foreignkey",
    )
    op.drop_table("region_patrol_points")
    op.drop_table("region_patrol_paths")
