# Generated Backend Symbol Summary

## `backend/app/__init__.py`

### Classes
- None found

### Functions
- None found

### Routers
- None found

## `backend/app/auth/__init__.py`

### Classes
- None found

### Functions
- None found

### Routers
- None found

## `backend/app/auth/dependencies.py`

### Classes
- None found

### Functions
- `get_current_user(`

### Routers
- None found

## `backend/app/auth/router.py`

### Classes
- None found

### Functions
- `register(payload: AuthRequest, db: Session = Depends(get_db)) -> User:`
- `login(payload: AuthRequest, db: Session = Depends(get_db)) -> TokenResponse:`
- `me(current_user: User = Depends(get_current_user)) -> User:`

### Routers
- `POST "/register", response_model=UserResponse`
- `POST "/login", response_model=TokenResponse`
- `GET "/me", response_model=UserResponse`

## `backend/app/auth/schemas.py`

### Classes
- `AuthRequest`
- `UserResponse`
- `TokenResponse`

### Functions
- None found

### Routers
- None found

## `backend/app/auth/security.py`

### Classes
- None found

### Functions
- `hash_password(password: str) -> str:`
- `verify_password(plain_password: str, hashed_password: str) -> bool:`
- `create_access_token(subject: str) -> str:`
- `decode_access_token(token: str) -> dict[str, Any]:`

### Routers
- None found

## `backend/app/characters/__init__.py`

### Classes
- None found

### Functions
- None found

### Routers
- None found

## `backend/app/characters/router.py`

### Classes
- None found

### Functions
- `_xp_to_next_level(level: int) -> int:`
- `_get_owned_character(character_id: int, user_id: int, db: Session) -> Character:`
- `_character_progression_response(character: Character) -> CharacterProgressionResponse:`
- `_character_currency_response(character: Character) -> CharacterCurrencyResponse:`
- `_character_inventory_response(character_id: int, db: Session) -> CharacterInventoryResponse:`
- `_character_equipment_response(character_id: int, db: Session) -> CharacterEquipmentResponse:`
- `_active_ability_definitions(db: Session) -> list[AbilityDefinition]:`
- `_get_starter_ability_definition(ability_key: str, db: Session) -> AbilityDefinition:`
- `_get_ability_definition(ability_key: str, db: Session) -> AbilityDefinition:`
- `_grant_starter_ability(`
- `_unlock_character_ability(`
- `_ensure_starter_abilities(character_id: int, db: Session) -> None:`
- `_character_abilities_response(character_id: int, db: Session) -> CharacterAbilitiesResponse:`
- `_validate_loadout(character_id: int, loadout: list[AbilityLoadoutEntry], db: Session) -> None:`
- `_validate_equip_slot(equip_slot: str) -> str:`
- `list_characters(`
- `create_character(`
- `get_character(`
- `delete_character(`
- `award_character_xp(`
- `award_character_currency(`
- `get_character_inventory(`
- `get_character_equipment(`
- `update_character_equipment(`
- `add_character_inventory_item(`
- `get_character_abilities(`
- `unlock_character_ability(`
- `update_character_ability_loadout(`

### Routers
- `GET "", response_model=list[CharacterResponse]`
- `POST "", response_model=CharacterResponse, status_code=status.HTTP_201_CREATED`
- `GET "/{character_id}", response_model=CharacterResponse`
- `DELETE "/{character_id}", response_model=CharacterDeleteResponse`
- `POST "/{character_id}/xp", response_model=CharacterProgressionResponse`
- `POST "/{character_id}/currency", response_model=CharacterCurrencyResponse`
- `GET "/{character_id}/inventory", response_model=CharacterInventoryResponse`
- `GET "/{character_id}/equipment", response_model=CharacterEquipmentResponse`
- `PUT "/{character_id}/equipment", response_model=CharacterEquipmentResponse`
- `POST "/{character_id}/inventory/items", response_model=CharacterInventoryResponse`
- `GET "/{character_id}/abilities", response_model=CharacterAbilitiesResponse`
- `POST "/{character_id}/abilities/{ability_key}/unlock", response_model=CharacterAbilitiesResponse`
- `PUT "/{character_id}/ability-loadout", response_model=CharacterAbilitiesResponse`

## `backend/app/characters/schemas.py`

### Classes
- `CharacterCreate`
- `CharacterResponse`
- `CharacterDeleteResponse`
- `CharacterXpAward`
- `CharacterCurrencyAward`
- `CharacterProgressionResponse`
- `CharacterCurrencyResponse`
- `ItemDefinitionResponse`
- `ItemStatModifierResponse`
- `CharacterInventoryEntryResponse`
- `CharacterInventoryResponse`
- `CharacterInventoryItemAdd`
- `CharacterEquipmentUpdate`
- `CharacterEquipmentEntryResponse`
- `CharacterEquipmentResponse`
- `AbilityEffectResponse`
- `AbilityDefinitionResponse`
- `CharacterAbilityResponse`
- `AbilityLoadoutEntry`
- `CharacterAbilitiesResponse`
- `AbilityLoadoutUpdate`

### Functions
- None found

### Routers
- None found

## `backend/app/config.py`

### Classes
- `Settings`

### Functions
- None found

### Routers
- None found

## `backend/app/db.py`

### Classes
- None found

### Functions
- `get_db() -> Generator[Session, None, None]:`

### Routers
- None found

## `backend/app/game/__init__.py`

### Classes
- None found

### Functions
- None found

### Routers
- None found

## `backend/app/game/router.py`

### Classes
- `ValidateJoinRequest`
- `ValidateJoinResponse`
- `SavePositionRequest`
- `SavePositionResponse`

### Functions
- `validate_join(`
- `save_position(`

### Routers
- `POST "/validate-join", response_model=ValidateJoinResponse`
- `POST "/save-position", response_model=SavePositionResponse`

## `backend/app/main.py`

### Classes
- None found

### Functions
- `health() -> dict[str, str]:`

### Routers
- None found

## `backend/app/models/__init__.py`

### Classes
- None found

### Functions
- None found

### Routers
- None found

## `backend/app/models/ability.py`

### Classes
- `AbilityDefinition`
- `AbilityEffect`
- `CharacterAbility`
- `CharacterAbilityLoadout`

### Functions
- None found

### Routers
- None found

## `backend/app/models/base.py`

### Classes
- `Base`

### Functions
- None found

### Routers
- None found

## `backend/app/models/character.py`

### Classes
- `Character`

### Functions
- None found

### Routers
- None found

## `backend/app/models/item.py`

### Classes
- `ItemDefinition`
- `ItemStatModifier`
- `CharacterInventory`
- `CharacterEquipment`

### Functions
- None found

### Routers
- None found

## `backend/app/models/user.py`

### Classes
- `User`

### Functions
- None found

### Routers
- None found

