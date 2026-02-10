<#
.SYNOPSIS
    Executes evaluation scenarios programmatically where possible.

.DESCRIPTION
    Runs automated checks from .eval.md files that can be validated programmatically:
    - File existence checks
    - Script syntax validation
    - JSON/YAML structure validation
    - Basic command execution tests
    
    For scenarios requiring human/agent observation, generates a checklist.

.PARAMETER EvalPath
    Path to specific evaluation file to run. If not provided, runs all.

.PARAMETER GenerateChecklist
    Generate human verification checklist for non-automatable scenarios.

.EXAMPLE
    .\Invoke-EvalScenarios.ps1
    .\Invoke-EvalScenarios.ps1 -EvalPath "01-install-verify.eval.md"
    .\Invoke-EvalScenarios.ps1 -GenerateChecklist
#>

[CmdletBinding()]
param(
    [string]$EvalPath,
    [switch]$GenerateChecklist
)

$ErrorActionPreference = "Stop"
$script:PassCount = 0
$script:FailCount = 0
$script:SkipCount = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Status,  # Pass, Fail, Skip
        [string]$Message = ""
    )
    
    switch ($Status) {
        "Pass" {
            Write-Host "  ✅ $TestName" -ForegroundColor Green
            $script:PassCount++
        }
        "Fail" {
            Write-Host "  ❌ $TestName" -ForegroundColor Red
            if ($Message) {
                Write-Host "     $Message" -ForegroundColor Red
            }
            $script:FailCount++
        }
        "Skip" {
            Write-Host "  ⏭️  $TestName" -ForegroundColor Yellow
            if ($Message) {
                Write-Host "     $Message" -ForegroundColor Gray
            }
            $script:SkipCount++
        }
    }
}

# Get paths
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$omanfoRoot = Join-Path $repoRoot "omanfo"
$evalsPath = Join-Path $omanfoRoot "evaluations"

Write-Host "🧪 Running Evaluation Scenarios" -ForegroundColor Cyan
Write-Host "   Evaluations path: $evalsPath`n" -ForegroundColor Gray

# Get evaluation files
if ($EvalPath) {
    $evalFiles = @(Get-Item (Join-Path $evalsPath $EvalPath))
} else {
    $evalFiles = Get-ChildItem $evalsPath -Filter "*.eval.md" -File | Sort-Object Name
}

Write-Host "Found $($evalFiles.Count) evaluation(s) to process`n" -ForegroundColor White

# Process each evaluation
foreach ($evalFile in $evalFiles) {
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Evaluation: $($evalFile.Name)" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    
    $evalContent = Get-Content $evalFile.FullName -Raw
    
    # Extract evaluation name (e.g., "01-install-verify" -> "Install & Verification")
    if ($evalFile.Name -match '^\d+-(.+)\.eval\.md$') {
        $evalName = $matches[1]
    } else {
        $evalName = $evalFile.BaseName
    }
    
    # Run automated checks based on evaluation type
    switch -Regex ($evalName) {
        'install-verify' {
            # Check if Install-Plugin.ps1 exists and has no syntax errors
            $installScript = Join-Path $omanfoRoot "scripts\Install-Plugin.ps1"
            
            if (Test-Path $installScript) {
                Write-TestResult "Install script exists" "Pass"
                
                # Check syntax
                try {
                    $syntaxErrors = $null
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $installScript -Raw), [ref]$syntaxErrors)
                    if ($syntaxErrors.Count -eq 0) {
                        Write-TestResult "Install script has no syntax errors" "Pass"
                    } else {
                        Write-TestResult "Install script has no syntax errors" "Fail" "$($syntaxErrors.Count) syntax error(s)"
                    }
                } catch {
                    Write-TestResult "Install script syntax check" "Fail" $_.Exception.Message
                }
            } else {
                Write-TestResult "Install script exists" "Fail"
            }
            
            # Verify skill structure exists
            $skillPath = Join-Path $omanfoRoot ".github\skills\okyerema"
            Write-TestResult "Skill directory exists" $(if (Test-Path $skillPath) { "Pass" } else { "Fail" })
            
            $skillMd = Join-Path $skillPath "SKILL.md"
            Write-TestResult "SKILL.md exists" $(if (Test-Path $skillMd) { "Pass" } else { "Fail" })
        }
        
        'issue-types' {
            # Check if Get-IssueTypeIds.ps1 exists
            $script = Join-Path $omanfoRoot ".github\skills\okyerema\scripts\Get-IssueTypeIds.ps1"
            Write-TestResult "Get-IssueTypeIds.ps1 exists" $(if (Test-Path $script) { "Pass" } else { "Fail" })
            
            # Check if issue-types.md reference exists
            $ref = Join-Path $omanfoRoot ".github\skills\okyerema\references\issue-types.md"
            Write-TestResult "issue-types.md reference exists" $(if (Test-Path $ref) { "Pass" } else { "Fail" })
        }
        
        'create-issues' {
            # Check if New-IssueWithType.ps1 exists
            $script = Join-Path $omanfoRoot ".github\skills\okyerema\scripts\New-IssueWithType.ps1"
            Write-TestResult "New-IssueWithType.ps1 exists" $(if (Test-Path $script) { "Pass" } else { "Fail" })
        }
        
        'hierarchy' {
            # Check hierarchy-related scripts
            $scripts = @(
                "Update-IssueHierarchy.ps1",
                "Test-Hierarchy.ps1",
                "Get-HierarchyHealth.ps1"
            )
            
            foreach ($scriptName in $scripts) {
                $script = Join-Path $omanfoRoot ".github\skills\okyerema\scripts\$scriptName"
                Write-TestResult "$scriptName exists" $(if (Test-Path $script) { "Pass" } else { "Fail" })
            }
            
            # Check relationships.md reference
            $ref = Join-Path $omanfoRoot ".github\skills\okyerema\references\relationships.md"
            Write-TestResult "relationships.md reference exists" $(if (Test-Path $ref) { "Pass" } else { "Fail" })
        }
        
        'projects' {
            # Check projects.md reference
            $ref = Join-Path $omanfoRoot ".github\skills\okyerema\references\projects.md"
            Write-TestResult "projects.md reference exists" $(if (Test-Path $ref) { "Pass" } else { "Fail" })
        }
        
        'pr-reviews' {
            # Check PR review scripts
            $scripts = @(
                "Get-UnresolvedThreads.ps1",
                "Reply-ReviewThread.ps1",
                "Resolve-ReviewThreads.ps1",
                "Get-PRHealth.ps1"
            )
            
            foreach ($scriptName in $scripts) {
                $script = Join-Path $omanfoRoot ".github\skills\okyerema\scripts\$scriptName"
                Write-TestResult "$scriptName exists" $(if (Test-Path $script) { "Pass" } else { "Fail" })
            }
            
            # Check pr-reviews.md reference
            $ref = Join-Path $omanfoRoot ".github\skills\okyerema\references\pr-reviews.md"
            Write-TestResult "pr-reviews.md reference exists" $(if (Test-Path $ref) { "Pass" } else { "Fail" })
        }
        
        'labels' {
            # Check labels.md reference
            $ref = Join-Path $omanfoRoot ".github\skills\okyerema\references\labels.md"
            Write-TestResult "labels.md reference exists" $(if (Test-Path $ref) { "Pass" } else { "Fail" })
        }
        
        'end-to-end' {
            # Check Get-Sitrep.ps1 exists
            $script = Join-Path $omanfoRoot ".github\skills\okyerema\scripts\Get-Sitrep.ps1"
            Write-TestResult "Get-Sitrep.ps1 exists" $(if (Test-Path $script) { "Pass" } else { "Fail" })
            
            # This is primarily a manual evaluation
            Write-TestResult "End-to-end workflow verification" "Skip" "Requires manual testing"
        }
        
        default {
            Write-TestResult "Automated checks" "Skip" "No automated checks defined for this evaluation"
        }
    }
    
    Write-Host ""
}

# Generate checklist if requested
if ($GenerateChecklist) {
    $checklistPath = Join-Path $repoRoot "eval-checklist.md"
    Write-Host "📋 Generating human verification checklist..." -ForegroundColor Cyan
    
    $checklist = @"
# Evaluation Checklist

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

This checklist contains evaluation scenarios that require human or agent observation.

"@
    
    foreach ($evalFile in $evalFiles) {
        $evalContent = Get-Content $evalFile.FullName -Raw
        
        # Extract title from markdown
        if ($evalContent -match '# (.+)') {
            $title = $matches[1]
        } else {
            $title = $evalFile.BaseName
        }
        
        $checklist += @"

## $title

- [ ] Review $($evalFile.Name)
- [ ] Execute manual steps
- [ ] Verify expected outcomes
- [ ] Document any issues

"@
    }
    
    Set-Content -Path $checklistPath -Value $checklist
    Write-Host "✅ Checklist saved to: $checklistPath" -ForegroundColor Green
}

# Summary
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Test Summary:" -ForegroundColor White
Write-Host "  ✅ Passed: $script:PassCount" -ForegroundColor Green
Write-Host "  ❌ Failed: $script:FailCount" -ForegroundColor Red
Write-Host "  ⏭️  Skipped: $script:SkipCount" -ForegroundColor Yellow

if ($script:FailCount -eq 0) {
    Write-Host "`n✅ All automated evaluation checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Evaluation validation failed with $script:FailCount error(s)" -ForegroundColor Red
    exit 1
}
