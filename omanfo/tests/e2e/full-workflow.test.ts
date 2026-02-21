/**
 * E2E tests — Full Workflow via okyerema
 * Layer 2: exercises the complete plan → materialize → status loop via the Copilot SDK.
 * Tests are skipped when a Copilot token or gh auth is unavailable.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { execSync } from 'child_process'
import { writeFileSync, unlinkSync } from 'fs'
import { tmpdir } from 'os'
import { join } from 'path'
import { createTestSession, isCopilotAvailable, type TestSession } from '../helpers/copilot-session.js'
import { isGhAvailable, cleanupIssues, TEST_REPO } from '../helpers/test-repo.js'

const TESTS_AVAILABLE = isCopilotAvailable() && isGhAvailable()
const RUN_ID = Date.now().toString(36).toUpperCase()
const TEST_PREFIX = `E2E-FLOW-${RUN_ID}`
const [OWNER, REPO] = TEST_REPO.split('/')

describe.skipIf(!TESTS_AVAILABLE)('Full Workflow', () => {
  let session: TestSession
  let planFile: string | undefined

  beforeAll(async () => {
    session = await createTestSession()
  })

  afterAll(async () => {
    await session?.stop()
    if (planFile) {
      try { unlinkSync(planFile) } catch { /* ignore */ }
    }
    cleanupIssues(TEST_PREFIX)
  })

  it('materializes a plan file into a GitHub issue hierarchy', async () => {
    const epicTitle = `${TEST_PREFIX}: Full Workflow Epic`
    planFile = join(tmpdir(), `e2e-plan-${RUN_ID}.md`)

    writeFileSync(
      planFile,
      `# ${epicTitle}\n\n## Overview\nE2E workflow test\n\n## Features\n\n### Feature: Gamma\n- Task: Implement gamma\n- Task: Test gamma\n`,
      'utf-8'
    )

    const response = await session.sendAndWait(
      `Materialize the plan from ${planFile} into ${OWNER}/${REPO}`
    )

    expect(response.trim().length).toBeGreaterThan(0)
    expect(session.toolCalls.length).toBeGreaterThan(0)
  })

  it('the epic created during materialization exists in GitHub', async () => {
    await new Promise((r) => setTimeout(r, 3000))

    const epicTitle = `${TEST_PREFIX}: Full Workflow Epic`
    const issuesJson = execSync(
      `gh issue list -R ${TEST_REPO} --json number,title --search "${epicTitle}" --limit 10`,
      { encoding: 'utf-8' }
    )
    const issues = JSON.parse(issuesJson) as Array<{ number: number; title: string }>
    const found = issues.find((i) => i.title === epicTitle)
    expect(found, `Epic "${epicTitle}" should exist in ${TEST_REPO}`).toBeDefined()
  })

  it('runs /health after materialization and gets a report', async () => {
    const response = await session.sendAndWait(`/health --owner ${OWNER} --repo ${REPO}`)
    expect(response.trim().length).toBeGreaterThan(0)
  })

  it('runs /sitrep and shows open issues', async () => {
    const response = await session.sendAndWait(`/sitrep --owner ${OWNER} --repo ${REPO}`)
    expect(response.trim().length).toBeGreaterThan(0)
  })
})
