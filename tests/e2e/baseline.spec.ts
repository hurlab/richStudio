import { test, expect, fixturePath, openNavigation } from './fixtures';

test('installed workspace imports synthetic enrichment without analysis', async ({ page }) => {
  await openNavigation(page);
  await page.getByRole('link', { name: /\bClustering\b/ }).click();
  await openNavigation(page);
  await page.getByRole('link', { name: /Upload files$/ }).click();
  const upload = page.getByRole('tabpanel').filter({ has: page.getByText('Upload enrichment results for clustering', { exact: true }) });
  await upload.getByLabel('Select files', { exact: true }).setInputFiles(fixturePath('imported-results.tsv'));
  await expect(upload.getByRole('cell', { name: 'imported-results.tsv', exact: true })).toBeVisible();
  await expect(upload.getByLabel('Select enrichment result', { exact: true })).toBeVisible();
  await expect(upload.getByRole('cell', { name: 'retained-a', exact: true })).toBeVisible();
});

test('negative assertion canary reports failure when explicitly injected', async ({ page }) => {
  if (process.env.WORKSPACE_NEGATIVE_ASSERTION === '1') {
    await expect(page.getByRole('heading', { name: 'INTENTIONALLY BROKEN FIXTURE EXPECTATION' })).toBeVisible({ timeout: 1_000 });
  } else {
    await expect(page.getByRole('heading', { name: 'Quick Start' })).toBeVisible();
  }
});
