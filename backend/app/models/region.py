from sqlalchemy import Boolean, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class RegionDefinition(Base):
    __tablename__ = "region_definitions"

    id: Mapped[int] = mapped_column(primary_key=True)
    region_key: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )

    enemy_spawns: Mapped[list["RegionEnemySpawn"]] = relationship(
        back_populates="region_definition",
        cascade="all, delete-orphan",
        order_by="RegionEnemySpawn.id",
    )


class RegionEnemySpawn(Base):
    __tablename__ = "region_enemy_spawns"

    id: Mapped[int] = mapped_column(primary_key=True)
    spawn_key: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    region_key: Mapped[str] = mapped_column(
        ForeignKey("region_definitions.region_key"),
        nullable=False,
    )
    enemy_key: Mapped[str] = mapped_column(
        ForeignKey("enemy_definitions.enemy_key"),
        nullable=False,
    )
    display_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    spawn_type: Mapped[str] = mapped_column(
        String(50),
        default="point",
        server_default="point",
        nullable=False,
    )
    position_x: Mapped[float] = mapped_column(Float, nullable=False)
    position_y: Mapped[float] = mapped_column(
        Float,
        default=0,
        server_default="0",
        nullable=False,
    )
    position_z: Mapped[float] = mapped_column(Float, nullable=False)
    spawn_radius: Mapped[float] = mapped_column(
        Float,
        default=0,
        server_default="0",
        nullable=False,
    )
    max_alive: Mapped[int] = mapped_column(
        Integer,
        default=1,
        server_default="1",
        nullable=False,
    )
    respawn_seconds: Mapped[float] = mapped_column(
        Float,
        default=10,
        server_default="10",
        nullable=False,
    )
    behavior_profile_key: Mapped[str] = mapped_column(
        String(64),
        default="wander",
        server_default="wander",
        nullable=False,
    )
    patrol_path_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    leash_radius_override: Mapped[float | None] = mapped_column(Float, nullable=True)
    aggro_radius_override: Mapped[float | None] = mapped_column(Float, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )

    region_definition: Mapped["RegionDefinition"] = relationship(
        back_populates="enemy_spawns"
    )
    enemy_definition: Mapped["EnemyDefinition"] = relationship(
        back_populates="region_spawns"
    )

    @property
    def enemy_display_name(self) -> str | None:
        if self.enemy_definition is None:
            return None

        return self.enemy_definition.display_name
