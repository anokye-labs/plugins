<#
.SYNOPSIS
    Validates that the plugin installs correctly into a test repository.

.DESCRIPTION
    Creates a temporary test repository, installs the plugin, and verifies:
    - Installation completes without errors
    - All expected files are present
    - Skill files load without syntax errors
    - manifest.json is valid JSON

.EXAMPLE
    .\Validate-PluginInstall.ps1
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
$installScript = Join-Path $omanfoRoot "scripts\Install-Plugin.ps1"

Write-Host "📦 Validating Plugin Installation" -ForegroundColor Cyan
Write-Host "   Install script: $installScript`n" -ForegroundColor Gray

# Create temporary test repo
$testRepoPath = Join-Path ([System.IO.Path]::GetTempPath()) "test-omanfo-install-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Creating test repository at: $testRepoPath" -ForegroundColor White

try {
    New-Item -ItemType Directory -Path $testRepoPath -Force | Out-Null
    Push-Location $testRepoPath
    
    # Initialize git repo
    git init -q
    git config user.email "ci@test.local"
    git config user.name "CI Test"
    
    Write-ValidationResult "Test repository created" (Test-Path ".git")

    # Run installation
    Write-Host "`nRunning installation..." -ForegroundColor White
    $installOutput = & $installScript -TargetRepo $testRepoPath -Force 2>&1
    $installSuccess = $null -eq $LASTEXITCODE -or $LASTEXITCODE -eq 0
    
    Write-ValidationResult "Installation completed successfully" $installSuccess
    
    if (-not $installSuccess) {
        Write-Host "`nInstallation output:" -ForegroundColor Yellow
        Write-Host $installOutput
    }

    # Verify skill directory structure
    Write-Host "`nValidating installed files..." -ForegroundColor White
    
    $skillPath = Join-Path $testRepoPath ".github\skills\okyerema"
    Write-ValidationResult "Skill directory exists" (Test-Path $skillPath)
    
    # Check SKILL.md
    $skillMd = Join-Path $skillPath "SKILL.md"
    Write-ValidationResult "SKILL.md exists" (Test-Path $skillMd)
    
    if (Test-Path $skillMd) {
        $skillContent = Get-Content $skillMd -Raw
        $hasYamlFrontmatter = $skillContent -match '(?s)^---\s*\n.*?\n---'
        Write-ValidationResult "SKILL.md has valid YAML frontmatter" $hasYamlFrontmatter
    }
    
    # Check scripts directory
    $scriptsPath = Join-Path $skillPath "scripts"
    Write-ValidationResult "Scripts directory exists" (Test-Path $scriptsPath)
    
    if (Test-Path $scriptsPath) {
        $scriptFiles = Get-ChildItem $scriptsPath -Filter "*.ps1" -File
        Write-ValidationResult "Scripts directory contains PowerShell files ($($scriptFiles.Count) found)" ($scriptFiles.Count -gt 0)
        
        # Validate each script for syntax errors
        foreach ($scriptFile in $scriptFiles) {
            $syntaxErrors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptFile.FullName -Raw), [ref]$syntaxErrors)
            $hasSyntaxErrors = $syntaxErrors.Count -gt 0
            Write-ValidationResult "Script '$($scriptFile.Name)' has no syntax errors" (-not $hasSyntaxErrors)
        }
    }
    
    # Check references directory
    $referencesPath = Join-Path $skillPath "references"
    Write-ValidationResult "References directory exists" (Test-Path $referencesPath)
    
    if (Test-Path $referencesPath) {
        $referenceFiles = Get-ChildItem $referencesPath -Filter "*.md" -File
        Write-ValidationResult "References directory contains markdown files ($($referenceFiles.Count) found)" ($referenceFiles.Count -gt 0)
    }
    
    # Check documentation files (if not skipped)
    $howWeWorkPath = Join-Path $testRepoPath "how-we-work.md"
    Write-ValidationResult "how-we-work.md exists" (Test-Path $howWeWorkPath)
    
    $agentsMdPath = Join-Path $testRepoPath "agents.md"
    Write-ValidationResult "agents.md exists" (Test-Path $agentsMdPath)
    
    # Validate manifest.json is valid
    Write-Host "`nValidating manifest.json..." -ForegroundColor White
    $manifestPath = Join-Path $omanfoRoot "manifest.json"
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-ValidationResult "manifest.json is valid JSON" $true
        
        # Check required fields
        $hasName = -not [string]::IsNullOrWhiteSpace($manifest.name)
        Write-ValidationResult "manifest.json has 'name' field" $hasName
        
        $hasVersion = -not [string]::IsNullOrWhiteSpace($manifest.version)
        Write-ValidationResult "manifest.json has 'version' field" $hasVersion
        
        $hasSkill = $null -ne $manifest.skill
        Write-ValidationResult "manifest.json has 'skill' section" $hasSkill
    }
    catch {
        Write-ValidationResult "manifest.json is valid JSON" $false
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }

} finally {
    Pop-Location
    
    # Cleanup test repo
    if (Test-Path $testRepoPath) {
        Write-Host "`nCleaning up test repository..." -ForegroundColor Gray
        Remove-Item $testRepoPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
if ($script:FailureCount -eq 0) {
    Write-Host "✅ All plugin installation checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Plugin installation validation failed with $script:FailureCount error(s)" -ForegroundColor Red
    exit 1
}
