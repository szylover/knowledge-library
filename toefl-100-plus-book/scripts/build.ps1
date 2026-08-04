param(
    [switch]$AllowShort
)

$ErrorActionPreference = 'Stop'

$bookRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $bookRoot -Parent
$sourceDir = Join-Path $bookRoot 'book'
$latexDir = Join-Path $bookRoot 'latex'
$pdfDir = Join-Path $repoRoot 'pdf'
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

$allChapters = Get-ChildItem $sourceDir -Filter '*.md' -File | Sort-Object Name
$mainChapters = $allChapters |
    Where-Object { $_.BaseName -match '^(0[0-9]|1[0-9])-' } |
    ForEach-Object FullName
$printableChapters = $allChapters |
    Where-Object { $_.BaseName -match '^20-' } |
    ForEach-Object FullName
$completeChapters = $allChapters | ForEach-Object FullName

if (-not $printableChapters) {
    throw 'Printable source book/20-*.md was not found.'
}

function Invoke-BookBuild {
    param(
        [string[]]$Chapters,
        [string]$MetadataFile,
        [string]$BaseName
    )

    & $pandoc @Chapters `
        --metadata-file=$MetadataFile `
        --lua-filter='table-widths.lua' `
        --lua-filter='printable-page-breaks.lua' `
        --top-level-division=chapter `
        --standalone `
        --from='gfm+hard_line_breaks' `
        --to=latex `
        --output="$BaseName.tex"

    if ($LASTEXITCODE -ne 0) {
        throw "Pandoc failed while building $BaseName."
    }

    $windowsPathForWsl = $latexDir -replace '\\', '/'
    $wslLatexDir = (wsl.exe wslpath -a $windowsPathForWsl).Trim()
    wsl.exe bash -lc "cd '$wslLatexDir' && latexmk -xelatex -interaction=nonstopmode -halt-on-error '$BaseName.tex'"

    if ($LASTEXITCODE -ne 0) {
        throw "XeLaTeX failed while building $BaseName."
    }

    Copy-Item "$BaseName.pdf" (Join-Path $pdfDir "$BaseName.pdf") -Force
}

function Get-PdfPages {
    param([string]$PdfPath)

    $windowsPathForWsl = $PdfPath -replace '\\', '/'
    $wslPdf = (wsl.exe wslpath -a $windowsPathForWsl).Trim()
    $info = wsl.exe bash -lc "pdfinfo '$wslPdf'"
    $pagesLine = $info | Where-Object { $_ -match '^Pages:\s+(\d+)$' }

    if (-not $pagesLine) {
        throw "Could not read page count from $PdfPath."
    }

    return [int]([regex]::Match($pagesLine, '\d+').Value)
}

Push-Location $latexDir
try {
    Invoke-BookBuild $mainChapters 'metadata.yaml' 'toefl-100-plus-book'
    Invoke-BookBuild $printableChapters 'metadata-printables.yaml' 'toefl-100-plus-printables'
    Invoke-BookBuild $completeChapters 'metadata-complete.yaml' 'toefl-100-plus-complete'
}
finally {
    Pop-Location
}

$mainPdf = Join-Path $pdfDir 'toefl-100-plus-book.pdf'
$printablesPdf = Join-Path $pdfDir 'toefl-100-plus-printables.pdf'
$completePdf = Join-Path $pdfDir 'toefl-100-plus-complete.pdf'
$mainPages = Get-PdfPages $mainPdf
$printablePages = Get-PdfPages $printablesPdf
$completePages = Get-PdfPages $completePdf

Write-Host "Main textbook: $mainPages pages"
Write-Host "Printables: $printablePages pages"
Write-Host "Complete edition: $completePages pages"

if (-not $AllowShort -and $mainPages -lt 750) {
    throw "Main textbook is $mainPages pages; at least 750 substantive pages are required."
}

& (Join-Path $PSScriptRoot 'validate-book.ps1') -AllowShort:$AllowShort
if ($LASTEXITCODE -ne 0) {
    throw 'Book validation failed.'
}
