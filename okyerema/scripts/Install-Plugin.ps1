<#
.SYNOPSIS
    Installs the Okyerema plugin into a target repository.

.DESCRIPTION
    Copies the Okyerema skill files, documentation, and agent entry point
    into the target repository. Optionally skips documentation or agent files.

.PARAMETER TargetRepo
    Path to the target repository root. Defaults to current directory.

.PARAMETER SkipDocs
    Skip copying how-we-work documentation files.

.PARAMETER SkipAgents
    Skip copying agents.md entry point.

.PARAMETER Force
    Overwrite existing files without prompting.

.EXAMPLE
    .\Install-Plugin.ps1 -TargetRepo C:\repos\my-project
    .\Install-Plugin.ps1 -TargetRepo . -SkipDocs
    .\Install-Plugin.ps1 -Force
#>
[CmdletBinding()]
param(
    [string]$TargetRepo = ".",
    [switch]$SkipDocs,
    [switch]$SkipAgents,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$pluginRoot = Split-Path -Parent $PSScriptRoot

# Resolve to absolute path
$TargetRepo = Resolve-Path $TargetRepo

# Verify target is a git repo
if (-not (Test-Path (Join-Path $TargetRepo ".git"))) {
    Write-Error "Target path is not a git repository: $TargetRepo"
    return
}

function Copy-PluginFiles {
    param([string]$Source, [string]$Destination, [string]$Label)

    if (Test-Path $Destination) {
        if (-not $Force) {
            $response = Read-Host "$Label already exists at $Destination. Overwrite? (y/N)"
            if ($response -ne 'y') {
                Write-Host "  Skipping $Label" -ForegroundColor Yellow
                return
            }
        }
    }

    $destDir = Split-Path -Parent $Destination
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Copy-Item -Path $Source -Destination $Destination -Force -Recurse
    Write-Host "  ✅ $Label" -ForegroundColor Green
}

Write-Host "`n🥁 Installing Okyerema Plugin" -ForegroundColor Cyan
Write-Host "   Target: $TargetRepo`n" -ForegroundColor Gray

# 1. Install skill files (always)
$skillSrc = Join-Path $pluginRoot ".github\skills\okyerema"
$skillDst = Join-Path $TargetRepo ".github\skills\okyerema"

Write-Host "Installing skill files..." -ForegroundColor White
Copy-PluginFiles "$skillSrc\SKILL.md" "$skillDst\SKILL.md" "SKILL.md"

# References
$refSrc = Join-Path $skillSrc "references"
$refDst = Join-Path $skillDst "references"
if (-not (Test-Path $refDst)) { New-Item -ItemType Directory -Path $refDst -Force | Out-Null }
Get-ChildItem $refSrc -File | ForEach-Object {
    Copy-PluginFiles $_.FullName (Join-Path $refDst $_.Name) "references/$($_.Name)"
}

# Scripts
$scriptSrc = Join-Path $skillSrc "scripts"
$scriptDst = Join-Path $skillDst "scripts"
if (-not (Test-Path $scriptDst)) { New-Item -ItemType Directory -Path $scriptDst -Force | Out-Null }
Get-ChildItem $scriptSrc -File | ForEach-Object {
    Copy-PluginFiles $_.FullName (Join-Path $scriptDst $_.Name) "scripts/$($_.Name)"
}

# 2. Install documentation (optional)
if (-not $SkipDocs) {
    Write-Host "`nInstalling documentation..." -ForegroundColor White
    $docRoot = Join-Path $pluginRoot "how-we-work"
    Copy-PluginFiles (Join-Path $pluginRoot "how-we-work.md") (Join-Path $TargetRepo "how-we-work.md") "how-we-work.md"

    $hwwDst = Join-Path $TargetRepo "how-we-work"
    if (-not (Test-Path $hwwDst)) { New-Item -ItemType Directory -Path $hwwDst -Force | Out-Null }
    Get-ChildItem $docRoot -File | ForEach-Object {
        Copy-PluginFiles $_.FullName (Join-Path $hwwDst $_.Name) "how-we-work/$($_.Name)"
    }
}

# 3. Install agents.md (optional)
if (-not $SkipAgents) {
    Write-Host "`nInstalling agent entry point..." -ForegroundColor White
    Copy-PluginFiles (Join-Path $pluginRoot "agents.md") (Join-Path $TargetRepo "agents.md") "agents.md"
}

# Summary
$fileCount = (Get-ChildItem $skillDst -Recurse -File).Count
Write-Host "`n✅ Okyerema plugin installed successfully!" -ForegroundColor Green
Write-Host "   Skill files: $fileCount" -ForegroundColor Gray
Write-Host "   Location: $skillDst" -ForegroundColor Gray

# Verify org issue types
Write-Host "`n💡 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Verify org issue types: .github\skills\okyerema\scripts\Get-IssueTypeIds.ps1 -Owner <your-org>"
Write-Host "   2. Commit the installed files"
Write-Host "   3. Test with: @okyerema create a Feature issue titled 'Test'"
