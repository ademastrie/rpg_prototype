from pydantic import BaseModel


class EnemyAttackResponse(BaseModel):
    attack_key: str
    attack_type: str
    damage: int
    range: float
    radius: float | None
    windup_seconds: float
    recovery_seconds: float
    cooldown_seconds: float
    visual_key: str | None

    model_config = {"from_attributes": True}


class EnemyLootEntryResponse(BaseModel):
    payload_type: str
    item_key: str | None
    min_quantity: int
    max_quantity: int
    drop_chance: float
    is_active: bool

    model_config = {"from_attributes": True}


class EnemyDefinitionResponse(BaseModel):
    enemy_key: str
    display_name: str
    description: str | None
    level: int
    max_hp: int
    move_speed: float
    xp_reward: int
    aggro_radius: float
    leash_radius: float | None
    visual_key: str | None
    is_active: bool
    attacks: list[EnemyAttackResponse]
    loot_entries: list[EnemyLootEntryResponse]

    model_config = {"from_attributes": True}
