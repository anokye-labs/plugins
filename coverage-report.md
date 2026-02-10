# Omanfo Plugin Coverage Report

**Generated:** 2026-02-10 02:10:58 UTC  
**Repository:** anokye-labs/plugins  
**Plugin:** Omanfo v1.0.0

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Features | 8 |
| Covered Features | 8 |
| **Coverage** | **100%** |
| Total Scripts | 10 |
| Total Evaluations | 8 |

## Coverage Status

✅ **PASS** - Coverage meets minimum threshold (80%)

## Feature Coverage Matrix

| Feature | Scripts | Evaluations | Status |
|---------|---------|-------------|--------|
| create-issues | 1 | 1 | ✅ Covered |
| end-to-end | 1 | 1 | ✅ Covered |
| hierarchy | 3 | 1 | ✅ Covered |
| install-verify | 0 | 1 | ✅ Covered |
| issue-types | 1 | 1 | ✅ Covered |
| labels | 0 | 1 | ✅ Covered |
| pr-reviews | 4 | 1 | ✅ Covered |
| projects | 0 | 1 | ✅ Covered |

## Detailed Feature Breakdown

### ✅ create-issues

**Scripts (1):**
- New-IssueWithType.ps1

**Evaluations (1):**
- 03-create-issues.eval.md
### ✅ end-to-end

**Scripts (1):**
- Get-Sitrep.ps1

**Evaluations (1):**
- 08-end-to-end.eval.md
### ✅ hierarchy

**Scripts (3):**
- Get-HierarchyHealth.ps1
- Test-Hierarchy.ps1
- Update-IssueHierarchy.ps1

**Evaluations (1):**
- 04-hierarchy.eval.md
### ✅ install-verify

**Scripts (0):**
- _(none)_

**Evaluations (1):**
- 01-install-verify.eval.md
### ✅ issue-types

**Scripts (1):**
- Get-IssueTypeIds.ps1

**Evaluations (1):**
- 02-issue-types.eval.md
### ✅ labels

**Scripts (0):**
- _(none)_

**Evaluations (1):**
- 07-labels.eval.md
### ✅ pr-reviews

**Scripts (4):**
- Get-PRHealth.ps1
- Get-UnresolvedThreads.ps1
- Reply-ReviewThread.ps1
- Resolve-ReviewThreads.ps1

**Evaluations (1):**
- 06-pr-reviews.eval.md
### ✅ projects

**Scripts (0):**
- _(none)_

**Evaluations (1):**
- 05-projects.eval.md

## Recommendations

✅ All features have evaluation coverage!

## Plugin Manifest Summary

- **Name:** omanfo
- **Version:** 1.0.0
- **Skill:** okyerema
- **Declared Scripts:** 10
- **Declared References:** 8
- **Declared Evaluations:** 8

## Validation Results

This report was generated as part of the CI validation pipeline. For detailed test results, see the workflow run logs.

---

**Next Steps:**
1. Review uncovered features and create evaluation scenarios
2. Ensure all new features include corresponding .eval.md files
3. Run full evaluation suite: .\omanfo\scripts\validation\Invoke-EvalScenarios.ps1

