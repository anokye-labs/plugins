<#
.SYNOPSIS
    Generates a coverage report showing validated vs unvalidated capabilities.

.DESCRIPTION
    Creates a markdown report summarizing:
    - Plugin coverage statistics
    - Features with/without evaluations
    - Test results
    - Coverage trends

.PARAMETER OutputPath
    Path where the report should be saved. Defaults to coverage-report.md in repo root.

.EXAMPLE
    .\New-CoverageReport.ps1
    .\New-CoverageReport.ps1 -OutputPath ./reports/coverage.md
#>

[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

# Get paths
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$omanfoRoot = Join-Path $repoRoot "omanfo"
$manifestPath = Join-Path $omanfoRoot "manifest.json"
$skillScriptsPath = Join-Path $omanfoRoot ".github\skills\okyerema\scripts"
$evalsPath = Join-Path $omanfoRoot "evaluations"

if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot "coverage-report.md"
}

Write-Host "📈 Generating Coverage Report" -ForegroundColor Cyan
Write-Host "   Output: $OutputPath`n" -ForegroundColor Gray

# Load manifest
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

# Get all skill scripts
$scripts = Get-ChildItem $skillScriptsPath -Filter "*.ps1" -File

# Get all evaluations
$evals = Get-ChildItem $evalsPath -Filter "*.eval.md" -File

# Build feature map
$features = @{}

# Map scripts to features
foreach ($script in $scripts) {
    $scriptName = $script.BaseName
    $featureName = switch -Regex ($scriptName) {
        'IssueType' { 'issue-types'; break }
        'Hierarchy|SubIssue|Parent' { 'hierarchy'; break }
        'Project' { 'projects'; break }
        'PR|Review|Thread' { 'pr-reviews'; break }
        'Label' { 'labels'; break }
        'Sitrep|Health' { 'end-to-end'; break }
        'New-IssueWithType' { 'create-issues'; break }
        default { $scriptName.ToLower(); break }
    }
    
    if (-not $features.ContainsKey($featureName)) {
        $features[$featureName] = @{
            Scripts = [System.Collections.ArrayList]::new()
            Evaluations = [System.Collections.ArrayList]::new()
        }
    }
    
    [void]$features[$featureName].Scripts.Add($script.Name)
}

# Map evaluations to features
foreach ($eval in $evals) {
    if ($eval.Name -match '^\d+-(.+)\.eval\.md$') {
        $featureName = $matches[1]
        
        if (-not $features.ContainsKey($featureName)) {
            $features[$featureName] = @{
                Scripts = [System.Collections.ArrayList]::new()
                Evaluations = [System.Collections.ArrayList]::new()
            }
        }
        
        [void]$features[$featureName].Evaluations.Add($eval.Name)
    }
}

# Calculate statistics
$totalFeatures = $features.Count
$coveredFeatures = ($features.Values | Where-Object { $_.Evaluations.Count -gt 0 }).Count
$coveragePercent = if ($totalFeatures -gt 0) {
    [math]::Round(($coveredFeatures / $totalFeatures) * 100, 2)
} else {
    0
}

# Generate report
$report = @"
# Omanfo Plugin Coverage Report

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")  
**Repository:** anokye-labs/plugins  
**Plugin:** Omanfo v$($manifest.version)

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Features | $totalFeatures |
| Covered Features | $coveredFeatures |
| **Coverage** | **$coveragePercent%** |
| Total Scripts | $($scripts.Count) |
| Total Evaluations | $($evals.Count) |

## Coverage Status

$(if ($coveragePercent -ge 80) {
    "✅ **PASS** - Coverage meets minimum threshold (80%)"
} elseif ($coveragePercent -ge 60) {
    "⚠️ **WARNING** - Coverage below recommended threshold (80%)"
} else {
    "❌ **FAIL** - Coverage critically low (minimum 80% required)"
})

## Feature Coverage Matrix

| Feature | Scripts | Evaluations | Status |
|---------|---------|-------------|--------|
"@

foreach ($featureName in $features.Keys | Sort-Object) {
    $feature = $features[$featureName]
    $scriptCount = $feature.Scripts.Count
    $evalCount = $feature.Evaluations.Count
    $status = if ($evalCount -gt 0) { "✅ Covered" } else { "❌ Missing" }
    
    $report += "`n| $featureName | $scriptCount | $evalCount | $status |"
}

$report += @"


## Detailed Feature Breakdown

"@

foreach ($featureName in $features.Keys | Sort-Object) {
    $feature = $features[$featureName]
    $status = if ($feature.Evaluations.Count -gt 0) { "✅" } else { "❌" }
    
    $report += @"

### $status $featureName

**Scripts ($($feature.Scripts.Count)):**
"@
    
    if ($feature.Scripts.Count -gt 0) {
        foreach ($script in $feature.Scripts | Sort-Object) {
            $report += "`n- $script"
        }
    } else {
        $report += "`n- _(none)_"
    }
    
    $report += "`n`n**Evaluations ($($feature.Evaluations.Count)):**"
    
    if ($feature.Evaluations.Count -gt 0) {
        foreach ($eval in $feature.Evaluations | Sort-Object) {
            $report += "`n- $eval"
        }
    } else {
        $report += "`n- ⚠️ **No evaluation coverage**"
    }
}

$report += @"


## Recommendations

"@

$uncoveredFeatures = $features.Keys | Where-Object { $features[$_].Evaluations.Count -eq 0 } | Sort-Object

if ($uncoveredFeatures.Count -gt 0) {
    $report += @"

### Missing Evaluations

The following features lack evaluation coverage and should have `.eval.md` files created:

"@
    foreach ($feature in $uncoveredFeatures) {
        $report += "`n- **$feature** - $($features[$feature].Scripts.Count) script(s) need validation"
    }
} else {
    $report += "`n✅ All features have evaluation coverage!"
}

$report += @"


## Plugin Manifest Summary

- **Name:** $($manifest.name)
- **Version:** $($manifest.version)
- **Skill:** $($manifest.skill.name)
- **Declared Scripts:** $($manifest.skill.scripts)
- **Declared References:** $($manifest.skill.references)
- **Declared Evaluations:** $($manifest.evaluations.count)

## Validation Results

This report was generated as part of the CI validation pipeline. For detailed test results, see the workflow run logs.

---

**Next Steps:**
1. Review uncovered features and create evaluation scenarios
2. Ensure all new features include corresponding `.eval.md` files
3. Run full evaluation suite: `.\omanfo\scripts\validation\Invoke-EvalScenarios.ps1`

"@

# Save report
Set-Content -Path $OutputPath -Value $report -Encoding UTF8

Write-Host "✅ Coverage report generated successfully!" -ForegroundColor Green
Write-Host "   Location: $OutputPath" -ForegroundColor Gray
Write-Host "   Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { "Green" } elseif ($coveragePercent -ge 60) { "Yellow" } else { "Red" })
