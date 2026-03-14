#Requires -Version 5.1

<#
.SYNOPSIS
    Executes a GraphQL query via the GitHub CLI with retry and error handling.

.DESCRIPTION
    Shared helper that invokes a GraphQL query using `gh api graphql`.
    Automatically retries transient failures with exponential backoff and jitter.
    Non-retryable errors (authentication, authorization, validation) fail immediately.

.PARAMETER Query
    The GraphQL query string to execute.

.PARAMETER Headers
    Optional hashtable of additional HTTP headers to pass to the request.

.PARAMETER MaxAttempts
    Maximum number of attempts before giving up. Defaults to 3.

.PARAMETER BaseDelayMs
    Base delay in milliseconds for exponential backoff. Defaults to 1000.
    The actual delay doubles on each retry (1s, 2s, 4s) with +/-25% jitter.
#>
function Invoke-GraphQL {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$Query,
        [hashtable]$Headers = @{},
        [int]$MaxAttempts = 3,
        [Alias('RetryDelayMs')]
        [int]$BaseDelayMs = 1000
    )

    $ErrorActionPreference = "Stop"

    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        try {
            $headerArgs = @()
            foreach ($key in $Headers.Keys) {
                $headerArgs += "-H"
                $headerArgs += "$key`: $($Headers[$key])"
            }

            if ($headerArgs.Count -gt 0) {
                $result = gh api graphql @headerArgs -f query="$Query" 2>&1
            } else {
                $result = gh api graphql -f query="$Query" 2>&1
            }

            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                throw "GraphQL command failed with exit code $LASTEXITCODE`: $result"
            }

            $parsed = $result | ConvertFrom-Json
            if ($parsed.errors) {
                $errorMsg = ($parsed.errors | ForEach-Object { $_.message }) -join '; '
                throw "GraphQL errors: $errorMsg"
            }

            return $parsed
        }
        catch {
            $errorMessage = $_.Exception.Message

            # Non-retryable errors — fail immediately
            $nonRetryablePatterns = @('NOT_FOUND', 'FORBIDDEN', 'UNAUTHORIZED', 'INSUFFICIENT_SCOPES')
            $isNonRetryable = $false
            foreach ($pattern in $nonRetryablePatterns) {
                if ($errorMessage -match $pattern) {
                    $isNonRetryable = $true
                    break
                }
            }

            # Validation errors are also non-retryable
            if ($errorMessage -match 'Variable .+ was defined|parse error|syntax error|argument .+ has invalid value') {
                $isNonRetryable = $true
            }

            if ($isNonRetryable -or $attempt -ge $MaxAttempts) {
                throw
            }

            # Exponential backoff with jitter
            $baseDelay = [math]::Pow(2, $attempt - 1) * $BaseDelayMs
            $jitter = Get-Random -Minimum ([int](-0.25 * $baseDelay)) -Maximum ([int](0.25 * $baseDelay))
            $sleepMs = [math]::Max(100, $baseDelay + $jitter)
            Write-Warning "Attempt $attempt failed: $errorMessage. Retrying in ${sleepMs}ms..."
            Start-Sleep -Milliseconds $sleepMs
        }
    }
}
