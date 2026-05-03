param(
    [string]$GodotExe = $env:GODOT_EXE
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    Write-Host "Missing Godot executable path. Example: .\godot\scripts\dev\run_client.ps1 -GodotExe 'C:\Tools\Godot\Godot_v4.5.exe'"
    Write-Host "Or set GODOT_EXE to the Godot executable path."
    exit 1
}

if (-not (Test-Path $GodotExe)) {
    Write-Host "Godot executable was not found at '$GodotExe'. Example: .\godot\scripts\dev\run_client.ps1 -GodotExe 'C:\Tools\Godot\Godot_v4.5.exe'"
    exit 1
}

$ScriptDir = $PSScriptRoot
$GodotDir = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path
$ScenePath = "res://scenes/client/login_character_select.tscn"

Push-Location $GodotDir
try {
    & $GodotExe --path $GodotDir $ScenePath
}
finally {
    Pop-Location
}
