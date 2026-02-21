<#
.SYNOPSIS
    Search for fal.ai models by keyword or category.
.DESCRIPTION
    Queries the fal.ai model registry and returns matching models with their
    endpoint IDs, names, and descriptions.
.PARAMETER Query
    Search term to filter models (e.g., 'flux', 'video', 'upscale').
.PARAMETER Category
    Filter by category (e.g., 'text-to-image', 'image-to-video').
.PARAMETER Limit
    Maximum number of results to return. Default: 10.
.EXAMPLE
    .\Search-FalModels.ps1 -Query "flux"
.EXAMPLE
    .\Search-FalModels.ps1 -Query "upscale" -Limit 5
.EXAMPLE
    .\Search-FalModels.ps1 -Category "text-to-video"
#>
[CmdletBinding()]
param(
    [string]$Query,

    [string]$Category,

    [int]$Limit = 10
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

$apiKey = Get-FalApiKey

# Build query string
$params = @("limit=$Limit")
if ($Query)    { $params += "q=$([uri]::EscapeDataString($Query))" }
if ($Category) { $params += "category=$([uri]::EscapeDataString($Category))" }
$queryString = $params -join '&'

$url = "https://api.fal.ai/v1/models?$queryString"

$headers = @{
    'Authorization' = "Key $apiKey"
    'Content-Type'  = 'application/json'
}

Write-Host "Searching fal.ai models..." -ForegroundColor Cyan

$response = Invoke-RestMethod -Uri $url -Method GET -Headers $headers -UseBasicParsing

# Extract model list from response
$models = if ($response.data) { @($response.data) } else { @($response) }

if ($models.Count -eq 0 -or ($models.Count -eq 1 -and -not $models[0].endpoint_id)) {
    Write-Host "No models found." -ForegroundColor Yellow
    return @()
}

# Build output objects
$output = @($models | ForEach-Object {
    [PSCustomObject]@{
        EndpointId  = $_.endpoint_id
        Name        = $_.display_name
        Category    = $_.category
        Description = $_.description
    }
})

Write-Host "Found $($output.Count) model(s)." -ForegroundColor Green

$output
