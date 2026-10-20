import { defineConfig } from '@playwright/test';
import path from 'node:path';

const artifactDir = process.env.WORKSPACE_ARTIFACTS ?? path.resolve(__dirname, '.moai/reports/SPEC-WORKSPACE-001/implementation/001/browser');

export default defineConfig({
  testDir: './tests/e2e',
  outputDir: path.join(artifactDir, 'browser-artifacts'),
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: !!process.env.CI,
  reporter: [['list'], ['json', { outputFile: path.join(artifactDir, 'browser-results.json') }]],
  use: {
    baseURL: 'http://127.0.0.1:3871',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 30_000,
    navigationTimeout: 60_000,
  },
  projects: [
    { name: 'chromium-desktop', use: { browserName: 'chromium', viewport: { width: 1280, height: 720 } } },
    { name: 'chromium-narrow', use: { browserName: 'chromium', viewport: { width: 375, height: 667 } } },
  ],
  webServer: {
    command: 'bash scripts/test-workspace.sh serve',
    url: 'http://127.0.0.1:3871',
    reuseExistingServer: false,
    timeout: 120_000,
    gracefulShutdown: { signal: 'SIGTERM', timeout: 5_000 },
  },
});
