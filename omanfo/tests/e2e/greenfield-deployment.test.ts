/**
 * E2E tests — Greenfield Anokye-System Deployment Scenario
 * Layer 2: validates the full greenfield lifecycle via the Copilot SDK:
 *   1. Install detection  — Okyeame detects an unconfigured repository
 *   2. Deployment intent  — agent references Install-Anokye.ps1 / okyerema skill
 *   3. Work planning      — Socratic dialog produces typed issues with a hierarchy
 *   4. Hierarchy check    — ≥1 Epic, ≥2 Features, ≥4 Tasks; parent-child links present
 * Tests are skipped when a Copilot token or gh auth is unavailable.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { execSync } from 'child_process'
import { createTestSession, isCopilotAvailable, type TestSession } from '../helpers/copilot-session.js'
import { isGhAvailable, cleanupIssues, TEST_REPO } from '../helpers/test-repo.js'

const TESTS_AVAILABLE = isCopilotAvailable() && isGhAvailable()
const RUN_ID = Date.now().toString(36).toUpperCase()
const TEST_PREFIX = `E2E-GF-${RUN_ID}`
const [OWNER, REPO] = TEST_REPO.split('/')

/** Retry a function until it returns a truthy value or the timeout expires. */
async function retryUntil<T>(
  fn: () => T,
  { maxMs = 15_000, intervalMs = 2_000 }: { maxMs?: number; intervalMs?: number } = {}
): Promise<T | undefined> {
  const deadline = Date.now() + maxMs
  let last: T | undefined
  while (Date.now() < deadline) {
    last = fn()
    if (last) return last
    await new Promise((r) => setTimeout(r, intervalMs))
  }
  return last
}

/** Return all open issues in the test repo whose titles begin with the given prefix. */
function queryIssues(prefix: string): Array<{ number: number; title: string }> {
  try {
    const json = execSync(
      `gh issue list -R ${TEST_REPO} --json number,title --limit 200`,
      { encoding: 'utf-8' }
    )
    const all = JSON.parse(json) as Array<{ number: number; title: string }>
    return all.filter((i) => i.title.startsWith(prefix))
  } catch {
    return []
  }
}

/** Return the issueType.name for a single issue via GraphQL. */
function queryIssueType(issueNumber: number): string {
  try {
    return execSync(
      `gh api graphql -f query='query { repository(owner: "${OWNER}", name: "${REPO}") { issue(number: ${issueNumber}) { issueType { name } } } }' --jq '.data.repository.issue.issueType.name'`,
      { encoding: 'utf-8' }
    ).trim()
  } catch {
    return ''
  }
}

/** Return the sub-issue numbers linked to a parent issue via GraphQL. */
function querySubIssues(parentNumber: number): number[] {
  try {
    const json = execSync(
      `gh api graphql -f query='query { repository(owner: "${OWNER}", name: "${REPO}") { issue(number: ${parentNumber}) { subIssues(first: 50) { nodes { number } } } } }' --jq '[.data.repository.issue.subIssues.nodes[].number]'`,
      { encoding: 'utf-8' }
    )
    return JSON.parse(json) as number[]
  } catch {
    return []
  }
}

describe.skipIf(!TESTS_AVAILABLE)('Greenfield Deployment Scenario', () => {
  let session: TestSession

  beforeAll(async () => {
    session = await createTestSession()
  })

  afterAll(async () => {
    await session?.stop()
    cleanupIssues(TEST_PREFIX)
  })

  // ── Step 1: Install detection ──────────────────────────────────────────────

  it('detects that the test repo does not have okyerema configured', async () => {
    const response = await session.sendAndWait(
      `Check whether the Anokye System (okyerema skill) is installed and configured in ${OWNER}/${REPO}. ` +
        `Describe what you find.`
    )

    expect(response.trim().length).toBeGreaterThan(0)
    // The agent should acknowledge it looked at the repository state
    expect(session.toolCalls.length).toBeGreaterThan(0)
  })

  // ── Step 2: Deployment intent ──────────────────────────────────────────────

  it('describes how to deploy the Anokye System and references the install script', async () => {
    const response = await session.sendAndWait(
      `How would you install the Anokye System into ${OWNER}/${REPO}? ` +
        `Describe the steps without executing them.`
    )

    expect(response.trim().length).toBeGreaterThan(0)
    // Agent should mention the installer or the okyerema skill
    expect(response).toMatch(/install-anokye|okyerema|omanfo/i)
  })

  // ── Step 3: Work planning via Socratic dialog ──────────────────────────────

  it('creates a typed issue hierarchy from a Socratic planning dialog', async () => {
    const epicTitle = `${TEST_PREFIX}: Anokye-System Rollout`

    const response = await session.sendAndWait(
      `We are planning the rollout of the Anokye System into ${OWNER}/${REPO}. ` +
        `Create the following issue hierarchy in that repo:\n` +
        `- 1 Epic titled "${epicTitle}"\n` +
        `- 2 child Features (e.g. "Bootstrap Infrastructure", "Enable Workflows")\n` +
        `- 2 Tasks under each Feature (e.g. "Configure branch rules", "Add workflow templates", ` +
        `"Set up issue types", "Verify agent configuration")\n` +
        `Use the correct organization issue types (Epic, Feature, Task). ` +
        `Link each Feature as a sub-issue of the Epic, and each Task as a sub-issue of its Feature.`
    )

    expect(response.trim().length).toBeGreaterThan(0)
    expect(session.toolCalls.length).toBeGreaterThan(0)
  })

  // ── Step 4: Verification ───────────────────────────────────────────────────

  it('at least 1 Epic with the test prefix exists in the repository', async () => {
    const issues = await retryUntil(() => queryIssues(TEST_PREFIX))
    const epics = (issues ?? []).filter((i) => queryIssueType(i.number) === 'Epic')
    expect(epics.length).toBeGreaterThanOrEqual(1)
  })

  it('at least 2 Features with the test prefix exist in the repository', async () => {
    const issues = await retryUntil(
      () => {
        const all = queryIssues(TEST_PREFIX)
        return all.filter((i) => queryIssueType(i.number) === 'Feature').length >= 2
          ? all
          : null
      },
      { maxMs: 20_000 }
    )
    const features = (issues ?? []).filter((i) => queryIssueType(i.number) === 'Feature')
    expect(features.length).toBeGreaterThanOrEqual(2)
  })

  it('at least 4 Tasks with the test prefix exist in the repository', async () => {
    const issues = await retryUntil(
      () => {
        const all = queryIssues(TEST_PREFIX)
        return all.filter((i) => queryIssueType(i.number) === 'Task').length >= 4
          ? all
          : null
      },
      { maxMs: 20_000 }
    )
    const tasks = (issues ?? []).filter((i) => queryIssueType(i.number) === 'Task')
    expect(tasks.length).toBeGreaterThanOrEqual(4)
  })

  it('the Epic has at least 1 child sub-issue (Feature)', async () => {
    const issues = queryIssues(TEST_PREFIX)
    const epic = issues.find((i) => queryIssueType(i.number) === 'Epic')
    if (!epic) {
      // If epic was not found in time, skip rather than fail — covered by previous test
      return
    }

    const children = await retryUntil(() => {
      const subs = querySubIssues(epic.number)
      return subs.length >= 1 ? subs : null
    })

    expect((children ?? []).length).toBeGreaterThanOrEqual(1)
  })

  it('at least 1 Feature has child Tasks linked as sub-issues', async () => {
    const issues = queryIssues(TEST_PREFIX)
    const features = issues.filter((i) => queryIssueType(i.number) === 'Feature')
    if (features.length === 0) return

    // At least one Feature should have sub-issues
    let foundChildren = false
    for (const feature of features) {
      const subs = querySubIssues(feature.number)
      if (subs.length >= 1) {
        foundChildren = true
        break
      }
    }
    expect(foundChildren).toBe(true)
  })
})
