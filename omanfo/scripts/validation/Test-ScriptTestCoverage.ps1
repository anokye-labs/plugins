# Test-ScriptTestCoverage.ps1
# Validates that all PowerShell scripts have corresponding unit tests

param(
    [Parameter(Mandatory)]
    [string]$PluginPath
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TEST: Script Test Coverage" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$pluginRoot = Join-Path $repoRoot $PluginPath

# Check if plugin directory exists
if (-not (Test-Path $pluginRoot)) {
    Write-Host "ℹ Plugin directory not found: $pluginRoot" -ForegroundColor Cyan
    Write-Host "✓ Skipping test coverage validation (plugin may not exist yet)" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Read manifest to discover skills with scripts
$manifestPath = Join-Path $pluginRoot "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Host "ℹ Manifest not found: $manifestPath" -ForegroundColor Cyan
    Write-Host "✓ Skipping test coverage validation (no manifest)" -ForegroundColor Green
    Write-Host ""
    exit 0
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

# Find skills with scripts > 0
$skillsWithScripts = $manifest.skills | Where-Object { $_.scripts -gt 0 }

if ($skillsWithScripts.Count -eq 0) {
    Write-Host "✓ No skills with scripts in this plugin - skipping test coverage validation" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Process each skill with scripts
$allScriptFiles = @()
$allScriptsDirs = @()

foreach ($skill in $skillsWithScripts) {
    $scriptsDir = Join-Path $pluginRoot $skill.path "scripts"
    
    if (-not (Test-Path $scriptsDir)) {
        Write-Host "⚠ Scripts directory not found for skill '$($skill.name)': $scriptsDir" -ForegroundColor Yellow
        continue
    }
    
    $allScriptsDirs += $scriptsDir
    
    $scriptFiles = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -File | 
        Where-Object { $_.Name -notmatch '^_' } |  # Exclude helper files starting with _
        Select-Object -ExpandProperty BaseName
    
    $allScriptFiles += $scriptFiles
}

if ($allScriptFiles.Count -eq 0) {
    Write-Host "✓ No scripts found in plugin - skipping test coverage validation" -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host "Found $($allScriptFiles.Count) script(s) across $($allScriptsDirs.Count) skill(s)" -ForegroundColor Gray
Write-Host ""

# 2. Parse all Describe blocks in tests/{PluginPath}/unit/*.Unit.Tests.ps1
$testsDir = Join-Path $repoRoot "tests/$PluginPath/unit"

if (-not (Test-Path $testsDir)) {
    Write-Host "✗ Tests directory not found: $testsDir" -ForegroundColor Red
    exit 1
}

$testFiles = Get-ChildItem -Path $testsDir -Filter "*.Unit.Tests.ps1" -File

$describeBlocks = @()
foreach ($testFile in $testFiles) {
    $content = Get-Content $testFile.FullName -Raw
    
    # Match Describe blocks with double or single quotes
    $matches = [regex]::Matches($content, 'Describe\s+["'']([^"'']+)["'']')
    
    foreach ($match in $matches) {
        $describeBlocks += $match.Groups[1].Value
    }
}

Write-Host "Found $($describeBlocks.Count) Describe block(s) in test files:" -ForegroundColor Gray
foreach ($block in $describeBlocks | Sort-Object) {
    Write-Host "  - $block" -ForegroundColor Gray
}
Write-Host ""

# 3. Match script base names to Describe block names
$missingTests = @()

foreach ($script in $allScriptFiles) {
    if ($describeBlocks -notcontains $script) {
        $missingTests += $script
    }
}

# 4. Report results
if ($missingTests.Count -eq 0) {
    Write-Host "✓ All $($allScriptFiles.Count) scripts have test coverage" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "✗ $($missingTests.Count) script(s) missing test coverage:" -ForegroundColor Red
    Write-Host ""
    
    foreach ($script in $missingTests | Sort-Object) {
        Write-Host "  ✗ $script.ps1" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Action Required:" -ForegroundColor Yellow
    Write-Host "  Add a Describe block for each missing script in tests/$PluginPath/unit/*.Unit.Tests.ps1" -ForegroundColor Gray
    Write-Host "  Example:" -ForegroundColor Gray
    Write-Host "    Describe `"ScriptName`" {" -ForegroundColor Gray
    Write-Host "      # Test cases here" -ForegroundColor Gray
    Write-Host "    }" -ForegroundColor Gray
    Write-Host ""
    
    exit 1
}
