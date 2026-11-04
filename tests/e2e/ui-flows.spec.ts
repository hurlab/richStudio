import { test, expect } from './fixtures';
import type { Page } from '@playwright/test';
import path from 'node:path';

// SPEC-WS-013 M1: AC-001 (empty states), AC-002 (job panel, at 390x844), AC-007 (menu, toasts).
// Viewports used by a measurement are set explicitly and the shared playwright.config.ts is not changed.

const baselineProject = path.resolve(__dirname, '../fixtures/ui-baseline/project-baseline.zip');

async function connected(page: Page) {
  await expect.poll(() => page.evaluate(() => !!(window as any).Shiny?.shinyapp?.isConnected())).toBe(true);
  await page.evaluate(() => document.fonts.ready);
}

async function showTab(page: Page, tab: string) {
  await page.locator(`a[href="#shiny-tab-${tab}"]`).evaluate(link => (link as HTMLElement).click());
  await expect(page.locator(`#shiny-tab-${tab}`)).toHaveClass(/\bactive\b/);
}

async function choose(page: Page, id: string, value: string) {
  await expect.poll(() => page.locator(`#${id}`).evaluate((node, wanted) =>
    !!(node as any).selectize?.options[wanted], value)).toBe(true);
  const control = page.locator(`#${id} + .selectize-control`);
  await control.locator('.selectize-input').click();
  await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  await page.keyboard.press('Escape');
}

const jobRows = (page: Page) => page.locator('section[aria-label="Analysis jobs"] .rs-job');
const activeRows = (page: Page) => page.locator(
  'section[aria-label="Analysis jobs"] .rs-job[data-state="queued"], section[aria-label="Analysis jobs"] .rs-job[data-state="running"], section[aria-label="Analysis jobs"] .rs-job[data-state="cancel_requested"]');

async function twoFinishedJobs(page: Page) {
  await showTab(page, 'home_tab');
  await page.locator('#home-load_demo').click();
  await expect(page.locator('#workspace-active_result')).toHaveValue('go1');
  await showTab(page, 'enrich_tab');
  await page.locator('#enrich-deg_load').click();
  await choose(page, 'enrich-degs_to_enrich', 'deg_mouse1');
  await page.locator('#enrich-enrich_deg').click();
  await expect(jobRows(page)).toHaveCount(1, { timeout: 30_000 });
  await expect(activeRows(page)).toHaveCount(0, { timeout: 120_000 });
  await showTab(page, 'cluster_tab');
  await choose(page, 'cluster-selected_rrs', 'go1');
  await choose(page, 'cluster-selected_rrs', 'go2');
  await page.locator('#cluster-cluster_name').fill('clus1');
  await page.locator('#cluster-cluster').click();
  await expect(jobRows(page)).toHaveCount(2, { timeout: 30_000 });
  await expect(activeRows(page)).toHaveCount(0, { timeout: 120_000 });
}

const RR_TABS = ['Table', 'Bar Plot', 'Dot Plot', 'Network', 'Heatmap'];

async function visibleEmptyStates(page: Page, scope: string) {
  return page.locator(`${scope} .empty-state`).locator('visible=true').allInnerTexts();
}

test.describe('AC-001 server-driven empty states', () => {
  test('an empty workspace shows one empty state with a next action per view; a populated one shows none', async ({ page }) => {
    await connected(page);
    await showTab(page, 'rr_visualize_tab');
    const pane = '#shiny-tab-rr_visualize_tab .tab-pane.active';
    for (const name of RR_TABS) {
      await page.locator('#shiny-tab-rr_visualize_tab').getByRole('tab', { name, exact: true }).click();
      const states = await visibleEmptyStates(page, pane);
      expect(states, `${name} empty workspace`).toHaveLength(1);
      expect(states[0], name).toMatch(/\b(Load|Import|Select|Choose|Upload)\b/);
    }
    await page.locator('#rr_visualize-rr_load').click();
    await expect(page.locator('#rr_visualize-select_net')).toHaveValue('go1');
    for (const name of RR_TABS) {
      await page.locator('#shiny-tab-rr_visualize_tab').getByRole('tab', { name, exact: true }).click();
      if (name === 'Heatmap') {
        await choose(page, 'rr_visualize-select_tophmap', 'go1');
      }
      await expect.poll(() => visibleEmptyStates(page, pane), { message: `${name} populated` }).toEqual([]);
      await expect(page.locator(`${pane}`).getByText('No data to display').locator('visible=true')).toHaveCount(0);
    }
  });

  test('cluster figures show no empty-state text once a clustering result is selected', async ({ page }) => {
    await connected(page);
    await showTab(page, 'clus_visualize_tab');
    expect((await visibleEmptyStates(page, '#shiny-tab-clus_visualize_tab')).length).toBeGreaterThanOrEqual(1);
    await twoFinishedJobs(page);
    await showTab(page, 'clus_visualize_tab');
    // The term heatmap shows rows once a cluster is chosen.
    await choose(page, 'clus_visualize-indiv_clus_select', 'cluster:1');
    await expect.poll(() => visibleEmptyStates(page, '#shiny-tab-clus_visualize_tab'), { timeout: 30_000 }).toEqual([]);
  });
});

test.describe('AC-002 compact job panel', () => {
  test('two finished jobs: collapsed panel is at most 64 px on every page, rows show status, settings stay closed', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await connected(page);
    await twoFinishedJobs(page);
    const pages = ['enrich_tab', 'rr_visualize_tab', 'cluster_tab', 'clus_visualize_tab', 'save_tab'];
    for (const tab of pages) {
      await showTab(page, tab);
      const panel = page.locator('section[aria-label="Analysis jobs"]');
      const summary = panel.locator('summary.rs-jobs-summary, .rs-jobs-disclosure > summary').first();
      await expect(summary, tab).toBeVisible();
      const box = await panel.boundingBox();
      expect(box!.height, `${tab} collapsed height`).toBeLessThanOrEqual(64);
      await expect(jobRows(page).locator('visible=true'), `${tab} collapsed rows`).toHaveCount(0);
    }
    await showTab(page, 'cluster_tab');
    await page.locator('section[aria-label="Analysis jobs"] summary').first().click();
    const rows = jobRows(page);
    await expect(rows.locator('visible=true')).toHaveCount(2);
    for (let i = 0; i < 2; i++) {
      await expect(rows.nth(i)).toContainText(/Succeeded|Failed|Cancelled|Interrupted|Detached/);
      // Run settings are inside a closed disclosure.
      const details = rows.nth(i).locator('details.rs-job-details');
      await expect(details).toHaveCount(1);
      expect(await details.evaluate(d => (d as HTMLDetailsElement).open)).toBe(false);
      await expect(details.locator('li').first()).not.toBeVisible();
      // Run ids are neutral text, never the danger colour.
      const colour = await rows.nth(i).locator('.rs-job-id').evaluate(e => getComputedStyle(e).color);
      expect(colour).not.toBe('rgb(199, 37, 78)');
      expect(colour).not.toBe('rgb(220, 53, 69)');
    }
  });
});

test.describe('AC-007 menu and notifications', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await connected(page);
  });

  test('on a narrow screen the menu closes after a destination is chosen', async ({ page }) => {
    await page.getByRole('button', { name: /Toggle navigation/ }).click();
    await expect(page.locator('body.sidebar-open')).toHaveCount(1);
    await page.locator('.sidebar-menu a[href="#shiny-tab-save_tab"]').click();
    await expect(page.locator('#shiny-tab-save_tab')).toHaveClass(/\bactive\b/, { timeout: 1000 });
    await expect(page.locator('body.sidebar-open')).toHaveCount(0, { timeout: 1000 });
    await expect.poll(async () => {
      const box = await page.locator('.sidebar-menu a[href="#shiny-tab-save_tab"]').boundingBox();
      return box ? box.x + box.width : Number.POSITIVE_INFINITY;
    }, { timeout: 1000 }).toBeLessThanOrEqual(0);
  });

  test('an error notification is gone after navigating to another step', async ({ page }) => {
    await showTab(page, 'save_tab');
    await page.locator('#save-load_project_file').setInputFiles({ name: 'broken.zip', mimeType: 'application/zip', buffer: Buffer.from('not a zip') });
    await expect.poll(async () => page.locator('#save-load_project_file_progress .progress-bar').textContent())
      .toContain('Upload complete');
    await page.locator('#save-load_project').click();
    const error = page.locator('.shiny-notification-error');
    await expect(error).toBeVisible();
    await showTab(page, 'home_tab');
    await expect(error).toHaveCount(0, { timeout: 2000 });
  });

  test('a persistent job progress notification is not auto-hidden, a plain message is', async ({ page }) => {
    // Same shape as the one workspace_jobs.R raises for a running job: id "job-<run id>", no duration.
    await page.evaluate(() => {
      const notifications = (window as any).Shiny.notifications;
      notifications.show({ id: 'job-ui-test', html: 'Running job progress', action: '', deps: [], duration: null, type: 'message' });
      notifications.show({ id: 'plain-ui-test', html: 'Plain message', action: '', deps: [], duration: 5000, type: 'message' });
    });
    const progress = page.locator('#shiny-notification-job-ui-test');
    const plain = page.locator('#shiny-notification-plain-ui-test');
    await expect(progress).toBeVisible();
    await expect(plain).toBeVisible();
    await expect(plain).toHaveCount(0, { timeout: 7000 });
    await page.waitForTimeout(1000);
    await expect(progress).toBeVisible();
  });

  test('a success notification is opaque, clear of the page action and hides by itself', async ({ page }) => {
    await showTab(page, 'save_tab');
    await page.locator('#save-load_project_file').setInputFiles(baselineProject);
    await expect.poll(async () => page.locator('#save-load_project_file_progress .progress-bar').textContent())
      .toContain('Upload complete');
    await page.locator('#save-download_project').scrollIntoViewIfNeeded();
    await page.locator('#save-load_project').click();
    const toast = page.locator('.shiny-notification', { hasText: 'Project opened successfully!' });
    await expect(toast).toBeVisible();
    const style = await toast.evaluate(e => {
      const s = getComputedStyle(e);
      const m = s.backgroundColor.match(/rgba?\(([^)]+)\)/)![1].split(/[ ,/]+/).filter(Boolean).map(Number);
      return { alpha: m.length > 3 ? m[3] : 1, opacity: Number(s.opacity) };
    });
    expect(style.alpha).toBe(1);
    // Fully shown (opacity is animated by Shiny while it fades in, so wait for it).
    await expect.poll(() => toast.evaluate(e => Number(getComputedStyle(e).opacity))).toBe(1);
    // Primary action of the Save step, centred in the viewport, does not sit under the toast.
    await page.locator('#save-download_project').evaluate(e => e.scrollIntoView({ block: 'center' }));
    const [toastBox, actionBox] = await Promise.all([toast.boundingBox(), page.locator('#save-download_project').boundingBox()]);
    const overlap = !(toastBox!.x + toastBox!.width <= actionBox!.x || actionBox!.x + actionBox!.width <= toastBox!.x ||
      toastBox!.y + toastBox!.height <= actionBox!.y || actionBox!.y + actionBox!.height <= toastBox!.y);
    expect(overlap).toBe(false);
    await expect(toast).toHaveCount(0, { timeout: 6000 });
  });
});

// ---- M2: copy and validation (AC-008, AC-009, AC-010, AC-028) -----------------------------------

const sampleDeg = path.resolve(__dirname, '../../inst/extdata/deg_mouse1.txt');

test.describe('AC-008 table display', () => {
  test('tables show labels, em-dash, three significant figures, no row-name column, and fit the width', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await connected(page);
    await twoFinishedJobs(page);
    const raw = ['GeneID_header', 'num_genes', 'has_expr_data', 'from_deg', 'Representative_Term', 'n_terms', 'min_pvalue'];
    const headers = (tab: string) => page.evaluate((t) => Array.from(document.querySelectorAll(`#shiny-tab-${t} .dataTables_wrapper`))
      .filter(w => (w as HTMLElement).offsetParent !== null)
      .map(w => Array.from(w.querySelectorAll('.dataTables_scrollHead thead tr:first-child th, table.dataTable:not(.dataTables_scrollBody table) thead tr:first-child th'))
        .map(th => (th.textContent || '').trim())), tab);
    for (const tab of ['enrich_tab', 'rr_visualize_tab', 'cluster_upload_tab', 'cluster_tab', 'clus_visualize_tab']) {
      await showTab(page, tab);
      await expect.poll(async () => (await headers(tab)).length, { message: `${tab} tables`, timeout: 15_000 }).toBeGreaterThan(0);
      const tables = await headers(tab);
      for (const table of tables) {
        for (const name of raw) expect(table, `${tab} ${name}`).not.toContain(name);
        expect(table.filter(h => h === ''), `${tab} empty (row-name) header`).toEqual([]);
      }
    }
    // The Cluster page summary table uses the labels, not n_terms / min_pvalue / Representative_Term.
    await showTab(page, 'cluster_tab');
    await expect.poll(async () => (await headers('cluster_tab')).flat(), { timeout: 15_000 }).toContain('Smallest p-value');
    expect((await headers('cluster_tab')).flat()).toEqual(expect.arrayContaining(['Representative term', 'Terms']));
    // Unknown tracking values are an em-dash, not "?".
    await showTab(page, 'rr_visualize_tab');
    const listCells = await page.locator('#rr_visualize-rr_list_table tbody td').allInnerTexts();
    expect(listCells).not.toContain('?');
    expect(listCells).toContain('—');
    // Results Table tab: p-values to three significant figures, adjusted p-value inside the table width.
    await page.locator('#shiny-tab-rr_visualize_tab').getByRole('tab', { name: 'Table', exact: true }).click();
    const table = page.locator('#rr_visualize-rr_table');
    await expect(table.locator('tbody tr').first()).toBeVisible();
    const info = await table.evaluate((el) => {
      const heads = Array.from(el.querySelectorAll('thead tr:first-child th')) as HTMLElement[];
      const idx = heads.findIndex(h => (h.textContent || '').trim() === 'Adjusted p-value');
      const p = heads.findIndex(h => (h.textContent || '').trim() === 'P-value');
      const rows = Array.from(el.querySelectorAll('tbody tr')).slice(0, 10);
      const wrapper = el.getBoundingClientRect();
      const adj = heads[idx].getBoundingClientRect();
      return { idx, p, adjRight: adj.right, wrapperRight: wrapper.right,
        values: rows.map(r => (r.children[p] as HTMLElement).innerText.trim()) };
    });
    expect(info.idx).toBeGreaterThanOrEqual(0);
    expect(info.adjRight).toBeLessThanOrEqual(info.wrapperRight + 1);
    const significant = (text: string) => (text.replace(/e[+-]?\d+$/i, '').replace(/^0\.0*/, '').replace('.', '').replace(/^0+/, '')).length;
    for (const value of info.values) expect(significant(value), value).toBeLessThanOrEqual(3);
  });
});

test.describe('AC-009 gene-column validation', () => {
  test('a file without a gene column is not added until a column is picked; cancel changes nothing', async ({ page }) => {
    await connected(page);
    await showTab(page, 'enrich_tab');
    const upload = (name: string, body: string | Buffer) =>
      page.locator('#enrich-deg_files').setInputFiles({ name, mimeType: 'text/plain', buffer: Buffer.from(body) });
    const rows = () => page.locator('#enrich-deg_list_table tbody tr').filter({ hasNotText: 'No data available' });
    await upload('this.is.not.txt', 'this.is.not\tscore\ng1\t0.5\n');
    await expect(page.locator('#shiny-modal')).toBeVisible();
    await expect(page.locator('#shiny-modal')).toContainText('this.is.not, score');
    await expect(page.locator('#enrich-deg_upload_status')).toContainText('not added');
    await expect(page.locator('#enrich-deg_upload_status')).toContainText('1 rows');
    await expect(rows()).toHaveCount(0);
    // Cancel: nothing added, the Save summary still lists no gene list.
    await page.locator('#enrich-deg_pick_cancel').click();
    await expect(page.locator('#shiny-modal')).toHaveCount(0);
    await expect(page.locator('#enrich-deg_upload_status')).toContainText('this.is.not.txt was not added.');
    await showTab(page, 'save_tab');
    await expect(page.locator('#save-deg_summary')).toContainText('No DEG sets loaded');
    // Pick: exactly one dataset with the chosen gene column.
    await showTab(page, 'enrich_tab');
    await upload('picked.txt', 'this.is.not\tscore\ng1\t0.5\ng2\t0.7\n');
    await expect(page.locator('#shiny-modal')).toBeVisible();
    await page.locator('#enrich-deg_pick_ok').click();
    await expect(page.locator('#enrich-deg_upload_status')).toContainText('Added picked.txt: gene column GeneID, 2 rows.');
    await expect(rows()).toHaveCount(1);
    // A valid list is confirmed with its detected column and row count.
    await page.locator('#enrich-deg_files').setInputFiles(sampleDeg);
    await expect(page.locator('#enrich-deg_upload_status')).toContainText('Added deg_mouse1.txt: gene column geneID, 79 rows.');
    await expect(rows()).toHaveCount(2);
  });
});

test.describe('AC-010 environment failure', () => {
  test('a missing annotation package shows the full command, no Retry and no Retry advice', async ({ page }) => {
    await connected(page);
    await showTab(page, 'enrich_tab');
    await page.locator('#enrich-deg_load').click();
    await choose(page, 'enrich-degs_to_enrich', 'deg_mouse1');
    await page.locator('#enrich-enrich_deg').click();
    await expect(jobRows(page)).toHaveCount(1, { timeout: 30_000 });
    await expect(activeRows(page)).toHaveCount(0, { timeout: 120_000 });
    const panel = page.locator('section[aria-label="Analysis jobs"]');
    await panel.locator('summary.rs-jobs-summary').click();
    const row = jobRows(page).first();
    await expect(row).toHaveAttribute('data-state', 'failed');
    const command = panel.locator('code.rs-job-command');
    await expect(command).toBeVisible();
    await expect(command).toHaveText(/^BiocManager::install\(['"]org\.[A-Za-z]+\.eg\.db['"]\)$/);
    await expect(panel.locator('.rs-copy')).toBeVisible();
    await expect(row.getByRole('button', { name: 'Retry' })).toHaveCount(0);
    await expect(panel).not.toContainText('use Retry');
    // The notification does not advise Retry either.
    const notices = await page.locator('.shiny-notification').allInnerTexts();
    for (const text of notices) expect(text).not.toContain('use Retry');
  });
});

test.describe('AC-028 old session file', () => {
  test('an .rds file is refused with a short message and the steps in an expandable block, gone after navigating', async ({ page }) => {
    await connected(page);
    await showTab(page, 'save_tab');
    await page.locator('#save-load_session_file').setInputFiles({ name: 'old.rds', mimeType: 'application/octet-stream', buffer: Buffer.from([0x58, 0x0a, 0x00, 0x00, 0x00]) });
    await expect.poll(async () => page.locator('#save-load_session_file_progress .progress-bar').textContent())
      .toContain('Upload complete');
    await page.locator('#save-load_session').click();
    const note = page.locator('.shiny-notification-error');
    await expect(note).toBeVisible();
    const visible = (await note.locator('.shiny-notification-content').innerText()).replace(/\s+/g, ' ').trim();
    expect(visible).toContain('nothing was loaded');
    // Sentences end in . ! or ? followed by a space or the end; the closed block shows only its title.
    expect((visible.match(/[.!?](\s|$)/g) || []).length).toBeLessThanOrEqual(3);
    const steps = note.locator('details.rs-refusal-steps');
    await expect(steps).toHaveCount(1);
    await expect(note.locator('code.rs-job-command')).not.toBeVisible();
    await steps.locator('summary').click();
    await expect(note.locator('code.rs-job-command')).toHaveText('Rscript scripts/convert-trusted-session.R my-session.rds my-session.json');
    await expect(note.locator('.rs-copy')).toBeVisible();
    await showTab(page, 'home_tab');
    await expect(page.locator('.shiny-notification-error')).toHaveCount(0, { timeout: 2000 });
  });
});

// ---- M4: figure legibility (AC-029) ----------------------------------------------------------

test.describe('AC-029 network figure', () => {
  for (const viewport of [{ width: 1440, height: 900 }, { width: 390, height: 844 }]) {
    test(`the demo network is visible at ${viewport.width}x${viewport.height} and no empty state covers it`, async ({ page }) => {
      await page.setViewportSize(viewport);
      await connected(page);
      await page.locator('#home-load_demo').click();
      await page.waitForSelector('#shiny-tab-rr_visualize_tab.active');
      await page.locator('#shiny-tab-rr_visualize_tab').getByRole('tab', { name: 'Network', exact: true }).click();
      const image = page.locator('#rr_visualize-network img');
      await expect(image).toBeVisible({ timeout: 10_000 });
      await expect.poll(async () => { const b = await image.boundingBox(); return !!b && b.width >= 200 && b.height >= 200; },
        { timeout: 10_000 }).toBe(true);
      await expect(page.locator('#rr_visualize-net_empty')).not.toBeVisible();
      await image.scrollIntoViewIfNeeded();
      const covered = await image.evaluate((img) => {
        const b = img.getBoundingClientRect();
        const top = document.elementFromPoint(b.left + b.width / 2, b.top + b.height / 2);
        return !(top === img || img.contains(top) || (top && (top as HTMLElement).closest('#rr_visualize-network')));
      });
      expect(covered).toBe(false);
      const natural = await image.evaluate((img) => [(img as HTMLImageElement).naturalWidth, (img as HTMLImageElement).naturalHeight]);
      expect(natural[0]).toBeGreaterThanOrEqual(200);
      expect(natural[1]).toBeGreaterThanOrEqual(200);
    });
  }
});
