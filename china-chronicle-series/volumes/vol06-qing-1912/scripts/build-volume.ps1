$ErrorActionPreference = 'Stop'

$volumeRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (& git -C $volumeRoot rev-parse --show-toplevel).Trim()
$output = Join-Path $repositoryRoot 'pdf\china-chronicle\vol06-qing-1912.pdf'
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

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
    Copy-Item -LiteralPath (Join-Path $buildDirectory 'main.pdf') -Destination $output -Force
    Write-Output "Published: $output"
}
finally {
    Remove-Item -LiteralPath $buildDirectory -Recurse -Force -ErrorAction SilentlyContinue
    Pop-Location
}
