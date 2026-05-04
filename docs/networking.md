# Networking Notes

## Authority

- Godot dedicated server owns live gameplay simulation.
- Client owns visuals, input, and UI only.
- Clients send intent, not final authoritative results.
- Enemy AI, enemy HP, player HP, damage/healing, ability execution, cooldowns, active effects, and respawn are server-authoritative.

## Join Sync

- Join sync is read-only serialization of current server state.
- Join sync must not reset live enemy or player simulation state, including positions, HP, alive/dead state, idle/chase state, aggro state, cooldowns, active effects, or respawn timers.
- Targeted sync to a joining peer should use targeted RPCs, such as `rpc_id(peer_id, ...)`, and should not broadcast full world state to existing peers.
- Client display RPCs should no-op on the server or otherwise avoid mutating server simulation.
