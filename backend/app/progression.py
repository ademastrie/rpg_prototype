from dataclasses import dataclass

from app.models.character import Character


@dataclass(frozen=True)
class XpAwardResult:
    character_id: int
    level: int
    current_xp: int
    xp_to_next_level: int
    xp_awarded: int
    levels_gained: int
    gained_levels: tuple[int, ...] = ()

    @property
    def leveled_up(self) -> bool:
        return self.levels_gained > 0


def xp_to_next_level(level: int) -> int:
    safe_level = max(level, 1)
    return 100 + ((safe_level - 1) * 75)


def level_delta_xp_multiplier(enemy_level: int, player_level: int) -> float:
    delta = enemy_level - player_level
    if delta >= 5:
        return 1.50
    if delta <= -5:
        return 0.00

    return {
        4: 1.40,
        3: 1.30,
        2: 1.20,
        1: 1.10,
        0: 1.00,
        -1: 0.85,
        -2: 0.65,
        -3: 0.40,
        -4: 0.20,
    }[delta]


def rounded_xp(value: float) -> int:
    return max(int(value + 0.5), 0)


def enemy_kill_xp_award(
    *,
    enemy_level: int,
    player_level: int,
    enemy_base_xp: int,
    region_xp_multiplier: float,
) -> int:
    multiplier = level_delta_xp_multiplier(enemy_level, player_level)
    return rounded_xp(enemy_base_xp * multiplier * region_xp_multiplier)


def apply_character_xp(character: Character, xp_awarded: int) -> XpAwardResult:
    awarded = max(int(xp_awarded), 0)
    character.level = max(character.level, 1)
    character.xp = max(character.xp, 0)
    starting_level = character.level

    if awarded == 0:
        return XpAwardResult(
            character_id=character.id,
            level=character.level,
            current_xp=character.xp,
            xp_to_next_level=xp_to_next_level(character.level),
            xp_awarded=0,
            levels_gained=0,
            gained_levels=(),
        )

    character.xp += awarded

    levels_gained = 0
    while character.xp >= xp_to_next_level(character.level):
        needed = xp_to_next_level(character.level)
        character.xp -= needed
        character.level += 1
        levels_gained += 1

    return XpAwardResult(
        character_id=character.id,
        level=character.level,
        current_xp=character.xp,
        xp_to_next_level=xp_to_next_level(character.level),
        xp_awarded=awarded,
        levels_gained=levels_gained,
        gained_levels=tuple(range(starting_level + 1, character.level + 1)),
    )
