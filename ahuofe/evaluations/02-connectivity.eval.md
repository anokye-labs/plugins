# Evaluation 2: API Connectivity

**Priority:** 🔴 Critical  
**Time:** 3 minutes  
**Prerequisites:** Installed plugin, `FAL_KEY` environment variable set

## Objective

Verify fal.ai API connectivity and authentication work correctly.

## Test Steps

### 2.1 Test Connection Script

**Action:** Run the connectivity test.

```powershell
& ahuofe\scripts\Test-FalConnection.ps1
```

**Expected:**
- [ ] `[PASS] FAL_KEY found` — API key is detected
- [ ] `[PASS] API reachable` — fal.ai responds with latency
- [ ] No errors or warnings

### 2.2 Missing API Key Handling

**Action:** Temporarily unset the API key and test.

```powershell
$savedKey = $env:FAL_KEY
$env:FAL_KEY = $null
try {
    & ahuofe\scripts\Test-FalConnection.ps1
} finally {
    $env:FAL_KEY = $savedKey
}
```

**Expected:**
- [ ] Script reports `FAL_KEY not found` (not a crash)
- [ ] Error message is descriptive

### 2.3 Shared Module Loads

**Action:** Import the shared module directly.

```powershell
Import-Module ahuofe\scripts\FalAi.psm1 -Force
Get-Command -Module FalAi
```

**Expected:**
- [ ] Module imports without errors
- [ ] Exports at least: `Get-FalApiKey`, `Invoke-FalApi`, `Send-FalFile`, `Wait-FalJob`, `ConvertTo-FalError`

### 2.4 Copilot Can Reach fal.ai

**Action:** In a Copilot chat session, ask:

> "Test the fal.ai API connection"

**Expected:**
- [ ] Copilot uses the fal-ai skill
- [ ] Runs or references `Test-FalConnection.ps1`
- [ ] Reports connectivity status

## Pass/Fail

- **PASS:** Steps 2.1, 2.2, and 2.3 succeed
- **FAIL:** Any of these fail
