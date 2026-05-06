from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload, with_loader_criteria

from app.db import get_db
from app.models.region import RegionDefinition, RegionEnemySpawn
from app.regions.schemas import (
    RegionDefinitionDetailResponse,
    RegionDefinitionResponse,
    RegionEnemySpawnsResponse,
)


router = APIRouter(prefix="/regions", tags=["regions"])


def _region_options() -> tuple:
    return (
        selectinload(RegionDefinition.enemy_spawns).selectinload(
            RegionEnemySpawn.enemy_definition
        ),
        with_loader_criteria(
            RegionEnemySpawn,
            RegionEnemySpawn.is_active.is_(True),
            include_aliases=True,
        ),
    )


def _get_active_region(region_key: str, db: Session) -> RegionDefinition:
    region = db.scalar(
        select(RegionDefinition)
        .options(*_region_options())
        .where(
            RegionDefinition.region_key == region_key.strip(),
            RegionDefinition.is_active.is_(True),
        )
    )
    if region is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Region definition not found.",
        )

    return region


@router.get("", response_model=list[RegionDefinitionResponse])
def list_regions(db: Session = Depends(get_db)) -> list[RegionDefinition]:
    return list(
        db.scalars(
            select(RegionDefinition)
            .where(RegionDefinition.is_active.is_(True))
            .order_by(RegionDefinition.display_name, RegionDefinition.id)
        ).all()
    )


@router.get("/{region_key}", response_model=RegionDefinitionDetailResponse)
def get_region(
    region_key: str,
    db: Session = Depends(get_db),
) -> RegionDefinition:
    return _get_active_region(region_key, db)


@router.get("/{region_key}/enemy-spawns", response_model=RegionEnemySpawnsResponse)
def list_region_enemy_spawns(
    region_key: str,
    db: Session = Depends(get_db),
) -> RegionDefinition:
    return _get_active_region(region_key, db)
