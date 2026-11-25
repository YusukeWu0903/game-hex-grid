param([switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$enginePath = $env:GODOT_BIN
if (-not $enginePath) {
    $enginePath = Join-Path (Split-Path -Parent $projectDirectory) 'Godot_v4.6.3-stable_win64.exe'
}
if (-not (Test-Path -LiteralPath $enginePath)) {
    throw 'Godot was not found. Set GODOT_BIN to the Godot 4.6 executable, or open project.godot in Godot.'
}
$env:HEX_TACTICS_DATA_DIR = Join-Path $projectDirectory 'user_data'
New-Item -ItemType Directory -Path $env:HEX_TACTICS_DATA_DIR -Force | Out-Null
$logPath = Join-Path $env:HEX_TACTICS_DATA_DIR 'game.log'
# Start-Process joins native arguments; quote filesystem paths for spaces.
$gameArguments = @('--path', ('"' + $projectDirectory + '"'), '--log-file', ('"' + $logPath + '"'))
if ($SmokeTest) { $gameArguments += @('--headless', '--quit-after', '5') }
$launch = @{
    FilePath = $enginePath
    ArgumentList = $gameArguments
    Wait = $true
    PassThru = $true
    WindowStyle = if ($SmokeTest) { 'Hidden' } else { 'Normal' }
}
# The normal path is the interactive game the user explicitly launches.
$gameProcess = Start-Process @launch
if ($gameProcess.ExitCode -ne 0) { throw "Godot exited with code $($gameProcess.ExitCode)" }
