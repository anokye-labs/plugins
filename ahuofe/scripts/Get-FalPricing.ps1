<#
.SYNOPSIS
    Query live pricing for fal.ai models.
.DESCRIPTION
    Retrieves pricing information from the fal.ai pricing API. Supports
    optional filtering by model ID or category.
.PARAMETER ModelId
    Filter results to a specific model endpoint, e.g. "fal-ai/flux/dev".
.PARAMETER Category
    Filter results to a specific category, e.g. "image", "video".
.EXAMPLE
    .\Get-FalPricing.ps1
.EXAMPLE
    .\Get-FalPricing.ps1 -ModelId "fal-ai/flux/dev"
.EXAMPLE
    .\Get-FalPricing.ps1 -Category "video"
#>
[CmdletBinding()]
param(
    [string]$ModelId,

    [string]$Category
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

Write-Host 'Fetching fal.ai pricing...' -ForegroundColor Cyan

$response = Invoke-FalApi -Method GET -Endpoint 'https://api.fal.ai/v1/models/pricing' -RawUrl

# Normalize: the response may be an array or an object with a .models / .data / .pricing property
$items = if ($response -is [array]) {
    $response
} elseif ($response.models) {
    $response.models
} elseif ($response.data) {
    $response.data
} elseif ($response.pricing) {
    $response.pricing
} else {
    @($response)
}

# Build structured output
$results = @($items | ForEach-Object {
    $id    = if ($_.model_id)   { $_.model_id }   elseif ($_.id) { $_.id } else { $_.endpoint_id }
    $price = if ($_.price)      { $_.price }      elseif ($_.cost) { $_.cost } else { 0 }
    $unit  = if ($_.unit)       { $_.unit }       else { 'request' }
    $cat   = if ($_.category)   { $_.category }   else { $null }

    [PSCustomObject]@{
        ModelId        = $id
        Price          = [double]$price
        Unit           = $unit
        Category       = $cat
        PriceFormatted = '$' + ([math]::Round([double]$price, 6).ToString('0.######')) + " per $unit"
    }
})

# Apply filters
if ($ModelId) {
    $results = @($results | Where-Object { $_.ModelId -eq $ModelId })
}

if ($Category) {
    $results = @($results | Where-Object { $_.Category -ieq $Category })
}

# Display
if ($results.Count -gt 0) {
    Write-Host "`nPricing ($($results.Count) model(s)):" -ForegroundColor Green
    $results | Format-Table ModelId, PriceFormatted, Category -AutoSize | Out-Host
} else {
    Write-Host 'No pricing data found for the specified filters.' -ForegroundColor Yellow
}

$results
