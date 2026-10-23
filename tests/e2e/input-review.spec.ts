import { test, expect } from './fixtures';
import type { Page, TestInfo } from '@playwright/test';

// SPEC-WS-004 intake review. Fixtures are built in memory and submitted through the
// real file inputs; bundled demo results stand in for prior data. No enrichment or
// clustering is executed: the DEG review card is checked before Run.

type Payload = { name: string; mimeType: string; buffer: Buffer };

const tsv = (name: string, rows: string[][]): Payload => ({
  name,
  mimeType: 'text/tab-separated-values',
  buffer: Buffer.from(rows.map(row => row.join('\t')).join('\n') + '\n', 'utf8'),
});

const validResult = tsv('valid-result.tsv', [
  ['Term', 'Annot', 'GeneID', 'Pvalue', 'Padj', 'Significant', 'Annotated', 'ProviderExtra'],
  ['Alpha term', 'A1', 'g1,g2,g3', '0.001', '0.01', '3', '10', 'kept-a'],
  ['Beta term', 'B1', 'g4,g5,g6', '0.002', '0.02', '3', '12', 'kept-b'],
]);
const malformedResult = tsv('malformed-result.tsv', [
  ['Term', 'Annot', 'GeneID', 'Pvalue', 'Padj'],
  ['Alpha term', 'A1', 'g1,g2', '1.5', '0.01'],
  ['', 'B1', 'g3', '0.02', '0.02'],
]);
const ambiguousResult = tsv('ambiguous-result.tsv', [
  ['Term', 'Annot', 'GeneID', 'FDR'],
  ['Alpha term', 'A1', 'g1,g2', '0.01'],
  ['Beta term', 'B1', 'g3', '0.2'],
]);
const hostileLabel = '<img src=x onerror=alert(1)>.csv';
const hostileDeg: Payload = {
  name: hostileLabel,
  mimeType: 'text/csv',
  buffer: Buffer.from('gene,padj\ng1,0.01\ng2,0.2\n', 'utf8'),
};
const degList: Payload = {
  name: 'review-genes.csv',
  mimeType: 'text/csv',
  buffer: Buffer.from('gene,padj,pvalue\ng1,0.001,0.5\ng2,0.02,0.01\ng3,0.3,0.02\n', 'utf8'),
};

async function attach(info: TestInfo, name: string, value: unknown) {
  await info.attach(name, { body: JSON.stringify(value, null, 2), contentType: 'application/json' });
}

async function chooseSelectize(page: Page, id: string, value: string) {
  // An upload repopulates the choices and shiny rebuilds the selectize control,
  // closing any dropdown opened before the option arrived; wait for the option first.
  await expect.poll(() => page.evaluate(([selectId, option]) => {
    const select = document.getElementById(selectId) as (HTMLElement & { selectize?: { options: Record<string, unknown> } }) | null;
    return Boolean(select?.selectize && Object.prototype.hasOwnProperty.call(select.selectize.options, option));
  }, [id, value] as const)).toBe(true);
  const control = page.locator(`#${id} + .selectize-control`);
  await control.locator('.selectize-input').click();
  await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  await expect(page.locator(`#${id}`)).toHaveValue(value);
}

async function expectTab(page: Page, tab: string) {
  const pane = page.locator(`#shiny-tab-${tab}`);
  await expect(pane).toHaveClass(/\bactive\b/);
  await expect(pane).toHaveAttribute('aria-hidden', 'false');
}

// Valid, malformed and ambiguous files through one uploader; prior data must survive.
async function exerciseUploader(page: Page, ns: string, prior: string[]) {
  const card = page.locator(`#${ns}-imported_results_card`);
  const status = page.locator(`#${ns}-intake_status`);
  const pending = page.locator(`#${ns}-intake_pending`);
  for (const label of prior) await expect(card).toContainText(label);

  await page.locator(`#${ns}-rr_files`).setInputFiles(validResult);
  await expect(card).toContainText('valid-result.tsv');

  await page.locator(`#${ns}-rr_files`).setInputFiles(malformedResult);
  await expect(status).toContainText('Column Pvalue has values outside [0, 1]');
  await expect(status).toContainText('Term is blank');
  await expect(card).not.toContainText('malformed-result.tsv');
  for (const label of [...prior, 'valid-result.tsv']) await expect(card).toContainText(label);

  await page.locator(`#${ns}-rr_files`).setInputFiles(ambiguousResult);
  await expect(pending).toContainText('ambiguous-result.tsv');
  await expect(card).not.toContainText('ambiguous-result.tsv');
  await chooseSelectize(page, `${ns}-intake_map_Padj`, 'FDR');
  await page.locator(`#${ns}-intake_import`).click();
  await expect(card).toContainText('ambiguous-result.tsv');
  await expect(card).toContainText('Mapped from FDR');
  await expect(card).toContainText('Raw p-values: not provided. Hierarchical clustering requires raw p-values (column Pvalue).');
  for (const label of [...prior, 'valid-result.tsv']) await expect(card).toContainText(label);
}

test('AC-003 cluster uploader imports valid, refuses malformed and confirms ambiguous files', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.locator('#home-load_demo').click();
  await expectTab(page, 'rr_visualize_tab');
  await page.locator('a[href="#shiny-tab-cluster_upload_tab"]').evaluate(link => (link as HTMLElement).click());
  await expectTab(page, 'cluster_upload_tab');
  await exerciseUploader(page, 'cluster_upload', ['go1', 'go2', 'kegg1']);
  await attach(info, 'cluster-uploader', { project: info.project.name, errors });
  expect(errors).toEqual([]);
});

test('AC-002 AC-003 direct-plot uploader validates files and plots without enrichment or clustering', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.locator('#home-load_demo').click();
  await expectTab(page, 'rr_visualize_tab');
  await exerciseUploader(page, 'rr_visualize', ['go1', 'go2', 'kegg1']);
  await page.locator('#shiny-tab-rr_visualize_tab a[data-toggle="tab"][data-value="Bar Plot"]').click();
  await chooseSelectize(page, 'rr_visualize-select_bar', 'valid-result.tsv');
  await expect(page.locator('#rr_visualize-barplot .main-svg').first()).toBeVisible();
  await attach(info, 'direct-plot-uploader', { project: info.project.name, errors });
  expect(errors).toEqual([]);
});

test('REQ-001 REQ-002 DEG preview and commit are labelled separately and the card shows before Run', async ({ page }, info) => {
  await page.locator('#home-upload_gene_lists').click();
  await expectTab(page, 'enrich_tab');
  const pane = page.locator('#shiny-tab-enrich_tab');
  const box = await pane.boundingBox();
  await attach(info, 'enrich-tab-box', { project: info.project.name, box });
  if (info.project.name === 'chromium-desktop') {
    expect(box).not.toBeNull();
    expect((box?.width ?? 0) * (box?.height ?? 0)).toBeGreaterThan(0);
  } else {
    await expect(pane.locator('*:visible').first()).toBeVisible();
  }
  await page.locator('#enrich-deg_files').setInputFiles(degList);
  await chooseSelectize(page, 'enrich-deg_table_select', 'review-genes.csv');
  await expect(page.getByText('Preview — not committed', { exact: true })).toBeVisible();
  await expect(page.locator('#enrich-review_preview_ui')).toContainText('padj < 0.05 (adjusted)');
  await expect(page.getByText('Default cutoff (used for gene lists without a committed revision)')).toBeVisible();
  await chooseSelectize(page, 'enrich-degs_to_enrich', 'review-genes.csv');
  const card = page.locator('#enrich-review_card');
  await expect(card).toContainText('Default rule (not customized)');
  await expect(card).toContainText('Mapped / unmapped: Not available (not measured)');
  await page.locator('#enrich-review_commit').click();
  await expect(card).toContainText('Committed revision 1');
  await expect(card).toContainText('Submitted genes: 2');
});

test('REQ-003 a hostile upload label renders as text and injects no element', async ({ page }, info) => {
  const dialogs: string[] = [];
  page.on('dialog', async dialog => {
    dialogs.push(dialog.message());
    await dialog.dismiss();
  });
  await page.locator('#home-upload_gene_lists').click();
  await expectTab(page, 'enrich_tab');
  await page.locator('#enrich-deg_files').setInputFiles(hostileDeg);
  await chooseSelectize(page, 'enrich-degs_to_enrich', hostileLabel);
  const card = page.locator('#enrich-review_card');
  await expect(card).toContainText(hostileLabel);
  await expect(page.locator('img[src="x"]')).toHaveCount(0);
  await attach(info, 'hostile-label', { project: info.project.name, dialogs });
  expect(dialogs).toEqual([]);
});
