param([int]$Port = 8260)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Windows-Helpers.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$pythonPath = Find-ProjectPython
Set-Location -LiteralPath $projectRoot
if (-not (Test-Path -LiteralPath 'build\native-host\AtariDiorama.dll')) {
    throw 'Build the native library first with scripts\Build-Windows.ps1.'
}
Write-Output "Open http://127.0.0.1:$Port in your browser. Press Ctrl+C here to stop."
& $pythonPath scripts/preview_server.py --port $Port
if ($LASTEXITCODE -ne 0) { throw 'Preview exited with an error.' }
