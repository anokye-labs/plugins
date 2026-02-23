#Requires -Version 5.1
<#
.SYNOPSIS
    Dry-run validator for agent workflow definitions.

.DESCRIPTION
    Simulates agent workflow steps without making real changes. Validates agent
    definition completeness (required frontmatter fields, referenced files exist)
    and reports which tools and scripts the agent would invoke during execution.

    When -DryRun is specified, only structural validation is performed and no
    workflow simulation is run. Without -DryRun, the script also simulates the
    sequence of tools and scripts the agent would invoke based on its definition.

.PARAMETER AgentPath
    Path to the .agent.md definition file to validate and simulate.

.PARAMETER TestIssue
    GitHub issue number or URL to use as simulated input when running
    workflow simulation (non-DryRun mode).

.PARAMETER DryRun
    Run structural validation only without simulating workflow execution.

.EXAMPLE
    .\Test-AgentWorkflow.ps1 -AgentPath .\omanfo\agents\okyerema.agent.md

    Validates the agent definition and simulates the tools it would invoke.

.EXAMPLE
    .\Test-AgentWorkflow.ps1 -AgentPath .\omanfo\agents\okyerema.agent.md -DryRun

    Validates the agent definition structure only, without simulating execution.

.EXAMPLE
    .\Test-AgentWorkflow.ps1 -AgentPath .\omanfo\agents\okyerema.agent.md -TestIssue 42

    Validates the agent definition and simulates execution with issue #42 as input.

.OUTPUTS
    PSCustomObject with:
      Valid         (bool)     — overall validation result
      AgentName     (string)   — parsed agent name from frontmatter
      Errors        (string[]) — validation errors found
      Warnings      (string[]) — non-fatal warnings
      Tools         (string[]) — tools declared in the agent definition
      Scripts       (string[]) — script references found in the definition body
      WouldInvoke   (string[]) — tools/scripts the agent would invoke (simulation)
      DryRun        (bool)     — whether this was a dry-run validation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AgentPath,

    [Parameter()]
    [string]$TestIssue,

    [Parameter()]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ─── Required frontmatter fields ────────────────────────────────────────────
$RequiredFields = @('name', 'description', 'tools')

# ─── Helpers ────────────────────────────────────────────────────────────────

function Read-Frontmatter {
    param([string]$Content)

    $frontmatter = @{}
    $lastKey     = $null

    if ($Content -notmatch '(?s)^---\r?\n(.+?)\r?\n---') {
        return $frontmatter
    }

    $block = $Matches[1]
    foreach ($line in ($block -split '\r?\n')) {
        if ($line -match '^\s*([^:]+):\s*(.*)$') {
            $key   = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $lastKey = $key

            # Parse inline YAML list: [a, b, c]
            if ($value -match '^\[(.+)\]$') {
                $frontmatter[$key] = ($Matches[1] -split '\s*,\s*') | ForEach-Object { $_.Trim() }
            }
            # Block scalar folded (>) or literal (|): collect subsequent indented lines as string
            elseif ($value -eq '>' -or $value -eq '|') {
                $frontmatter[$key] = ''
            }
            # Empty value: key may start an indented list
            elseif ($value -eq '') {
                $frontmatter[$key] = @()
            }
            else {
                $frontmatter[$key] = $value
            }
        }
        elseif ($line -match '^\s*-\s+(.+)$') {
            # List item under the last key
            if ($lastKey) {
                $frontmatter[$lastKey] += $Matches[1].Trim()
            }
        }
        elseif ($line -match '^\s{2,}\S' -and $lastKey -and $frontmatter[$lastKey] -is [string]) {
            # Indented continuation line for a block scalar value
            $trimmed = $line.Trim()
            $existing = $frontmatter[$lastKey]
            $frontmatter[$lastKey] = if ($existing) { "$existing $trimmed" } else { $trimmed }
        }
    }

    return $frontmatter
}

function Find-ScriptReferences {
    param([string]$Body)

    $scripts = [System.Collections.Generic.List[string]]::new()

    # Match script paths with path separators (e.g. scripts/Foo-Bar.ps1 or scripts\Foo.ps1)
    $pathMatches = [regex]::Matches($Body, '[A-Za-z0-9_./-]+(\\|/)[A-Za-z0-9_./-]+\.ps1\b')
    foreach ($m in $pathMatches) {
        $scripts.Add($m.Value)
    }

    # Match backtick-quoted script names (any valid PowerShell script name)
    $tickMatches = [regex]::Matches($Body, '`([A-Za-z0-9_-]+\.ps1)`')
    foreach ($m in $tickMatches) {
        if (-not $scripts.Contains($m.Groups[1].Value)) {
            $scripts.Add($m.Groups[1].Value)
        }
    }

    return ($scripts | Select-Object -Unique)
}

function Resolve-AgentBasePath {
    param([string]$AgentFilePath)
    # Walk up from the agent file to find the repository root (indicated by a .git directory)
    $dir = Split-Path $AgentFilePath -Parent
    while ($dir -and (Test-Path $dir)) {
        if (Test-Path (Join-Path $dir '.git')) { return $dir }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    # Fallback: return the agent file's own directory
    return Split-Path $AgentFilePath -Parent
}

# ─── Validate file exists ────────────────────────────────────────────────────
$errors   = [System.Collections.ArrayList]::new()
$warnings = [System.Collections.ArrayList]::new()

if (-not (Test-Path $AgentPath)) {
    [void]$errors.Add("Agent file not found: '$AgentPath'")
    $result = [PSCustomObject]@{
        Valid       = $false
        AgentName   = ''
        Errors      = $errors.ToArray()
        Warnings    = $warnings.ToArray()
        Tools       = @()
        Scripts     = @()
        WouldInvoke = @()
        DryRun      = $DryRun.IsPresent
    }
    Write-Host "❌ Validation failed: agent file not found." -ForegroundColor Red
    return $result
}

$resolvedPath = (Resolve-Path $AgentPath).Path
$content      = Get-Content -Path $resolvedPath -Raw
$basePath     = Resolve-AgentBasePath $resolvedPath

# ─── Parse frontmatter ───────────────────────────────────────────────────────
$frontmatter = Read-Frontmatter -Content $content

# ─── 1. Required field validation ───────────────────────────────────────────
foreach ($field in $RequiredFields) {
    if (-not $frontmatter.ContainsKey($field) -or
        ($frontmatter[$field] -is [string] -and [string]::IsNullOrWhiteSpace($frontmatter[$field])) -or
        ($frontmatter[$field] -is [array]  -and $frontmatter[$field].Count -eq 0)) {
        [void]$errors.Add("Missing required frontmatter field: '$field'.")
    }
}

$agentName = if ($frontmatter.ContainsKey('name')) { $frontmatter['name'] } else { '' }

# ─── 2. Tools field ─────────────────────────────────────────────────────────
$tools = @()
if ($frontmatter.ContainsKey('tools')) {
    $rawTools = $frontmatter['tools']
    $tools    = if ($rawTools -is [array]) { $rawTools } else { @($rawTools) }
    $tools    = $tools | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

# ─── 3. Body / script references ────────────────────────────────────────────
# Use the frontmatter closing delimiter position from the regex match in Read-Frontmatter.
# Re-match here to locate where the frontmatter ends so the body is extracted reliably.
if ($content -match '(?s)^---\r?\n.+?\r?\n---\r?\n?') {
    $body = $content.Substring($Matches[0].Length).TrimStart()
}
else {
    $body = $content
}

$scriptRefs = Find-ScriptReferences -Body $body

# ─── 4. Check referenced files exist ────────────────────────────────────────
foreach ($scriptRef in $scriptRefs) {
    # Only check paths that look like relative paths (contain directory separators)
    if ($scriptRef -match '[/\\]') {
        $candidate = Join-Path $basePath $scriptRef
        if (-not (Test-Path $candidate)) {
            [void]$warnings.Add("Referenced script not found: '$scriptRef' (resolved to '$candidate').")
        }
    }
}

# ─── 5. Warn if description is very short ───────────────────────────────────
if ($frontmatter.ContainsKey('description')) {
    $desc = $frontmatter['description']
    if ($desc -is [string] -and $desc.Length -lt 20) {
        [void]$warnings.Add("Agent description is very short (< 20 characters). Consider expanding it.")
    }
}

# ─── 6. Simulate workflow steps (non-DryRun only) ───────────────────────────
$wouldInvoke = [System.Collections.ArrayList]::new()

if (-not $DryRun) {
    # Add declared tools
    foreach ($tool in $tools) {
        [void]$wouldInvoke.Add("tool:$tool")
    }

    # Add script references from body
    foreach ($script in $scriptRefs) {
        [void]$wouldInvoke.Add("script:$script")
    }

    # If a test issue was provided, note it would be fetched
    if (-not [string]::IsNullOrWhiteSpace($TestIssue)) {
        [void]$wouldInvoke.Insert(0, "fetch-issue:$TestIssue")
    }
}

# ─── Build result ────────────────────────────────────────────────────────────
$result = [PSCustomObject]@{
    Valid       = $errors.Count -eq 0
    AgentName   = $agentName
    Errors      = $errors.ToArray()
    Warnings    = $warnings.ToArray()
    Tools       = $tools
    Scripts     = $scriptRefs
    WouldInvoke = $wouldInvoke.ToArray()
    DryRun      = $DryRun.IsPresent
}

# ─── Output summary ──────────────────────────────────────────────────────────
if ($result.Valid) {
    Write-Host "✅ Agent '$agentName' is valid" -ForegroundColor Green
    if ($result.Warnings.Count -gt 0) {
        foreach ($w in $result.Warnings) {
            Write-Host "  ⚠ $w" -ForegroundColor Yellow
        }
    }
    if (-not $DryRun) {
        Write-Host "  Would invoke:" -ForegroundColor Cyan
        foreach ($inv in $result.WouldInvoke) {
            Write-Host "    - $inv" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "  (dry-run — simulation skipped)" -ForegroundColor Gray
    }
}
else {
    Write-Host "❌ Agent validation failed ($($result.Errors.Count) error(s))" -ForegroundColor Red
    foreach ($e in $result.Errors) {
        Write-Host "  ✗ $e" -ForegroundColor Red
    }
    if ($result.Warnings.Count -gt 0) {
        foreach ($w in $result.Warnings) {
            Write-Host "  ⚠ $w" -ForegroundColor Yellow
        }
    }
}

$result
