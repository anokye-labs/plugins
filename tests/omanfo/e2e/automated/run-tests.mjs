#!/usr/bin/env node
/**
 * Test runner - executes all E2E tests sequentially
 */

import { readdirSync } from 'fs';
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function runTest(testFile) {
  return new Promise((resolve) => {
    console.log(`\n${'='.repeat(70)}`);
    console.log(`Running: ${testFile}`);
    console.log('='.repeat(70));

    const child = spawn(
      'node',
      ['--loader', 'ts-node/esm', testFile],
      {
        cwd: __dirname,
        stdio: 'inherit',
        env: { ...process.env }
      }
    );

    child.on('close', (code) => {
      resolve({ testFile, exitCode: code });
    });
  });
}

async function main() {
  // Find all test files
  const testFiles = readdirSync(__dirname)
    .filter(f => f.endsWith('.e2e.ts'))
    .sort();

  if (testFiles.length === 0) {
    console.error('No test files found');
    process.exit(1);
  }

  console.log(`Found ${testFiles.length} test file(s):`);
  testFiles.forEach(f => console.log(`  - ${f}`));

  const results = [];
  
  // Run tests sequentially
  for (const testFile of testFiles) {
    const result = await runTest(testFile);
    results.push(result);
  }

  // Print summary
  console.log('\n' + '='.repeat(70));
  console.log('TEST SUMMARY');
  console.log('='.repeat(70));

  const passed = results.filter(r => r.exitCode === 0);
  const failed = results.filter(r => r.exitCode !== 0);

  console.log(`\nTotal: ${results.length}`);
  console.log(`Passed: ${passed.length}`);
  console.log(`Failed: ${failed.length}`);

  if (failed.length > 0) {
    console.log('\nFailed tests:');
    failed.forEach(r => console.log(`  ✗ ${r.testFile} (exit code ${r.exitCode})`));
  }

  // Exit with failure if any test failed
  process.exit(failed.length > 0 ? 1 : 0);
}

main().catch(error => {
  console.error('Test runner failed:', error);
  process.exit(1);
});
