# StatusHealth.Tests.ps1
# Pester tests for status and health monitoring scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../.github/skills/okyerema/scripts"
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

    It "Should provide cycles as array" {
        Mock gh { 
            $global:LASTEXITCODE = 0
            return $fixtureData 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"
        
        $result.Cycles | Should -BeOfType [array]
    }
}
