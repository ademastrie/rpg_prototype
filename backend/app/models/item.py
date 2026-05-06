from typing import TYPE_CHECKING

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.character import Character


class ItemDefinition(Base):
    __tablename__ = "item_definitions"

    id: Mapped[int] = mapped_column(primary_key=True)
    item_key: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    item_type: Mapped[str] = mapped_column(String(50), nullable=False)
    equip_slot: Mapped[str | None] = mapped_column(String(50), nullable=True)
    stackable: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    max_stack: Mapped[int] = mapped_column(Integer, default=99, server_default="99", nullable=False)
    icon_key: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    inventory_entries: Mapped[list["CharacterInventory"]] = relationship(back_populates="item_definition")
    stat_modifiers: Mapped[list["ItemStatModifier"]] = relationship(
        back_populates="item_definition",
        cascade="all, delete-orphan",
    )
    equipment_entries: Mapped[list["CharacterEquipment"]] = relationship(back_populates="item_definition")


class ItemStatModifier(Base):
    __tablename__ = "item_stat_modifiers"

    id: Mapped[int] = mapped_column(primary_key=True)
    item_key: Mapped[str] = mapped_column(ForeignKey("item_definitions.item_key"), nullable=False)
    stat_key: Mapped[str] = mapped_column(String(64), nullable=False)
    value: Mapped[float] = mapped_column(Float, nullable=False)
    modifier_type: Mapped[str] = mapped_column(String(32), default="flat", server_default="flat", nullable=False)

    item_definition: Mapped["ItemDefinition"] = relationship(back_populates="stat_modifiers")


class CharacterInventory(Base):
    __tablename__ = "character_inventory"

    id: Mapped[int] = mapped_column(primary_key=True)
    character_id: Mapped[int] = mapped_column(ForeignKey("characters.id"), nullable=False)
    item_key: Mapped[str] = mapped_column(ForeignKey("item_definitions.item_key"), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)

    character: Mapped["Character"] = relationship(back_populates="inventory")
    item_definition: Mapped["ItemDefinition"] = relationship(back_populates="inventory_entries")
    equipment_entries: Mapped[list["CharacterEquipment"]] = relationship(
        back_populates="inventory_entry",
    )


class CharacterEquipment(Base):
    __tablename__ = "character_equipment"
    __table_args__ = (
        UniqueConstraint("character_id", "equip_slot", name="uq_character_equipment_character_slot"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    character_id: Mapped[int] = mapped_column(ForeignKey("characters.id"), nullable=False)
    equip_slot: Mapped[str] = mapped_column(String(50), nullable=False)
    item_key: Mapped[str] = mapped_column(ForeignKey("item_definitions.item_key"), nullable=False)
    inventory_entry_id: Mapped[int | None] = mapped_column(
        ForeignKey("character_inventory.id"),
        nullable=True,
    )

    character: Mapped["Character"] = relationship(back_populates="equipment")
    item_definition: Mapped["ItemDefinition"] = relationship(back_populates="equipment_entries")
    inventory_entry: Mapped["CharacterInventory | None"] = relationship(
        back_populates="equipment_entries",
    )
