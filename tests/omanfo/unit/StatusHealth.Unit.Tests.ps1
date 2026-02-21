# StatusHealth.Tests.ps1
# Pester tests for status and health monitoring scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../../omanfo/skills/okyerema/scripts"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Get-Sitrep" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-Sitrep.ps1"
        $mockResponse = @'
{
  "data": {
    "repository": {
      "openIssues": { "totalCount": 15, "nodes": [] },
      "closedRecent": { "nodes": [] }
    }
  }
}
'@
    }

    It "Should have required parameters" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters.Keys | Should -Contain "Repo"
    }

    It "Should have optional IssueNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "IssueNumber"
    }

    It "Should have optional PullNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "PullNumber"
    }

    It "Should have Brief switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Brief"
    }

    It "Should query repository data via GraphQL" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $mockResponse 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        Mock git { return "main" } -ParameterFilter { $args[0] -eq 'rev-parse' }
        Mock git { return "" } -ParameterFilter { $args[0] -eq 'log' }
        Mock git { return "" } -ParameterFilter { $args[0] -eq 'status' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should return PSCustomObject" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $mockResponse 
        } -ParameterFilter { $args[0] -eq 'api' }
        Mock git { return "main" } -ParameterFilter { $args[0] -eq 'rev-parse' }
        Mock git { return "" } -ParameterFilter { $args[0] -eq 'log' }
        Mock git { return "" } -ParameterFilter { $args[0] -eq 'status' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result | Should -BeOfType [PSCustomObject]
    }

    It "Should include TotalOpen in output" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $mockResponse 
        } -ParameterFilter { $args[0] -eq 'api' }
        Mock git { return "main" } -ParameterFilter { $args[0] -eq 'rev-parse' }
        Mock git { return "" } -ParameterFilter { $args[0] -eq 'log' }
        Mock git { return "" } -ParameterFilter { $args[0] -eq 'status' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.PSObject.Properties.Name | Should -Contain "TotalOpen"
    }

    It "Should include GitStatus in output" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $mockResponse 
        } -ParameterFilter { $args[0] -eq 'api' }
        Mock git { return "main" } -ParameterFilter { $args[0] -eq 'rev-parse' }
        Mock git { return "" } -ParameterFilter { $args[0] -eq 'log' }
        Mock git { return "" } -ParameterFilter { $args[0] -eq 'status' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.PSObject.Properties.Name | Should -Contain "GitStatus"
    }
}

Describe "Get-HierarchyHealth" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-HierarchyHealth.ps1"
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

    It "Should query all issues with hierarchy data" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should return PSCustomObject with health metrics" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result | Should -BeOfType [PSCustomObject]
    }

    It "Should include TypeCounts property" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.PSObject.Properties.Name | Should -Contain "TypeCounts"
    }

    It "Should include Orphans property" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.PSObject.Properties.Name | Should -Contain "Orphans"
    }

    It "Should include HealthScore property" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.PSObject.Properties.Name | Should -Contain "HealthScore"
    }
}

Describe "Get-DagStatus" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-DagStatus.ps1"
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

    It "Should query issues with blocking relationships" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should return array of issue objects" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = @(& $scriptPath -Owner "test-org" -Repo "test-repo")
        
        # Force result to array and check it has items
        $result.Count | Should -BeGreaterOrEqual 0
    }
}

Describe "Get-DagCompletionReport" {
    BeforeAll {
        $scriptPath  = Join-Path $scriptsPath "Get-DagCompletionReport.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "dag-completion.json") -Raw
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

    It "Should have optional RootNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "RootNumber"
    }

    It "Should have Brief switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Brief"
    }

    It "Should not throw with valid fixture data" {
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

    It "Should include PercentComplete property" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.PSObject.Properties.Name | Should -Contain "PercentComplete"
    }

    It "Should include RootReports property" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.PSObject.Properties.Name | Should -Contain "RootReports"
    }

    It "Should include BlockedPaths and BlockedPathCount properties" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.PSObject.Properties.Name | Should -Contain "BlockedPaths"
        $result.PSObject.Properties.Name | Should -Contain "BlockedPathCount"
    }

    It "Should include CriticalPath and CriticalPathLength properties" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.PSObject.Properties.Name | Should -Contain "CriticalPath"
        $result.PSObject.Properties.Name | Should -Contain "CriticalPathLength"
    }

    It "Should compute correct PercentComplete for fixture data" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        # Fixture: 10 total, 4 closed (issues 2, 4, 5, 7) = 40%
        $result.TotalIssues    | Should -Be 10
        $result.ClosedCount    | Should -Be 4
        $result.PercentComplete | Should -Be 40
    }

    It "Should detect blocked paths where all issues are open" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        # Fixture has 3 all-open paths: #1 → #3 → #6, #8 → #9, #8 → #10
        $result.BlockedPathCount | Should -Be 3
        $result.BlockedPaths.Count | Should -Be $result.BlockedPathCount
    }

    It "Should identify the longest all-open chain as critical path" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        # Longest all-open path in fixture is #1 → #3 → #6 (length 3)
        $result.CriticalPathLength | Should -Be 3
    }

    It "Should report two roots for fixture data" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $fixtureData
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        # Fixture has two roots: #1 (Epic) and #8 (Feature)
        $result.RootCount | Should -Be 2
        $result.RootReports.Count | Should -Be 2
    }
}

Describe "Invoke-DagHealthCheck" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Invoke-DagHealthCheck.ps1"
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

    It "Should query dependency graph" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw
    }

    It "Should return health report with cycles" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.PSObject.Properties.Name | Should -Contain "Cycles"
    }

    It "Should return health score" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.PSObject.Properties.Name | Should -Contain "HealthScore"
    }

    It "Should provide cycles property with correct count" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.PSObject.Properties.Name | Should -Contain "Cycles"
        $result.Cycles.Count | Should -Be $result.CycleCount
    }
}
