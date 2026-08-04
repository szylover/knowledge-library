[CmdletBinding()]
param(
    [string]$BookRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($BookRoot)) {
    $BookRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

$bookDir = Join-Path $BookRoot 'book'
$answerPath = Join-Path $bookDir '19-扩展题库答案与解析.md'
$errors = [System.Collections.Generic.List[string]]::new()

function Add-Error([string]$Message) {
    $script:errors.Add($Message)
}

function Read-Chapter([int]$Number) {
    $files = @(Get-ChildItem -LiteralPath $bookDir -File -Filter "$Number-*.md")
    if ($files.Count -ne 1) {
        throw "Expected one chapter $Number file; found $($files.Count)."
    }
    Get-Content -LiteralPath $files[0].FullName -Raw
}

function Get-Ids([string]$Text, [string]$Pattern) {
    @([regex]::Matches($Text, $Pattern) | ForEach-Object Value | Sort-Object -Unique)
}

function Test-Contiguous([string]$Name, [string[]]$Ids, [string]$Prefix, [int]$Digits) {
    if ($Ids.Count -eq 0) {
        Add-Error "$Name has no source identifiers."
        return
    }

    $numbers = @($Ids | ForEach-Object { [int]($_.Substring($Prefix.Length)) } | Sort-Object -Unique)
    $expected = @(1..$numbers[-1])
    $missing = @($expected | Where-Object { $_ -notin $numbers })
    if ($missing.Count -gt 0) {
        $formatted = $missing | ForEach-Object { "$Prefix$($_.ToString("D$Digits"))" }
        Add-Error "$Name source numbering has gaps: $($formatted -join ', ')."
    }
}

function Add-SuffixedIds([string[]]$Ids, [string[]]$Suffixes) {
    @(
        foreach ($id in $Ids) {
            foreach ($suffix in $Suffixes) {
                "$id-$suffix"
            }
        }
    )
}

function Compare-Maps([string]$Name, [string[]]$Expected, [string[]]$Actual) {
    $missing = @($Expected | Where-Object { $_ -notin $Actual })
    $orphaned = @($Actual | Where-Object { $_ -notin $Expected })
    if ($missing.Count -gt 0) {
        Add-Error "$Name missing answer entries ($($missing.Count)): $($missing -join ', ')."
    }
    if ($orphaned.Count -gt 0) {
        Add-Error "$Name has orphaned answer entries ($($orphaned.Count)): $($orphaned -join ', ')."
    }
}

$ch13 = Read-Chapter 13
$ch14 = Read-Chapter 14
$ch15 = Read-Chapter 15
$ch16 = Read-Chapter 16
$ch17 = Read-Chapter 17
$ch18 = Read-Chapter 18
$answerText = Get-Content -LiteralPath $answerPath -Raw
$answerLines = Get-Content -LiteralPath $answerPath

$ctw = Get-Ids $ch13 'CTW-\d{3}'
$bas = Get-Ids $ch13 'BAS-\d{3}'
$rdl = Get-Ids $ch14 'RDL-\d{3}'
$rap = Get-Ids $ch14 'RAP-\d{3}'
$lcr = Get-Ids $ch15 'LCR-\d{3}'
$lt = Get-Ids $ch15 'LT-\d{3}'
$bs = Get-Ids $ch16 'BS-\d{3}'
$ed = Get-Ids $ch16 'ED-\d{3}'
$mockRl = Get-Ids $ch18 'M0[1-6]-[RL]\d{2}'
$routeRl = Get-Ids $ch18 'R[AB]-[RL]\d{2}'

Test-Contiguous 'CTW' $ctw 'CTW-' 3
Test-Contiguous 'BAS' $bas 'BAS-' 3
Test-Contiguous 'RDL' $rdl 'RDL-' 3
Test-Contiguous 'RAP' $rap 'RAP-' 3
Test-Contiguous 'LCR' $lcr 'LCR-' 3
Test-Contiguous 'LT' $lt 'LT-' 3
Test-Contiguous 'BS' $bs 'BS-' 3
Test-Contiguous 'ED' $ed 'ED-' 3

$expectedObjective = @(
    $ctw
    $bas
    (Add-SuffixedIds $rdl @('CTW', 'Q1', 'Q2'))
    (Add-SuffixedIds $rap @('Q1', 'Q2', 'Q3'))
    $lcr
    (Add-SuffixedIds $lt @('Q1', 'Q2', 'Q3'))
    $bs
    $ed
    $mockRl
    $routeRl
)

$objectivePattern = '(?:CTW|BAS|BS|ED|LCR)-\d{3}|RDL-\d{3}-(?:CTW|Q[12])|RAP-\d{3}-Q[123]|LT-\d{3}-Q[123]|(?:M0[1-6]|R[AB])-[RL]\d{2}'
$objectiveRecords = @()
foreach ($line in $answerLines) {
    $match = [regex]::Match($line, "^\*\*(?<id>$objectivePattern)\*\*(?<body>.*)$")
    if ($match.Success) {
        $objectiveRecords += [pscustomobject]@{
            Id = $match.Groups['id'].Value
            Body = $match.Groups['body'].Value.Trim()
        }
    }
}

$actualObjective = @($objectiveRecords | ForEach-Object Id)
Compare-Maps 'Objective answer map' $expectedObjective $actualObjective

$duplicates = @($actualObjective | Group-Object | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) {
    Add-Error "Objective answer entries are not unique: $(($duplicates | ForEach-Object Name) -join ', ')."
}

foreach ($record in $objectiveRecords) {
    if ([string]::IsNullOrWhiteSpace($record.Body)) {
        Add-Error "$($record.Id) has an empty answer entry."
    }
}

$choiceIds = @(
    $expectedObjective | Where-Object {
        $_ -match '^(?:RDL-\d{3}-Q[12]|RAP-\d{3}-Q[123]|LCR-\d{3}|LT-\d{3}-Q[123]|(?:M0[1-6]|R[AB])-[RL]\d{2})$'
    }
)
foreach ($id in $choiceIds) {
    $record = @($objectiveRecords | Where-Object Id -eq $id)
    if ($record.Count -eq 1 -and $record[0].Body -notmatch '(?i)(?:^|[^A-Z])[A-D](?:$|[^A-Z])') {
        Add-Error "$id does not begin with one unique A-D answer."
    }
}

foreach ($mock in 1..6) {
    $name = "M$($mock.ToString('D2'))"
    $sourceIds = @($mockRl | Where-Object { $_ -like "$name-*" })
    $answerIds = @($actualObjective | Where-Object { $_ -like "$name-*" })
    if ($sourceIds.Count -ne 70 -or $answerIds.Count -ne 70) {
        Add-Error "$name must map 70 R/L objective entries; source=$($sourceIds.Count), answers=$($answerIds.Count)."
    }
    Write-Host "$name R/L: $($answerIds.Count)/$($sourceIds.Count)"
}
foreach ($route in 'RA', 'RB') {
    $sourceIds = @($routeRl | Where-Object { $_ -like "$route-*" })
    $answerIds = @($actualObjective | Where-Object { $_ -like "$route-*" })
    if ($sourceIds.Count -ne 24 -or $answerIds.Count -ne 24) {
        Add-Error "$route must map 24 R/L objective entries; source=$($sourceIds.Count), answers=$($answerIds.Count)."
    }
    Write-Host "$route R/L: $($answerIds.Count)/$($sourceIds.Count)"
}

$ec = Get-Ids $ch16 'EC-\d{3}'
$ad = Get-Ids $ch16 'AD-\d{3}'
$lr = Get-Ids $ch17 'LR-\d{3}'
$interview = Get-Ids $ch17 'INT-\d{3}'
$mockWs = Get-Ids $ch18 'M0[1-6]-[WS]\d{2}'
$routeWs = Get-Ids $ch18 'R[AB]-[WS]\d{2}'
$writingIds = @($ec + $ad + @($mockWs | Where-Object { $_ -match '-W' }) + @($routeWs | Where-Object { $_ -match '-W' }))
$speakingIds = @($interview + @($mockWs | Where-Object { $_ -match '-S' }) + @($routeWs | Where-Object { $_ -match '-S' }))

$scorePattern = '(?:EC|AD|INT)-\d{3}|(?:M0[1-6]|R[AB])-[WS]\d{2}'
$scoreRecords = @{}
foreach ($line in $answerLines) {
    foreach ($match in [regex]::Matches($line, "\*\*(?<id>$scorePattern)\*\*")) {
        $id = $match.Groups['id'].Value
        if (-not $scoreRecords.ContainsKey($id)) {
            $scoreRecords[$id] = @()
        }
        $scoreRecords[$id] += $line
    }
}

$actualScores = @($scoreRecords.Keys)
Compare-Maps 'Writing/speaking score map' @($writingIds + $speakingIds) $actualScores
foreach ($id in $actualScores) {
    if ($scoreRecords[$id].Count -ne 1) {
        Add-Error "$id has $($scoreRecords[$id].Count) scoring entries; exactly one is required."
    }
}

foreach ($id in $writingIds) {
    if ($scoreRecords.ContainsKey($id) -and $scoreRecords[$id][0] -notmatch '0.{1,4}2|C=2/1/0') {
        Add-Error "$id lacks a writing scoring scale."
    }
}
foreach ($id in $speakingIds) {
    if ($scoreRecords.ContainsKey($id) -and $scoreRecords[$id][0] -notmatch '0.{1,4}4') {
        Add-Error "$id lacks a speaking scoring scale."
    }
}

$lrScoreIds = @()
foreach ($line in $answerLines | Where-Object { $_ -match '^\*\*LR-\d{3}' }) {
    if ($line -notmatch '0.{1,4}4') {
        Add-Error "LR scoring group lacks a 0—4 scale: $line"
    }
    $lrScoreIds += [regex]::Matches($line, 'LR-\d{3}') | ForEach-Object Value
}
Compare-Maps 'Listen and Repeat scoring map' $lr @($lrScoreIds | Sort-Object -Unique)
$lrDuplicates = @($lrScoreIds | Group-Object | Where-Object Count -gt 1)
if ($lrDuplicates.Count -gt 0) {
    Add-Error "Listen and Repeat scoring entries are not unique: $(($lrDuplicates | ForEach-Object Name) -join ', ')."
}

Write-Host "Objective answers: $($actualObjective.Count)/$($expectedObjective.Count)"
Write-Host "Writing score points: $($writingIds.Count)/$($writingIds.Count)"
Write-Host "Speaking score points: $($speakingIds.Count + $lr.Count)/$($speakingIds.Count + $lr.Count)"

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Answer map validation passed: no duplicate, orphaned, or missing answer entries.'
