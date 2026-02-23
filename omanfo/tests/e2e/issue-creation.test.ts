/**
 * E2E tests — Issue Creation via okyerema
 * Layer 2: sends prompts via the Copilot SDK and verifies issues appear in GitHub.
 * Tests are skipped when a Copilot token or gh auth is unavailable.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { execSync } from 'child_process'
import { createTestSession, isCopilotAvailable, type TestSession } from '../helpers/copilot-session.js'
import { isGhAvailable, cleanupIssues, TEST_REPO } from '../helpers/test-repo.js'

const TESTS_AVAILABLE = isCopilotAvailable() && isGhAvailable()
const RUN_ID = Date.now().toString(36).toUpperCase()
const TEST_PREFIX = `E2E-SDK-${RUN_ID}`
const [OWNER, REPO] = TEST_REPO.split('/')

describe.skipIf(!TESTS_AVAILABLE)('Issue Creation via okyerema', () => {
  let session: TestSession
  const issueTitle = `${TEST_PREFIX}: Automated test Task`

  beforeAll(async () => {
    session = await createTestSession()
  })

  afterAll(async () => {
    await session?.stop()
    cleanupIssues(TEST_PREFIX)
  })

  it('creates a Task issue and the agent calls a tool', async () => {
    const response = await session.sendAndWait(
      `Create a Task issue in ${OWNER}/${REPO} with title "${issueTitle}" and body "Automated E2E test issue — safe to close"`
    )

    expect(response.trim().length).toBeGreaterThan(0)
    expect(session.toolCalls.length).toBeGreaterThan(0)
  })

  it('the created issue appears in the repository', async () => {
    // Allow GitHub API to propagate
    await new Promise((r) => setTimeout(r, 2000))

    const issuesJson = execSync(
      `gh issue list -R ${TEST_REPO} --json number,title --search "${issueTitle}" --limit 10`,
      { encoding: 'utf-8' }
    )
    const issues = JSON.parse(issuesJson) as Array<{ number: number; title: string }>
    const created = issues.find((i) => i.title === issueTitle)
    expect(created).toBeDefined()
  })

  it('the created issue has type Task', async () => {
    const issuesJson = execSync(
      `gh issue list -R ${TEST_REPO} --json number,title --search "${issueTitle}" --limit 10`,
      { encoding: 'utf-8' }
    )
    const issues = JSON.parse(issuesJson) as Array<{ number: number; title: string }>
    const created = issues.find((i) => i.title === issueTitle)

    if (!created) return // covered by previous test

    const typeJson = execSync(
      `gh api graphql -f query='query { repository(owner: "${OWNER}", name: "${REPO}") { issue(number: ${created.number}) { issueType { name } } } }' --jq '.data.repository.issue.issueType.name'`,
      { encoding: 'utf-8' }
    ).trim()

    expect(typeJson).toBe('Task')
  })
})
