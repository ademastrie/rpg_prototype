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
- `_get_owned_character(character_id: int, user_id: int, db: Session) -> Character:`
- `_character_progression_response(character: Character) -> CharacterProgressionResponse:`
- `_character_currency_response(character: Character) -> CharacterCurrencyResponse:`
- `_character_inventory_response(character_id: int, db: Session) -> CharacterInventoryResponse:`
- `_character_equipment_response(character_id: int, db: Session) -> CharacterEquipmentResponse:`
- `_active_ability_definitions(db: Session) -> list[AbilityDefinition]:`
- `_get_starter_ability_definition(ability_key: str, db: Session) -> AbilityDefinition:`
- `_get_starter_weapon_definition(`
- `_get_ability_definition(ability_key: str, db: Session) -> AbilityDefinition:`
- `_grant_starter_ability(`
- `_grant_starter_weapon(`
- `_unlock_character_ability(`
- `_ensure_starter_abilities(character_id: int, db: Session) -> None:`
- `_character_abilities_response(character_id: int, db: Session) -> CharacterAbilitiesResponse:`
- `_validate_loadout(character_id: int, loadout: list[AbilityLoadoutEntry], db: Session) -> None:`
- `_validate_equip_slot(equip_slot: str) -> str:`
- `_validate_equippable_inventory_entry(`
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
- `ItemStatModifierResponse`
- `ItemAbilityGrantResponse`
- `ItemDefinitionResponse`
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

## `backend/app/enemies/__init__.py`

### Classes
- None found

### Functions
- None found

### Routers
- None found

## `backend/app/enemies/router.py`

### Classes
- None found

### Functions
- `_enemy_definition_options() -> tuple:`
- `list_enemy_definitions(db: Session = Depends(get_db)) -> list[EnemyDefinition]:`
- `get_enemy_definition(`

### Routers
- `GET "", response_model=list[EnemyDefinitionResponse]`
- `GET "/{enemy_key}", response_model=EnemyDefinitionResponse`

## `backend/app/enemies/schemas.py`

### Classes
- `EnemyAttackResponse`
- `EnemyLootEntryResponse`
- `EnemyArchetypeSummaryResponse`
- `EnemyDefinitionResponse`

### Functions
- None found

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
- `AwardEnemyXpRequest`
- `AwardEnemyXpResponse`

### Functions
- `_resolve_enemy_definition(`
- `_resolve_region_definition(`
- `validate_join(`
- `save_position(`
- `award_enemy_xp(`

### Routers
- `POST "/validate-join", response_model=ValidateJoinResponse`
- `POST "/save-position", response_model=SavePositionResponse`
- `POST "/server/award-enemy-xp", response_model=AwardEnemyXpResponse`

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

## `backend/app/models/enemy.py`

### Classes
- `EnemyArchetype`
- `EnemyDefinition`
- `EnemyAttack`
- `EnemyLootEntry`

### Functions
- None found

### Routers
- None found

## `backend/app/models/item.py`

### Classes
- `ItemDefinition`
- `ItemStatModifier`
- `ItemAbilityGrant`
- `CharacterInventory`
- `CharacterEquipment`

### Functions
- None found

### Routers
- None found

## `backend/app/models/region.py`

### Classes
- `RegionDefinition`
- `RegionEnemySpawn`
- `RegionPatrolPath`
- `RegionPatrolPoint`

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

## `backend/app/progression.py`

### Classes
- `XpAwardResult`

### Functions
- `xp_to_next_level(level: int) -> int:`
- `level_delta_xp_multiplier(enemy_level: int, player_level: int) -> float:`
- `rounded_xp(value: float) -> int:`
- `enemy_kill_xp_award(`
- `apply_character_xp(character: Character, xp_awarded: int) -> XpAwardResult:`

### Routers
- None found

## `backend/app/regions/__init__.py`

### Classes
- None found

### Functions
- None found

### Routers
- None found

## `backend/app/regions/router.py`

### Classes
- None found

### Functions
- `_region_options() -> tuple:`
- `_get_active_region(region_key: str, db: Session) -> RegionDefinition:`
- `list_regions(db: Session = Depends(get_db)) -> list[RegionDefinition]:`
- `get_region(`
- `list_region_enemy_spawns(`
- `list_region_patrol_paths(`

### Routers
- `GET "", response_model=list[RegionDefinitionResponse]`
- `GET "/{region_key}", response_model=RegionDefinitionDetailResponse`
- `GET "/{region_key}/enemy-spawns", response_model=RegionEnemySpawnsResponse`
- `GET "/{region_key}/patrol-paths", response_model=RegionPatrolPathsResponse`

## `backend/app/regions/schemas.py`

### Classes
- `RegionEnemySpawnResponse`
- `RegionPatrolPointResponse`
- `RegionPatrolPathResponse`
- `RegionDefinitionResponse`
- `RegionDefinitionDetailResponse`
- `RegionEnemySpawnsResponse`
- `RegionPatrolPathsResponse`

### Functions
- None found

### Routers
- None found

## `backend/app/server_auth.py`

### Classes
- None found

### Functions
- `require_game_server_secret(x_game_server_secret: str = Header(default="")) -> None:`

### Routers
- None found

