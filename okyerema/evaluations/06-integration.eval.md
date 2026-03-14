---
name: integration
description: Evaluate multi-script workflow integration
---

# Integration Evaluation

## Scenario
Test end-to-end workflow using multiple scripts in sequence.

## Steps

1. **Setup** — Run `Get-RepoReadiness.ps1` to audit the repo
2. **Dispatch** — Run `Invoke-PlanMaterialization.ps1` to create issue DAG from plan
3. **Monitor** — Run `Get-DagStatus.ps1` to see hierarchy status
4. **Check** — Run `Get-ReadyIssues.ps1` to find work ready for agents
5. **Health** — Run `Get-HierarchyHealth.ps1` to validate structure
6. **Report** — Run `Get-Sitrep.ps1` for tactical status

## Success Criteria
- Scripts compose correctly in sequence
- Output from one script can inform the next
- No state corruption between script invocations
- Final sitrep accurately reflects all changes
