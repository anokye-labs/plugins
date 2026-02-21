#Requires -Version 5.1
<#
.SYNOPSIS
    Assesses the complexity of a triage round based on the threads to address.

.DESCRIPTION
    Takes a set of review threads with their dispositions and computes:
    - Complexity tier (simple/medium/complex)
    - Coding agent timeout in minutes
    - Max remaining rounds before escalation

    This is per-round, not per-PR. Round 1 may be simple while round 3 is complex.

.PARAMETER Threads
    Array of PSCustomObjects with properties: Disposition, Priority, HasSuggestion, FilePath

.PARAMETER CurrentRound
    The current round number (1-based).

.PARAMETER MaxRoundsOverride
    Optional override for max rounds (from initial PR complexity).

.EXAMPLE
    $threads = @(
        [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$true; FilePath='docs/README.md' }
    )
    Measure-RoundComplexity -Threads $threads -CurrentRound 1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject[]]$Threads,

    [Parameter(Mandatory)]
    [int]$CurrentRound,

    [Parameter()]
    [int]$MaxRoundsOverride = 0
)

$fixThreads = @($Threads | Where-Object { $_.Disposition -eq 'fix' })
$fixCount = $fixThreads.Count

# Count unique files involved
$uniqueFiles = @($fixThreads | Where-Object { $_.FilePath } | Select-Object -ExpandProperty FilePath -Unique)
$fileCount = $uniqueFiles.Count

# Count suggestions (easy to apply) vs code fixes (harder)
$suggestionCount = @($fixThreads | Where-Object { $_.HasSuggestion }).Count
$codeFixes = $fixCount - $suggestionCount

# Any critical priority?
$hasCritical = @($fixThreads | Where-Object { $_.Priority -eq 'critical' }).Count -gt 0

# Complexity scoring
$score = 0
$score += [Math]::Min($codeFixes * 2, 10)    # code fixes are harder
$score += [Math]::Min($suggestionCount, 3)    # suggestions are easy
$score += [Math]::Min($fileCount, 5)          # more files = more complex
if ($hasCritical) { $score += 3 }             # critical = extra complexity

# Tier thresholds
if ($score -le 3) {
    $tier = 'simple'
    $codingTimeout = 10
    $baseMaxRounds = 2
} elseif ($score -le 8) {
    $tier = 'medium'
    $codingTimeout = 30
    $baseMaxRounds = 3
} else {
    $tier = 'complex'
    $codingTimeout = 60
    $baseMaxRounds = 5
}

$maxRounds = if ($MaxRoundsOverride -gt 0) { $MaxRoundsOverride } else { $baseMaxRounds }
$remainingRounds = [Math]::Max(0, $maxRounds - $CurrentRound)

return [PSCustomObject]@{
    Tier             = $tier
    Score            = $score
    CodingTimeoutMin = $codingTimeout
    ReviewTimeoutMin = [Math]::Max(15, [int]($codingTimeout / 2))
    MaxRounds        = $maxRounds
    CurrentRound     = $CurrentRound
    RemainingRounds  = $remainingRounds
    ShouldEscalate   = $remainingRounds -le 0
    FixCount         = $fixCount
    SuggestionCount  = $suggestionCount
    CodeFixCount     = $codeFixes
    UniqueFiles      = $fileCount
    HasCritical      = $hasCritical
}
