$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'run_game.ps1'
& $launcher -Headless --script 'res://tests/run_tests.gd'
exit $LASTEXITCODE
