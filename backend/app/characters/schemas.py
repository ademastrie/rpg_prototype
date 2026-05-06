from datetime import datetime

from pydantic import BaseModel


class CharacterCreate(BaseModel):
    name: str
    starter_ability_key: str = "slash"


class CharacterResponse(BaseModel):
    id: int
    user_id: int
    name: str
    level: int
    xp: int
    gold: int
    region_id: str
    position_x: float
    position_y: float
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class CharacterDeleteResponse(BaseModel):
    success: bool
    character_id: int


class CharacterXpAward(BaseModel):
    xp_amount: int


class CharacterCurrencyAward(BaseModel):
    gold_amount: int


class CharacterProgressionResponse(BaseModel):
    character_id: int
    level: int
    xp: int
    xp_to_next: int


class CharacterCurrencyResponse(BaseModel):
    character_id: int
    gold: int


class ItemDefinitionResponse(BaseModel):
    item_key: str
    display_name: str
    description: str | None
    item_type: str
    stackable: bool
    max_stack: int
    icon_key: str | None
    is_active: bool

    model_config = {"from_attributes": True}


class CharacterInventoryEntryResponse(BaseModel):
    item_key: str
    quantity: int
    definition: ItemDefinitionResponse


class CharacterInventoryResponse(BaseModel):
    character_id: int
    items: list[CharacterInventoryEntryResponse]


class CharacterInventoryItemAdd(BaseModel):
    item_key: str
    quantity: int


class AbilityEffectResponse(BaseModel):
    effect_type: str
    target_team: str
    stat_key: str | None
    value: float
    tick_interval_seconds: float | None
    duration_seconds: float | None

    model_config = {"from_attributes": True}


class AbilityDefinitionResponse(BaseModel):
    ability_key: str
    display_name: str
    description: str | None
    trigger_type: str
    targeting_type: str
    cooldown_seconds: float
    range: float | None
    radius: float | None
    visual_key: str | None
    is_active: bool
    effects: list[AbilityEffectResponse]

    model_config = {"from_attributes": True}


class CharacterAbilityResponse(BaseModel):
    ability_key: str
    unlocked: bool
    ability_level: int
    ability_xp: int
    definition: AbilityDefinitionResponse


class AbilityLoadoutEntry(BaseModel):
    slot_index: int
    ability_key: str
    enabled: bool

    model_config = {"from_attributes": True}


class CharacterAbilitiesResponse(BaseModel):
    character_id: int
    unlocked_abilities: list[CharacterAbilityResponse]
    loadout: list[AbilityLoadoutEntry]


class AbilityLoadoutUpdate(BaseModel):
    loadout: list[AbilityLoadoutEntry]
