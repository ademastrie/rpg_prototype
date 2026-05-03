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

Or launch the backend from anywhere:

```powershell
.\scripts\run_backend.ps1
```

Launch the Godot server and client scenes:

```powershell
.\godot\scripts\dev\run_server.ps1 -GodotExe "C:\path\to\godot.exe"
.\godot\scripts\dev\run_client.ps1 -GodotExe "C:\path\to\godot.exe"
```

You can also set `GODOT_EXE` instead of passing `-GodotExe`.

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
