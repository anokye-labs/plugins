<#
.SYNOPSIS
    Example script demonstrating OkyeremanAgentRunner module usage.

.DESCRIPTION
    This script demonstrates all major features of the OkyeremanAgentRunner module:
    - Structured logging
    - Retry logic with error handling
    - Issue context loading
    - Safe output processing
    - Correlation tracking
    
    NOTE: This is a demonstration script. It does not execute actual GitHub API calls
    but shows the patterns for using the module.
#>

# Import the module
$modulePath = Join-Path $PSScriptRoot "../OkyeremanAgentRunner.psd1"
Import-Module $modulePath -Force

Write-Host "`n=== OkyeremanAgentRunner Module Demo ===" -ForegroundColor Cyan

# 1. Correlation Tracking
Write-Host "`n--- Correlation Tracking ---" -ForegroundColor Yellow
$correlationId = New-CorrelationId -Prefix "demo"
Set-CorrelationId -CorrelationId $correlationId
Write-Host "Generated Correlation ID: $correlationId"

# 2. Structured Logging
Write-Host "`n--- Structured Logging ---" -ForegroundColor Yellow
Write-AgentLog "Demo script started" -Level Info -Agent "DemoAgent" -CorrelationId $correlationId
Write-AgentLog "Processing workflow..." -Level Info
Write-AgentLog "Detailed debug information" -Level Debug
Write-AgentLog "Warning: This is a demo" -Level Warn

# Return log as object
$logObject = Write-AgentLog "Task completed successfully" -Level Info -AsObject
Write-Host "Log object structure:"
$logObject | Format-List

# 3. Error Handling with Retry
Write-Host "`n--- Error Handling & Retry Logic ---" -ForegroundColor Yellow

# Simulate a flaky API call that succeeds on retry
$script:attemptNumber = 0
try {
    $result = Invoke-WithRetry -ScriptBlock {
        $script:attemptNumber++
        if ($script:attemptNumber -lt 2) {
            Write-AgentLog "API call failed (attempt $script:attemptNumber)" -Level Debug
            throw "Simulated temporary failure"
        }
        return "API call succeeded on attempt $script:attemptNumber"
    } -MaxRetries 3 -InitialDelaySeconds 1
    
    Write-Host "Result: $result" -ForegroundColor Green
}
catch {
    $error = New-AgentError -Message "Operation failed" -ErrorCode "DemoError" -Details $_.Exception.Message
    $error | Format-List
}

# 4. Safe Output Processing
Write-Host "`n--- Safe Output Processing ---" -ForegroundColor Yellow

# Sanitize sensitive data
$unsafeText = @"
Here's my GitHub token: ghp_1234567890abcdefghijklmnopqrstuv123456
Contact me at: user@example.com
Phone: 555-123-4567
"@

Write-Host "Original text (UNSAFE):"
Write-Host $unsafeText -ForegroundColor DarkGray

$safeText = ConvertTo-SafeOutput $unsafeText
Write-Host "`nSanitized text (SAFE):"
Write-Host $safeText -ForegroundColor Green

# Truncate long output
$longText = "a" * 500
$truncated = Limit-OutputLength $longText -MaxLength 50
Write-Host "`nTruncated output (50 chars max):"
Write-Host $truncated

# Format as GitHub markdown
$code = @"
function Get-Demo {
    param([string]`$Name)
    Write-Host "Hello, `$Name!"
}
"@

Write-Host "`nFormatted as code block:"
$formatted = ConvertTo-GitHubMarkdown $code -Format CodeBlock -Language powershell
Write-Host $formatted

Write-Host "`nFormatted as quote:"
$quote = ConvertTo-GitHubMarkdown "This is an important note" -Format Quote
Write-Host $quote

# 5. Simulated Issue Context (would require actual GitHub API)
Write-Host "`n--- Issue Context (Demo - requires GitHub API) ---" -ForegroundColor Yellow
Write-Host "In a real scenario, you would use:" -ForegroundColor Gray
Write-Host '  $context = Get-IssueContext -Owner anokye-labs -Repo plugins -IssueNumber 42' -ForegroundColor DarkGray
Write-Host '  # Access: $context.title, $context.parentIssue, $context.subIssues, etc.' -ForegroundColor DarkGray
Write-Host ""
Write-Host "  To clear cache:" -ForegroundColor Gray
Write-Host '  Clear-IssueContextCache' -ForegroundColor DarkGray

# 6. Simulated PR Management (would require actual GitHub API)
Write-Host "`n--- PR Management (Demo - requires GitHub API) ---" -ForegroundColor Yellow
Write-Host "Create a PR:" -ForegroundColor Gray
Write-Host '  $pr = New-AgentPR -Owner anokye-labs -Repo plugins -Title "Fix" -Body "Description" -IssueNumber 42' -ForegroundColor DarkGray
Write-Host ""
Write-Host "Get PR status:" -ForegroundColor Gray
Write-Host '  $status = Get-PRStatus -Owner anokye-labs -Repo plugins -PullNumber 42' -ForegroundColor DarkGray
Write-Host ""
Write-Host "Add review comment:" -ForegroundColor Gray
Write-Host '  Add-PRReviewComment -Owner anokye-labs -Repo plugins -PullNumber 42 -Body "LGTM!" -Event APPROVE' -ForegroundColor DarkGray

# 7. Integration Example
Write-Host "`n--- Integration Example ---" -ForegroundColor Yellow
Write-Host "Typical agent workflow combining all features:" -ForegroundColor Gray

$workflowCid = Get-CorrelationId
Write-AgentLog "Starting agent workflow" -Level Info -CorrelationId $workflowCid

# Simulate agent processing with retry
try {
    $output = Invoke-WithRetry -ScriptBlock {
        # Simulate agent work
        $agentResponse = "Task completed. Token: ghp_fakesecrettoken12345678901234567890"
        
        # Sanitize output
        $safeResponse = ConvertTo-SafeOutput $agentResponse
        
        # Truncate if needed
        $finalOutput = Limit-OutputLength $safeResponse -MaxLength 200
        
        return $finalOutput
    } -MaxRetries 2 -InitialDelaySeconds 1
    
    Write-AgentLog "Workflow completed successfully" -Level Info -CorrelationId $workflowCid
    Write-Host "Agent output: $output" -ForegroundColor Green
}
catch {
    Write-AgentLog "Workflow failed: $_" -Level Error -CorrelationId $workflowCid
}

Write-Host "`n=== Demo Complete ===" -ForegroundColor Cyan
Write-Host "All 15 module functions have been demonstrated." -ForegroundColor Green
Write-Host "Correlation ID for this session: $workflowCid`n"
