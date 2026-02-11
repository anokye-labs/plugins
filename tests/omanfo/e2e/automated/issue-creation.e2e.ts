#!/usr/bin/env node
/**
 * E2E Test: Issue Creation
 * Validates creating a Task issue via Okyerema
 */

import { CopilotTestHarness } from './copilot-harness.js';
import { execSync } from 'child_process';

async function main() {
  const testRepo = process.env.E2E_TEST_REPO || 'anokye-labs/plugins';
  const [owner, repo] = testRepo.split('/');
  const runId = new Date().toISOString().replace(/[-:]/g, '').substring(0, 15);
  const issueTitle = `E2E-SDK-${runId}: Test task issue`;
  
  const harness = new CopilotTestHarness();
  let createdIssueNumber: number | null = null;

  try {
    console.log('\n' + '='.repeat(60));
    console.log('🧪 Test: Issue Creation via Okyerema');
    console.log('='.repeat(60));

    await harness.start();

    // Create issue via Copilot
    const result = await harness.sendAndWait(
      `Create a Task issue in ${owner}/${repo} with title "${issueTitle}" and body "Test issue created by automated E2E test"`
    );

    if (!result.success) {
      console.error(`❌ Test failed: ${result.error}`);
      return false;
    }

    // Verify issue was created via GitHub API
    console.log('\n📋 Verifying issue creation via GitHub API...');
    
    // Give GitHub API time to process
    await new Promise(resolve => setTimeout(resolve, 2000));

    const issuesJson = execSync(
      `gh api repos/${owner}/${repo}/issues --jq '.[] | select(.title == "${issueTitle}") | .number'`,
      { encoding: 'utf-8' }
    ).trim();

    if (!issuesJson) {
      console.error('❌ Issue was not created in repository');
      return false;
    }

    createdIssueNumber = parseInt(issuesJson);
    console.log(`✓ Issue #${createdIssueNumber} created successfully`);

    // Verify issue type is Task
    const issueType = execSync(
      `gh api graphql -f query='query { repository(owner: "${owner}", name: "${repo}") { issue(number: ${createdIssueNumber}) { issueType { name } } } }' --jq '.data.repository.issue.issueType.name'`,
      { encoding: 'utf-8' }
    ).trim();

    if (issueType !== 'Task') {
      console.error(`❌ Issue type is "${issueType}", expected "Task"`);
      return false;
    }

    console.log(`✓ Issue has correct type: ${issueType}`);
    console.log('\n✅ Test "Issue Creation" PASSED');
    return true;

  } catch (error) {
    console.error('❌ Test "Issue Creation" threw exception:', error);
    return false;
  } finally {
    // Cleanup: Close the created issue
    if (createdIssueNumber) {
      try {
        console.log(`\n🧹 Cleaning up: Closing issue #${createdIssueNumber}...`);
        execSync(
          `gh issue close ${createdIssueNumber} --repo ${owner}/${repo} --reason "not_planned"`,
          { encoding: 'utf-8' }
        );
        console.log(`✓ Issue #${createdIssueNumber} closed`);
      } catch (error) {
        console.error(`⚠️  Failed to close issue #${createdIssueNumber}:`, error);
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
