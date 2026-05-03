from fastapi import FastAPI

from app.auth.router import router as auth_router
from app.characters.router import router as characters_router


app = FastAPI()
app.include_router(auth_router)
app.include_router(characters_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
