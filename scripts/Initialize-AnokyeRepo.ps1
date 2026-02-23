#Requires -Version 5.1
<#
.SYNOPSIS
    Initializes the standard Anokye directory structure for a new repository.

.DESCRIPTION
    Creates the standard Anokye directory structure under a target path, including
    .github/skills, .github/workflows, .github/ISSUE_TEMPLATE, scripts, and docs/adr.
    Optionally copies template files (.gitignore, .editorconfig) and initializes stub files.

    This script handles initial repo structure setup. For automation gap analysis
    on an existing repository, use Initialize-RepoAutomation.ps1 instead.

.PARAMETER Path
    Target directory where the repository root will be created.

.PARAMETER RepoName
    Name of the repository being initialized. Used as the root subdirectory name.

.PARAMETER IncludeTemplates
    When specified, copies template files (.gitignore, .editorconfig) into the target.
    Templates are sourced from the scripts/templates/ directory alongside this script.

.PARAMETER DryRun
    Shows what would be created without writing any files.

.EXAMPLE
    ./Initialize-AnokyeRepo.ps1 -Path ~/repos -RepoName my-new-repo
    Creates the standard directory structure at ~/repos/my-new-repo/.

.EXAMPLE
    ./Initialize-AnokyeRepo.ps1 -Path ~/repos -RepoName my-new-repo -IncludeTemplates
    Creates the directory structure and copies .gitignore and .editorconfig templates.

.EXAMPLE
    ./Initialize-AnokyeRepo.ps1 -Path ~/repos -RepoName my-new-repo -DryRun
    Shows what would be created without writing any files.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$RepoName,

    [Parameter()]
    [switch]$IncludeTemplates,

    [Parameter()]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = Join-Path $Path $RepoName

$directories = @(
    '.github/skills',
    '.github/workflows',
    '.github/ISSUE_TEMPLATE',
    'scripts',
    'docs/adr'
)

$stubs = @{
    'docs/adr/README.md' = @"
# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for $RepoName.

## Format

Each ADR is a Markdown file named `NNN-short-title.md` (e.g., `001-use-powershell.md`).

## Resources

- [Michael Nygard's ADR format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
"@
}

$directoriesCreated = [System.Collections.Generic.List[string]]::new()
$directoriesSkipped = [System.Collections.Generic.List[string]]::new()
$stubsCreated = [System.Collections.Generic.List[string]]::new()
$templatesCopied = [System.Collections.Generic.List[string]]::new()

# Create directories
foreach ($dir in $directories) {
    $fullPath = Join-Path $repoRoot $dir
    if ($DryRun) {
        Write-Host "[DryRun] Would create directory: $fullPath"
        $directoriesCreated.Add($fullPath)
    } elseif (Test-Path $fullPath) {
        Write-Verbose "Already exists: $fullPath"
        $directoriesSkipped.Add($fullPath)
    } else {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "Created directory: $fullPath"
        $directoriesCreated.Add($fullPath)
    }
}

# Initialize stub files
foreach ($stub in $stubs.GetEnumerator()) {
    $fullPath = Join-Path $repoRoot $stub.Key
    if ($DryRun) {
        Write-Host "[DryRun] Would create stub: $fullPath"
        $stubsCreated.Add($fullPath)
    } elseif (Test-Path $fullPath) {
        Write-Verbose "Stub already exists: $fullPath"
    } else {
        $stub.Value | Set-Content -Path $fullPath -Encoding UTF8
        Write-Host "Created stub: $fullPath"
        $stubsCreated.Add($fullPath)
    }
}

# Copy template files
if ($IncludeTemplates) {
    $templatesDir = Join-Path $PSScriptRoot 'templates'
    $templateFiles = @('.gitignore', '.editorconfig')

    foreach ($template in $templateFiles) {
        $source = Join-Path $templatesDir $template
        $dest = Join-Path $repoRoot $template

        if (-not (Test-Path $source)) {
            Write-Warning "Template not found, skipping: $source"
            continue
        }

        if ($DryRun) {
            Write-Host "[DryRun] Would copy template: $template -> $dest"
            $templatesCopied.Add($dest)
        } else {
            Copy-Item -Path $source -Destination $dest -Force
            Write-Host "Copied template: $template"
            $templatesCopied.Add($dest)
        }
    }
}

[PSCustomObject]@{
    RepoName           = $RepoName
    Path               = $repoRoot
    DirectoriesCreated = $directoriesCreated.ToArray()
    DirectoriesSkipped = $directoriesSkipped.ToArray()
    StubsCreated       = $stubsCreated.ToArray()
    TemplatesCopied    = $templatesCopied.ToArray()
    DryRun             = $DryRun.IsPresent
}
