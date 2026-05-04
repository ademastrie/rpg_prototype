# Ability Model

Current Godot hardcoded ability definitions are temporary prototype definitions.

## Planned Shape

- Ability = trigger + targeting shape + one or more effects.
- Trigger examples: cooldown, periodic, continuous, passive.
- Targeting examples: self, aimed cone, aimed line, radius around self, ground area.
- Effect examples: damage, healing, health regen, defense boost, speed boost, stat modifier, aura effect.
- Auras are not only damage; aura-style abilities may apply damage, healing, regeneration, defense, movement speed, or other stat effects.

## Runtime Authority

- Backend/PostgreSQL will eventually own durable ability definitions and character unlock/loadout state.
- Godot server owns live ability execution, cooldowns, active effects, hit detection, and damage/healing resolution during a session.
