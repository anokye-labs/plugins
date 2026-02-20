<#
.SYNOPSIS
    List and manage fal.ai inference requests.
.DESCRIPTION
    Retrieves requests by endpoint from the fal.ai platform. Supports filtering
    by model and limiting result count. Optionally deletes payloads for a
    specific request ID to free up storage.
.PARAMETER ModelId
    Filter requests to a specific model endpoint, e.g. "fal-ai/flux/dev".
.PARAMETER Limit
    Maximum number of requests to return. Default: 20.
.PARAMETER Delete
    Request ID whose payloads should be deleted (cleanup).
.EXAMPLE
    .\Get-FalRequests.ps1
.EXAMPLE
    .\Get-FalRequests.ps1 -ModelId "fal-ai/flux/dev" -Limit 10
.EXAMPLE
    .\Get-FalRequests.ps1 -Delete "req-abc123"
#>
[CmdletBinding()]
param(
    [string]$ModelId,

    [int]$Limit = 20,

    [string]$Delete
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# ─── Delete payloads for a specific request ─────────────────────────────────
if ($Delete) {
    $deleteUrl = "https://api.fal.ai/v1/models/requests/$Delete/payloads"
    Write-Host "Deleting payloads for request '$Delete'..." -ForegroundColor Cyan

    Invoke-FalApi -Method DELETE -Endpoint $deleteUrl -RawUrl | Out-Null

    Write-Host "Payloads deleted for request: $Delete" -ForegroundColor Green
    return [PSCustomObject]@{
        RequestId = $Delete
        Action    = 'PayloadsDeleted'
        Success   = $true
    }
}

# ─── List requests ───────────────────────────────────────────────────────────
$queryParts = @("limit=$Limit")
if ($ModelId) {
    $queryParts += "endpoint_id=$([uri]::EscapeDataString($ModelId))"
}
$queryString = $queryParts -join '&'
$listUrl = "https://api.fal.ai/v1/models/requests/by-endpoint?$queryString"

Write-Host 'Fetching fal.ai requests...' -ForegroundColor Cyan

$response = Invoke-FalApi -Method GET -Endpoint $listUrl -RawUrl

# Normalize response shape
$items = if ($response -is [array]) {
    $response
} elseif ($response.requests) {
    $response.requests
} elseif ($response.data) {
    $response.data
} else {
    @($response)
}

$results = @($items | ForEach-Object {
    $reqId    = if ($_.request_id)   { $_.request_id }   else { $_.id }
    $endpoint = if ($_.endpoint_id)  { $_.endpoint_id }  else { $_.model_id }
    $status   = if ($_.status)       { $_.status }       else { $null }
    $created  = if ($_.created_at)   { $_.created_at }   else { $null }

    [PSCustomObject]@{
        RequestId  = $reqId
        EndpointId = $endpoint
        Status     = $status
        CreatedAt  = $created
    }
})

# Display
if ($results.Count -gt 0) {
    Write-Host "`nRequests ($($results.Count)):" -ForegroundColor Green
    $results | Format-Table RequestId, EndpointId, Status, CreatedAt -AutoSize | Out-Host
} else {
    Write-Host 'No requests found.' -ForegroundColor Yellow
}

$results
