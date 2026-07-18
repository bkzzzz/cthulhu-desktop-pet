$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$godotExe = Join-Path (Split-Path -Parent $projectDir) 'godot.windows.editor.x86_64.exe'
$testLog = Join-Path ([System.IO.Path]::GetTempPath()) 'cthulu-godot-tests.log'

if (-not (Test-Path -LiteralPath $godotExe -PathType Leaf)) {
    Write-Error "Godot executable was not found: $godotExe"
    exit 1
}

$process = Start-Process -FilePath $godotExe `
    -ArgumentList @('--headless', '--path', $projectDir, '--log-file', $testLog, '--script', 'res://tests/run_tests.gd') `
    -WindowStyle Hidden -Wait -PassThru
$logText = Get-Content -LiteralPath $testLog -Raw
Write-Output $logText
if ($process.ExitCode -ne 0 -or $logText -match 'SCRIPT ERROR|FAIL:') {
    exit 1
}
exit 0
