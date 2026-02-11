#!/usr/bin/env node
/**
 * E2E Test: Health Check
 * Validates /health command returns hierarchy health metrics
 */

import { runTest } from './copilot-harness.js';

async function main() {
  const testRepo = process.env.E2E_TEST_REPO || 'anokye-labs/plugins';
  const [owner, repo] = testRepo.split('/');

  const success = await runTest(
    'Hierarchy Health Check',
    `/health --owner ${owner} --repo ${repo}`,
    {
      shouldNotBeEmpty: true,
      shouldContain: ['TypeCounts', 'HealthScore'],
      shouldCallTools: ['Invoke-DagHealthCheck']
    }
  );

  process.exit(success ? 0 : 1);
}

main().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
