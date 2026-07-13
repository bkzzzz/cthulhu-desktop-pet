[CmdletBinding()]
param(
    [switch]$Editor,
    [switch]$Headless,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArguments
)

$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$godotExe = Join-Path (Split-Path -Parent $projectDir) 'godot.windows.editor.x86_64.exe'

if (-not (Test-Path -LiteralPath $godotExe -PathType Leaf)) {
    Write-Error "Godot executable was not found: $godotExe"
    exit 1
}

$arguments = @('--path', $projectDir)
if ($Editor) {
    $arguments += '--editor'
}
if ($Headless) {
    $arguments += '--headless'
}
if ($GodotArguments) {
    $arguments += $GodotArguments
}

& $godotExe @arguments
exit $LASTEXITCODE
