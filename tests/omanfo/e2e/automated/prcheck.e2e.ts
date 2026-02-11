#!/usr/bin/env node
/**
 * E2E Test: PR Check
 * Validates /prcheck command returns PR status and review info
 */

import { runTest } from './copilot-harness.js';

async function main() {
  const testRepo = process.env.E2E_TEST_REPO || 'anokye-labs/plugins';
  const [owner, repo] = testRepo.split('/');
  
  // Use a known PR number or skip test if not specified
  const prNumber = process.env.E2E_TEST_PR || '107';

  const success = await runTest(
    'PR Status Check',
    `/prcheck --owner ${owner} --repo ${repo} --pr ${prNumber}`,
    {
      shouldNotBeEmpty: true,
      shouldContain: ['state', 'mergeable'],
      shouldCallTools: ['Get-PRHealth']
    }
  );

  process.exit(success ? 0 : 1);
}

main().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
