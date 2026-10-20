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

test('actual resource DT draws its configured rows and columns', async ({ page }) => {
  const { readFileSync } = await import('node:fs');
  const path = await import('node:path');
  const { pathToFileURL } = await import('node:url');
  const directory = path.resolve(process.env.WORKSPACE_ARTIFACTS ?? '.moai/reports/SPEC-WORKSPACE-001/implementation/001/browser', 'resources');
  const receipt = JSON.parse(readFileSync(path.join(directory, 'render.json'), 'utf8')) as {
    table: { rows: number; columns: number; first_label: string; last_label: string };
  };
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(pathToFileURL(path.join(directory, 'actual-table.html')).href);
  await expect(page.getByRole('cell', { name: 'column1: activate to sort column ascending', exact: true }).first()).toBeVisible();
  await expect(page.getByRole('cell', { name: receipt.table.first_label, exact: true })).toBeVisible();
  await expect.poll(() => page.evaluate(() => {
    type TableApi = { rows(): { count(): number }; columns(): { count(): number } };
    type JQuery = { (element: Element): { DataTable(): TableApi }; fn: { dataTable: { tables(): Element[] } } };
    const jquery = (window as unknown as { jQuery: JQuery }).jQuery;
    const table = jquery(jquery.fn.dataTable.tables()[0]).DataTable();
    return { rows: table.rows().count(), columns: table.columns().count() };
  })).toEqual({ rows: receipt.table.rows, columns: receipt.table.columns });
  await page.getByRole('link', { name: String(receipt.table.rows / 10), exact: true }).click();
  await expect(page.getByRole('cell', { name: receipt.table.last_label, exact: true })).toBeVisible();
  await expect(page.getByText('Showing 1,991 to 2,000 of 2,000 entries', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});

test('actual resource GGally network PNG decodes in the browser', async ({ page }) => {
  const path = await import('node:path');
  const { pathToFileURL } = await import('node:url');
  const directory = path.resolve(process.env.WORKSPACE_ARTIFACTS ?? '.moai/reports/SPEC-WORKSPACE-001/implementation/001/browser', 'resources');
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(pathToFileURL(path.join(directory, 'actual-network.html')).href);
  const image = page.getByRole('img', { name: 'Measured enrichment network at 400 nodes and 800 edges' });
  await expect(image).toBeVisible();
  await expect.poll(() => image.evaluate(element => {
    const image = element as HTMLImageElement;
    return { complete: image.complete, width: image.naturalWidth, height: image.naturalHeight };
  })).toEqual({ complete: true, width: 1280, height: 720 });
  expect(errors).toEqual([]);
});
