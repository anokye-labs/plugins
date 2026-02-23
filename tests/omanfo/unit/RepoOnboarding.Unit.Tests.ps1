# RepoOnboarding.Unit.Tests.ps1
# Pester tests for repo onboarding audit and automation scaffolding scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../../omanfo/skills/okyerema/scripts"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Get-RepoReadiness" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-RepoReadiness.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "repo-readiness.json") -Raw
    }

    It "Should have required Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required Repo parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters['Repo'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have Brief switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Brief"
    }

    It "Should query repository via GraphQL" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should return PSCustomObject" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result | Should -BeOfType [PSCustomObject]
    }

    It "Should include ReadinessScore property" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.PSObject.Properties.Name | Should -Contain "ReadinessScore"
    }

    It "Should include Gaps property" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.PSObject.Properties.Name | Should -Contain "Gaps"
    }

    It "Should include all check properties" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.PSObject.Properties.Name | Should -Contain "CopilotInstructionsOk"
        $result.PSObject.Properties.Name | Should -Contain "AgenticWorkflowsOk"
        $result.PSObject.Properties.Name | Should -Contain "ProjectLinkedOk"
        $result.PSObject.Properties.Name | Should -Contain "IssueTypesOk"
        $result.PSObject.Properties.Name | Should -Contain "CiWorkflowsOk"
    }

    It "Should return score 100 when all checks pass" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        # Fixture has all checks passing
        $result.ReadinessScore | Should -Be 100
        $result.GapCount | Should -Be 0
    }

    It "Should detect missing copilot-instructions as a gap" {
        $noInstructions = $fixtureData | ConvertFrom-Json
        $noInstructions.data.repository.copilotInstructions = $null
        $noInstructionsJson = $noInstructions | ConvertTo-Json -Depth 20

        Mock gh {
            $global:LASTEXITCODE = 0
            return $noInstructionsJson
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.CopilotInstructionsOk | Should -Be $false
        $result.Gaps | Should -Contain "CopilotInstructions"
    }

    It "Should detect missing agentic workflows as a gap" {
        $noAW = $fixtureData | ConvertFrom-Json
        $noAW.data.repository.agenticWorkflowsDir = $null
        $noAWJson = $noAW | ConvertTo-Json -Depth 20

        Mock gh {
            $global:LASTEXITCODE = 0
            return $noAWJson
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.AgenticWorkflowsOk | Should -Be $false
        $result.Gaps | Should -Contain "AgenticWorkflows"
    }

    It "Should detect missing GitHub Project as a gap" {
        $noProject = $fixtureData | ConvertFrom-Json
        $noProject.data.repository.projectsV2 = [PSCustomObject]@{ totalCount = 0; nodes = @() }
        $noProjectJson = $noProject | ConvertTo-Json -Depth 20

        Mock gh {
            $global:LASTEXITCODE = 0
            return $noProjectJson
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.ProjectLinkedOk | Should -Be $false
        $result.Gaps | Should -Contain "ProjectLinked"
    }

    It "Should detect missing CI workflows as a gap" {
        $noCI = $fixtureData | ConvertFrom-Json
        $noCI.data.repository.workflowsDir = $null
        $noCIJson = $noCI | ConvertTo-Json -Depth 20

        Mock gh {
            $global:LASTEXITCODE = 0
            return $noCIJson
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.CiWorkflowsOk | Should -Be $false
        $result.Gaps | Should -Contain "CiWorkflows"
    }

    It "Should not count agentic workflows without lock.yml files" {
        $emptyAW = $fixtureData | ConvertFrom-Json
        $emptyAW.data.repository.agenticWorkflowsDir = [PSCustomObject]@{
            entries = @([PSCustomObject]@{ name = "issue-triage.md"; type = "blob" })
        }
        $emptyAWJson = $emptyAW | ConvertTo-Json -Depth 20

        Mock gh {
            $global:LASTEXITCODE = 0
            return $emptyAWJson
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.AgenticWorkflowsOk | Should -Be $false
        $result.AgenticWorkflowCount | Should -Be 0
    }

    It "Should score 0 when all checks fail" {
        $empty = $fixtureData | ConvertFrom-Json
        $empty.data.repository.copilotInstructions = $null
        $empty.data.repository.agenticWorkflowsDir = $null
        $empty.data.repository.workflowsDir = $null
        $empty.data.repository.projectsV2 = [PSCustomObject]@{ totalCount = 0; nodes = @() }
        $empty.data.repository.openIssues = [PSCustomObject]@{
            totalCount = 3
            nodes = @(
                [PSCustomObject]@{ issueType = $null; labels = [PSCustomObject]@{ nodes = @([PSCustomObject]@{ name = "epic" }) } }
                [PSCustomObject]@{ issueType = $null; labels = [PSCustomObject]@{ nodes = @([PSCustomObject]@{ name = "task" }) } }
                [PSCustomObject]@{ issueType = $null; labels = [PSCustomObject]@{ nodes = @() } }
            )
        }
        $emptyJson = $empty | ConvertTo-Json -Depth 20

        Mock gh {
            $global:LASTEXITCODE = 0
            return $emptyJson
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.ReadinessScore | Should -Be 0
        $result.GapCount | Should -Be 5
    }
}

Describe "Initialize-RepoAutomation" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Initialize-RepoAutomation.ps1"

        $metaResponse = @'
{
  "data": {
    "repository": {
      "id": "R_kgDOABCDEF",
      "owner": {
        "__typename": "Organization",
        "issueTypes": {
          "nodes": [
            { "id": "IT_epic001", "name": "Epic" },
            { "id": "IT_task001", "name": "Task" }
          ]
        }
      }
    },
    "viewer": { "login": "test-user" }
  }
}
'@

        $createIssueResponse = @'
{
  "data": {
    "createIssue": {
      "issue": { "id": "I_001", "number": 42, "url": "https://github.com/test-org/test-repo/issues/42", "title": "Test Issue" }
    }
  }
}
'@
        $subIssueResponse = @'
{ "data": { "addSubIssue": { "issue": { "id": "I_001" }, "subIssue": { "id": "I_002" } } } }
'@
    }

    It "Should have required Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required Repo parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters['Repo'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have WhatIf switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "WhatIf"
    }

    It "Should have ReadinessReport parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "ReadinessReport"
    }

    It "Should do nothing when there are no gaps" {
        $emptyReport = [PSCustomObject]@{
            Owner          = "test-org"
            Repo           = "test-repo"
            ReadinessScore = 100
            Gaps           = @()
            GapCount       = 0
        }

        { & $scriptPath -Owner "test-org" -Repo "test-repo" -ReadinessReport $emptyReport *>&1 } | Should -Not -Throw
    }

    It "Should preview issues in WhatIf mode without calling gh" {
        $report = [PSCustomObject]@{
            Owner                   = "test-org"
            Repo                    = "test-repo"
            ReadinessScore          = 75
            Gaps                    = @("CopilotInstructions")
            GapCount                = 1
            CopilotInstructionsOk   = $false
            CopilotInstructionsNote = "missing"
            AgenticWorkflowsOk      = $true
            AgenticWorkflowsNote    = "present"
            AgenticWorkflowCount    = 1
            ProjectLinkedOk         = $true
            ProjectLinkedNote       = "1 project"
            ActiveProjects          = @()
            IssueTypesOk            = $true
            IssueTypesNote          = "in use"
            CiWorkflowsOk           = $true
            CiWorkflowsNote         = "present"
            CiWorkflowCount         = 2
        }

        Mock gh {
            $global:LASTEXITCODE = 0
            return $metaResponse
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

        $output = & $scriptPath -Owner "test-org" -Repo "test-repo" `
            -ReadinessReport $report -WhatIf *>&1

        $output | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match '\[WhatIf\]' }).Count | Should -BeGreaterThan 0
    }
}
