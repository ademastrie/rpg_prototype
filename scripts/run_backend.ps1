$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$BackendDir = Join-Path $RepoDir "backend"
$PythonExe = Join-Path $BackendDir ".venv\Scripts\python.exe"

if (-not (Test-Path $PythonExe)) {
    throw "Could not find backend virtualenv Python at $PythonExe. Run .\backend\scripts\setup_dev.ps1 first."
}

Push-Location $BackendDir
try {
    & $PythonExe -m uvicorn app.main:app --reload
}
finally {
    Pop-Location
}
