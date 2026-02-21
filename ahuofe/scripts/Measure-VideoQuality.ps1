<#
.SYNOPSIS
    Measures video quality metrics for a given video file.
.DESCRIPTION
    Computes file-based metadata and placeholder metrics for video quality.
    Uses ffprobe when available for accurate metadata; falls back to file-based
    analysis otherwise. Temporal consistency and optical flow are placeholders
    requiring ffmpeg/OpenCV.
.PARAMETER VideoPath
    Path to the video file to measure (mandatory).
.PARAMETER ReferenceVideoPath
    Optional reference video for comparison metrics (placeholder).
.PARAMETER OutputFormat
    Output format: 'PSObject' (default) or 'JSON'.
.EXAMPLE
    .\Measure-VideoQuality.ps1 -VideoPath .\clip.mp4
.EXAMPLE
    .\Measure-VideoQuality.ps1 -VideoPath .\clip.mp4 -OutputFormat JSON
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$VideoPath,

    [string]$ReferenceVideoPath,

    [ValidateSet('PSObject', 'JSON')]
    [string]$OutputFormat = 'PSObject'
)

$fileInfo = Get-Item $VideoPath
$extension = $fileInfo.Extension.TrimStart('.').ToUpper()

# Defaults for metadata
$duration    = -1.0
$width       = -1
$height      = -1
$frameCount  = -1
$codec       = 'unknown'
$frameRate   = -1.0
$metaSource  = 'file-only'

# Check for ffprobe
$ffprobe = Get-Command 'ffprobe' -ErrorAction SilentlyContinue

if ($ffprobe) {
    $metaSource = 'ffprobe'
    try {
        $probeJson = & ffprobe -v quiet -print_format json -show_format -show_streams $VideoPath 2>&1
        $probe = $probeJson | ConvertFrom-Json

        $videoStream = $probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1

        if ($videoStream) {
            $width      = [int]$videoStream.width
            $height     = [int]$videoStream.height
            $codec      = $videoStream.codec_name
            $frameCount = if ($videoStream.nb_frames -and $videoStream.nb_frames -ne 'N/A') {
                [int]$videoStream.nb_frames
            } else { -1 }

            if ($videoStream.r_frame_rate) {
                $parts = $videoStream.r_frame_rate -split '/'
                if ($parts.Count -eq 2 -and [double]$parts[1] -ne 0) {
                    $frameRate = [Math]::Round([double]$parts[0] / [double]$parts[1], 2)
                }
            }
        }

        if ($probe.format -and $probe.format.duration) {
            $duration = [Math]::Round([double]$probe.format.duration, 3)
        }
    }
    catch {
        Write-Warning "ffprobe failed: $_. Falling back to file-based analysis."
        $metaSource = 'file-only'
    }
}

# Resolution string
$resolution = if ($width -gt 0 -and $height -gt 0) { "${width}x${height}" } else { 'unknown' }

# Placeholder metrics (require external tools for real computation)
$temporalConsistency = -1.0
$temporalNote = 'Temporal consistency requires ffmpeg + Python. Returns -1 as placeholder.'

$opticalFlow = -1.0
$opticalFlowNote = 'Optical flow computation requires OpenCV (Python cv2). Returns -1 as placeholder.'

$referenceComparison = $null
if ($ReferenceVideoPath) {
    if (Test-Path $ReferenceVideoPath -PathType Leaf) {
        $referenceComparison = [PSCustomObject]@{
            ReferenceFile = (Get-Item $ReferenceVideoPath).FullName
            PSNR          = -1.0
            PSNRNote      = 'Frame-level PSNR requires ffmpeg. Returns -1 as placeholder.'
        }
    }
    else {
        Write-Warning "Reference video not found: $ReferenceVideoPath"
    }
}

$output = [PSCustomObject]@{
    FilePath             = $fileInfo.FullName
    FileSize             = $fileInfo.Length
    Extension            = $extension
    Duration             = $duration
    Resolution           = $resolution
    Width                = $width
    Height               = $height
    FrameCount           = $frameCount
    FrameRate            = $frameRate
    Codec                = $codec
    MetadataSource       = $metaSource
    TemporalConsistency  = $temporalConsistency
    TemporalNote         = $temporalNote
    OpticalFlow          = $opticalFlow
    OpticalFlowNote      = $opticalFlowNote
    ReferenceComparison  = $referenceComparison
}

if ($OutputFormat -eq 'JSON') {
    $output | ConvertTo-Json -Depth 5
} else {
    $output
}
