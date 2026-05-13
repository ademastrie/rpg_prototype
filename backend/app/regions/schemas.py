from pydantic import BaseModel


class RegionEnemySpawnResponse(BaseModel):
    spawn_key: str
    region_key: str
    enemy_key: str
    enemy_display_name: str | None
    display_name: str | None
    spawn_type: str
    position_x: float
    position_y: float
    position_z: float
    spawn_radius: float
    max_alive: int
    respawn_seconds: float
    behavior_profile_key: str
    patrol_path_key: str | None
    leash_radius_override: float | None
    aggro_radius_override: float | None
    is_active: bool

    model_config = {"from_attributes": True}


class RegionPatrolPointResponse(BaseModel):
    point_order: int
    position_x: float
    position_y: float
    position_z: float
    wait_seconds: float

    model_config = {"from_attributes": True}


class RegionPatrolPathResponse(BaseModel):
    patrol_path_key: str
    display_name: str
    points: list[RegionPatrolPointResponse]

    model_config = {"from_attributes": True}


class RegionDefinitionResponse(BaseModel):
    region_key: str
    display_name: str
    description: str | None
    recommended_level_min: int
    recommended_level_max: int
    xp_multiplier: float
    is_active: bool

    model_config = {"from_attributes": True}


class RegionDefinitionDetailResponse(RegionDefinitionResponse):
    enemy_spawns: list[RegionEnemySpawnResponse]


class RegionEnemySpawnsResponse(RegionDefinitionResponse):
    enemy_spawns: list[RegionEnemySpawnResponse]


class RegionPatrolPathsResponse(RegionDefinitionResponse):
    patrol_paths: list[RegionPatrolPathResponse]
