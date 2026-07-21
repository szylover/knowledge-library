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
$tierColumn = @('tier')
$acceptanceColumns = @(
    'year_ce',
    'chronological_band',
    'tier',
    'actioner_representation',
    'spatial_scope',
    'source_caveat_class'
)
$acceptedSchemas = @(
    [pscustomobject]@{
        Name                = 'legacy-10'
        Columns             = $legacyColumns
        RequiredColumns     = $legacyColumns
        HasEvidencePassport = $false
        HasTier             = $false
        ValidateNarrativeTargets = $false
    },
    [pscustomobject]@{
        Name                = 'legacy+caveat+tier-12'
        Columns             = @($legacyColumns + 'source_caveat' + 'tier')
        RequiredColumns     = @($legacyColumns + 'source_caveat' + 'tier')
        HasEvidencePassport = $false
        HasTier             = $true
        ValidateNarrativeTargets = $false
    },
    [pscustomobject]@{
        Name                = 'evidence-passport-13'
        Columns             = @($legacyColumns + $passportColumns)
        RequiredColumns     = @($legacyColumns + $passportColumns)
        HasEvidencePassport = $true
        HasTier             = $false
        ValidateNarrativeTargets = $true
    },
    [pscustomobject]@{
        Name                = 'evidence-passport+tier-14'
        Columns             = @($legacyColumns + $passportColumns + $tierColumn)
        RequiredColumns     = @($legacyColumns + $passportColumns + $tierColumn)
        HasEvidencePassport = $true
        HasTier             = $true
        ValidateNarrativeTargets = $false
    },
    [pscustomobject]@{
        Name                = 'acceptance-evidence-19'
        Columns             = @($legacyColumns + $passportColumns + $acceptanceColumns)
        RequiredColumns     = @($legacyColumns + $passportColumns + $acceptanceColumns)
        HasEvidencePassport = $true
        HasTier             = $true
        ValidateNarrativeTargets = $false
    }
)
$auxiliarySchemas = @(
    [pscustomobject]@{
        Name    = 'coverage-actioner-gap'
        Columns = @('chronological_band', 'actioner_representation', 'record_count', 'gap_status')
    },
    [pscustomobject]@{
        Name    = 'coverage-year-gap'
        Columns = @('year_ce', 'record_count', 'gap_status')
    },
    [pscustomobject]@{
        Name    = 'ledger-schema'
        Columns = @('field', 'required', 'controlled_values_or_format', 'evidence_boundary')
    },
    [pscustomobject]@{
        Name    = 'source-caveat-audit'
        Columns = @('evidence_type', 'source_caveat_class', 'record_count', 'blank_source_caveat_count')
    }
)
$seriesRoot = Split-Path -Parent $PSScriptRoot
$allowedEvidenceTypes = @(
    'annalistic_record',
    'narrative_text',
    'retrospective_history',
    'official_or_administrative_document',
    'excavated_text_or_inscription',
    'archaeological_context',
    'modern_research',
    'archival_record',
    'cross_polity_record',
    'local_record'
)
$allowedTiers = @('A', 'B', 'C')

function Test-ColumnSequence {
    param(
        [string[]]$Actual,
        [string[]]$Expected
    )

    if ($Actual.Count -ne $Expected.Count) {
        return $false
    }

    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($Actual[$index] -cne $Expected[$index]) {
            return $false
        }
    }

    return $true
}

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

function Get-IncludedTexFiles {
    param(
        [System.IO.DirectoryInfo]$VolumeRoot
    )

    $mainFile = Join-Path $VolumeRoot.FullName 'main.tex'
    if (-not (Test-Path -LiteralPath $mainFile -PathType Leaf)) {
        throw "Cannot find volume main file: $mainFile"
    }

    $included = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue([System.IO.Path]::GetFullPath($mainFile))
    $rootPrefix = "$([System.IO.Path]::GetFullPath($VolumeRoot.FullName))$([System.IO.Path]::DirectorySeparatorChar)"

    while ($pending.Count -gt 0) {
        $file = $pending.Dequeue()
        if (-not $included.Add($file)) {
            continue
        }

        $content = [System.IO.File]::ReadAllText($file)
        foreach ($match in [regex]::Matches($content, '\\(?:input|include)\{([^}]+)\}')) {
            $reference = $match.Groups[1].Value.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            if ([System.IO.Path]::GetExtension($reference) -eq '') {
                $reference += '.tex'
            }

            $candidate = [System.IO.Path]::GetFullPath((Join-Path $VolumeRoot.FullName $reference))
            if ($candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
                (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $pending.Enqueue($candidate)
            }
        }
    }

    return $included
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
    $schema = $null
    $skipSchema = $null
    $parser = $null
    $includedTexFiles = $null

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

            $schema = @(
                $acceptedSchemas | Where-Object {
                    Test-ColumnSequence -Actual $header -Expected $_.Columns
                }
            ) | Select-Object -First 1
            if ($null -eq $schema) {
                $skipSchema = @(
                    $auxiliarySchemas | Where-Object {
                        Test-ColumnSequence -Actual $header -Expected $_.Columns
                    }
                ) | Select-Object -First 1
            }

            if ($null -ne $skipSchema) {
                # Coverage and audit CSVs share the ledger directory but are not ledgers.
            }
            elseif ($null -eq $schema) {
                Add-Issue -Issues $issues -Message (
                    "Unrecognized ledger header. Accepted schemas: " +
                    "$(($acceptedSchemas.Name) -join ', ')."
                )
            }
            else {
                $columnPositions = @{}
                for ($index = 0; $index -lt $schema.Columns.Count; $index++) {
                    $columnPositions[$schema.Columns[$index]] = $index
                }
                if ($schema.ValidateNarrativeTargets) {
                    try {
                        $includedTexFiles = Get-IncludedTexFiles -VolumeRoot $File.Directory.Parent.Parent
                    }
                    catch {
                        Add-Issue -Issues $issues -Message "Unable to inspect narrative targets: $($_.Exception.Message)"
                    }
                }

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
                    if ($fields.Count -ne $schema.Columns.Count) {
                        Add-Issue -Issues $issues -Message (
                            "Data row $recordCount has $($fields.Count) columns; expected $($schema.Columns.Count)."
                        )
                        continue
                    }

                    foreach ($column in $schema.RequiredColumns) {
                        if ([string]::IsNullOrWhiteSpace($fields[$columnPositions[$column]])) {
                            Add-Issue -Issues $issues -Message "Data row $recordCount has an empty '$column' value."
                        }
                    }

                    $id = $fields[0].Trim()
                    if (-not [string]::IsNullOrWhiteSpace($id) -and -not $seenIds.Add($id)) {
                        Add-Issue -Issues $issues -Message "Data row $recordCount repeats id '$id'."
                    }

                    if ($schema.HasEvidencePassport) {
                        $evidenceType = $fields[$columnPositions['evidence_type']].Trim()
                        if ($allowedEvidenceTypes -cnotcontains $evidenceType) {
                            Add-Issue -Issues $issues -Message (
                                "Data row $recordCount has unsupported evidence_type '$evidenceType'."
                            )
                        }
                    }

                    if ($schema.HasTier) {
                        $tier = $fields[$columnPositions['tier']].Trim()
                        if ($allowedTiers -cnotcontains $tier) {
                            Add-Issue -Issues $issues -Message (
                                "Data row $recordCount has unsupported tier '$tier'."
                            )
                        }
                    }

                    if ($schema.ValidateNarrativeTargets -and $null -ne $includedTexFiles) {
                        $target = $fields[$columnPositions['target']].Trim()
                        $targetPath = [System.IO.Path]::GetFullPath((
                            Join-Path $File.Directory.Parent.Parent.FullName $target.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
                        ))
                        if (-not $includedTexFiles.Contains($targetPath)) {
                            Add-Issue -Issues $issues -Message (
                                "Data row $recordCount target '$target' is not an existing file included by the volume main.tex."
                            )
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

    $status = if ($null -ne $skipSchema) {
        'SKIP'
    }
    elseif ($issues.Count -eq 0) {
        'PASS'
    }
    else {
        'FAIL'
    }
    $schemaName = if ($null -ne $schema) {
        $schema.Name
    }
    elseif ($null -ne $skipSchema) {
        $skipSchema.Name
    }
    else {
        'unrecognized'
    }
    [pscustomobject]@{
        File    = $File.FullName
        Status  = $status
        Records = $recordCount
        Schema  = $schemaName
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
