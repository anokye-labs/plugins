# Contributing to Anokye Plugins

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| PowerShell | 7.0+ | Scripts, modules, Pester tests |
| Node.js | 18+ | TypeScript pipeline, Vitest tests |
| GitHub CLI (`gh`) | Latest | API operations, authentication |
| Pester | 5.x | PowerShell test framework |
| Git | Latest | Version control |

### Optional

| Tool | Purpose |
|------|---------|
| fal.ai API key (`FAL_KEY`) | Required for ahuofe E2E tests |
| ImageSorcery MCP server | Required for image-sorcery skill testing |

## Running Tests

### All PowerShell Tests

```powershell
# Ahuofe plugin tests
Invoke-Pester ahuofe/tests/

# Omanfo plugin tests
Invoke-Pester tests/omanfo/

# Repo script tests
Invoke-Pester tests/scripts/unit/
```

### All TypeScript Tests

```bash
# Ahuofe pipeline
cd ahuofe/pipeline && npm install && npm test

# Omanfo TypeScript tests
cd omanfo/tests && npm install && npm test
```

### By Tier

```powershell
# Unit tests only (fast, fully mocked)
Invoke-Pester ahuofe/tests/unit/
Invoke-Pester tests/omanfo/unit/

# Integration tests (mocked APIs)
Invoke-Pester ahuofe/tests/integration/
Invoke-Pester tests/omanfo/integration/

# E2E tests (mocked — runs in CI without credentials)
Invoke-Pester ahuofe/tests/e2e/
Invoke-Pester tests/omanfo/e2e/
```

## How to Add Things

### A New Skill

1. Create directory: `{plugin}/skills/{skill-name}/`
2. Write `SKILL.md` (must be <500 lines)
3. Add `references/` for extended docs (progressive disclosure)
4. Add `scripts/` for PowerShell helpers if needed
5. Add tests in `{plugin}/tests/` covering the skill's functionality
6. Update the plugin's `README.md` skill table

### A New Script

1. Create `{location}/scripts/Verb-Noun.ps1` using PowerShell Verb-Noun naming
2. Include comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)
3. Use `[CmdletBinding()]` and typed `[Parameter()]` attributes
4. Return `[PSCustomObject]` for structured output
5. Add Pester tests in the appropriate `tests/` directory
6. Import shared modules via `$PSScriptRoot`-relative paths

### A New Agent Archetype

1. Create `omanfo/archetypes/{name}.agent.md` following the `.agent.md` format
2. Define persona, triggers, workflow steps, and tools
3. Add workflow YAML in `.github/workflows/` if needed
4. Add Pester tests for the agent's workflow logic
5. Use `scripts/New-Agent.ps1` to scaffold from a template:
   ```powershell
   ./scripts/New-Agent.ps1 -Name my-agent -Archetype custom
   ```

### A New Shared Module

1. Create directory: `shared/{ModuleName}/`
2. Create `{ModuleName}.psd1` (module manifest) and `{ModuleName}.psm1` (implementation)
3. Add a `README.md` following the style of [OkyeremanAgentRunner/README.md](../shared/OkyeremanAgentRunner/README.md)
4. Add `Tests/` directory with Pester tests
5. Update [shared/README.md](../shared/README.md) module table

### A New Plugin

1. Create the plugin directory at the repo root (e.g., `myplugin/`)
2. Add `.github/plugin/plugin.json` with Copilot CLI metadata
3. Add `skills/`, `scripts/`, `tests/` directories
4. Add `README.md` with overview, skill table, and installation instructions
5. Update root `README.md` plugin table

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): description`

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`

**Scopes:** `(ahuofe)`, `(omanfo)`, `(shared)`, `(ci)`, `(docs)`, `(scripts)`

Examples:
```
feat(omanfo): add xlsx skill for spreadsheet processing
fix(ahuofe): handle 429 rate limit in FalAi.psm1
test(shared): add retry logic tests for OkyeremanAgentRunner
docs: update ARCHITECTURE.md with pipeline section
ci: add nightly scenario test workflow
```

## Pull Request Process

1. **Create a branch** from `main` with a descriptive name
2. **Write tests** for all new features and bug fixes
3. **Run the full test suite** before pushing
4. **Open a PR** with a clear description referencing the related issue (`Closes #123`)
5. **CI checks must pass** — `validate-plugin.yml` runs structure validation, linting, and tests
6. **PRs require a linked issue** — the `require-linked-issue.yml` workflow enforces this
7. **Review and merge** — approved PRs enter the merge queue automatically

## CI Checks

The following checks run on every PR:

| Check | Workflow | What It Validates |
|-------|----------|-------------------|
| File structure | `validate-plugin.yml` | Plugin directory layout, required files |
| Syntax | `validate-plugin.yml` | PowerShell syntax, PSScriptAnalyzer |
| Unit tests | `validate-plugin.yml` | Pester unit tests pass |
| Coverage threshold | `validate-plugin.yml` | Line coverage >= 70% (JaCoCo) |
| E2E tests | `validate-plugin.yml` | Mocked E2E tests pass (ahuofe + omanfo) |
| Dependency audit | `validate-plugin.yml` | No high/critical npm vulnerabilities |
| Linked issue | `require-linked-issue.yml` | PR references an issue |

See [WORKFLOWS.md](WORKFLOWS.md) for full workflow documentation.

## Design Principles

- **Skills < 500 lines** — Use `references/` for progressive disclosure
- **GraphQL-first** — All structured GitHub operations use GraphQL, not REST
- **Organization issue types** — Epic, Feature, Task, Bug (never labels for structure)
- **Sub-issues for hierarchy** — Parent-child relationships via sub-issues API
- **PowerShell Verb-Noun** — All scripts follow standard PowerShell naming
- **Comment-based help is the docs** — Scripts self-document; don't duplicate externally
