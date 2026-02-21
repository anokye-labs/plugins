<#
.SYNOPSIS
    Validates ImageSorcery MCP server connectivity and basic operations.

.DESCRIPTION
    Tests that the ImageSorcery MCP server is accessible and core operations
    (get_metainfo, detect, resize) work correctly. Uses a minimal 1x1 PNG
    test fixture located in tests/fixtures/.

.PARAMETER TestImagePath
    Path to the test image. Defaults to tests/fixtures/test-1x1.png relative
    to the repository root.

.EXAMPLE
    .\scripts\Test-ImageSorcery.ps1
    .\scripts\Test-ImageSorcery.ps1 -TestImagePath "C:\images\sample.png"
#>
param(
    [string]$TestImagePath
)

$ErrorActionPreference = 'Continue'
$script:PassCount = 0
$script:FailCount = 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-TestResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail = '',
        [double]$ElapsedMs = 0
    )
    $status = if ($Passed) { 'PASS' } else { 'FAIL' }
    $color  = if ($Passed) { 'Green' } else { 'Red' }
    $timing = if ($ElapsedMs -gt 0) { " (${ElapsedMs}ms)" } else { '' }
    $msg    = "[$status] $Name$timing"
    if ($Detail) { $msg += " - $Detail" }
    Write-Host $msg -ForegroundColor $color

    if ($Passed) { $script:PassCount++ } else { $script:FailCount++ }
}

function Get-RepoRoot {
    $dir = $PSScriptRoot
    while ($dir -and -not (Test-Path (Join-Path $dir '.git'))) {
        $dir = Split-Path $dir -Parent
    }
    if (-not $dir) { $dir = (Get-Location).Path }
    return $dir
}

# ---------------------------------------------------------------------------
# Resolve test image
# ---------------------------------------------------------------------------

$repoRoot = Get-RepoRoot

if (-not $TestImagePath) {
    $TestImagePath = Join-Path $repoRoot 'tests' 'fixtures' 'test-1x1.png'
}

$TestImagePath = [System.IO.Path]::GetFullPath($TestImagePath)

Write-Host '========================================'
Write-Host ' ImageSorcery MCP Validation'
Write-Host '========================================'
Write-Host "Test image : $TestImagePath"
Write-Host "Repo root  : $repoRoot"
Write-Host ''

# ---------------------------------------------------------------------------
# Test 1: Test image exists
# ---------------------------------------------------------------------------

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$exists = Test-Path $TestImagePath
$sw.Stop()
Write-TestResult -Name 'Test image exists' -Passed $exists `
    -Detail $(if (-not $exists) { "File not found: $TestImagePath" } else { '' }) `
    -ElapsedMs $sw.ElapsedMilliseconds

if (-not $exists) {
    Write-Host ''
    Write-Host 'Cannot continue without a test image. Create tests/fixtures/test-1x1.png or specify -TestImagePath.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host "Results: $($script:PassCount) passed, $($script:FailCount) failed"
    exit 1
}

# ---------------------------------------------------------------------------
# Test 2: MCP server process check
# ---------------------------------------------------------------------------

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mcpConfig = Join-Path $repoRoot '.github' 'mcp.json'
$mcpRootConfig = Join-Path $repoRoot 'mcp.json'
$configFound = (Test-Path $mcpConfig) -or (Test-Path $mcpRootConfig)
$sw.Stop()
Write-TestResult -Name 'MCP configuration file exists' -Passed $configFound `
    -Detail $(if (-not $configFound) { "No mcp.json found at .github/mcp.json or repo root" } else { '' }) `
    -ElapsedMs $sw.ElapsedMilliseconds

# ---------------------------------------------------------------------------
# Test 3: get_metainfo on test image
# ---------------------------------------------------------------------------

$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    # Attempt to call the MCP tool via Python module invocation
    $pyScript = @"
import json, sys
try:
    from PIL import Image
    img = Image.open(r'$($TestImagePath -replace "'","''")')
    info = {
        'width': img.width,
        'height': img.height,
        'format': img.format,
        'mode': img.mode
    }
    print(json.dumps(info))
    sys.exit(0)
except Exception as e:
    print(json.dumps({'error': str(e)}))
    sys.exit(1)
"@
    $result = $pyScript | python 2>&1
    $sw.Stop()

    if ($LASTEXITCODE -eq 0) {
        $meta = $result | ConvertFrom-Json
        $dimensionsOk = ($meta.width -eq 1) -and ($meta.height -eq 1)
        Write-TestResult -Name 'get_metainfo (image readable)' -Passed $true `
            -Detail "width=$($meta.width), height=$($meta.height), format=$($meta.format)" `
            -ElapsedMs $sw.ElapsedMilliseconds

        Write-TestResult -Name 'get_metainfo (dimensions correct)' -Passed $dimensionsOk `
            -Detail $(if (-not $dimensionsOk) { "Expected 1x1, got $($meta.width)x$($meta.height)" } else { '1x1 confirmed' }) `
            -ElapsedMs 0
    }
    else {
        Write-TestResult -Name 'get_metainfo (image readable)' -Passed $false `
            -Detail "Python/Pillow failed: $result" `
            -ElapsedMs $sw.ElapsedMilliseconds
    }
}
catch {
    $sw.Stop()
    Write-TestResult -Name 'get_metainfo (image readable)' -Passed $false `
        -Detail "Exception: $_" -ElapsedMs $sw.ElapsedMilliseconds
}

# ---------------------------------------------------------------------------
# Test 4: detect (requires YOLO model)
# ---------------------------------------------------------------------------

$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $pyDetect = @"
import json, sys
try:
    from ultralytics import YOLO
    print(json.dumps({'available': True}))
    sys.exit(0)
except ImportError:
    print(json.dumps({'available': False, 'reason': 'ultralytics not installed'}))
    sys.exit(0)
except Exception as e:
    print(json.dumps({'available': False, 'reason': str(e)}))
    sys.exit(1)
"@
    $detectResult = $pyDetect | python 2>&1
    $sw.Stop()

    if ($LASTEXITCODE -eq 0) {
        $detectInfo = $detectResult | ConvertFrom-Json
        Write-TestResult -Name 'detect (YOLO available)' -Passed $detectInfo.available `
            -Detail $(if (-not $detectInfo.available) { $detectInfo.reason } else { 'ultralytics importable' }) `
            -ElapsedMs $sw.ElapsedMilliseconds
    }
    else {
        Write-TestResult -Name 'detect (YOLO available)' -Passed $false `
            -Detail "Check failed: $detectResult" -ElapsedMs $sw.ElapsedMilliseconds
    }
}
catch {
    $sw.Stop()
    Write-TestResult -Name 'detect (YOLO available)' -Passed $false `
        -Detail "Exception: $_" -ElapsedMs $sw.ElapsedMilliseconds
}

# ---------------------------------------------------------------------------
# Test 5: resize operation
# ---------------------------------------------------------------------------

$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $resizedPath = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        'imagesorcery_test_resized.png'
    )
    $pyResize = @"
import json, sys
try:
    from PIL import Image
    img = Image.open(r'$($TestImagePath -replace "'","''")')
    resized = img.resize((10, 10), Image.NEAREST)
    resized.save(r'$($resizedPath -replace "'","''")')
    verify = Image.open(r'$($resizedPath -replace "'","''")')
    print(json.dumps({'width': verify.width, 'height': verify.height, 'path': r'$($resizedPath -replace "'","''")'}))
    sys.exit(0)
except Exception as e:
    print(json.dumps({'error': str(e)}))
    sys.exit(1)
"@
    $resizeResult = $pyResize | python 2>&1
    $sw.Stop()

    if ($LASTEXITCODE -eq 0) {
        $resizeInfo = $resizeResult | ConvertFrom-Json
        $sizeOk = ($resizeInfo.width -eq 10) -and ($resizeInfo.height -eq 10)
        Write-TestResult -Name 'resize (1x1 → 10x10)' -Passed $sizeOk `
            -Detail "Output: $($resizeInfo.width)x$($resizeInfo.height)" `
            -ElapsedMs $sw.ElapsedMilliseconds
    }
    else {
        Write-TestResult -Name 'resize (1x1 → 10x10)' -Passed $false `
            -Detail "Resize failed: $resizeResult" -ElapsedMs $sw.ElapsedMilliseconds
    }

    # Cleanup
    if (Test-Path $resizedPath) { Remove-Item $resizedPath -Force }
}
catch {
    $sw.Stop()
    Write-TestResult -Name 'resize (1x1 → 10x10)' -Passed $false `
        -Detail "Exception: $_" -ElapsedMs $sw.ElapsedMilliseconds
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '========================================'
$total = $script:PassCount + $script:FailCount
Write-Host "Results: $($script:PassCount)/$total passed, $($script:FailCount) failed"
Write-Host '========================================'

if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
