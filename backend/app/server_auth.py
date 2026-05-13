from hmac import compare_digest

from fastapi import Header, HTTPException, status

from app.config import settings


def require_game_server_secret(x_game_server_secret: str = Header(default="")) -> None:
    configured_secret = settings.GAME_SERVER_SECRET
    if configured_secret == "":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Game server-only endpoints are not configured.",
        )

    if not compare_digest(x_game_server_secret, configured_secret):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid game server secret.",
        )
