# RPG Prototype

## Backend

From `backend/`:

```powershell
.\.venv\Scripts\activate
uvicorn app.main:app --reload
```

Check the PostgreSQL connection:

```powershell
python .\scripts\check_db.py
```

Run database migrations:

```powershell
alembic revision --autogenerate -m "message"
alembic upgrade head
alembic current
```
