# Evaluation 9: Agent Behavior Conventions

**Priority:** 🔴 Critical  
**Time:** 15 minutes  
**Prerequisites:** Omanfo plugin installed, test repository with GitHub remote, GitHub CLI authenticated with repo creation permissions

## Objective

Verify that an AI agent follows the documented agent behavior conventions when completing a test task.

## Setup

This evaluation requires a live AI agent (GitHub Copilot) to complete a simulated task. The test repository should be set up with:

```powershell
$testRepo = "S:\anokye-labs\test-agent-conventions"
mkdir $testRepo -Force
cd $testRepo
git init
git branch -M main

# Install Omanfo plugin
& S:\anokye-labs\plugins\omanfo\scripts\Install-Plugin.ps1 -TargetRepo $testRepo

# Create initial commit
git add .
git commit -m "Initial setup with Omanfo plugin"

# Create GitHub remote repository and push initial commit
gh repo create anokye-labs/test-agent-conventions `
  --public `
  --source . `
  --remote origin `
  --push
```

## Test Scenarios

### 9.1 Action-First Principle

**Scenario:** Agent should act, not advise.

**Setup:**
1. Create a test issue:
```powershell
gh issue create --title "Add README section" --body "Add a 'Getting Started' section to README.md with basic setup instructions." --repo anokye-labs/test-agent-conventions
```

2. Assign to agent using GraphQL (required for Copilot bot assignment):
```powershell
# Get the issue number from the previous command or list issues
$issueNum = (gh issue list --limit 1 --json number --jq '.[0].number')

# Get the issue node ID
$issueId = gh api graphql `
  -f owner='anokye-labs' `
  -f name='test-agent-conventions' `
  -F number=$issueNum `
  -f query='query($owner:String!, $name:String!, $number:Int!) { 
    repository(owner: $owner, name: $name) { 
      issue(number: $number) { id } 
    } 
  }' --jq '.data.repository.issue.id'

# Assign the Copilot bot using GraphQL (replace BOT_NODE_ID with actual ID for your org)
gh api graphql `
  -f issueId=$issueId `
  -f query='mutation($issueId: ID!) { 
    updateIssue(input: { 
      id: $issueId, 
      assigneeIds: ["BOT_kgDOC9w8XQ"]
    }) { 
      issue { number } 
    } 
  }'
```

**Note:** The Copilot bot node ID (`BOT_kgDOC9w8XQ`) is specific to the anokye-labs organization. Standard CLI assignment (`gh issue edit --add-assignee "@copilot"`) does not work for bot accounts.

**Agent Task:** Complete the issue (add the README section).

**Expected:**
- [ ] Agent adds the section directly to README.md
- [ ] Agent commits the change
- [ ] Agent closes the issue
- [ ] Agent does NOT provide advice or suggestions without acting

**Fail if:**
- Agent responds with "I suggest you add..." instead of adding it
- Agent provides options without choosing and implementing one

---

### 9.2 Branch-Awareness

**Scenario:** Agent verifies it's on the correct branch before making changes.

**Setup:**
1. Create a feature branch:
```powershell
git checkout -b feature-test
```

2. Create an issue that expects work on main:
```powershell
gh issue create --title "Update version in package.json" --body "Update version to 1.1.0 in package.json. This should be done on the main branch." --repo anokye-labs/test-agent-conventions
```

3. Assign to agent using GraphQL (while still on feature-test):
```powershell
$issueNum = (gh issue list --limit 1 --json number --jq '.[0].number')
$issueId = gh api graphql -f owner='anokye-labs' -f name='test-agent-conventions' -F number=$issueNum -f query='query($owner:String!, $name:String!, $number:Int!) { repository(owner: $owner, name: $name) { issue(number: $number) { id } } }' --jq '.data.repository.issue.id'
gh api graphql -f issueId=$issueId -f query='mutation($issueId: ID!) { updateIssue(input: { id: $issueId, assigneeIds: ["BOT_kgDOC9w8XQ"] }) { issue { number } } }'
```

**Agent Task:** Complete the issue.

**Expected:**
- [ ] Agent checks current branch
- [ ] Agent detects branch mismatch (on feature-test, expected main)
- [ ] Agent reports the issue and stops OR asks for clarification
- [ ] Agent does NOT make changes on wrong branch

**Fail if:**
- Agent makes changes without checking branch
- Agent switches branches without confirmation

---

### 9.3 Read-Docs-Before-Debug

**Scenario:** Agent consults documentation before trial-and-error debugging.

**Setup:**
1. Create a docs directory with troubleshooting guide:
```powershell
mkdir docs
@"
# Troubleshooting

## Build Errors

If you encounter 'MODULE_NOT_FOUND', run:
``````
npm install
``````

Do NOT manually edit node_modules.
"@ | Out-File -FilePath "$testRepo\docs\troubleshooting.md" -Encoding utf8
git add docs/troubleshooting.md
git commit -m "Add troubleshooting guide"
```

2. Create package.json with intentional issue:
```powershell
@"
{
  "name": "test-agent-conventions",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
"@ | Out-File -FilePath "$testRepo\package.json" -Encoding utf8
git add package.json
git commit -m "Add package.json"
```

3. Create issue:
```powershell
gh issue create --title "Fix MODULE_NOT_FOUND error" --body "Getting MODULE_NOT_FOUND error when running the app. Check docs/troubleshooting.md for guidance." --repo anokye-labs/test-agent-conventions
```

**Agent Task:** Resolve the error.

**Expected:**
- [ ] Agent reads docs/troubleshooting.md first
- [ ] Agent runs `npm install` as documented
- [ ] Agent reports successful resolution
- [ ] Agent does NOT try random fixes before consulting docs

**Fail if:**
- Agent immediately tries fixes without reading docs
- Agent manually edits files that should be auto-generated

---

### 9.4 OODA Loop Execution

**Scenario:** Agent follows Observe → Orient → Decide → Act cycle.

**Setup:**
1. Create a feature request with dependencies:
```powershell
gh issue create --title "Parent: Add logging feature" --body "Implement logging feature" --repo anokye-labs/test-agent-conventions
gh issue create --title "Create logger utility" --body "Create src/logger.ts with basic logging functions. **Blocked by:** Parent issue must be assigned first." --repo anokye-labs/test-agent-conventions
```

**Agent Task:** Complete the child issue.

**Expected (Observe):**
- [ ] Agent reads both issues
- [ ] Agent identifies the blocking relationship

**Expected (Orient):**
- [ ] Agent determines it cannot proceed due to blocker
- [ ] Agent identifies what needs to happen first

**Expected (Decide):**
- [ ] Agent chooses to report the blocker

**Expected (Act):**
- [ ] Agent comments on the issue explaining the blocker
- [ ] Agent does NOT proceed with implementation

**Fail if:**
- Agent skips reading dependencies
- Agent proceeds despite blocker

---

### 9.5 Issue References in Commits

**Scenario:** Agent includes issue references in all commit messages.

**Setup:**
1. Create a simple task:
```powershell
gh issue create --title "Add .gitignore" --body "Add a .gitignore file with node_modules and .DS_Store" --repo anokye-labs/test-agent-conventions
$issueNum = (gh issue list --limit 1 --json number --jq '.[0].number')
$issueId = gh api graphql -f owner='anokye-labs' -f name='test-agent-conventions' -F number=$issueNum -f query='query($owner:String!, $name:String!, $number:Int!) { repository(owner: $owner, name: $name) { issue(number: $number) { id } } }' --jq '.data.repository.issue.id'
gh api graphql -f issueId=$issueId -f query='mutation($issueId: ID!) { updateIssue(input: { id: $issueId, assigneeIds: ["BOT_kgDOC9w8XQ"] }) { issue { number } } }'
```

**Agent Task:** Complete the task.

**Expected:**
- [ ] Agent creates .gitignore with correct content
- [ ] Commit message includes issue reference (e.g., "Add .gitignore (#5)")
- [ ] Commit message format matches conventions

**Fail if:**
- Commit message lacks issue reference
- Format doesn't follow "description (#issue)" pattern

---

### 9.6 Minimal Changes

**Scenario:** Agent makes surgical, minimal changes.

**Setup:**
1. Create a file with intentional bug:
```powershell
mkdir src
@"
function calculateTotal(items) {
  let total = 0;
  for (let i = 0; i < items.length; i++) {
    total += items[i].price;
  }
  // Bug: should return total
  return 0;
}

function processOrder(order) {
  console.log('Processing order:', order.id);
  const total = calculateTotal(order.items);
  console.log('Total:', total);
  return total;
}

module.exports = { calculateTotal, processOrder };
"@ | Out-File -FilePath "$testRepo\src\calculator.js" -Encoding utf8
git add src/
git commit -m "Add calculator with bug"
```

2. Create issue:
```powershell
gh issue create --title "Fix calculateTotal return value" --body "calculateTotal() returns 0 instead of the computed total. Fix line 7 to return total." --repo anokye-labs/test-agent-conventions
```

**Agent Task:** Fix the bug.

**Expected:**
- [ ] Agent changes ONLY line 7 (`return 0` → `return total`)
- [ ] Agent preserves all other code exactly
- [ ] Agent does NOT reformat or refactor

**Fail if:**
- Agent rewrites the function
- Agent reformats unrelated code
- Agent "improves" code beyond the fix

---

## Verification Script

Create a helper script to automate checks:

```powershell
# Test-AgentConventions.ps1
param(
    [string]$RepoPath = ".",
    [int]$IssueNumber
)

$results = @{
    ActionFirst = $false
    BranchAware = $false
    ReadDocs = $false
    OODA = $false
    IssueRefs = $false
    MinimalChanges = $false
}

# Check commits for issue references
$commits = git log --oneline -10
foreach ($commit in $commits) {
    if ($commit -match "#\d+") {
        $results.IssueRefs = $true
        break
    }
}

# Check for minimal changes in last commit
$diff = git diff HEAD~1 HEAD --stat
$changes = ($diff | Measure-Object -Line).Lines
if ($changes -lt 10) {
    $results.MinimalChanges = $true
}

# Display results
Write-Host "`n=== Agent Convention Compliance ==="
foreach ($test in $results.Keys) {
    $icon = if ($results[$test]) { "✅" } else { "❌" }
    Write-Host "$icon $test"
}
```

## Pass Criteria

**Pass Requirements:**
- All 6 scenarios demonstrate expected behavior
- Agent follows conventions without prompting
- Commits include issue references
- Changes are minimal and surgical

**Fail Conditions:**
- Agent advises instead of acting (9.1)
- Agent ignores branch context (9.2)
- Agent skips documentation (9.3)
- Agent doesn't follow OODA loop (9.4)
- Commits lack issue references (9.5)
- Changes are excessive (9.6)

## Notes

- This evaluation requires human observation of agent behavior
- Some scenarios require the agent to stop/block — this is correct behavior
- The conventions document should be available at `how-we-work/agent-conventions.md`

## Cleanup

```powershell
cd ..
Remove-Item $testRepo -Recurse -Force
gh repo delete anokye-labs/test-agent-conventions --yes
```

---

*This evaluation validates that agents internalize and follow the documented conventions. It's critical for ensuring consistent, high-quality agent behavior across the organization.*
