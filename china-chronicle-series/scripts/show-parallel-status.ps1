param(
    [switch]$Watch,
    [ValidateRange(2, 3600)]
    [int]$RefreshSeconds = 10
)

$ErrorActionPreference = 'Stop'
$seriesRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (& git -C $seriesRoot rev-parse --show-toplevel).Trim()
$worktreeRoot = Join-Path $repositoryRoot '.chronicle-worktrees'

function Get-QueueStates {
    param([string[]]$QueueFiles)

    $states = @{}
    foreach ($queueFile in $QueueFiles) {
        if (-not (Test-Path $queueFile)) {
            continue
        }

        $taskId = $null
        foreach ($line in Get-Content -LiteralPath $queueFile) {
            if ($line -match '^\s*-\s+id:\s*([^\s#]+)') {
                $taskId = $Matches[1]
                continue
            }

            if ($null -ne $taskId -and $line -match '^\s+status:\s*([^\s#]+)') {
                $states[$taskId] = $Matches[1]
                $taskId = $null
            }
        }
    }

    return $states
}

function Get-TaskStatus {
    $queueFiles = @(
        (Join-Path $seriesRoot 'WORK_QUEUE.yaml'),
        (Join-Path $seriesRoot 'volumes\vol01-zhou-qin\WORK_QUEUE.yaml')
    )
    $queueStates = Get-QueueStates -QueueFiles $queueFiles
    $rows = @()

    if (Test-Path $worktreeRoot) {
        foreach ($worktree in Get-ChildItem -LiteralPath $worktreeRoot -Directory | Sort-Object Name) {
            $taskId = $worktree.Name
            $status = if ($queueStates.ContainsKey($taskId)) { $queueStates[$taskId] } else { 'worktree-active' }
            $changes = @(git -C $worktree.FullName status --porcelain)
            $numstat = @(git -C $worktree.FullName diff --numstat)
            $added = 0
            $removed = 0

            foreach ($line in $numstat) {
                $parts = $line -split "`t"
                if ($parts.Count -ge 2) {
                    if ($parts[0] -match '^\d+$') { $added += [int]$parts[0] }
                    if ($parts[1] -match '^\d+$') { $removed += [int]$parts[1] }
                }
            }

            $lastCommit = (& git -C $worktree.FullName log -1 --format='%h %s').Trim()
            $rows += [pscustomobject]@{
                Task = $taskId
                Queue = $status
                Branch = (& git -C $worktree.FullName branch --show-current).Trim()
                ChangedFiles = $changes.Count
                Delta = "+$added / -$removed"
                LastCommit = $lastCommit
            }
        }
    }

    return $rows
}

do {
    if ($Watch) {
        Clear-Host
    }

    Write-Host "China Chronicle parallel status - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Repository: $repositoryRoot"
    Write-Host ""

    $tasks = Get-TaskStatus
    if ($tasks.Count -eq 0) {
        Write-Host "No active chronicle worktrees."
    }
    else {
        $tasks | Format-Table -AutoSize
        Write-Host "Progress is derived from each worktree's Git delta. Queue status is advisory."
    }

    if ($Watch) {
        Start-Sleep -Seconds $RefreshSeconds
    }
}
while ($Watch)
