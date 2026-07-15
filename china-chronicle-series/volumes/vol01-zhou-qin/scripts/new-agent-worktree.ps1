param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [string]$Branch = "chronicle/$TaskId"
)

$script = Join-Path $PSScriptRoot '..\..\..\scripts\new-agent-worktree.ps1'
& $script -TaskId $TaskId -Branch $Branch
