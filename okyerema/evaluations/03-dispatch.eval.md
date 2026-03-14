---
name: dispatch
description: Evaluate issue dispatch and hierarchy building
---

# Dispatch Evaluation

## Scenario
Test issue creation, hierarchy building, and plan materialization.

## Steps

1. Run `Get-IssueTypeIds.ps1` — verify type IDs are retrieved
2. Run `New-IssueWithType.ps1` to create an Epic
3. Run `New-IssueWithType.ps1` to create Features under the Epic
4. Run `New-IssueWithType.ps1` to create Tasks under Features
5. Run `Update-IssueHierarchy.ps1` to establish relationships
6. Run `Test-Hierarchy.ps1` to verify all relationships
7. Run `Add-IssuesToProject.ps1` to add to project board

## Success Criteria
- Issue type IDs match expected types (Epic, Feature, Task, Bug)
- Issues created with correct types via GraphQL
- Parent-child relationships established via sub-issues API
- Hierarchy verification confirms all relationships
- Project board items created successfully
