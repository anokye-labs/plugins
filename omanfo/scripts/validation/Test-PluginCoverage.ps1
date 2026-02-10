<#
.SYNOPSIS
    Validates plugin coverage - ensures every feature has validation tests and evaluations.

.DESCRIPTION
    Enforces the coverage matrix:
    - Every script in the skill must have a corresponding evaluation scenario
    - Every evaluation must test actual features
    - Coverage percentage is calculated and reported
    - Fails if coverage is below threshold

.PARAMETER MinimumCoverage
    Minimum coverage percentage required (default: 80)

.EXAMPLE
    .\Test-PluginCoverage.ps1
    .\Test-PluginCoverage.ps1 -MinimumCoverage 100
#>

[CmdletBinding()]
param(
    [int]$MinimumCoverage = 80
)

$ErrorActionPreference = "Stop"
$script:FailureCount = 0

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "ValidationHelpers.psm1") -Force

function Write-ValidationResult {
    param(
        [string]$Message,
        [bool]$Success
    )
    
    if ($Success) {
        Write-Host "  ✅ $Message" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $Message" -ForegroundColor Red
        $script:FailureCount++
    }
}

# Get paths
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$omanfoRoot = Join-Path $repoRoot "omanfo"
$manifestPath = Join-Path $omanfoRoot "manifest.json"
$skillScriptsPath = Join-Path $omanfoRoot ".github\skills\okyerema\scripts"
$evalsPath = Join-Path $omanfoRoot "evaluations"

Write-Host "📊 Validating Plugin Coverage" -ForegroundColor Cyan
Write-Host "   Minimum required: $MinimumCoverage%`n" -ForegroundColor Gray

# Load manifest
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

# Get all skill scripts
$scripts = Get-ChildItem $skillScriptsPath -Filter "*.ps1" -File
Write-Host "Found $($scripts.Count) skill scripts" -ForegroundColor White

# Get all evaluations
$evals = Get-ChildItem $evalsPath -Filter "*.eval.md" -File
Write-Host "Found $($evals.Count) evaluation scenarios`n" -ForegroundColor White

# Build feature map using shared helper
$features = Build-FeatureMap -ScriptPath $skillScriptsPath -EvalPath $evalsPath

# Analyze coverage
Write-Host "Coverage Analysis:" -ForegroundColor White
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host ("{0,-30} {1,-25} {2,-20}" -f "Feature", "Scripts", "Evaluations") -ForegroundColor Cyan
Write-Host ("{0,-30} {1,-25} {2,-20}" -f "-------", "-------", "-----------") -ForegroundColor Gray

$totalFeatures = $features.Count
$coveredFeatures = 0

foreach ($featureName in $features.Keys | Sort-Object) {
    $feature = $features[$featureName]
    $scriptCount = $feature.Scripts.Count
    $evalCount = $feature.Evaluations.Count
    
    $isCovered = $evalCount -gt 0
    if ($isCovered) {
        $coveredFeatures++
    }
    
    $status = if ($isCovered) { "✅" } else { "❌" }
    
    Write-Host ("{0,-30} {1,-25} {2,-20}" -f `
        "$status $featureName", `
        "$scriptCount script(s)", `
        "$evalCount eval(s)") `
        -ForegroundColor $(if ($isCovered) { "Green" } else { "Yellow" })
}

Write-Host ("=" * 80) -ForegroundColor Gray

# Calculate coverage percentage
$coveragePercent = if ($totalFeatures -gt 0) {
    [math]::Round(($coveredFeatures / $totalFeatures) * 100, 2)
} else {
    0
}

Write-Host "`nCoverage Summary:" -ForegroundColor White
Write-Host "  Total features: $totalFeatures" -ForegroundColor Gray
Write-Host "  Covered features: $coveredFeatures" -ForegroundColor Gray
Write-Host "  Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge $MinimumCoverage) { "Green" } else { "Red" })
Write-Host "  Minimum required: $MinimumCoverage%" -ForegroundColor Gray

# Validate specific requirements
Write-Host "`nValidating requirements..." -ForegroundColor White

# 1. Every script should map to at least one feature
$unmappedScripts = $scripts | Where-Object {
    $scriptName = $_.BaseName
    $mapped = $false
    foreach ($feature in $features.Values) {
        if ($feature.Scripts -contains $_.Name) {
            $mapped = $true
            break
        }
    }
    -not $mapped
}

Write-ValidationResult "All scripts are mapped to features" ($unmappedScripts.Count -eq 0)
if ($unmappedScripts.Count -gt 0) {
    foreach ($script in $unmappedScripts) {
        Write-Host "    Unmapped: $($script.Name)" -ForegroundColor Yellow
    }
}

# 2. Every evaluation should test actual features
$unmappedEvals = $evals | Where-Object {
    $evalName = $_.Name
    $mapped = $false
    foreach ($feature in $features.Values) {
        if ($feature.Evaluations -contains $evalName) {
            $mapped = $true
            break
        }
    }
    -not $mapped
}

Write-ValidationResult "All evaluations are mapped to features" ($unmappedEvals.Count -eq 0)
if ($unmappedEvals.Count -gt 0) {
    foreach ($eval in $unmappedEvals) {
        Write-Host "    Unmapped: $($eval.Name)" -ForegroundColor Yellow
    }
}

# 3. Check if coverage meets minimum threshold
$meetsCoverage = $coveragePercent -ge $MinimumCoverage
Write-ValidationResult "Coverage meets minimum threshold ($MinimumCoverage%)" $meetsCoverage

# 4. Check for features without evaluations
$featuresWithoutEvals = $features.Keys | Where-Object { $features[$_].Evaluations.Count -eq 0 }
if ($featuresWithoutEvals.Count -gt 0) {
    Write-Host "`n⚠️  Features without evaluations:" -ForegroundColor Yellow
    foreach ($feature in $featuresWithoutEvals) {
        Write-Host "    - $feature" -ForegroundColor Yellow
        foreach ($script in $features[$feature].Scripts) {
            Write-Host "        Script: $script" -ForegroundColor Gray
        }
    }
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
if ($script:FailureCount -eq 0 -and $meetsCoverage) {
    Write-Host "✅ All plugin coverage checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Plugin coverage validation failed" -ForegroundColor Red
    if (-not $meetsCoverage) {
        Write-Host "   Coverage is $coveragePercent%, required $MinimumCoverage%" -ForegroundColor Red
    }
    if ($script:FailureCount -gt 0) {
        Write-Host "   $script:FailureCount validation error(s)" -ForegroundColor Red
    }
    exit 1
}
