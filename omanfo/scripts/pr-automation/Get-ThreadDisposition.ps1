#Requires -Version 5.1
<#
.SYNOPSIS
    Classifies a PR review thread into a disposition for the triage agent.

.DESCRIPTION
    Deterministic classifier that examines a review thread's content, author,
    and signals to decide how the triage agent should handle it.

    Dispositions:
    - resolve    : Informational/acknowledged, resolve the thread
    - fix        : Coding agent should address this (push a commit)
    - create-issue : Valid concern but defer to a future issue
    - needs-human  : Escalate to a human reviewer

.PARAMETER Body
    The text body of the first comment in the review thread.

.PARAMETER Author
    The login of the comment author (e.g., 'devin-ai-integration[bot]').

.PARAMETER HasSuggestion
    Whether the comment contains a GitHub suggestion block.

.PARAMETER Reactions
    Hashtable of reactions on the comment (e.g., @{'+1'=2; '-1'=0}).

.PARAMETER Severity
    Optional severity extracted from the comment (e.g., 'P1', 'Critical').

.EXAMPLE
    Get-ThreadDisposition -Body "Consider renaming this variable" -Author "devin-ai-integration[bot]"
    # Returns: resolve

.EXAMPLE
    Get-ThreadDisposition -Body "Security: SQL injection via string concat" -Author "copilot-pull-request-reviewer[bot]"
    # Returns: fix
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Body,

    [Parameter(Mandatory)]
    [string]$Author,

    [Parameter()]
    [switch]$HasSuggestion,

    [Parameter()]
    [hashtable]$Reactions = @{},

    [Parameter()]
    [string]$Severity = ''
)

# Normalize
$bodyLower = $Body.ToLower()
$isBot = $Author -match '\[bot\]$' -or $Author -match '^app/'

# --- Security / Critical patterns (always fix) ---
$securityPatterns = @(
    'security vulnerabilit',
    'sql injection',
    'command injection',
    'xss vulnerabilit',
    'hardcoded secret',
    'hardcoded password',
    'hardcoded api.?key',
    'credential[s]? leak',
    'authentication bypass',
    'data loss'
)

foreach ($pattern in $securityPatterns) {
    if ($bodyLower -match $pattern) {
        return [PSCustomObject]@{
            Disposition = 'fix'
            Reason      = "Security concern detected: matches pattern '$pattern'"
            Priority    = 'critical'
        }
    }
}

# --- Explicit severity badges (Codex pattern: P1/P2/P3) ---
if ($Severity -match '^P[12]$' -or $Severity -match '^(Critical|High)$' -or $bodyLower -match 'P1[- ]' -or $bodyLower -match '!\[P1') {
    # P1/P2 or Critical/High → fix
    return [PSCustomObject]@{
        Disposition = 'fix'
        Reason      = "High-priority review comment (severity: $Severity)"
        Priority    = 'high'
    }
}

# --- GitHub suggestion blocks → fix (agent can apply directly) ---
if ($HasSuggestion -or $Body -match '```suggestion') {
    return [PSCustomObject]@{
        Disposition = 'fix'
        Reason      = 'Comment contains a GitHub suggestion block that can be applied'
        Priority    = 'medium'
    }
}

# --- Breaking / functional correctness patterns → fix ---
$breakingPatterns = @(
    'will (cause|result in|lead to) (fail|error|crash|break)',
    'does not (work|function|support|handle)',
    'is (broken|incorrect|wrong|missing)',
    'fails? (with|when|silently|explicit)',
    'undefined (variable|function|property)',
    'not (supported|implemented|handled)',
    'required .* missing',
    'type.?error',
    'runtime.?error'
)

foreach ($pattern in $breakingPatterns) {
    if ($bodyLower -match $pattern) {
        return [PSCustomObject]@{
            Disposition = 'fix'
            Reason      = "Functional concern detected: matches pattern '$pattern'"
            Priority    = 'medium'
        }
    }
}

# --- Architecture / design concerns → needs-human ---
$architecturePatterns = @(
    'architect',
    'design (decision|choice|pattern|question)',
    'should (we|this) (instead|rather)',
    'fundamentally',
    'refactor.*(entire|whole|significant)',
    'breaking change',
    'backward.?compat',
    'migration (path|strategy|plan)'
)

foreach ($pattern in $architecturePatterns) {
    if ($bodyLower -match $pattern) {
        return [PSCustomObject]@{
            Disposition = 'needs-human'
            Reason      = "Architecture/design concern: matches pattern '$pattern'"
            Priority    = 'high'
        }
    }
}

# --- Test coverage requests → create-issue ---
$testPatterns = @(
    'missing test',
    'no test',
    'test coverage',
    'should (have|include|add) test',
    'untested'
)

foreach ($pattern in $testPatterns) {
    if ($bodyLower -match $pattern) {
        return [PSCustomObject]@{
            Disposition = 'create-issue'
            Reason      = "Test coverage request: matches pattern '$pattern'"
            Priority    = 'low'
        }
    }
}

# --- Informational / noise patterns → resolve ---
$informationalPatterns = @(
    'useful\? react with',
    'nit:',
    'nitpick',
    'style (preference|suggestion|nit)',
    'consider (renaming|using|adding)',
    'optional:',
    'minor:',
    'fyi:',
    'note:',
    'for (your )?information'
)

foreach ($pattern in $informationalPatterns) {
    if ($bodyLower -match $pattern) {
        return [PSCustomObject]@{
            Disposition = 'resolve'
            Reason      = "Informational comment: matches pattern '$pattern'"
            Priority    = 'low'
        }
    }
}

# --- Bot comments with no actionable patterns → resolve ---
if ($isBot) {
    # Low severity from bots without any actionable pattern matched above
    if ($Severity -match '^P[345]$' -or $Severity -match '^(Low|Medium)$' -or $bodyLower -match '!\[P[345]') {
        return [PSCustomObject]@{
            Disposition = 'resolve'
            Reason      = "Low-priority bot comment (severity: $Severity)"
            Priority    = 'low'
        }
    }
}

# --- Default: if from a bot with no strong signal → resolve; from human → needs-human ---
if ($isBot) {
    return [PSCustomObject]@{
        Disposition = 'resolve'
        Reason      = 'Bot comment with no actionable pattern detected'
        Priority    = 'low'
    }
} else {
    return [PSCustomObject]@{
        Disposition = 'needs-human'
        Reason      = 'Human comment with no clear automated disposition'
        Priority    = 'medium'
    }
}
