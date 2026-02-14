<#
.SYNOPSIS
    Generate videos from images using fal.ai models.
.DESCRIPTION
    Submits an image-to-video generation request to fal.ai via the queue API
    and polls until the video is ready.
.PARAMETER ImageUrl
    URL of the source image (required).
.PARAMETER Prompt
    Optional text prompt for guiding the video generation.
.PARAMETER Model
    The fal.ai model endpoint. Default: fal-ai/kling-video/v2.6/pro/image-to-video.
.PARAMETER Duration
    Video duration in seconds. Default: 5.
.PARAMETER Queue
    Use queue mode. Default: $true (video generation is always async).
.EXAMPLE
    .\Invoke-FalImageToVideo.ps1 -ImageUrl "https://example.com/photo.jpg"
.EXAMPLE
    .\Invoke-FalImageToVideo.ps1 -ImageUrl "https://example.com/photo.jpg" -Prompt "Zoom in slowly" -Duration 10
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ImageUrl,

    [string]$Prompt,

    [string]$Model = 'fal-ai/kling-video/v2.6/pro/image-to-video',

    [int]$Duration = 5,

    [bool]$Queue = $true
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Build payload
$body = @{
    image_url = $ImageUrl
    duration  = $Duration
}

if ($PSBoundParameters.ContainsKey('Prompt') -and $Prompt) {
    $body.prompt = $Prompt
}

# Execute via queue (video generation is always async)
if ($Queue) {
    Write-Host "Submitting to queue: $Model..." -ForegroundColor Cyan
    $result = Wait-FalJob -Model $Model -Body $body
}
else {
    Write-Host "Generating with $Model (sync)..." -ForegroundColor Cyan
    $result = Invoke-FalApi -Method POST -Endpoint $Model -Body $body
}

# Build output
$output = [PSCustomObject]@{
    Video    = $null
    Duration = $Duration
    Width    = $null
    Height   = $null
    ImageUrl = $ImageUrl
    Model    = $Model
}

if ($result.video) {
    $output.Video = [PSCustomObject]@{
        Url = $result.video.url
    }
    if ($result.video.width)  { $output.Width  = $result.video.width }
    if ($result.video.height) { $output.Height = $result.video.height }
}

# Display summary
if ($output.Video) {
    Write-Host "Video: $($output.Video.Url)" -ForegroundColor Green
}

$output
