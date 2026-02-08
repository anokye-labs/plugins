# Evaluation 7: Label Operations

**Priority:** 🟢 Nice-to-have  
**Time:** 5 minutes  
**Prerequisites:** Installed plugin, repository with some labels

## Objective

Verify the skill's label guidance works — labels are used sparingly and correctly.

## Test Steps

### 7.1 Label Best Practices in Skill

**Action:** Verify the SKILL.md contains label guidance.

```powershell
$skill = Get-Content ".github\skills\okyerema\SKILL.md" -Raw
$skill -match "label"
```

**Expected:**
- [ ] SKILL.md mentions labels
- [ ] Guidance says "use sparingly"
- [ ] Directs to references/labels.md for details

### 7.2 Reference Has Operations

**Action:** Check labels reference content.

```powershell
$labels = Get-Content ".github\skills\okyerema\references\labels.md" -Raw
$labels -match "addLabelsToLabelable"
```

**Expected:**
- [ ] Contains GraphQL mutations for adding/removing labels
- [ ] Has `createLabel` mutation
- [ ] Includes best practices section

### 7.3 Copilot Follows Label Rules

**Action:** In Copilot chat, ask:

> "Add labels 'phase-1', 'phase-2', 'priority-high', 'priority-low', 'status-blocked', 'type-feature' to issue #2 in anokye-labs/plugins."

**Expected:**
- [ ] Copilot pushes back or warns about over-labeling
- [ ] References the "use sparingly" principle
- [ ] May suggest using issue types instead of type-labels

### 7.4 Copilot Creates Label When Needed

**Action:** In Copilot chat:

> "Create a label called 'evaluation' in anokye-labs/plugins with color #ededed."

**Expected:**
- [ ] Uses GraphQL `createLabel` mutation
- [ ] Label is created in the repository

## Pass/Fail

- **PASS:** Steps 7.1 and 7.2 succeed
- **FAIL:** Label reference is missing or incorrect
