<#
.SYNOPSIS
    Installs all Anokye Labs plugins via the Copilot CLI.

.DESCRIPTION
    Installs the omanfo and ahuofe plugins using `copilot plugin install`.
    Supports installation from the local source tree or from the remote
    GitHub repository.

.PARAMETER Plugins
    Optional list of plugin names to install. Defaults to all (omanfo, ahuofe).

.PARAMETER Remote
    Install from the remote GitHub repository instead of the local source tree.

.EXAMPLE
    .\Install-Plugins.ps1
    .\Install-Plugins.ps1 -Plugins ahuofe
    .\Install-Plugins.ps1 -Remote
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string[]]$Plugins = @("omanfo", "ahuofe"),
    [switch]$Remote
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Error "Copilot CLI is not installed. See: https://docs.github.com/copilot/concepts/agents/about-copilot-cli"
    return
}

Write-Host "`n📦 Installing plugins" -ForegroundColor Cyan

$installed = 0
foreach ($name in $Plugins) {
    if ($Remote) {
        $source = "anokye-labs/plugins:$name"
    } else {
        $source = Join-Path $repoRoot $name
    }

    Write-Host "   Installing: $name ($source)" -ForegroundColor Gray
    copilot plugin install $source 2>&1
    if ($LASTEXITCODE -eq 0) {
        $installed++
    } else {
        Write-Warning "Failed to install '$name'"
    }
}

Write-Host "`n✅ Installed $installed of $($Plugins.Count) plugin(s)" -ForegroundColor Green
