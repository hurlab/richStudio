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
    await showTab(page, 'enrich_tab');
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
