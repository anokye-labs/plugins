<#
.SYNOPSIS
    Classify PR review thread comments by severity.

.DESCRIPTION
    Analyzes review thread comments to determine severity level based on keywords,
    tone, and content. Returns: Critical, High, Medium, Low, or Info.
    
    Severity levels:
    - Critical: Blocking issues, security vulnerabilities, data loss risks
    - High: Major bugs, incorrect logic, breaking changes
    - Medium: Code quality issues, maintainability concerns
    - Low: Minor improvements, style suggestions
    - Info: Questions, clarifications, informational comments

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER ThreadId
    Specific thread ID to analyze. If omitted, analyzes all unresolved threads.

.PARAMETER ThreadIndex
    Zero-based index into unresolved threads (alternative to ThreadId).

.EXAMPLE
    .\Get-ThreadSeverity.ps1 -Owner anokye-labs -Repo plugins -PullNumber 6
    
    Analyzes all unresolved threads and returns severity for each.

.EXAMPLE
    .\Get-ThreadSeverity.ps1 -Owner anokye-labs -Repo plugins -PullNumber 6 -ThreadIndex 0
    
    Analyzes thread at index 0 and returns its severity.

.OUTPUTS
    PSCustomObject with properties: ThreadId, Severity, Confidence, Reason, FirstComment
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [string]$ThreadId,
    [int]$ThreadIndex = -1
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

# Constants
$PREVIEW_MAX_LENGTH = 200

# Severity keywords and patterns
$severityPatterns = @{
    Critical = @(
        'security\s+(?:vulnerability|flaw|issue)',
        'data\s+loss',
        'critical\s+(?:bug|issue|error)',
        'blocking',
        'breaks?\s+(?:production|build|tests?)',
        'must\s+(?:fix|be\s+fixed)',
        'vulnerable\s+to',
        'injection',
        'authentication\s+bypass',
        'unauthorized\s+access'
    )
    High = @(
        '\b(?:bug|error|issue|problem|broken|fails?)\b',
        'incorrect\s+(?:logic|behavior|implementation)',
        "doesn't\s+work",
        'breaking\s+change',
        'regression',
        'memory\s+leak',
        'race\s+condition',
        'deadlock',
        'should\s+(?:not|never)'
    )
    Medium = @(
        'code\s+quality',
        'maintainability',
        'readability',
        'refactor',
        'technical\s+debt',
        'could\s+(?:be\s+)?(?:improved|better)',
        'consider\s+(?:using|changing)',
        'suggest',
        'recommend',
        'might\s+want\s+to'
    )
    Low = @(
        'nit:?',
        'nitpick',
        'minor',
        'style',
        'formatting',
        'typo',
        'spelling',
        'whitespace',
        'optional',
        'preference'
    )
    Info = @(
        '\?$',
        'question:?',
        'why\s+(?:do|does|did|is|are)',
        'what\s+(?:is|are|does)',
        'how\s+(?:do|does)',
        'curious',
        'wondering',
        'fyi',
        'note:?',
        'just\s+(?:a\s+)?(?:note|fyi|info)'
    )
}

# Fetch thread(s)
if ($ThreadId) {
    # Fetch specific thread
    $nodeQuery = @"
{
  node(id: `"$ThreadId`") {
    ... on PullRequestReviewThread {
      id
      isResolved
      path
      line
      comments(first: 10) {
        nodes {
          author { login }
          body
          createdAt
        }
      }
    }
  }
}
"@
    $result = Invoke-GraphQL -Query $nodeQuery

    $threads = @($result.data.node)
} elseif ($ThreadIndex -ge 0) {
    # Fetch all unresolved and pick by index
    $indexQuery = @"
{
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          comments(first: 10) {
            nodes {
              author { login }
              body
              createdAt
            }
          }
        }
      }
    }
  }
}
"@
    $result = Invoke-GraphQL -Query $indexQuery
    
    $unresolved = $result.data.repository.pullRequest.reviewThreads.nodes | Where-Object { -not $_.isResolved }
    if ($ThreadIndex -ge $unresolved.Count) {
        Write-Error "ThreadIndex $ThreadIndex out of range. Only $($unresolved.Count) unresolved threads."
        exit 1
    }
    $threads = @($unresolved[$ThreadIndex])
} else {
    # Fetch all unresolved threads
    $allQuery = @"
{
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          comments(first: 10) {
            nodes {
              author { login }
              body
              createdAt
            }
          }
        }
      }
    }
  }
}
"@
    $result = Invoke-GraphQL -Query $allQuery
    
    $threads = $result.data.repository.pullRequest.reviewThreads.nodes | Where-Object { -not $_.isResolved }
}

# Analyze each thread
$results = @()

foreach ($thread in $threads) {
    if (-not $thread.comments.nodes -or $thread.comments.nodes.Count -eq 0) {
        continue
    }
    
    # Combine all comments in thread for analysis
    $allText = ($thread.comments.nodes | ForEach-Object { if ($_.body) { $_.body } }) -join " "
    $firstComment = $thread.comments.nodes[0].body
    
    # Score each severity level
    $scores = @{}
    foreach ($severity in $severityPatterns.Keys) {
        $score = 0
        foreach ($pattern in $severityPatterns[$severity]) {
            if ($allText -and $allText -imatch $pattern) {
                $score++
            }
        }
        $scores[$severity] = $score
    }
    
    # Determine severity based on highest score
    $maxScore = ($scores.Values | Measure-Object -Maximum).Maximum
    
    if ($maxScore -eq 0) {
        # No patterns matched, default to Medium
        $determinedSeverity = "Medium"
        $confidence = "Low"
        $reason = "No specific severity indicators found"
    } else {
        # Find severity with highest score
        $matchedSeverities = $scores.GetEnumerator() | Where-Object { $_.Value -eq $maxScore } | ForEach-Object { $_.Key }
        
        # If multiple severities tied, pick the highest priority
        $priorityOrder = @("Critical", "High", "Medium", "Low", "Info")
        $determinedSeverity = $priorityOrder | Where-Object { $_ -in $matchedSeverities } | Select-Object -First 1
        
        # Calculate confidence based on score
        if ($maxScore -ge 3) {
            $confidence = "High"
        } elseif ($maxScore -eq 2) {
            $confidence = "Medium"
        } else {
            $confidence = "Low"
        }
        
        # Find which patterns matched
        $matchedPatterns = @()
        foreach ($pattern in $severityPatterns[$determinedSeverity]) {
            if ($allText -and $allText -imatch $pattern) {
                $matchedPatterns += $pattern
            }
        }
        $reason = "Matched patterns: " + ($matchedPatterns -join ", ")
    }
    
    $result = [PSCustomObject]@{
        ThreadId = $thread.id
        Path = $thread.path
        Line = $thread.line
        Severity = $determinedSeverity
        Confidence = $confidence
        Reason = $reason
        FirstComment = if ($firstComment) { 
            $firstComment.Substring(0, [Math]::Min($PREVIEW_MAX_LENGTH, $firstComment.Length)) 
        } else { 
            "" 
        }
        CommentCount = $thread.comments.nodes.Count
    }
    
    $results += $result
}

# Output results
if ($results.Count -eq 0) {
    Write-Host "No threads to analyze." -ForegroundColor Yellow
} else {
    Write-Host "`nThread Severity Analysis for $Owner/$Repo PR #$PullNumber" -ForegroundColor Cyan
    Write-Host "Found $($results.Count) thread(s)`n" -ForegroundColor Gray
    
    foreach ($r in $results) {
        $severityColor = switch ($r.Severity) {
            "Critical" { "Red" }
            "High" { "Magenta" }
            "Medium" { "Yellow" }
            "Low" { "Blue" }
            "Info" { "Cyan" }
        }
        
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "Thread: $($r.Path):$($r.Line)" -ForegroundColor White
        Write-Host "Severity: " -NoNewline
        Write-Host $r.Severity -ForegroundColor $severityColor -NoNewline
        Write-Host " (Confidence: $($r.Confidence))" -ForegroundColor Gray
        Write-Host "Reason: $($r.Reason)" -ForegroundColor DarkGray
        Write-Host "Preview: $($r.FirstComment)" -ForegroundColor Gray
        Write-Host ""
    }
}

# Return objects to pipeline
return $results
