from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.db import get_db
from app.models.character import Character
from app.models.enemy import EnemyDefinition
from app.models.region import RegionDefinition
from app.models.user import User
from app.progression import (
    apply_character_xp,
    enemy_kill_xp_award,
    level_delta_xp_multiplier,
    xp_to_next_level,
)
from app.server_auth import require_game_server_secret


router = APIRouter(prefix="/game", tags=["game"])


class ValidateJoinRequest(BaseModel):
    character_id: int


class ValidateJoinResponse(BaseModel):
    user_id: int
    character_id: int
    character_name: str
    level: int
    xp: int
    current_xp: int
    xp_to_next_level: int
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


class AwardEnemyXpRequest(BaseModel):
    character_id: int
    enemy_key: str
    region_key: str


class AwardEnemyXpResponse(BaseModel):
    character_id: int
    level: int
    current_xp: int
    xp_to_next_level: int
    xp_awarded: int
    leveled_up: bool
    levels_gained: int
    enemy_key: str
    enemy_level: int
    region_key: str
    region_xp_multiplier: float
    level_delta_multiplier: float


def _resolve_enemy_definition(
    payload: AwardEnemyXpRequest,
    db: Session,
) -> EnemyDefinition:
    enemy_key = payload.enemy_key.strip()
    enemy_definition = db.scalar(
        select(EnemyDefinition).where(
            EnemyDefinition.enemy_key == enemy_key,
            EnemyDefinition.is_active.is_(True),
        )
    )
    if enemy_definition is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown or inactive enemy_key: {enemy_key}.",
        )

    return enemy_definition


def _resolve_region_definition(
    payload: AwardEnemyXpRequest,
    db: Session,
) -> RegionDefinition:
    region_key = payload.region_key.strip()
    region_definition = db.scalar(
        select(RegionDefinition).where(
            RegionDefinition.region_key == region_key,
            RegionDefinition.is_active.is_(True),
        )
    )
    if region_definition is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown or inactive region_key: {region_key}.",
        )

    return region_definition


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
        current_xp=character.xp,
        xp_to_next_level=xp_to_next_level(character.level),
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


@router.post("/server/award-enemy-xp", response_model=AwardEnemyXpResponse)
def award_enemy_xp(
    payload: AwardEnemyXpRequest,
    _: None = Depends(require_game_server_secret),
    db: Session = Depends(get_db),
) -> AwardEnemyXpResponse:
    character = db.scalar(
        select(Character).where(Character.id == payload.character_id)
    )
    if character is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Character not found.",
        )

    enemy_definition = _resolve_enemy_definition(payload, db)
    region_definition = _resolve_region_definition(payload, db)
    delta_multiplier = level_delta_xp_multiplier(
        enemy_definition.level,
        character.level,
    )
    xp_awarded = enemy_kill_xp_award(
        enemy_level=enemy_definition.level,
        player_level=character.level,
        enemy_base_xp=enemy_definition.base_xp,
        region_xp_multiplier=region_definition.xp_multiplier,
    )
    result = apply_character_xp(character, xp_awarded)

    db.commit()
    db.refresh(character)

    return AwardEnemyXpResponse(
        character_id=result.character_id,
        level=result.level,
        current_xp=result.current_xp,
        xp_to_next_level=result.xp_to_next_level,
        xp_awarded=result.xp_awarded,
        leveled_up=result.leveled_up,
        levels_gained=result.levels_gained,
        enemy_key=enemy_definition.enemy_key,
        enemy_level=enemy_definition.level,
        region_key=region_definition.region_key,
        region_xp_multiplier=region_definition.xp_multiplier,
        level_delta_multiplier=delta_multiplier,
    )
