from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.db import get_db
from app.models.character import Character
from app.models.user import User


router = APIRouter(prefix="/game", tags=["game"])


class ValidateJoinRequest(BaseModel):
    character_id: int


class ValidateJoinResponse(BaseModel):
    user_id: int
    character_id: int
    character_name: str
    level: int
    xp: int
    gold: int
    region_id: str
    position_x: float
    position_y: float


class SavePositionRequest(BaseModel):
    character_id: int
    region_id: str
    position_x: float
    position_y: float


class SavePositionResponse(BaseModel):
    character_id: int
    region_id: str
    position_x: float
    position_y: float


@router.post("/validate-join", response_model=ValidateJoinResponse)
def validate_join(
    payload: ValidateJoinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ValidateJoinResponse:
    character = db.scalar(
        select(Character).where(
            Character.id == payload.character_id,
            Character.user_id == current_user.id,
        )
    )
    if character is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Character not found.",
        )

    return ValidateJoinResponse(
        user_id=current_user.id,
        character_id=character.id,
        character_name=character.name,
        level=character.level,
        xp=character.xp,
        gold=character.gold,
        region_id=character.region_id,
        position_x=character.position_x,
        position_y=character.position_y,
    )


@router.post("/save-position", response_model=SavePositionResponse)
def save_position(
    payload: SavePositionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SavePositionResponse:
    character = db.scalar(
        select(Character).where(
            Character.id == payload.character_id,
            Character.user_id == current_user.id,
        )
    )
    if character is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Character not found.",
        )

    character.region_id = payload.region_id
    character.position_x = payload.position_x
    character.position_y = payload.position_y
    db.commit()
    db.refresh(character)

    return SavePositionResponse(
        character_id=character.id,
        region_id=character.region_id,
        position_x=character.position_x,
        position_y=character.position_y,
    )
