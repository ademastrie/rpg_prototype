# Architecture Notes

## Authority Model

- FastAPI and PostgreSQL own durable definitions and persistent character state.
- PostgreSQL stores durable state only; it is not used for per-frame movement, combat, projectiles, enemy AI, or live simulation.
- The Godot dedicated server owns live simulation state.
- The Godot client owns visuals, input, and UI only.
- Clients send intent, such as movement, aim, combat toggles, and ability toggle requests. They do not send final authoritative results.

## Server-Authoritative Gameplay

- Enemy AI, enemy HP, player HP, damage, ability execution, cooldowns, and respawn are server-authoritative.
- Enemy and ability definitions that are currently hardcoded in Godot are temporary prototype structures.
- Those definitions should eventually be loaded from backend/database-backed durable definitions.

## Planned Persistent Gameplay Data

- Backend/PostgreSQL will eventually own durable gameplay definitions and persistent character state.
- Current Godot hardcoded ability definitions are temporary prototype definitions.
- Ability model: an ability is a trigger, a targeting shape, and one or more effects.
- Trigger examples: cooldown, periodic, continuous, passive.
- Targeting examples: self, aimed cone, aimed line, radius around self, ground area.
- Effect examples: damage, healing, health regen, defense boost, speed boost, stat modifier, aura effect.
- Auras are not only damage; aura-style abilities may apply damage, healing, regeneration, defense, movement speed, or other stat effects.
- Likely future tables: `ability_definitions`, `ability_effects`, `character_abilities`, `character_ability_loadout`, player/character stats, enemy definitions, region spawn rules, loot tables, gear/items, inventory/equipment.
- First implementation target: ability definitions/effects, character ability unlocks, and character ability loadout/enabled state.
- The Godot dedicated server still owns live simulation during a session: current HP, cooldowns, active effects, enemy simulation, hit detection, and damage/healing resolution.

## Join Sync

- Join sync must be read-only serialization of current server state.
- Join sync must not reset live enemy or player simulation state, including positions, HP, alive/dead state, idle/chase state, aggro state, cooldowns, or respawn timers.
- Targeted sync to a joining peer should use targeted RPCs, such as `rpc_id(peer_id, ...)`, and should not broadcast full world state to existing peers.
- Client display RPCs should no-op on the server or otherwise avoid mutating server simulation.
