import logging
from collections.abc import Iterable
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.ability import AbilityDefinition, CharacterAbility
from app.models.character import Character
from app.models.progression import LevelReward


logger = logging.getLogger(__name__)

LEVEL_REWARD_ABILITY_UNLOCK = "ability_unlock"


@dataclass(frozen=True)
class RewardApplicationResult:
    level_required: int
    reward_type: str
    reward_key: str
    already_owned: bool
    granted: bool


def apply_level_rewards(
    session: Session,
    character: Character,
    gained_levels: Iterable[int],
) -> list[RewardApplicationResult]:
    levels = sorted(set(gained_levels))
    if not levels:
        return []

    rewards = list(
        session.scalars(
            select(LevelReward)
            .where(
                LevelReward.level_required.in_(levels),
                LevelReward.is_active.is_(True),
            )
            .order_by(LevelReward.level_required, LevelReward.id)
        ).all()
    )

    results: list[RewardApplicationResult] = []
    for reward in rewards:
        if reward.reward_type == LEVEL_REWARD_ABILITY_UNLOCK:
            results.append(_apply_ability_unlock_reward(session, character, reward))
            continue

        logger.warning(
            "Ignoring unknown level reward type %r for character_id=%s level=%s reward_key=%r",
            reward.reward_type,
            character.id,
            reward.level_required,
            reward.reward_key,
        )
        results.append(
            RewardApplicationResult(
                level_required=reward.level_required,
                reward_type=reward.reward_type,
                reward_key=reward.reward_key,
                already_owned=False,
                granted=False,
            )
        )

    return results


def _apply_ability_unlock_reward(
    session: Session,
    character: Character,
    reward: LevelReward,
) -> RewardApplicationResult:
    ability_key = reward.reward_key
    ability_definition = session.scalar(
        select(AbilityDefinition).where(AbilityDefinition.ability_key == ability_key)
    )
    if ability_definition is None:
        logger.warning(
            "Ignoring level ability unlock with unknown ability_key=%r for character_id=%s level=%s",
            ability_key,
            character.id,
            reward.level_required,
        )
        return RewardApplicationResult(
            level_required=reward.level_required,
            reward_type=reward.reward_type,
            reward_key=ability_key,
            already_owned=False,
            granted=False,
        )

    character_ability = session.scalar(
        select(CharacterAbility).where(
            CharacterAbility.character_id == character.id,
            CharacterAbility.ability_key == ability_key,
        )
    )
    if character_ability is None:
        session.add(
            CharacterAbility(
                character_id=character.id,
                ability_key=ability_key,
                unlocked=True,
            )
        )
        return RewardApplicationResult(
            level_required=reward.level_required,
            reward_type=reward.reward_type,
            reward_key=ability_key,
            already_owned=False,
            granted=True,
        )

    already_owned = character_ability.unlocked
    character_ability.unlocked = True
    return RewardApplicationResult(
        level_required=reward.level_required,
        reward_type=reward.reward_type,
        reward_key=ability_key,
        already_owned=already_owned,
        granted=not already_owned,
    )
