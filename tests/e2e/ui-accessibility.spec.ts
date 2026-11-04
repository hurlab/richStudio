import { test, expect } from './fixtures';
import type { Page } from '@playwright/test';

// SPEC-WS-013 M1: AC-003 (browser part), AC-004, AC-005, AC-006. Facts are read from computed styles
// and the DOM in both Playwright projects; nothing is inferred from the CSS text.

const TABS = ['home_tab', 'enrich_tab', 'rr_visualize_tab', 'cluster_upload_tab', 'cluster_tab',
  'clus_visualize_tab', 'update_tab', 'save_tab'];

async function connected(page: Page) {
  await expect.poll(() => page.evaluate(() => !!(window as any).Shiny?.shinyapp?.isConnected())).toBe(true);
  await page.evaluate(() => document.fonts.ready);
}

async function showTab(page: Page, tab: string) {
  await page.locator(`a[href="#shiny-tab-${tab}"]`).evaluate(link => (link as HTMLElement).click());
  await expect(page.locator(`#shiny-tab-${tab}`)).toHaveClass(/\bactive\b/);
}

async function loadDemo(page: Page) {
  await connected(page);
  await page.locator('#home-load_demo').click();
  await expect(page.locator('#workspace-active_result')).toHaveValue('go1');
}

// Colour helpers run in the page so the numbers are the browser's computed values.
const colourTools = `
  const parse = (value) => {
    const m = value.match(/rgba?\\(([^)]+)\\)/);
    if (!m) return [0, 0, 0, 0];
    const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
    return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1];
  };
  const over = (top, under) => {
    const a = top[3] + under[3] * (1 - top[3]);
    if (a === 0) return [255, 255, 255, 1];
    return [0, 1, 2].map(i => (top[i] * top[3] + under[i] * under[3] * (1 - top[3])) / a).concat([a]);
  };
  const background = (element) => {
    let layers = [];
    for (let node = element; node; node = node.parentElement) {
      const c = parse(getComputedStyle(node).backgroundColor);
      if (c[3] > 0) layers.push(c);
      if (c[3] === 1) break;
    }
    let result = [255, 255, 255, 1];
    for (let i = layers.length - 1; i >= 0; i--) result = over(layers[i], result);
    return result;
  };
  const lum = (c) => {
    const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]);
  };
  const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
`;

test.describe('AC-003 disabled controls and the unrecorded-metadata disclosure', () => {
  test('disabled header actions look disabled, say why once, and metadata is one disclosure', async ({ page }) => {
    await connected(page);
    // Results exist but none is the active dataset: both header actions are disabled.
    await page.locator('a[href="#shiny-tab-rr_visualize_tab"]').evaluate(l => (l as HTMLElement).click());
    await page.locator('#rr_visualize-rr_load').click();
    await expect(page.locator('#workspace-create_figure')).toBeDisabled();

    const found = await page.evaluate(() => {
      const visible = (e: Element) => (e as HTMLElement).offsetParent !== null || getComputedStyle(e).position === 'fixed';
      return Array.from(document.querySelectorAll('button:disabled, input:disabled, select:disabled, [aria-disabled="true"]'))
        .filter(visible).map(e => {
          const s = getComputedStyle(e);
          return { id: (e as HTMLElement).id, opacity: Number(s.opacity), cursor: s.cursor, color: s.color,
            background: s.backgroundColor, border: s.borderTopColor,
            reason: !!(e.getAttribute('title') || e.getAttribute('aria-describedby')) };
        }).filter(x => !x.id.endsWith('-selectized'));
    });
    expect(found.length).toBeGreaterThanOrEqual(2);
    for (const control of found) {
      // Disabled is shown by explicit colours (opacity is not used: the SPEC-WS-002 guard refuses it).
      expect(control.cursor, control.id).toBe('not-allowed');
      if (!/^DataTables_Table_/.test(control.id)) {
        expect(control.background, control.id).toBe('rgb(226, 232, 240)');
        expect(control.color, control.id).toBe('rgb(71, 85, 105)');
      }
      // A disabled DataTables Previous/Next link is third-party and self-evident; it must still look disabled.
      if (!/^DataTables_Table_\d+_(previous|next)$/.test(control.id)) expect(control.reason, control.id).toBe(true);
    }
    // Distinct from an enabled button: different computed surface and text colour.
    const look = (selector: string) => page.locator(selector).evaluate(e => { const s = getComputedStyle(e);
      return { color: s.color, background: s.backgroundColor, border: s.borderTopColor }; });
    const disabledLook = await look('#workspace-create_figure');
    const enabledLook = await look('#rr_visualize-rr_load');
    await test.info().attach('enabled-vs-disabled-colours', { body: JSON.stringify({ enabledLook, disabledLook }), contentType: 'application/json' });
    expect(disabledLook.background).not.toBe(enabledLook.background);
    expect(disabledLook.color).not.toBe(enabledLook.color);
    await expect(page.locator('#workspace-create_figure')).toHaveAttribute('title', /Choose a result first/);
    // The hint is shown once, not once per button.
    await expect(page.locator('#workspace-header').getByText('Choose a result first', { exact: true })).toHaveCount(1);
    await expect(page.locator('#workspace-actions-reason')).toBeVisible();

    // Three unrecorded fields (the demo carries no run, organism or identifier type): a new session.
    await page.reload();
    await connected(page);
    await page.locator('#home-load_demo').click();
    await expect(page.locator('#workspace-active_result')).toHaveValue('go1');
    const header = page.locator('#workspace-header');
    const trigger = header.locator('summary');
    await expect(trigger).toHaveCount(1);
    await expect(trigger).toBeVisible();
    await expect(trigger).toHaveAccessibleName(/3 not recorded/);
    await expect(header.getByText('Not recorded', { exact: true }).locator('visible=true')).toHaveCount(0);
    await trigger.click();
    await expect(header.getByText('Not recorded', { exact: true }).locator('visible=true')).toHaveCount(3);
  });
});

test.describe('AC-004 visible focus', () => {
  test('sidebar links, the Bookmark control, buttons and text inputs show a 3:1 outline of at least 2 px', async ({ page }) => {
    await loadDemo(page);
    if ((page.viewportSize()?.width ?? 1280) <= 767 && !(await page.locator('body.sidebar-open').count())) {
      await page.locator('.sidebar-toggle').click();
      await expect(page.locator('body.sidebar-open')).toHaveCount(1);
    }
    await page.keyboard.press('Tab');
    const targets: Array<[string, string]> = [
      ['sidebar link', '.sidebar-menu a[href="#shiny-tab-save_tab"]'],
      ['sidebar sub link', '.sidebar-menu a[href="#shiny-tab-enrich_tab"]'],
      ['bookmark', '[id="._bookmark_"]'],
    ];
    const measure = async (selector: string) => {
      await page.locator(selector).first().focus();
      return page.evaluate((sel) => {
        const element = document.querySelector(sel) as HTMLElement;
        const focused = document.activeElement === element;
        const style = getComputedStyle(element);
        const outline = { focused, style: style.outlineStyle, width: parseFloat(style.outlineWidth), colour: style.outlineColor };
        // eslint-disable-next-line no-new-func
        const tools = new Function(`${(window as any).__colourTools} return { parse, background, ratio };`)();
        const adjacent = tools.background(element.parentElement);
        const colour = tools.parse(outline.colour);
        return { ...outline, contrast: tools.ratio(colour, adjacent) };
      }, selector);
    };
    await page.evaluate((tools) => { (window as any).__colourTools = tools; }, colourTools);
    const results: Record<string, unknown> = {};
    for (const [name, selector] of targets) {
      const r = await measure(selector);
      results[name] = r;
      expect(r.focused, name).toBe(true);
      expect(r.style, name).not.toBe('none');
      expect(r.width, name).toBeGreaterThanOrEqual(2);
      expect(r.contrast, name).toBeGreaterThanOrEqual(3);
    }
    // A button and a text input on pages that show them.
    await showTab(page, 'home_tab');
    if (await page.locator('body.sidebar-open').count()) await page.locator('.sidebar-toggle').click();
    for (const [name, tab, selector] of [
      ['button', 'home_tab', '#home-upload_gene_lists'],
      ['text input', 'update_tab', '#update-new_deg_name'],
      ['select input', 'cluster_tab', '#cluster-cluster_name'],
    ] as Array<[string, string, string]>) {
      await showTab(page, tab);
      const r = await measure(selector);
      expect(r.focused, name).toBe(true);
      expect(r.style, name).not.toBe('none');
      expect(r.width, name).toBeGreaterThanOrEqual(2);
      expect(r.contrast, name).toBeGreaterThanOrEqual(3);
    }
  });
});

test.describe('AC-005 text size and contrast', () => {
  test('help text, sidebar section headers and the footer are at least 13 px and 4.5:1', async ({ page }) => {
    await loadDemo(page);
    await page.evaluate((tools) => { (window as any).__colourTools = tools; }, colourTools);
    const failures: string[] = [];
    let measured = 0;
    for (const tab of TABS) {
      await showTab(page, tab);
      const rows = await page.evaluate(() => {
        // eslint-disable-next-line no-new-func
        const tools = new Function(`${(window as any).__colourTools} return { parse, background, ratio };`)();
        const nodes = Array.from(document.querySelectorAll(
          '.help-block, .sidebar-menu .header, .sidebar-footer .lab-name, .sidebar-footer .lab-dept, .sidebar-footer a'));
        return nodes.filter(n => {
          const r = n.getBoundingClientRect();
          return r.width > 0 && r.height > 0 && getComputedStyle(n).visibility !== 'hidden' && (n.textContent || '').trim().length > 0;
        }).map(n => {
          const s = getComputedStyle(n);
          return { name: `${n.className || n.tagName}: ${(n.textContent || '').trim().slice(0, 30)}`,
            size: parseFloat(s.fontSize), ratio: tools.ratio(tools.parse(s.color), tools.background(n)) };
        });
      });
      for (const row of rows) {
        measured += 1;
        if (row.size < 13) failures.push(`${tab} ${row.name} font ${row.size}px`);
        if (row.ratio < 4.5) failures.push(`${tab} ${row.name} contrast ${row.ratio.toFixed(2)}`);
      }
    }
    expect(measured).toBeGreaterThan(10);
    expect(failures).toEqual([]);
  });
});

test.describe('AC-006 one job-status live region', () => {
  test('exactly one app-authored aria-live node, no role=log, and every other live node is listed', async ({ page }) => {
    await loadDemo(page);
    // Origins that may carry a live attribute besides the job-status region. Shiny adds
    // aria-live="polite" to every bound output and updated input that does not set its own, so those
    // nodes are framework-added, not app-authored; the explorer selection output is set to off explicitly.
    const listed: Array<[string, string]> = [
      ['.workflow-stepper', 'Home Quick Start result message (app-authored, not job status)'],
      ['.shiny-bound-output', 'Shiny output binding (framework-added polite)'],
      ['.shiny-bound-input', 'Shiny input binding (framework-added polite)'],
      ['.shiny-notification', 'Shiny notification panel'],
      ['.dataTables_info', 'DataTables row-count status (third-party widget)'],
      ['.dataTables_wrapper', 'DataTables widget (third-party)'],
      ['.plotly', 'plotly widget (third-party)'],
      ['.selectize-control', 'selectize widget (third-party)'],
    ];
    const collect = () => page.evaluate((selectors) => Array.from(document.querySelectorAll(
      '[aria-live]:not([aria-live="off"]), [role="status"], [role="alert"], [role="log"], [role="alertdialog"], output')).map(e => ({
      id: e.id, cls: String((e as HTMLElement).className), live: e.getAttribute('aria-live'), role: e.getAttribute('role'),
      insideJobs: !!e.closest('section[aria-label="Analysis jobs"]'),
      plugin: e.parentElement === document.body && e.getAttribute('role') === 'log' && !e.id && !(e as HTMLElement).className,
      origin: selectors.find(sel => !!e.closest(sel)) || null,
    })), listed.map(l => l[0]));

    const verify = async (label: string) => {
      const live = await collect();
      const jobLive = live.filter(n => n.insideJobs && n.live && n.live !== 'off');
      expect(jobLive.map(n => n.id), `${label}: job live regions`).toEqual(['jobs-jobs_announce']);
      // No app-authored role=log: the server-sent page has none, and the role=log nodes found at runtime are the
      // selectize accessibility plugin's body-level announcers (no id, no class, direct children of body).
      const logs = await page.evaluate(() => Array.from(document.querySelectorAll('[role="log"]')).map(e => ({
        parentIsBody: e.parentElement === document.body, id: e.id, cls: String((e as HTMLElement).className) })));
      expect(logs.filter(n => !(n.parentIsBody && !n.id && !n.cls)), `${label}: role=log not from the selectize plugin`).toEqual([]);
      const served = await (await page.request.get('/')).text();
      expect(served.includes('role="log"'), `${label}: server-sent role=log`).toBe(false);
      // The explorer selection region is not live.
      const selected = page.locator('#rr_visualize-ex_selected');
      if (await selected.count()) await expect(selected).toHaveAttribute('aria-live', 'off');
      expect(await page.locator('#rr_visualize-ex_selected [aria-live]').count()).toBe(0);
      const unlisted = live.filter(n => !n.insideJobs && !n.origin && !n.plugin)
        .map(n => `${n.id || n.cls || n.role} live=${n.live} role=${n.role}`);
      expect(unlisted, `${label}: unlisted live nodes`).toEqual([]);
    };

    await verify('idle');
    // With the Results explorer open and a selection made, the explorer selection region is not live.
    await showTab(page, 'rr_visualize_tab');
    await expect(page.locator('#rr_visualize-ex_result')).toBeAttached();
    await verify('results page');
    // With a job queued or running (a clustering run) the same single region is the only job live node.
    await showTab(page, 'cluster_tab');
    const select = page.locator('#cluster-selected_rrs + .selectize-control');
    for (const value of ['go1', 'go2']) {
      await select.locator('.selectize-input').click();
      await select.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
    }
    await page.keyboard.press('Escape');
    await page.locator('#cluster-cluster_name').fill('live_check');
    await page.locator('#cluster-cluster').click();
    await expect(page.locator('section[aria-label="Analysis jobs"] .rs-job')).toHaveCount(1, { timeout: 30_000 });
    await verify('job present');
  });
});
