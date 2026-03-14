# Tests

Test suites for Anokye Labs plugins. Organized by plugin, with unit, integration, and e2e tiers.

## Structure

| Directory | Plugin | Contents |
|-----------|--------|----------|
| [omanfo/](omanfo/) | Omanfo | Smoke tests, unit tests, integration tests, e2e tests |
| [okyerema/](okyerema/) | Okyerema | Unit tests, integration tests, e2e tests, fixtures |

## Running Tests

```powershell
# Run all unit tests
pwsh -NoProfile -Command "Invoke-Pester -Path tests/omanfo/unit,tests/okyerema/unit -CI"

# Run a specific plugin's tests
pwsh -NoProfile -Command "Invoke-Pester -Path tests/okyerema/ -CI"

# Run with local test runner (okyerema)
pwsh -File tests/okyerema/Run-LocalTests.ps1
```

## Test Tiers

| Tier | Speed | External deps | When to run |
|------|-------|---------------|-------------|
| **unit** | Fast | None | Every commit |
| **integration** | Medium | GitHub API | PR validation |
| **e2e** | Slow | Full environment | Pre-release |
