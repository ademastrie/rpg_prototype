# AGENTS.md

## Project Rules

- Godot version: 4.5.
- Backend/PostgreSQL owns durable state and persistent character data.
- Godot dedicated server owns live simulation.
- Client owns visuals, input, and UI only.
- Enemies, combat, HP, cooldowns, abilities, damage/healing, and respawn are server-authoritative.
- Current hardcoded Godot ability/enemy definitions are temporary prototype definitions.
- Preserve the existing client/server/backend authority split.
- Make small, reviewable changes. Do not rewrite architecture without explicit approval.
- Do not modify `backend/.env` or `backend/.venv`.

## Environment / Verification

- Do not attempt to run Python, Godot, unit tests, migrations, servers, or game launches in this Codex environment.
- Use static review only: inspect code, check call flow, and reason about syntax/logic from the files provided.
- Do not end responses with generic test cases or manual test checklists.
- Only mention verification when a specific static-review concern remains or the user asks how to test something.
