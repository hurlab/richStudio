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
