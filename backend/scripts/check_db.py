import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError


BACKEND_DIR = Path(__file__).resolve().parents[1]


def main() -> int:
    load_dotenv(BACKEND_DIR / ".env")

    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("Database check failed: DATABASE_URL is not set in backend/.env.")
        return 1

    try:
        engine = create_engine(database_url)
        with engine.connect() as connection:
            version = connection.execute(text("SELECT version()")).scalar_one()
    except SQLAlchemyError as exc:
        print(f"Database check failed: {exc}")
        return 1

    print(f"Database check succeeded: {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
