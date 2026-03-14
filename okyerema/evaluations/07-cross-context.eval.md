---
name: cross-context
description: Evaluate same script working across Claude Code, Copilot, and Actions
---

# Cross-Context Evaluation

## Scenario
Verify the same PowerShell scripts produce identical results when invoked from
different contexts (Claude Code, Copilot, GitHub Actions, local act).

## Steps

1. **PowerShell Direct** — Run `Get-Sitrep.ps1` from a PowerShell terminal
2. **Claude Code** — Invoke via `pwsh -File scripts/health/Get-Sitrep.ps1`
3. **GitHub Actions** — Trigger the sankofa-patrol workflow
4. **Local act** — Run `act -j patrol` with the sankofa-patrol workflow

## Success Criteria
- All four contexts produce structurally identical output
- Script parameters work the same across contexts
- Error handling behaves consistently
- Exit codes match across contexts
