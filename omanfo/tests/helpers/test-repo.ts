/**
 * test-repo.ts
 * gh CLI wrappers, issue cleanup, and state queries for E2E tests.
 */

import { execSync } from 'child_process'

export const TEST_REPO = process.env.E2E_TEST_REPO ?? 'anokye-labs/test-sandbox'

/**
 * Call the GitHub REST API for the test repo and return parsed JSON.
 */
export function ghApi(endpoint: string): unknown {
  return JSON.parse(
    execSync(`gh api repos/${TEST_REPO}/${endpoint}`, { encoding: 'utf-8' })
  )
}

/**
 * List open issues whose titles start with the given prefix.
 */
export function listIssues(prefix: string): Array<{ number: number; title: string; state: string }> {
  const issues = JSON.parse(
    execSync(`gh issue list -R ${TEST_REPO} --json number,title,state --limit 200`, {
      encoding: 'utf-8',
    })
  ) as Array<{ number: number; title: string; state: string }>
  return issues.filter((i) => i.title.startsWith(prefix))
}

/**
 * Close and delete all issues whose titles start with the given prefix.
 */
export function cleanupIssues(prefix: string): void {
  const issues = listIssues(prefix)
  for (const issue of issues) {
    try {
      execSync(`gh issue close ${issue.number} -R ${TEST_REPO} --reason not_planned`, {
        stdio: 'pipe',
      })
    } catch {
      // already closed — continue
    }
    try {
      execSync(`gh issue delete ${issue.number} -R ${TEST_REPO} --yes`, { stdio: 'pipe' })
    } catch {
      // deletion may fail when the issue is locked; ignore
    }
  }
}

/**
 * Return true when the gh CLI is authenticated and can reach GitHub.
 */
export function isGhAvailable(): boolean {
  try {
    execSync('gh auth status', { stdio: 'pipe' })
    return true
  } catch {
    return false
  }
}

/**
 * Return true when PowerShell (pwsh) is available on PATH.
 */
export function isPwshAvailable(): boolean {
  try {
    execSync('pwsh -NoProfile -Command exit', { stdio: 'pipe' })
    return true
  } catch {
    return false
  }
}

/**
 * Run a PowerShell script from the okyerema scripts directory.
 *
 * @param scriptName  Script filename (e.g. 'Get-IssueTypeIds.ps1')
 * @param args        Parameter string appended to the pwsh command
 */
export function runScript(scriptName: string, args = ''): string {
  const scriptDir = new URL('../../../skills/okyerema/scripts', import.meta.url).pathname
  const scriptPath = `${scriptDir}/${scriptName}`
  return execSync(
    `pwsh -NoProfile -NonInteractive -Command "& '${scriptPath}' ${args}"`,
    { encoding: 'utf-8' }
  )
}
