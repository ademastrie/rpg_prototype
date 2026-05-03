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

## Join Sync

- Join sync must be read-only serialization of current server state.
- Join sync must not reset live enemy or player simulation state, including positions, HP, alive/dead state, idle/chase state, aggro state, cooldowns, or respawn timers.
- Targeted sync to a joining peer should use targeted RPCs, such as `rpc_id(peer_id, ...)`, and should not broadcast full world state to existing peers.
- Client display RPCs should no-op on the server or otherwise avoid mutating server simulation.
