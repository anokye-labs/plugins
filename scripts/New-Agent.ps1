#Requires -Version 5.1
<#
.SYNOPSIS
    Scaffolds a new agent from an archetype template.

.DESCRIPTION
    Generates a .agent.md definition file, a companion GitHub Actions workflow
    YAML, and scaffolded Pester test files for a new agent. Supports four
    archetypes: doc-sync, labeler, reviewer, and custom.

.PARAMETER Name
    Name of the agent to create. Used as the base name for all generated files.

.PARAMETER Archetype
    The archetype template to base the new agent on.
    Must be one of: doc-sync, labeler, reviewer, custom.

.PARAMETER OutputPath
    Directory to write generated files. Defaults to the repository root
    (the parent directory of the scripts/ folder).

.PARAMETER DryRun
    When specified, previews what would be created without writing any files.

.EXAMPLE
    .\New-Agent.ps1 -Name my-agent -Archetype reviewer
    Scaffolds a reviewer-style agent named "my-agent" in the repo root.

.EXAMPLE
    .\New-Agent.ps1 -Name doc-watcher -Archetype doc-sync -DryRun
    Previews all files that would be generated without writing them.

.EXAMPLE
    .\New-Agent.ps1 -Name custom-bot -Archetype custom -OutputPath ./output
    Scaffolds a custom agent, writing files to the ./output directory.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory)]
    [ValidateSet('doc-sync', 'labeler', 'reviewer', 'custom')]
    [string]$Archetype,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Resolve output path ─────────────────────────────────────────────────────

if (-not $OutputPath) {
    # Default to repository root (parent of the scripts/ directory)
    $OutputPath = Split-Path $PSScriptRoot -Parent
}

$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

# ─── Archetype templates ──────────────────────────────────────────────────────

function Get-AgentTemplate {
    param(
        [string]$Name,
        [string]$Archetype
    )

    $titleCase = (Get-Culture).TextInfo.ToTitleCase($Name.Replace('-', ' '))

    switch ($Archetype) {
        'doc-sync' {
            return @"
---
name: $Name
description: >
  Documentation synchronization agent. Detects mismatches between code changes
  and documentation, then generates PRs to keep docs in sync with implementation.
archetype: doc-sync
tools:
  - powershell
  - github-cli
  - bash
---

# $titleCase Agent

You are a documentation synchronization agent. Your purpose is to ensure that
documentation stays in sync with code changes by detecting mismatches and
creating pull requests to update documentation.

<persona>
- You are a **$titleCase Agent** — you keep documentation synchronized with code
- You **watch merged PRs** and analyze changes for documentation impacts
- You **detect documentation gaps** — when code changes but docs don't
- You **create PRs** to update documentation that has fallen out of sync
- You are proactive but not intrusive — surface issues, don't force changes
- You speak in actions, not suggestions — create the PR, explain the mismatch
</persona>

## Role Boundaries

<role>

### What You DO
- **Monitor merged PRs** — Track code changes that may affect documentation
- **Analyze changes** — Compare code signatures, function names, API endpoints
- **Detect mismatches** — Identify when docs reference outdated code
- **Create documentation PRs** — Generate PRs with proposed doc updates

### What You DO NOT Do
- ❌ Modify code or implementation
- ❌ Merge PRs yourself (require human review)
- ❌ Delete documentation without replacement

</role>

## Workflow

<workflow>

### Trigger: Merged PR

1. Retrieve PR details (number, title, files changed, diff)
2. Parse changed files and extract code modifications
3. Search for related documentation references
4. Detect mismatches between code and docs
5. Create documentation PR if mismatches found

</workflow>

## Configuration

<config>

### Environment Variables

- ``AGENT_ENABLED`` — Enable/disable agent (default: ``true``)
- ``AGENT_BRANCHES`` — Comma-separated branches to monitor (default: ``main``)

</config>
"@
        }
        'labeler' {
            return @"
---
name: $Name
description: >
  Issue labeling agent. Analyzes issue content to automatically apply appropriate
  labels including type detection, priority, and phase.
archetype: labeler
tools:
  - powershell
  - github-cli
---

# $titleCase Agent

You are an issue labeling agent. Your purpose is to automatically analyze new
issues and apply appropriate labels based on content patterns and context.

<persona>
- You are a **$titleCase Agent** — you classify and tag issues automatically
- You **analyze issue content** to detect type, priority, and categorization
- You **apply labels** that help teams organize and prioritize work
- You are precise but not aggressive — apply only high-confidence labels
- You speak in actions, not suggestions — apply the label, log the reasoning
</persona>

## Role Boundaries

<role>

### What You DO
- **Analyze new issues** — Parse title, body, and metadata
- **Detect issue type** — Epic, Feature, Task, or Bug
- **Apply priority labels** — Based on urgency keywords and context
- **Tag phase labels** — Design, implementation, review, etc.

### What You DO NOT Do
- ❌ Close or resolve issues
- ❌ Assign issues to individuals
- ❌ Modify issue content

</role>

## Workflow

<workflow>

### Trigger: Issue Opened

1. Parse issue title and body
2. Detect issue type from content patterns
3. Determine priority level
4. Apply labels via GitHub API

</workflow>

## Configuration

<config>

### Environment Variables

- ``AGENT_ENABLED`` — Enable/disable agent (default: ``true``)
- ``AGENT_MIN_CONFIDENCE`` — Minimum confidence to apply label (default: ``0.7``)

</config>
"@
        }
        'reviewer' {
            return @"
---
name: $Name
description: >
  Pull request reviewer agent. Posts structured review comments, validates commit
  messages and issue references, checks for common mistakes, and assesses test coverage.
archetype: reviewer
tools:
  - powershell
  - github-cli
  - bash
---

# $titleCase Agent

You are a pull request reviewer agent. Your purpose is to automatically review
PRs with structured feedback, validate conventions, and help maintain code quality.

<persona>
- You are a **$titleCase Agent** — you provide automated code reviews
- You **analyze diffs** to detect common mistakes and patterns
- You **validate conventions** like commit format and issue references
- You **assess test coverage** to ensure changes are tested
- You are helpful but not pedantic — focus on meaningful issues
- You speak in actions, not suggestions — post the review, explain the concern
</persona>

## Role Boundaries

<role>

### What You DO
- **Review PR diffs** — Detect bugs, anti-patterns, and style violations
- **Validate commit messages** — Check format and content
- **Check issue references** — Ensure PRs link to issues
- **Assess test coverage** — Flag untested changes

### What You DO NOT Do
- ❌ Approve PRs without validation
- ❌ Merge PRs
- ❌ Modify PR code directly

</role>

## Workflow

<workflow>

### Trigger: Pull Request Opened / Synchronized

1. Retrieve PR diff and metadata
2. Validate commit messages and issue references
3. Analyze diff for common issues
4. Post review comments via GitHub API

</workflow>

## Configuration

<config>

### Environment Variables

- ``AGENT_ENABLED`` — Enable/disable agent (default: ``true``)
- ``AGENT_AUTO_APPROVE`` — Auto-approve when all checks pass (default: ``false``)

</config>
"@
        }
        'custom' {
            return @"
---
name: $Name
description: >
  Custom agent. Add your description here.
archetype: custom
tools:
  - powershell
  - github-cli
---

# $titleCase Agent

You are a custom agent. Replace this content with your agent's purpose and behavior.

<persona>
- You are a **$titleCase Agent** — describe your agent's role here
- Add additional persona traits as needed
</persona>

## Role Boundaries

<role>

### What You DO
- Define what this agent does

### What You DO NOT Do
- ❌ Define what this agent does not do

</role>

## Workflow

<workflow>

### Trigger: Define your trigger

1. Step 1
2. Step 2
3. Step 3

</workflow>

## Configuration

<config>

### Environment Variables

- ``AGENT_ENABLED`` — Enable/disable agent (default: ``true``)

</config>
"@
        }
    }
}

function Get-WorkflowTemplate {
    param(
        [string]$Name,
        [string]$Archetype
    )

    switch ($Archetype) {
        'doc-sync' {
            $trigger = @"
  pull_request:
    types: [closed]
    branches: [main]
"@
            $condition = "if: github.event.pull_request.merged == true"
            $permissions = @"
      contents: write
      pull-requests: write
"@
        }
        'labeler' {
            $trigger = @"
  issues:
    types: [opened]
"@
            $condition = ""
            $permissions = @"
      issues: write
"@
        }
        'reviewer' {
            $trigger = @"
  pull_request:
    types: [opened, synchronize, reopened]
"@
            $condition = ""
            $permissions = @"
      pull-requests: write
"@
        }
        'custom' {
            $trigger = @"
  workflow_dispatch:
"@
            $condition = ""
            $permissions = @"
      contents: read
"@
        }
    }

    $conditionLine = if ($condition) { "`n    $condition" } else { "" }

    return @"
name: $Name Agent

on:
$trigger
jobs:
  run-agent:
    name: Run $Name Agent
    runs-on: ubuntu-latest$conditionLine
    permissions:
$permissions
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run $Name Agent
        env:
          GH_TOKEN: `${{ secrets.GITHUB_TOKEN }}
        run: |
          pwsh .github/agents/$Name.agent.ps1
"@
}

function Get-AgentScriptTemplate {
    param(
        [string]$Name,
        [string]$Archetype
    )

    $titleCase = (Get-Culture).TextInfo.ToTitleCase($Name.Replace('-', ' '))

    return @"
#Requires -Version 5.1
<#
.SYNOPSIS
    $titleCase agent implementation.
.DESCRIPTION
    Entry point for the $Name agent (archetype: $Archetype).
    Replace this placeholder with your agent logic.
.PARAMETER DryRun
    Preview actions without making changes.
.EXAMPLE
    ./$Name.agent.ps1
    Runs the $titleCase agent.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]`$DryRun
)

`$ErrorActionPreference = 'Stop'

# TODO: Implement $titleCase agent logic here.
# See .github/agents/$Name.agent.md for the agent definition.

Write-Host "$titleCase agent is not yet implemented." -ForegroundColor Yellow

return [PSCustomObject]@{
    Agent   = '$Name'
    Status  = 'not-implemented'
    DryRun  = `$DryRun.IsPresent
}
"@
}

function Get-TestTemplate {
    param(
        [string]$Name,
        [string]$Archetype
    )

    $titleCase = (Get-Culture).TextInfo.ToTitleCase($Name.Replace('-', ' '))

    return @"
# $titleCase Agent Tests

BeforeAll {
    `$agentPath = Join-Path `$PSScriptRoot "../../../.github/agents/$Name.agent.ps1"
}

Describe '$titleCase Agent' {

    Context 'Script structure' {
        It 'Agent definition file exists' {
            `$agentMd = Join-Path `$PSScriptRoot "../../../.github/agents/$Name.agent.md"
            Test-Path `$agentMd | Should -BeTrue
        }

        It 'Workflow file exists' {
            `$workflowYml = Join-Path `$PSScriptRoot "../../../.github/workflows/$Name.yml"
            Test-Path `$workflowYml | Should -BeTrue
        }
    }

    Context '$Archetype archetype behavior' {
        It 'Placeholder: add $Archetype-specific tests here' {
            `$true | Should -BeTrue
        }
    }
}
"@
}

# ─── Build file list ──────────────────────────────────────────────────────────

$agentMdRelative     = ".github/agents/$Name.agent.md"
$agentScriptRelative = ".github/agents/$Name.agent.ps1"
$workflowRelative    = ".github/workflows/$Name.yml"
$testRelative        = "tests/scripts/unit/$Name.Agent.Tests.ps1"

$agentMdPath     = Join-Path $OutputPath $agentMdRelative
$agentScriptPath = Join-Path $OutputPath $agentScriptRelative
$workflowPath    = Join-Path $OutputPath $workflowRelative
$testPath        = Join-Path $OutputPath $testRelative

$agentMdContent     = Get-AgentTemplate      -Name $Name -Archetype $Archetype
$agentScriptContent = Get-AgentScriptTemplate -Name $Name -Archetype $Archetype
$workflowContent    = Get-WorkflowTemplate   -Name $Name -Archetype $Archetype
$testContent        = Get-TestTemplate       -Name $Name -Archetype $Archetype

$filesToCreate = @(
    [PSCustomObject]@{ RelativePath = $agentMdRelative;     FullPath = $agentMdPath;     Content = $agentMdContent }
    [PSCustomObject]@{ RelativePath = $agentScriptRelative; FullPath = $agentScriptPath; Content = $agentScriptContent }
    [PSCustomObject]@{ RelativePath = $workflowRelative;    FullPath = $workflowPath;    Content = $workflowContent }
    [PSCustomObject]@{ RelativePath = $testRelative;        FullPath = $testPath;        Content = $testContent }
)

# ─── DryRun / Write ───────────────────────────────────────────────────────────

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN — the following files would be created:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($file in $filesToCreate) {
        Write-Host "  $($file.RelativePath)" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "No files written." -ForegroundColor Yellow
}
else {
    foreach ($file in $filesToCreate) {
        $dir = Split-Path $file.FullPath -Parent
        if (-not (Test-Path $dir)) {
            $null = New-Item -ItemType Directory -Path $dir -Force
        }
        Set-Content -Path $file.FullPath -Value $file.Content -Encoding UTF8
        Write-Host "  Created: $($file.RelativePath)" -ForegroundColor Green
    }
}

# ─── Return structured result ─────────────────────────────────────────────────

return [PSCustomObject]@{
    Name        = $Name
    Archetype   = $Archetype
    OutputPath  = $OutputPath
    DryRun      = $DryRun.IsPresent
    FilesCreated = $filesToCreate | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = $_.RelativePath
            FullPath     = $_.FullPath
            Written      = (-not $DryRun.IsPresent)
        }
    }
}
