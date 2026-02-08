<#
.SYNOPSIS
    Verifies the Okyerema plugin installation in a target repository.

.DESCRIPTION
    Checks that all required files are present, scripts are executable,
    and the GitHub CLI is properly configured. Used as a post-install check.

.PARAMETER TargetRepo
    Path to the target repository root. Defaults to current directory.

.PARAMETER Owner
    GitHub organization name for verifying issue type access.

.EXAMPLE
    .\Verify-Installation.ps1 -TargetRepo C:\repos\my-project -Owner anokye-labs
#>
[CmdletBinding()]
param(
    [string]$TargetRepo = ".",
    [string]$Owner
)

$ErrorActionPreference = "Continue"
$TargetRepo = Resolve-Path $TargetRepo
$passed = 0
$failed = 0
$warnings = 0

function Test-Check {
    param([string]$Name, [scriptblock]$Check)

    try {
        $result = & $Check
        if ($result) {
            Write-Host "  ✅ $Name" -ForegroundColor Green
            $script:passed++
        } else {
            Write-Host "  ❌ $Name" -ForegroundColor Red
            $script:failed++
        }
    } catch {
        Write-Host "  ❌ $Name — $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
    }
}

function Test-Warning {
    param([string]$Name, [scriptblock]$Check)

    try {
        $result = & $Check
        if ($result) {
            Write-Host "  ✅ $Name" -ForegroundColor Green
            $script:passed++
        } else {
            Write-Host "  ⚠️  $Name" -ForegroundColor Yellow
            $script:warnings++
        }
    } catch {
        Write-Host "  ⚠️  $Name — $($_.Exception.Message)" -ForegroundColor Yellow
        $script:warnings++
    }
}

Write-Host "`n🔍 Verifying Okyerema Plugin Installation" -ForegroundColor Cyan
Write-Host "   Target: $TargetRepo`n" -ForegroundColor Gray

# Skill structure
Write-Host "Skill Structure:" -ForegroundColor White
$skillDir = Join-Path $TargetRepo ".github\skills\okyerema"
Test-Check "SKILL.md exists" { Test-Path (Join-Path $skillDir "SKILL.md") }

$requiredRefs = @("issue-types.md", "relationships.md", "projects.md", "pr-reviews.md", "labels.md", "errors.md")
foreach ($ref in $requiredRefs) {
    Test-Check "references/$ref" { Test-Path (Join-Path $skillDir "references\$ref") }
}

$requiredScripts = @("Get-IssueTypeIds.ps1", "New-IssueWithType.ps1", "Update-IssueHierarchy.ps1",
                      "Test-Hierarchy.ps1", "Get-UnresolvedThreads.ps1", "Reply-ReviewThread.ps1",
                      "Resolve-ReviewThreads.ps1")
foreach ($script in $requiredScripts) {
    Test-Check "scripts/$script" { Test-Path (Join-Path $skillDir "scripts\$script") }
}

# Documentation
Write-Host "`nDocumentation:" -ForegroundColor White
Test-Warning "how-we-work.md" { Test-Path (Join-Path $TargetRepo "how-we-work.md") }
Test-Warning "how-we-work/getting-started.md" { Test-Path (Join-Path $TargetRepo "how-we-work\getting-started.md") }
Test-Warning "how-we-work/our-way.md" { Test-Path (Join-Path $TargetRepo "how-we-work\our-way.md") }
Test-Warning "how-we-work/glossary.md" { Test-Path (Join-Path $TargetRepo "how-we-work\glossary.md") }
Test-Warning "agents.md" { Test-Path (Join-Path $TargetRepo "agents.md") }

# Prerequisites
Write-Host "`nPrerequisites:" -ForegroundColor White
Test-Check "Git repository" { Test-Path (Join-Path $TargetRepo ".git") }
Test-Check "PowerShell 7+" { $PSVersionTable.PSVersion.Major -ge 7 }
Test-Check "GitHub CLI installed" { Get-Command gh -ErrorAction SilentlyContinue }
Test-Check "GitHub CLI authenticated" {
    $status = gh auth status 2>&1
    $LASTEXITCODE -eq 0
}

# Organization access
if ($Owner) {
    Write-Host "`nOrganization Access ($Owner):" -ForegroundColor White
    Test-Check "Can query issue types" {
        $result = gh api graphql -f query="{ organization(login: `"$Owner`") { issueTypes(first: 5) { nodes { name id } } } }" 2>&1
        $LASTEXITCODE -eq 0
    }
}

# SKILL.md quality
Write-Host "`nSkill Quality:" -ForegroundColor White
$skillPath = Join-Path $skillDir "SKILL.md"
if (Test-Path $skillPath) {
    $lineCount = (Get-Content $skillPath).Count
    Test-Check "SKILL.md under 500 lines ($lineCount lines)" { $lineCount -lt 500 }

    $content = Get-Content $skillPath -Raw
    Test-Check "Has YAML frontmatter" { $content -match "^---" }
    Test-Check "Has description in frontmatter" { $content -match "description:" }
}

# Summary
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "Results: $passed passed, $failed failed, $warnings warnings" -ForegroundColor $(if ($failed -gt 0) { "Red" } elseif ($warnings -gt 0) { "Yellow" } else { "Green" })

if ($failed -gt 0) {
    Write-Host "❌ Installation has issues that need to be resolved." -ForegroundColor Red
    exit 1
} elseif ($warnings -gt 0) {
    Write-Host "⚠️  Installation OK with optional items missing." -ForegroundColor Yellow
} else {
    Write-Host "✅ Installation verified successfully!" -ForegroundColor Green
}
