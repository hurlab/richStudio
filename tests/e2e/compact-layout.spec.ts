import { test, expect } from './fixtures';
import type { Page, TestInfo } from '@playwright/test';
import fs from 'node:fs';

const settings = ['anntype_select', 'keytype_select', 'ont_select', 'species_select'];
const baselinePopulatedSpan = 1044.34375;
const normalized = (value: string) => value.replace(/\s+/g, ' ').trim();
const expectedReview = normalized(`deg_mouse1 Gene list: deg_mouse1 Default rule (not customized)
Source digest: 34ff201542ea Gene column: geneID Rule: padj < 0.05 (adjusted)
Rows kept: 31 Submitted genes: 31 Distinct genes: 31 Excluded: p missing 0,
p ${String.fromCodePoint(8805)} cutoff 48, blank/missing ID 0 Duplicates (information): 0
Species: human Identifier type: SYMBOL Annotation: GO Ontology: BP
Mapped / unmapped: Not available (not measured)`);

async function tab(page: Page, name: string) {
  if (!await page.locator(`#shiny-tab-${name}.active`).count()) {
    const home = page.getByRole('link', { name: /\bHome$/ });
    let previous = '', frames = 0;
    await expect.poll(async () => {
      const box = await home.boundingBox(), key = JSON.stringify(box);
      frames = key === previous ? frames + 1 : 1; previous = key;
      return frames >= 3;
    }, { intervals: [100, 200, 300] }).toBe(true);
    const homeBox = await home.boundingBox();
    if (!homeBox || homeBox.x + homeBox.width <= 0) {
      await page.getByRole('button', { name: /Toggle navigation/ }).click();
    }
    await home.scrollIntoViewIfNeeded(); await expect(home).toBeInViewport();
    const selector = `a[href="#shiny-tab-${name}"]`;
    const link = page.locator(`.sidebar-menu ${selector}`);
    if (!await link.isVisible()) {
      await page.locator('.sidebar-menu li.treeview', { has: page.locator(selector) }).locator(':scope > a').click();
    }
    await link.click();
  }
  if (await page.locator('body.sidebar-open').count()) {
    await page.getByRole('button', { name: /Toggle navigation/ }).click();
    await expect(page.locator('body.sidebar-open')).toHaveCount(0);
  }
  await expect(page.locator(`#shiny-tab-${name}`)).toHaveClass(/\bactive\b/);
  await page.evaluate(() => window.scrollTo(0, 0));
}

async function ready(page: Page) {
  await expect.poll(() => page.evaluate(() => !!(window as any).Shiny?.shinyapp?.isConnected())).toBe(true);
  await page.evaluate(() => document.fonts.ready);
  await tab(page, 'enrich_tab');
  await expect(page.locator('#enrich-review_card')).toContainText('Select gene lists to review them before Run.');
}

async function choose(page: Page, id: string, value: string) {
  const input = page.locator(`#${id}`);
  await expect.poll(() => input.evaluate((node, wanted) =>
    !!(node as any).selectize?.options[wanted], value)).toBe(true);
  const values = await input.evaluate(node => Array.from((node as HTMLSelectElement).selectedOptions).map(x => x.value));
  if (!values.includes(value)) {
    const control = page.locator(`#${id} + .selectize-control`);
    await control.locator('.selectize-input').click();
    await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  }
  await page.keyboard.press('Escape');
  await page.locator('#enrich-review_card').click();
}

async function demo(page: Page) {
  await page.locator('#enrich-deg_load').click();
  await expect(page.locator('#enrich-deg_list_table')).toContainText('deg_mouse1');
  await choose(page, 'enrich-deg_table_select', 'deg_mouse1');
  await choose(page, 'enrich-degs_to_enrich', 'deg_mouse1');
  await expect.poll(async () => normalized(await page.locator('#enrich-review_card').innerText())).toBe(expectedReview);
  await expect(page.locator('#enrich-review_card')).toBeVisible();
  await expect(page.locator('#enrich-review_preview_ui')).toBeVisible();
  await expect(page.locator('#enrich-review_preview_ui')).toContainText('Source digest: 34ff201542ea');
  await expect(page.locator('#enrich-enrich_deg')).toBeEnabled();
  for (const [id, value] of Object.entries({ anntype_select: 'GO', keytype_select: 'SYMBOL', ont_select: 'BP', species_select: 'human', deg_filter_cutoff: '' })) {
    await expect(page.locator(`#enrich-${id}`)).toHaveValue(value);
  }
  await page.evaluate(() => window.scrollTo(0, 0));
}

async function measure(page: Page) {
  const result = await page.locator('#shiny-tab-enrich_tab').evaluate((pane, names) => {
    const rect = (node: Element) => {
      const b = node.getBoundingClientRect();
      return { x: b.x, y: b.y, right: b.right, bottom: b.bottom, width: b.width, height: b.height, docTop: b.top + scrollY, docBottom: b.bottom + scrollY };
    };
    const run = document.getElementById('enrich-enrich_deg')!;
    const card = run.closest('.box')!;
    const fields = names.map(name => {
      const input = document.getElementById(`enrich-${name}`)!;
      const group = input.closest('.shiny-input-container')!;
      const sibling = input.nextElementSibling;
      const control = sibling?.classList.contains('selectize-control') ? sibling.querySelector('.selectize-input')! : input;
      const label = group.querySelector('label')!;
      return { id: input.id, ...rect(group), control: rect(control), label: rect(label),
        font: parseFloat(getComputedStyle(control).fontSize), labelFont: parseFloat(getComputedStyle(label).fontSize),
        value: (input as HTMLSelectElement).value };
    });
    const duplicateBindings = Array.from(document.querySelectorAll('[id]')).filter(node => {
      if (!/^(enrich|rr_visualize|cluster_upload|cluster|clus_visualize|save|update)-/.test(node.id)) return false;
      if (!(node.classList.contains('shiny-bound-input') || node.classList.contains('shiny-bound-output') || /^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(node.tagName))) return false;
      return document.querySelectorAll(`[id="${node.id}"]`).length > 1;
    }).map(node => node.id);
    return { viewport: { width: innerWidth, height: innerHeight }, scrollY, documentWidth: document.documentElement.scrollWidth,
      card: rect(card), run: rect(run), primarySpan: run.getBoundingClientRect().bottom - card.getBoundingClientRect().top,
      fields, duplicateBindings, reviewFont: parseFloat(getComputedStyle(pane.querySelector('#enrich-review_card')!).fontSize),
      helpFonts: Array.from(pane.querySelectorAll('.help-block')).filter(x => x.getBoundingClientRect().height > 0).map(x => parseFloat(getComputedStyle(x).fontSize)),
      reviewText: pane.querySelector('#enrich-review_card')?.textContent ?? '' };
  }, settings);
  return result;
}

async function capture(page: Page, info: TestInfo, stem: string) {
  let previous = '', frames = 0, result: Awaited<ReturnType<typeof measure>> | undefined;
  await expect.poll(async () => {
    result = await measure(page); const key = JSON.stringify(result);
    frames = key === previous ? frames + 1 : 1; previous = key;
    return frames >= 3;
  }, { intervals: [100, 250, 500] }).toBe(true);
  fs.writeFileSync(info.outputPath(`${stem}.json`), JSON.stringify(result, null, 2));
  await page.screenshot({ path: info.outputPath(`${stem}.png`), fullPage: true });
  await info.attach(stem, { path: info.outputPath(`${stem}.json`), contentType: 'application/json' });
  return result!;
}

function fit(state: Awaited<ReturnType<typeof measure>>) {
  expect(state.scrollY).toBe(0);
  expect(state.documentWidth).toBeLessThanOrEqual(state.viewport.width + 1);
  expect(state.duplicateBindings).toEqual([]);
  expect(state.reviewFont).toBeGreaterThanOrEqual(14);
  for (const font of state.helpFonts) expect(font).toBeGreaterThanOrEqual(12);
  for (const field of state.fields) {
    expect(field.control.x).toBeGreaterThanOrEqual(-1);
    expect(field.control.right).toBeLessThanOrEqual(state.viewport.width + 1);
    expect(field.font).toBeGreaterThanOrEqual(14);
    expect(field.labelFont).toBeGreaterThanOrEqual(13);
    expect(field.control.height).toBeGreaterThanOrEqual(38);
  }
}

function columns(state: Awaited<ReturnType<typeof measure>>) {
  const pairs = state.fields.flatMap((a, i) => state.fields.slice(i + 1).map(b => [a, b]));
  return pairs.filter(([a, b]) => Math.abs(a.y - b.y) <= 2 &&
    (a.right <= b.x + 1 || b.right <= a.x + 1)).length;
}

test('compact settled Enrich keeps the desktop Run action in view and related fields in columns', async ({ page }, info) => {
  await ready(page); const state = await capture(page, info, 'initial'); fit(state);
  if (state.viewport.width >= 1280) {
    expect.soft(state.run.bottom, 'Complete Run action must be above the desktop fold').toBeLessThanOrEqual(state.viewport.height);
    expect.soft(columns(state), 'Related settings must share at least two nonoverlapping visual columns').toBeGreaterThan(0);
  } else if (state.viewport.width <= 375) {
    expect(Math.max(...state.fields.map(x => x.x)) - Math.min(...state.fields.map(x => x.x))).toBeLessThanOrEqual(1);
    for (let i = 1; i < state.fields.length; i++) expect(state.fields[i].y).toBeGreaterThanOrEqual(state.fields[i - 1].bottom);
  }
});

test('compact populated Enrich reduces primary span while preserving the complete review state', async ({ page }, info) => {
  await ready(page); await demo(page); const state = await capture(page, info, 'populated'); fit(state);
  expect(normalized(state.reviewText)).toBe(expectedReview);
  if (state.viewport.width >= 1280) {
    expect(state.primarySpan, 'At least 25 percent reduction against the matched unrounded baseline').toBeLessThanOrEqual(baselinePopulatedSpan * .75);
  }
});

test('compact reflow preserves preview versus commit bindings, keyboard access and selected values', async ({ page }, info) => {
  await ready(page); await demo(page);
  const card = page.locator('#enrich-review_card');
  await page.locator('#enrich-review_commit').click();
  await expect(card).toContainText('Committed revision 1');
  await expect(card).toContainText('Submitted genes: 31');
  await page.locator('#enrich-review_cutoff').fill('0.1');
  await page.locator('#enrich-review_cutoff').press('Tab');
  await expect(page.locator('#enrich-review_preview_ui')).toContainText('padj < 0.1 (adjusted)');
  await expect(card).toContainText('padj < 0.05 (adjusted)');
  await expect(card).toContainText('Committed revision 1');
  const original = page.viewportSize()!;
  await tab(page, 'save_tab'); await tab(page, 'enrich_tab');
  await expect(page.locator('#enrich-degs_to_enrich')).toHaveValues(['deg_mouse1']);
  await page.setViewportSize(original.width > 500 ? { width: 375, height: 667 } : { width: 1024, height: 768 });
  await expect(page.locator('#enrich-anntype_select')).toHaveValue('GO');
  await expect(page.locator('#enrich-review_p_role')).toHaveValue('adjusted');
  await expect(page.locator('#enrich-review_cutoff')).toHaveValue('0.1');
  await page.locator('#enrich-review_cutoff').focus();
  await expect(page.locator('#enrich-review_cutoff')).toBeFocused();
  await page.keyboard.press('Tab');
  expect(await page.locator('#enrich-review_cutoff').evaluate(node => document.activeElement !== node)).toBe(true);
  await page.setViewportSize(original); await page.evaluate(() => window.scrollTo(0, 0));
  const state = await capture(page, info, 'binding-contract'); fit(state);
  await expect(card).toContainText('Committed revision 1');
  await expect(page.locator('#enrich-enrich_deg')).toBeEnabled();
});
