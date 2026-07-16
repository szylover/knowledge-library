$ErrorActionPreference = 'Stop'

$volumeRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $volumeRoot '.build'
$tectonic = 'D:\projects\tools\tectonic\tectonic.exe'

if (-not (Test-Path -LiteralPath $tectonic)) {
    $tectonic = (Get-Command tectonic -ErrorAction Stop).Source
}

Push-Location $volumeRoot
try {
    Remove-Item -LiteralPath $buildDirectory -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
    & $tectonic -X compile --outdir $buildDirectory main.tex
    if ($LASTEXITCODE -ne 0) {
        throw "Tectonic compilation failed with exit code $LASTEXITCODE."
    }
    Write-Output "Built local validation PDF: $(Join-Path $buildDirectory 'main.pdf')"
}
finally {
    Pop-Location
}
