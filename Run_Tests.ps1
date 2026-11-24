param(
    [string]$GodotPath = '',
    [string]$EvidenceRoot = 'D:/Codex/visualizations/2026-11-25/hex-tactics-godot',
    [switch]$HeadlessUI
)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $GodotPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Godot_v4.6.3-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot executable not found.' }
$runDirectory = Join-Path $EvidenceRoot ('run-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$env:HEX_TACTICS_TEST_DIR = Join-Path $runDirectory 'evidence'
$env:HEX_TACTICS_DATA_DIR = Join-Path $runDirectory 'ui-data'
New-Item -ItemType Directory -Path $env:HEX_TACTICS_TEST_DIR -Force | Out-Null
foreach ($testName in @('test_hex_rules','test_battle_rules','test_session','test_ui')) {
    $logPath = Join-Path $runDirectory ($testName + '.log')
    $engineArguments = @('--path', $PSScriptRoot, '--script', ('res://tests/' + $testName + '.gd'), '--log-file', $logPath)
    if ($testName -ne 'test_ui' -or $HeadlessUI) { $engineArguments += '--headless' }
    else { $engineArguments += @('--resolution','1440x900','--position','100,50') }
    & $GodotPath @engineArguments
    $testExit = $LASTEXITCODE
    if ($testExit -ne 0) { throw "$testName failed with exit code $testExit" }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -match 'SCRIPT ERROR|ERROR:' -or $log -notmatch 'checks, 0 failures') { throw "$testName did not pass. Inspect $logPath" }
}
Write-Output "All suites passed. Evidence: $runDirectory"
