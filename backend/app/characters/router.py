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
    CharacterDeleteResponse,
    CharacterCurrencyAward,
    CharacterCurrencyResponse,
    CharacterEquipmentEntryResponse,
    CharacterEquipmentResponse,
    CharacterEquipmentUpdate,
    CharacterInventoryEntryResponse,
    CharacterInventoryItemAdd,
    CharacterInventoryResponse,
    CharacterProgressionResponse,
    CharacterResponse,
    CharacterXpAward,
)
from app.db import get_db
from app.models.ability import AbilityDefinition, CharacterAbility, CharacterAbilityLoadout
from app.models.character import Character
from app.models.item import CharacterEquipment, CharacterInventory, ItemDefinition
from app.models.user import User


router = APIRouter(prefix="/characters", tags=["characters"])
MAX_LOADOUT_ENTRIES = 5
DEFAULT_STARTER_ABILITY_KEY = "slash"
STARTER_ABILITY_KEYS = {"slash", "firebolt"}
VALID_EQUIPMENT_SLOTS = {"weapon", "head", "chest", "arms", "hands", "legs", "feet"}


def _xp_to_next_level(level: int) -> int:
    return max(level, 1) * 100


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


def _character_progression_response(character: Character) -> CharacterProgressionResponse:
    return CharacterProgressionResponse(
        character_id=character.id,
        level=character.level,
        xp=character.xp,
        xp_to_next=_xp_to_next_level(character.level),
    )


def _character_currency_response(character: Character) -> CharacterCurrencyResponse:
    return CharacterCurrencyResponse(
        character_id=character.id,
        gold=character.gold,
    )


def _character_inventory_response(character_id: int, db: Session) -> CharacterInventoryResponse:
    equipped_inventory_entry_ids = set(
        db.scalars(
            select(CharacterEquipment.inventory_entry_id).where(
                CharacterEquipment.character_id == character_id,
                CharacterEquipment.inventory_entry_id.is_not(None),
            )
        ).all()
    )
    inventory_entries = list(
        db.scalars(
            select(CharacterInventory)
            .options(selectinload(CharacterInventory.item_definition))
            .join(CharacterInventory.item_definition)
            .where(CharacterInventory.character_id == character_id)
            .order_by(ItemDefinition.display_name, CharacterInventory.id)
        ).all()
    )

    return CharacterInventoryResponse(
        character_id=character_id,
        items=[
            CharacterInventoryEntryResponse(
                inventory_entry_id=entry.id,
                item_key=entry.item_key,
                display_name=entry.item_definition.display_name,
                item_type=entry.item_definition.item_type,
                equip_slot=entry.item_definition.equip_slot,
                stackable=entry.item_definition.stackable,
                quantity=entry.quantity,
                equipped=entry.id in equipped_inventory_entry_ids,
                definition=entry.item_definition,
            )
            for entry in inventory_entries
        ],
    )


def _character_equipment_response(character_id: int, db: Session) -> CharacterEquipmentResponse:
    equipment_entries = list(
        db.scalars(
            select(CharacterEquipment)
            .options(
                selectinload(CharacterEquipment.item_definition).selectinload(
                    ItemDefinition.stat_modifiers
                )
            )
            .join(CharacterEquipment.item_definition)
            .where(CharacterEquipment.character_id == character_id)
            .order_by(CharacterEquipment.equip_slot)
        ).all()
    )

    return CharacterEquipmentResponse(
        character_id=character_id,
        equipment=[
            CharacterEquipmentEntryResponse(
                equip_slot=entry.equip_slot,
                inventory_entry_id=entry.inventory_entry_id,
                item_key=entry.item_key,
                definition=entry.item_definition,
                stat_modifiers=entry.item_definition.stat_modifiers,
            )
            for entry in equipment_entries
        ],
    )


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


def _validate_equip_slot(equip_slot: str) -> str:
    equip_slot_text = equip_slot.strip()
    if equip_slot_text not in VALID_EQUIPMENT_SLOTS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"equip_slot must be one of: {', '.join(sorted(VALID_EQUIPMENT_SLOTS))}.",
        )

    return equip_slot_text


def _validate_equippable_inventory_entry(
    character_id: int,
    equip_slot: str,
    inventory_entry: CharacterInventory,
) -> ItemDefinition:
    item_definition = inventory_entry.item_definition
    if item_definition is None or not item_definition.is_active:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Inventory entry does not reference an active item.",
        )
    if item_definition.item_type != "equipment" or item_definition.equip_slot is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Item is not equippable: {inventory_entry.item_key}.",
        )
    if item_definition.equip_slot != equip_slot:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Item {inventory_entry.item_key} cannot be equipped in slot {equip_slot}.",
        )
    if inventory_entry.character_id != character_id or inventory_entry.quantity <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Inventory entry is not available for this character.",
        )

    return item_definition


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


@router.delete("/{character_id}", response_model=CharacterDeleteResponse)
def delete_character(
    character_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterDeleteResponse:
    character = _get_owned_character(character_id, current_user.id, db)

    db.execute(
        delete(CharacterEquipment).where(
            CharacterEquipment.character_id == character.id
        )
    )
    db.execute(
        delete(CharacterInventory).where(
            CharacterInventory.character_id == character.id
        )
    )
    db.execute(
        delete(CharacterAbilityLoadout).where(
            CharacterAbilityLoadout.character_id == character.id
        )
    )
    db.execute(
        delete(CharacterAbility).where(
            CharacterAbility.character_id == character.id
        )
    )
    db.delete(character)
    db.commit()

    return CharacterDeleteResponse(success=True, character_id=character_id)


@router.post("/{character_id}/xp", response_model=CharacterProgressionResponse)
def award_character_xp(
    character_id: int,
    payload: CharacterXpAward,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterProgressionResponse:
    if payload.xp_amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="xp_amount must be greater than 0.",
        )

    character = _get_owned_character(character_id, current_user.id, db)
    character.xp += payload.xp_amount
    while character.xp >= _xp_to_next_level(character.level):
        character.xp -= _xp_to_next_level(character.level)
        character.level += 1

    db.commit()
    db.refresh(character)

    return _character_progression_response(character)


@router.post("/{character_id}/currency", response_model=CharacterCurrencyResponse)
def award_character_currency(
    character_id: int,
    payload: CharacterCurrencyAward,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterCurrencyResponse:
    if payload.gold_amount < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="gold_amount cannot be negative.",
        )

    character = _get_owned_character(character_id, current_user.id, db)
    character.gold += payload.gold_amount

    db.commit()
    db.refresh(character)

    return _character_currency_response(character)


@router.get("/{character_id}/inventory", response_model=CharacterInventoryResponse)
def get_character_inventory(
    character_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterInventoryResponse:
    character = _get_owned_character(character_id, current_user.id, db)

    return _character_inventory_response(character.id, db)


@router.get("/{character_id}/equipment", response_model=CharacterEquipmentResponse)
def get_character_equipment(
    character_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterEquipmentResponse:
    character = _get_owned_character(character_id, current_user.id, db)

    return _character_equipment_response(character.id, db)


@router.put("/{character_id}/equipment", response_model=CharacterEquipmentResponse)
def update_character_equipment(
    character_id: int,
    payload: CharacterEquipmentUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterEquipmentResponse:
    character = _get_owned_character(character_id, current_user.id, db)
    equip_slot = _validate_equip_slot(payload.equip_slot)
    inventory_entry_id = payload.inventory_entry_id
    item_key = payload.item_key.strip() if payload.item_key is not None else ""

    equipment_entry = db.scalar(
        select(CharacterEquipment).where(
            CharacterEquipment.character_id == character.id,
            CharacterEquipment.equip_slot == equip_slot,
        )
    )

    if inventory_entry_id is None and item_key == "":
        if equipment_entry is not None:
            db.delete(equipment_entry)
            db.commit()
        return _character_equipment_response(character.id, db)

    inventory_entry: CharacterInventory | None = None
    if inventory_entry_id is not None:
        inventory_entry = db.scalar(
            select(CharacterInventory)
            .options(selectinload(CharacterInventory.item_definition))
            .where(
                CharacterInventory.id == inventory_entry_id,
                CharacterInventory.character_id == character.id,
                CharacterInventory.quantity > 0,
            )
        )
        if inventory_entry is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Inventory entry is not in this character's inventory: {inventory_entry_id}.",
            )
        item_definition = _validate_equippable_inventory_entry(
            character.id,
            equip_slot,
            inventory_entry,
        )
        if item_key != "" and item_key != item_definition.item_key:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="inventory_entry_id and item_key refer to different items.",
            )
    else:
        item_definition = db.scalar(
            select(ItemDefinition).where(
                ItemDefinition.item_key == item_key,
                ItemDefinition.is_active.is_(True),
            )
        )
        if item_definition is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Unknown or inactive item_key: {item_key}.",
            )
        if item_definition.item_type != "equipment" or item_definition.equip_slot is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Item is not equippable: {item_key}.",
            )
        if item_definition.equip_slot != equip_slot:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Item {item_key} cannot be equipped in slot {equip_slot}.",
            )

        equipped_inventory_entry_ids = set(
            db.scalars(
                select(CharacterEquipment.inventory_entry_id).where(
                    CharacterEquipment.character_id == character.id,
                    CharacterEquipment.inventory_entry_id.is_not(None),
                )
            ).all()
        )
        inventory_entries = list(
            db.scalars(
                select(CharacterInventory)
                .where(
                    CharacterInventory.character_id == character.id,
                    CharacterInventory.item_key == item_definition.item_key,
                    CharacterInventory.quantity > 0,
                )
                .order_by(CharacterInventory.id)
            ).all()
        )
        inventory_entry = next(
            (
                entry
                for entry in inventory_entries
                if entry.id not in equipped_inventory_entry_ids
                or (
                    equipment_entry is not None
                    and entry.id == equipment_entry.inventory_entry_id
                )
            ),
            None,
        )
        if inventory_entry is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Item is not in this character's inventory: {item_key}.",
            )

    if equipment_entry is None:
        db.add(
            CharacterEquipment(
                character_id=character.id,
                equip_slot=equip_slot,
                item_key=item_definition.item_key,
                inventory_entry_id=inventory_entry.id,
            )
        )
    else:
        equipment_entry.item_key = item_definition.item_key
        equipment_entry.inventory_entry_id = inventory_entry.id

    db.commit()

    return _character_equipment_response(character.id, db)


@router.post("/{character_id}/inventory/items", response_model=CharacterInventoryResponse)
def add_character_inventory_item(
    character_id: int,
    payload: CharacterInventoryItemAdd,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CharacterInventoryResponse:
    if payload.quantity <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="quantity must be greater than 0.",
        )

    character = _get_owned_character(character_id, current_user.id, db)
    item_key = payload.item_key.strip()
    item_definition = db.scalar(
        select(ItemDefinition).where(
            ItemDefinition.item_key == item_key,
            ItemDefinition.is_active.is_(True),
        )
    )
    if item_definition is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown or inactive item_key: {item_key}.",
        )

    if item_definition.stackable:
        inventory_entry = db.scalar(
            select(CharacterInventory).where(
                CharacterInventory.character_id == character.id,
                CharacterInventory.item_key == item_definition.item_key,
            )
        )
        if inventory_entry is None:
            db.add(
                CharacterInventory(
                    character_id=character.id,
                    item_key=item_definition.item_key,
                    quantity=min(payload.quantity, item_definition.max_stack),
                )
            )
        else:
            inventory_entry.quantity = min(
                inventory_entry.quantity + payload.quantity,
                item_definition.max_stack,
            )
    else:
        for _ in range(payload.quantity):
            db.add(
                CharacterInventory(
                    character_id=character.id,
                    item_key=item_definition.item_key,
                    quantity=1,
                )
            )

    db.commit()

    return _character_inventory_response(character.id, db)


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
