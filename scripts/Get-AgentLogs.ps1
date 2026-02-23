#!/usr/bin/env pwsh
#Requires -Version 5.1
<#
.SYNOPSIS
    Queries GitHub Actions workflow run logs for a specific agent.

.DESCRIPTION
    Retrieves workflow run logs from GitHub Actions for a named agent, with
    optional filtering by date range, run status, and output format. Uses the
    GitHub CLI (gh) to call the REST API and returns structured results.

.PARAMETER AgentName
    Name of the agent (workflow name) whose logs to query. Required.

.PARAMETER Owner
    Repository owner (organization or user). Defaults to "anokye-labs".

.PARAMETER Repo
    Repository name. Defaults to "plugins".

.PARAMETER Since
    Start of date range filter. Only runs created at or after this datetime
    are returned.

.PARAMETER Status
    Filter by workflow run status. Valid values: queued, in_progress,
    completed, success, failure, neutral, cancelled, skipped, timed_out,
    action_required.

.PARAMETER Format
    Output format. Valid values: human (default), json.

.EXAMPLE
    ./Get-AgentLogs.ps1 -AgentName "pr-triage"
    Returns all workflow runs for the pr-triage agent in human-readable format.

.EXAMPLE
    ./Get-AgentLogs.ps1 -AgentName "copilot-checks" -Status failure
    Returns only failed runs for the copilot-checks agent.

.EXAMPLE
    ./Get-AgentLogs.ps1 -AgentName "pr-triage" -Since (Get-Date).AddDays(-7) -Format json
    Returns runs from the past 7 days in JSON format.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AgentName,

    [Parameter()]
    [string]$Owner = "anokye-labs",

    [Parameter()]
    [string]$Repo = "plugins",

    [Parameter()]
    [datetime]$Since,

    [Parameter()]
    [ValidateSet('queued', 'in_progress', 'completed', 'success', 'failure',
        'neutral', 'cancelled', 'skipped', 'timed_out', 'action_required')]
    [string]$Status,

    [Parameter()]
    [ValidateSet('human', 'json')]
    [string]$Format = 'human'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-WorkflowRuns {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$AgentName,
        [datetime]$Since,
        [string]$Status
    )

    # Build query parameters
    $params = @("per_page=100")

    if ($Status) {
        $params += "status=$Status"
    }

    if ($Since) {
        $isoDate = $Since.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $params += "created=>=$isoDate"
    }

    $query = $params -join "&"
    $endpoint = "/repos/$Owner/$Repo/actions/runs?$query"

    try {
        $response = & gh api $endpoint --paginate 2>&1
        if (-not $response) {
            return @()
        }

        # gh --paginate may return multiple JSON objects concatenated; wrap in array
        $json = $response | ConvertFrom-Json

        $runs = if ($json -is [array]) {
            $json | ForEach-Object {
                if ($_.workflow_runs) { $_.workflow_runs } else { $_ }
            }
        }
        elseif ($json.workflow_runs) {
            $json.workflow_runs
        }
        else {
            @()
        }

        # Filter by agent name (case-insensitive substring match on workflow name)
        $filtered = $runs | Where-Object {
            $_.name -and $_.name -like "*$AgentName*"
        }

        return $filtered
    }
    catch {
        Write-Error "Failed to query workflow runs: $_"
        throw
    }
}

function Format-HumanOutput {
    param($Runs, [string]$AgentName)

    if (-not $Runs -or @($Runs).Count -eq 0) {
        Write-Host "No workflow runs found for agent: $AgentName"
        return
    }

    $count = @($Runs).Count
    Write-Host "Found $count run(s) for agent '$AgentName':" -ForegroundColor Cyan
    Write-Host ""

    foreach ($run in $Runs) {
        $statusColor = switch ($run.conclusion) {
            'success'  { 'Green' }
            'failure'  { 'Red' }
            'cancelled' { 'Yellow' }
            default    { 'White' }
        }

        $conclusion = if ($run.conclusion) { $run.conclusion } else { $run.status }
        Write-Host "  Run #$($run.run_number)" -ForegroundColor Cyan -NoNewline
        Write-Host "  [$conclusion]" -ForegroundColor $statusColor -NoNewline
        Write-Host "  $($run.name)"
        Write-Host "    Created : $($run.created_at)"
        Write-Host "    Branch  : $($run.head_branch)"
        Write-Host "    URL     : $($run.html_url)"
        Write-Host ""
    }
}

# ============================================================================
# Main
# ============================================================================

$queryParams = @{
    Owner     = $Owner
    Repo      = $Repo
    AgentName = $AgentName
}
if ($PSBoundParameters.ContainsKey('Since'))  { $queryParams.Since  = $Since }
if ($PSBoundParameters.ContainsKey('Status')) { $queryParams.Status = $Status }

$runs = Get-WorkflowRuns @queryParams

[array]$runList = @()
if ($runs) { [array]$runList = @($runs) }

$result = [PSCustomObject]@{
    AgentName = $AgentName
    Owner     = $Owner
    Repo      = $Repo
    RunCount  = $runList.Count
    Runs      = $runList
}

if ($Format -eq 'json') {
    $result | ConvertTo-Json -Depth 10
}
else {
    Format-HumanOutput -Runs $runList -AgentName $AgentName
    $result
}
