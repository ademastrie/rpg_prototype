from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.ability import CharacterAbility, CharacterAbilityLoadout
    from app.models.item import CharacterEquipment, CharacterInventory
    from app.models.user import User


class Character(Base):
    __tablename__ = "characters"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(64), nullable=False)
    level: Mapped[int] = mapped_column(Integer, default=1, server_default="1", nullable=False)
    xp: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    gold: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    region_id: Mapped[str] = mapped_column(
        String(100),
        default="starting_region",
        server_default="starting_region",
        nullable=False,
    )
    position_x: Mapped[float] = mapped_column(Float, default=0, server_default="0", nullable=False)
    position_y: Mapped[float] = mapped_column(Float, default=0, server_default="0", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    user: Mapped["User"] = relationship(back_populates="characters")
    abilities: Mapped[list["CharacterAbility"]] = relationship(
        back_populates="character",
        cascade="all, delete-orphan",
    )
    ability_loadout: Mapped[list["CharacterAbilityLoadout"]] = relationship(
        back_populates="character",
        cascade="all, delete-orphan",
    )
    inventory: Mapped[list["CharacterInventory"]] = relationship(
        back_populates="character",
        cascade="all, delete-orphan",
    )
    equipment: Mapped[list["CharacterEquipment"]] = relationship(
        back_populates="character",
        cascade="all, delete-orphan",
    )
