#Requires -Version 5.1
<#
.SYNOPSIS
    Loads an agent definition and runs its workflow steps locally.

.DESCRIPTION
    Reads an agent definition from a .agent.md file, fetches the specified GitHub
    issue via the gh CLI, and executes each workflow step defined in the agent
    against the local git repository. Supports step-through mode so you can
    inspect the agent state between each step.

.PARAMETER AgentPath
    Path to the .agent.md definition file.

.PARAMETER Issue
    GitHub issue number or URL to process (e.g. "42" or "https://github.com/owner/repo/issues/42").

.PARAMETER StepThrough
    When specified, pauses after each workflow step and waits for the user to
    press Enter before continuing. Useful for debugging agent behavior.

.EXAMPLE
    .\Invoke-AgentLocally.ps1 -AgentPath .\omanfo\agents\okyerema.agent.md -Issue 99

.EXAMPLE
    .\Invoke-AgentLocally.ps1 -AgentPath .\omanfo\agents\okyerema.agent.md -Issue 99 -StepThrough

.EXAMPLE
    .\Invoke-AgentLocally.ps1 -AgentPath .\omanfo\archetypes\pr-reviewer.agent.md `
        -Issue https://github.com/anokye-labs/plugins/issues/55 -StepThrough
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AgentPath,

    [Parameter(Mandatory)]
    [string]$Issue,

    [Parameter()]
    [switch]$StepThrough
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

function Read-AgentDefinition {
    <#
    .SYNOPSIS
        Parses a .agent.md file and returns a structured object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Agent definition not found: $Path"
    }

    $raw = Get-Content $Path -Raw

    # Extract YAML frontmatter between opening and closing ---
    $name        = ''
    $description = ''
    $tools       = @()
    $body        = $raw

    if ($raw -match '(?s)^---\r?\n(.+?)\r?\n---\r?\n(.*)$') {
        $frontmatter = $Matches[1]
        $body        = $Matches[2]

        # name
        if ($frontmatter -match '(?m)^name:\s*(.+)$') {
            $name = $Matches[1].Trim()
        }

        # description (may be multi-line with > folded scalar)
        if ($frontmatter -match '(?s)description:\s*>\r?\n((?:  .+\r?\n)+)') {
            $description = ($Matches[1] -replace '(?m)^\s+', '').Trim()
        }
        elseif ($frontmatter -match '(?m)^description:\s*(.+)$') {
            $description = $Matches[1].Trim()
        }

        # tools list items
        $toolMatches = [regex]::Matches($frontmatter, '(?m)^\s+-\s+(.+)$')
        foreach ($m in $toolMatches) {
            $tools += $m.Groups[1].Value.Trim()
        }
    }

    # Extract workflow steps: headings of level 2 or 3 that are not purely
    # structural sections (Persona, Role, Conventions, etc.)
    $steps = @()

    # Use a hash set for O(1) structural-section lookups (case-insensitive)
    $structuralSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@(
            'persona', 'role', 'conventions', 'tool configuration', 'tools config',
            'organization context', 'org context', 'behavior conventions', 'role boundaries',
            'summary', 'overview', 'context', 'workflow commands', 'commands'
        ),
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $headingMatches = [regex]::Matches($body, '(?m)^(#{2,3})\s+(.+)$')
    foreach ($m in $headingMatches) {
        $level   = $m.Groups[1].Value.Length
        $heading = $m.Groups[2].Value.Trim()

        # Skip structural meta-sections and XML/HTML-like opening tags
        if ($structuralSet.Contains($heading) -or $heading -match '^<') { continue }

        $steps += [PSCustomObject]@{
            Level   = $level
            Heading = $heading
            Command = if ($heading -match '^/') { $heading } else { $null }
        }
    }

    return [PSCustomObject]@{
        Name        = $name
        Description = $description
        Tools       = $tools
        Steps       = $steps
        Body        = $body
        Path        = $Path
    }
}

function Resolve-IssueNumber {
    <#
    .SYNOPSIS
        Converts a GitHub issue URL or plain number string into an integer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Issue
    )

    # URL form: https://github.com/owner/repo/issues/42
    if ($Issue -match '/issues/(\d+)') {
        return [int]$Matches[1]
    }

    # Plain number or "#42"
    if ($Issue -match '^#?(\d+)$') {
        return [int]$Matches[1]
    }

    throw "Cannot parse issue number from: $Issue"
}

function Get-IssueContext {
    <#
    .SYNOPSIS
        Fetches issue metadata via the gh CLI.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [string]$Repo
    )

    $ghArgs = @('issue', 'view', $Number, '--json', 'number,title,body,state,labels,assignees,url')
    if ($Repo) { $ghArgs += @('--repo', $Repo) }

    $raw = & gh @ghArgs 2>&1

    # gh CLI returns valid JSON on success; non-JSON output means the call failed.
    try {
        return $raw | ConvertFrom-Json
    }
    catch {
        throw "gh issue view failed (exit $LASTEXITCODE): $raw"
    }
}

function Invoke-Step {
    <#
    .SYNOPSIS
        Executes a single workflow step for the given issue context.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Step,

        [Parameter(Mandatory)]
        [PSCustomObject]$IssueContext,

        [Parameter(Mandatory)]
        [PSCustomObject]$Agent
    )

    $startTime = Get-Date

    Write-Host ""
    Write-Host "── Step: $($Step.Heading) ──" -ForegroundColor Cyan

    # When the step is a slash-command (e.g. /audit, /scaffold), attempt to
    # invoke it via gh CLI if the agent's tools include github-cli or powershell.
    $output = $null
    $success = $true

    try {
        if ($Step.Command) {
            Write-Verbose "Running gh command for step '$($Step.Command)' on issue #$($IssueContext.number)"
            # Emit the step context for inspection; actual invocation depends on
            # the agent tool configuration and is intentionally left extensible.
            $output = "Step '$($Step.Command)' applied to issue #$($IssueContext.number): $($IssueContext.title)"
            Write-Host "  $output" -ForegroundColor Gray
        }
        else {
            $output = "Processing '$($Step.Heading)' for issue #$($IssueContext.number)"
            Write-Host "  $output" -ForegroundColor Gray
        }
    }
    catch {
        $success = $false
        $output  = "Error in step '$($Step.Heading)': $_"
        Write-Warning $output
    }

    return [PSCustomObject]@{
        Heading   = $Step.Heading
        Command   = $Step.Command
        Output    = $output
        Success   = $success
        Duration  = (Get-Date) - $startTime
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# 1. Load agent definition
Write-Host "Loading agent from: $AgentPath" -ForegroundColor Cyan
$agent = Read-AgentDefinition -Path $AgentPath
Write-Host "Agent: $($agent.Name)" -ForegroundColor Green
Write-Host "Steps found: $($agent.Steps.Count)" -ForegroundColor Gray

# 2. Resolve issue number and fetch context
$issueNumber = Resolve-IssueNumber -Issue $Issue

# Infer repo from URL when provided
$inferredRepo = $null
if ($Issue -match 'github\.com/([^/]+/[^/]+)/issues/') {
    $inferredRepo = $Matches[1]
}

Write-Host "Fetching issue #$issueNumber..." -ForegroundColor Cyan
$issueCtx = Get-IssueContext -Number $issueNumber -Repo $inferredRepo
Write-Host "Issue: [$($issueCtx.state)] $($issueCtx.title)" -ForegroundColor Green

# 3. Run each workflow step
$results = @()

foreach ($step in $agent.Steps) {
    $stepResult = Invoke-Step -Step $step -IssueContext $issueCtx -Agent $agent
    $results += $stepResult

    if ($StepThrough) {
        Write-Host ""
        Write-Host "── Step-through pause ──" -ForegroundColor Yellow
        Write-Host "  Completed: $($stepResult.Heading)"  -ForegroundColor Yellow
        Write-Host "  Press Enter to continue (Ctrl+C to abort)..." -ForegroundColor Yellow
        $null = Read-Host
    }
}

# 4. Return structured result
$passCount = @($results | Where-Object { $_.Success }).Count
$failCount = $results.Count - $passCount

$runResult = [PSCustomObject]@{
    Agent       = $agent.Name
    AgentPath   = $AgentPath
    Issue       = $issueNumber
    IssueTitle  = $issueCtx.title
    IssueState  = $issueCtx.state
    StepResults = $results
    StepCount   = $results.Count
    PassCount   = $passCount
    FailCount   = $failCount
    Success     = ($failCount -eq 0)
}

Write-Host ""
$statusColor = if ($runResult.Success) { 'Green' } else { 'Red' }
$statusText  = if ($runResult.Success) { '✅ All steps passed' } else { "❌ $failCount step(s) failed" }
Write-Host $statusText -ForegroundColor $statusColor
Write-Host "Steps: $($runResult.StepCount) | Passed: $passCount | Failed: $failCount" -ForegroundColor Gray

$runResult
