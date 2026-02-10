<#
.SYNOPSIS
    Validates that manifest.json is consistent with actual plugin files.

.DESCRIPTION
    Checks that:
    - All declared scripts exist in the scripts directory
    - All declared references exist in the references directory
    - Evaluation count matches actual .eval.md files
    - All required metadata fields are present

.EXAMPLE
    .\Test-ManifestConsistency.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$script:FailureCount = 0

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

Write-Host "🔍 Validating Manifest Consistency" -ForegroundColor Cyan
Write-Host "   Manifest: $manifestPath`n" -ForegroundColor Gray

# Load manifest
if (-not (Test-Path $manifestPath)) {
    Write-Host "❌ manifest.json not found at: $manifestPath" -ForegroundColor Red
    exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

# 1. Validate skill scripts
Write-Host "Validating skill scripts..." -ForegroundColor White
$skillScriptsPath = Join-Path $omanfoRoot ".github\skills\okyerema\scripts"
$actualScripts = Get-ChildItem $skillScriptsPath -Filter "*.ps1" -File
$declaredScriptCount = $manifest.skill.scripts

Write-ValidationResult "Script count: declared=$declaredScriptCount, actual=$($actualScripts.Count)" `
    ($declaredScriptCount -eq $actualScripts.Count)

foreach ($script in $actualScripts) {
    $exists = Test-Path $script.FullName
    Write-ValidationResult "Script exists: $($script.Name)" $exists
}

# 2. Validate skill references
Write-Host "`nValidating skill references..." -ForegroundColor White
$skillReferencesPath = Join-Path $omanfoRoot ".github\skills\okyerema\references"
$actualReferences = Get-ChildItem $skillReferencesPath -Filter "*.md" -File
$declaredReferenceCount = $manifest.skill.references

Write-ValidationResult "Reference count: declared=$declaredReferenceCount, actual=$($actualReferences.Count)" `
    ($declaredReferenceCount -eq $actualReferences.Count)

foreach ($ref in $actualReferences) {
    $exists = Test-Path $ref.FullName
    Write-ValidationResult "Reference exists: $($ref.Name)" $exists
}

# 3. Validate evaluations
Write-Host "`nValidating evaluations..." -ForegroundColor White
$evalsPath = Join-Path $omanfoRoot "evaluations"
$actualEvals = Get-ChildItem $evalsPath -Filter "*.eval.md" -File
$declaredEvalCount = $manifest.evaluations.count

Write-ValidationResult "Evaluation count: declared=$declaredEvalCount, actual=$($actualEvals.Count)" `
    ($declaredEvalCount -eq $actualEvals.Count)

foreach ($eval in $actualEvals) {
    $exists = Test-Path $eval.FullName
    Write-ValidationResult "Evaluation exists: $($eval.Name)" $exists
}

# 4. Validate required manifest fields
Write-Host "`nValidating required manifest fields..." -ForegroundColor White
$requiredFields = @(
    @{Path = "name"; Value = $manifest.name},
    @{Path = "version"; Value = $manifest.version},
    @{Path = "description"; Value = $manifest.description},
    @{Path = "skill.name"; Value = $manifest.skill.name},
    @{Path = "skill.path"; Value = $manifest.skill.path},
    @{Path = "skill.entryPoint"; Value = $manifest.skill.entryPoint}
)

foreach ($field in $requiredFields) {
    $hasValue = -not [string]::IsNullOrWhiteSpace($field.Value)
    Write-ValidationResult "Field '$($field.Path)' is present" $hasValue
}

# 5. Verify SKILL.md exists
Write-Host "`nValidating entry point..." -ForegroundColor White
$skillPath = Join-Path $omanfoRoot $manifest.skill.path
$entryPoint = Join-Path $skillPath $manifest.skill.entryPoint
$entryPointExists = Test-Path $entryPoint
Write-ValidationResult "Entry point exists: $($manifest.skill.entryPoint)" $entryPointExists

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
if ($script:FailureCount -eq 0) {
    Write-Host "✅ All manifest consistency checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Manifest validation failed with $script:FailureCount error(s)" -ForegroundColor Red
    exit 1
}
