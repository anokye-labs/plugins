<#
.SYNOPSIS
    Uninstalls Anokye Labs plugins via the Copilot CLI.

.DESCRIPTION
    Uninstalls plugins using `copilot plugin uninstall`. By default uninstalls
    all Anokye plugins (omanfo, ahuofe). Use -Plugins to target specific ones.

.PARAMETER Plugins
    Optional list of plugin names to uninstall. Defaults to all (omanfo, ahuofe).

.EXAMPLE
    .\Uninstall-Plugins.ps1
    .\Uninstall-Plugins.ps1 -Plugins omanfo
    .\Uninstall-Plugins.ps1 -Plugins omanfo, ahuofe
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string[]]$Plugins = @("omanfo", "ahuofe")
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Error "Copilot CLI is not installed. See: https://docs.github.com/copilot/concepts/agents/about-copilot-cli"
    return
}

Write-Host "`n🗑️  Uninstalling plugins" -ForegroundColor Cyan

$failed = 0
foreach ($name in $Plugins) {
    Write-Host "   Uninstalling: $name" -ForegroundColor Gray
    copilot plugin uninstall $name 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to uninstall '$name' (may not be installed)"
        $failed++
    }
}

$succeeded = $Plugins.Count - $failed
Write-Host "`n✅ Uninstalled $succeeded of $($Plugins.Count) plugin(s)" -ForegroundColor Green
