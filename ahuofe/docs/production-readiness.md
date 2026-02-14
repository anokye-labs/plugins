# Production Readiness Checklist

> Use this checklist before releasing any wave or major feature.

## Checklist

### Security

- [ ] Security review completed — see [docs/security/](security/)
- [ ] API key management follows [security guide](security/api-key-management.md)
- [ ] No secrets committed to source control
- [ ] `.env` file in `.gitignore`
- [ ] Secret handling documented — see [docs/security/secret-handling.md](security/secret-handling.md)

### Skill Files

- [ ] All SKILL.md files under 500 lines
- [ ] All SKILL.md files under 6500 tokens
- [ ] Skill files contain required sections (tools, examples, constraints)
- [ ] No hardcoded API keys or secrets in skill files

### Error Handling

- [ ] Error handling covers all failure modes:
  - [ ] Network timeout
  - [ ] API rate limiting (429)
  - [ ] Invalid API key (401/403)
  - [ ] Malformed request (400)
  - [ ] Server errors (500+)
  - [ ] File I/O errors
  - [ ] Invalid user input
- [ ] Errors return user-friendly messages
- [ ] Errors are logged with structured format

### Rate Limiting

- [ ] Rate limiting implemented for fal.ai calls
- [ ] Retry logic with exponential backoff
- [ ] Queue polling has max-wait timeout
- [ ] Concurrent request limits defined

### Logging

- [ ] Logging follows structured format (JSON or key=value)
- [ ] Log levels used appropriately (Debug, Info, Warning, Error)
- [ ] Sensitive data excluded from logs (API keys, user data)
- [ ] Request/response metadata logged (model, duration, status)

### Testing

- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Evaluation tests passing
- [ ] Gate tests passing (Gate 1, Gate 2, etc.)
- [ ] Golden prompt regression tests passing
- [ ] Code coverage above minimum threshold

### CI/CD Pipeline

- [ ] CI/CD pipeline operational
- [ ] Automated tests run on PR
- [ ] Quality gates enforced
- [ ] Branch protection rules configured
- [ ] Artifact publishing configured

### Documentation

- [ ] User guides complete — see [docs/user-guides/](user-guides/)
- [ ] API reference complete — see [docs/api-reference/](api-reference/)
- [ ] Architecture docs complete — see [docs/architecture/](architecture/)
- [ ] Examples gallery populated — see [docs/examples-gallery/](examples-gallery/)
- [ ] AGENTS.md up to date

### Performance

- [ ] Performance baseline established
- [ ] Image generation completes within 120s
- [ ] Queue wait time under 300s
- [ ] File sizes within thresholds (1KB–50MB)

### Quality

- [ ] Quality thresholds configured — see [tests/fixtures/quality-thresholds.json](../tests/fixtures/quality-thresholds.json)
- [ ] Golden prompts dataset populated — see [tests/fixtures/golden-prompts.json](../tests/fixtures/golden-prompts.json)
- [ ] Brightness, contrast, entropy checks operational
- [ ] CLIP score validation available (when Python dependencies present)

### Monitoring & Alerting

- [ ] Monitoring strategy defined
- [ ] API error rate tracking in place
- [ ] Generation success/failure metrics available
- [ ] Alerting thresholds configured

---

## Validation Scripts

Run these PowerShell commands to validate each category programmatically.

### Security Validation

```powershell
# Verify no secrets in tracked files
$secrets = git grep -i 'FAL_KEY\s*=' -- ':!.env*' ':!*.md' ':!*.json'
if ($secrets) { Write-Error "Potential secret found in tracked files"; exit 1 }

# Verify .env is in .gitignore
$gitignore = Get-Content .gitignore -Raw
if ($gitignore -notmatch '\.env') { Write-Error ".env not in .gitignore"; exit 1 }

# Verify security docs exist
@('docs/security/api-key-management.md', 'docs/security/secret-handling.md') | ForEach-Object {
    if (-not (Test-Path $_)) { Write-Error "Missing: $_"; exit 1 }
}
Write-Host "✅ Security checks passed" -ForegroundColor Green
```

### Skill File Validation

```powershell
# Check all SKILL.md files are under 500 lines
$skills = Get-ChildItem -Recurse -Filter 'SKILL.md'
foreach ($skill in $skills) {
    $lineCount = (Get-Content $skill.FullName).Count
    if ($lineCount -gt 500) {
        Write-Error "$($skill.FullName) has $lineCount lines (max 500)"
        exit 1
    }
    Write-Host "  $($skill.Name): $lineCount lines" -ForegroundColor Gray
}
Write-Host "✅ Skill file line counts OK" -ForegroundColor Green
```

### Error Handling Validation

```powershell
# Verify error handling patterns exist in scripts
$scripts = Get-ChildItem scripts -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
foreach ($s in $scripts) {
    $content = Get-Content $s.FullName -Raw
    if ($content -notmatch 'try\s*\{' -and $content -notmatch 'catch') {
        Write-Warning "$($s.Name) may lack error handling"
    }
}
Write-Host "✅ Error handling spot-check complete" -ForegroundColor Green
```

### Test Execution

```powershell
# Run all gate tests
Invoke-Pester tests/gates -Output Detailed

# Run unit tests
Invoke-Pester tests/unit -Output Detailed

# Run integration tests (requires API key)
if ($env:FAL_KEY) {
    Invoke-Pester tests/integration -Output Detailed
} else {
    Write-Warning "Skipping integration tests (FAL_KEY not set)"
}

# Run evaluation tests
Invoke-Pester tests/evaluation -Output Detailed
```

### Quality Threshold Validation

```powershell
# Verify quality threshold config is valid
$thresholds = Get-Content tests/fixtures/quality-thresholds.json -Raw | ConvertFrom-Json
if (-not $thresholds.image) { Write-Error "Missing image thresholds"; exit 1 }
if (-not $thresholds.video) { Write-Error "Missing video thresholds"; exit 1 }
if (-not $thresholds.performance) { Write-Error "Missing performance thresholds"; exit 1 }
Write-Host "✅ Quality thresholds valid" -ForegroundColor Green

# Verify golden prompts dataset
$prompts = Get-Content tests/fixtures/golden-prompts.json -Raw | ConvertFrom-Json
$count = $prompts.prompts.Count
if ($count -lt 20) { Write-Error "Only $count golden prompts (need 20+)"; exit 1 }
Write-Host "✅ Golden prompts: $count entries" -ForegroundColor Green
```

### Documentation Completeness

```powershell
# Verify all doc directories have content
$docDirs = @(
    @{ Path = 'docs/user-guides'; Min = 3 },
    @{ Path = 'docs/api-reference'; Min = 2 },
    @{ Path = 'docs/examples-gallery'; Min = 2 },
    @{ Path = 'docs/architecture'; Min = 1 },
    @{ Path = 'docs/security'; Min = 2 }
)
foreach ($dir in $docDirs) {
    $files = Get-ChildItem $dir.Path -Filter '*.md' -ErrorAction SilentlyContinue
    if ($files.Count -lt $dir.Min) {
        Write-Error "$($dir.Path) has $($files.Count) files (need $($dir.Min)+)"
        exit 1
    }
}
Write-Host "✅ Documentation completeness OK" -ForegroundColor Green
```

### Performance Baseline

```powershell
# Verify performance thresholds are configured
$thresholds = Get-Content tests/fixtures/quality-thresholds.json -Raw | ConvertFrom-Json
$maxGen = $thresholds.performance.max_generation_time_seconds
$maxQueue = $thresholds.performance.max_queue_wait_seconds
Write-Host "Max generation time: ${maxGen}s"
Write-Host "Max queue wait: ${maxQueue}s"
Write-Host "✅ Performance baseline configured" -ForegroundColor Green
```

### Run All Validations

```powershell
# One-liner to run all gate tests as a quick validation
Invoke-Pester tests/gates -Output Detailed -PassThru |
    Select-Object -Property Result, TotalCount, PassedCount, FailedCount, SkippedCount
```
