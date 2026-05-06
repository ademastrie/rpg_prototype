"""tune prototype enemies to Godot world units

Revision ID: 20260506_000009
Revises: 20260506_000008
Create Date: 2026-05-06 00:00:09.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_000009"
down_revision: Union[str, Sequence[str], None] = "20260506_000008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


enemy_definitions = sa.table(
    "enemy_definitions",
    sa.column("enemy_key", sa.String),
    sa.column("move_speed", sa.Float),
    sa.column("aggro_radius", sa.Float),
    sa.column("leash_radius", sa.Float),
)

enemy_attacks = sa.table(
    "enemy_attacks",
    sa.column("enemy_key", sa.String),
    sa.column("attack_key", sa.String),
    sa.column("range", sa.Float),
    sa.column("radius", sa.Float),
)

region_enemy_spawns = sa.table(
    "region_enemy_spawns",
    sa.column("spawn_key", sa.String),
    sa.column("position_x", sa.Float),
    sa.column("position_y", sa.Float),
    sa.column("position_z", sa.Float),
    sa.column("spawn_radius", sa.Float),
)


def upgrade() -> None:
    _update_enemy_definition("grunt", move_speed=3.0, aggro_radius=14.0, leash_radius=50.0)
    _update_enemy_definition("brute", move_speed=2.0, aggro_radius=12.0, leash_radius=55.0)
    _update_enemy_definition("caster", move_speed=2.5, aggro_radius=18.0, leash_radius=60.0)

    _update_enemy_attack("grunt", "claw_swipe", range=2.5, radius=2.4)
    _update_enemy_attack("brute", "heavy_slam", range=3.0, radius=3.4)
    _update_enemy_attack("caster", "shadow_bolt", range=16.0, radius=1.0)

    _update_region_spawn("starter_field_grunt_west", x=-8.0, y=0.0, z=8.0, radius=0.0)
    _update_region_spawn("starter_field_grunt_east", x=10.0, y=0.0, z=8.0, radius=0.0)
    _update_region_spawn("starter_field_brute_north", x=16.0, y=0.0, z=-6.0, radius=0.0)
    _update_region_spawn("starter_field_caster_south", x=-14.0, y=0.0, z=-8.0, radius=0.0)


def downgrade() -> None:
    _update_enemy_definition("grunt", move_speed=85.0, aggro_radius=180.0, leash_radius=360.0)
    _update_enemy_definition("brute", move_speed=65.0, aggro_radius=190.0, leash_radius=380.0)
    _update_enemy_definition("caster", move_speed=75.0, aggro_radius=260.0, leash_radius=420.0)

    _update_enemy_attack("grunt", "claw_swipe", range=34.0, radius=24.0)
    _update_enemy_attack("brute", "heavy_slam", range=42.0, radius=36.0)
    _update_enemy_attack("caster", "shadow_bolt", range=240.0, radius=8.0)

    _update_region_spawn("starter_field_grunt_west", x=-120.0, y=0.0, z=80.0, radius=24.0)
    _update_region_spawn("starter_field_grunt_east", x=160.0, y=0.0, z=120.0, radius=24.0)
    _update_region_spawn("starter_field_brute_north", x=260.0, y=0.0, z=-80.0, radius=32.0)
    _update_region_spawn("starter_field_caster_south", x=-220.0, y=0.0, z=-140.0, radius=28.0)


def _update_enemy_definition(
    enemy_key: str,
    *,
    move_speed: float,
    aggro_radius: float,
    leash_radius: float,
) -> None:
    op.execute(
        enemy_definitions.update()
        .where(enemy_definitions.c.enemy_key == enemy_key)
        .values(
            move_speed=move_speed,
            aggro_radius=aggro_radius,
            leash_radius=leash_radius,
        )
    )


def _update_enemy_attack(
    enemy_key: str,
    attack_key: str,
    *,
    range: float,
    radius: float,
) -> None:
    op.execute(
        enemy_attacks.update()
        .where(enemy_attacks.c.enemy_key == enemy_key)
        .where(enemy_attacks.c.attack_key == attack_key)
        .values(range=range, radius=radius)
    )


def _update_region_spawn(
    spawn_key: str,
    *,
    x: float,
    y: float,
    z: float,
    radius: float,
) -> None:
    op.execute(
        region_enemy_spawns.update()
        .where(region_enemy_spawns.c.spawn_key == spawn_key)
        .values(
            position_x=x,
            position_y=y,
            position_z=z,
            spawn_radius=radius,
        )
    )
