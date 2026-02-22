@{
    RootModule        = 'CLITestHarness.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a3f7c2d1-8b4e-4f6a-9c0d-e5f1a2b3c4d5'
    Author            = 'Anokye Labs'
    CompanyName       = 'Anokye Labs'
    Copyright         = '(c) Anokye Labs. All rights reserved.'
    Description       = 'Shared test harness for running E2E tests against both GitHub Copilot CLI and Claude Code CLI.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-SupportedProviders'
        'Test-ProviderAvailable'
        'Get-AvailableProviders'
        'Invoke-CLIPrompt'
        'Start-CLISession'
        'Send-CLISessionPrompt'
        'Stop-CLISession'
        'Get-CLIOutput'
        'Wait-CLIPattern'
        'Get-IssueNumbersFromOutput'
        'Assert-IssueState'
        'Close-TestIssues'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData        = @{
        PSData = @{
            Tags       = @('testing', 'copilot', 'claude', 'e2e', 'cli')
            ProjectUri = 'https://github.com/anokye-labs/plugins'
        }
    }
}
