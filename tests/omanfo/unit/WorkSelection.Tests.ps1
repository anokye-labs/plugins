# WorkSelection.Tests.ps1
# Pester tests for work selection and prioritization scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../../omanfo/.github/skills/okyerema/scripts"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Get-ReadyIssues" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-ReadyIssues.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "dag-health.json") -Raw
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

    It "Should query all open issues with dependencies" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should return array of ready issues" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result | Should -BeOfType [array]
    }
}

Describe "Get-BlockedIssues" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-BlockedIssues.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "dag-health.json") -Raw
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

    It "Should query all open issues" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should return array of blocked issues" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result | Should -BeOfType [array]
    }
}

Describe "Get-OrphanedIssues" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-OrphanedIssues.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "hierarchy-tree.json") -Raw
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

    It "Should query issues with hierarchy relationships" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should return array of orphaned issues" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result | Should -BeOfType [array]
    }
}

Describe "Get-StalledWork" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-StalledWork.ps1"
        $mockResponse = @'
{
  "data": {
    "repository": {
      "issues": {
        "nodes": [
          {
            "number": 20,
            "title": "Old issue",
            "state": "OPEN",
            "updatedAt": "2025-01-01T00:00:00Z",
            "timelineItems": {
              "nodes": [
                { "__typename": "IssueComment", "createdAt": "2025-01-01T00:00:00Z" }
              ]
            }
          }
        ]
      }
    }
  }
}
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

    It "Should have optional DaysSinceUpdate parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "DaysSinceUpdate"
    }

    It "Should query issues with timeline data" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $mockResponse 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should identify stalled issues" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $mockResponse 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -DaysSinceUpdate 30
        
        $result | Should -BeOfType [array]
    }
}
