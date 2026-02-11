#!/usr/bin/env node
/**
 * E2E Test: What's Left
 * Validates /whatsleft command returns ready and blocked issues
 */

import { runTest } from './copilot-harness.js';

async function main() {
  const testRepo = process.env.E2E_TEST_REPO || 'anokye-labs/plugins';
  const [owner, repo] = testRepo.split('/');

  const success = await runTest(
    'Remaining Work Query',
    `/whatsleft --owner ${owner} --repo ${repo}`,
    {
      shouldNotBeEmpty: true,
      shouldContain: ['Ready', 'Blocked'],
      shouldCallTools: ['Get-ReadyIssues', 'Get-BlockedIssues']
    }
  );

  process.exit(success ? 0 : 1);
}

main().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
