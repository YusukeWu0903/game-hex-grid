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
$gameArguments = @('--path', $projectDirectory, '--log-file', (Join-Path $env:HEX_TACTICS_DATA_DIR 'game.log'))
if ($SmokeTest) { $gameArguments += @('--headless', '--quit-after', '5') }
& $enginePath @gameArguments
if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
