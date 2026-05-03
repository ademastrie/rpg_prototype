from datetime import datetime

from pydantic import BaseModel


class CharacterCreate(BaseModel):
    name: str


class CharacterResponse(BaseModel):
    id: int
    user_id: int
    name: str
    level: int
    xp: int
    region_id: str
    position_x: float
    position_y: float
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
