#!/usr/bin/env node
/**
 * E2E Test: Plan Materialization
 * Validates materializing a plan.md creates proper issue hierarchy
 */

import { CopilotTestHarness } from './copilot-harness.js';
import { execSync } from 'child_process';
import { writeFileSync, unlinkSync } from 'fs';
import { join } from 'path';

async function main() {
  const testRepo = process.env.E2E_TEST_REPO || 'anokye-labs/plugins';
  const [owner, repo] = testRepo.split('/');
  const runId = new Date().toISOString().replace(/[-:]/g, '').substring(0, 15);
  const epicTitle = `E2E-SDK-${runId}: Test Epic`;
  
  const harness = new CopilotTestHarness();
  const createdIssues: number[] = [];
  let planFile: string | null = null;

  try {
    console.log('\n' + '='.repeat(60));
    console.log('🧪 Test: Plan Materialization');
    console.log('='.repeat(60));

    // Create a test plan file
    planFile = join('/tmp', `test-plan-${runId}.md`);
    const planContent = `# ${epicTitle}

## Overview
Test plan for automated E2E testing

## Features

### Feature 1: Test Feature A
- Task: Implement component A
- Task: Add tests for A

### Feature 2: Test Feature B
- Task: Implement component B
- Task: Add tests for B
`;

    writeFileSync(planFile, planContent);
    console.log(`✓ Created test plan: ${planFile}`);

    await harness.start();

    // Materialize plan via Copilot
    const result = await harness.sendAndWait(
      `Materialize the plan from ${planFile} into ${owner}/${repo}`
    );

    if (!result.success) {
      console.error(`❌ Test failed: ${result.error}`);
      return false;
    }

    console.log('\n📋 Verifying issue hierarchy via GitHub API...');
    
    // Give GitHub API time to process
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Find the created Epic
    const epicJson = execSync(
      `gh api repos/${owner}/${repo}/issues --jq '.[] | select(.title == "${epicTitle}") | .number'`,
      { encoding: 'utf-8' }
    ).trim();

    if (!epicJson) {
      console.error('❌ Epic was not created');
      return false;
    }

    const epicNumber = parseInt(epicJson);
    createdIssues.push(epicNumber);
    console.log(`✓ Epic #${epicNumber} created`);

    // Verify Epic type
    const epicType = execSync(
      `gh api graphql -f query='query { repository(owner: "${owner}", name: "${repo}") { issue(number: ${epicNumber}) { issueType { name } } } }' --jq '.data.repository.issue.issueType.name'`,
      { encoding: 'utf-8' }
    ).trim();

    if (epicType !== 'Epic') {
      console.error(`❌ Issue type is "${epicType}", expected "Epic"`);
      return false;
    }
    console.log(`✓ Epic has correct type: ${epicType}`);

    // Find child issues (sub-issues of the Epic)
    const childIssuesJson = execSync(
      `gh api graphql -f query='query { repository(owner: "${owner}", name: "${repo}") { issue(number: ${epicNumber}) { subIssues(first: 100) { nodes { number title issueType { name } } } } } }' --jq '.data.repository.issue.subIssues.nodes'`,
      { encoding: 'utf-8' }
    );

    const childIssues = JSON.parse(childIssuesJson);
    console.log(`✓ Found ${childIssues.length} child issues`);

    if (childIssues.length < 2) {
      console.error(`❌ Expected at least 2 child issues (Features), got ${childIssues.length}`);
      return false;
    }

    // Track all created issues for cleanup
    childIssues.forEach((issue: any) => {
      createdIssues.push(issue.number);
      console.log(`  - #${issue.number}: ${issue.title} (${issue.issueType?.name || 'Unknown'})`);
    });

    console.log('\n✅ Test "Plan Materialization" PASSED');
    return true;

  } catch (error) {
    console.error('❌ Test "Plan Materialization" threw exception:', error);
    return false;
  } finally {
    // Cleanup: Close all created issues
    for (const issueNumber of createdIssues) {
      try {
        console.log(`🧹 Closing issue #${issueNumber}...`);
        execSync(
          `gh issue close ${issueNumber} --repo ${owner}/${repo} --reason "not_planned"`,
          { encoding: 'utf-8' }
        );
      } catch (error) {
        console.error(`⚠️  Failed to close issue #${issueNumber}:`, error);
      }
    }

    // Cleanup: Remove plan file
    if (planFile) {
      try {
        unlinkSync(planFile);
        console.log(`✓ Removed test plan file`);
      } catch (error) {
        console.error('⚠️  Failed to remove plan file:', error);
      }
    }

    await harness.stop();
  }
}

main().then(success => {
  process.exit(success ? 0 : 1);
}).catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
