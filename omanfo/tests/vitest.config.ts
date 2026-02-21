import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    testTimeout: 120_000,
    hookTimeout: 30_000,
    reporters: ['verbose'],
    include: ['**/*.test.ts'],
    exclude: ['node_modules', 'dist'],
    // Force exit after all tests complete — the Copilot SDK may keep handles open
    forceRerunTriggers: [],
    // Integration and E2E tests are slow; run them sequentially
    pool: 'forks',
    poolOptions: {
      forks: {
        singleFork: true,
      },
    },
  },
})
