#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate plugin coverage report for capabilities and evaluations.

.DESCRIPTION
    Reads manifest.json to identify declared capabilities (scripts and evaluations),
    scans the plugin directory structure to find actual scripts and evaluation files,
    and reports on coverage status. Exits with code 1 if any capability lacks validation.

.PARAMETER PluginPath
    Path to the plugin directory. Defaults to 'omanfo' relative to repository root.

.PARAMETER OutputFormat
    Output format: 'json', 'text', or 'both'. Defaults to 'both'.

.PARAMETER MinimumCoverage
    Minimum coverage percentage required (0-100). Defaults to 100.

.EXAMPLE
    ./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo

.EXAMPLE
    ./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo -OutputFormat json

.EXAMPLE
    ./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo -MinimumCoverage 80
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PluginPath = "omanfo",

    [Parameter()]
    [ValidateSet('json', 'text', 'both')]
    [string]$OutputFormat = "both",

    [Parameter()]
    [ValidateRange(0, 100)]
    [int]$MinimumCoverage = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve plugin path to absolute
if (-not [System.IO.Path]::IsPathRooted($PluginPath)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $PluginPath = Join-Path $repoRoot $PluginPath
}

if (-not (Test-Path $PluginPath)) {
    Write-Error "Plugin path not found: $PluginPath"
    exit 1
}

# Read manifest.json
$manifestPath = Join-Path $PluginPath "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Error "manifest.json not found at: $manifestPath"
    exit 1
}

try {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Failed to parse manifest.json: $_"
    exit 1
}

# Extract declared counts from manifest
# Support both old format (skill) and new format (skills array)
$declaredScripts = 0
$actualScripts = @()

if ($manifest.PSObject.Properties['skills']) {
    # New format: array of skills - aggregate scripts across all skills
    if ($manifest.skills.Count -eq 0) {
        Write-Error "Manifest has 'skills' array but it is empty. At least one skill must be defined."
        exit 1
    }
    
    foreach ($skill in $manifest.skills) {
        $declaredScripts += $skill.scripts
        
        # Scan for actual scripts for each skill
        $scriptsPath = Join-Path $PluginPath $skill.path "scripts"
        if (Test-Path $scriptsPath) {
            $actualScripts += @(Get-ChildItem -Path $scriptsPath -Filter "*.ps1" -File | Select-Object -ExpandProperty Name)
        }
    }
} elseif ($manifest.PSObject.Properties['skill']) {
    # Old format: single skill object
    $declaredScripts = $manifest.skill.scripts
    
    # Scan for actual scripts
    $scriptsPath = Join-Path $PluginPath $manifest.skill.path "scripts"
    if (Test-Path $scriptsPath) {
        $actualScripts = @(Get-ChildItem -Path $scriptsPath -Filter "*.ps1" -File | Select-Object -ExpandProperty Name)
    }
} else {
    Write-Error "No 'skill' or 'skills' property found in manifest"
    exit 1
}

$declaredEvaluations = $manifest.evaluations.count

# Scan for actual evaluation files
$evaluationsPath = Join-Path $PluginPath $manifest.evaluations.path
$actualEvaluations = @()
if (Test-Path $evaluationsPath) {
    $actualEvaluations = @(Get-ChildItem -Path $evaluationsPath -Filter "*.eval.md" -File | Select-Object -ExpandProperty Name)
}

# Calculate coverage
$scriptCoverage = if ($declaredScripts -gt 0) { 
    [math]::Round(($actualScripts.Count / $declaredScripts) * 100, 2) 
} else { 
    100 
}

$evaluationCoverage = if ($declaredEvaluations -gt 0) { 
    [math]::Round(($actualEvaluations.Count / $declaredEvaluations) * 100, 2) 
} else { 
    100 
}

$overallCoverage = if (($declaredScripts + $declaredEvaluations) -gt 0) {
    [math]::Round((($actualScripts.Count + $actualEvaluations.Count) / ($declaredScripts + $declaredEvaluations)) * 100, 2)
} else {
    100
}

# Determine status
# When MinimumCoverage < 100, use only percentage check (not raw count checks)
# This allows gradual coverage improvement without requiring 100% immediately
if ($MinimumCoverage -eq 100) {
    # Strict mode: require exact count match AND 100% coverage
    $scriptsMet = $actualScripts.Count -ge $declaredScripts
    $evaluationsMet = $actualEvaluations.Count -ge $declaredEvaluations
    $coverageMet = $overallCoverage -ge $MinimumCoverage
    $allPassed = $scriptsMet -and $evaluationsMet -and $coverageMet
} else {
    # Percentage mode: require only that coverage meets threshold
    $scriptsMet = $scriptCoverage -ge $MinimumCoverage
    $evaluationsMet = $evaluationCoverage -ge $MinimumCoverage
    $coverageMet = $overallCoverage -ge $MinimumCoverage
    $allPassed = $coverageMet
}

# Build report object
$report = [PSCustomObject]@{
    Plugin = $manifest.name
    Version = $manifest.version
    Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Scripts = [PSCustomObject]@{
        Declared = $declaredScripts
        Actual = $actualScripts.Count
        Coverage = $scriptCoverage
        Status = if ($scriptsMet) { "✓ PASS" } else { "✗ FAIL" }
        Files = $actualScripts
    }
    Evaluations = [PSCustomObject]@{
        Declared = $declaredEvaluations
        Actual = $actualEvaluations.Count
        Coverage = $evaluationCoverage
        Status = if ($evaluationsMet) { "✓ PASS" } else { "✗ FAIL" }
        Files = $actualEvaluations
    }
    Overall = [PSCustomObject]@{
        Coverage = $overallCoverage
        MinimumRequired = $MinimumCoverage
        Status = if ($allPassed) { "✓ PASS" } else { "✗ FAIL" }
    }
}

# Output JSON if requested
if ($OutputFormat -eq 'json' -or $OutputFormat -eq 'both') {
    $jsonOutput = $report | ConvertTo-Json -Depth 10
    if ($OutputFormat -eq 'json') {
        Write-Output $jsonOutput
    }
    else {
        # Save to file for 'both' mode
        $jsonPath = Join-Path $PSScriptRoot "coverage-report.json"
        $jsonOutput | Out-File -FilePath $jsonPath -Encoding utf8
        Write-Verbose "JSON report saved to: $jsonPath"
    }
}

# Output human-readable if requested
if ($OutputFormat -eq 'text' -or $OutputFormat -eq 'both') {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           PLUGIN COVERAGE REPORT                               ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Plugin:    $($manifest.name) v$($manifest.version)"
    Write-Host "Generated: $($report.Timestamp)"
    Write-Host ""
    
    Write-Host "┌─ SCRIPTS ─────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  Declared:  $declaredScripts"
    Write-Host "  Actual:    $($actualScripts.Count)"
    Write-Host "  Coverage:  $scriptCoverage%"
    $statusColor = if ($scriptsMet) { "Green" } else { "Red" }
    Write-Host "  Status:    $($report.Scripts.Status)" -ForegroundColor $statusColor
    
    if ($actualScripts.Count -gt 0) {
        Write-Host ""
        Write-Host "  Files found:" -ForegroundColor Gray
        foreach ($script in $actualScripts | Sort-Object) {
            Write-Host "    • $script" -ForegroundColor Gray
        }
    }
    Write-Host "└───────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "┌─ EVALUATIONS ─────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  Declared:  $declaredEvaluations"
    Write-Host "  Actual:    $($actualEvaluations.Count)"
    Write-Host "  Coverage:  $evaluationCoverage%"
    $statusColor = if ($evaluationsMet) { "Green" } else { "Red" }
    Write-Host "  Status:    $($report.Evaluations.Status)" -ForegroundColor $statusColor
    
    if ($actualEvaluations.Count -gt 0) {
        Write-Host ""
        Write-Host "  Files found:" -ForegroundColor Gray
        foreach ($eval in $actualEvaluations | Sort-Object) {
            Write-Host "    • $eval" -ForegroundColor Gray
        }
    }
    Write-Host "└───────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "┌─ OVERALL ─────────────────────────────────────────────────────┐" -ForegroundColor Magenta
    Write-Host "  Total Declared:   $($declaredScripts + $declaredEvaluations)"
    Write-Host "  Total Actual:     $($actualScripts.Count + $actualEvaluations.Count)"
    Write-Host "  Coverage:         $overallCoverage%"
    Write-Host "  Minimum Required: $MinimumCoverage%"
    $statusColor = if ($allPassed) { "Green" } else { "Red" }
    Write-Host "  Status:           $($report.Overall.Status)" -ForegroundColor $statusColor
    Write-Host "└───────────────────────────────────────────────────────────────┘" -ForegroundColor Magenta
    Write-Host ""
    
    if (-not $allPassed) {
        Write-Host "ISSUES FOUND:" -ForegroundColor Red
        if (-not $scriptsMet) {
            Write-Host "  ✗ Scripts: Expected $declaredScripts, found $($actualScripts.Count)" -ForegroundColor Red
        }
        if (-not $evaluationsMet) {
            Write-Host "  ✗ Evaluations: Expected $declaredEvaluations, found $($actualEvaluations.Count)" -ForegroundColor Red
        }
        if (-not $coverageMet) {
            Write-Host "  ✗ Coverage: $overallCoverage% is below minimum $MinimumCoverage%" -ForegroundColor Red
        }
        Write-Host ""
    }
}

# Exit with appropriate code
if ($allPassed) {
    exit 0
}
else {
    exit 1
}
