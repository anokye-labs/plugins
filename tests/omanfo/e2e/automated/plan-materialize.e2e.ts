#!/usr/bin/env node
/**
 * E2E Test: Plan Materialization
 * Validates materializing a plan.md creates proper issue hierarchy
 */

import { CopilotTestHarness } from './copilot-harness.js';
import { execSync } from 'child_process';
import { writeFileSync, unlinkSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

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

    // Create a test plan file in platform-independent temp directory
    planFile = join(tmpdir(), `test-plan-${runId}.md`);
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

    // Track all created issues for cleanup (including grandchildren)
    for (const issue of childIssues) {
      createdIssues.push(issue.number);
      console.log(`  - #${issue.number}: ${issue.title} (${issue.issueType?.name || 'Unknown'})`);
      
      // Query sub-issues of this issue (e.g., Tasks under each Feature)
      try {
        const grandchildJson = execSync(
          `gh api graphql -f query='query { repository(owner: "${owner}", name: "${repo}") { issue(number: ${issue.number}) { subIssues(first: 100) { nodes { number title issueType { name } } } } } }' --jq '.data.repository.issue.subIssues.nodes'`,
          { encoding: 'utf-8' }
        );
        
        const grandchildren = JSON.parse(grandchildJson);
        grandchildren.forEach((grandchild: any) => {
          createdIssues.push(grandchild.number);
          console.log(`    - #${grandchild.number}: ${grandchild.title} (${grandchild.issueType?.name || 'Unknown'})`);
        });
      } catch (error) {
        // Silently continue if querying grandchildren fails
      }
    }

    console.log('\n✅ Test "Plan Materialization" PASSED');
    return true;

  } catch (error) {
    console.error('❌ Test "Plan Materialization" threw exception:', error);
    return false;
  } finally {
    // Cleanup: Close all created issues
    // Before closing tracked issues, search for any orphaned issues with our prefix
    // This handles cases where test fails early and not all issues were tracked
    try {
      console.log(`\n🔍 Searching for any orphaned issues with prefix E2E-SDK-${runId}...`);
      const searchResults = execSync(
        `gh issue list --repo ${owner}/${repo} --search "E2E-SDK-${runId} in:title" --state open --json number --jq '.[].number'`,
        { encoding: 'utf-8' }
      ).trim();
      
      if (searchResults) {
        const orphanedIssues = searchResults.split('\n').map(n => parseInt(n.trim())).filter(n => !isNaN(n));
        orphanedIssues.forEach(num => {
          if (!createdIssues.includes(num)) {
            console.log(`  Found orphaned issue #${num}, adding to cleanup list`);
            createdIssues.push(num);
          }
        });
      }
    } catch (error) {
      console.log('  Search completed (or no additional issues found)');
    }
    
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
