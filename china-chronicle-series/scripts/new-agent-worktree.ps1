param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [string]$Branch = "chronicle/$TaskId"
)

$ErrorActionPreference = 'Stop'
$seriesRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (& git -C $seriesRoot rev-parse --show-toplevel).Trim()
$worktreeRoot = Join-Path $repositoryRoot '.chronicle-worktrees'
$target = Join-Path $worktreeRoot $TaskId

$queueFiles = @(
    (Join-Path $seriesRoot 'WORK_QUEUE.yaml')
) + @(
    Get-ChildItem -LiteralPath (Join-Path $seriesRoot 'volumes') -Filter 'WORK_QUEUE.yaml' -File -Recurse |
        Select-Object -ExpandProperty FullName
)

$taskPattern = "^\s*-\s+id:\s*$([regex]::Escape($TaskId))\s*$"
if (-not (Select-String -LiteralPath $queueFiles -Pattern $taskPattern -Quiet)) {
    throw "Task '$TaskId' is not listed in the series or a volume-local WORK_QUEUE.yaml."
}
if (Test-Path $target) {
    throw "Worktree already exists: $target"
}

New-Item -ItemType Directory -Force -Path $worktreeRoot | Out-Null
git -C $repositoryRoot fetch origin
git -C $repositoryRoot worktree add -b $Branch $target origin/main

Write-Output "Worktree: $target"
Write-Output "Branch: $Branch"
Write-Output "Next: read china-chronicle-series/AGENTS.md and claim the task in WORK_QUEUE.yaml."
