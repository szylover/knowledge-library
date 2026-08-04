param(
    [switch]$AllowShort
)

$ErrorActionPreference = 'Stop'

$bookRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $bookRoot -Parent
$sourceDir = Join-Path $bookRoot 'book'
$latexDir = Join-Path $bookRoot 'latex'
$requiredFiles = @(
    '00-使用说明与诊断.md',
    '01-24周总学习路线.md',
    '02-词汇语法与发音基础.md',
    '03-阅读完整教程.md',
    '04-听力完整教程.md',
    '05-写作完整教程.md',
    '06-口语完整教程.md',
    '07-阶段测验与完整模考.md',
    '08-答案解析评分量表.md',
    '09-错题本复盘表与打卡表.md',
    '10-资料来源与更新说明.md',
    '11-Sapiens辅助阅读与迁移训练.md',
    '12-ChatGPT口语陪练提示词与记录表.md',
    '13-词汇词形与语法分级题库.md',
    '14-阅读分级题库.md',
    '15-听力脚本与分级题库.md',
    '16-写作强化工作簿.md',
    '17-口语强化工作簿.md',
    '18-阶段卷与完整模考.md',
    '19-扩展题库答案与解析.md',
    '20-可打印答题纸与记录表.md'
)

$errors = [System.Collections.Generic.List[string]]::new()

foreach ($file in $requiredFiles) {
    $path = Join-Path $sourceDir $file
    if (-not (Test-Path $path)) {
        $errors.Add("Missing source file: $file")
        continue
    }

    $content = Get-Content $path
    $h1Count = @($content | Where-Object { $_ -match '^# ' }).Count
    if ($h1Count -ne 1) {
        $errors.Add("$file has $h1Count top-level headings; exactly one is required.")
    }

    if ($content -match '(?i)\b(TODO|TBD|PLACEHOLDER)\b|待补|占位') {
        $errors.Add("$file contains TODO/TBD/placeholder text.")
    }
}

$newSources = Get-ChildItem $sourceDir -Filter '*.md' -File |
    Where-Object { $_.BaseName -match '^1[3-9]-' }
foreach ($source in $newSources) {
    $duplicates = Get-Content $source.FullName |
        Where-Object { $_.Length -ge 60 -and $_ -notmatch '^\s*[#>|-]' } |
        Group-Object |
        Where-Object Count -gt 2

    foreach ($duplicate in $duplicates) {
        $errors.Add("$($source.Name) repeats a long content line $($duplicate.Count) times: $($duplicate.Name.Substring(0, [Math]::Min(80, $duplicate.Name.Length)))")
    }
}

$pdfRequirements = @(
    @{ Name = 'toefl-100-plus-book.pdf'; Minimum = 750; Maximum = $null },
    @{ Name = 'toefl-100-plus-printables.pdf'; Minimum = 50; Maximum = 100 },
    @{ Name = 'toefl-100-plus-complete.pdf'; Minimum = 751; Maximum = $null }
)

$pdfPages = @{}

foreach ($requirement in $pdfRequirements) {
    $pdf = Join-Path $repoRoot "pdf\$($requirement.Name)"
    if (-not (Test-Path $pdf)) {
        $errors.Add("Missing PDF: $($requirement.Name)")
        continue
    }

    $windowsPathForWsl = $pdf -replace '\\', '/'
    $wslPdf = (wsl.exe wslpath -a $windowsPathForWsl).Trim()
    $info = wsl.exe bash -lc "pdfinfo '$wslPdf'"
    $infoText = $info -join "`n"
    $pagesLine = $info | Where-Object { $_ -match '^Pages:\s+(\d+)$' }
    if (-not $pagesLine) {
        $errors.Add("Could not read the page count of $($requirement.Name).")
        continue
    }
    $pages = [int]([regex]::Match($pagesLine, '\d+').Value)
    $pdfPages[$requirement.Name] = $pages

    if (-not ($AllowShort -and $requirement.Name -eq 'toefl-100-plus-book.pdf') -and $pages -lt $requirement.Minimum) {
        $errors.Add("$($requirement.Name) has $pages pages; minimum is $($requirement.Minimum).")
    }
    if ($requirement.Maximum -and $pages -gt $requirement.Maximum) {
        $errors.Add("$($requirement.Name) has $pages pages; maximum is $($requirement.Maximum).")
    }

    if ($infoText -notmatch '(?m)^Page size:\s+595\.2\d x 841\.8\d pts \(A4\)$') {
        $errors.Add("$($requirement.Name) is not A4 according to pdfinfo.")
    }
    if ($infoText -match '(?m)^Encrypted:\s+yes$') {
        $errors.Add("$($requirement.Name) is encrypted and cannot be verified for printing.")
    }

    $textCheck = wsl.exe bash -lc "pdftotext '$wslPdf' - | grep -q '[^[:space:]]'"
    if ($LASTEXITCODE -ne 0) {
        $errors.Add("$($requirement.Name) has no searchable text.")
    }

    $bookmarks = wsl.exe bash -lc "mutool show '$wslPdf' outline"
    if ($LASTEXITCODE -ne 0 -or -not ($bookmarks | Where-Object { $_ -match 'nameddest=' })) {
        $errors.Add("$($requirement.Name) has no readable PDF bookmarks.")
    }
}

if ($pdfPages.ContainsKey('toefl-100-plus-book.pdf') -and
    $pdfPages.ContainsKey('toefl-100-plus-complete.pdf') -and
    $pdfPages['toefl-100-plus-complete.pdf'] -le $pdfPages['toefl-100-plus-book.pdf']) {
    $errors.Add('toefl-100-plus-complete.pdf must have more pages than the main textbook.')
}

$latexOutputs = @(
    'toefl-100-plus-book',
    'toefl-100-plus-printables',
    'toefl-100-plus-complete'
)

foreach ($output in $latexOutputs) {
    $log = Join-Path $latexDir "$output.log"
    if (-not (Test-Path $log)) {
        $errors.Add("Missing XeLaTeX log: $output.log")
        continue
    }

    $layoutDiagnostics = Select-String -Path $log -Pattern '^(Overfull \\hbox|! )|LaTeX Error:|Undefined control sequence|Emergency stop|Missing character:'
    foreach ($diagnostic in $layoutDiagnostics) {
        $errors.Add("$output.log: $($diagnostic.Line)")
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { [Console]::Error.WriteLine($_) }
    exit 1
}

Write-Host 'All source, PDF page, searchable-text, bookmark, A4, and XeLaTeX layout gates passed.'
