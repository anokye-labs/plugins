<#
.SYNOPSIS
    Generate videos from text prompts using fal.ai models.
.DESCRIPTION
    Submits a text-to-video generation request to fal.ai via the queue API
    and polls until the video is ready.
.PARAMETER Prompt
    The text description of the video to generate (required).
.PARAMETER Model
    The fal.ai model endpoint. Default: fal-ai/kling-video/v2.6/pro/text-to-video.
.PARAMETER Duration
    Video duration in seconds. Default: 5.
.PARAMETER AspectRatio
    Aspect ratio for the video. Default: 16:9.
.PARAMETER Queue
    Use queue mode. Default: $true (video generation is always async).
.EXAMPLE
    .\Invoke-FalVideoGen.ps1 -Prompt "Ocean waves crashing on a beach at sunset"
.EXAMPLE
    .\Invoke-FalVideoGen.ps1 -Prompt "A cat playing piano" -Duration 10 -AspectRatio "9:16"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Prompt,

    [string]$Model = 'fal-ai/kling-video/v2.6/pro/text-to-video',

    [int]$Duration = 5,

    [string]$AspectRatio = '16:9',

    [bool]$Queue = $true
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Build payload
$body = @{
    prompt       = $Prompt
    duration     = $Duration
    aspect_ratio = $AspectRatio
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
    Prompt   = $Prompt
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
