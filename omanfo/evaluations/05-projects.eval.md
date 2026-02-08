# Evaluation 5: GitHub Projects V2

**Priority:** 🟡 Important  
**Time:** 10 minutes  
**Prerequisites:** Installed plugin, org with a Projects V2 board

## Objective

Verify the skill's Projects V2 reference enables Copilot to manage project boards.

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

### 5.3 Update Project Field

**Action:** In Copilot chat:

> "Set the Status field of issue #2 on the project board to 'In Progress'."

**Expected:**
- [ ] Copilot uses `updateProjectV2ItemFieldValue` mutation
- [ ] Field is updated in the project board
- [ ] Handles field type correctly (single-select)

### 5.4 Query Project Items

**Action:** In Copilot chat:

> "Show me all items in the Media Plugin Development project with their status."

**Expected:**
- [ ] Returns items with their current field values
- [ ] Handles pagination if many items

## Pass/Fail

- **PASS:** Steps 5.1 and 5.2 succeed
- **FAIL:** Copilot cannot find or use the Projects V2 reference
