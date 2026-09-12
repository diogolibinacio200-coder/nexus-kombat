param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
& $enginePath --headless --path $projectRoot --editor --import --quit
foreach ($test in @('combat_test.gd','modules_test.gd','audio_test.gd','defense_test.gd','data_test.gd','flow_test.gd')) {
    & $enginePath --headless --path $projectRoot --script "res://tests/$test"
    if ($LASTEXITCODE -ne 0) { throw "Falha: $test" }
}
