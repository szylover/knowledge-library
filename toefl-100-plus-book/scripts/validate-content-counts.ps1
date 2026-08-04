$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bookRoot = Split-Path $PSScriptRoot -Parent
$sourceDir = Join-Path $bookRoot 'book'
$errors = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()

function Get-ChapterPath {
    param([int]$Number)

    $matches = @(Get-ChildItem -LiteralPath $sourceDir -Filter ('{0:D2}-*.md' -f $Number) -File)
    if ($matches.Count -ne 1) {
        throw "Expected exactly one source file for chapter $Number; found $($matches.Count)."
    }

    return $matches[0].FullName
}

function Get-NumberedItems {
    param(
        [string]$Path,
        [string]$Pattern
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $Path) {
        $lineNumber++
        $match = [regex]::Match($line, $Pattern)
        if ($match.Success) {
            $items.Add([pscustomobject]@{
                Number = [int]$match.Groups[1].Value
                Line = $line
                LineNumber = $lineNumber
            })
        }
    }

    return @($items)
}

function Test-ContinuousNumbers {
    param(
        [string]$Name,
        [object[]]$Items
    )

    if ($Items.Count -eq 0) {
        $errors.Add("$Name has no numbered items.")
        return
    }

    $duplicates = @($Items | Group-Object Number | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count -gt 0) {
        $errors.Add("$Name repeats number(s): $($duplicates -join ', ').")
    }

    $last = ($Items | Measure-Object -Property Number -Maximum).Maximum
    $present = @($Items.Number)
    $missing = @(1..$last | Where-Object { $_ -notin $present })
    if ($missing.Count -gt 0) {
        $errors.Add("$Name skips number(s): $($missing -join ', ').")
    }

    if ($Items.Count -ne $last) {
        $errors.Add("$Name has $($Items.Count) items but its last number is $last.")
    }
}

function Get-PrimaryStem {
    param(
        [string[]]$Lines,
        [int]$LineNumber,
        [ValidateSet('Current', 'NextNonBlank')]
        [string]$Mode
    )

    $index = $LineNumber - 1
    if ($Mode -eq 'NextNonBlank') {
        $index++
        while ($index -lt $Lines.Count -and [string]::IsNullOrWhiteSpace($Lines[$index])) {
            $index++
        }
    }

    if ($index -ge $Lines.Count) {
        return ''
    }

    return $Lines[$index]
}

function Normalize-Stem {
    param([string]$Stem)

    $normalized = $Stem -replace '(?i)\b(CTW|BAS|L&R|RDL|RAP|LCR|LT|BS|EC|AD|LR|INT)-\d{3}\b', '$1-###'
    $normalized = $normalized -replace '^\s*(?:[-*]|\d+\.)\s*', ''
    $normalized = $normalized -replace '\s+', ' '
    return $normalized.Trim()
}

function Test-DuplicatePrimaryStems {
    param(
        [string]$Name,
        [string]$Path,
        [object[]]$Items,
        [ValidateSet('Current', 'NextNonBlank')]
        [string]$Mode
    )

    $lines = @(Get-Content -LiteralPath $Path)
    $stems = foreach ($item in $Items) {
        [pscustomobject]@{
            Number = $item.Number
            Stem = Normalize-Stem (Get-PrimaryStem -Lines $lines -LineNumber $item.LineNumber -Mode $Mode)
        }
    }

    $blank = @($stems | Where-Object { [string]::IsNullOrWhiteSpace($_.Stem) })
    if ($blank.Count -gt 0) {
        $errors.Add("$Name has blank primary stem(s): $($blank.Number -join ', ').")
    }

    $duplicates = @($stems | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Stem) } |
        Group-Object Stem | Where-Object Count -gt 1)
    foreach ($duplicate in $duplicates) {
        $numbers = @($duplicate.Group.Number) -join ', '
        $errors.Add("$Name repeats a primary stem in item(s): $numbers. Stem: $($duplicate.Name)")
    }
}

$chapters = @{}
foreach ($number in (@(7) + (13..18))) {
    $chapters[$number] = Get-ChapterPath $number
}

$specifications = @(
    @{ Name = 'Complete the Words'; Chapter = 13; Pattern = '^\*\*CTW-(\d{3})｜'; Minimum = 120; StemMode = 'NextNonBlank' },
    @{ Name = 'Build a Sentence (chapter 13)'; Chapter = 13; Pattern = '^\d+\. \*\*BAS-(\d{3})｜'; Minimum = 0; StemMode = 'Current' },
    @{ Name = 'Listen and Repeat (chapter 13)'; Chapter = 13; Pattern = '^\d+\. \*\*L&R-(\d{3})\*\*'; Minimum = 0; StemMode = 'Current' },
    @{ Name = 'Read in Daily Life'; Chapter = 14; Pattern = '^\*\*RDL-(\d{3})｜'; Minimum = 120; StemMode = 'Current' },
    @{ Name = 'Read an Academic Passage'; Chapter = 14; Pattern = '^\*\*RAP-(\d{3})｜'; Minimum = 80; StemMode = 'Current' },
    @{ Name = 'Listen and Choose a Response'; Chapter = 15; Pattern = '^\*\*LCR-(\d{3})｜'; Minimum = 300; StemMode = 'Current' },
    @{ Name = 'Conversation / Announcement / Academic Talk'; Chapter = 15; Pattern = '^\*\*LT-(\d{3})｜'; Minimum = 160; StemMode = 'Current' },
    @{ Name = 'Build a Sentence (chapter 16)'; Chapter = 16; Pattern = '^- \*\*BS-(\d{3})\*\*'; Minimum = 0; StemMode = 'Current' },
    @{ Name = 'Write an Email'; Chapter = 16; Pattern = '^#### EC-(\d{3})｜'; Minimum = 80; StemMode = 'NextNonBlank' },
    @{ Name = 'Academic Discussion'; Chapter = 16; Pattern = '^#### AD-(\d{3})｜'; Minimum = 80; StemMode = 'NextNonBlank' },
    @{ Name = 'Listen and Repeat (chapter 17)'; Chapter = 17; Pattern = '^\d+\. `LR-(\d{3})`'; Minimum = 0; StemMode = 'Current' },
    @{ Name = 'Take an Interview'; Chapter = 17; Pattern = '^#### INT-(\d{3})｜'; Minimum = 100; StemMode = 'NextNonBlank' }
)

$counts = @{}
foreach ($specification in $specifications) {
    $items = Get-NumberedItems -Path $chapters[$specification.Chapter] -Pattern $specification.Pattern
    Test-ContinuousNumbers -Name $specification.Name -Items $items
    Test-DuplicatePrimaryStems -Name $specification.Name -Path $chapters[$specification.Chapter] -Items $items -Mode $specification.StemMode

    $counts[$specification.Name] = $items.Count
    $results.Add([pscustomobject]@{
        Content = $specification.Name
        Count = $items.Count
        Minimum = $specification.Minimum
    })

    if ($items.Count -lt $specification.Minimum) {
        $errors.Add("$($specification.Name) has $($items.Count) items; minimum is $($specification.Minimum).")
    }
}

$buildASentence = $counts['Build a Sentence (chapter 13)'] + $counts['Build a Sentence (chapter 16)']
$listenAndRepeat = $counts['Listen and Repeat (chapter 13)'] + $counts['Listen and Repeat (chapter 17)']
$results.Add([pscustomobject]@{ Content = 'Build a Sentence (total)'; Count = $buildASentence; Minimum = 300 })
$results.Add([pscustomobject]@{ Content = 'Listen and Repeat (total)'; Count = $listenAndRepeat; Minimum = 400 })
if ($buildASentence -lt 300) {
    $errors.Add("Build a Sentence has $buildASentence items; minimum is 300.")
}
if ($listenAndRepeat -lt 400) {
    $errors.Add("Listen and Repeat has $listenAndRepeat items; minimum is 400.")
}

$chapter7Mocks = @(Select-String -LiteralPath $chapters[7] -Pattern '^## 模考 [A-Z]｜')
$chapter18Mocks = @(Select-String -LiteralPath $chapters[18] -Pattern '^## .*固定全卷仿真 M(\d{2})｜')
$mockNumbers = @($chapter18Mocks | ForEach-Object { [int]$_.Matches[0].Groups[1].Value })
if ($mockNumbers.Count -ne 6 -or @($mockNumbers | Sort-Object -Unique).Count -ne 6 -or @(1..6 | Where-Object { $_ -notin $mockNumbers }).Count -gt 0) {
    $errors.Add('Chapter 18 fixed mock identifiers must be continuous from M01 through M06.')
}
$completeMocks = $chapter7Mocks.Count + $chapter18Mocks.Count
$results.Add([pscustomobject]@{ Content = 'Complete mocks (chapters 7 + 18)'; Count = $completeMocks; Minimum = 8 })
if ($completeMocks -lt 8) {
    $errors.Add("Complete mocks total $completeMocks; minimum is 8.")
}

foreach ($chapter in 13..18) {
    $path = $chapters[$chapter]
    $content = Get-Content -Raw -LiteralPath $path
    if ($content -match '(?i)\b(?:TODO|TBD|PLACEHOLDER)\b|待补|占位') {
        $errors.Add("$(Split-Path $path -Leaf) contains TODO/TBD/placeholder text.")
    }

    $doubleWords = @([regex]::Matches($content, '(?i)\b(the|how)\s+\1\b'))
    foreach ($doubleWord in $doubleWords) {
        $errors.Add("$(Split-Path $path -Leaf) contains an accidental doubled word: $($doubleWord.Value).")
    }
}

$results | Format-Table -AutoSize

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Content-count, numbering, primary-stem, placeholder, and doubled-word gates passed.'
