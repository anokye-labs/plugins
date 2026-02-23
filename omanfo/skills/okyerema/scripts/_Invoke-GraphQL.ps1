# _Invoke-GraphQL.ps1
# Shared helper: execute a GraphQL query via gh CLI with retry and error handling

function Invoke-GraphQL {
    param(
        [Parameter(Mandatory)][string]$Query,
        [hashtable]$Headers = @{},
        [int]$MaxAttempts = 3,
        [int]$RetryDelayMs = 1000
    )

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
            if ($attempt -ge $MaxAttempts) {
                throw
            }
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message). Retrying in ${RetryDelayMs}ms..."
            Start-Sleep -Milliseconds $RetryDelayMs
        }
    }
}
