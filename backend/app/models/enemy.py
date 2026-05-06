from sqlalchemy import Boolean, CheckConstraint, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class EnemyDefinition(Base):
    __tablename__ = "enemy_definitions"

    id: Mapped[int] = mapped_column(primary_key=True)
    enemy_key: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    level: Mapped[int] = mapped_column(Integer, default=1, server_default="1", nullable=False)
    max_hp: Mapped[int] = mapped_column(Integer, nullable=False)
    move_speed: Mapped[float] = mapped_column(Float, nullable=False)
    xp_reward: Mapped[int] = mapped_column(Integer, nullable=False)
    aggro_radius: Mapped[float] = mapped_column(Float, nullable=False)
    leash_radius: Mapped[float | None] = mapped_column(Float, nullable=True)
    visual_key: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    attacks: Mapped[list["EnemyAttack"]] = relationship(
        back_populates="enemy_definition",
        cascade="all, delete-orphan",
        order_by="EnemyAttack.id",
    )
    loot_entries: Mapped[list["EnemyLootEntry"]] = relationship(
        back_populates="enemy_definition",
        cascade="all, delete-orphan",
        order_by="EnemyLootEntry.id",
    )


class EnemyAttack(Base):
    __tablename__ = "enemy_attacks"
    __table_args__ = (
        CheckConstraint(
            "attack_type IN ('melee_circle', 'ranged_line', 'ranged_bolt')",
            name="ck_enemy_attacks_attack_type",
        ),
        UniqueConstraint("enemy_key", "attack_key", name="uq_enemy_attacks_enemy_attack"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    enemy_key: Mapped[str] = mapped_column(ForeignKey("enemy_definitions.enemy_key"), nullable=False)
    attack_key: Mapped[str] = mapped_column(String(64), nullable=False)
    attack_type: Mapped[str] = mapped_column(String(50), nullable=False)
    damage: Mapped[int] = mapped_column(Integer, nullable=False)
    range: Mapped[float] = mapped_column(Float, nullable=False)
    radius: Mapped[float | None] = mapped_column(Float, nullable=True)
    windup_seconds: Mapped[float] = mapped_column(Float, nullable=False)
    recovery_seconds: Mapped[float] = mapped_column(Float, nullable=False)
    cooldown_seconds: Mapped[float] = mapped_column(Float, nullable=False)
    visual_key: Mapped[str | None] = mapped_column(String(100), nullable=True)

    enemy_definition: Mapped["EnemyDefinition"] = relationship(back_populates="attacks")


class EnemyLootEntry(Base):
    __tablename__ = "enemy_loot_entries"
    __table_args__ = (
        CheckConstraint(
            "payload_type IN ('currency', 'item')",
            name="ck_enemy_loot_entries_payload_type",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    enemy_key: Mapped[str] = mapped_column(ForeignKey("enemy_definitions.enemy_key"), nullable=False)
    payload_type: Mapped[str] = mapped_column(String(50), nullable=False)
    item_key: Mapped[str | None] = mapped_column(ForeignKey("item_definitions.item_key"), nullable=True)
    min_quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    max_quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    drop_chance: Mapped[float] = mapped_column(Float, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    enemy_definition: Mapped["EnemyDefinition"] = relationship(back_populates="loot_entries")
