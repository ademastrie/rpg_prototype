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
from app.progression import apply_character_xp, enemy_kill_xp_award
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
    enemy_level: int | None = None
    enemy_base_xp: int | None = None
    region_key: str | None = None
    region_xp_multiplier: float | None = None


class AwardEnemyXpResponse(BaseModel):
    character_id: int
    level: int
    current_xp: int
    xp_to_next_level: int
    xp_awarded: int
    leveled_up: bool
    levels_gained: int


def _resolve_enemy_xp_inputs(
    payload: AwardEnemyXpRequest,
    db: Session,
) -> tuple[int, int]:
    enemy_key = payload.enemy_key.strip()
    enemy_definition = db.scalar(
        select(EnemyDefinition).where(
            EnemyDefinition.enemy_key == enemy_key,
            EnemyDefinition.is_active.is_(True),
        )
    )
    if enemy_definition is not None:
        return enemy_definition.level, enemy_definition.base_xp

    if payload.enemy_level is None or payload.enemy_base_xp is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Unknown enemy_key requires enemy_level and enemy_base_xp.",
        )

    if payload.enemy_level < 1:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="enemy_level must be at least 1.",
        )

    if payload.enemy_base_xp < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="enemy_base_xp cannot be negative.",
        )

    return payload.enemy_level, payload.enemy_base_xp


def _resolve_region_xp_multiplier(
    payload: AwardEnemyXpRequest,
    db: Session,
) -> float:
    if payload.region_key is not None:
        region_key = payload.region_key.strip()
        region_definition = db.scalar(
            select(RegionDefinition).where(
                RegionDefinition.region_key == region_key,
                RegionDefinition.is_active.is_(True),
            )
        )
        if region_definition is not None:
            return region_definition.xp_multiplier

    multiplier = payload.region_xp_multiplier
    if multiplier is None:
        return 1.0

    if multiplier < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="region_xp_multiplier cannot be negative.",
        )

    return multiplier


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

    enemy_level, enemy_base_xp = _resolve_enemy_xp_inputs(payload, db)
    region_xp_multiplier = _resolve_region_xp_multiplier(payload, db)
    xp_awarded = enemy_kill_xp_award(
        enemy_level=enemy_level,
        player_level=character.level,
        enemy_base_xp=enemy_base_xp,
        region_xp_multiplier=region_xp_multiplier,
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
    )
