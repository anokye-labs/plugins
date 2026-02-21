<#
.SYNOPSIS
    Upscale an image or video using fal.ai super-resolution models.
.DESCRIPTION
    Increases the resolution of an image or video using AI upscaling.
    Supports both synchronous and queue-based modes.
.PARAMETER ImageUrl
    URL of the image to upscale. Required for image upscaling (default).
.PARAMETER VideoUrl
    URL of the video to upscale. Required when UpscaleType is 'video'.
.PARAMETER UpscaleType
    Type of media to upscale: 'image' (default) or 'video'.
.PARAMETER Scale
    Upscale factor. Default: 2. Valid values: 2, 4.
.PARAMETER Model
    The fal.ai upscaling model endpoint.
    Image default: fal-ai/aura-sr. Video default: fal-ai/video-upscaler.
.PARAMETER Queue
    Use queue mode (submit, poll, retrieve) instead of synchronous.
.EXAMPLE
    .\Invoke-FalUpscale.ps1 -ImageUrl "https://fal.media/files/example.png"
.EXAMPLE
    .\Invoke-FalUpscale.ps1 -ImageUrl "https://..." -Scale 4 -Queue
.EXAMPLE
    .\Invoke-FalUpscale.ps1 -VideoUrl "https://..." -UpscaleType video -Queue
.EXAMPLE
    .\Invoke-FalUpscale.ps1 -VideoUrl "https://..." -Model "fal-ai/topaz/upscale/video" -Queue
#>
[CmdletBinding(DefaultParameterSetName='Image')]
param(
    [Parameter(Mandatory, ParameterSetName='Image')]
    [string]$ImageUrl,

    [Parameter(Mandatory, ParameterSetName='Video')]
    [string]$VideoUrl,

    [ValidateSet('image', 'video')]
    [string]$UpscaleType,

    [ValidateSet(2, 4)]
    [int]$Scale = 2,

    [string]$Model,

    [switch]$Queue
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Determine upscale type and set model default
$isVideo = $PSCmdlet.ParameterSetName -eq 'Video'
if (-not $Model) {
    $Model = if ($isVideo) { 'fal-ai/video-upscaler' } else { 'fal-ai/aura-sr' }
}

# Build payload
if ($isVideo) {
    $body = @{
        video_url = $VideoUrl
        scale     = $Scale
    }
} else {
    $body = @{
        image_url = $ImageUrl
        scale     = $Scale
    }
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
    Video  = $null
    Width  = $null
    Height = $null
}

if ($isVideo) {
    if ($result.video) {
        $output.Video = [PSCustomObject]@{
            Url = $result.video.url
        }
    }
} else {
    if ($result.image) {
        $output.Image = [PSCustomObject]@{
            Url    = $result.image.url
            Width  = $result.image.width
            Height = $result.image.height
        }
        $output.Width  = $result.image.width
        $output.Height = $result.image.height
    }
}

# Display summary
if ($output.Image) {
    Write-Host "Upscaled: $($output.Image.Url)" -ForegroundColor Green
    Write-Host "Size: $($output.Width)x$($output.Height)" -ForegroundColor Green
}
elseif ($output.Video) {
    Write-Host "Upscaled video: $($output.Video.Url)" -ForegroundColor Green
}

$output
