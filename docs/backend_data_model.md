# Backend Data Model

Backend/PostgreSQL owns durable gameplay definitions and persistent character state.

## Planned Persistent Gameplay Data

- Ability definitions and effects
- Character ability unlocks
- Character ability loadout and enabled ability state
- Player/character stats
- Enemy definitions
- Region spawn rules
- Loot tables
- Gear/items
- Inventory/equipment

## First Implementation Target

- `ability_definitions`
- `ability_effects`
- `character_abilities`
- `character_ability_loadout`

PostgreSQL stores durable state only. It is not used for per-frame movement, combat, projectiles, enemy AI, or live simulation.
