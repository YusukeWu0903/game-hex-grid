param(
    [string]$GodotPath = '',
    [string]$EvidenceRoot = 'D:/Codex/visualizations/2026-11-25/hex-tactics-foundation',
    [switch]$HeadlessUI,
    [switch]$FullPlaythrough
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
$testNames = @('test_hex_rules','test_missions','test_rpg','test_rpg_simulation','test_world','test_pathfinding_heap','test_battle_rules','test_session','test_foundation','test_threat','test_ai_detour','test_ai_equivalence','test_save','test_preferences','test_resume_simulation','test_cinematic_lifecycle','test_ui','test_radial_ui','test_cinematic','test_foundation_ui','test_dialogs','test_world_ui')
if ($FullPlaythrough) { $testNames += 'test_playthrough_ui' }
if (-not $HeadlessUI) { $testNames += @('test_portraits','test_rpg_ui','test_mission_ui') }
foreach ($testName in $testNames) {
    $logPath = Join-Path $runDirectory ($testName + '.log')
    $engineArguments = @('--path', $PSScriptRoot, '--script', ('res://tests/' + $testName + '.gd'), '--log-file', $logPath)
    if ($testName -notin @('test_ui','test_radial_ui','test_cinematic','test_foundation_ui','test_dialogs','test_playthrough_ui','test_world_ui','test_portraits','test_rpg_ui','test_mission_ui') -or $HeadlessUI) { $engineArguments += '--headless' }
    else { $engineArguments += @('--resolution','1440x900','--position','100,50') }
    & $GodotPath @engineArguments
    $testExit = $LASTEXITCODE
    if ($testExit -ne 0) { throw "$testName failed with exit code $testExit" }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -match 'SCRIPT ERROR|ERROR:' -or $log -notmatch 'checks, 0 failures') { throw "$testName did not pass. Inspect $logPath" }
}
Write-Output "All suites passed. Evidence: $runDirectory"
