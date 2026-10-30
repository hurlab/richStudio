import { test, expect, openNavigation } from './fixtures';
import type { Page, TestInfo } from '@playwright/test';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';

type Cell = { x: string; y: string; z: number | null };
type Expected = { ids: string[]; terms: string[]; cells: Cell[] };
type Case = { name: string; rows?: number; kind?: string };

const fixtureScript = String.raw`
library(richStudio)
cases <- jsonlite::fromJSON(Sys.getenv("LEGIBILITY_CASES"), simplifyVector=FALSE)
session <- readRDS("tests/fixtures/workspace/scientific-cluster-session-v1.rds")
session$clusnames <- character(); session$clusdfs <- list(); session$cluslists <- list()
tracking <- list(); expected <- list()
for (item in cases) {
  if (identical(item$kind, "gse")) {
    files <- list.files("tests/fixtures/workspace/gse63310", pattern="[.]tsv$", full.names=TRUE)
    inputs <- lapply(files, read.delim, check.names=FALSE); names(inputs) <- basename(files)
    result <- richStudio:::workspace_cluster_compute(inputs, "hierarchical",
      richStudio:::build_cluster_params(list(), "hierarchical"), item$name)
    stopifnot(isTRUE(result$success))
    summary <- result$summary_df; details <- result$cluster_df
  } else {
    n <- as.integer(item$rows); ids <- seq_len(n) * 3L + 2L
    if (identical(item$kind, "long-id")) {
      ids <- paste0(paste(rep("long-cluster-id", 8), collapse=""), c("A", "B"))
    }
    terms <- rep(c(
      paste(rep("대표 기능 α 🧬 é & growth regulation", 7), collapse=" "),
      paste0("Shared <img src=x onerror=\"window.__heatmapInjected=1\"> ",
             "<script>window.__heatmapInjected=1</script> ",
             paste(rep("long representative term", 7), collapse=" "))
    ), length.out=n)
    a <- rep(c(NA_real_, 1, 0, .01), length.out=n)
    b <- rep(c(.5, NA_real_, .04, 0), length.out=n)
    if (identical(item$kind, "all-na")) { a[] <- NA_real_; b[] <- NA_real_ }
    summary <- data.frame(Cluster=ids, Representative_Term=terms,
      Padj_case=a, Padj_control=b, Pvalue_case=a/2, Pvalue_control=b/2,
      stringsAsFactors=FALSE)
    details <- summary; details$Term <- terms; details$GeneID <- "g1,g2"
  }
  name <- item$name; n <- nrow(summary)
  session$clusnames <- c(session$clusnames, name)
  session$clusdfs[[name]] <- summary; session$cluslists[[name]] <- details
  tracking[[name]] <- data.frame(name=name, method="hierarchical", n_clusters=n,
    n_terms=nrow(details), stringsAsFactors=FALSE)
  columns <- grep("^Padj_", names(details), value=TRUE)
  groups <- split(seq_len(nrow(details)), as.character(details$Cluster))
  cells <- list()
  for (i in seq_len(n)) for (column in columns) {
    values <- details[[column]][groups[[as.character(summary$Cluster[i])]]]
    raw <- if (all(is.na(values))) NA_real_ else mean(values, na.rm=TRUE)
    shown <- if (!is.na(raw) && raw==0) .Machine$double.xmin*.Machine$double.eps else raw
    cells[[length(cells)+1L]] <- list(x=sub("^Padj_", "", column),
      y=paste0("cluster:", summary$Cluster[i]), z=round(-log10(shown),4))
  }
  expected[[name]] <- list(ids=as.list(paste0("cluster:", summary$Cluster)),
    terms=as.list(summary$Representative_Term), cells=cells)
}
session$big_clusdf$df <- do.call(rbind, tracking)
saveRDS(session, Sys.getenv("LEGIBILITY_SESSION"))
jsonlite::write_json(expected, Sys.getenv("LEGIBILITY_EXPECTED"),
  auto_unbox=TRUE, pretty=TRUE, digits=NA, na="null")
`;

function sessionFixture(info: TestInfo, cases: Case[]) {
  const file = info.outputPath('legibility-session.rds');
  const expected = info.outputPath('expected-cells.json');
  const result = spawnSync('Rscript', ['--vanilla', '-'], {
    input: fixtureScript, encoding: 'utf8', timeout: 120_000,
    env: { ...process.env, RENV_CONFIG_AUTOLOADER_ENABLED: 'FALSE',
      LEGIBILITY_CASES: JSON.stringify(cases), LEGIBILITY_SESSION: file,
      LEGIBILITY_EXPECTED: expected, OPENBLAS_NUM_THREADS: '1', OMP_NUM_THREADS: '1' },
  });
  fs.writeFileSync(info.outputPath('fixture-generation.log'), result.stdout + result.stderr);
  if (result.error) throw result.error;
  expect(result.status, 'fixture generation must finish successfully').toBe(0);
  return { file, expected: JSON.parse(fs.readFileSync(expected, 'utf8')) as Record<string, Expected> };
}

async function tab(page: Page, name: string) {
  await openNavigation(page);
  const selector = `a[href="#shiny-tab-${name}"]`;
  const link = page.locator(`.sidebar-menu ${selector}`);
  if (!(await link.isVisible())) {
    await page.locator('.sidebar-menu li.treeview', { has: page.locator(selector) }).locator(':scope > a').click();
  }
  await link.click();
  if (await page.locator('body.sidebar-open').count()) {
    await page.getByRole('button', { name: /Toggle navigation/ }).click();
    await expect(page.locator('body.sidebar-open')).toHaveCount(0);
    await expect(page.getByRole('link', { name: /\bHome$/ })).not.toBeInViewport();
  }
  await expect(page.locator(`#shiny-tab-${name}`)).toHaveClass(/\bactive\b/);
}

async function load(page: Page, file: string, firstName?: string) {
  await tab(page, 'save_tab');
  // Existing Shiny file/Selectize bindings use stable module IDs, as in the
  // established scientific workflow suite. New viewer controls use their names.
  await page.locator('#save-load_session_file').setInputFiles(file);
  await expect.poll(() => page.locator('#save-load_session_file').evaluate(element =>
    element.closest('.shiny-input-container')?.querySelector('.progress-bar')?.textContent?.trim()),
  { timeout: 60_000 }).toBe('Upload complete');
  await page.locator('#save-load_session').click();
  if (firstName) await expect(page.locator('#save-clus_summary')).toContainText(firstName);
}

async function select(page: Page, name: string) {
  await tab(page, 'clus_visualize_tab');
  const original = page.locator('#clus_visualize-clusdf_select');
  await expect.poll(() => original.evaluate((element, wanted) =>
    !!(element as HTMLSelectElement & { selectize?: { options: Record<string, unknown> } }).selectize?.options[wanted], name)).toBe(true);
  const control = page.locator('#clus_visualize-clusdf_select + .selectize-control');
  await control.locator('.selectize-input').click();
  await control.locator(`.selectize-dropdown .option[data-value="${name}"]`).click();
  await expect(original).toHaveValue(name);
  await expect(page.getByRole('region', { name: 'Cluster heatmap', exact: true })).toBeVisible();
}

async function plotState(page: Page) {
  return page.locator('#clus_visualize-clusdf_hmap').evaluate(element => {
    type Trace = { type?: string; x?: unknown[]; y?: unknown[]; z?: unknown[]; text?: unknown };
    const plot = (element.classList.contains('js-plotly-plot') ? element : element.querySelector('.js-plotly-plot')) as
      (HTMLElement & { data?: Trace[]; _fullLayout?: any;
        _context?: { toImageButtonOptions?: { width?: number; height?: number; scale?: number } } }) | null;
    const trace = plot?.data?.find(t => t.type === 'heatmap');
    if (!plot || !trace) return null;
    const x = trace.x ?? [], y = trace.y ?? [], z = trace.z ?? [];
    const cells: Cell[] = [];
    if (Array.isArray(z[0])) {
      for (let row = 0; row < y.length; row++) for (let col = 0; col < x.length; col++) {
        const value = (z[row] as unknown[])[col];
        cells.push({ x: String(x[col]), y: String(y[row]), z: typeof value === 'number' ? value : null });
      }
    } else {
      for (let i = 0; i < z.length; i++) cells.push({ x: String(x[i]), y: String(y[i]),
        z: typeof z[i] === 'number' ? z[i] as number : null });
    }
    const box = plot.getBoundingClientRect();
    const labels = Array.from(plot.querySelectorAll('.yaxislayer-above .ytick text')).map(node => {
      const rect = node.getBoundingClientRect();
      return { text: node.textContent ?? '', top: rect.top, bottom: rect.bottom,
        left: rect.left, right: rect.right, width: rect.width, height: rect.height,
        font: parseFloat(getComputedStyle(node).fontSize) };
    }).sort((a, b) => a.top - b.top);
    const annotations = Array.from(plot.querySelectorAll('.annotation-text')).map(node => {
      const rect = node.getBoundingClientRect();
      return { text: node.textContent ?? '', top: rect.top, bottom: rect.bottom,
        left: rect.left, right: rect.right };
    });
    const xAxisText = Array.from(plot.querySelectorAll('.xtick text, .xtitle, .gtitle')).map(node => {
      const rect = node.getBoundingClientRect();
      return { text: node.textContent ?? '', top: rect.top, bottom: rect.bottom,
        left: rect.left, right: rect.right };
    });
    const layout = plot._fullLayout;
    const imageOptions = plot._context?.toImageButtonOptions ?? {};
    return { cells, hover: trace.text, labels, annotations, xAxisText,
      exportSize: { width: Number(imageOptions.width ?? layout.width),
        height: Number(imageOptions.height ?? layout.height), scale: Number(imageOptions.scale ?? 1) },
      plot: { top: box.top, bottom: box.bottom, left: box.left, right: box.right,
        width: box.width, height: box.height },
      matrixLeft: box.left + layout.xaxis._offset, axisHeight: layout.yaxis._length,
      range: layout.yaxis.range, categoryarray: layout.yaxis.categoryarray,
      documentWidth: document.documentElement.scrollWidth, viewportWidth: window.innerWidth,
      title: String(layout.title?.text ?? ''), recalculating: element.classList.contains('recalculating') };
  });
}

async function stable(page: Page, expected: Expected) {
  let captured: Awaited<ReturnType<typeof plotState>> = null;
  let previous = '', frames = 0;
  await expect.poll(async () => {
    const current = await plotState(page);
    const key = JSON.stringify(current && [current.cells, current.range, current.labels]);
    if (current && current.cells.length === expected.cells.length && !current.recalculating) {
      frames = key === previous ? frames + 1 : 1; captured = current;
    } else frames = 0;
    previous = key;
    return frames >= 3;
  }, { timeout: 60_000, intervals: [100, 250, 500] }).toBe(true);
  const result = captured as Awaited<ReturnType<typeof plotState>>;
  if (!result) throw new Error('No stable quantitative trace');
  const actual = new Map(result.cells.map(cell => [`${cell.x}\0${cell.y}`, cell.z]));
  expect(actual.size).toBe(expected.cells.length);
  for (const cell of expected.cells) expect(actual.get(`${cell.x}\0${cell.y}`)).toBe(cell.z);
  return result;
}

async function geometry(page: Page, expected: Expected) {
  const state = await stable(page, expected);
  const region = page.getByRole('region', { name: 'Cluster heatmap', exact: true });
  const viewport = await region.boundingBox();
  expect(viewport).not.toBeNull();
  expect(viewport!.height).toBeLessThanOrEqual(Math.min(720, page.viewportSize()!.height * .7) + 1);
  expect(state.plot.height).toBeLessThanOrEqual(8192);
  expect(state.plot.width).toBeLessThanOrEqual(8192);
  expect(state.documentWidth).toBeLessThanOrEqual(state.viewportWidth + 1);
  expect(state.labels.length).toBeGreaterThan(0);
  const visibleRows = Math.min(expected.ids.length,
    Math.round(Math.abs(Number(state.range[1]) - Number(state.range[0]))));
  expect(visibleRows).toBeGreaterThan(0);
  expect(state.axisHeight / visibleRows).toBeGreaterThanOrEqual(17.95);
  expect(state.labels).toHaveLength(visibleRows);
  for (let i = 0; i < state.labels.length; i++) {
    const label = state.labels[i];
    expect(label.font).toBeGreaterThanOrEqual(14);
    expect(label.width).toBeLessThanOrEqual(240.5);
    expect(label.left).toBeGreaterThanOrEqual(state.plot.left - .5);
    expect(label.right).toBeLessThanOrEqual(state.matrixLeft + .5);
    if (i) {
      expect(label.top).toBeGreaterThanOrEqual(state.labels[i - 1].bottom - .5);
    }
  }
  const footnote = state.annotations.find(a => /Grey cells:/.test(a.text));
  expect(footnote, 'missing/zero explanation must remain in the actual figure').toBeTruthy();
  if (footnote) {
    expect(footnote.top).toBeGreaterThanOrEqual(state.plot.top - 1);
    expect(footnote.bottom).toBeLessThanOrEqual(state.plot.bottom + 1);
    for (const text of state.xAxisText) {
      const intersects = footnote.left < text.right - .5 && footnote.right > text.left + .5 &&
        footnote.top < text.bottom - .5 && footnote.bottom > text.top + .5;
      expect(intersects, `NA/zero note must not cross ${text.text}`).toBe(false);
    }
  }
  return state;
}

async function keyboardFigureEdges(page: Page) {
  const region = page.getByRole('region', { name: 'Cluster heatmap', exact: true });
  for (let i = 0; i < 80 && !(await region.evaluate(el => document.activeElement === el)); i++) await page.keyboard.press('Tab');
  expect(await region.evaluate(el => document.activeElement === el)).toBe(true);
  expect(await region.evaluate(el => {
    const style = getComputedStyle(el);
    return (style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) >= 1) || style.boxShadow !== 'none';
  })).toBe(true);
  await region.press('End');
  await expect.poll(() => region.evaluate(el => el.scrollHeight - el.clientHeight - el.scrollTop)).toBeLessThanOrEqual(2);
  await expect.poll(async () => {
    const current = await plotState(page), viewport = await region.boundingBox();
    const last = current?.labels[current.labels.length - 1];
    return !!last && !!viewport && last.top >= viewport.y - 1 && last.bottom <= viewport.y + viewport.height + 1;
  }).toBe(true);
  await region.press('Home');
  await expect.poll(() => region.evaluate(el => el.scrollTop)).toBeLessThanOrEqual(1);
  await expect.poll(async () => {
    const current = await plotState(page), viewport = await region.boundingBox();
    const first = current?.labels[0];
    return !!first && !!viewport && first.top >= viewport.y - 1 && first.bottom <= viewport.y + viewport.height + 1;
  }).toBe(true);
}

async function imageExport(page: Page, info: TestInfo, stem: string) {
  const state = await plotState(page);
  if (!state) throw new Error('No image source');
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    // Plotly's existing modebar is a library boundary; data-title is its stable
    // native camera identifier when the bundled version supplies no ARIA name.
    page.locator('#clus_visualize-clusdf_hmap [data-title="Download plot as a png"]').click(),
  ]);
  const file = info.outputPath(stem + '.png'); await download.saveAs(file);
  const png = fs.readFileSync(file);
  expect(png.subarray(1, 4).toString()).toBe('PNG');
  expect(png.readUInt32BE(16)).toBeLessThanOrEqual(8192);
  expect(png.readUInt32BE(20)).toBeLessThanOrEqual(8192);
  expect(state.exportSize.width).toBe(1000);
  expect(state.exportSize.height).toBe(Math.round(state.plot.height));
  expect(state.exportSize.scale).toBeGreaterThan(0);
  expect(png.readUInt32BE(16)).toBe(Math.round(state.exportSize.width * state.exportSize.scale));
  expect(png.readUInt32BE(20)).toBe(Math.round(state.plot.height * state.exportSize.scale));
  const viewport = await page.getByRole('region', { name: 'Cluster heatmap', exact: true }).boundingBox();
  expect(viewport).not.toBeNull();
  expect(png.readUInt32BE(20)).toBeGreaterThan(viewport!.height * state.exportSize.scale);
  expect(png.length).toBeGreaterThan(1000);
  await info.attach(stem, { path: file, contentType: 'image/png' });
}

test('dense bundled-size and real GSE heatmaps expose readable rows and preserve values', async ({ page }, info) => {
  test.setTimeout(240_000);
  const data = sessionFixture(info, [{ name: 'Dense141', rows: 141 }, { name: 'GSE366', kind: 'gse' }]);
  await load(page, data.file, 'Dense141');
  const measurements = [];
  for (const name of ['Dense141', 'GSE366']) {
    await select(page, name);
    const state = await geometry(page, data.expected[name]); measurements.push({ name, state });
    await keyboardFigureEdges(page);
    await page.screenshot({ path: info.outputPath(name + '.png') });
  }
  await imageExport(page, info, 'normal-current-view');
  const originalViewport = page.viewportSize()!;
  await page.setViewportSize(originalViewport.width > 500 ? { width: 375, height: 667 } : { width: 1280, height: 720 });
  await geometry(page, data.expected.GSE366);
  await expect(page.locator('#clus_visualize-clusdf_select')).toHaveValue('GSE366');
  await keyboardFigureEdges(page);
  await page.setViewportSize(originalViewport);
  await geometry(page, data.expected.GSE366);
  fs.writeFileSync(info.outputPath('readability.json'), JSON.stringify(measurements, null, 2));
});

test('all admitted rows remain reachable through bounded keyboard windows and honest export', async ({ page }, info) => {
  test.setTimeout(300_000);
  const data = sessionFixture(info, [{ name: 'Normal400', rows: 400 }, { name: 'Window401', rows: 401 },
    { name: 'Maximum2000', rows: 2000 }, { name: 'Small10', rows: 10 }]);
  await load(page, data.file, 'Normal400');
  await select(page, 'Normal400'); await geometry(page, data.expected.Normal400);
  for (const name of ['Window401', 'Maximum2000']) {
    await select(page, name);
    const control = page.getByLabel('Cluster row window', { exact: true });
    await expect(control).toBeVisible(); await expect(control).toBeEnabled();
    // Shiny updates the figure and native choices independently. Await this
    // result's options rather than sampling the previous result's dropdown.
    await expect(control.locator('option')).toHaveCount(Math.ceil(data.expected[name].ids.length / 400));
    const visited = new Set<string>();
    await control.focus(); await control.press('Home');
    expect(await control.evaluate(el => {
      const style = getComputedStyle(el);
      return style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) >= 1;
    })).toBe(true);
    const options = await control.locator('option').count();
    for (let window = 0; window < options; window++) {
      const visibleIds = [...data.expected[name].ids].reverse().slice(window * 400, (window + 1) * 400).sort();
      await expect.poll(async () => {
        const current = await plotState(page);
        return current?.labels.map(label => 'cluster:' + label.text.match(/[0-9]+/)?.[0]).sort() ?? [];
      }, { timeout: 60_000 }).toEqual(visibleIds);
      const state = await geometry(page, data.expected[name]);
      expect(state.labels.length).toBeLessThanOrEqual(400);
      for (const label of state.labels) {
        const id = label.text.match(/[0-9]+/)?.[0];
        if (id) visited.add('cluster:' + id);
      }
      if (window < options - 1) await control.press('ArrowDown');
    }
    expect([...visited].sort()).toEqual([...data.expected[name].ids].sort());
    await control.press('End');
    const final = await geometry(page, data.expected[name]);
    expect(final.title + ' ' + final.annotations.map(a => a.text).join(' ')).toMatch(/rows.*of|rows.*\//i);
    expect(final.title + ' ' + final.annotations.map(a => a.text).join(' ')).toContain(String(data.expected[name].ids.length));
    await keyboardFigureEdges(page);
    if (name === 'Maximum2000') await imageExport(page, info, 'last-window-current-view');
  }
  await select(page, 'Small10'); const small = await geometry(page, data.expected.Small10);
  expect(small.plot.height).toBeLessThan(800);
  await expect(page.getByLabel('Cluster row window', { exact: true })).not.toBeVisible();
  await expect.poll(() => page.getByRole('region', { name: 'Cluster heatmap', exact: true }).evaluate(el => el.scrollTop)).toBeLessThanOrEqual(1);
  await expect(page.locator('#clus_visualize-clusdf_select')).toHaveValue('Small10');
  await tab(page, 'save_tab');
  await page.locator('#save-session_name').fill('complete-legibility-session');
  const [download] = await Promise.all([
    page.waitForEvent('download'), page.locator('#save-download_session').click(),
  ]);
  const saved = info.outputPath('complete-legibility-session.rds');
  await download.saveAs(saved);
  const compared = spawnSync('Rscript', ['--vanilla', '-'], {
    input: `original <- readRDS(Sys.getenv("LEGIBILITY_ORIGINAL"))
saved <- readRDS(Sys.getenv("LEGIBILITY_SAVED"))
for (name in names(original$clusdfs)) {
  stopifnot(identical(original$clusdfs[[name]], saved$clusdfs[[name]]),
    identical(original$cluslists[[name]], saved$cluslists[[name]]))
}
stopifnot(nrow(saved$clusdfs$Maximum2000)==2000L)
cat("COMPLETE_SESSION_EXPORT_PASS\\n")`,
    encoding: 'utf8', timeout: 60_000,
    env: { ...process.env, LEGIBILITY_ORIGINAL: data.file, LEGIBILITY_SAVED: saved },
  });
  fs.writeFileSync(info.outputPath('saved-session-comparison.log'), compared.stdout + compared.stderr);
  if (compared.error) throw compared.error;
  expect(compared.status).toBe(0);
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Welcome to richStudio' })).toBeVisible();
  await load(page, saved, 'Maximum2000');
  await select(page, 'Maximum2000');
  await geometry(page, data.expected.Maximum2000);
});

test('small missing and oversized-ID labels stay inert and retain complete originals', async ({ page }, info) => {
  test.setTimeout(180_000);
  await page.evaluate(() => { (window as Window & { __heatmapInjected?: number }).__heatmapInjected = 0; });
  const data = sessionFixture(info, [{ name: 'Single', rows: 1 }, { name: 'AllMissing', rows: 2, kind: 'all-na' },
    { name: 'LongIDs', rows: 2, kind: 'long-id' }]);
  await tab(page, 'clus_visualize_tab');
  await expect(page.getByText('Select a cluster result above to view the heatmap.', { exact: true })).toBeVisible();
  await expect(page.getByLabel('Cluster row window', { exact: true })).not.toBeVisible();
  await load(page, data.file, 'Single');
  for (const name of ['Single', 'AllMissing', 'LongIDs']) {
    await select(page, name); const state = await geometry(page, data.expected[name]);
    expect(state.plot.height).toBeLessThan(800);
    // Selectize keeps unselected choices in its store rather than native option
    // nodes; this is the same existing library boundary as result selection.
    await expect.poll(() => page.locator('#clus_visualize-indiv_clus_select').evaluate((element, expected) => {
      const selectize = (element as HTMLSelectElement & {
        selectize?: { options: Record<string, Record<string, string>>; settings: { labelField: string } };
      }).selectize;
      const options = Object.values(selectize?.options ?? {}).map(option => option[selectize!.settings.labelField]);
      return expected.ids.every((id, i) => options.some(option =>
        option.includes(id.replace(/^cluster:/, '')) && option.includes(expected.terms[i])));
    }, data.expected[name])).toBe(true);
    if (name === 'AllMissing') expect(state.cells.every(cell => cell.z === null)).toBe(true);
    if (name === 'LongIDs') {
      expect(new Set(state.labels.map(label => label.text)).size).toBe(2);
      expect(state.labels.map(label => label.text.match(/^Display row [0-9]+/)?.[0]).sort()).toEqual(['Display row 1', 'Display row 2']);
      const contents = await page.getByRole('region', { name: 'Cluster heatmap', exact: true }).textContent();
      expect(contents).toMatch(/(?:full|original).*ID|ID.*(?:full|original)/i);
      await page.getByRole('region', { name: 'Cluster heatmap', exact: true }).scrollIntoViewIfNeeded();
      const position = await page.locator('#clus_visualize-clusdf_hmap').evaluate((element, cell) => {
        const plot = (element.classList.contains('js-plotly-plot') ? element : element.querySelector('.js-plotly-plot')) as any;
        const box = plot.getBoundingClientRect();
        const x = plot._fullLayout.xaxis, y = plot._fullLayout.yaxis;
        return { x: box.left + x._offset + x.l2p(x._categories.indexOf(cell.x)),
          y: box.top + y._offset + y.l2p(y._categories.indexOf(cell.y)) };
      }, { x: 'case', y: data.expected[name].ids[1] });
      expect(position.x).toBeGreaterThanOrEqual(0);
      expect(position.x).toBeLessThan(page.viewportSize()!.width);
      expect(position.y).toBeGreaterThanOrEqual(0);
      expect(position.y).toBeLessThan(page.viewportSize()!.height);
      await page.mouse.move(position.x, position.y);
      await expect.poll(async () => {
        const text = await page.locator('#clus_visualize-clusdf_hmap .hoverlayer').textContent() ?? '';
        return text.replace(/\s+/g, ' ');
      }).toContain(data.expected[name].terms[1].replace(/\s+/g, ' '));
      await expect(page.locator('#clus_visualize-clusdf_hmap .hoverlayer')).toContainText(data.expected[name].ids[1].replace(/^cluster:/, ''));
    }
  }
  expect(await page.evaluate(() => (window as Window & { __heatmapInjected?: number }).__heatmapInjected)).toBe(0);
  expect(await page.locator('#clus_visualize-clusdf_hmap img[src="x"]').count()).toBe(0);
  expect(await page.locator('#clus_visualize-clusdf_hmap script').filter({ hasText: '__heatmapInjected' }).count()).toBe(0);
});

test('policy-plus-one reports the limit without allocating an oversized figure', async ({ page }, info) => {
  test.setTimeout(120_000);
  const data = sessionFixture(info, [{ name: 'Rejected2001', rows: 2001 }, { name: 'Recovered10', rows: 10 }]);
  await load(page, data.file);
  await tab(page, 'clus_visualize_tab');
  await expect.poll(() => page.locator('#clus_visualize-clusdf_select').evaluate(element =>
    !!(element as HTMLSelectElement & { selectize?: { options: Record<string, unknown> } }).selectize?.options.Rejected2001)).toBe(true);
  const control = page.locator('#clus_visualize-clusdf_select + .selectize-control');
  await control.locator('.selectize-input').click();
  await control.locator('.selectize-dropdown .option[data-value="Rejected2001"]').click();
  await expect(page.getByText(/resource limit exceeded: render_rows/i)).toBeVisible({ timeout: 30_000 });
  const state = await plotState(page);
  if (state) { expect(state.plot.height).toBeLessThanOrEqual(8192); expect(state.cells).toHaveLength(0); }
  await expect(page.getByLabel('Cluster row window', { exact: true })).not.toBeVisible();
  await expect(page.locator('.shiny-disconnected-overlay')).toHaveCount(0);
  await select(page, 'Recovered10');
  await geometry(page, data.expected.Recovered10);
});
