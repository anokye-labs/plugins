<#
.SYNOPSIS
    Get fal.ai API usage and billing data.
.DESCRIPTION
    Retrieves usage statistics from the fal.ai platform, including costs,
    request counts, and breakdowns by model endpoint.
.PARAMETER Days
    Number of days of usage history to retrieve. Default: 30.
.PARAMETER GroupBy
    Group results by 'endpoint' or 'timeframe'. Default: endpoint.
.PARAMETER Model
    Filter usage to a specific model endpoint.
.PARAMETER Timeframe
    Aggregation interval: minute, hour, day, week, month.
.EXAMPLE
    .\Get-FalUsage.ps1
.EXAMPLE
    .\Get-FalUsage.ps1 -Days 7 -Model "fal-ai/flux/dev"
.EXAMPLE
    .\Get-FalUsage.ps1 -Days 90 -Timeframe "month"
#>
[CmdletBinding()]
param(
    [int]$Days = 30,

    [ValidateSet('endpoint', 'timeframe')]
    [string]$GroupBy = 'endpoint',

    [string]$Model,

    [ValidateSet('minute', 'hour', 'day', 'week', 'month')]
    [string]$Timeframe
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

$apiKey = Get-FalApiKey

# Build query parameters
$startDate = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-dd')
$endDate   = (Get-Date).ToString('yyyy-MM-dd')

$params = @("start=$startDate", "end=$endDate", "expand=time_series,summary")
if ($Model) {
    $params += "endpoint_id=$([uri]::EscapeDataString($Model))"
}
if ($Timeframe) {
    $params += "timeframe=$Timeframe"
}

$queryString = $params -join '&'
$url = "https://api.fal.ai/v1/models/usage?$queryString"

$headers = @{
    'Authorization' = "Key $apiKey"
    'Content-Type'  = 'application/json'
}

Write-Host "Fetching usage data for the last $Days day(s)..." -ForegroundColor Cyan

$response = Invoke-RestMethod -Uri $url -Method GET -Headers $headers -UseBasicParsing

# Extract summary
$summary = $response.summary

$output = [PSCustomObject]@{
    StartDate    = $startDate
    EndDate      = $endDate
    TotalCost    = if ($summary.total_cost) { $summary.total_cost } elseif ($summary.cost) { $summary.cost } else { 0 }
    TotalRequests = if ($summary.total_requests) { $summary.total_requests } elseif ($summary.request_count) { $summary.request_count } else { 0 }
    ByEndpoint   = @()
    RawData      = $response
}

# Aggregate by endpoint from time_series
$timeSeries = if ($response.time_series) { $response.time_series } elseif ($response.data) { $response.data } else { @() }
$byEndpoint = @{}

foreach ($bucket in $timeSeries) {
    $results = if ($bucket.results) { $bucket.results } else { @($bucket) }
    foreach ($item in $results) {
        $endpointId = $item.endpoint_id
        if (-not $endpointId) { continue }
        if (-not $byEndpoint.ContainsKey($endpointId)) {
            $byEndpoint[$endpointId] = @{ Cost = 0; Quantity = 0 }
        }
        $byEndpoint[$endpointId].Cost     += [double]($item.cost ?? 0)
        $byEndpoint[$endpointId].Quantity  += [double]($item.quantity ?? $item.request_count ?? 0)
    }
}

$output.ByEndpoint = @($byEndpoint.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        EndpointId = $_.Key
        Cost       = $_.Value.Cost
        Quantity   = $_.Value.Quantity
    }
} | Sort-Object Cost -Descending)

# Display summary
Write-Host "`nUsage Summary ($startDate to $endDate):" -ForegroundColor Green
Write-Host "  Total Cost:     `$$($output.TotalCost)" -ForegroundColor White
Write-Host "  Total Requests: $($output.TotalRequests)" -ForegroundColor White

if ($output.ByEndpoint.Count -gt 0) {
    Write-Host "`nBy Endpoint:" -ForegroundColor Green
    $output.ByEndpoint | Format-Table EndpointId, Cost, Quantity -AutoSize | Out-Host
}

$output
