import sys
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app.config import settings  # noqa: E402


def main() -> int:
    if not settings.DATABASE_URL:
        print("Database check failed: DATABASE_URL is not set in backend/.env.")
        return 1

    try:
        from app.db import engine

        with engine.connect() as connection:
            version = connection.execute(text("SELECT version()")).scalar_one()
    except SQLAlchemyError as exc:
        print(f"Database check failed: {exc}")
        return 1
    except Exception as exc:
        print(f"Database check failed: {exc}")
        return 1

    print(f"Database check succeeded: {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
