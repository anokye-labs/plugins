# Test-AgentWorkflow.Unit.Tests.ps1
# Pester tests for scripts/Test-AgentWorkflow.ps1

BeforeAll {
    $script:scriptPath = Resolve-Path "$PSScriptRoot/../../../scripts/Test-AgentWorkflow.ps1"

    # Helper: write a temporary .agent.md fixture and return its path
    function New-AgentFixture {
        param(
            [string]$Name        = 'test-agent',
            [string]$Description = 'A test agent for unit testing purposes.',
            [string[]]$Tools     = @('powershell', 'github-cli'),
            [string]$Body        = '',
            [switch]$OmitName,
            [switch]$OmitDescription,
            [switch]$OmitTools
        )

        $lines = @('---')
        if (-not $OmitName)        { $lines += "name: $Name" }
        if (-not $OmitDescription) { $lines += "description: $Description" }
        if (-not $OmitTools) {
            $toolList = ($Tools | ForEach-Object { "  - $_" }) -join "`n"
            $lines += "tools:`n$toolList"
        }
        $lines += '---'
        if ($Body) { $lines += $Body }

        $tmpFile = [System.IO.Path]::Combine(
            [System.IO.Path]::GetTempPath(),
            [System.IO.Path]::GetRandomFileName() + '.agent.md'
        )
        $lines -join "`n" | Set-Content -Path $tmpFile -NoNewline
        return $tmpFile
    }
}

Describe 'Test-AgentWorkflow — parameter validation' {

    It 'AgentPath parameter is mandatory' {
        $cmd = Get-Command $script:scriptPath
        $cmd.Parameters['AgentPath'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            Select-Object -ExpandProperty Mandatory |
            Should -Be $true
    }

    It 'TestIssue parameter is optional' {
        $cmd = Get-Command $script:scriptPath
        $mandatory = $cmd.Parameters['TestIssue'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            Select-Object -ExpandProperty Mandatory
        $mandatory | Should -Be $false
    }

    It 'DryRun parameter is a switch' {
        $cmd = Get-Command $script:scriptPath
        $cmd.Parameters['DryRun'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
    }
}

Describe 'Test-AgentWorkflow — file not found' {

    It 'Returns Valid=$false when AgentPath does not exist' {
        $result = & $script:scriptPath -AgentPath 'C:\nonexistent\missing.agent.md'
        $result.Valid | Should -Be $false
    }

    It 'Includes an error about the missing file' {
        $result = & $script:scriptPath -AgentPath 'C:\nonexistent\missing.agent.md'
        $result.Errors.Count | Should -BeGreaterThan 0
        $result.Errors[0] | Should -Match 'not found'
    }

    It 'Returns an object with all expected properties even on file-not-found' {
        $result = & $script:scriptPath -AgentPath 'C:\nonexistent\missing.agent.md'
        $result.PSObject.Properties.Name | Should -Contain 'Valid'
        $result.PSObject.Properties.Name | Should -Contain 'Errors'
        $result.PSObject.Properties.Name | Should -Contain 'Warnings'
        $result.PSObject.Properties.Name | Should -Contain 'Tools'
        $result.PSObject.Properties.Name | Should -Contain 'Scripts'
        $result.PSObject.Properties.Name | Should -Contain 'WouldInvoke'
        $result.PSObject.Properties.Name | Should -Contain 'DryRun'
    }
}

Describe 'Test-AgentWorkflow — valid agent definition' {

    It 'Returns Valid=$true for a well-formed agent file' {
        $tmp = New-AgentFixture
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.Valid | Should -Be $true
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Parses the agent name from frontmatter' {
        $tmp = New-AgentFixture -Name 'my-agent'
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.AgentName | Should -Be 'my-agent'
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Returns the declared tools list' {
        $tmp = New-AgentFixture -Tools @('powershell', 'github-cli')
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.Tools | Should -Contain 'powershell'
            $result.Tools | Should -Contain 'github-cli'
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Returns zero errors for a valid agent' {
        $tmp = New-AgentFixture
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.Errors.Count | Should -Be 0
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-AgentWorkflow — required field validation' {

    It 'Reports error when name field is missing' {
        $tmp = New-AgentFixture -OmitName
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.Valid | Should -Be $false
            $result.Errors | Should -Contain "Missing required frontmatter field: 'name'."
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports error when description field is missing' {
        $tmp = New-AgentFixture -OmitDescription
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.Valid | Should -Be $false
            $result.Errors | Should -Contain "Missing required frontmatter field: 'description'."
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports error when tools field is missing' {
        $tmp = New-AgentFixture -OmitTools
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.Valid | Should -Be $false
            $result.Errors | Should -Contain "Missing required frontmatter field: 'tools'."
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-AgentWorkflow — script reference detection' {

    It 'Detects .ps1 script references in the body' {
        $body = "## Scripts`nUse scripts/Set-BranchProtection.ps1 to configure branches."
        $tmp  = New-AgentFixture -Body $body
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.Scripts | Should -Contain 'scripts/Set-BranchProtection.ps1'
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Returns empty Scripts when no script references exist in body' {
        $tmp = New-AgentFixture -Body 'No scripts here.'
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.Scripts.Count | Should -Be 0
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-AgentWorkflow — DryRun mode' {

    It 'Sets DryRun=$true on result when -DryRun switch is used' {
        $tmp = New-AgentFixture
        try {
            $result = & $script:scriptPath -AgentPath $tmp -DryRun
            $result.DryRun | Should -Be $true
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Returns empty WouldInvoke in DryRun mode' {
        $tmp = New-AgentFixture
        try {
            $result = & $script:scriptPath -AgentPath $tmp -DryRun
            $result.WouldInvoke.Count | Should -Be 0
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Sets DryRun=$false when -DryRun switch is not used' {
        $tmp = New-AgentFixture
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.DryRun | Should -Be $false
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-AgentWorkflow — simulation mode' {

    It 'WouldInvoke contains declared tools prefixed with "tool:"' {
        $tmp = New-AgentFixture -Tools @('powershell', 'github-cli')
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.WouldInvoke | Should -Contain 'tool:powershell'
            $result.WouldInvoke | Should -Contain 'tool:github-cli'
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'WouldInvoke contains script references prefixed with "script:"' {
        $body = "Use scripts/Set-BranchProtection.ps1 in your workflow."
        $tmp  = New-AgentFixture -Body $body
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result.WouldInvoke | Should -Contain 'script:scripts/Set-BranchProtection.ps1'
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Includes fetch-issue entry when -TestIssue is provided' {
        $tmp = New-AgentFixture
        try {
            $result = & $script:scriptPath -AgentPath $tmp -TestIssue '99'
            $result.WouldInvoke | Should -Contain 'fetch-issue:99'
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'fetch-issue entry appears first in WouldInvoke' {
        $tmp = New-AgentFixture -Tools @('powershell')
        try {
            $result = & $script:scriptPath -AgentPath $tmp -TestIssue '7'
            $result.WouldInvoke[0] | Should -Be 'fetch-issue:7'
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-AgentWorkflow — return type' {

    It 'Returns a PSCustomObject' {
        $tmp = New-AgentFixture
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $result | Should -BeOfType [PSCustomObject]
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'Result has all eight documented properties' {
        $tmp = New-AgentFixture
        try {
            $result = & $script:scriptPath -AgentPath $tmp
            $props  = $result.PSObject.Properties.Name
            foreach ($prop in @('Valid','AgentName','Errors','Warnings','Tools','Scripts','WouldInvoke','DryRun')) {
                $props | Should -Contain $prop
            }
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}
