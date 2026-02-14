<#
.SYNOPSIS
    Check the queue status of a fal.ai request.
.DESCRIPTION
    Queries the fal.ai queue API for the current status of a submitted
    request, including queue position, status, and logs.
.PARAMETER RequestId
    The request ID returned when a job was submitted to the queue.
.PARAMETER Model
    The fal.ai model endpoint (e.g., 'fal-ai/flux/dev').
.EXAMPLE
    .\Get-QueueStatus.ps1 -RequestId "abc-123" -Model "fal-ai/flux/dev"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RequestId,

    [Parameter(Mandatory)]
    [string]$Model
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

$apiKey = Get-FalApiKey

$url = "https://queue.fal.run/$Model/requests/$RequestId/status"

$headers = @{
    'Authorization' = "Key $apiKey"
    'Content-Type'  = 'application/json'
}

Write-Host "Checking queue status for $RequestId..." -ForegroundColor Cyan

$response = Invoke-RestMethod -Uri $url -Method GET -Headers $headers -UseBasicParsing

$output = [PSCustomObject]@{
    RequestId     = $RequestId
    Model         = $Model
    Status        = $response.status
    QueuePosition = $response.queue_position
    ResponseUrl   = $response.response_url
    Logs          = $response.logs
}

# Display status
$color = switch ($output.Status) {
    'COMPLETED'  { 'Green' }
    'FAILED'     { 'Red' }
    'IN_QUEUE'   { 'Yellow' }
    'IN_PROGRESS' { 'Cyan' }
    default      { 'White' }
}
Write-Host "Status: $($output.Status)" -ForegroundColor $color

if ($null -ne $output.QueuePosition) {
    Write-Host "Queue Position: $($output.QueuePosition)" -ForegroundColor Yellow
}

$output
