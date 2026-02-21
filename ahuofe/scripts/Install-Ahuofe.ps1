<#
.SYNOPSIS
    Installs the Ahuofe media plugin via the Copilot CLI.

.DESCRIPTION
    Installs the Ahuofe plugin (fal.ai, fal-workflow, image-sorcery, and
    media-agents skills) using `copilot plugin install`. Supports installation
    from the local source tree or from the remote GitHub repository.

.PARAMETER Source
    Plugin source: a local path, owner/repo, or owner/repo:path.
    Defaults to the ahuofe directory in this repository.

.PARAMETER Remote
    Install from the remote GitHub repository instead of the local source tree.

.EXAMPLE
    .\Install-Ahuofe.ps1
    .\Install-Ahuofe.ps1 -Remote
    .\Install-Ahuofe.ps1 -Source C:\path\to\ahuofe
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Source,
    [switch]$Remote
)

$ErrorActionPreference = "Stop"
$pluginRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Error "Copilot CLI is not installed. See: https://docs.github.com/copilot/concepts/agents/about-copilot-cli"
    return
}

if (-not $Source) {
    if ($Remote) {
        $Source = "anokye-labs/plugins:ahuofe"
    } else {
        $Source = $pluginRoot
    }
}

Write-Host "`n🎨 Installing Ahuofe plugin" -ForegroundColor Cyan
Write-Host "   Source: $Source`n" -ForegroundColor Gray

copilot plugin install $Source
if ($LASTEXITCODE -ne 0) {
    Write-Error "Plugin installation failed."
    return
}

Write-Host "`n💡 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Set your fal.ai API key: `$env:FAL_KEY = 'your-key'"
Write-Host "   2. Test with: 'Generate an image of a mountain landscape'"
