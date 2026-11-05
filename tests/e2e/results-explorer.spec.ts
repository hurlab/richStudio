import { test, expect } from './fixtures';
import type { Page, TestInfo } from '@playwright/test';
import fs from 'node:fs';

// SPEC-WS-008 unified results explorer. Fixtures are built in memory and submitted
// through the real uploader; bundled demo results stand in for prior imported data.
// No enrichment or clustering is executed, so every scenario here is an imported
// result without clusters. Both Playwright projects run every test.

type Payload = { name: string; mimeType: string; buffer: Buffer };

const tsv = (name: string, rows: string[][]): Payload => ({
  name,
  mimeType: 'text/tab-separated-values',
  buffer: Buffer.from(rows.map(row => row.join('\t')).join('\n') + '\n', 'utf8'),
});

// Two terms share the label "same" but have different IDs; values need full precision.
const dupLabels = tsv('dup-labels.tsv', [
  ['Term', 'Annot', 'GeneID', 'Pvalue', 'Padj', 'Significant', 'Annotated', 'ProviderExtra'],
  ['same', 'GO:1', 'g1,g2,g3', '1.2345678901234567e-12', '0.30000000000000004', '3', '10', 'keep-1'],
  ['same', 'GO:2', 'g2,g4', '0.001', '0.01', '2', '12', 'keep-2'],
  ['other', 'GO:3', 'g5', '0.2', '0.5', '1', '8', 'keep-3'],
]);

const ns = 'rr_visualize';

async function attach(info: TestInfo, name: string, value: unknown) {
  await info.attach(name, { body: JSON.stringify(value, null, 2), contentType: 'application/json' });
}

async function chooseSelectize(page: Page, id: string, value: string) {
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

async function openExplorer(page: Page) {
  await page.locator('#home-load_demo').click();
  await expectTab(page, 'rr_visualize_tab');
  await expect(page.locator(`#${ns}-ex_summary`)).toContainText('Result summary');
  // The result chooser sits in the collapsed Figure settings (SPEC-WS-013 M8).
  await page.locator('#shiny-tab-rr_visualize_tab details.rs-figure-settings').evaluate(d => { (d as HTMLDetailsElement).open = true; });
  // On a narrow screen the figure is a closed disclosure above the table.
  {
    const toggle = page.locator('#shiny-tab-rr_visualize_tab label.rs-figure-toggle');
    if (await toggle.isVisible() && !(await toggle.locator('input').isChecked())) await toggle.click();
  }
  // The result summary sits in a Details disclosure.
  await page.locator('#shiny-tab-rr_visualize_tab details.rs-details').evaluate(d => { (d as HTMLDetailsElement).open = true; });
}

async function importDupLabels(page: Page) {
  await openExplorer(page);
  await page.locator(`#${ns}-rr_files`).setInputFiles(dupLabels);
  await chooseSelectize(page, `${ns}-ex_result`, 'dup-labels.tsv');
  await expect(page.locator(`#${ns}-ex_summary`)).toContainText('dup-labels.tsv');
  await expect(page.locator(`#${ns}-ex_table tbody tr`)).toHaveCount(3);
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (c === '"') quoted = false;
      else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(cell); cell = ''; }
    else if (c === '\n') { row.push(cell); rows.push(row); row = []; cell = ''; }
    else if (c !== '\r') cell += c;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  return rows;
}

async function downloadExact(page: Page): Promise<string> {
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator(`#${ns}-ex_download_exact`).click(),
  ]);
  const path = await download.path();
  return fs.readFileSync(path, 'utf8');
}

// The explorer table is a server-side DT; sorting happens on the client, so a header
// click reorders rows without any new server value.
async function sortBy(page: Page, header: string) {
  const th = page.locator(`#${ns}-ex_table .dataTables_scrollHead th`).filter({ hasText: header }).first();
  await th.click();
}

const tableRow = (page: Page, id: string) =>
  page.locator(`#${ns}-ex_table tbody tr`).filter({ hasText: id });

// Reads the figure straight from the rendered Plotly graph: which point carries the
// emphasis and which label it has.
async function figureState(page: Page) {
  return page.evaluate((id) => {
    const gd = document.getElementById(`${id}-ex_plot`) as unknown as {
      data?: Array<{ y: string[]; marker: { line: { width: number[] }; size: number[] } }>;
    } | null;
    const trace = gd?.data?.[0];
    if (!trace) return null;
    const widths = ([] as number[]).concat(trace.marker.line.width);
    const top = Math.max(...widths);
    const emphasised = widths.map((w, i) => (w === top && top > Math.min(...widths) ? i : -1)).filter(i => i >= 0);
    return { labels: trace.y, emphasised: emphasised.map(i => trace.y[i]) };
  }, ns);
}

test('REQ-001 REQ-005 AC-004 imported enrichment without clusters opens result-first, makes a figure and exports exact values', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await importDupLabels(page);

  const summary = page.locator(`#${ns}-ex_summary`);
  await expect(summary).toContainText('Terms');
  await expect(summary).toContainText('3');
  await expect(summary).toContainText('Not recorded');
  const actions = page.locator(`#${ns}-ex_actions`);
  // The table and the figure are the page itself, so only the cluster action is offered (M8).
  await expect(actions.getByRole('button', { name: 'Cluster these results' })).toBeEnabled();
  await expect(actions.getByRole('button', { name: 'View results' })).toHaveCount(0);
  const rerun = actions.getByRole('button', { name: 'Run again' });
  await expect(rerun).toBeDisabled();
  await expect(actions).toContainText('No recorded run for this result');

  // Exact values and provider columns leave the app unchanged.
  const csv = parseCsv(await downloadExact(page));
  expect(csv[0]).toEqual(['Term', 'Annot', 'GeneID', 'Pvalue', 'Padj', 'Significant', 'Annotated', 'ProviderExtra']);
  expect(csv).toHaveLength(4);
  expect(Number(csv[1][3])).toBe(1.2345678901234567e-12);
  expect(Number(csv[1][4])).toBe(0.30000000000000004);
  expect(csv.slice(1).map(r => r[7])).toEqual(['keep-1', 'keep-2', 'keep-3']);
  expect(csv.slice(1).map(r => r[1])).toEqual(['GO:1', 'GO:2', 'GO:3']);
  // The table shows 3 significant digits only for display.
  await expect(tableRow(page, 'GO:1')).toContainText('1.23e-12');

  // A figure is available without clustering through the existing figure view.
  await page.getByRole('radio', { name: 'Bar', exact: true }).check();
  await expect(page.locator(`#${ns}-select_bar`)).toHaveValue('dup-labels.tsv');
  await expect(page.locator(`#${ns}-barplot .main-svg`).first()).toBeVisible();

  // The linked terms figure also draws from the imported result.
  await page.getByRole('radio', { name: 'Terms', exact: true }).check();
  await expect(page.locator(`#${ns}-ex_plot .main-svg`).first()).toBeVisible();
  await attach(info, 'imported-without-clusters', { project: info.project.name, errors });
  expect(errors).toEqual([]);
});

test('REQ-002 AC-001 AC-002 selection follows the source term through sorting, table, panel and figure', async ({ page }, info) => {
  await importDupLabels(page);
  const panel = page.locator(`#${ns}-ex_selected`);
  await expect(panel).toContainText('No term selected');

  // Sort first, then select: the identity comes from the source row, not its position.
  await sortBy(page, 'Adjusted p-value');
  await sortBy(page, 'Adjusted p-value');
  await tableRow(page, 'GO:2').locator('td').first().click();
  await expect(panel).toContainText('GO:2');
  await expect(panel).toContainText('g2, g4');
  await expect(panel).not.toContainText('GO:1');
  await expect(page.locator(`#${ns}-ex_table tbody tr.selected`)).toHaveCount(1);
  await expect(page.locator(`#${ns}-ex_table tbody tr.selected`)).toContainText('GO:2');
  await expect.poll(async () => (await figureState(page))?.emphasised).toEqual(['same [GO:2]']);

  // The identical label "same" with another ID is a different identity.
  await sortBy(page, 'Adjusted p-value');
  await expect(page.locator(`#${ns}-ex_table tbody tr.selected`)).toContainText('GO:2');
  await expect(panel).toContainText('GO:2');
  await tableRow(page, 'GO:1').locator('td').first().click();
  await expect(panel).toContainText('GO:1');
  await expect(panel).toContainText('g1, g2, g3');
  await expect(panel).not.toContainText('GO:2');
  await expect.poll(async () => (await figureState(page))?.emphasised).toEqual(['same [GO:1]']);

  // Clicking a figure point selects the same term in the table and the panel.
  const labels = (await figureState(page))?.labels ?? [];
  const index = labels.indexOf('other [GO:3]');
  expect(index).toBeGreaterThanOrEqual(0);
  const point = page.locator(`#${ns}-ex_plot .scatterlayer .points path`).nth(index);
  // A load notification can sit over the figure; dismiss it before clicking the marker.
  await page.evaluate(() => document.querySelectorAll('.shiny-notification').forEach(n => n.remove()));
  await point.scrollIntoViewIfNeeded();
  const box = await point.boundingBox();
  expect(box).not.toBeNull();
  const x = (box?.x ?? 0) + (box?.width ?? 0) / 2;
  const y = (box?.y ?? 0) + (box?.height ?? 0) / 2;
  // Plotly resolves a click from the last hover, so move onto the marker first.
  await page.mouse.move(x, y);
  await page.mouse.click(x, y);
  await expect(panel).toContainText('GO:3');
  await expect(page.locator(`#${ns}-ex_table tbody tr.selected`)).toContainText('GO:3');
  await expect.poll(async () => (await figureState(page))?.emphasised).toEqual(['other [GO:3]']);

  await page.locator(`#${ns}-ex_clear`).click();
  await expect(panel).toContainText('No term selected');
  await attach(info, 'linked-selection', { project: info.project.name });
});

test('REQ-003 REQ-004 AC-002 AC-003 comparison states are textual, unknown context is unsupported and raw values stay', async ({ page }, info) => {
  await openExplorer(page);
  await chooseSelectize(page, `${ns}-ex_result`, 'go1');
  await expect(page.locator(`#${ns}-ex_table tbody tr`).first()).toBeVisible();
  const before = await downloadExact(page);
  const summaryCue = (await page.locator(`#${ns}-ex_summary .rs-workspace-dataset`).first().innerText()).trim();
  expect(summaryCue).toMatch(/D-[A-Z]/);

  await page.locator(`#${ns}-ex_table tbody tr`).first().locator('td').first().click();
  const compare = page.locator(`#${ns}-ex_compare_table`);
  await expect(compare).toContainText('Selected term across datasets');
  await expect(compare).toContainText('Recorded value');
  // No species, key type or annotation is recorded for imported demo results.
  await expect(compare).toContainText('Comparison unsupported');
  await expect(compare).toContainText('not recorded for both datasets');
  await expect(compare.locator('tbody tr')).toHaveCount(3);

  // The dataset cue (code, name, ID) is the same in the summary and the comparison.
  const code = summaryCue.match(/D-[A-Z]/)![0];
  await expect(compare.locator('.rs-workspace-dataset').filter({ hasText: code })).toHaveCount(1);
  await chooseSelectize(page, `${ns}-ex_result`, 'go2');
  await expect(page.locator(`#${ns}-ex_summary`)).toContainText('go2');
  await chooseSelectize(page, `${ns}-ex_result`, 'go1');
  await expect(page.locator(`#${ns}-ex_summary`)).toContainText('go1');
  const again = (await page.locator(`#${ns}-ex_summary .rs-workspace-dataset`).first().innerText()).trim();
  expect(again).toBe(summaryCue);

  // Comparing and selecting never touched the stored values.
  expect(await downloadExact(page)).toBe(before);
  await attach(info, 'comparison', { project: info.project.name, summaryCue });
});
