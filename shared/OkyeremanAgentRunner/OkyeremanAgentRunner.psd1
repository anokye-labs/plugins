#
# Module manifest for module 'OkyeremanAgentRunner'
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'OkyeremanAgentRunner.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core', 'Desktop')

    # ID used to uniquely identify this module
    GUID = '8c3f5a1e-9b2d-4f6a-a5c7-1e8b9d4f6a5c'

    # Author of this module
    Author = 'anokye-labs'

    # Company or vendor of this module
    CompanyName = 'Anokye Labs'

    # Copyright statement for this module
    Copyright = '(c) 2026 Anokye Labs. MIT License.'

    # Description of the functionality provided by this module
    Description = 'Shared agent runner module for Anokye Labs agent archetypes. Provides common functions for logging, error handling, issue context, PR management, safe output processing, and correlation tracking.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
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

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('GitHub', 'Agents', 'Automation', 'CI/CD', 'GraphQL', 'Anokye')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/anokye-labs/plugins/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/anokye-labs/plugins'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
# OkyeremanAgentRunner v1.0.0

Initial release of the shared agent runner module for Anokye Labs.

## Features
- Structured logging with GitHub Actions annotations
- Retry logic with exponential backoff and rate limit detection
- Issue context loading and caching
- PR creation and management
- Safe output processing (sanitization, truncation, markdown formatting)
- Correlation ID tracking for tracing agent actions

## Function Groups
- Logging: Write-AgentLog
- Error Handling: Invoke-WithRetry, New-AgentError
- Issue Context: Get-IssueContext, Clear-IssueContextCache
- PR Management: New-AgentPR, Get-PRStatus, Add-PRReviewComment
- Safe Output: ConvertTo-SafeOutput, Limit-OutputLength, ConvertTo-GitHubMarkdown
- Correlation: New-CorrelationId, Set-CorrelationId, Get-CorrelationId
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
