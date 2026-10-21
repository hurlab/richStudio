import { test as base, expect, type Page } from '@playwright/test';
import path from 'node:path';

export const fixturePath = (name: string): string =>
  path.resolve(__dirname, '../fixtures/workspace', name);

export async function openNavigation(page: Page): Promise<void> {
  const home = page.getByRole('link', { name: /\bHome$/ });
  const bounds = await home.boundingBox();
  if (!bounds || bounds.x + bounds.width <= 0) {
    await page.getByRole('button', { name: /Toggle navigation/ }).click();
  }
  await home.scrollIntoViewIfNeeded();
  await expect(home).toBeInViewport();
}

export const test = base.extend({
  page: async ({ page }, use) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Welcome to richStudio' })).toBeVisible();
    await use(page);
  },
});
export { expect };
