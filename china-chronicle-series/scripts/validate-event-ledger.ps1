[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Path,

    [switch]$Recurse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$legacyColumns = @(
    'id',
    'date',
    'polity',
    'event',
    'confidence',
    'core_sources',
    'modern_direction',
    'cause',
    'consequence',
    'target'
)
$passportColumns = @(
    'evidence_type',
    'source_locator',
    'source_caveat'
)
$seriesRoot = Split-Path -Parent $PSScriptRoot
$allowedEvidenceTypes = @(
    'annalistic_record',
    'narrative_text',
    'retrospective_history',
    'official_or_administrative_document',
    'excavated_text_or_inscription',
    'archaeological_context',
    'modern_research'
)

function Get-LedgerFiles {
    param(
        [string[]]$InputPath,
        [switch]$SearchRecursively
    )

    $files = @()
    foreach ($inputItem in $InputPath) {
        $candidatePath = if ([System.IO.Path]::IsPathRooted($inputItem)) {
            $inputItem
        }
        else {
            Join-Path $seriesRoot $inputItem
        }

        foreach ($resolvedPath in @(Resolve-Path -LiteralPath $candidatePath -ErrorAction Stop)) {
            $item = Get-Item -LiteralPath $resolvedPath.Path -ErrorAction Stop
            if ($item.PSIsContainer) {
                $parameters = @{
                    LiteralPath = $item.FullName
                    File        = $true
                    Filter      = '*.csv'
                }
                if ($SearchRecursively) {
                    $parameters.Recurse = $true
                }
                $files += @(Get-ChildItem @parameters)
            }
            elseif ($item.Extension -eq '.csv') {
                $files += $item
            }
            else {
                throw "Not a CSV file or directory: $($item.FullName)"
            }
        }
    }

    return @($files | Sort-Object FullName -Unique)
}

function Add-Issue {
    param(
        [System.Collections.Generic.List[string]]$Issues,
        [string]$Message
    )

    [void]$Issues.Add($Message)
}

function Test-EventLedger {
    param(
        [System.IO.FileInfo]$File
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $recordCount = 0
    $hasPassportColumns = $false
    $parser = $null

    try {
        $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new(
            $File.FullName,
            [System.Text.Encoding]::UTF8,
            $true
        )
        $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
        $parser.SetDelimiters(',')
        $parser.HasFieldsEnclosedInQuotes = $true

        if ($parser.EndOfData) {
            Add-Issue -Issues $issues -Message 'The file is empty.'
        }
        else {
            $header = @($parser.ReadFields() | ForEach-Object { $_.Trim() })
            if ($header.Count -gt 0) {
                $header[0] = $header[0].TrimStart([char]0xFEFF)
            }

            $expectedHeader = @($legacyColumns)
            if ($header.Count -gt $legacyColumns.Count) {
                $expectedHeader += $passportColumns
                $hasPassportColumns = $true
            }

            if ($header.Count -ne $expectedHeader.Count) {
                Add-Issue -Issues $issues -Message (
                    "Header has $($header.Count) columns; expected $($legacyColumns.Count) legacy columns " +
                    "or $($legacyColumns.Count + $passportColumns.Count) columns with the evidence-passport extension."
                )
            }
            else {
                for ($index = 0; $index -lt $expectedHeader.Count; $index++) {
                    if ($header[$index] -cne $expectedHeader[$index]) {
                        Add-Issue -Issues $issues -Message (
                            "Header column $($index + 1) is '$($header[$index])'; expected '$($expectedHeader[$index])'."
                        )
                    }
                }
            }

            if ($issues.Count -eq 0) {
                while (-not $parser.EndOfData) {
                    try {
                        $fields = @($parser.ReadFields())
                    }
                    catch {
                        Add-Issue -Issues $issues -Message "Malformed CSV record after data row ${recordCount}: $($_.Exception.Message)"
                        continue
                    }

                    if ($fields.Count -eq 1 -and [string]::IsNullOrWhiteSpace($fields[0])) {
                        continue
                    }

                    $recordCount++
                    if ($fields.Count -ne $expectedHeader.Count) {
                        Add-Issue -Issues $issues -Message (
                            "Data row $recordCount has $($fields.Count) columns; expected $($expectedHeader.Count)."
                        )
                        continue
                    }

                    for ($index = 0; $index -lt $legacyColumns.Count; $index++) {
                        if ([string]::IsNullOrWhiteSpace($fields[$index])) {
                            Add-Issue -Issues $issues -Message "Data row $recordCount has an empty '$($legacyColumns[$index])' value."
                        }
                    }

                    $id = $fields[0].Trim()
                    if (-not [string]::IsNullOrWhiteSpace($id) -and -not $seenIds.Add($id)) {
                        Add-Issue -Issues $issues -Message "Data row $recordCount repeats id '$id'."
                    }

                    if ($hasPassportColumns) {
                        $passportValues = @($fields[$legacyColumns.Count..($expectedHeader.Count - 1)])
                        $populatedPassportFields = @(
                            $passportValues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                        ).Count

                        if ($populatedPassportFields -ne 0) {
                            if ($populatedPassportFields -ne $passportColumns.Count) {
                                Add-Issue -Issues $issues -Message (
                                    "Data row $recordCount has a partial evidence-passport; " +
                                    "evidence_type, source_locator, and source_caveat must all be populated."
                                )
                            }
                            elseif ($allowedEvidenceTypes -cnotcontains $fields[$legacyColumns.Count].Trim()) {
                                Add-Issue -Issues $issues -Message (
                                    "Data row $recordCount has unsupported evidence_type '$($fields[$legacyColumns.Count])'."
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    catch {
        Add-Issue -Issues $issues -Message $_.Exception.Message
    }
    finally {
        if ($null -ne $parser) {
            $parser.Close()
        }
    }

    $status = if ($issues.Count -eq 0) { 'PASS' } else { 'FAIL' }
    $schema = if ($hasPassportColumns) { 'legacy+passport' } else { 'legacy-10' }
    [pscustomobject]@{
        File    = $File.FullName
        Status  = $status
        Records = $recordCount
        Schema  = $schema
        Issues  = $issues
    }
}

$files = @(Get-LedgerFiles -InputPath $Path -SearchRecursively:$Recurse)
if ($files.Count -eq 0) {
    throw 'No CSV files were found.'
}

$results = @($files | ForEach-Object { Test-EventLedger -File $_ })
foreach ($result in $results) {
    Write-Output "$($result.Status) $($result.File) ($($result.Records) data rows; $($result.Schema))"
    foreach ($issue in $result.Issues) {
        [Console]::Error.WriteLine("  - $issue")
    }
}

if (@($results | Where-Object { $_.Status -eq 'FAIL' }).Count -gt 0) {
    [Console]::Error.WriteLine('Ledger validation failed.')
    exit 1
}
