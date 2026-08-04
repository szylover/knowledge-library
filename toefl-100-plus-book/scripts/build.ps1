$ErrorActionPreference = 'Stop'

$bookRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $bookRoot -Parent
$sourceDir = Join-Path $bookRoot 'book'
$latexDir = Join-Path $bookRoot 'latex'
$outputPdf = Join-Path $repoRoot 'pdf\toefl-100-plus-book.pdf'
$pandocCommand = Get-Command pandoc -ErrorAction SilentlyContinue
$pandoc = if ($pandocCommand) {
    $pandocCommand.Source
}
else {
    Join-Path $env:LOCALAPPDATA 'Pandoc\pandoc.exe'
}

if (-not (Test-Path $pandoc)) {
    throw 'Pandoc was not found. Install it with: winget install JohnMacFarlane.Pandoc'
}
$chapters = Get-ChildItem $sourceDir -Filter '*.md' -File |
    Sort-Object Name |
    ForEach-Object FullName

Push-Location $latexDir
try {
    & $pandoc @chapters `
        --metadata-file='metadata.yaml' `
        --lua-filter='table-widths.lua' `
        --top-level-division=chapter `
        --standalone `
        --from='gfm+hard_line_breaks' `
        --to=latex `
        --output='toefl-100-plus.tex'

    if ($LASTEXITCODE -ne 0) {
        throw "Pandoc failed with exit code $LASTEXITCODE."
    }

    $windowsPathForWsl = $latexDir -replace '\\', '/'
    $wslLatexDir = (wsl.exe wslpath -a $windowsPathForWsl).Trim()
    wsl.exe bash -lc "cd '$wslLatexDir' && latexmk -xelatex -interaction=nonstopmode -halt-on-error toefl-100-plus.tex"

    if ($LASTEXITCODE -ne 0) {
        throw "XeLaTeX failed with exit code $LASTEXITCODE."
    }

    Copy-Item 'toefl-100-plus.pdf' $outputPdf -Force
    Write-Host "Built $outputPdf"
}
finally {
    Pop-Location
}
