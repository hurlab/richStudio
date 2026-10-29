import { test, expect, fixturePath, openNavigation } from './fixtures';
import type { BrowserContext, Page, TestInfo } from '@playwright/test';

const resultName = 'clustering-six-terms.tsv';
// Synthetic-only fixture: three overlapping A terms, three overlapping B terms,
// disjoint between groups, with distinct raw and adjusted p-values.
const methods = [
  { value: 'hierarchical', name: 'E2E_Hierarchical' },
  { value: 'david', name: 'E2E_DAVID' },
  { value: 'richR', name: 'E2E_Original_Kappa' },
] as const;
const resultNames = methods.map(method => method.name);
const legacyResultNames = ['Live_Hierarchical', 'Live_DAVID', 'Live_Original_Kappa'];

type HeatmapValue = { term: string; value: number };

async function attach(info: TestInfo, name: string, value: unknown) {
  await info.attach(name, { body: JSON.stringify(value, null, 2), contentType: 'application/json' });
}

async function goToTab(page: Page, tab: string) {
  await openNavigation(page);
  const href = `a[href="#shiny-tab-${tab}"]`;
  const link = page.locator(`.sidebar-menu ${href}`);
  if (!(await link.isVisible())) {
    await page.locator('.sidebar-menu li.treeview', { has: page.locator(href) }).locator(':scope > a').click();
  }
  await expect(link).toBeVisible();
  await link.click();
  if (await page.locator('body.sidebar-open').count()) {
    await page.getByRole('button', { name: /Toggle navigation/ }).click();
    await expect(page.locator('body.sidebar-open')).toHaveCount(0);
    const home = page.locator('.sidebar-menu a[href="#shiny-tab-home_tab"]');
    await expect.poll(async () => {
      const bounds = await home.boundingBox();
      return bounds ? bounds.x + bounds.width : Number.POSITIVE_INFINITY;
    }).toBeLessThanOrEqual(0);
  }
  const pane = page.locator(`#shiny-tab-${tab}`);
  await expect(pane).toHaveClass(/\bactive\b/);
  await expect(pane).toHaveAttribute('aria-hidden', 'false');
}

async function chooseSelectize(page: Page, id: string, value: string) {
  await expect.poll(() => page.evaluate(([selectId, option]) => {
    const select = document.getElementById(selectId) as
      (HTMLElement & { selectize?: { options: Record<string, unknown> } }) | null;
    return Boolean(select?.selectize && Object.prototype.hasOwnProperty.call(select.selectize.options, option));
  }, [id, value] as const)).toBe(true);
  const control = page.locator(`#${id} + .selectize-control`);
  await control.locator('.selectize-input').click();
  await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  await expect(page.locator(`#${id}`)).toHaveValue(value);
}

async function chooseSelectizeMultiple(page: Page, id: string, values: string[]) {
  for (const value of values) {
    await expect.poll(() => page.evaluate(([selectId, option]) => {
      const select = document.getElementById(selectId) as
        (HTMLElement & { selectize?: { options: Record<string, unknown> } }) | null;
      return Boolean(select?.selectize && Object.prototype.hasOwnProperty.call(select.selectize.options, option));
    }, [id, value] as const)).toBe(true);
    const control = page.locator(`#${id} + .selectize-control`);
    await control.locator('.selectize-input').click();
    await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  }
  await expect(page.locator(`#${id}`)).toHaveValues(values);
}

async function uploadSyntheticResults(page: Page) {
  await goToTab(page, 'cluster_upload_tab');
  await page.locator('#cluster_upload-rr_files').setInputFiles(fixturePath('clustering-six-terms.tsv'));
  // The canonical five-column TSV imports directly; no column mapping is required.
  await expect(page.locator('#cluster_upload-imported_results_card')).toContainText(resultName);
}

async function runClustering(page: Page, method: typeof methods[number]) {
  await goToTab(page, 'cluster_tab');
  await page.locator(`input[name="cluster-clustering_method"][value="${method.value}"]`).check();
  await page.locator('#cluster-cluster_name').fill(method.name);
  await page.locator('#cluster-cluster').click();

  const methodInfo = page.locator('#cluster-method_info');
  await expect(methodInfo).toContainText(`Method: ${method.value}`, { timeout: 60_000 });
  const summary = page.locator('#cluster-cluster_summary_table');
  await expect(summary.locator('tbody tr')).toHaveCount(2);
  await expect(summary).toContainText('A1');
  await expect(summary).toContainText('B1');
  await expect(summary).toContainText('3');
}

async function readHeatmapValues(page: Page): Promise<HeatmapValue[] | null> {
  return page.locator('#clus_visualize-clusdf_hmap').evaluate(element => {
    const root = element as HTMLElement & { data?: unknown[] };
    const plot = (root.classList.contains('js-plotly-plot')
      ? root
      : root.querySelector('.js-plotly-plot')) as (HTMLElement & {
        data?: Array<{ type?: string; y?: unknown[]; z?: unknown[][] | unknown[] }>;
      }) | null;
    const trace = plot?.data?.find(item => item.type === 'heatmap' && Array.isArray(item.y) && Array.isArray(item.z));
    if (!trace || !Array.isArray(trace.y) || !Array.isArray(trace.z)) return null;

    const terms = trace.y.map(String);
    const matrix = trace.z as unknown[];
    const values = terms.map((term, index) => {
      let value: unknown;
      if (Array.isArray(matrix[index])) value = (matrix[index] as unknown[])[0];
      else if (Array.isArray(matrix[0]) && (matrix[0] as unknown[]).length === terms.length) {
        value = (matrix[0] as unknown[])[index];
      } else value = matrix[index];
      return { term, value: Number(value) };
    });
    if (values.some(item => !Number.isFinite(item.value))) return null;
    return values.sort((a, b) => a.term.localeCompare(b.term)).map(item => ({
      term: item.term,
      value: Math.round(item.value * 10000) / 10000,
    }));
  });
}

async function waitForHeatmap(page: Page, expected: HeatmapValue[]) {
  await expect.poll(() => readHeatmapValues(page)).toEqual(expected);
}

async function uploadComplete(page: Page, id: string) {
  const fileInput = page.locator(`#${id}`);
  await expect(fileInput).toBeAttached();
  await expect.poll(() => fileInput.evaluate(element =>
    element.closest('.shiny-input-container')?.querySelector('.progress-bar')?.textContent?.trim() === 'Upload complete'),
  { timeout: 30_000 }).toBe(true);
}

async function loadRds(page: Page, file: string) {
  await goToTab(page, 'save_tab');
  await page.locator('#save-load_session_file').setInputFiles(file);
  await uploadComplete(page, 'save-load_session_file');
  await page.locator('#save-load_session').click();
}

async function expectRestoredResults(page: Page, names: string[]) {
  const summary = page.locator('#save-clus_summary');
  await expect(summary).toContainText(`${names.length} clustering result(s)`);
  for (const name of names) await expect(summary).toContainText(name);

  await goToTab(page, 'cluster_upload_tab');
  const uploadedFiles = page.locator('#cluster_upload-list_box');
  await uploadedFiles.locator('a[data-toggle="tab"][data-value="Cluster Results"]').click();
  const uploadTable = page.locator('#cluster_upload-clus_list_table');
  await expect(uploadTable.locator('tbody tr')).toHaveCount(names.length);
  for (const name of names) await expect(uploadTable).toContainText(name);

  await goToTab(page, 'clus_visualize_tab');
  await expect(page.locator('#clus_visualize-cluslist_box')).toBeVisible();
  const visualizationTable = page.locator('#clus_visualize-clus_list_table');
  await expect(visualizationTable.locator('tbody tr')).toHaveCount(names.length);
  for (const name of names) await expect(visualizationTable).toContainText(name);
}

test('clustering plot controls refresh, session restore rebuilds tracking lists, and empty heatmap state is truthful', async ({ page }, info) => {
  test.setTimeout(180_000);
  const pageErrors: string[] = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  await uploadSyntheticResults(page);
  await goToTab(page, 'cluster_tab');
  await chooseSelectizeMultiple(page, 'cluster-selected_rrs', [resultName]);

  for (const method of methods) await runClustering(page, method);

  await goToTab(page, 'clus_visualize_tab');
  await chooseSelectize(page, 'clus_visualize-clusdf_select', methods[0].name);
  const placeholder = page.locator('#clus_visualize-clusdf_hmap_empty');
  await waitForHeatmap(page, [
    { term: 'cluster:1', value: 3.699 },
    { term: 'cluster:2', value: 3.301 },
  ]);
  const initialPadjMean = await readHeatmapValues(page);
  await expect(page.locator('#clus_visualize-clusdf_hmap .main-svg').first()).toBeVisible();
  await expect(placeholder).toBeHidden();

  await chooseSelectize(page, 'clus_visualize-big_value_type', 'Pvalue');
  await waitForHeatmap(page, [
    { term: 'cluster:1', value: 4.699 },
    { term: 'cluster:2', value: 4.301 },
  ]);
  const afterPvalueMean = await readHeatmapValues(page);
  // Changing the aggregation must update the existing plot without reselecting data.
  await chooseSelectize(page, 'clus_visualize-value_by', 'min');
  await waitForHeatmap(page, [
    { term: 'cluster:1', value: 5 },
    { term: 'cluster:2', value: 4.3979 },
  ]);
  const afterPvalueMin = await readHeatmapValues(page);
  await expect(placeholder).toBeHidden();

  await goToTab(page, 'save_tab');
  await page.locator('#save-session_name').fill('clustering-roundtrip');
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator('#save-download_session').click(),
  ]);
  const savedSession = info.outputPath('clustering-roundtrip.rds');
  await download.saveAs(savedSession);
  await info.attach('clustering-roundtrip.rds', { path: savedSession, contentType: 'application/x-r-rds' });

  const browser = page.context().browser();
  if (!browser) throw new Error('Playwright browser context is unavailable');
  const extraContexts: BrowserContext[] = [];
  try {
    const restoredContext = await browser.newContext({ viewport: page.viewportSize(), acceptDownloads: true });
    extraContexts.push(restoredContext);
    const restoredPage = await restoredContext.newPage();
    restoredPage.on('pageerror', error => pageErrors.push(`restored: ${error.message}`));
    await restoredPage.goto(new URL('/', page.url()).toString());
    await expect(restoredPage.locator('#loading-overlay')).toBeHidden();
    await goToTab(restoredPage, 'save_tab');
    await expect(restoredPage.locator('#save-clus_summary')).toContainText('No clustering results');
    await goToTab(restoredPage, 'clus_visualize_tab');
    await expect(restoredPage.locator('#clus_visualize-clusdf_hmap_empty')).toBeVisible();
    await expect(restoredPage.locator('#clus_visualize-clusdf_hmap .main-svg').first()).toBeHidden();

    await loadRds(restoredPage, savedSession);
    await expectRestoredResults(restoredPage, resultNames);

    await goToTab(restoredPage, 'update_tab');
    await chooseSelectizeMultiple(restoredPage, 'update-remove_clus_select', resultNames);
    await restoredPage.locator('#update-remove_clus_btn').click();
    await restoredPage.getByRole('button', { name: 'Remove', exact: true }).last().click();
    await goToTab(restoredPage, 'save_tab');
    await expect(restoredPage.locator('#save-clus_summary')).toContainText('No clustering results');
    await goToTab(restoredPage, 'clus_visualize_tab');
    await expect(restoredPage.locator('#clus_visualize-clusdf_hmap_empty')).toBeVisible();
    await expect(restoredPage.locator('#clus_visualize-clusdf_hmap .main-svg').first()).toBeHidden();

    // This small v1.0 RDS was saved through the deployed 149bcfd browser flow
    // using only the synthetic six-term fixture. It predates tracking metadata.
    const legacyContext = await browser.newContext({ viewport: page.viewportSize(), acceptDownloads: true });
    extraContexts.push(legacyContext);
    const legacyPage = await legacyContext.newPage();
    legacyPage.on('pageerror', error => pageErrors.push(`legacy: ${error.message}`));
    await legacyPage.goto(new URL('/', page.url()).toString());
    await expect(legacyPage.locator('#loading-overlay')).toBeHidden();
    await goToTab(legacyPage, 'save_tab');
    await expect(legacyPage.locator('#save-clus_summary')).toContainText('No clustering results');
    await loadRds(legacyPage, fixturePath('legacy-clustering-session-v1.rds'));
    await expectRestoredResults(legacyPage, legacyResultNames);

    await attach(info, 'clustering-roundtrip-evidence', {
      project: info.project.name,
      fixture: resultName,
      methods: resultNames,
      initialPadjMean,
      afterPvalueMean,
      afterPvalueMin,
      restoredSummary: await restoredPage.locator('#save-clus_summary').innerText(),
      legacyNames: legacyResultNames,
      pageErrors,
    });
    expect(pageErrors).toEqual([]);
  } finally {
    await Promise.all(extraContexts.map(context => context.close()));
  }
});
