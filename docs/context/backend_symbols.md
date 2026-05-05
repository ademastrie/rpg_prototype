# Backend Symbol Summary

## App/Core

- `backend/app/main.py`: FastAPI app and health endpoint.
- `backend/app/config.py`: `Settings` model for environment-backed configuration.
- `backend/app/db.py`: `get_db()` SQLAlchemy session dependency.

## Auth

- `backend/app/auth/router.py`: `register`, `login`, `me` endpoints.
- `backend/app/auth/security.py`: password hashing/verification and JWT create/decode helpers.
- `backend/app/auth/dependencies.py`: `get_current_user` dependency.
- `backend/app/auth/schemas.py`: auth request/user/token Pydantic schemas.

## Characters / Progression / Abilities

- `backend/app/characters/router.py`: character list/create/get, XP award, ability list/unlock, loadout update.
- Important helpers: owned-character lookup, XP-to-next formula, starter ability grant, starter ability backfill, active ability definitions, ability lookup, unlock, loadout validation, response shaping.
- `backend/app/characters/schemas.py`: character/progression/ability/loadout Pydantic schemas.

## Game Server API

- `backend/app/game/router.py`: endpoints intended for Godot server use.
- Main responsibilities: validate join/session ownership and save character position.

## Models

- `backend/app/models/user.py`: user model.
- `backend/app/models/character.py`: character model with progression/position fields.
- `backend/app/models/ability.py`: ability definitions, effects, character unlocks, character loadout.
- `backend/app/models/base.py`: declarative base.
