#!/usr/bin/env node
/**
 * E2E Test: Sitrep (Status Report)
 * Validates /sitrep command returns project status
 */

import { runTest } from './copilot-harness.js';

async function main() {
  const testRepo = process.env.E2E_TEST_REPO || 'anokye-labs/plugins';
  const [owner, repo] = testRepo.split('/');

  const success = await runTest(
    'Sitrep Status Report',
    `/sitrep --owner ${owner} --repo ${repo}`,
    {
      shouldNotBeEmpty: true,
      shouldCallTools: ['powershell'],
      rubric: `The response should be a project status report for ${testRepo}. It should include information about open issues, git status, or repository health. It should feel like a useful summary a developer would want to see.`,
      minScore: 3,
    }
  );

  process.exit(success ? 0 : 1);
}

main().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
