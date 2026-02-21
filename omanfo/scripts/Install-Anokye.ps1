<#
.SYNOPSIS
    Installs the Omanfo plugin via the Copilot CLI.

.DESCRIPTION
    Installs the Omanfo plugin (Okyeame agent, Okyerema coordinator, and project
    management skills) using `copilot plugin install`. Supports installation from
    the local source tree or from the remote GitHub repository.

.PARAMETER Source
    Plugin source: a local path, owner/repo, or owner/repo:path.
    Defaults to the omanfo directory in this repository.

.PARAMETER Remote
    Install from the remote GitHub repository instead of the local source tree.

.EXAMPLE
    .\Install-Anokye.ps1
    .\Install-Anokye.ps1 -Remote
    .\Install-Anokye.ps1 -Source C:\path\to\omanfo
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
        $Source = "anokye-labs/plugins:omanfo"
    } else {
        $Source = $pluginRoot
    }
}

Write-Host "`n🥁 Installing Omanfo plugin" -ForegroundColor Cyan
Write-Host "   Source: $Source`n" -ForegroundColor Gray

copilot plugin install $Source
if ($LASTEXITCODE -ne 0) {
    Write-Error "Plugin installation failed."
    return
}

Write-Host "`n💡 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Verify org issue types: Get-IssueTypeIds.ps1 -Owner <your-org>"
Write-Host "   2. Test with: @okyerema create a Feature issue titled 'Test'"
