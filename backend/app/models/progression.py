from sqlalchemy import Boolean, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class LevelReward(Base):
    __tablename__ = "level_rewards"
    __table_args__ = (
        UniqueConstraint(
            "level_required",
            "reward_type",
            "reward_key",
            name="uq_level_rewards_level_type_key",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    level_required: Mapped[int] = mapped_column(Integer, nullable=False)
    reward_type: Mapped[str] = mapped_column(String(50), nullable=False)
    reward_key: Mapped[str] = mapped_column(String(100), nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
