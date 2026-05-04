# AGENTS.md

## Project Map

This is a learning prototype for a persistent-feeling online action RPG in Godot.

Read deeper docs as needed:
- [Architecture](docs/architecture.md)
- [Networking](docs/networking.md)
- [Ability Model](docs/ability_model.md)
- [Backend Data Model](docs/backend_data_model.md)
- [Testing](docs/testing.md)

## Critical Rules

- Backend/PostgreSQL owns durable state and persistent character data.
- Godot dedicated server owns live simulation.
- Client owns visuals, input, and UI only.
- Enemies, combat, HP, cooldowns, abilities, damage/healing, and respawn are server-authoritative.
- Join sync must be read-only and must not reset live simulation state.
- Current hardcoded Godot ability/enemy definitions are temporary prototype definitions.
- Do not modify `backend/.env` or `backend/.venv`.
- Make small, reviewable changes. Do not rewrite architecture without explicit approval.
