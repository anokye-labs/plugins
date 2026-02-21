<#
.SYNOPSIS
    Upscale an image using fal.ai super-resolution models.
.DESCRIPTION
    Increases the resolution of an image using AI upscaling.
    Supports both synchronous and queue-based modes.
.PARAMETER ImageUrl
    URL of the image to upscale (required).
.PARAMETER Scale
    Upscale factor. Default: 2. Valid values: 2, 4.
.PARAMETER Model
    The fal.ai upscaling model endpoint. Default: fal-ai/aura-sr.
.PARAMETER Queue
    Use queue mode (submit, poll, retrieve) instead of synchronous.
.EXAMPLE
    .\Invoke-FalUpscale.ps1 -ImageUrl "https://fal.media/files/example.png"
.EXAMPLE
    .\Invoke-FalUpscale.ps1 -ImageUrl "https://..." -Scale 4 -Queue
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ImageUrl,

    [ValidateSet(2, 4)]
    [int]$Scale = 2,

    [string]$Model = 'fal-ai/aura-sr',

    [switch]$Queue
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Build payload
$body = @{
    image_url = $ImageUrl
    scale     = $Scale
}

# Execute
if ($Queue) {
    Write-Host "Submitting upscale to queue: $Model..." -ForegroundColor Cyan
    $result = Wait-FalJob -Model $Model -Body $body
}
else {
    Write-Host "Upscaling with $Model (sync)..." -ForegroundColor Cyan
    $result = Invoke-FalApi -Method POST -Endpoint $Model -Body $body
}

# Build output
$output = [PSCustomObject]@{
    Image  = $null
    Width  = $null
    Height = $null
}

if ($result.image) {
    $output.Image = [PSCustomObject]@{
        Url    = $result.image.url
        Width  = $result.image.width
        Height = $result.image.height
    }
    $output.Width  = $result.image.width
    $output.Height = $result.image.height
}

# Display summary
if ($output.Image) {
    Write-Host "Upscaled: $($output.Image.Url)" -ForegroundColor Green
    Write-Host "Size: $($output.Width)x$($output.Height)" -ForegroundColor Green
}

$output
