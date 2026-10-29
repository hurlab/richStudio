import { test, expect, fixturePath, openNavigation } from './fixtures';
import type { BrowserContext, Page, TestInfo } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

type Cell = { x: string; y: string; z: number | null };
type Heatmap = { name?: string; cells: Cell[]; text: unknown; ticktext: unknown; tickvals: unknown };
const fixtureResult = 'Scientific_fixture';
const syntheticInputs = ['clustering-six-terms.tsv', 'clustering-missing-values.tsv'];
const methods = [
  { value: 'hierarchical', name: 'Scientific_Hierarchical' },
  { value: 'david', name: 'Scientific_DAVID' },
] as const;

async function goToTab(page: Page, tab: string) {
  await openNavigation(page);
  const selector = `a[href="#shiny-tab-${tab}"]`;
  const link = page.locator(`.sidebar-menu ${selector}`);
  if (!(await link.isVisible())) {
    await page.locator('.sidebar-menu li.treeview', { has: page.locator(selector) }).locator(':scope > a').click();
  }
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
  await expect(page.locator(`#shiny-tab-${tab}`)).toHaveClass(/\bactive\b/);
}

async function choose(page: Page, id: string, values: string[]) {
  await expect.poll(() => page.locator(`#${id}`).evaluate((element, options) => {
    const select = element as HTMLSelectElement & { selectize?: { options: Record<string, unknown> } };
    return options.every(option => Boolean(select.selectize?.options[option]));
  }, values), { timeout: 60_000 }).toBe(true);
  // Replace previous selections through the actual keyboard control.
  const multiple = await page.locator(`#${id}`).evaluate(element => (element as HTMLSelectElement).multiple);
  if (multiple) {
    const input = page.locator(`#${id} + .selectize-control .selectize-input input`);
    await input.click();
    await input.press('ControlOrMeta+A');
    await input.press('Backspace');
    await expect(page.locator(`#${id}`)).toHaveValues([]);
  }
  for (const value of values) {
    const control = page.locator(`#${id} + .selectize-control`);
    await control.locator('.selectize-input').click();
    await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  }
  if (multiple) await expect(page.locator(`#${id}`)).toHaveValues(values);
  else await expect(page.locator(`#${id}`)).toHaveValue(values[0]);
}

async function heatmaps(page: Page, selector = '#clus_visualize-clusdf_hmap'): Promise<Heatmap[]> {
  return page.locator(selector).evaluate(element => {
    type Trace = { type?: string; name?: string; x?: unknown[]; y?: unknown[]; z?: unknown[]; text?: unknown };
    const plot = (element.classList.contains('js-plotly-plot') ? element : element.querySelector('.js-plotly-plot')) as
      (HTMLElement & { data?: Trace[]; layout?: { yaxis?: { ticktext?: unknown; tickvals?: unknown } } }) | null;
    return (plot?.data ?? []).filter(trace => trace.type === 'heatmap').map(trace => {
      const x = trace.x ?? [];
      const y = trace.y ?? [];
      const z = trace.z ?? [];
      const cells: Array<{ x: string; y: string; z: number | null }> = [];
      if (Array.isArray(z[0])) {
        for (let row = 0; row < y.length; row++) {
          for (let column = 0; column < x.length; column++) {
            const value = (z[row] as unknown[])[column];
            cells.push({ x: String(x[column]), y: String(y[row]), z: typeof value === 'number' ? value : null });
          }
        }
      } else {
        for (let index = 0; index < z.length; index++) {
          const value = z[index];
          cells.push({ x: String(x[index]), y: String(y[index]), z: typeof value === 'number' ? value : null });
        }
      }
      return { name: trace.name, cells, text: trace.text,
        ticktext: plot?.layout?.yaxis?.ticktext, tickvals: plot?.layout?.yaxis?.tickvals };
    });
  });
}

function mainTrace(traces: Heatmap[]): Heatmap | undefined {
  // Values are the heatmap with a nonzero p-value transform; a missing-cell
  // background layer, if present, is not the quantitative trace.
  return traces.find(trace => trace.cells.some(cell => typeof cell.z === 'number' && cell.z > 1));
}

function assertUniqueCells(trace: Heatmap) {
  const keys = trace.cells.map(cell => `${cell.x}\u0000${cell.y}`);
  expect(new Set(keys).size).toBe(keys.length);
}

async function selectResultTrace(page: Page, name: string) {
  await choose(page, 'clus_visualize-clusdf_select', [name]);
  const row = page.locator('#clus_visualize-clus_list_table tbody tr').filter({ hasText: name });
  await expect(row).toHaveCount(1);
  const values = await row.locator('td').allTextContents();
  const nameIndex = values.findIndex(value => value.trim() === name);
  const clusters = Number(values[nameIndex + 2]);
  expect(nameIndex).toBeGreaterThanOrEqual(0);
  expect(Number.isInteger(clusters) && clusters > 0).toBe(true);
  // Keep the accepted frame together with the selection and count checks,
  // so a reactive selection reset cannot pass during a transient render.
  let captured: Heatmap[] = [];
  let previous = '';
  let stableFrames = 0;
  const observations: Array<{ selected: string; clusters: number; recalculating: boolean }> = [];
  await expect.poll(async () => {
    const selected = await page.locator('#clus_visualize-clusdf_select').inputValue();
    const recalculating = await page.locator('#clus_visualize-clusdf_hmap').evaluate(element =>
      element.classList.contains('recalculating'));
    const traces = await heatmaps(page);
    const trace = mainTrace(traces);
    const actualClusters = trace ? new Set(trace.cells.map(cell => cell.y)).size : 0;
    observations.push({ selected, clusters: actualClusters, recalculating });
    const signature = JSON.stringify(traces);
    if (selected === name && actualClusters === clusters && !recalculating) {
      stableFrames = signature === previous ? stableFrames + 1 : 1;
      captured = traces;
    } else stableFrames = 0;
    previous = signature;
    return stableFrames >= 3;
  }, { timeout: 60_000, intervals: [100, 250, 500] }).toBe(true).finally(() => {
    const transitions = observations.filter((value, index, all) =>
      index === 0 || JSON.stringify(value) !== JSON.stringify(all[index - 1]));
    console.log('TRACE_SELECTION', JSON.stringify({ name, expectedClusters: clusters,
      rowValues: values, framesObserved: observations.length, transitions }));
  });
  return captured;
}

async function saveEvidence(info: TestInfo, name: string, value: unknown) {
  const target = info.outputPath(`${name}.json`);
  fs.writeFileSync(target, JSON.stringify(value, null, 2));
  await info.attach(name, { path: target, contentType: 'application/json' });
}

async function boundaryPixels(page: Page, info: TestInfo) {
  const graph = page.locator('#clus_visualize-clusdf_hmap');
  await graph.scrollIntoViewIfNeeded();
  const points = await graph.evaluate(element => {
    type Axis = { _categories: string[]; _offset: number; l2p: (value: number) => number };
    const plot = (element.classList.contains('js-plotly-plot') ? element : element.querySelector('.js-plotly-plot')) as
      HTMLElement & { _fullLayout: { xaxis: Axis; yaxis: Axis } };
    const box = plot.getBoundingClientRect();
    const axes = plot._fullLayout;
    return [['alpha', 'cluster:10'], ['beta', 'cluster:10'], ['alpha', 'cluster:30'], ['beta', 'cluster:30']].map(([x, y]) => {
      const xIndex = axes.xaxis._categories.indexOf(x);
      const yIndex = axes.yaxis._categories.indexOf(y);
      if (xIndex < 0 || yIndex < 0) throw new Error('Expected category missing from rendered axes');
      const viewportX = box.left + axes.xaxis._offset + axes.xaxis.l2p(xIndex);
      const viewportY = box.top + axes.yaxis._offset + axes.yaxis.l2p(yIndex);
      return { x, y, viewportX, viewportY, documentX: viewportX + scrollX, documentY: viewportY + scrollY };
    });
  });
  const hover = [];
  for (const point of points) {
    // Validate real mouse hover before full-page capture can resize the widget.
    // Re-read live axes and target the cell interior, away from gridlines.
    const position = await graph.evaluate((element, point) => {
      type Axis = { _categories: string[]; _offset: number; l2p: (value: number) => number };
      const plot = (element.classList.contains('js-plotly-plot') ? element : element.querySelector('.js-plotly-plot')) as
        HTMLElement & { _fullLayout: { xaxis: Axis; yaxis: Axis } };
      const box = plot.getBoundingClientRect();
      const axes = plot._fullLayout;
      return { x: box.left + axes.xaxis._offset + axes.xaxis.l2p(axes.xaxis._categories.indexOf(point.x)) + 5,
        y: box.top + axes.yaxis._offset + axes.yaxis.l2p(axes.yaxis._categories.indexOf(point.y)) + 5 };
    }, point);
    await page.mouse.move(0, 0);
    await page.mouse.move(position.x, position.y);
    const layer = graph.locator('.hoverlayer');
    await expect(layer).toContainText(`Cluster ${point.y.split(':')[1]}`);
    if (point.x === 'alpha' && point.y === 'cluster:10') await expect(layer).toContainText('Not available');
    if (point.x === 'beta' && point.y === 'cluster:30') await expect(layer).toContainText('display floor');
    hover.push({ x: point.x, y: point.y, text: await layer.textContent() });
  }
  const screenshot = await page.screenshot({ path: info.outputPath('scientific-summary-pixels.png'), fullPage: true });
  const pixels = await page.evaluate(async ({ png, points }) => {
    const picture = new Image();
    picture.src = png;
    await picture.decode();
    const canvas = document.createElement('canvas');
    canvas.width = picture.naturalWidth;
    canvas.height = picture.naturalHeight;
    const context = canvas.getContext('2d');
    if (!context) throw new Error('Canvas pixel decoding unavailable');
    context.drawImage(picture, 0, 0);
    return points.map(point => ({ ...point,
      rgba: Array.from(context.getImageData(Math.round(point.documentX), Math.round(point.documentY), 1, 1).data),
      patch: [-5, 0, 5].flatMap(dx => [-5, 0, 5].map(dy =>
        Array.from(context.getImageData(Math.round(point.documentX + dx), Math.round(point.documentY + dy), 1, 1).data))) }));
  }, { png: `data:image/png;base64,${screenshot.toString('base64')}`, points });
  const missing = pixels.find(point => point.x === 'alpha' && point.y === 'cluster:10');
  const pOne = pixels.find(point => point.x === 'beta' && point.y === 'cluster:10');
  if (!missing || !pOne) throw new Error('Boundary pixel points missing');
  await saveEvidence(info, 'scientific-boundary-pixel-observations', { pixels });
  // The exact category centre can lie on an axis gridline. Require the
  // declared missing background in the adjacent cell interior instead.
  expect(missing.patch.some(rgba => rgba[0] === 238 && rgba[1] === 238 && rgba[2] === 238)).toBe(true);
  expect(pOne.rgba.slice(0, 3)).not.toEqual(missing.rgba.slice(0, 3));
  await saveEvidence(info, 'scientific-boundary-pixels', { pixels, hover });
  return { pixels, hover };
}

async function uploadComplete(page: Page, id: string) {
  await expect.poll(() => page.locator(`#${id}`).evaluate(element =>
    element.closest('.shiny-input-container')?.querySelector('.progress-bar')?.textContent?.trim()),
  { timeout: 60_000 }).toBe('Upload complete');
}

async function loadSession(page: Page, file: string, names: string[]) {
  await goToTab(page, 'save_tab');
  await page.locator('#save-load_session_file').setInputFiles(file);
  await uploadComplete(page, 'save-load_session_file');
  await page.locator('#save-load_session').click();
  await expect(page.locator('#save-clus_summary')).toContainText(`${names.length} clustering result(s)`);
  for (const name of names) await expect(page.locator('#save-clus_summary')).toContainText(name);
}

async function downloadSession(page: Page, info: TestInfo, stem: string) {
  await goToTab(page, 'save_tab');
  await page.locator('#save-session_name').fill(stem);
  const [download] = await Promise.all([
    page.waitForEvent('download'), page.locator('#save-download_session').click(),
  ]);
  const target = info.outputPath(`${stem}.rds`);
  await download.saveAs(target);
  await info.attach(stem, { path: target, contentType: 'application/x-r-rds' });
  return target;
}

async function openFresh(page: Page): Promise<{ context: BrowserContext; page: Page }> {
  const browser = page.context().browser();
  if (!browser) throw new Error('Browser missing');
  const context = await browser.newContext({ viewport: page.viewportSize(), acceptDownloads: true });
  const fresh = await context.newPage();
  await fresh.goto(new URL('/', page.url()).toString());
  await expect(fresh.getByRole('heading', { name: 'Welcome to richStudio' })).toBeVisible();
  return { context, page: fresh };
}

async function runMethods(page: Page, resultNames: string[], prefix = 'Scientific') {
  await goToTab(page, 'cluster_tab');
  await choose(page, 'cluster-selected_rrs', resultNames);
  const names: string[] = [];
  for (const method of methods) {
    const name = `${prefix}_${method.value}`;
    await page.locator(`input[name="cluster-clustering_method"][value="${method.value}"]`).check();
    await page.locator('#cluster-cluster_name').fill(name);
    await page.locator('#cluster-cluster').click();
    await expect(page.locator('#cluster-method_info')).toContainText(`Method: ${method.value}`, { timeout: 120_000 });
    await expect(page.locator('#cluster-cluster_results_box')).toBeVisible();
    names.push(name);
  }
  return names;
}

test('saved scientific boundary session keeps missing values and duplicate representative clusters distinct', async ({ page }, info) => {
  test.setTimeout(180_000);
  const pageErrors: string[] = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  await loadSession(page, fixturePath('scientific-cluster-session-v1.rds'), [fixtureResult]);
  await goToTab(page, 'clus_visualize_tab');
  await choose(page, 'clus_visualize-clusdf_select', [fixtureResult]);
  await expect.poll(async () => mainTrace(await heatmaps(page))?.cells.length).toBe(4);
  const summary = mainTrace(await heatmaps(page));
  if (!summary) throw new Error('Quantitative heatmap missing');
  assertUniqueCells(summary);
  expect(new Set(summary.cells.map(cell => cell.y))).toEqual(new Set(['cluster:10', 'cluster:30']));
  const cell = (x: string, y: string) => summary.cells.find(item => item.x === x && item.y === y)?.z;
  expect(cell('alpha', 'cluster:10')).toBeNull();
  expect(cell('beta', 'cluster:10')).toBeCloseTo(0, 12);
  expect(cell('alpha', 'cluster:30')).toBe(2);
  expect(cell('beta', 'cluster:30')).toBeGreaterThan(2);
  await expect(page.locator('#clus_visualize-clusdf_hmap_empty')).toBeHidden();
  const pixelCheck = await boundaryPixels(page, info);
  await choose(page, 'clus_visualize-indiv_clus_select', ['cluster:10']);
  await expect(page.locator('#clus_visualize-indiv_hmap_empty')).toBeHidden();
  await expect.poll(async () => mainTrace(await heatmaps(page, '#clus_visualize-indiv_clus_hmap'))?.cells.length ??
    (await heatmaps(page, '#clus_visualize-indiv_clus_hmap'))[0]?.cells.length).toBeGreaterThan(0);
  const firstIndividual = await heatmaps(page, '#clus_visualize-indiv_clus_hmap');
  expect(JSON.stringify(firstIndividual)).toContain('Ten first');
  expect(JSON.stringify(firstIndividual)).toContain('Ten second');
  expect(JSON.stringify(firstIndividual)).not.toContain('Thirty first');
  expect(JSON.stringify(firstIndividual)).not.toContain('Thirty second');
  await page.screenshot({ path: info.outputPath('scientific-boundary.png'), fullPage: true });
  const saved = await downloadSession(page, info, 'scientific-boundary-roundtrip');
  const fresh = await openFresh(page);
  try {
    await loadSession(fresh.page, saved, [fixtureResult]);
    await goToTab(fresh.page, 'clus_visualize_tab');
    await choose(fresh.page, 'clus_visualize-clusdf_select', [fixtureResult]);
    await expect.poll(async () => mainTrace(await heatmaps(fresh.page))?.cells).toEqual(summary.cells);
    await choose(fresh.page, 'clus_visualize-indiv_clus_select', ['cluster:30']);
    await expect(fresh.page.locator('#clus_visualize-indiv_hmap_empty')).toBeHidden();
    await expect.poll(async () => JSON.stringify(await heatmaps(fresh.page, '#clus_visualize-indiv_clus_hmap'))).toContain('Thirty first');
    const individual = await heatmaps(fresh.page, '#clus_visualize-indiv_clus_hmap');
    expect(JSON.stringify(individual)).toContain('Thirty first');
    expect(JSON.stringify(individual)).toContain('Thirty second');
    expect(JSON.stringify(individual)).toContain('Padj: 0 (display floor)');
    expect(JSON.stringify(individual)).not.toContain('Ten first');
    expect(JSON.stringify(individual)).not.toContain('Ten second');
    await downloadSession(fresh.page, info, 'scientific-boundary-restored');
    await loadSession(fresh.page, fixturePath('scientific-all-missing-session-v1.rds'), [fixtureResult]);
    await goToTab(fresh.page, 'clus_visualize_tab');
    await choose(fresh.page, 'clus_visualize-clusdf_select', [fixtureResult]);
    await expect.poll(async () => {
      const traces = await heatmaps(fresh.page);
      return traces.length === 1 && traces[0].cells.length === 4 &&
        traces[0].cells.every(cell => cell.z === null);
    }).toBe(true);
    await choose(fresh.page, 'clus_visualize-indiv_clus_select', ['cluster:10']);
    await expect.poll(async () => {
      const traces = await heatmaps(fresh.page, '#clus_visualize-indiv_clus_hmap');
      return traces.length === 1 && traces[0].cells.length === 4 &&
        traces[0].cells.every(cell => cell.z === null) &&
        JSON.stringify(traces[0].text).includes('Not available');
    }).toBe(true);
    await expect(fresh.page.locator('#clus_visualize-indiv_clus_hmap')).toContainText('No available values');
    await fresh.page.screenshot({ path: info.outputPath('scientific-all-missing.png'), fullPage: true });
  } finally {
    await fresh.context.close();
  }
  await saveEvidence(info, 'scientific-boundary-evidence', { project: info.project.name, summary, firstIndividual, pixelCheck, pageErrors });
  expect(pageErrors).toEqual([]);
});

test('fresh synthetic TSV upload runs both corrected backends and preserves missing values through reload', async ({ page }, info) => {
  test.setTimeout(240_000);
  const pageErrors: string[] = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  await goToTab(page, 'cluster_upload_tab');
  await page.locator('#cluster_upload-rr_files').setInputFiles(syntheticInputs.map(fixturePath));
  for (const name of syntheticInputs) await expect(page.locator('#cluster_upload-imported_results_card')).toContainText(name);
  const names = await runMethods(page, syntheticInputs);
  const traces: Record<string, Heatmap[]> = {};
  await goToTab(page, 'clus_visualize_tab');
  for (const name of names) {
    const captured = await selectResultTrace(page, name);
    const trace = mainTrace(captured);
    if (!trace) throw new Error(`Missing numeric trace for ${name}`);
    expect(trace.cells).toHaveLength(4);
    assertUniqueCells(trace);
    expect(trace.cells.filter(cell => cell.z === null)).toHaveLength(1);
    expect(trace.cells.filter(cell => cell.z === 0)).toHaveLength(1);
    traces[name] = captured;
  }
  await page.screenshot({ path: info.outputPath('synthetic-upload-compute.png'), fullPage: true });
  const saved = await downloadSession(page, info, 'synthetic-gui-roundtrip');
  const fresh = await openFresh(page);
  try {
    await loadSession(fresh.page, saved, names);
    await goToTab(fresh.page, 'clus_visualize_tab');
    for (const name of names) {
      const captured = await selectResultTrace(fresh.page, name);
      expect(mainTrace(captured)?.cells).toEqual(mainTrace(traces[name])?.cells);
    }
    await downloadSession(fresh.page, info, 'synthetic-gui-restored');
  } finally {
    await fresh.context.close();
  }
  await saveEvidence(info, 'synthetic-gui-evidence', { project: info.project.name, inputs: syntheticInputs, names, traces, pageErrors });
  expect(pageErrors).toEqual([]);
});

test('GSE63310 real TSV inputs run corrected Kappa hierarchical and DAVID backends via GUI', async ({ page }, info) => {
  test.setTimeout(360_000);
  const inputRoot = process.env.SCIENTIFIC_REAL_INPUTS ?? fixturePath('gse63310');
  const files = fs.readdirSync(inputRoot).filter(name => name.endsWith('.tsv')).sort();
  expect(files).toHaveLength(6);
  const identities = JSON.parse(fs.readFileSync(path.join(inputRoot, 'sha256.json'), 'utf8')) as
    Record<string, { sha256: string }>;
  for (const file of files) {
    expect(createHash('sha256').update(fs.readFileSync(path.join(inputRoot, file))).digest('hex')).toBe(identities[file].sha256);
  }
  const pageErrors: string[] = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  await goToTab(page, 'cluster_upload_tab');
  await page.locator('#cluster_upload-rr_files').setInputFiles(files.map(name => path.join(inputRoot, name)));
  for (const name of files) await expect(page.locator('#cluster_upload-imported_results_card')).toContainText(name, { timeout: 60_000 });
  const names = await runMethods(page, files, 'GSE63310');
  const traces: Record<string, Heatmap[]> = {};
  await goToTab(page, 'clus_visualize_tab');
  for (const name of names) {
    const captured = await selectResultTrace(page, name);
    const trace = mainTrace(captured);
    if (!trace) throw new Error(`Missing numeric trace for ${name}`);
    expect(trace.cells.length).toBeGreaterThan(6);
    assertUniqueCells(trace);
    expect(trace.cells.every(cell => /^cluster:\d+$/.test(cell.y))).toBe(true);
    traces[name] = captured;
    await page.screenshot({ path: info.outputPath(`${name}.png`), fullPage: true });
  }
  const saved = await downloadSession(page, info, 'gse63310-gui-roundtrip');
  const fresh = await openFresh(page);
  try {
    await loadSession(fresh.page, saved, names);
    await goToTab(fresh.page, 'clus_visualize_tab');
    for (const name of names) {
      const captured = await selectResultTrace(fresh.page, name);
      expect(mainTrace(captured)?.cells).toEqual(mainTrace(traces[name])?.cells);
    }
    await downloadSession(fresh.page, info, 'gse63310-gui-restored');
  } finally {
    await fresh.context.close();
  }
  await saveEvidence(info, 'gse63310-gui-evidence', { project: info.project.name, inputRoot, inputs: files, names, traces, pageErrors });
  expect(pageErrors).toEqual([]);
});

test('bundled GO and KEGG demo tables load and GO1-GO2 run through the corrected backend', async ({ page }, info) => {
  test.setTimeout(240_000);
  const pageErrors: string[] = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  await goToTab(page, 'cluster_upload_tab');
  await page.locator('#cluster_upload-rr_load').click();
  const table = page.locator('#cluster_upload-rr_list_table');
  for (const name of ['go1', 'go2', 'kegg1']) await expect(table).toContainText(name);
  await goToTab(page, 'cluster_tab');
  await choose(page, 'cluster-selected_rrs', ['go1', 'go2']);
  await page.locator('input[name="cluster-clustering_method"][value="hierarchical"]').check();
  await page.locator('#cluster-cluster_name').fill('Bundled_GO_hierarchical');
  await page.locator('#cluster-cluster').click();
  await expect(page.locator('#cluster-method_info')).toContainText('Method: hierarchical', { timeout: 120_000 });
  await goToTab(page, 'clus_visualize_tab');
  await choose(page, 'clus_visualize-clusdf_select', ['Bundled_GO_hierarchical']);
  await expect.poll(async () => mainTrace(await heatmaps(page))?.cells.length, { timeout: 60_000 }).toBeGreaterThan(2);
  const trace = mainTrace(await heatmaps(page));
  if (!trace) throw new Error('Bundled GO numeric trace missing');
  assertUniqueCells(trace);
  await page.screenshot({ path: info.outputPath('bundled-go.png'), fullPage: true });
  await downloadSession(page, info, 'bundled-go-session');
  await saveEvidence(info, 'bundled-go-evidence', { project: info.project.name, trace, pageErrors });
  expect(pageErrors).toEqual([]);
});
