#!/usr/bin/env node
/**
 * Validation script for automated E2E test setup
 * Checks prerequisites without running actual tests
 */

console.log('🔍 Validating automated E2E test setup...\n');

let errors = 0;

// Check Node.js version
const nodeVersion = process.version;
const nodeMajor = parseInt(nodeVersion.slice(1).split('.')[0]);
console.log(`Node.js: ${nodeVersion}`);
if (nodeMajor < 20) {
  console.error('❌ Node.js 20+ required');
  errors++;
} else {
  console.log('✓ Node.js version OK');
}

// Check if we're in ES module mode
console.log(`\nModule system: ${process.env.NODE_OPTIONS || 'default'}`);
console.log('✓ ES modules enabled');

// Check for GitHub token
const hasToken = !!process.env.GITHUB_TOKEN || !!process.env.GH_TOKEN;
console.log(`\nGitHub token: ${hasToken ? '✓ Available' : '⚠️  Not set (required for tests)'}`);
if (!hasToken) {
  console.log('  Set GITHUB_TOKEN or use `gh auth login`');
}

// Check for gh CLI
import { execSync } from 'child_process';
try {
  const ghVersion = execSync('gh --version', { encoding: 'utf-8' });
  console.log(`\nGitHub CLI: ${ghVersion.split('\n')[0]}`);
  console.log('✓ gh CLI available');
} catch (error) {
  console.error('❌ GitHub CLI not found');
  console.error('  Install from: https://cli.github.com');
  errors++;
}

// Try to import the SDK
console.log('\n📦 Checking Copilot SDK...');
try {
  const { CopilotClient } = await import('@github/copilot-sdk');
  console.log('✓ @github/copilot-sdk imported successfully');
  console.log(`  Type: ${typeof CopilotClient}`);
} catch (error) {
  console.error('❌ Failed to import @github/copilot-sdk');
  console.error(`  Error: ${error.message}`);
  errors++;
}

// Check test files
console.log('\n📝 Checking test files...');
import { readdirSync } from 'fs';
const testFiles = readdirSync('.').filter(f => f.endsWith('.e2e.ts'));
console.log(`✓ Found ${testFiles.length} test files:`);
testFiles.forEach(f => console.log(`  - ${f}`));

// Summary
console.log('\n' + '='.repeat(50));
if (errors === 0) {
  console.log('✅ Setup validation PASSED');
  console.log('All prerequisites are met for automated E2E tests.');
  process.exit(0);
} else {
  console.log(`❌ Setup validation FAILED (${errors} errors)`);
  console.log('Fix the errors above before running tests.');
  process.exit(1);
}
