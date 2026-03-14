# MultiScriptWorkflow.Tests.ps1
# Integration tests verifying multi-script workflows compose correctly

BeforeAll {
    $rhythmPath = Join-Path $PSScriptRoot "../../../okyerema/scripts/rhythm"
    $dispatchPath = Join-Path $PSScriptRoot "../../../okyerema/scripts/dispatch"
    $verifyPath = Join-Path $PSScriptRoot "../../../okyerema/scripts/verify"
    $healthPath = Join-Path $PSScriptRoot "../../../okyerema/scripts/health"
}

Describe "Script Cross-References" {
    It "All rhythm scripts should exist and be callable" {
        $scripts = @(
            "Get-ReadyIssues.ps1",
            "Get-BlockedIssues.ps1",
            "Get-DagStatus.ps1",
            "Get-DagCompletionReport.ps1",
            "Get-StalledWork.ps1",
            "Invoke-DagHealthCheck.ps1",
            "Invoke-PRCompletion.ps1"
        )

        foreach ($script in $scripts) {
            $path = Join-Path $rhythmPath $script
            Test-Path $path | Should -BeTrue -Because "$script should exist in rhythm/"
            $cmd = Get-Command $path
            $cmd | Should -Not -BeNullOrEmpty
        }
    }

    It "All dispatch scripts should exist and be callable" {
        $scripts = @(
            "Get-IssueTypeIds.ps1",
            "New-IssueWithType.ps1",
            "New-IssueBatch.ps1",
            "New-IssueHierarchy.ps1",
            "Update-IssueHierarchy.ps1",
            "Set-IssueDependency.ps1",
            "Test-Hierarchy.ps1",
            "Add-IssuesToProject.ps1",
            "Invoke-PlanMaterialization.ps1",
            "Sync-PlanToIssues.ps1"
        )

        foreach ($script in $scripts) {
            $path = Join-Path $dispatchPath $script
            Test-Path $path | Should -BeTrue -Because "$script should exist in dispatch/"
            $cmd = Get-Command $path
            $cmd | Should -Not -BeNullOrEmpty
        }
    }

    It "All verify scripts should exist and be callable" {
        $scripts = @(
            "Get-PRStatus.ps1",
            "Get-PRHealth.ps1",
            "Get-PRTimeline.ps1",
            "Get-ThreadSeverity.ps1",
            "Get-UnresolvedThreads.ps1",
            "Reply-ReviewThread.ps1",
            "Resolve-ReviewThreads.ps1",
            "Submit-PRReview.ps1",
            "Find-IssueByPR.ps1"
        )

        foreach ($script in $scripts) {
            $path = Join-Path $verifyPath $script
            Test-Path $path | Should -BeTrue -Because "$script should exist in verify/"
            $cmd = Get-Command $path
            $cmd | Should -Not -BeNullOrEmpty
        }
    }

    It "All health scripts should exist and be callable" {
        $scripts = @(
            "Get-HierarchyHealth.ps1",
            "Get-OrphanedIssues.ps1",
            "Get-Sitrep.ps1",
            "Get-RepoReadiness.ps1",
            "Initialize-RepoAutomation.ps1"
        )

        foreach ($script in $scripts) {
            $path = Join-Path $healthPath $script
            Test-Path $path | Should -BeTrue -Because "$script should exist in health/"
            $cmd = Get-Command $path
            $cmd | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Script Parameter Consistency" {
    It "All API scripts should have Owner and Repo parameters" {
        $apiScripts = @(
            (Join-Path $rhythmPath "Get-ReadyIssues.ps1"),
            (Join-Path $rhythmPath "Get-BlockedIssues.ps1"),
            (Join-Path $rhythmPath "Get-DagStatus.ps1"),
            (Join-Path $dispatchPath "Get-IssueTypeIds.ps1"),
            (Join-Path $dispatchPath "New-IssueWithType.ps1"),
            (Join-Path $verifyPath "Get-PRStatus.ps1"),
            (Join-Path $healthPath "Get-Sitrep.ps1"),
            (Join-Path $healthPath "Get-HierarchyHealth.ps1")
        )

        foreach ($scriptPath in $apiScripts) {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain "Owner" -Because "$($cmd.Name) should have Owner param"
            $scriptName = Split-Path $scriptPath -Leaf
            # Get-IssueTypeIds only needs Owner (org-level query)
            if ($scriptName -ne "Get-IssueTypeIds.ps1") {
                $cmd.Parameters.Keys | Should -Contain "Repo" -Because "$($cmd.Name) should have Repo param"
            }
        }
    }
}
