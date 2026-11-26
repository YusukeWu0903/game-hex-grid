param(
    [Parameter(Mandatory=$true)][string]$Template,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$GodotPath='D:/Project/Godot_v4.6.3-stable_win64_console.exe'
)
$ErrorActionPreference='Stop'
$templatePath=(Resolve-Path -LiteralPath $Template).Path.Replace('\','/')
$presetPath=Join-Path $PSScriptRoot 'export_presets.cfg'
$original=[IO.File]::ReadAllText($presetPath)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
try {
    [IO.File]::WriteAllText($presetPath,$original.Replace('custom_template/release=""','custom_template/release="'+$templatePath+'"'))
    & $GodotPath --headless --path $PSScriptRoot --export-release 'Windows Desktop' (Join-Path $OutputDirectory 'HexTactics.exe')
    if($LASTEXITCODE -ne 0) {throw 'Godot Windows export failed'}
} finally {
    [IO.File]::WriteAllText($presetPath,$original)
}
