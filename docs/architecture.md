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

See [Networking](networking.md), [Ability Model](ability_model.md), and [Backend Data Model](backend_data_model.md) for focused details.
