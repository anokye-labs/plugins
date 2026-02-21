<#
.SYNOPSIS
    Upload a local file to the fal.ai CDN.
.DESCRIPTION
    Uploads images and videos to fal.ai CDN using the shared Send-FalFile function.
    Returns a structured object with the CDN URL and file metadata.
.PARAMETER FilePath
    Path to the local file to upload (required).
.PARAMETER ContentType
    MIME type override. If omitted, auto-detected from file extension.
.EXAMPLE
    .\Upload-ToFalCDN.ps1 -FilePath .\photo.png
.EXAMPLE
    .\Upload-ToFalCDN.ps1 -FilePath .\clip.mp4 -ContentType 'video/mp4'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$FilePath,

    [string]$ContentType
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Resolve full path and get file info
$resolvedPath = (Resolve-Path $FilePath).Path
$fileItem = Get-Item $resolvedPath
$fileName = $fileItem.Name
$fileSize = $fileItem.Length
$ext = ($fileName -split '\.')[-1].ToLower()

# Auto-detect content type if not provided
if (-not $ContentType) {
    $ContentType = switch ($ext) {
        'png'  { 'image/png' }
        'jpg'  { 'image/jpeg' }
        'jpeg' { 'image/jpeg' }
        'webp' { 'image/webp' }
        'gif'  { 'image/gif' }
        'mp4'  { 'video/mp4' }
        'mov'  { 'video/quicktime' }
        'webm' { 'video/webm' }
        default { 'application/octet-stream' }
    }
}

# Validate supported types
$supportedExtensions = @('png','jpg','jpeg','webp','gif','mp4','mov','webm')
if ($ext -notin $supportedExtensions) {
    Write-Warning "Extension '.$ext' is not in the supported list ($($supportedExtensions -join ', ')). Uploading anyway."
}

Write-Host "Uploading: $fileName ($([math]::Round($fileSize / 1KB, 1)) KB)" -ForegroundColor Cyan

# Upload via shared module
$cdnUrl = Send-FalFile -FilePath $resolvedPath

Write-Host "Upload complete!" -ForegroundColor Green
Write-Host "URL: $cdnUrl" -ForegroundColor Green

# Return structured output
[PSCustomObject]@{
    Url         = $cdnUrl
    FileName    = $fileName
    ContentType = $ContentType
    Size        = $fileSize
}
