/**
 * E2E tests — Hierarchy Building via okyerema
 * Layer 2: sends prompts via the Copilot SDK and verifies the issue hierarchy in GitHub.
 * Tests are skipped when a Copilot token or gh auth is unavailable.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { execSync } from 'child_process'
import { createTestSession, isCopilotAvailable, type TestSession } from '../helpers/copilot-session.js'
import { isGhAvailable, cleanupIssues, TEST_REPO } from '../helpers/test-repo.js'

const TESTS_AVAILABLE = isCopilotAvailable() && isGhAvailable()
const RUN_ID = Date.now().toString(36).toUpperCase()
const TEST_PREFIX = `E2E-HIER-${RUN_ID}`
const [OWNER, REPO] = TEST_REPO.split('/')

describe.skipIf(!TESTS_AVAILABLE)('Hierarchy Building via okyerema', () => {
  let session: TestSession
  const epicTitle = `${TEST_PREFIX}: Test Epic`
  const featureTitle = `${TEST_PREFIX}: Test Feature`
  const taskTitle = `${TEST_PREFIX}: Test Task`

  beforeAll(async () => {
    session = await createTestSession()
  })

  afterAll(async () => {
    await session?.stop()
    cleanupIssues(TEST_PREFIX)
  })

  it('builds a 3-level hierarchy (Epic → Feature → Task)', async () => {
    const prompt =
      `In ${OWNER}/${REPO} create a 3-level issue hierarchy: ` +
      `an Epic titled "${epicTitle}", ` +
      `a child Feature titled "${featureTitle}", ` +
      `and a grandchild Task titled "${taskTitle}". ` +
      `Link them as sub-issues.`

    const response = await session.sendAndWait(prompt)
    expect(response.trim().length).toBeGreaterThan(0)
    expect(session.toolCalls.length).toBeGreaterThan(0)
  })

  it('all three issues appear in the repository', async () => {
    await new Promise((r) => setTimeout(r, 3000))

    for (const title of [epicTitle, featureTitle, taskTitle]) {
      const issuesJson = execSync(
        `gh issue list -R ${TEST_REPO} --json number,title --search "${title}" --limit 10`,
        { encoding: 'utf-8' }
      )
      const issues = JSON.parse(issuesJson) as Array<{ number: number; title: string }>
      const found = issues.find((i) => i.title === title)
      expect(found, `Expected issue "${title}" to exist in ${TEST_REPO}`).toBeDefined()
    }
  })

  it('Epic has the correct issue type', async () => {
    const issuesJson = execSync(
      `gh issue list -R ${TEST_REPO} --json number,title --search "${epicTitle}" --limit 10`,
      { encoding: 'utf-8' }
    )
    const issues = JSON.parse(issuesJson) as Array<{ number: number; title: string }>
    const epic = issues.find((i) => i.title === epicTitle)
    if (!epic) return

    const typeJson = execSync(
      `gh api graphql -f query='query { repository(owner: "${OWNER}", name: "${REPO}") { issue(number: ${epic.number}) { issueType { name } } } }' --jq '.data.repository.issue.issueType.name'`,
      { encoding: 'utf-8' }
    ).trim()

    expect(typeJson).toBe('Epic')
  })
})
