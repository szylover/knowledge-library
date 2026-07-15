$ErrorActionPreference = 'Stop'
$volumeRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (& git -C $volumeRoot rev-parse --show-toplevel).Trim()
$output = Join-Path $repositoryRoot 'pdf\china-chronicle\vol01-zhou-qin.pdf'

Push-Location $volumeRoot
try {
    & 'D:\projects\tools\tectonic\tectonic.exe' -X compile main.tex
    if ($LASTEXITCODE -ne 0) {
        throw "Tectonic compilation failed with exit code $LASTEXITCODE."
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
    Copy-Item -LiteralPath 'main.pdf' -Destination $output -Force
    Write-Output "Published: $output"
}
finally {
    Pop-Location
}
