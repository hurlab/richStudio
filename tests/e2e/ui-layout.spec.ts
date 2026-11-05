import { test, expect } from './fixtures';
import type { Page } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

// SPEC-WS-013 M3: AC-011 (one box style, red and green only for states) and AC-012 (no transition: all,
// no empty Home strip, reduced motion). Facts come from computed styles in both Playwright projects.

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
async function choose(page: Page, id: string, value: string) {
  await expect.poll(() => page.locator(`#${id}`).evaluate((node, wanted) =>
    !!(node as any).selectize?.options[wanted], value)).toBe(true);
  const control = page.locator(`#${id} + .selectize-control`);
  await control.locator('.selectize-input').click();
  await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  await page.keyboard.press('Escape');
}

test.describe('AC-011 one box style and semantic colours', () => {
  test('box headers share one style and red/green appear only on destructive, error or success elements', async ({ page }) => {
    await connected(page);
    await page.locator('#home-load_demo').click();
    await expect(page.locator('#workspace-active_result')).toHaveValue('go1');
    await showTab(page, 'update_tab');
    await page.locator('#enrich-deg_load').click();
    await showTab(page, 'cluster_tab');
    await choose(page, 'cluster-selected_rrs', 'go1');
    await choose(page, 'cluster-selected_rrs', 'go2');
    await page.locator('#cluster-cluster_name').fill('clus1');
    await page.locator('#cluster-cluster').click();
    await expect(page.locator('section[aria-label="Analysis jobs"] .rs-job')).toHaveCount(1, { timeout: 30_000 });
    await expect(page.locator('.rs-job[data-state="queued"], .rs-job[data-state="running"]')).toHaveCount(0, { timeout: 120_000 });

    const headerStyles = new Set<string>();
    const topBorders = new Set<string>();
    const colourUses: string[] = [];
    // Elements that may carry the danger or success colour, named by class or role.
    const allowedDanger = ['.btn-danger', '.shiny-notification-error', '[role="alert"]', '.rs-workspace-status-failed',
      '.has-error', '.shiny-output-error', '.rs-workspace-error', '.shiny-input-container.has-error'];
    const allowedSuccess = ['.rs-workspace-status-succeeded', '.shiny-notification-success'];
    for (const tab of TABS) {
      await showTab(page, tab);
      const found = await page.evaluate(({ allowedDanger, allowedSuccess }) => {
        const root = getComputedStyle(document.documentElement);
        const norm = (v: string) => { const e = document.createElement('i'); e.style.color = v.trim(); document.body.appendChild(e);
          const c = getComputedStyle(e).color; e.remove(); return c; };
        const danger = norm(root.getPropertyValue('--rs-danger')), success = norm(root.getPropertyValue('--rs-success'));
        const visible = (e: Element) => (e as HTMLElement).offsetParent !== null || getComputedStyle(e).position === 'fixed';
        const headers = Array.from(document.querySelectorAll('.box > .box-header')).filter(visible)
          .filter(h => !/\bbox-(danger|warning)\b/.test((h.parentElement as HTMLElement).className)).map(h => {
            const s = getComputedStyle(h), t = getComputedStyle(h.querySelector('.box-title') || h);
            const b = getComputedStyle(h.parentElement as HTMLElement);
            return { header: [s.backgroundColor, s.borderBottomColor, s.borderBottomWidth].join('|'),
              title: [t.fontFamily, t.fontSize, t.fontWeight, t.color].join('|'),
              top: [b.borderTopColor, b.borderTopWidth].join('|') };
          });
        const uses: string[] = [];
        for (const e of Array.from(document.querySelectorAll('body *')).filter(visible)) {
          const s = getComputedStyle(e);
          const colours = [s.backgroundColor, s.borderTopColor, s.borderRightColor, s.borderBottomColor, s.borderLeftColor];
          const hasWidth = (side: string) => parseFloat((s as any)[side]) > 0;
          const hits: string[] = [];
          if (s.backgroundColor === danger) hits.push('danger');
          if (s.backgroundColor === success) hits.push('success');
          if (s.borderTopStyle !== 'none') {
            const sides: Array<[string, string]> = [['borderTopColor', 'borderTopWidth'], ['borderRightColor', 'borderRightWidth'],
              ['borderBottomColor', 'borderBottomWidth'], ['borderLeftColor', 'borderLeftWidth']];
            for (const [c, w] of sides) { if ((s as any)[c] === danger && hasWidth(w)) hits.push('danger'); if ((s as any)[c] === success && hasWidth(w)) hits.push('success'); }
          }
          void colours;
          for (const kind of new Set(hits)) {
            const list = kind === 'danger' ? allowedDanger : allowedSuccess;
            if (!list.some(sel => e.closest(sel))) uses.push(`${kind}: ${e.tagName.toLowerCase()}.${String((e as HTMLElement).className).slice(0, 60)} "${(e.textContent || '').trim().slice(0, 30)}"`);
          }
        }
        return { headers, uses };
      }, { allowedDanger, allowedSuccess });
      for (const h of found.headers) { headerStyles.add(`${h.header} || ${h.title}`); topBorders.add(h.top); }
      colourUses.push(...found.uses.map(u => `${tab}: ${u}`));
    }
    expect(headerStyles.size, `distinct box header styles: ${JSON.stringify([...headerStyles])}`).toBe(1);
    expect(topBorders.size, `distinct box top borders: ${JSON.stringify([...topBorders])}`).toBe(1);
    expect(colourUses, 'danger or success colour on an element that is not a destructive, error or success state').toEqual([]);
  });
});

test.describe('AC-012 motion and the Home strip', () => {
  test('custom.css has no transition: all', async () => {
    const css = fs.readFileSync(path.resolve(__dirname, '../../inst/application/www/custom.css'), 'utf8');
    expect(css.match(/transition\s*:\s*all\b/g) || []).toEqual([]);
  });

  test('an empty Home renders no empty bordered status strip', async ({ page }) => {
    await connected(page);
    const strips = await page.evaluate(() => Array.from(document.querySelectorAll('#shiny-tab-home_tab *')).filter(e => {
      const s = getComputedStyle(e), r = e.getBoundingClientRect();
      const bordered = ['Top', 'Right', 'Bottom', 'Left'].some(x => parseFloat((s as any)[`border${x}Width`]) > 0 && (s as any)[`border${x}Style`] !== 'none');
      return r.width > 0 && r.height > 0 && bordered && (e.textContent || '').trim() === '' &&
        !e.querySelector('img, svg, input, button, i, canvas') && !['HR', 'INPUT', 'BUTTON'].includes(e.tagName);
    }).map(e => `${e.tagName.toLowerCase()}#${e.id}.${String((e as HTMLElement).className)}`));
    expect(strips).toEqual([]);
    const status = page.locator('#home-demo_status');
    if (await status.count()) await expect(status).toHaveText('');
  });

  test('with reduced motion the menu and notification transitions last at most 0.01 s', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await connected(page);
    await page.evaluate(() => (window as any).Shiny.notifications.show({ id: 'motion-check', html: 'Check', action: '', deps: [], duration: null, type: 'message' }));
    await expect(page.locator('#shiny-notification-motion-check')).toBeVisible();
    if ((page.viewportSize()?.width ?? 1280) <= 767) {
      await page.getByRole('button', { name: /Toggle navigation/ }).click();
      await expect(page.locator('body.sidebar-open')).toHaveCount(1);
    }
    const selectors = ['.main-sidebar', '.content-wrapper', '.main-header', '.sidebar-menu > li > a',
      '.sidebar-menu .treeview-menu > li > a', '#shiny-notification-motion-check', '.shiny-notification'];
    const slow = await page.evaluate((sels) => sels.flatMap(sel => Array.from(document.querySelectorAll(sel)).slice(0, 3).flatMap(e => {
      const s = getComputedStyle(e);
      const longest = Math.max(...s.transitionDuration.split(',').map(x => parseFloat(x) * (x.trim().endsWith('ms') ? 0.001 : 1)));
      return longest > 0.01 ? [`${sel}: ${s.transitionDuration}`] : [];
    })), selectors);
    expect(slow).toEqual([]);
  });
});

// ---- M5: context bar (AC-014) and layout (AC-016) -----------------------------------------------

const VIEWPORTS = [{ name: 'desktop', width: 1440, height: 900, bar: 56 }, { name: 'narrow', width: 390, height: 844, bar: 64 }];

async function populated(page: Page) {
  await connected(page);
  await page.locator('#home-load_demo').click();
  await expect(page.locator('#workspace-active_result')).toHaveValue('go1');
}

for (const vp of VIEWPORTS) {
  test.describe(`AC-014 context bar at ${vp.width}x${vp.height}`, () => {
    test('exactly one compact context bar on Enrich, Results and Cluster, none on Home and Save, and Cluster passes the active result', async ({ page }) => {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await populated(page);
      for (const tab of ['enrich_tab', 'rr_visualize_tab', 'cluster_tab']) {
        await showTab(page, tab);
        const bars = page.locator('.rs-context-bar');
        await expect(bars.locator('visible=true'), `${tab} bars`).toHaveCount(1);
        const box = await bars.first().boundingBox();
        expect(box!.height, `${tab} bar height`).toBeLessThanOrEqual(vp.bar);
        await expect(page.locator('#workspace-active_result'), `${tab} dataset`).toHaveValue('go1');
        await expect(bars.first().getByText('Not recorded', { exact: true }).locator('visible=true')).toHaveCount(0);
        const trigger = bars.first().locator('summary').first();
        await expect(trigger).toBeVisible();
        await expect(trigger).toHaveAccessibleName(/\d+ not recorded/);
        // the former active-workspace card is gone
        await expect(page.locator('section[aria-label="Active workspace"]')).toHaveCount(0);
      }
      for (const tab of ['home_tab', 'save_tab']) {
        await showTab(page, tab);
        await expect(page.locator('.rs-context-bar').locator('visible=true'), `${tab} bar`).toHaveCount(0);
      }
      // Cluster from the context bar opens the Cluster step with the active result selected.
      await showTab(page, 'rr_visualize_tab');
      if (await page.locator('.rs-context-toggle').isVisible()) await page.locator('.rs-context-toggle').click();
      await page.locator('#workspace-cluster_results').click();
      await expect(page.locator('#shiny-tab-cluster_tab')).toHaveClass(/\bactive\b/);
      await expect.poll(() => page.locator('#cluster-selected_rrs').evaluate(el =>
        Array.from((el as HTMLSelectElement).selectedOptions).map(o => o.value))).toEqual(['go1']);
    });
  });
}

// A finished clustering job puts the job badge into the bar; the collapsed bar must still fit its limit.
for (const vp of VIEWPORTS) {
  test.describe(`AC-014 context bar with a job at ${vp.width}x${vp.height}`, () => {
    test('the collapsed bar stays within its height limit with the job badge showing, and the badge keeps a 36 px hit area', async ({ page }) => {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await populated(page);
      await showTab(page, 'cluster_tab');
      await choose(page, 'cluster-selected_rrs', 'go1');
      await choose(page, 'cluster-selected_rrs', 'go2');
      await page.locator('#cluster-cluster_name').fill('clus1');
      await page.locator('#cluster-cluster').click();
      const badge = page.locator('#jobs-job_badge');
      await expect(badge).toHaveText(/1 job (running|finished)/, { timeout: 30_000 });
      await expect(badge).toHaveText('1 job finished', { timeout: 120_000 });
      for (const tab of ['enrich_tab', 'rr_visualize_tab', 'cluster_tab']) {
        await showTab(page, tab);
        const bar = page.locator('.rs-context-bar').locator('visible=true');
        await expect(bar, `${tab} bar`).toHaveCount(1);
        const box = await bar.first().boundingBox();
        expect(box!.height, `${tab} bar height with a job`).toBeLessThanOrEqual(vp.bar);
        const hit = await badge.boundingBox();
        expect(hit!.height, `${tab} badge height`).toBeGreaterThanOrEqual(36);
        expect(hit!.width, `${tab} badge width`).toBeGreaterThanOrEqual(36);
        const toggle = page.locator('.rs-context-toggle');
        if (vp.width < 768) {
          // The collapsed narrow bar keeps switcher, trigger, badge and toggle in one row.
          const toggleBox = await toggle.boundingBox();
          expect(toggleBox!.y, `${tab} toggle on the first row`).toBeLessThan(box!.y + 50);
          const style = await toggle.evaluate(e => { const c = getComputedStyle(e); return { colour: c.color, border: c.borderTopColor }; });
          // The toggle is a secondary button like the others, not a greyed-out control.
          expect(style.colour, `${tab} toggle text colour`).toBe('rgb(30, 41, 59)');
          expect(style.border, `${tab} toggle border colour`).toBe('rgb(100, 116, 139)');
        }
      }
      // The badge words the server writes for other job mixes (AC-015: one running and two finished jobs says
      // "1 job running"; two running jobs say "2 jobs running"; a queue is worded compactly as "2 running, 1 queued"). The layout is measured
      // with each text in place of the finished one, on every page that carries the bar.
      for (const tab of ['enrich_tab', 'rr_visualize_tab', 'cluster_tab']) {
        await showTab(page, tab);
        for (const words of ['1 job running', '2 jobs running', '2 running, 1 queued']) {
          await badge.evaluate((e, w) => { e.textContent = w; }, words);
          const box = await page.locator('.rs-context-bar').locator('visible=true').first().boundingBox();
          expect(box!.height, `${tab} bar height with "${words}"`).toBeLessThanOrEqual(vp.bar);
        }
      }
    });
  });
}

test.describe('AC-016 layout without the card and the inline job log', () => {
  for (const vp of [{ width: 1440, height: 900, top: 200 }, { width: 390, height: 844, top: 260 }]) {
    test(`Cluster form heading is within ${vp.top} px at ${vp.width}x${vp.height} and nothing overflows`, async ({ page }) => {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await populated(page);
      await showTab(page, 'cluster_tab');
      const heading = page.locator('#shiny-tab-cluster_tab').getByText('Cluster Enrichment Results', { exact: true }).first();
      await expect(heading).toBeVisible();
      await page.evaluate(() => window.scrollTo(0, 0));
      const top = (await heading.boundingBox())!.y;
      expect(top, 'form heading top').toBeLessThanOrEqual(vp.top);
      if (vp.width <= 400) {
        for (const tab of ['enrich_tab', 'rr_visualize_tab', 'cluster_tab']) {
          await showTab(page, tab);
          const widths = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
          expect(widths[0], `${tab} scrollWidth`).toBeLessThanOrEqual(widths[1]);
        }
      }
    });
  }
});

// ---- M6: navigation, Data step and Save (AC-019) ------------------------------------------------

async function finishedClusterJob(page: Page) {
  await showTab(page, 'cluster_tab');
  await choose(page, 'cluster-selected_rrs', 'go1');
  await choose(page, 'cluster-selected_rrs', 'go2');
  await page.locator('#cluster-cluster_name').fill('clus1');
  await page.locator('#cluster-cluster').click();
  await expect(page.locator('#jobs-job_badge')).toHaveText('1 job finished', { timeout: 120_000 });
}

test.describe('AC-019 navigation, Data step and Save', () => {
  test('the navigation is flat, no page claims a feature is unsupported, and the loaders live on Data', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await populated(page);
    await expect(page.locator('.sidebar-menu li.treeview')).toHaveCount(0);
    await expect(page.locator('.sidebar-menu')).not.toContainText(/Bookmark/);
    const routes = ['home_tab', 'update_tab', 'enrich_tab', 'rr_visualize_tab', 'cluster_upload_tab', 'cluster_tab', 'clus_visualize_tab', 'save_tab'];
    for (const tab of routes) {
      await showTab(page, tab);
      const text = await page.locator(`#shiny-tab-${tab}`).innerText();
      expect(text, `${tab} unsupported text`).not.toMatch(/not yet supported|currently not available|will be supported/i);
      expect(text, `${tab} file path text`).not.toMatch(/docs\/|\.md\b/);
      // The DEG upload on Data has a working "Text input" tab; the inert ones are gone everywhere else.
      if (tab !== 'update_tab') expect(await page.locator(`#shiny-tab-${tab} .nav-tabs a`).allInnerTexts(), `${tab} tabs`).not.toContain('Text input');
    }
    // The Results page no longer has the loader; Data has it with its ids unchanged.
    await showTab(page, 'rr_visualize_tab');
    await expect(page.locator('#shiny-tab-rr_visualize_tab #rr_visualize-rr_files')).toHaveCount(0);
    await showTab(page, 'update_tab');
    await expect(page.locator('#shiny-tab-update_tab #rr_visualize-rr_files')).toHaveCount(1);
    await expect(page.locator('#shiny-tab-update_tab').getByRole('heading', { name: 'Data', exact: true })).toBeVisible();
    // Cluster figures has no "Load cluster result" panel; the importer route is reachable and accepts a file.
    await showTab(page, 'clus_visualize_tab');
    await expect(page.getByText('Load cluster result')).toHaveCount(0);
    await showTab(page, 'cluster_upload_tab');
    await expect(page.locator('#cluster_upload-rr_files')).toHaveCount(1);
    await expect(page.locator('#shiny-tab-cluster_upload_tab')).toHaveClass(/\bactive\b/);
    // Share link sits in the page footer, not in the primary navigation.
    await expect(page.locator('footer.rs-page-footer').getByText('Share link')).toBeVisible();
  });

  test('Save has one primary Save project action and the JSON session sits inside Advanced', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await populated(page);
    await showTab(page, 'save_tab');
    const save = page.locator('#save-download_project');
    await expect(save).toBeVisible();
    await expect(save).toContainText('Save project');
    const download = page.waitForEvent('download');
    await save.click();
    expect((await download).suggestedFilename()).toMatch(/^richstudio_project_.*\.zip$/);
    const advanced = page.locator('#shiny-tab-save_tab details').filter({ hasText: 'Advanced' });
    await expect(advanced).toHaveCount(1);
    expect(await advanced.evaluate(d => (d as HTMLDetailsElement).open)).toBe(false);
    await expect(page.locator('#save-download_session')).not.toBeVisible();
    await advanced.locator('summary').click();
    await expect(page.locator('#save-download_session')).toBeVisible();
  });
});

for (const vp of [{ width: 1440, height: 900, top: 300 }, { width: 390, height: 844, top: 420 }]) {
  test.describe(`AC-019 Data step layout at ${vp.width}x${vp.height}`, () => {
    test('the DEG upload control is near the top with a context bar, with a finished job present and no overflow', async ({ page }) => {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await populated(page);
      await finishedClusterJob(page);
      await showTab(page, 'update_tab');
      await expect(page.locator('.rs-context-bar').locator('visible=true')).toHaveCount(1);
      const upload = page.locator('#enrich-deg_files');
      await expect(page.locator('#enrich-deg_files-label')).toBeVisible();
      await page.evaluate(() => window.scrollTo(0, 0));
      const top = (await page.locator('#enrich-deg_files').locator('xpath=ancestor::div[contains(@class,"form-group")][1]').boundingBox())!.y;
      expect(top, 'DEG upload control top').toBeLessThanOrEqual(vp.top);
      expect(await upload.count()).toBe(1);
      const widths = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
      expect(widths[0], 'scrollWidth').toBeLessThanOrEqual(widths[1]);
    });
  });
}

// ---- M7: Enrich progressive disclosure (AC-020) -------------------------------------------------

for (const vp of [{ width: 1440, height: 900, bar: 300, height_max: 1350 }, { width: 390, height: 844, bar: 420, height_max: 2110 }]) {
  test.describe(`AC-020 Enrich at ${vp.width}x${vp.height}`, () => {
    test('plain by default, the run bar stays near the top of the viewport at every scroll position, and the page is short', async ({ page }) => {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await populated(page);
      await showTab(page, 'update_tab');
      await page.locator('#enrich-deg_load').click();
      await finishedClusterJob(page);
      await showTab(page, 'enrich_tab');
      await page.evaluate(() => window.scrollTo(0, 0));
      for (const term of ['Commit input revision', 'Source digest', 'Stored rows', 'P-value role', 'Preview — not committed', 'keytype']) {
        await expect(page.locator('#shiny-tab-enrich_tab').getByText(term).locator('visible=true'), `"${term}" is visible by default`).toHaveCount(0);
      }
      await expect(page.locator('#enrich-run_summary')).toBeVisible();
      await expect(page.locator('#shiny-tab-enrich_tab .rs-adjust > summary')).toBeVisible();
      await expect(page.locator('#shiny-tab-enrich_tab .rs-adjust > summary')).toContainText('Adjust');
      expect(await page.locator('#shiny-tab-enrich_tab details[open]').count(), 'no disclosure open by default').toBe(0);
      const height = await page.evaluate(() => document.documentElement.scrollHeight);
      expect(height, 'scroll height before expanding Adjust or Advanced').toBeLessThanOrEqual(vp.height_max);
      const widths = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
      expect(widths[0], 'scrollWidth').toBeLessThanOrEqual(widths[1]);
      const run = page.locator('#enrich-enrich_deg');
      const bar = page.locator('#shiny-tab-enrich_tab .rs-run-bar');
      const maxScroll = await page.evaluate(() => document.documentElement.scrollHeight - window.innerHeight);
      for (const y of [0, Math.round(maxScroll / 2), maxScroll]) {
        await page.evaluate(top => window.scrollTo(0, top), y);
        await page.waitForTimeout(150);
        const top = (await bar.boundingBox())!.y;
        expect(top, `run bar top at scroll ${y}`).toBeLessThanOrEqual(vp.bar);
        expect(top, `run bar top at scroll ${y}`).toBeGreaterThanOrEqual(0);
        await expect(run, `Run in the viewport at scroll ${y}`).toBeInViewport();
      }
    });
  });
}

// ---- M7 fix: the stuck Run bar sits directly below the header that is actually visible ----------

for (const vp of [{ width: 390, height: 844, advanced: false }, { width: 1440, height: 900, advanced: true }]) {
  test(`AC-020 the stuck Run bar leaves no band of content above it at ${vp.width}x${vp.height}`, async ({ page }) => {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    await populated(page);
    await showTab(page, 'update_tab');
    await page.locator('#enrich-deg_load').click();
    await showTab(page, 'enrich_tab');
    if (vp.advanced) await page.locator('#shiny-tab-enrich_tab details').evaluateAll(ds => ds.forEach(d => { (d as HTMLDetailsElement).open = true; }));
    await page.evaluate(() => window.scrollTo(0, 0));
    const natural = await page.locator('#shiny-tab-enrich_tab .rs-run-bar').evaluate(e => e.getBoundingClientRect().top);
    await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    await page.waitForTimeout(300);
    const m = await page.evaluate(() => {
      const bar = document.querySelector('#shiny-tab-enrich_tab .rs-run-bar')!.getBoundingClientRect();
      const header = document.querySelector('.main-header')!.getBoundingClientRect();
      const above = bar.top > 4 ? document.elementFromPoint(bar.left + bar.width / 2, bar.top - 4) : null;
      return { barTop: bar.top, headerBottom: header.bottom, aboveClass: above ? (above as HTMLElement).className : null, scrollY };
    });
    await test.info().attach('bar-vs-header', { body: JSON.stringify(m), contentType: 'application/json' });
    // The bar only sticks once the page has scrolled past its natural position; shorter pages leave it unstuck.
    if (m.scrollY < natural) return;
    expect(m.barTop, 'bar is stuck, not scrolled away').toBeGreaterThanOrEqual(-2);
    expect(m.barTop, 'bar top against the visible header bottom').toBeLessThanOrEqual(Math.max(0, m.headerBottom) + 2);
  });
}

// ---- M8: Results master-detail (AC-022, AC-024) ---------------------------------------------------

async function resultsState(page: Page) {
  await populated(page);
  await showTab(page, 'update_tab');
  await page.locator('#enrich-deg_load').click();
  await finishedClusterJob(page);
  await showTab(page, 'rr_visualize_tab');
  await expect(page.locator('#rr_visualize-ex_table tbody tr').first()).toBeVisible({ timeout: 20_000 });
  await page.evaluate(() => window.scrollTo(0, 0));
}

// y-axis tick labels of the plotly figures inside `scope` must stay inside their plot container.
async function tickLabelsInside(page: Page, scope: string) {
  return page.locator(`${scope} .js-plotly-plot`).evaluateAll(plots => plots.flatMap(plot => {
    const box = plot.getBoundingClientRect();
    if (box.width === 0) return [];
    return Array.from(plot.querySelectorAll('.yaxislayer-above .ytick text')).map(t => t.getBoundingClientRect())
      .filter(r => r.left < box.left - 1 || r.right > box.right + 1).map(r => ({ left: r.left, right: r.right, plotLeft: box.left, plotRight: box.right }));
  }));
}

for (const vp of [{ width: 1440, height: 900, top: 300 }, { width: 390, height: 844, top: 420 }]) {
  test.describe(`AC-022 AC-024 Results at ${vp.width}x${vp.height}`, () => {
    test('master-detail: no tab set, table near the top, figure beside (or above) the table, one segmented control, settings collapsed', async ({ page }) => {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await resultsState(page);
      const pane = page.locator('#shiny-tab-rr_visualize_tab');
      await expect(pane.getByRole('tab', { name: 'Explorer' })).toHaveCount(0);
      for (const name of ['Table', 'Bar Plot', 'Dot Plot', 'Network', 'Heatmap']) await expect(pane.getByRole('tab', { name, exact: true })).toHaveCount(0);
      expect(await pane.locator('ul.nav-tabs').locator('visible=true').count(), 'visible tab levels').toBeLessThanOrEqual(1);
      expect(await pane.locator('details.rs-figure-settings').evaluate(d => (d as HTMLDetailsElement).open), 'settings collapsed').toBe(false);
      const table = page.locator('#rr_visualize-ex_table');
      const figure = page.locator('#rr_visualize-ex_plot');
      const topAt = async () => (await table.boundingBox())!.y;
      expect(await topAt(), 'term table top at first show').toBeLessThanOrEqual(vp.top);
      if (vp.width < 768) {
        // Narrow: the figure is a closed disclosure above the table; opened, it has its normal height.
        const toggle = pane.locator('label.rs-figure-toggle');
        await expect(toggle).toBeVisible();
        expect((await toggle.boundingBox())!.y + (await toggle.boundingBox())!.height, 'figure disclosure above the table').toBeLessThanOrEqual((await table.boundingBox())!.y + 2);
        await expect(figure).not.toBeVisible();
        await toggle.click();
        await expect(figure.locator('.main-svg').first()).toBeVisible({ timeout: 20_000 });
        const t = (await table.boundingBox())!, f = (await figure.boundingBox())!;
        expect(f.y + f.height, 'figure above the table').toBeLessThanOrEqual(t.y + 2);
        expect(f.height, 'figure at a readable height').toBeGreaterThanOrEqual(300);
        await toggle.click();
      } else {
        await expect(figure.locator('.main-svg').first()).toBeVisible({ timeout: 20_000 });
        const t = (await table.boundingBox())!, f = (await figure.boundingBox())!;
        expect(f.x >= t.x + t.width - 2 || t.x >= f.x + f.width - 2, 'table and figure side by side').toBe(true);
        expect(Math.abs(f.y - t.y), 'same top').toBeLessThan(120);
      }
      await table.locator('tbody tr').first().click();
      await page.evaluate(() => window.scrollTo(0, 0));
      expect(await topAt(), 'term table top after selecting a term').toBeLessThanOrEqual(vp.top);
      // one segmented control, reachable by keyboard
      const radios = pane.locator('#rr_visualize-plot_type input[type="radio"]');
      await expect(radios).toHaveCount(5);
      await radios.first().focus();
      await page.keyboard.press('ArrowRight');
      await expect(radios.nth(1)).toBeChecked();
    });

    test('selected term: plain labels visible, Result ID and Annotation namespace only inside Details, figure labels stay inside their plot', async ({ page }) => {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await resultsState(page);
      const pane = page.locator('#shiny-tab-rr_visualize_tab');
      await pane.locator('#rr_visualize-ex_table tbody tr').first().click();
      const selected = page.locator('#rr_visualize-ex_selected');
      await expect(selected).toContainText('Term ID');
      await expect(selected).toContainText('Member genes');
      for (const text of ['Result ID', 'Annotation namespace']) await expect(pane.getByText(text, { exact: true }).locator('visible=true'), `"${text}" visible by default`).toHaveCount(0);
      await selected.locator('details summary').click();
      await expect(selected.getByText('Result ID', { exact: true })).toBeVisible();
      const figureToggle = pane.locator('label.rs-figure-toggle');
      if (await figureToggle.isVisible()) await figureToggle.click();
      for (const type of ['Terms', 'Bar', 'Dot']) {
        await pane.getByRole('radio', { name: type, exact: true }).check();
        await page.waitForTimeout(2500);
        expect(await tickLabelsInside(page, '#shiny-tab-rr_visualize_tab'), `${type} y-axis labels outside the plot`).toEqual([]);
      }
      await showTab(page, 'clus_visualize_tab');
      await page.waitForTimeout(2500);
      expect(await tickLabelsInside(page, '#shiny-tab-clus_visualize_tab'), 'Cluster figures y-axis labels outside the plot').toEqual([]);
    });
  });
}
