from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.orm import Session, selectinload

from app.auth.dependencies import get_current_user
from app.characters.schemas import (
    AbilityLoadoutEntry,
    AbilityLoadoutUpdate,
    CharacterAbilitiesResponse,
    CharacterAbilityResponse,
    CharacterCreate,
    CharacterResponse,
)
from app.db import get_db
from app.models.ability import AbilityDefinition, CharacterAbility, CharacterAbilityLoadout
from app.models.character import Character
from app.models.user import User


router = APIRouter(prefix="/characters", tags=["characters"])
MAX_LOADOUT_ENTRIES = 5
DEFAULT_STARTER_ABILITY_KEY = "slash"
STARTER_ABILITY_KEYS = {"slash", "firebolt"}


def _get_owned_character(character_id: int, user_id: int, db: Session) -> Character:
    character = db.scalar(
        select(Character).where(
            Character.id == character_id,
            Character.user_id == user_id,
        )
    )
    if character is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Character not found.",
        )

    return character


def _active_ability_definitions(db: Session) -> list[AbilityDefinition]:
    return list(
        db.scalars(
            select(AbilityDefinition)
            .where(AbilityDefinition.is_active.is_(True))
            .order_by(AbilityDefinition.id)
        ).all()
    )


def _get_starter_ability_definition(ability_key: str, db: Session) -> AbilityDefinition:
    starter_ability_key = ability_key.strip()
    if starter_ability_key not in STARTER_ABILITY_KEYS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Selected starter ability is not allowed.",
        )

    ability_definition = db.scalar(
        select(AbilityDefinition).where(
            AbilityDefinition.ability_key == starter_ability_key,
            AbilityDefinition.is_active.is_(True),
        )
    )
    if ability_definition is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Selected starter ability is not available.",
        )

    return ability_definition


def _get_ability_definition(ability_key: str, db: Session) -> AbilityDefinition:
    ability_key_text = ability_key.strip()
    ability_definition = db.scalar(
        select(AbilityDefinition).where(
            AbilityDefinition.ability_key == ability_key_text,
        )
    )
    if ability_definition is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown ability_key: {ability_key_text}.",
        )

    return ability_definition


def _grant_starter_ability(
    character_id: int,
    ability_definition: AbilityDefinition,
    db: Session,
) -> None:
    db.add(
        CharacterAbility(
            character_id=character_id,
            ability_key=ability_definition.ability_key,
        )
    )
    db.add(
        CharacterAbilityLoadout(
            character_id=character_id,
            slot_index=0,
            ability_key=ability_definition.ability_key,
            enabled=True,
        )
    )


def _unlock_character_ability(
    character_id: int,
    ability_definition: AbilityDefinition,
    db: Session,
) -> None:
    character_ability = db.scalar(
        select(CharacterAbility).where(
            CharacterAbility.character_id == character_id,
            CharacterAbility.ability_key == ability_definition.ability_key,
        )
    )
    if character_ability is None:
        db.add(
            CharacterAbility(
                character_id=character_id,
                ability_key=ability_definition.ability_key,
                unlocked=True,
            )
        )
        return

    character_ability.unlocked = True


def _ensure_starter_abilities(character_id: int, db: Session) -> None:
    has_abilities = db.scalar(
        select(CharacterAbility.id)
        .where(CharacterAbility.character_id == character_id)
        .limit(1)
    )
    has_loadout = db.scalar(
        select(CharacterAbilityLoadout.id)
        .where(CharacterAbilityLoadout.character_id == character_id)
        .limit(1)
    )

    if has_abilities is not None and has_loadout is not None:
        return

    ability_definitions = _active_ability_definitions(db)

    if has_abilities is None:
        starter_ability = next(
            (
                ability_definition
                for ability_definition in ability_definitions
                if ability_definition.ability_key == DEFAULT_STARTER_ABILITY_KEY
            ),
            None,
        )
        if starter_ability is not None:
            db.add(
                CharacterAbility(
                    character_id=character_id,
                    ability_key=starter_ability.ability_key,
                )
            )

    if has_loadout is None:
        unlocked_abilities = list(
            db.scalars(
                select(CharacterAbility)
                .join(CharacterAbility.ability)
                .where(
                    CharacterAbility.character_id == character_id,
                    CharacterAbility.unlocked.is_(True),
                )
                .order_by(AbilityDefinition.id)
            ).all()
        )
        for slot_index, ability in enumerate(unlocked_abilities[:MAX_LOADOUT_ENTRIES]):
            db.add(
                CharacterAbilityLoadout(
                    character_id=character_id,
                    slot_index=slot_index,
                    ability_key=ability.ability_key,
                    enabled=True,
                )
            )

    db.commit()


def _character_abilities_response(character_id: int, db: Session) -> CharacterAbilitiesResponse:
    abilities = list(
        db.scalars(
            select(CharacterAbility)
            .options(
                selectinload(CharacterAbility.ability).selectinload(
                    AbilityDefinition.effects
                )
            )
            .where(
                CharacterAbility.character_id == character_id,
                CharacterAbility.unlocked.is_(True),
            )
            .join(CharacterAbility.ability)
            .order_by(AbilityDefinition.id)
        ).all()
    )
    loadout = list(
        db.scalars(
            select(CharacterAbilityLoadout)
            .where(CharacterAbilityLoadout.character_id == character_id)
            .order_by(CharacterAbilityLoadout.slot_index)
        ).all()
    )

    return CharacterAbilitiesResponse(
        character_id=character_id,
        unlocked_abilities=[
            CharacterAbilityResponse(
                ability_key=ability.ability_key,
                unlocked=ability.unlocked,
                ability_level=ability.ability_level,
                ability_xp=ability.ability_xp,
                definition=ability.ability,
            )
            for ability in abilities
        ],
        loadout=[AbilityLoadoutEntry.model_validate(entry) for entry in loadout],
    )


def _validate_loadout(character_id: int, loadout: list[AbilityLoadoutEntry], db: Session) -> None:
    if len(loadout) > MAX_LOADOUT_ENTRIES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Loadout can contain at most 5 entries.",
        )

    slot_indexes = [entry.slot_index for entry in loadout]
    if any(
        slot_index < 0 or slot_index >= MAX_LOADOUT_ENTRIES
        for slot_index in slot_indexes
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="slot_index must be between 0 and 4.",
        )
    if len(set(slot_indexes)) != len(slot_indexes):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Loadout cannot contain duplicate slot_index values.",
        )

    ability_keys = [entry.ability_key for entry in loadout]
    if len(set(ability_keys)) != len(ability_keys):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Loadout cannot contain duplicate ability_key values.",
        )

    requested_ability_keys = set(ability_keys)
    existing_ability_keys = set(
        db.scalars(
            select(AbilityDefinition.ability_key).where(
                AbilityDefinition.ability_key.in_(requested_ability_keys)
            )
        ).all()
    )
    missing_ability_keys = requested_ability_keys - existing_ability_keys
    if missing_ability_keys:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown ability_key: {sorted(missing_ability_keys)[0]}.",
        )

    unlocked_ability_keys = set(
        db.scalars(
            select(CharacterAbility.ability_key).where(
                CharacterAbility.character_id == character_id,
                CharacterAbility.unlocked.is_(True),
                CharacterAbility.ability_key.in_(requested_ability_keys),
            )
        ).all()
    )
    locked_ability_keys = requested_ability_keys - unlocked_ability_keys
    if locked_ability_keys:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Ability is not unlocked for this character: {sorted(locked_ability_keys)[0]}.",
        )


@router.get("", response_model=list[CharacterResponse])
def list_characters(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Character]:
    return list(db.scalars(select(Character).where(Character.user_id == current_user.id)).all())


@router.post("", response_model=CharacterResponse, status_code=status.HTTP_201_CREATED)
def create_character(
    payload: CharacterCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Character:
    starter_ability = _get_starter_ability_definition(payload.starter_ability_key, db)
    character = Character(name=payload.name, user_id=current_user.id)
    db.add(character)
    db.flush()
    _grant_starter_ability(character.id, starter_ability, db)
    db.commit()
    db.refresh(character)
    return character


@router.get("/{character_id}", response_model=CharacterResponse)
def get_character(
    character_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Character:
    character = db.scalar(
        select(Character).where(
            Character.id == character_id,
            Character.user_id == current_user.id,
        )
    )
    if character is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Character not found.",
        )

    return character


@router.get("/{character_id}/abilities", response_model=CharacterAbilitiesResponse)
def get_character_abilities(
    character_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterAbilitiesResponse:
    character = _get_owned_character(character_id, current_user.id, db)
    _ensure_starter_abilities(character.id, db)

    return _character_abilities_response(character.id, db)


@router.post("/{character_id}/abilities/{ability_key}/unlock", response_model=CharacterAbilitiesResponse)
def unlock_character_ability(
    character_id: int,
    ability_key: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterAbilitiesResponse:
    character = _get_owned_character(character_id, current_user.id, db)
    ability_definition = _get_ability_definition(ability_key, db)
    _unlock_character_ability(character.id, ability_definition, db)
    db.commit()

    return _character_abilities_response(character.id, db)


@router.put("/{character_id}/ability-loadout", response_model=CharacterAbilitiesResponse)
def update_character_ability_loadout(
    character_id: int,
    payload: AbilityLoadoutUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterAbilitiesResponse:
    character = _get_owned_character(character_id, current_user.id, db)
    _ensure_starter_abilities(character.id, db)
    _validate_loadout(character.id, payload.loadout, db)

    db.execute(
        delete(CharacterAbilityLoadout).where(
            CharacterAbilityLoadout.character_id == character.id
        )
    )
    for entry in payload.loadout:
        db.add(
            CharacterAbilityLoadout(
                character_id=character.id,
                slot_index=entry.slot_index,
                ability_key=entry.ability_key,
                enabled=entry.enabled,
            )
        )

    db.commit()

    return _character_abilities_response(character.id, db)
