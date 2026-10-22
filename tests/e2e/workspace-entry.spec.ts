import { test, expect } from './fixtures';
import type { Page, TestInfo } from '@playwright/test';
import type { AxeResults, RunOptions } from 'axe-core';
import { createRequire } from 'node:module';

// SPEC-WS-003 browser entry paths. Bundled demo results stand in for a completed
// enrichment run (fixtures rule); no enrichment or clustering is executed here.
const requireLocal = createRequire(__filename);

const homeActions = [
  { id: 'home-upload_gene_lists', label: 'Upload gene lists', tab: 'enrich_tab', landing: '#enrich-deg_files-label' },
  { id: 'home-import_results', label: 'Import enrichment results', tab: 'cluster_upload_tab', landing: '#cluster_upload-rr_files-label' },
  { id: 'home-open_saved', label: 'Open saved analysis', tab: 'save_tab', landing: '#save-load_session' },
  { id: 'home-load_demo', label: 'Load demo results', tab: 'rr_visualize_tab', landing: '#workspace-create_figure' },
] as const;

async function attach(info: TestInfo, name: string, value: unknown) {
  await info.attach(name, { body: JSON.stringify(value, null, 2), contentType: 'application/json' });
}

// The routed pane's own box can be zero-height (floated columns directly under the
// tab item), so the route is proven by its state and by visible content inside it.
async function expectTab(page: Page, tab: string) {
  const pane = page.locator(`#shiny-tab-${tab}`);
  await expect(pane).toHaveClass(/\bactive\b/);
  await expect(pane).toHaveAttribute('aria-hidden', 'false');
  await expect(page.locator('.tab-pane.active[id^="shiny-tab-"]')).toHaveCount(1);
  if (tab !== 'home_tab') await expect(page.locator('#shiny-tab-home_tab')).toBeHidden();
  await expect(pane.locator('*:visible').first()).toBeVisible();
}

// Narrow viewports use the off-canvas sidebar (AdminLTE below 768px), driven by the
// body.sidebar-open class; its slide transition must finish before the next decision.
const homeLink = (page: Page) => page.locator('.sidebar-menu a[href="#shiny-tab-home_tab"]');
const isNarrow = (page: Page) => (page.viewportSize()?.width ?? 1280) < 768;

async function waitSidebarClosed(page: Page) {
  await expect(page.locator('body.sidebar-open')).toHaveCount(0);
  await expect.poll(async () => {
    const bounds = await homeLink(page).boundingBox();
    return bounds ? bounds.x + bounds.width : Number.POSITIVE_INFINITY;
  }).toBeLessThanOrEqual(0);
}

async function openSidebar(page: Page) {
  if (isNarrow(page) && !(await page.locator('body.sidebar-open').count())) {
    await waitSidebarClosed(page);
    await page.getByRole('button', { name: /Toggle navigation/ }).click();
    await expect(page.locator('body.sidebar-open')).toHaveCount(1);
  }
  await homeLink(page).scrollIntoViewIfNeeded();
  await expect(homeLink(page)).toBeInViewport();
}

async function closeNavigation(page: Page) {
  if (await page.locator('body.sidebar-open').count()) {
    await page.getByRole('button', { name: /Toggle navigation/ }).click();
  }
  if (isNarrow(page)) await waitSidebarClosed(page);
}

// Sidebar route by its unchanged href; a collapsed group is expanded first.
async function openRoute(page: Page, tab: string, caption: RegExp) {
  await openSidebar(page);
  const href = `a[href="#shiny-tab-${tab}"]`;
  const link = page.locator(`.sidebar-menu ${href}`);
  if (!(await link.isVisible())) {
    await page.locator('.sidebar-menu li.treeview', { has: page.locator(href) }).locator(':scope > a').click();
  }
  await expect(link).toHaveText(caption);
  await link.click();
  await closeNavigation(page);
  await expectTab(page, tab);
}

async function tabTo(page: Page, id: string): Promise<number> {
  await page.evaluate(() => (document.activeElement as HTMLElement | null)?.blur());
  for (let presses = 1; presses <= 120; presses++) {
    await page.keyboard.press('Tab');
    if (await page.evaluate(() => document.activeElement?.id ?? '') === id) return presses;
  }
  throw new Error(`Keyboard focus never reached #${id}`);
}

async function chooseSelectize(page: Page, id: string, value: string) {
  const control = page.locator(`#${id} + .selectize-control`);
  await control.locator('.selectize-input').click();
  await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  await expect(page.locator(`#${id}`)).toHaveValue(value);
}

async function axeScan(page: Page, info: TestInfo, name: string, include: string[]) {
  const asset = requireLocal.resolve('axe-core/axe.min.js');
  const metadata = requireLocal('axe-core/package.json') as { name: string; version: string };
  expect(metadata).toMatchObject({ name: 'axe-core', version: '4.14.0' });
  await page.addScriptTag({ path: asset });
  const options: RunOptions = { reporter: 'v2', resultTypes: ['violations'] };
  const scan = await page.evaluate(async ({ include, options }) => {
    const axe = (window as unknown as { axe: { version: string; run(context: unknown, options: RunOptions): Promise<AxeResults> } }).axe;
    return { version: axe.version, results: await axe.run({ include: include.map(selector => [selector]) }, options) };
  }, { include, options });
  await attach(info, name, { project: info.project.name, url: page.url(), include, options, version: scan.version, violations: scan.results.violations });
  expect(scan.results.violations).toEqual([]);
}

for (const action of homeActions) {
  test(`REQ-001 AC-001 keyboard Tab and Enter activate ${action.label} with visible focus`, async ({ page }, info) => {
    const button = page.locator(`#${action.id}`);
    await expect(button).toHaveText(action.label);
    await expect(button).toBeEnabled();
    const presses = await tabTo(page, action.id);
    await expect(button).toBeFocused();
    await expect(button).toBeInViewport();
    const focus = await button.evaluate(element => {
      const style = getComputedStyle(element);
      return { focusVisible: element.matches(':focus-visible'), outlineStyle: style.outlineStyle,
        outlineWidth: style.outlineWidth, boxShadow: style.boxShadow };
    });
    await attach(info, `focus-${action.id}`, { project: info.project.name, presses, ...focus });
    expect(focus.focusVisible).toBe(true);
    expect((focus.outlineStyle !== 'none' && focus.outlineWidth !== '0px') || focus.boxShadow !== 'none').toBe(true);
    await page.keyboard.press('Enter');
    await expectTab(page, action.tab);
    await expect(page.locator('#shiny-tab-home_tab')).toBeHidden();
    await expect(page.locator(action.landing)).toBeVisible();
    if (action.id === 'home-open_saved') {
      await expect(page.locator('#save-load_session_file-label')).toBeVisible();
    }
    if (action.id === 'home-load_demo') {
      await expect(page.locator('#workspace-active_result')).toHaveValue('go1');
    } else {
      // Demo data load only after the demo action.
      await expect(page.locator('#workspace-summary')).toContainText('No dataset selected');
      await expect(page.locator('#workspace-active_result option')).toHaveCount(1);
    }
  });
}

test('REQ-001 collapsed navigation reaches Home and Save/Load through relabelled routes', async ({ page }, info) => {
  if (info.project.name === 'chromium-narrow') {
    await expect(page.getByRole('button', { name: /Toggle navigation/ })).toBeVisible();
  }
  await openRoute(page, 'save_tab', /Save\/Load/);
  await expect(page.locator('#save-load_session')).toBeVisible();
  await openRoute(page, 'home_tab', /Home/);
  await expect(page.getByRole('heading', { name: 'Welcome to richStudio' })).toBeVisible();
  await expect(page.locator('#home-open_saved')).toBeVisible();
  await openSidebar(page);
  await expect(page.locator('.sidebar-menu a[href="#shiny-tab-rr_visualize_tab"]')).toHaveText(/Enrichment figures/);
  await expect(page.locator('.sidebar-menu a[href="#shiny-tab-clus_visualize_tab"]')).toHaveText(/Cluster figures/);
  await closeNavigation(page);
});

test('REQ-002 REQ-003 REQ-004 AC-002 AC-003 S8r demo, dataset change, Create figure and continuity', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  const select = page.locator('#workspace-active_result');
  const summary = page.locator('#workspace-summary');

  // S8r: nothing is selected before the demo action.
  await expect(summary).toContainText('No dataset selected');
  await expect(select).toHaveValue('');
  await expect(page.locator('#workspace-active_result option:checked')).toHaveText('Choose a result');
  await expect(page.locator('#workspace-create_figure')).toBeDisabled();
  await expect(page.locator('#workspace-cluster_results')).toBeDisabled();

  await page.locator('#home-load_demo').click();
  await expectTab(page, 'rr_visualize_tab');
  await expect(select).toHaveValue('go1');
  await expect(summary).toContainText('go1');

  await select.selectOption('kegg1');
  await expect(summary).toContainText('kegg1');
  await expect(summary).toContainText('Recorded organism');
  await expect(summary).toContainText('Recorded identifier type');

  // Activating the demo again keeps the user's choice.
  await openRoute(page, 'home_tab', /Home/);
  await page.locator('#home-load_demo').click();
  await expectTab(page, 'rr_visualize_tab');
  await expect(select).toHaveValue('kegg1');
  await expect(summary).toContainText('kegg1');

  // AC-002: imported-only results reach an enrichment figure without analysis.
  await page.locator('#workspace-create_figure').click();
  await expectTab(page, 'rr_visualize_tab');
  await expect(page.locator('#rr_visualize-select_bar')).toHaveValue('kegg1');
  await expect(page.locator('#rr_visualize-select_dot')).toHaveValue('kegg1');
  await page.locator('#shiny-tab-rr_visualize_tab a[data-toggle="tab"][data-value="Bar Plot"]').click();
  await expect(page.locator('#rr_visualize-barplot .main-svg').first()).toBeVisible();

  // AC-003: valid settings survive a round trip through clustering.
  await chooseSelectize(page, 'rr_visualize-select_bar', 'go2');
  await chooseSelectize(page, 'rr_visualize-bar_type', 'value');
  await chooseSelectize(page, 'rr_visualize-bar_valtype', 'Pvalue');
  await page.locator('#workspace-cluster_results').click();
  await expectTab(page, 'cluster_tab');
  await openRoute(page, 'rr_visualize_tab', /Enrichment figures/);
  const settings = {
    select_bar: await page.locator('#rr_visualize-select_bar').inputValue(),
    bar_type: await page.locator('#rr_visualize-bar_type').inputValue(),
    bar_valtype: await page.locator('#rr_visualize-bar_valtype').inputValue(),
  };
  await attach(info, 'continuity-settings', { project: info.project.name, settings });
  expect(settings).toEqual({ select_bar: 'go2', bar_type: 'value', bar_valtype: 'Pvalue' });
  await expect(select).toHaveValue('kegg1');
  expect(errors).toEqual([]);
});

test('REQ-001 REQ-003 M15 axe reports no violations on Home and on the populated header', async ({ page }, info) => {
  await expect(page.locator('#workspace-summary')).toContainText('No dataset selected');
  await axeScan(page, info, 'axe-home', ['#shiny-tab-home_tab', '#workspace-header']);
  await page.locator('#home-load_demo').click();
  await expectTab(page, 'rr_visualize_tab');
  await expect(page.locator('#workspace-summary')).toContainText('go1');
  await expect(page.locator('#workspace-create_figure')).toBeEnabled();
  await axeScan(page, info, 'axe-header', ['#workspace-header']);
});
