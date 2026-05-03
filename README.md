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
