#Requires -Version 5.1
# Invoke-AgentLocally.Tests.ps1
# Pester unit tests for scripts/Invoke-AgentLocally.ps1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../../scripts/Invoke-AgentLocally.ps1'

    # Helper: create a minimal .agent.md fixture in a temp directory
    function New-AgentFixture {
        param(
            [string]$Name        = 'test-agent',
            [string]$Description = 'A test agent',
            [string[]]$Tools     = @('github-cli'),
            [string]$ExtraBody   = ''
        )
        $dir  = Join-Path ([System.IO.Path]::GetTempPath()) "agent-test-$([guid]::NewGuid().ToString('N').Substring(0,6))"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null

        $toolLines = ($Tools | ForEach-Object { "  - $_" }) -join "`n"
        $content = @"
---
name: $Name
description: $Description
tools:
$toolLines
---

## Workflow Commands

### /step-one
Does the first thing.

### /step-two
Does the second thing.

$ExtraBody
"@
        $filePath = Join-Path $dir "$Name.agent.md"
        Set-Content -Path $filePath -Value $content -Encoding UTF8
        return $filePath
    }

    # Helper: create a minimal .agent.md with no workflow steps
    function New-EmptyStepsAgentFixture {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) "agent-empty-$([guid]::NewGuid().ToString('N').Substring(0,6))"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $content = @"
---
name: no-steps-agent
description: An agent with no workflow steps
tools:
  - powershell
---

# No-Steps Agent

Just a description, no workflow commands.
"@
        $filePath = Join-Path $dir 'no-steps-agent.agent.md'
        Set-Content -Path $filePath -Value $content -Encoding UTF8
        return $filePath
    }
}

# ---------------------------------------------------------------------------
# Parameter validation
# ---------------------------------------------------------------------------

Describe 'Invoke-AgentLocally — parameters' {

    It 'Has mandatory -AgentPath parameter' {
        $cmd = Get-Command $script:ScriptPath
        $cmd.Parameters['AgentPath'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object { $_.Mandatory } |
            Should -Contain $true
    }

    It 'Has mandatory -Issue parameter' {
        $cmd = Get-Command $script:ScriptPath
        $cmd.Parameters['Issue'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object { $_.Mandatory } |
            Should -Contain $true
    }

    It 'Has optional -StepThrough switch parameter' {
        $cmd = Get-Command $script:ScriptPath
        $cmd.Parameters.Keys | Should -Contain 'StepThrough'
        $cmd.Parameters['StepThrough'].ParameterType | Should -Be ([switch])
    }
}

# ---------------------------------------------------------------------------
# Read-AgentDefinition (invoked via dot-sourcing a sub-script helper is not
# practical here, so we exercise it indirectly through the script with a mock)
# ---------------------------------------------------------------------------

Describe 'Invoke-AgentLocally — agent definition loading' {

    It 'Throws when agent file does not exist' {
        Mock gh { } -Verifiable
        { & $script:ScriptPath -AgentPath 'nonexistent.agent.md' -Issue '1' } |
            Should -Throw '*not found*'
    }

    It 'Parses agent name from frontmatter' {
        $agentFile = New-AgentFixture -Name 'my-agent'
        try {
            Mock gh {
                return '{"number":1,"title":"Test issue","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/1"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '1'
            $result.Agent | Should -Be 'my-agent'
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Detects workflow steps from ## and ### headings' {
        $agentFile = New-AgentFixture -Name 'steps-agent'
        try {
            Mock gh {
                return '{"number":5,"title":"Step issue","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/5"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '5'
            # The fixture has two ### step headings: /step-one and /step-two
            $result.StepCount | Should -Be 2
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns StepCount 0 when agent has no workflow steps' {
        $agentFile = New-EmptyStepsAgentFixture
        try {
            Mock gh {
                return '{"number":2,"title":"No steps issue","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/2"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '2'
            $result.StepCount | Should -Be 0
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Issue number resolution
# ---------------------------------------------------------------------------

Describe 'Invoke-AgentLocally — issue resolution' {

    It 'Accepts a plain issue number' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":42,"title":"Plain number","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/42"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '42'
            $result.Issue | Should -Be 42
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Accepts a #-prefixed issue number' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":7,"title":"Hash prefixed","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/7"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '#7'
            $result.Issue | Should -Be 7
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Accepts a full GitHub issue URL' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":99,"title":"URL issue","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/anokye-labs/plugins/issues/99"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile `
                -Issue 'https://github.com/anokye-labs/plugins/issues/99'
            $result.Issue | Should -Be 99
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Throws on an unrecognised issue format' {
        $agentFile = New-AgentFixture
        try {
            { & $script:ScriptPath -AgentPath $agentFile -Issue 'not-a-number' } |
                Should -Throw '*Cannot parse issue number*'
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Result structure
# ---------------------------------------------------------------------------

Describe 'Invoke-AgentLocally — result structure' {

    It 'Returns a PSCustomObject' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":1,"title":"Struct test","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/1"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '1'
            $result | Should -BeOfType [PSCustomObject]
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Result has expected top-level properties' {
        $agentFile = New-AgentFixture -Name 'prop-agent'
        try {
            Mock gh {
                return '{"number":3,"title":"Props issue","body":"","state":"CLOSED","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/3"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '3'

            $result.PSObject.Properties.Name | Should -Contain 'Agent'
            $result.PSObject.Properties.Name | Should -Contain 'AgentPath'
            $result.PSObject.Properties.Name | Should -Contain 'Issue'
            $result.PSObject.Properties.Name | Should -Contain 'IssueTitle'
            $result.PSObject.Properties.Name | Should -Contain 'IssueState'
            $result.PSObject.Properties.Name | Should -Contain 'StepResults'
            $result.PSObject.Properties.Name | Should -Contain 'StepCount'
            $result.PSObject.Properties.Name | Should -Contain 'PassCount'
            $result.PSObject.Properties.Name | Should -Contain 'FailCount'
            $result.PSObject.Properties.Name | Should -Contain 'Success'
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'IssueTitle and IssueState are populated from gh output' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":10,"title":"My feature","body":"body text","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/10"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '10'
            $result.IssueTitle | Should -Be 'My feature'
            $result.IssueState | Should -Be 'OPEN'
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Success is true when all steps pass' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":1,"title":"All pass","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/1"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '1'
            $result.Success     | Should -Be $true
            $result.FailCount   | Should -Be 0
            $result.PassCount   | Should -Be $result.StepCount
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Each StepResult has Heading, Command, Output, Success, Duration' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":1,"title":"Step props","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/1"}' 
            }
            $result = & $script:ScriptPath -AgentPath $agentFile -Issue '1'
            foreach ($sr in $result.StepResults) {
                $sr.PSObject.Properties.Name | Should -Contain 'Heading'
                $sr.PSObject.Properties.Name | Should -Contain 'Command'
                $sr.PSObject.Properties.Name | Should -Contain 'Output'
                $sr.PSObject.Properties.Name | Should -Contain 'Success'
                $sr.PSObject.Properties.Name | Should -Contain 'Duration'
            }
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# gh CLI interaction
# ---------------------------------------------------------------------------

Describe 'Invoke-AgentLocally — gh CLI integration' {

    It 'Calls gh issue view with the correct issue number' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":88,"title":"CLI test","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/x/y/issues/88"}' 
            }
            & $script:ScriptPath -AgentPath $agentFile -Issue '88' | Out-Null

            Should -Invoke gh -Times 1 -ParameterFilter {
                $args[0] -eq 'issue' -and $args[1] -eq 'view' -and $args[2] -eq 88
            }
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Throws when gh exits non-zero' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                $global:LASTEXITCODE = 1
                return 'error: issue not found'
            }
            { & $script:ScriptPath -AgentPath $agentFile -Issue '999' } |
                Should -Throw '*gh issue view failed*'
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
            $global:LASTEXITCODE = 0
        }
    }

    It 'Passes --repo to gh when URL contains owner/repo' {
        $agentFile = New-AgentFixture
        try {
            Mock gh {
                return '{"number":55,"title":"Repo inference","body":"","state":"OPEN","labels":[],"assignees":[],"url":"https://github.com/anokye-labs/plugins/issues/55"}' 
            }
            & $script:ScriptPath -AgentPath $agentFile `
                -Issue 'https://github.com/anokye-labs/plugins/issues/55' | Out-Null

            Should -Invoke gh -Times 1 -ParameterFilter {
                $args -contains '--repo' -and $args -contains 'anokye-labs/plugins'
            }
        }
        finally {
            Remove-Item (Split-Path $agentFile) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
