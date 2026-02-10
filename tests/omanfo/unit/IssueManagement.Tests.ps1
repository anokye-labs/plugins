# IssueManagement.Tests.ps1
# Pester tests for issue management scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../../omanfo/.github/skills/okyerema/scripts"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Get-IssueTypeIds" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-IssueTypeIds.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "issue-types.json") -Raw
    }

    It "Should have required Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $true
    }

    It "Should query organization issue types via GraphQL" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        $result = & $scriptPath -Owner "test-org" *>&1
        
        Should -Invoke gh -Times 1 -ParameterFilter { $args[0] -eq 'api' }
    }

    It "Should return hashtable with type IDs" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        $result = & $scriptPath -Owner "test-org" | Where-Object { $_ -is [hashtable] }
        
        $result | Should -BeOfType [hashtable]
        $result.Keys.Count | Should -BeGreaterThan 0
    }

    It "Should map Epic type name to ID" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        $result = & $scriptPath -Owner "test-org" | Where-Object { $_ -is [hashtable] }
        
        $result['Epic'] | Should -Be 'IT_kwDOCfc9t84Ab123'
    }

    It "Should map all four standard types" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        $result = & $scriptPath -Owner "test-org" | Where-Object { $_ -is [hashtable] }
        
        $result['Epic'] | Should -Not -BeNullOrEmpty
        $result['Feature'] | Should -Not -BeNullOrEmpty
        $result['Task'] | Should -Not -BeNullOrEmpty
        $result['Bug'] | Should -Not -BeNullOrEmpty
    }
}

Describe "New-IssueWithType" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "New-IssueWithType.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "issue-types.json") -Raw
        $createResponse = @'
{
  "data": {
    "createIssue": {
      "issue": {
        "id": "I_kwDOCfc9t85abc123",
        "number": 42,
        "title": "Test Issue",
        "issueType": { "name": "Task" },
        "url": "https://github.com/test/repo/issues/42"
      }
    }
  }
}
'@
    }

    It "Should have required parameters" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters.Keys | Should -Contain "Title"
        $cmd.Parameters.Keys | Should -Contain "TypeName"
    }

    It "Should query repository and issue types" {
        Mock gh { 
            if ($args -contains 'graphql') {
                if ($args -match 'createIssue') {
                    return $createResponse
                } else {
                    return $fixtureData
                }
            }
        } -ParameterFilter { $args[0] -eq 'api' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -Title "Test" -TypeName "Task" *>&1
        
        Should -Invoke gh -Times 2
    }

    It "Should create issue with correct type" {
        Mock gh { 
            if ($args -match 'createIssue') {
                return $createResponse
            } else {
                return $fixtureData
            }
        } -ParameterFilter { $args[0] -eq 'api' }
        
        $output = (& $scriptPath -Owner "test-org" -Repo "test-repo" -Title "Test" -TypeName "Task" *>&1) | Out-String
        
        $output | Should -Match "Created #42"
        $output | Should -Match "Task"
    }

    It "Should handle Body parameter" {
        Mock gh { 
            if ($args -match 'createIssue') {
                return $createResponse
            } else {
                return $fixtureData
            }
        } -ParameterFilter { $args[0] -eq 'api' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" -Title "Test" -TypeName "Task" -Body "Description" *>&1 } | Should -Not -Throw
    }

    It "Should handle Labels parameter" {
        Mock gh { 
            if ($args -match 'createIssue') {
                return $createResponse
            } elseif ($args -match 'addLabelsToLabelable') {
                return '{"data":{"addLabelsToLabelable":{"labelable":{"number":42}}}}'
            } else {
                return $fixtureData
            }
        } -ParameterFilter { $args[0] -eq 'api' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" -Title "Test" -TypeName "Task" -Labels @("bug", "urgent") *>&1 } | Should -Not -Throw
    }
}

Describe "Update-IssueHierarchy" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Update-IssueHierarchy.ps1"
        $mutationResponse = '{"data":{"updateIssueSubIssues":{"issue":{"number":1}}}}'
    }

    It "Should have required parameters" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters.Keys | Should -Contain "ParentNumber"
        $cmd.Parameters.Keys | Should -Contain "ChildNumbers"
    }

    It "Should accept array of child numbers" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters['ChildNumbers'].ParameterType | Should -Be ([int[]])
    }

    It "Should call GraphQL mutation" {
        Mock gh { 
            $script:LASTEXITCODE = 0
            return $mutationResponse 
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -ParentNumber 1 -ChildNumbers @(2, 3) *>&1
        
        Should -Invoke gh -ParameterFilter { $args[0] -eq 'api' }
    }

    It "Should handle single child" {
        Mock gh { 
            $script:LASTEXITCODE = 0
            return $mutationResponse 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" -ParentNumber 1 -ChildNumbers @(2) *>&1 } | Should -Not -Throw
    }

    It "Should handle multiple children" {
        Mock gh { 
            $script:LASTEXITCODE = 0
            return $mutationResponse 
        } -ParameterFilter { $args[0] -eq 'api' }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" -ParentNumber 1 -ChildNumbers @(2, 3, 4) *>&1 } | Should -Not -Throw
    }
}

Describe "Set-IssueDependency" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Set-IssueDependency.ps1"
    }

    It "Should have required parameters" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters.Keys | Should -Contain "IssueNumber"
        $cmd.Parameters.Keys | Should -Contain "Action"
    }

    It "Should accept Add action" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters['Action'].Attributes.ValidValues | Should -Contain 'Add'
    }

    It "Should accept Remove action" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters['Action'].Attributes.ValidValues | Should -Contain 'Remove'
    }

    It "Should accept Query action" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters['Action'].Attributes.ValidValues | Should -Contain 'Query'
    }

    It "Should have BlockedBy parameter for Add action" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "BlockedBy"
    }
}

Describe "Test-Hierarchy" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Test-Hierarchy.ps1"
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

    It "Should accept IssueNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "IssueNumber"
        $cmd.Parameters['IssueNumber'].Attributes.Mandatory | Should -Be $true
    }

    It "Should accept optional Depth parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Depth"
    }
}
