# OkyeremanAgentRunner.psm1
# Shared agent runner module for Anokye Labs agent archetypes
# Provides common functions for logging, error handling, issue context, PR management, etc.

#region Logging

<#
.SYNOPSIS
    Writes a structured log entry.

.DESCRIPTION
    Outputs a structured log entry with timestamp, level, agent name, correlation ID, and message.
    Supports pipeline-friendly object output and GitHub Actions annotations.

.PARAMETER Message
    The log message to write.

.PARAMETER Level
    Log level: Debug, Info, Warn, or Error. Default is Info.

.PARAMETER Agent
    Name of the agent generating the log. Optional.

.PARAMETER CorrelationId
    Correlation ID for tracking related actions. Optional.

.PARAMETER AsObject
    If set, returns a PSCustomObject instead of writing to host.

.PARAMETER Quiet
    If set, suppresses console output (useful when logging internally).

.EXAMPLE
    Write-AgentLog -Message "Processing issue #42" -Level Info -Agent "Asafo"

.EXAMPLE
    Write-AgentLog "Task completed" -Level Info -CorrelationId "abc123" -AsObject
#>
function Write-AgentLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Debug', 'Info', 'Warn', 'Error')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$Agent = '',

        [Parameter()]
        [string]$CorrelationId = '',

        [Parameter()]
        [switch]$AsObject,

        [Parameter()]
        [switch]$Quiet
    )

    $timestamp = Get-Date -Format 'o'
    
    $logEntry = [PSCustomObject]@{
        Timestamp     = $timestamp
        Level         = $Level
        Agent         = $Agent
        CorrelationId = $CorrelationId
        Message       = $Message
    }

    if ($AsObject) {
        return $logEntry
    }

    if (-not $Quiet) {
        # Console output with color coding
        $color = switch ($Level) {
            'Debug' { 'Gray' }
            'Info'  { 'White' }
            'Warn'  { 'Yellow' }
            'Error' { 'Red' }
        }

        $prefix = if ($Agent) { "[$Agent]" } else { "" }
        $correlationSuffix = if ($CorrelationId) { " [CID:$CorrelationId]" } else { "" }
        
        Write-Host "$timestamp [$Level]$prefix $Message$correlationSuffix" -ForegroundColor $color

        # GitHub Actions annotations for warnings and errors
        if ($env:GITHUB_ACTIONS -eq 'true') {
            switch ($Level) {
                'Warn'  { Write-Output "::warning::$Message" }
                'Error' { Write-Output "::error::$Message" }
            }
        }
    }
}

#endregion

#region GraphQL

<#
.SYNOPSIS
    Invokes a GitHub GraphQL API call with retry logic and rate-limit handling.

.DESCRIPTION
    Wraps `gh api graphql` with exponential backoff retry logic, automatic
    `GraphQL-Features: sub_issues` header injection when needed, rate-limit
    detection (429 / secondary rate limit), and structured error output.

.PARAMETER Query
    The GraphQL query or mutation string.

.PARAMETER SubIssues
    If set, injects the `GraphQL-Features: sub_issues` header required for
    sub-issue API operations.

.PARAMETER AdditionalHeaders
    A hashtable of additional HTTP headers to pass to `gh api graphql`.

.PARAMETER MaxRetries
    Maximum number of retry attempts on transient errors. Default is 3.

.PARAMETER InitialDelaySeconds
    Initial delay in seconds before the first retry. Default is 2.

.PARAMETER BackoffMultiplier
    Multiplier applied to the delay after each retry. Default is 2.

.PARAMETER MaxDelaySeconds
    Maximum delay between retries in seconds. Default is 60.

.EXAMPLE
    $result = Invoke-GraphQL -Query 'query { viewer { login } }'

.EXAMPLE
    $result = Invoke-GraphQL -Query $subIssueQuery -SubIssues

.EXAMPLE
    $result = Invoke-GraphQL -Query $mutation -AdditionalHeaders @{ 'X-Custom': 'value' }
#>
function Invoke-GraphQL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter()]
        [switch]$SubIssues,

        [Parameter()]
        [hashtable]$AdditionalHeaders = @{},

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$InitialDelaySeconds = 2,

        [Parameter()]
        [double]$BackoffMultiplier = 2,

        [Parameter()]
        [int]$MaxDelaySeconds = 60
    )

    $attempt = 0
    $delay = $InitialDelaySeconds
    # Pattern to detect rate-limit responses from the GitHub API
    $rateLimitPattern = '429|rate limit|secondary rate limit|too many requests'

    while ($attempt -le $MaxRetries) {
        $attempt++

        try {
            # Build header arguments
            $headerArgs = @()
            if ($SubIssues) {
                $headerArgs += '-H'
                $headerArgs += 'GraphQL-Features: sub_issues'
            }
            foreach ($key in $AdditionalHeaders.Keys) {
                $headerArgs += '-H'
                $headerArgs += "$key`: $($AdditionalHeaders[$key])"
            }

            # Invoke gh api graphql
            if ($headerArgs.Count -gt 0) {
                $rawResult = gh api graphql @headerArgs -f query="$Query" 2>&1
            }
            else {
                $rawResult = gh api graphql -f query="$Query" 2>&1
            }

            if ($LASTEXITCODE -ne 0) {
                $errorText = $rawResult | Out-String

                # Detect rate limiting from exit-code path
                if ($errorText -match $rateLimitPattern) {
                    throw [System.Exception]::new("rate limit: $errorText")
                }

                throw [System.Exception]::new("GraphQL command failed (exit $LASTEXITCODE): $errorText")
            }

            $parsed = $rawResult | ConvertFrom-Json

            # Surface GraphQL-level errors
            if ($parsed.errors) {
                $errorMsg = ($parsed.errors | ForEach-Object { $_.message }) -join '; '

                # Detect secondary rate limit in GraphQL error messages
                if ($errorMsg -match $rateLimitPattern) {
                    throw [System.Exception]::new("rate limit: $errorMsg")
                }

                throw [System.Exception]::new("GraphQL errors: $errorMsg")
            }

            return $parsed
        }
        catch {
            $errorMessage = $_.Exception.Message
            $isRateLimit = $errorMessage -match $rateLimitPattern

            if ($attempt -gt $MaxRetries) {
                Write-AgentLog "All $MaxRetries retry attempt(s) exhausted: $errorMessage" -Level Error -Quiet
                throw
            }

            if ($isRateLimit) {
                $retryAfter = 60
                Write-AgentLog "Rate limit detected. Waiting ${retryAfter}s before retry (attempt $attempt/$MaxRetries)..." -Level Warn -Quiet
                Start-Sleep -Seconds $retryAfter
            }
            else {
                Write-AgentLog "Attempt $attempt failed: $errorMessage. Retrying in ${delay}s..." -Level Warn -Quiet
                Start-Sleep -Seconds $delay
                $delay = [Math]::Min($delay * $BackoffMultiplier, $MaxDelaySeconds)
            }
        }
    }
}

#endregion

#region Error Handling

<#
.SYNOPSIS
    Invokes a script block with retry logic and exponential backoff.

.DESCRIPTION
    Executes a script block and retries on failure with configurable backoff.
    Detects rate limiting and waits appropriately.

.PARAMETER ScriptBlock
    The script block to execute.

.PARAMETER MaxRetries
    Maximum number of retry attempts. Default is 3.

.PARAMETER InitialDelaySeconds
    Initial delay in seconds before first retry. Default is 2.

.PARAMETER BackoffMultiplier
    Multiplier for exponential backoff. Default is 2.

.PARAMETER MaxDelaySeconds
    Maximum delay between retries in seconds. Default is 60.

.EXAMPLE
    Invoke-WithRetry -ScriptBlock { gh api graphql -f query=$query } -MaxRetries 5

.EXAMPLE
    $result = Invoke-WithRetry { SomeRiskyOperation } -InitialDelaySeconds 5
#>
function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$InitialDelaySeconds = 2,

        [Parameter()]
        [double]$BackoffMultiplier = 2,

        [Parameter()]
        [int]$MaxDelaySeconds = 60
    )

    $attempt = 0
    $delay = $InitialDelaySeconds

    while ($attempt -le $MaxRetries) {
        try {
            $attempt++
            $result = & $ScriptBlock
            return $result
        }
        catch {
            $errorMessage = $_.Exception.Message
            
            # Check for rate limiting
            if ($errorMessage -match 'rate limit|too many requests|429') {
                if ($attempt -gt $MaxRetries) {
                    Write-AgentLog "All $MaxRetries retry attempts exhausted (rate limit)." -Level Error -Quiet
                    throw
                }
                
                Write-AgentLog "Rate limit detected. Waiting before retry..." -Level Warn -Quiet
                
                # Try to parse retry-after header if available
                $retryAfter = 60
                if ($_.Exception.Response.Headers -and $_.Exception.Response.Headers['Retry-After']) {
                    $retryAfter = [int]$_.Exception.Response.Headers['Retry-After']
                }
                Start-Sleep -Seconds $retryAfter
            }
            elseif ($attempt -le $MaxRetries) {
                Write-AgentLog "Attempt $attempt failed: $errorMessage. Retrying in $delay seconds..." -Level Warn -Quiet
                Start-Sleep -Seconds $delay
                $delay = [Math]::Min($delay * $BackoffMultiplier, $MaxDelaySeconds)
            }
            else {
                Write-AgentLog "All $MaxRetries retry attempts exhausted." -Level Error -Quiet
                throw
            }
        }
    }
}

<#
.SYNOPSIS
    Creates a structured error object for agent failures.

.DESCRIPTION
    Returns a standardized error object for graceful failure handling.

.PARAMETER Message
    Error message.

.PARAMETER ErrorCode
    Error code or category.

.PARAMETER Details
    Additional error details.

.EXAMPLE
    New-AgentError -Message "Failed to create issue" -ErrorCode "GraphQLError" -Details $_.Exception.Message
#>
function New-AgentError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$ErrorCode = 'UnknownError',

        [Parameter()]
        [string]$Details = ''
    )

    return [PSCustomObject]@{
        Success   = $false
        Message   = $Message
        ErrorCode = $ErrorCode
        Details   = $Details
        Timestamp = Get-Date -Format 'o'
    }
}

#endregion

#region Issue Context

<#
.SYNOPSIS
    Loads issue details including parent, sub-issues, and labels.

.DESCRIPTION
    Queries GitHub GraphQL API to retrieve comprehensive issue context.
    Caches results for the session to minimize API calls.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER IssueNumber
    Issue number to query.

.PARAMETER UseCache
    If set, uses cached context if available. Default is true.

.EXAMPLE
    $context = Get-IssueContext -Owner anokye-labs -Repo plugins -IssueNumber 42

.EXAMPLE
    $context = Get-IssueContext -Owner myorg -Repo myrepo -IssueNumber 10 -UseCache:$false
#>
function Get-IssueContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [int]$IssueNumber,

        [Parameter()]
        [bool]$UseCache = $true
    )

    $cacheKey = "$Owner/$Repo#$IssueNumber"
    
    if ($UseCache -and $script:IssueContextCache -and $script:IssueContextCache.ContainsKey($cacheKey)) {
        Write-AgentLog "Using cached context for $cacheKey" -Level Debug -Quiet
        return $script:IssueContextCache[$cacheKey]
    }

    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $IssueNumber) {
      id
      number
      title
      body
      state
      issueType { name }
      labels(first: 50) {
        nodes { name }
      }
      parentIssue {
        number
        title
        issueType { name }
      }
      subIssues(first: 100) {
        nodes {
          number
          title
          state
          issueType { name }
        }
      }
      projectItems(first: 20) {
        nodes {
          id
          project { title number }
        }
      }
    }
  }
}
"@

    try {
        $result = Invoke-WithRetry -ScriptBlock {
            gh api graphql -H "GraphQL-Features: sub_issues" -f query=$query | ConvertFrom-Json
        }

        $context = $result.data.repository.issue

        # Initialize cache if needed
        if (-not $script:IssueContextCache) {
            $script:IssueContextCache = @{}
        }

        # Cache the result
        $script:IssueContextCache[$cacheKey] = $context

        return $context
    }
    catch {
        Write-AgentLog "Failed to load issue context for $cacheKey : $_" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Clears the issue context cache.

.DESCRIPTION
    Removes all cached issue contexts from the current session.

.EXAMPLE
    Clear-IssueContextCache
#>
function Clear-IssueContextCache {
    [CmdletBinding()]
    param()

    $script:IssueContextCache = @{}
    Write-AgentLog "Issue context cache cleared" -Level Debug -Quiet
}

#endregion

#region PR Management

<#
.SYNOPSIS
    Creates a pull request from the current branch with issue linkage.

.DESCRIPTION
    Creates a PR and optionally links it to an issue using closing keywords.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER Title
    PR title.

.PARAMETER Body
    PR description/body.

.PARAMETER Base
    Base branch. Default is 'main'.

.PARAMETER Head
    Head branch. If not specified, uses current branch.

.PARAMETER IssueNumber
    Optional issue number to link with 'Closes #N' syntax.

.EXAMPLE
    New-AgentPR -Owner anokye-labs -Repo plugins -Title "Fix logging" -Body "Implements structured logging" -IssueNumber 13

.EXAMPLE
    New-AgentPR -Owner myorg -Repo myrepo -Title "Add feature" -Body "New feature" -Base develop
#>
function New-AgentPR {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Body,

        [Parameter()]
        [string]$Base = 'main',

        [Parameter()]
        [string]$Head = '',

        [Parameter()]
        [int]$IssueNumber = 0
    )

    # Get current branch if Head not specified
    if (-not $Head) {
        $Head = git branch --show-current
        if (-not $Head) {
            throw "Could not determine current branch and Head parameter not provided"
        }
    }

    # Add issue linkage if provided
    $prBody = $Body
    if ($IssueNumber -gt 0) {
        $prBody = "$Body`n`nCloses #$IssueNumber"
    }

    # Escape strings for GraphQL
    $escapedTitle = $Title.Replace('\', '\\').Replace('"', '\"')
    $escapedBody = $prBody.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')
    $escapedHead = $Head.Replace('\', '\\').Replace('"', '\"')
    $escapedBase = $Base.Replace('\', '\\').Replace('"', '\"')

    # Get repository ID
    $repoQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    id
  }
}
"@

    try {
        $repoResult = gh api graphql -f query=$repoQuery | ConvertFrom-Json
        $repoId = $repoResult.data.repository.id

        # Create PR mutation
        $mutation = @"
mutation {
  createPullRequest(input: {
    repositoryId: `"$repoId`"
    title: `"$escapedTitle`"
    body: `"$escapedBody`"
    baseRefName: `"$escapedBase`"
    headRefName: `"$escapedHead`"
  }) {
    pullRequest {
      id
      number
      title
      url
    }
  }
}
"@

        $result = gh api graphql -f query=$mutation | ConvertFrom-Json
        $pr = $result.data.createPullRequest.pullRequest

        Write-AgentLog "✓ Created PR #$($pr.number): $($pr.title)" -Level Info
        Write-AgentLog "  URL: $($pr.url)" -Level Info

        return $pr
    }
    catch {
        Write-AgentLog "Failed to create PR: $_" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Gets the status of a pull request including checks and reviews.

.DESCRIPTION
    Queries PR status, check runs, review state, and mergeable status.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    PR number.

.EXAMPLE
    $status = Get-PRStatus -Owner anokye-labs -Repo plugins -PullNumber 42
#>
function Get-PRStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [int]$PullNumber
    )

    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      id
      number
      title
      state
      mergeable
      merged
      reviewDecision
      commits(last: 1) {
        nodes {
          commit {
            statusCheckRollup {
              state
              contexts(first: 100) {
                nodes {
                  ... on CheckRun {
                    name
                    conclusion
                    status
                  }
                  ... on StatusContext {
                    context
                    state
                  }
                }
              }
            }
          }
        }
      }
      reviewThreads(first: 100) {
        totalCount
        nodes {
          isResolved
          isOutdated
        }
      }
    }
  }
}
"@

    try {
        $result = gh api graphql -f query=$query | ConvertFrom-Json
        return $result.data.repository.pullRequest
    }
    catch {
        Write-AgentLog "Failed to get PR status for #$PullNumber : $_" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Posts a structured review comment on a pull request.

.DESCRIPTION
    Adds a review comment to a PR with optional review state.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    PR number.

.PARAMETER Body
    Review comment body (markdown supported).

.PARAMETER Event
    Review event type: COMMENT, APPROVE, or REQUEST_CHANGES. Default is COMMENT.

.EXAMPLE
    Add-PRReviewComment -Owner anokye-labs -Repo plugins -PullNumber 42 -Body "LGTM! ✓" -Event APPROVE

.EXAMPLE
    Add-PRReviewComment -Owner myorg -Repo myrepo -PullNumber 10 -Body "Please fix the tests"
#>
function Add-PRReviewComment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [int]$PullNumber,

        [Parameter(Mandatory)]
        [string]$Body,

        [Parameter()]
        [ValidateSet('COMMENT', 'APPROVE', 'REQUEST_CHANGES')]
        [string]$Event = 'COMMENT'
    )

    # Get PR node ID
    $prQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      id
    }
  }
}
"@

    try {
        $prResult = gh api graphql -f query=$prQuery | ConvertFrom-Json
        $prId = $prResult.data.repository.pullRequest.id

        # Escape body
        $escapedBody = $Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')

        # Add review
        $mutation = @"
mutation {
  addPullRequestReview(input: {
    pullRequestId: `"$prId`"
    body: `"$escapedBody`"
    event: $Event
  }) {
    pullRequestReview {
      id
      author { login }
    }
  }
}
"@

        $result = gh api graphql -f query=$mutation | ConvertFrom-Json
        Write-AgentLog "✓ Added review comment to PR #$PullNumber" -Level Info
        return $result.data.addPullRequestReview.pullRequestReview
    }
    catch {
        Write-AgentLog "Failed to add review comment: $_" -Level Error
        throw
    }
}

#endregion

#region Safe Output Processing

<#
.SYNOPSIS
    Sanitizes agent output by removing secrets and PII patterns.

.DESCRIPTION
    Scans text for common secret patterns (API keys, tokens) and PII
    (email addresses, phone numbers) and redacts them.

.PARAMETER Text
    Text to sanitize.

.PARAMETER RedactionMarker
    String to use for redaction. Default is '[REDACTED]'.

.PARAMETER IncludeGenericSecrets
    If set, also redacts generic uppercase alphanumeric strings (32+ chars).
    This may produce false positives. Default is false.

.EXAMPLE
    $safe = ConvertTo-SafeOutput -Text $agentResponse

.EXAMPLE
    ConvertTo-SafeOutput "My token is ghp_1234567890" -RedactionMarker "***"
    
.EXAMPLE
    ConvertTo-SafeOutput $text -IncludeGenericSecrets
#>
function ConvertTo-SafeOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Text,

        [Parameter()]
        [string]$RedactionMarker = '[REDACTED]',

        [Parameter()]
        [switch]$IncludeGenericSecrets
    )

    process {
        $sanitized = $Text
        
        # Escape $ in RedactionMarker to prevent regex backreference interpretation
        $safeMarker = $RedactionMarker.Replace('$', '$$')

        # GitHub tokens (various types, 30+ characters)
        $sanitized = $sanitized -replace 'ghp_[a-zA-Z0-9]{30,}', $safeMarker
        $sanitized = $sanitized -replace 'gho_[a-zA-Z0-9]{30,}', $safeMarker
        $sanitized = $sanitized -replace 'ghu_[a-zA-Z0-9]{30,}', $safeMarker
        $sanitized = $sanitized -replace 'ghs_[a-zA-Z0-9]{30,}', $safeMarker
        $sanitized = $sanitized -replace 'ghr_[a-zA-Z0-9]{30,}', $safeMarker
        $sanitized = $sanitized -replace 'github_pat_[a-zA-Z0-9_]{30,}', $safeMarker

        # Generic API keys (optional, may have false positives)
        if ($IncludeGenericSecrets) {
            $sanitized = $sanitized -replace '\b[A-Z0-9_]{32,}\b', $safeMarker
        }

        # Email addresses
        $sanitized = $sanitized -replace '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', $safeMarker

        # Phone numbers (US format)
        $sanitized = $sanitized -replace '\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', $safeMarker

        return $sanitized
    }
}

<#
.SYNOPSIS
    Truncates text to a maximum length.

.DESCRIPTION
    Limits text to specified length and adds ellipsis if truncated.

.PARAMETER Text
    Text to truncate.

.PARAMETER MaxLength
    Maximum length. Default is 1000.

.PARAMETER Ellipsis
    Ellipsis string to append. Default is '...'.

.EXAMPLE
    $short = Limit-OutputLength -Text $longText -MaxLength 500
#>
function Limit-OutputLength {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Text,

        [Parameter()]
        [int]$MaxLength = 1000,

        [Parameter()]
        [string]$Ellipsis = '...'
    )

    process {
        if ($Text.Length -le $MaxLength) {
            return $Text
        }

        $truncateAt = [Math]::Max(0, $MaxLength - $Ellipsis.Length)
        $truncated = $Text.Substring(0, $truncateAt) + $Ellipsis
        Write-AgentLog "Output truncated from $($Text.Length) to $MaxLength characters" -Level Debug -Quiet
        return $truncated
    }
}

<#
.SYNOPSIS
    Formats text for GitHub comment markdown.

.DESCRIPTION
    Wraps text in appropriate markdown formatting for GitHub comments.

.PARAMETER Text
    Text to format.

.PARAMETER Format
    Format type: Plain, Code, CodeBlock, or Quote. Default is Plain.

.PARAMETER Language
    Language for code blocks. Default is empty.

.EXAMPLE
    $formatted = ConvertTo-GitHubMarkdown -Text $code -Format CodeBlock -Language powershell

.EXAMPLE
    ConvertTo-GitHubMarkdown "Important note" -Format Quote
#>
function ConvertTo-GitHubMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Text,

        [Parameter()]
        [ValidateSet('Plain', 'Code', 'CodeBlock', 'Quote')]
        [string]$Format = 'Plain',

        [Parameter()]
        [string]$Language = ''
    )

    process {
        $nl = [System.Environment]::NewLine
        switch ($Format) {
            'Code' {
                return "``$Text``"
            }
            'CodeBlock' {
                $langMarker = if ($Language) { $Language } else { '' }
                $fence = '```'
                return "$fence$langMarker$nl$Text$nl$fence"
            }
            'Quote' {
                $lines = $Text -split $nl
                $quotedLines = @()
                foreach ($line in $lines) {
                    $quotedLines += ('> ' + $line)
                }
                return $quotedLines -join $nl
            }
            default {
                return $Text
            }
        }
    }
}

#endregion

#region Correlation Tracking

<#
.SYNOPSIS
    Generates a new correlation ID.

.DESCRIPTION
    Creates a unique correlation ID for tracking agent actions across issues, PRs, and commits.

.PARAMETER Prefix
    Optional prefix for the correlation ID. Default is 'agent'.

.EXAMPLE
    $correlationId = New-CorrelationId

.EXAMPLE
    $correlationId = New-CorrelationId -Prefix 'asafo'
#>
function New-CorrelationId {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Prefix = 'agent'
    )

    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    $random = Get-Random -Minimum 1000 -Maximum 9999
    return "$Prefix-$timestamp-$random"
}

<#
.SYNOPSIS
    Stores a correlation ID for the current session.

.DESCRIPTION
    Saves a correlation ID to session variable for reuse across operations.

.PARAMETER CorrelationId
    Correlation ID to store. Can be empty to clear the current ID.

.EXAMPLE
    Set-CorrelationId -CorrelationId $cid

.EXAMPLE
    Set-CorrelationId -CorrelationId "" # Clear the ID
#>
function Set-CorrelationId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$CorrelationId
    )

    $script:CurrentCorrelationId = $CorrelationId
    if ($CorrelationId) {
        Write-AgentLog "Correlation ID set: $CorrelationId" -Level Debug -Quiet
    } else {
        Write-AgentLog "Correlation ID cleared" -Level Debug -Quiet
    }
}

<#
.SYNOPSIS
    Retrieves the current session correlation ID.

.DESCRIPTION
    Gets the stored correlation ID or generates a new one if none exists.

.PARAMETER AutoGenerate
    If true, generates a new correlation ID if none exists. Default is true.

.EXAMPLE
    $cid = Get-CorrelationId

.EXAMPLE
    $cid = Get-CorrelationId -AutoGenerate:$false
#>
function Get-CorrelationId {
    [CmdletBinding()]
    param(
        [Parameter()]
        [bool]$AutoGenerate = $true
    )

    if ($script:CurrentCorrelationId) {
        return $script:CurrentCorrelationId
    }

    if ($AutoGenerate) {
        $newId = New-CorrelationId
        Set-CorrelationId -CorrelationId $newId
        return $newId
    }

    return $null
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    # Logging
    'Write-AgentLog',

    # GraphQL
    'Invoke-GraphQL',
    
    # Error Handling
    'Invoke-WithRetry',
    'New-AgentError',
    
    # Issue Context
    'Get-IssueContext',
    'Clear-IssueContextCache',
    
    # PR Management
    'New-AgentPR',
    'Get-PRStatus',
    'Add-PRReviewComment',
    
    # Safe Output Processing
    'ConvertTo-SafeOutput',
    'Limit-OutputLength',
    'ConvertTo-GitHubMarkdown',
    
    # Correlation Tracking
    'New-CorrelationId',
    'Set-CorrelationId',
    'Get-CorrelationId'
)
