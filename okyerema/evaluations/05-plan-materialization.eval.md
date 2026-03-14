---
name: plan-materialization
description: Evaluate markdown plan to issue DAG conversion
---

# Plan Materialization Evaluation

## Scenario
Test converting a markdown plan into a GitHub issue hierarchy.

## Setup
- A markdown plan file with Epic/Feature/Task structure

## Steps

1. Create a test plan file with clear hierarchy
2. Run `Invoke-PlanMaterialization.ps1` with the plan file
3. Verify issues were created with correct types
4. Verify hierarchy relationships were established
5. Run `Sync-PlanToIssues.ps1` with an updated plan
6. Verify changes were synchronized

## Success Criteria
- Plan parsed correctly into issue structure
- All issues created with correct types
- Hierarchy matches plan structure
- Sync detects and applies changes
