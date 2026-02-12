# CLITestHarness.psm1
# Shared test harness for running E2E tests against both GitHub Copilot CLI and Claude Code CLI.
# Provides a provider-agnostic interface for sending prompts and capturing responses.

#region Provider Configuration

$script:ProviderConfig = @{
    copilot = @{
        Command         = 'copilot'
        OneShotArgs     = @('-p', '{prompt}', '--allow-all-tools', '-s')
        InteractiveArgs = @()
        ReadyPattern    = '> '
        InstallUrl      = 'https://github.com/github/copilot-cli'
        AuthCheck       = { copilot --version 2>&1 | Out-Null; $LASTEXITCODE -eq 0 }
    }
    claude = @{
        Command         = 'claude'
        OneShotArgs     = @('-p', '{prompt}', '--output-format', 'text')
        InteractiveArgs = @()
        ReadyPattern    = '> '
        InstallUrl      = 'https://docs.anthropic.com/en/docs/claude-code'
        AuthCheck       = { claude --version 2>&1 | Out-Null; $LASTEXITCODE -eq 0 }
    }
}

#endregion

#region Provider Discovery

<#
.SYNOPSIS
    Returns the list of supported CLI providers.

.DESCRIPTION
    Lists all provider names that the harness can target.

.EXAMPLE
    Get-SupportedProviders
#>
function Get-SupportedProviders {
    [CmdletBinding()]
    param()

    return @($script:ProviderConfig.Keys)
}

<#
.SYNOPSIS
    Tests whether a CLI provider is available on the current machine.

.DESCRIPTION
    Checks if the provider CLI binary is on PATH and optionally validates that it can run.

.PARAMETER Provider
    The provider to check: copilot or claude.

.PARAMETER SkipAuthCheck
    If set, only checks for the binary on PATH without running the CLI version check.

.EXAMPLE
    Test-ProviderAvailable -Provider copilot

.EXAMPLE
    Test-ProviderAvailable -Provider claude -SkipAuthCheck
#>
function Test-ProviderAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('copilot', 'claude')]
        [string]$Provider,

        [Parameter()]
        [switch]$SkipAuthCheck
    )

    $config = $script:ProviderConfig[$Provider]
    $cmd = Get-Command $config.Command -ErrorAction SilentlyContinue

    if (-not $cmd) {
        return [PSCustomObject]@{
            Available   = $false
            Provider    = $Provider
            Command     = $config.Command
            Reason      = "CLI not found on PATH"
            InstallUrl  = $config.InstallUrl
        }
    }

    if (-not $SkipAuthCheck) {
        try {
            $authResult = & $config.AuthCheck
            if (-not $authResult) {
                return [PSCustomObject]@{
                    Available   = $false
                    Provider    = $Provider
                    Command     = $config.Command
                    Reason      = "CLI version check failed"
                    InstallUrl  = $config.InstallUrl
                }
            }
        }
        catch {
            return [PSCustomObject]@{
                Available   = $false
                Provider    = $Provider
                Command     = $config.Command
                Reason      = "Authentication check error: $_"
                InstallUrl  = $config.InstallUrl
            }
        }
    }

    return [PSCustomObject]@{
        Available   = $true
        Provider    = $Provider
        Command     = $cmd.Source
        Reason      = $null
        InstallUrl  = $config.InstallUrl
    }
}

<#
.SYNOPSIS
    Returns a list of providers available on the current machine.

.DESCRIPTION
    Checks all supported providers and returns those that are installed and (optionally) verified to run.

.PARAMETER SkipAuthCheck
    If set, only checks for binaries without running the CLI version check.

.EXAMPLE
    Get-AvailableProviders

.EXAMPLE
    Get-AvailableProviders -SkipAuthCheck
#>
function Get-AvailableProviders {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$SkipAuthCheck
    )

    $results = @()
    foreach ($provider in Get-SupportedProviders) {
        $check = Test-ProviderAvailable -Provider $provider -SkipAuthCheck:$SkipAuthCheck
        if ($check.Available) {
            $results += $provider
        }
    }
    return $results
}

#endregion

#region One-Shot Invocation

<#
.SYNOPSIS
    Sends a single prompt to a CLI provider and returns the response.

.DESCRIPTION
    Executes a one-shot (non-interactive) prompt against the specified provider CLI.
    This is the core function used by E2E tests to exercise plugin functionality.

.PARAMETER Provider
    The CLI provider to use: copilot or claude.

.PARAMETER Prompt
    The prompt text to send.

.PARAMETER TimeoutSeconds
    Maximum time to wait for a response. Default is 120 seconds.

.PARAMETER AdditionalArgs
    Extra CLI arguments to pass to the provider command.

.PARAMETER WorkingDirectory
    Directory to run the CLI from. Defaults to current location.

.EXAMPLE
    $result = Invoke-CLIPrompt -Provider copilot -Prompt "Create a Task issue titled 'Test' in myorg/myrepo"

.EXAMPLE
    $result = Invoke-CLIPrompt -Provider claude -Prompt "/sitrep for anokye-labs/plugins" -TimeoutSeconds 60
#>
function Invoke-CLIPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('copilot', 'claude')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [int]$TimeoutSeconds = 120,

        [Parameter()]
        [string[]]$AdditionalArgs = @(),

        [Parameter()]
        [string]$WorkingDirectory
    )

    $config = $script:ProviderConfig[$Provider]
    $command = $config.Command

    $cliArgs = @()
    foreach ($arg in $config.OneShotArgs) {
        if ($arg -eq '{prompt}') {
            $cliArgs += $Prompt
        }
        else {
            $cliArgs += $arg
        }
    }
    $cliArgs += $AdditionalArgs

    $startTime = Get-Date

    $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = $command
    foreach ($arg in $cliArgs) {
        [void]$processInfo.ArgumentList.Add($arg)
    }
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    if ($WorkingDirectory) {
        $processInfo.WorkingDirectory = $WorkingDirectory
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $processInfo

    $stdoutBuilder = [System.Text.StringBuilder]::new()
    $stderrBuilder = [System.Text.StringBuilder]::new()

    $stdoutEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        if ($null -ne $EventArgs.Data) {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    } -MessageData $stdoutBuilder

    $stderrEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        if ($null -ne $EventArgs.Data) {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    } -MessageData $stderrBuilder

    try {
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        $endTime = Get-Date
        $duration = $endTime - $startTime

        if (-not $completed) {
            try { $process.Kill() } catch { }
            Start-Sleep -Milliseconds 250
            return [PSCustomObject]@{
                Success      = $false
                Provider     = $Provider
                Prompt       = $Prompt
                Output       = $stdoutBuilder.ToString()
                ErrorOutput  = $stderrBuilder.ToString()
                ExitCode     = -1
                TimedOut     = $true
                Duration     = $duration
            }
        }

        Start-Sleep -Milliseconds 250

        $stdout = $stdoutBuilder.ToString()
        $stderr = $stderrBuilder.ToString()
        $exitCode = $process.ExitCode

        return [PSCustomObject]@{
            Success      = ($exitCode -eq 0)
            Provider     = $Provider
            Prompt       = $Prompt
            Output       = $stdout
            ErrorOutput  = $stderr
            ExitCode     = $exitCode
            TimedOut     = $false
            Duration     = $duration
        }
    }
    finally {
        Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
        Remove-Job -Id $stdoutEvent.Id -Force -ErrorAction SilentlyContinue
        Remove-Job -Id $stderrEvent.Id -Force -ErrorAction SilentlyContinue
        $process.Dispose()
    }
}

#endregion

#region Interactive Session

<#
.SYNOPSIS
    Starts an interactive CLI session for multi-turn testing.

.DESCRIPTION
    Launches the CLI in interactive mode and returns a session object that
    can be used to send prompts and read responses across multiple turns.

.PARAMETER Provider
    The CLI provider to use: copilot or claude.

.PARAMETER WorkingDirectory
    Directory to run the CLI from. Defaults to current location.

.EXAMPLE
    $session = Start-CLISession -Provider copilot
    $response = Send-CLIPrompt -Session $session -Prompt "Create a Task"
    Stop-CLISession -Session $session
#>
function Start-CLISession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('copilot', 'claude')]
        [string]$Provider,

        [Parameter()]
        [string]$WorkingDirectory
    )

    $config = $script:ProviderConfig[$Provider]
    $command = $config.Command

    $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = $command
    foreach ($arg in $config.InteractiveArgs) {
        [void]$processInfo.ArgumentList.Add($arg)
    }
    $processInfo.RedirectStandardInput = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    if ($WorkingDirectory) {
        $processInfo.WorkingDirectory = $WorkingDirectory
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $processInfo

    $outputBuffer = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $errorBuffer = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

    $stdoutEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        if ($null -ne $EventArgs.Data) {
            $Event.MessageData.Enqueue($EventArgs.Data)
        }
    } -MessageData $outputBuffer

    $stderrEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        if ($null -ne $EventArgs.Data) {
            $Event.MessageData.Enqueue($EventArgs.Data)
        }
    } -MessageData $errorBuffer

    try {
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
    }
    catch {
        Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
        Remove-Job -Id $stdoutEvent.Id -Force -ErrorAction SilentlyContinue
        Remove-Job -Id $stderrEvent.Id -Force -ErrorAction SilentlyContinue
        $process.Dispose()
        throw
    }

    return [PSCustomObject]@{
        Process       = $process
        Provider      = $Provider
        OutputBuffer  = $outputBuffer
        ErrorBuffer   = $errorBuffer
        StdoutEvent   = $stdoutEvent
        StderrEvent   = $stderrEvent
        StartTime     = Get-Date
        TurnCount     = 0
    }
}

<#
.SYNOPSIS
    Sends a prompt to an active interactive CLI session.

.DESCRIPTION
    Writes a prompt to the CLI process stdin and waits for a response
    by monitoring stdout for the ready pattern.

.PARAMETER Session
    The session object returned by Start-CLISession.

.PARAMETER Prompt
    The prompt text to send.

.PARAMETER TimeoutSeconds
    Maximum time to wait for a response. Default is 120 seconds.

.EXAMPLE
    $response = Send-CLISessionPrompt -Session $session -Prompt "Create a Task issue"
#>
function Send-CLISessionPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Session,

        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter()]
        [int]$TimeoutSeconds = 120
    )

    if ($Session.Process.HasExited) {
        return [PSCustomObject]@{
            Success   = $false
            Output    = ''
            Error     = 'Session process has exited'
            Turn      = $Session.TurnCount
        }
    }

    $drainedLines = @()
    $line = $null
    while ($Session.OutputBuffer.TryDequeue([ref]$line)) {
        $drainedLines += $line
    }

    $Session.Process.StandardInput.WriteLine($Prompt)
    $Session.Process.StandardInput.Flush()
    $Session.TurnCount++

    $startTime = Get-Date
    $responseLines = @()
    $config = $script:ProviderConfig[$Session.Provider]
    $readyPattern = $config.ReadyPattern

    while (((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        $line = $null
        while ($Session.OutputBuffer.TryDequeue([ref]$line)) {
            $responseLines += $line
            if ($line -match [regex]::Escape($readyPattern)) {
                return [PSCustomObject]@{
                    Success   = $true
                    Output    = ($responseLines -join "`n")
                    Error     = $null
                    Turn      = $Session.TurnCount
                }
            }
        }
        Start-Sleep -Milliseconds 100
    }

    return [PSCustomObject]@{
        Success   = $false
        Output    = ($responseLines -join "`n")
        Error     = "Timed out after $TimeoutSeconds seconds"
        Turn      = $Session.TurnCount
    }
}

<#
.SYNOPSIS
    Stops an interactive CLI session and cleans up resources.

.DESCRIPTION
    Sends exit/quit to the CLI, waits for graceful shutdown, then kills if needed.

.PARAMETER Session
    The session object returned by Start-CLISession.

.EXAMPLE
    Stop-CLISession -Session $session
#>
function Stop-CLISession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Session
    )

    try {
        if (-not $Session.Process.HasExited) {
            try {
                $Session.Process.StandardInput.WriteLine('/exit')
                $Session.Process.StandardInput.Flush()
            }
            catch { }

            $exited = $Session.Process.WaitForExit(5000)
            if (-not $exited) {
                try { $Session.Process.Kill() } catch { }
            }
        }
    }
    finally {
        Unregister-Event -SourceIdentifier $Session.StdoutEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $Session.StderrEvent.Name -ErrorAction SilentlyContinue
        Remove-Job -Id $Session.StdoutEvent.Id -Force -ErrorAction SilentlyContinue
        Remove-Job -Id $Session.StderrEvent.Id -Force -ErrorAction SilentlyContinue
        $Session.Process.Dispose()
    }
}

#endregion

#region Response Parsing

<#
.SYNOPSIS
    Extracts GitHub issue numbers from CLI output text.

.DESCRIPTION
    Parses CLI response text for issue number patterns (#123) and returns
    them as an array of integers. Works identically across providers.

.PARAMETER Text
    The CLI output text to parse.

.EXAMPLE
    $issues = Get-IssueNumbersFromOutput -Text $result.Output
#>
function Get-IssueNumbersFromOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $matches = [regex]::Matches($Text, '#(\d+)')
    return @($matches | ForEach-Object { [int]$_.Groups[1].Value })
}

<#
.SYNOPSIS
    Verifies a GitHub issue exists and matches expectations.

.DESCRIPTION
    Queries the GitHub API to verify an issue exists, checking title, state,
    and optionally issue type. This is provider-agnostic verification.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER IssueNumber
    Issue number to verify.

.PARAMETER ExpectedTitle
    Expected issue title (partial match).

.PARAMETER ExpectedState
    Expected issue state. Default is 'OPEN'.

.EXAMPLE
    $check = Assert-IssueState -Owner anokye-labs -Repo plugins -IssueNumber 42 -ExpectedTitle "Test"
#>
function Assert-IssueState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [int]$IssueNumber,

        [Parameter()]
        [string]$ExpectedTitle,

        [Parameter()]
        [string]$ExpectedState = 'OPEN'
    )

    $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    issue(number: $IssueNumber) {
      title
      state
      issueType { name }
      subIssues(first: 10) {
        nodes { number title state }
      }
    }
  }
}
"@

    try {
        $result = gh api graphql -H "GraphQL-Features: sub_issues" -f query=$query 2>&1 | ConvertFrom-Json
        $issue = $result.data.repository.issue

        if (-not $issue) {
            return [PSCustomObject]@{
                Passed     = $false
                Message    = "Issue #$IssueNumber not found"
                Issue      = $null
            }
        }

        $passed = $true
        $messages = @()

        if ($ExpectedTitle -and $issue.title -notlike "*$ExpectedTitle*") {
            $passed = $false
            $messages += "Title mismatch: expected '*$ExpectedTitle*', got '$($issue.title)'"
        }

        if ($ExpectedState -and $issue.state -ne $ExpectedState) {
            $passed = $false
            $messages += "State mismatch: expected '$ExpectedState', got '$($issue.state)'"
        }

        return [PSCustomObject]@{
            Passed     = $passed
            Message    = if ($messages.Count -gt 0) { $messages -join '; ' } else { "OK" }
            Issue      = $issue
        }
    }
    catch {
        return [PSCustomObject]@{
            Passed     = $false
            Message    = "API error: $_"
            Issue      = $null
        }
    }
}

#endregion

#region Test Cleanup

<#
.SYNOPSIS
    Closes test issues created during an E2E test run.

.DESCRIPTION
    Accepts an array of issue numbers and closes them with state_reason=not_planned.
    Used as cleanup in AfterAll blocks of Pester tests.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER IssueNumbers
    Array of issue numbers to close.

.EXAMPLE
    Close-TestIssues -Owner anokye-labs -Repo plugins -IssueNumbers @(100, 101, 102)
#>
function Close-TestIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [int[]]$IssueNumbers
    )

    $closed = 0
    foreach ($num in $IssueNumbers) {
        try {
            gh api "repos/$Owner/$Repo/issues/$num" `
                -X PATCH `
                -f state=closed `
                -f state_reason=not_planned `
                2>&1 | Out-Null
            $closed++
        }
        catch {
            Write-Warning "Failed to close issue #$num : $_"
        }
    }

    Write-Host "Closed $closed of $($IssueNumbers.Count) test issues." -ForegroundColor Green
}

#endregion

#region Module Exports

Export-ModuleMember -Function @(
    'Get-SupportedProviders'
    'Test-ProviderAvailable'
    'Get-AvailableProviders'
    'Invoke-CLIPrompt'
    'Start-CLISession'
    'Send-CLISessionPrompt'
    'Stop-CLISession'
    'Get-IssueNumbersFromOutput'
    'Assert-IssueState'
    'Close-TestIssues'
)

#endregion
