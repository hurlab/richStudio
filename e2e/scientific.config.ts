import { defineConfig } from '@playwright/test';
import path from 'node:path';

const artifacts = process.env.SCIENTIFIC_E2E_ARTIFACTS ?? path.resolve(__dirname, '../.moai/reports/scientific-heatmap-adoption/e2e');
const port = Number(process.env.SCIENTIFIC_E2E_PORT ?? '3887');

export default defineConfig({
  testDir: path.resolve(__dirname, '../tests/e2e'),
  testMatch: 'scientific-heatmaps.spec.ts',
  outputDir: path.join(artifacts, 'browser-artifacts'),
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['line'], ['json', { outputFile: path.join(artifacts, 'browser-results.json') }]],
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    actionTimeout: 30_000,
    navigationTimeout: 60_000,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    acceptDownloads: true,
  },
  projects: [
    { name: 'chromium-desktop', use: { browserName: 'chromium', viewport: { width: 1440, height: 1000 } } },
    { name: 'chromium-narrow', use: { browserName: 'chromium', viewport: { width: 390, height: 844 } } },
  ],
  webServer: {
    command: 'bash e2e/serve-scientific.sh',
    cwd: path.resolve(__dirname, '..'),
    url: `http://127.0.0.1:${port}`,
    reuseExistingServer: false,
    timeout: 120_000,
    gracefulShutdown: { signal: 'SIGTERM', timeout: 10_000 },
  },
});
