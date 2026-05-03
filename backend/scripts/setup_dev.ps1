$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$VenvDir = Join-Path $BackendDir ".venv"
$PythonExe = Join-Path $VenvDir "Scripts\python.exe"
$Requirements = Join-Path $BackendDir "requirements.txt"

if (-not (Test-Path $Requirements)) {
    throw "Could not find requirements.txt at $Requirements"
}

if (-not (Test-Path $PythonExe)) {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        py -3 -m venv $VenvDir
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        python -m venv $VenvDir
    }
    else {
        throw "Could not find Python. Install Python 3 and try again."
    }
}

& $PythonExe -m pip install --upgrade pip
& $PythonExe -m pip install -r $Requirements

Write-Host "Backend development environment is ready at $VenvDir"
