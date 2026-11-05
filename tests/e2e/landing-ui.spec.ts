import { test, expect, openNavigation } from './fixtures';

test('landing shows release information and keeps empty dataset controls hidden', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await expect(page.locator('#loading-overlay')).toBeHidden();
  await expect(page.locator('.version-pill')).toHaveText(/v\d+\.\d+\.\d+/);
  if (process.env.EXPECTED_RELEASE_BUILD) {
    await expect(page.locator('.version-pill')).toContainText(`Build ${process.env.EXPECTED_RELEASE_BUILD}`);
  }
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

test('the navigation is one flat list in task order with no collapsible group', async ({ page }) => {
  await expect(page.locator('#loading-overlay')).toBeHidden();
  await openNavigation(page);
  await expect(page.locator('.sidebar-menu li.treeview')).toHaveCount(0);
  await expect(page.locator('.sidebar-menu .treeview-menu')).toHaveCount(0);
  await expect(page.locator('.sidebar-menu [data-toggle="collapse"]')).toHaveCount(0);
  const routes = ['home_tab', 'update_tab', 'cluster_upload_tab', 'enrich_tab', 'rr_visualize_tab',
    'cluster_tab', 'clus_visualize_tab', 'save_tab'];
  for (const route of routes) {
    await expect(page.locator(`.sidebar-menu a[href="#shiny-tab-${route}"]`), route).toBeVisible();
  }
  const order = await page.locator('.sidebar-menu a[href^="#shiny-tab-"]')
    .evaluateAll(links => links.map(link => (link.getAttribute('href') ?? '').replace('#shiny-tab-', '')));
  expect(order).toEqual(routes);
});
