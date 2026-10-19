function Find-ProjectPython {
    foreach ($command in @('py', 'python')) {
        $candidate = Get-Command $command -ErrorAction SilentlyContinue
        if ($candidate -and $candidate.Source -notlike '*WindowsApps*') {
            return $candidate.Source
        }
    }
    $blenderRoot = Join-Path $env:ProgramFiles 'Blender Foundation'
    if (Test-Path -LiteralPath $blenderRoot) {
        $bundled = Get-ChildItem -Path (Join-Path $blenderRoot '*\*\python\bin\python.exe') -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($bundled) { return $bundled.FullName }
    }
    throw 'Install Python 3.12 or newer from python.org (with PATH enabled), then open a new terminal.'
}
