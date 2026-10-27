import { test, expect, openNavigation } from './fixtures';

test('landing shows release information and keeps empty dataset controls hidden', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await expect(page.locator('#loading-overlay')).toBeHidden();
  await expect(page.locator('.version-pill')).toHaveText(/v\d+\.\d+\.\d+/);
  await expect(page.locator('#workspace-header')).toBeHidden();
  await expect(page.getByLabel('Change dataset', { exact: true })).toBeHidden();
  await page.screenshot({ path: info.outputPath('landing.png'), fullPage: true });

  await page.locator('#home-load_demo').click();
  await expect(page.locator('#workspace-header')).toBeVisible();
  await expect(page.locator('#workspace-active_result')).toHaveValue('go1');
  await page.locator('#workspace-active_result').selectOption('kegg1');
  await expect(page.locator('#workspace-summary')).toContainText('kegg1');

  await openNavigation(page);
  await page.locator('.sidebar-menu a[href="#shiny-tab-update_tab"]').click();
  if (await page.locator('body.sidebar-open').count()) {
    await page.getByRole('button', { name: /Toggle navigation/ }).click();
  }
  const removeControl = page.locator('#update-remove_rr_select + .selectize-control');
  for (const name of ['go1', 'go2', 'kegg1']) {
    await removeControl.locator('.selectize-input input').fill(name);
    await removeControl.locator(`.selectize-dropdown .option[data-value="${name}"]`).click();
  }
  await page.locator('#update-remove_rr_btn').click();
  await page.locator('#update-confirm_remove_rr').click();
  await expect(page.locator('#workspace-header')).toBeHidden();
  expect(errors).toEqual([]);
});

test('analysis menus start expanded and toggle independently', async ({ page }) => {
  await expect(page.locator('#loading-overlay')).toBeHidden();
  await openNavigation(page);
  const enrichment = page.locator('.sidebar-menu > li.treeview').filter({
    has: page.locator('a[href="#shiny-tab-enrich_tab"]'),
  });
  const clustering = page.locator('.sidebar-menu > li.treeview').filter({
    has: page.locator('a[href="#shiny-tab-cluster_tab"]'),
  });
  const enrichmentItems = enrichment.locator(':scope > ul');
  const clusteringItems = clustering.locator(':scope > ul');
  await expect(enrichmentItems).toBeVisible();
  await expect(clusteringItems).toBeVisible();

  await enrichment.locator(':scope > a').click();
  await expect(enrichmentItems).toBeHidden();
  await expect(clusteringItems).toBeVisible();
  await enrichment.locator(':scope > a').click();
  await expect(enrichmentItems).toBeVisible();
  await expect(clusteringItems).toBeVisible();

  await clustering.locator(':scope > a').click();
  await expect(clusteringItems).toBeHidden();
  await expect(enrichmentItems).toBeVisible();
  await clustering.locator(':scope > a').click();
  await expect(clusteringItems).toBeVisible();
  await expect(enrichmentItems).toBeVisible();

  await enrichment.locator('a[href="#shiny-tab-enrich_tab"]').click();
  await expect(page.locator('#shiny-tab-enrich_tab')).toHaveClass(/\bactive\b/);
});
