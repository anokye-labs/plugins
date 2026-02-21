<#
.SYNOPSIS
    Tests connectivity to the fal.ai API.
.DESCRIPTION
    Validates that FAL_KEY is configured and the fal.ai API is reachable.
    Makes a lightweight call and reports status.
.EXAMPLE
    .\Test-FalConnection.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

$results = @{
    KeyFound     = $false
    ApiReachable = $false
    ResponseTime = $null
    Error        = $null
}

# 1. Check API key
try {
    $key = Get-FalApiKey
    $maskedKey = $key.Substring(0, [Math]::Min(8, $key.Length)) + '...'
    $results.KeyFound = $true
    Write-Host "[PASS] FAL_KEY found ($maskedKey)" -ForegroundColor Green
}
catch {
    $results.Error = $_.Exception.Message
    Write-Host "[FAIL] FAL_KEY not found: $($_.Exception.Message)" -ForegroundColor Red
    [PSCustomObject]$results
    return
}

# 2. Test API connectivity with a lightweight schema request
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-RestMethod -Uri 'https://fal.ai/api/openapi/queue/openapi.json?endpoint_id=fal-ai%2Fflux%2Fdev' `
        -Method GET -Headers @{ 'Content-Type' = 'application/json' } -UseBasicParsing -ErrorAction Stop
    $stopwatch.Stop()

    $results.ApiReachable = $true
    $results.ResponseTime = "$($stopwatch.ElapsedMilliseconds)ms"
    Write-Host "[PASS] API reachable (response: $($results.ResponseTime))" -ForegroundColor Green
}
catch {
    $results.Error = $_.Exception.Message
    Write-Host "[FAIL] API unreachable: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host ''
if ($results.KeyFound -and $results.ApiReachable) {
    Write-Host 'fal.ai connection OK' -ForegroundColor Green
}
else {
    Write-Host 'fal.ai connection FAILED' -ForegroundColor Red
}

[PSCustomObject]$results
