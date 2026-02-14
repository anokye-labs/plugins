# Contributing to Copilot Media Plugins

Thank you for your interest in contributing! This document explains how to get started.

## Reporting Issues

- Use [GitHub Issues](https://github.com/anokye-labs/copilot-media-plugins/issues) to report bugs or request features.
- Check existing issues before creating a new one to avoid duplicates.
- Use the provided issue templates (bug report, feature request) when available.
- Include steps to reproduce, expected behavior, and actual behavior for bug reports.

## Submitting Pull Requests

1. **Fork** the repository and create a branch from `main`.
2. **Name your branch** using the convention: `<type>/<short-description>` (e.g., `feat/add-blur-script`, `fix/queue-timeout`, `docs/update-readme`).
3. **Make your changes** — keep PRs focused on a single concern.
4. **Write or update tests** for any new functionality.
5. **Run tests** before submitting (see [Testing](#testing)).
6. **Open a PR** against `main` and fill out the PR template.
7. **Link issues** using `Closes #<number>` in the PR description.

### Commit Message Format

```
<type>(<scope>): <short description>

<optional body>

Closes #<issue-number>
```

**Types:** `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `ci`

**Example:**
```
feat(fal-ai): add image-to-video generation script

Implement Invoke-FalImageToVideo.ps1 with queue mode support
and progress monitoring.

Closes #25
```

## Development Setup

### Prerequisites

- **PowerShell 7+** — [Install guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **fal.ai API key** — [Get one at fal.ai](https://fal.ai/dashboard/keys)
- **Python 3.10+** — For ImageSorcery MCP server (optional)
- **Pester 5** — PowerShell testing framework

### Getting Started

```powershell
# Clone the repository
git clone https://github.com/anokye-labs/copilot-media-plugins.git
cd copilot-media-plugins

# Set your API key
$env:FAL_KEY = "your-key-here"

# Install Pester (if not already installed)
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force

# Verify setup
.\scripts\Test-FalConnection.ps1
```

### Project Structure

```
copilot-media-plugins/
├── scripts/          # PowerShell scripts and shared module
│   ├── FalAi.psm1   # Shared module (auth, HTTP, uploads, queue)
│   └── *.ps1         # Individual command scripts
├── skills/           # Copilot skill definitions
│   ├── fal-ai/       # AI generation skill
│   ├── fal-workflow/  # Multi-step workflow skill
│   ├── image-sorcery/ # Local image processing skill
│   └── media-agents/ # Fleet-pattern orchestration skill
├── tests/            # Test suites
│   ├── unit/         # Unit tests
│   ├── integration/  # Integration tests
│   ├── e2e/          # End-to-end tests
│   ├── evaluation/   # Quality evaluation tests
│   └── gates/        # Quality gate checks
├── docs/             # Documentation
└── .github/          # GitHub configuration
```

## Testing

This project uses [Pester 5](https://pester.dev/) for testing.

```powershell
# Run all tests
Invoke-Pester -Path tests/

# Run a specific tier
Invoke-Pester -Path tests/unit/
Invoke-Pester -Path tests/integration/

# Run with detailed output
Invoke-Pester -Path tests/ -Output Detailed
```

### Writing Tests

- Place tests alongside the tier they belong to (`tests/unit/`, `tests/integration/`, etc.).
- Name test files `*.Tests.ps1` following Pester conventions.
- Use `Describe`, `Context`, and `It` blocks for structure.
- Mock external API calls in unit tests using `Mock`.

## Code Style

### PowerShell Best Practices

- Use **approved verbs** for function/script names (`Get-`, `Set-`, `Invoke-`, `Test-`, `New-`, `Measure-`).
- Include **comment-based help** (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`) in all scripts and exported functions.
- Use `[CmdletBinding()]` and `[Parameter()]` attributes for all parameters.
- Use `[OutputType()]` to declare return types.
- Follow the existing patterns in `scripts/` — import `FalAi.psm1` for shared functionality.
- Prefer `Write-Verbose` and `Write-Warning` over `Write-Host` for diagnostic output.
- Use `ErrorAction Stop` in `try/catch` blocks for explicit error handling.

### General Guidelines

- Keep functions focused — one function, one responsibility.
- Avoid hardcoded values — use parameters or module-level constants.
- Document non-obvious logic with inline comments.

## Branch Naming Conventions

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feat/` | New feature | `feat/add-video-gen` |
| `fix/` | Bug fix | `fix/queue-timeout` |
| `docs/` | Documentation | `docs/update-api-ref` |
| `test/` | Test changes | `test/add-unit-tests` |
| `refactor/` | Code refactoring | `refactor/simplify-auth` |
| `chore/` | Maintenance tasks | `chore/update-deps` |
| `ci/` | CI/CD changes | `ci/add-lint-workflow` |

## Script Conventions

All scripts in `scripts/` must follow these conventions:

1. **Comment-based help** — Every `.ps1` file must include `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, and `.EXAMPLE` blocks.
2. **CmdletBinding** — All scripts must use `[CmdletBinding()]` and declare parameters with `[Parameter()]` attributes.
3. **Import shared module** — Scripts that call fal.ai APIs must import the shared module:
   ```powershell
   Import-Module "$PSScriptRoot/FalAi.psm1" -Force
   ```
4. **OutputType** — Declare `[OutputType()]` on all scripts and exported functions.
5. **Approved verbs** — Use PowerShell approved verbs (`Get-`, `Invoke-`, `New-`, `Test-`, `Measure-`, `Search-`, `Upload-`).
6. **Error handling** — Use `try/catch` with `ErrorAction Stop`; surface errors via `Write-Error`.

## Test Requirements

All new scripts and features require tests:

- **Unit tests are mandatory** — Place in `tests/unit/<ScriptName>.Tests.ps1`.
- **Pester 5 syntax** — Use `Describe`, `Context`, `It`, `Should`, `BeforeAll`, `BeforeEach`.
- **Mock external APIs** — Never make live API calls in unit tests. Use `Mock` for `Invoke-RestMethod` and `Invoke-WebRequest`.
- **Naming** — Test files must end in `.Tests.ps1`.
- **Run before submitting** — All unit tests must pass: `Invoke-Pester -Path tests/unit/`.
- **Gate tests** — If adding structural elements (skills, references), add or update gate tests in `tests/gates/`.

Example test structure:

```powershell
Describe 'Invoke-FalGenerate' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
        Mock Invoke-RestMethod { return @{ images = @(@{ url = 'https://example.com/img.png' }) } }
    }

    It 'Should return an image URL' {
        $result = & "$PSScriptRoot/../../scripts/Invoke-FalGenerate.ps1" -Prompt 'test'
        $result.images[0].url | Should -Match 'https://'
    }
}
```

## Skill File Guidelines

Skill definitions live in `skills/<skill-name>/SKILL.md`:

- **Frontmatter required fields** — `name`, `description`, `metadata.author`, `metadata.version`.
- **Line budget** — SKILL.md files must stay under 500 lines / 6500 tokens (validated by `TokenBudget.Tests.ps1`).
- **References directory** — Large reference content goes in `skills/<skill-name>/references/*.md`, not in SKILL.md itself.
- **Trigger phrases** — Include explicit trigger phrases in the `description` frontmatter so the skill router can match user intent.
- **Format** — Use YAML frontmatter (`---`) followed by Markdown content with clear sections for capabilities, usage patterns, and examples.

## Evaluation

To add new quality metrics or golden prompt tests:

1. **Add measurement script** — Create `scripts/Measure-<Metric>.ps1` following script conventions above.
2. **Add evaluation test** — Create `tests/evaluation/<Metric>.Tests.ps1` that validates thresholds.
3. **Update thresholds** — Add metric thresholds to `tests/fixtures/quality-thresholds.json`.
4. **Golden prompts** — Add test prompts to `tests/fixtures/golden-prompts.json` with expected quality ranges.
5. **Performance baselines** — Update `tests/fixtures/performance-baseline.json` when establishing new baselines.

Run evaluation tests with:

```powershell
Invoke-Pester ./tests/evaluation/ -Output Detailed
```

## Questions?

Open a [discussion](https://github.com/anokye-labs/copilot-media-plugins/discussions) or file an issue if you have questions about contributing.
