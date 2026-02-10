# Evaluation 5: GitHub Projects V2

**Priority:** 🟡 Important  
**Time:** 15 minutes  
**Prerequisites:** Installed plugin, org with a Projects V2 board

## Objective

Verify the skill's Projects V2 reference enables Copilot to manage project boards, including bulk operations with custom field values.

## Test Steps

### 5.1 Discover Projects

**Action:** In Copilot chat, ask:

> "List the GitHub Projects V2 boards in the anokye-labs organization."

**Expected:**
- [ ] Copilot uses the projects.md reference
- [ ] Returns project names and IDs
- [ ] Uses GraphQL `projectsV2` query

### 5.2 Add Issue to Project

**Action:** In Copilot chat:

> "Add issue #2 from anokye-labs/plugins to the Media Plugin Development project board."

**Expected:**
- [ ] Copilot uses `addProjectV2ItemById` mutation
- [ ] Issue appears on the project board
- [ ] Returns confirmation

### 5.3 Bulk Add Issues with Field Values

**Action:** In Copilot chat:

> "Add issues #10, #11, and #12 from anokye-labs/plugins to project #3 and set their Status to 'In Progress' and Priority to 'High'."

**Expected:**
- [ ] Copilot uses `Add-IssuesToProject.ps1` script
- [ ] All three issues are added to the project
- [ ] Custom field values are set correctly
- [ ] Returns summary with success/failure counts

### 5.4 Update Project Field

**Action:** In Copilot chat:

> "Set the Status field of issue #2 on the project board to 'In Progress'."

**Expected:**
- [ ] Copilot uses `updateProjectV2ItemFieldValue` mutation
- [ ] Field is updated in the project board
- [ ] Handles field type correctly (single-select)

### 5.5 Query Project Items

**Action:** In Copilot chat:

> "Show me all items in the Media Plugin Development project with their status."

**Expected:**
- [ ] Returns items with their current field values
- [ ] Handles pagination if many items

### 5.6 Error Handling

**Action:** In Copilot chat:

> "Add issues #999, #1000 (non-existent) to project #3."

**Expected:**
- [ ] Script handles missing issues gracefully
- [ ] Returns clear error messages
- [ ] Does not crash or leave incomplete state

## Pass/Fail

- **PASS:** Steps 5.1, 5.2, and 5.3 succeed
- **FAIL:** Copilot cannot find or use the Projects V2 reference or bulk add script
