# RPG Prototype

## Backend

Set up the Windows development environment:

```powershell
.\backend\scripts\setup_dev.ps1
```

Or from `backend/`:

```powershell
.\scripts\setup_dev.ps1
```

From `backend/`:

```powershell
.\.venv\Scripts\activate
uvicorn app.main:app --reload
```

Check the PostgreSQL connection:

```powershell
python .\scripts\check_db.py
```

Create, apply, and inspect database migrations:

```powershell
alembic revision --autogenerate -m "message"
alembic upgrade head
alembic current
```
