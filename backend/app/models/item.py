from typing import TYPE_CHECKING

from sqlalchemy import Boolean, ForeignKey, Integer, String, UniqueConstraint
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
    stackable: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    max_stack: Mapped[int] = mapped_column(Integer, default=99, server_default="99", nullable=False)
    icon_key: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    inventory_entries: Mapped[list["CharacterInventory"]] = relationship(back_populates="item_definition")


class CharacterInventory(Base):
    __tablename__ = "character_inventory"
    __table_args__ = (
        UniqueConstraint("character_id", "item_key", name="uq_character_inventory_character_item"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    character_id: Mapped[int] = mapped_column(ForeignKey("characters.id"), nullable=False)
    item_key: Mapped[str] = mapped_column(ForeignKey("item_definitions.item_key"), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)

    character: Mapped["Character"] = relationship(back_populates="inventory")
    item_definition: Mapped["ItemDefinition"] = relationship(back_populates="inventory_entries")
