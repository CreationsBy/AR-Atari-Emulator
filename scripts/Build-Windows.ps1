param([int]$Jobs = 3)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Windows-Helpers.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$pythonPath = Find-ProjectPython
Set-Location -LiteralPath $projectRoot
$compilerPath = Join-Path $projectRoot '.tools\zig-windows-x86_64-0.13.0\zig.exe'
if (-not (Test-Path -LiteralPath $compilerPath)) {
    $toolsPath = Join-Path $projectRoot '.tools'
    New-Item -ItemType Directory -Path $toolsPath -Force | Out-Null
    $archivePath = Join-Path $toolsPath 'zig.zip'
    Write-Output 'Downloading the official portable Zig 0.13 compiler (about 80 MB).'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri 'https://ziglang.org/download/0.13.0/zig-windows-x86_64-0.13.0.zip' -OutFile $archivePath
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne 'd859994725ef9402381e557c60bb57497215682e355204d754ee3df75ee3c158') {
        throw 'Compiler archive checksum mismatch. Extraction stopped.'
    }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $toolsPath -Force
}
& $pythonPath scripts/verify_vendor.py
if ($LASTEXITCODE -ne 0) { throw 'Vendor verification failed.' }
& $pythonPath scripts/assemble_homebrew.py
if ($LASTEXITCODE -ne 0) { throw 'ROM assembly failed.' }
& $pythonPath scripts/build_native.py --zig $compilerPath --jobs $Jobs
if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
& $pythonPath -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) { throw 'Native tests failed.' }
