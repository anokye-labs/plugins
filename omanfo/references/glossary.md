# Glossary: The Anokye System

The Anokye System is our multi-agent orchestration architecture for software
development. Each role has an Akan name reflecting its function.

| Akan Term | Meaning | Role in the Anokye System |
|-----------|---------|--------------------------|
| **Okyeame** | Linguist | The voice — gives status updates, reports on blocked issues, asks for clarity when needed. |
| **Okyerema** | Master drummer | The master drummer of the asafo — keeps the warriors in rhythm through workflow automation, patrols, and CI/CD. |
| **Asafo** | Warrior company | Implementation agents — `@copilot` and other agents that pick up Tasks, write code, open PRs |
| **Adwoma** | Work | GitHub Issues as external memory — every task, decision, status change. The single source of truth. |
| **Ananse** | Spider (folklore) | The agentic runtime — `@copilot` coding agent, `gh-aw` workflows, GitHub Actions |
| **Sankofa** | Return and get it | Automated health patrols — scheduled workflows that detect stale, orphaned, or stuck work |
| **Akwaaba** | Welcome | The reference repository — conventions, onboarding, team knowledge |

## Principle Summary

1. **Okyeame speaks, Asafo implements** — the linguist gives voice, the warriors execute
2. **Okyerema keeps the rhythm** — the master drummer of the asafo keeps the warriors in cadence
3. **Adwoma is the single source of truth** — if it's not in an issue, it doesn't exist
4. **Zero-footprint computing** — agents query the API, never rely on local memory
5. **Sankofa keeps the system healthy** — automated patrols catch what humans miss
6. **Automate the predictable, ask about the ambiguous** — human attention for judgment only
