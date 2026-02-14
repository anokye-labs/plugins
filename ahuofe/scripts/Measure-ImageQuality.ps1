<#
.SYNOPSIS
    Measures image quality metrics for a given image file.
.DESCRIPTION
    Computes file-based, statistical, and comparison metrics for an image.
    Provides SSIM approximation when a reference image is given.
    CLIP score is a placeholder requiring Python CLIP installation.
.PARAMETER ImagePath
    Path to the image file to measure (mandatory).
.PARAMETER ReferenceImagePath
    Optional reference image for comparison metrics (SSIM).
.PARAMETER Prompt
    Optional text prompt for CLIP score computation (placeholder).
.PARAMETER OutputFormat
    Output format: 'PSObject' (default) or 'JSON'.
.PARAMETER Threshold
    Hashtable of minimum acceptable values, e.g. @{ Brightness = 50; Contrast = 20 }.
.EXAMPLE
    .\Measure-ImageQuality.ps1 -ImagePath .\photo.png
.EXAMPLE
    .\Measure-ImageQuality.ps1 -ImagePath .\photo.png -ReferenceImagePath .\ref.png -OutputFormat JSON
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ImagePath,

    [string]$ReferenceImagePath,

    [string]$Prompt,

    [ValidateSet('PSObject', 'JSON')]
    [string]$OutputFormat = 'PSObject',

    [hashtable]$Threshold = @{}
)

function Read-PngHeader {
    param([string]$FilePath)
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $result = [PSCustomObject]@{
        Width      = -1
        Height     = -1
        BitDepth   = -1
        ColorType  = -1
        IsValid    = $false
        FileSize   = $bytes.Length
        PixelData  = $null
    }

    # Check PNG signature
    if ($bytes.Length -lt 33) { return $result }
    $sig = $bytes[0..7]
    $pngSig = @(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    $isMatch = $true
    for ($i = 0; $i -lt 8; $i++) {
        if ($sig[$i] -ne $pngSig[$i]) { $isMatch = $false; break }
    }
    if (-not $isMatch) { return $result }

    # IHDR starts at offset 8 (4-byte length + 4-byte type + data)
    $result.Width     = ([int]$bytes[16] -shl 24) -bor ([int]$bytes[17] -shl 16) -bor ([int]$bytes[18] -shl 8) -bor [int]$bytes[19]
    $result.Height    = ([int]$bytes[20] -shl 24) -bor ([int]$bytes[21] -shl 16) -bor ([int]$bytes[22] -shl 8) -bor [int]$bytes[23]
    $result.BitDepth  = [int]$bytes[24]
    $result.ColorType = [int]$bytes[25]
    $result.IsValid   = $true
    $result.PixelData = $bytes

    return $result
}

function Get-ColorDepth {
    param([int]$BitDepth, [int]$ColorType)
    $channels = switch ($ColorType) {
        0 { 1 }  # Grayscale
        2 { 3 }  # RGB
        3 { 1 }  # Indexed
        4 { 2 }  # Grayscale + Alpha
        6 { 4 }  # RGBA
        default { 3 }
    }
    return $BitDepth * $channels
}

function Get-ImageStats {
    param([byte[]]$Bytes)
    if ($Bytes.Length -eq 0) {
        return [PSCustomObject]@{ MeanBrightness = -1; Contrast = -1; Entropy = -1 }
    }

    # Use raw bytes as a rough proxy for pixel intensity distribution
    $values = $Bytes | ForEach-Object { [double]$_ }
    $mean = ($values | Measure-Object -Average).Average
    $variance = ($values | ForEach-Object { ($_ - $mean) * ($_ - $mean) } | Measure-Object -Average).Average
    $stddev = [Math]::Sqrt($variance)

    # Entropy approximation from byte histogram
    $histogram = @{}
    foreach ($b in $Bytes) {
        if ($histogram.ContainsKey($b)) { $histogram[$b]++ }
        else { $histogram[$b] = 1 }
    }
    $total = $Bytes.Length
    $entropy = 0.0
    foreach ($count in $histogram.Values) {
        $p = $count / $total
        if ($p -gt 0) { $entropy -= $p * [Math]::Log($p, 2) }
    }

    return [PSCustomObject]@{
        MeanBrightness = [Math]::Round($mean, 2)
        Contrast       = [Math]::Round($stddev, 2)
        Entropy        = [Math]::Round($entropy, 4)
    }
}

function Get-SsimApprox {
    param([byte[]]$Bytes1, [byte[]]$Bytes2)
    $len = [Math]::Min($Bytes1.Length, $Bytes2.Length)
    if ($len -eq 0) { return -1.0 }

    # Simplified SSIM: normalized cross-correlation of byte streams
    $mean1 = 0.0; $mean2 = 0.0
    for ($i = 0; $i -lt $len; $i++) {
        $mean1 += $Bytes1[$i]
        $mean2 += $Bytes2[$i]
    }
    $mean1 /= $len; $mean2 /= $len

    $var1 = 0.0; $var2 = 0.0; $cov = 0.0
    for ($i = 0; $i -lt $len; $i++) {
        $d1 = $Bytes1[$i] - $mean1
        $d2 = $Bytes2[$i] - $mean2
        $var1 += $d1 * $d1
        $var2 += $d2 * $d2
        $cov  += $d1 * $d2
    }
    $var1 /= $len; $var2 /= $len; $cov /= $len

    $C1 = 6.5025   # (0.01 * 255)^2
    $C2 = 58.5225   # (0.03 * 255)^2

    $numerator   = (2 * $mean1 * $mean2 + $C1) * (2 * $cov + $C2)
    $denominator = ($mean1 * $mean1 + $mean2 * $mean2 + $C1) * ($var1 + $var2 + $C2)

    if ($denominator -eq 0) { return -1.0 }
    return [Math]::Round($numerator / $denominator, 6)
}

# --- Main ---
$header = Read-PngHeader -FilePath $ImagePath
$fileInfo = Get-Item $ImagePath

$width  = if ($header.IsValid) { $header.Width } else { -1 }
$height = if ($header.IsValid) { $header.Height } else { -1 }
$aspectRatio = if ($width -gt 0 -and $height -gt 0) { [Math]::Round($width / $height, 4) } else { -1 }
$colorDepth  = if ($header.IsValid) { Get-ColorDepth -BitDepth $header.BitDepth -ColorType $header.ColorType } else { -1 }

$stats = if ($header.IsValid -and $header.PixelData) {
    Get-ImageStats -Bytes $header.PixelData
} else {
    [PSCustomObject]@{ MeanBrightness = -1; Contrast = -1; Entropy = -1 }
}

$ssim = -1.0
if ($ReferenceImagePath -and (Test-Path $ReferenceImagePath -PathType Leaf)) {
    $refHeader = Read-PngHeader -FilePath $ReferenceImagePath
    if ($header.IsValid -and $refHeader.IsValid) {
        $ssim = Get-SsimApprox -Bytes1 $header.PixelData -Bytes2 $refHeader.PixelData
    }
}

$clipScore = -1.0
$clipNote = if ($Prompt) { 'CLIP score requires Python clip library. Install via: pip install openai-clip' } else { $null }

$thresholdResults = @{}
if ($Threshold.Count -gt 0) {
    $metricMap = @{
        Brightness = $stats.MeanBrightness
        Contrast   = $stats.Contrast
        Entropy    = $stats.Entropy
        SSIM       = $ssim
        Width      = $width
        Height     = $height
    }
    foreach ($key in $Threshold.Keys) {
        $actual = $metricMap[$key]
        if ($null -ne $actual -and $actual -ge 0) {
            $thresholdResults[$key] = [PSCustomObject]@{
                Minimum = $Threshold[$key]
                Actual  = $actual
                Pass    = $actual -ge $Threshold[$key]
            }
        }
    }
}

$output = [PSCustomObject]@{
    FilePath       = $fileInfo.FullName
    FileSize       = $fileInfo.Length
    Width          = $width
    Height         = $height
    AspectRatio    = $aspectRatio
    ColorDepth     = $colorDepth
    MeanBrightness = $stats.MeanBrightness
    Contrast       = $stats.Contrast
    Entropy        = $stats.Entropy
    SSIM           = $ssim
    CLIPScore      = $clipScore
    CLIPNote       = $clipNote
    Thresholds     = if ($thresholdResults.Count -gt 0) { $thresholdResults } else { $null }
}

if ($OutputFormat -eq 'JSON') {
    $output | ConvertTo-Json -Depth 5
} else {
    $output
}
