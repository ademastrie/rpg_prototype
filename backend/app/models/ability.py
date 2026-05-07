from typing import TYPE_CHECKING

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.character import Character


class AbilityDefinition(Base):
    __tablename__ = "ability_definitions"

    id: Mapped[int] = mapped_column(primary_key=True)
    ability_key: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    behavior_key: Mapped[str | None] = mapped_column(String(100), nullable=True)
    trigger_type: Mapped[str] = mapped_column(String(50), nullable=False)
    targeting_type: Mapped[str] = mapped_column(String(50), nullable=False)
    cooldown_seconds: Mapped[float] = mapped_column(Float, default=0, server_default="0", nullable=False)
    range: Mapped[float | None] = mapped_column(Float, nullable=True)
    radius: Mapped[float | None] = mapped_column(Float, nullable=True)
    arc_angle_degrees: Mapped[float | None] = mapped_column(Float, nullable=True)
    visual_key: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    effects: Mapped[list["AbilityEffect"]] = relationship(
        back_populates="ability",
        cascade="all, delete-orphan",
    )

    @property
    def damage(self) -> float | None:
        return self._effect_value("damage")

    @property
    def healing(self) -> float | None:
        return self._effect_value("healing")

    @property
    def tick_seconds(self) -> float | None:
        for effect in self.effects:
            if effect.tick_interval_seconds is not None:
                return effect.tick_interval_seconds
        return None

    def _effect_value(self, effect_type: str) -> float | None:
        for effect in self.effects:
            if effect.effect_type == effect_type:
                return effect.value
        return None


class AbilityEffect(Base):
    __tablename__ = "ability_effects"

    id: Mapped[int] = mapped_column(primary_key=True)
    ability_key: Mapped[str] = mapped_column(ForeignKey("ability_definitions.ability_key"), nullable=False)
    effect_type: Mapped[str] = mapped_column(String(50), nullable=False)
    target_team: Mapped[str] = mapped_column(String(50), nullable=False)
    stat_key: Mapped[str | None] = mapped_column(String(50), nullable=True)
    value: Mapped[float] = mapped_column(Float, nullable=False)
    tick_interval_seconds: Mapped[float | None] = mapped_column(Float, nullable=True)
    duration_seconds: Mapped[float | None] = mapped_column(Float, nullable=True)

    ability: Mapped["AbilityDefinition"] = relationship(back_populates="effects")


class CharacterAbility(Base):
    __tablename__ = "character_abilities"
    __table_args__ = (
        UniqueConstraint("character_id", "ability_key", name="uq_character_abilities_character_ability"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    character_id: Mapped[int] = mapped_column(ForeignKey("characters.id"), nullable=False)
    ability_key: Mapped[str] = mapped_column(ForeignKey("ability_definitions.ability_key"), nullable=False)
    unlocked: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    ability_level: Mapped[int] = mapped_column(Integer, default=1, server_default="1", nullable=False)
    ability_xp: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)

    character: Mapped["Character"] = relationship(back_populates="abilities")
    ability: Mapped["AbilityDefinition"] = relationship()


class CharacterAbilityLoadout(Base):
    __tablename__ = "character_ability_loadout"
    __table_args__ = (
        UniqueConstraint("character_id", "slot_index", name="uq_character_ability_loadout_character_slot"),
        UniqueConstraint("character_id", "ability_key", name="uq_character_ability_loadout_character_ability"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    character_id: Mapped[int] = mapped_column(ForeignKey("characters.id"), nullable=False)
    slot_index: Mapped[int] = mapped_column(Integer, nullable=False)
    ability_key: Mapped[str] = mapped_column(ForeignKey("ability_definitions.ability_key"), nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    character: Mapped["Character"] = relationship(back_populates="ability_loadout")
    ability: Mapped["AbilityDefinition"] = relationship()
