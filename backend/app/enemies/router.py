from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db import get_db
from app.enemies.schemas import EnemyDefinitionResponse
from app.models.enemy import EnemyDefinition


router = APIRouter(prefix="/enemy-definitions", tags=["enemy-definitions"])


def _enemy_definition_options() -> tuple:
    return (
        selectinload(EnemyDefinition.attacks),
        selectinload(EnemyDefinition.loot_entries),
    )


@router.get("", response_model=list[EnemyDefinitionResponse])
def list_enemy_definitions(db: Session = Depends(get_db)) -> list[EnemyDefinition]:
    return list(
        db.scalars(
            select(EnemyDefinition)
            .options(*_enemy_definition_options())
            .where(EnemyDefinition.is_active.is_(True))
            .order_by(EnemyDefinition.level, EnemyDefinition.id)
        ).all()
    )


@router.get("/{enemy_key}", response_model=EnemyDefinitionResponse)
def get_enemy_definition(
    enemy_key: str,
    db: Session = Depends(get_db),
) -> EnemyDefinition:
    enemy_definition = db.scalar(
        select(EnemyDefinition)
        .options(*_enemy_definition_options())
        .where(
            EnemyDefinition.enemy_key == enemy_key.strip(),
            EnemyDefinition.is_active.is_(True),
        )
    )
    if enemy_definition is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Enemy definition not found.",
        )

    return enemy_definition
