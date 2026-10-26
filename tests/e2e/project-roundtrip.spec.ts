import { test, expect } from './fixtures';
import type { Page, TestInfo } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

// SPEC-WS-007 project save / new session / open round trip in a real browser. The
// bundled demo results (go1, go2, kegg1) stand in for a finished analysis; the project
// ZIP is inspected independently of the application (member list, manifest, recomputed
// digests) with the Python standard library, and a rejected project is shown to change
// nothing. Desktop viewport only: the Save tab is reached through the sidebar, whose
// off-canvas behaviour is covered by workspace-entry.spec.ts.

async function attach(info: TestInfo, name: string, value: unknown) {
  await info.attach(name, { body: JSON.stringify(value, null, 2), contentType: 'application/json' });
}

async function openSaveTab(page: Page) {
  const href = 'a[href="#shiny-tab-save_tab"]';
  const link = page.locator(`.sidebar-menu ${href}`);
  if (!(await link.isVisible())) {
    await page.locator('.sidebar-menu li.treeview', { has: page.locator(href) }).locator(':scope > a').click();
  }
  await link.click();
  await expect(page.locator('#shiny-tab-save_tab')).toHaveClass(/\bactive\b/);
  await expect(page.locator('#save-download_project')).toBeVisible();
}

// Reads one member of a ZIP with the standard library (-I: isolated mode).
function zipMember(file: string, member: string): Buffer {
  return execFileSync('python3', ['-I', '-c',
    'import sys, zipfile; sys.stdout.buffer.write(zipfile.ZipFile(sys.argv[1]).read(sys.argv[2]))', file, member],
    { maxBuffer: 64 * 1024 * 1024 });
}

function zipNames(file: string): string[] {
  const out = execFileSync('python3', ['-I', '-c',
    'import sys, zipfile; print("\\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))', file]);
  return out.toString().split('\n').filter(Boolean);
}

async function downloadProject(page: Page, info: TestInfo, name: string): Promise<string> {
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator('#save-download_project').click(),
  ]);
  const target = info.outputPath(name);
  await download.saveAs(target);
  return target;
}

async function openProject(page: Page, file: string) {
  await page.locator('#save-load_project_file').setInputFiles(file);
  // The upload must finish before Open is pressed.
  await expect.poll(async () => page.locator('#save-load_project_file_progress .progress-bar').textContent())
    .toContain('Upload complete');
  await page.locator('#save-load_project').click();
}

test('REQ-001 REQ-003 REQ-004 AC-001 AC-003 a project saves, is inspected, and opens in a new session', async ({ page }, info) => {
  test.skip(info.project.name !== 'chromium-desktop', 'Sidebar routing is exercised by the narrow-viewport entry spec');

  // 1. Results exist: load the bundled demo and go to the Save tab.
  await page.locator('#home-load_demo').click();
  await expect(page.locator('#workspace-active_result')).toHaveValue('go1');
  await openSaveTab(page);
  await expect(page.locator('#save-rr_summary')).toContainText('go1');
  await expect(page.locator('#save-rr_summary')).toContainText('kegg1');

  // 2. Save a project and inspect the ZIP outside the application.
  const saved = await downloadProject(page, info, 'project.zip');
  expect(path.basename(saved)).toBe('project.zip');
  const members = zipNames(saved).sort();
  expect(members).toEqual(['manifest.json', 'methods.md', 'tables.json']);
  const manifest = JSON.parse(zipMember(saved, 'manifest.json').toString('utf8'));
  expect(manifest.schema).toBe('richstudio.project');
  expect(manifest.format_version).toMatch(/^1\.\d+$/);
  const labels = manifest.results.map((r: { label: string }) => r.label).sort();
  expect(labels).toEqual(['go1', 'go2', 'kegg1']);
  for (const result of manifest.results) {
    expect(result.id).toMatch(/^rs-[0-9a-f]{12}$/);
    // Imported demo results carry no run record and no background: absence is typed.
    expect(result.parameters.status).toBe('not_recorded');
    expect(result.background.status).toBe('not_recorded');
  }
  for (const file of manifest.files as { name: string; sha256: string; bytes: number }[]) {
    const body = zipMember(saved, file.name);
    expect(createHash('sha256').update(body).digest('hex')).toBe(file.sha256);
    expect(body.length).toBe(file.bytes);
  }
  const methods = zipMember(saved, 'methods.md').toString('utf8');
  expect(methods).toContain('## Unavailable provenance');
  await attach(info, 'project-inspection', { members, labels, files: manifest.files, format_version: manifest.format_version });

  // 3. A new session starts empty; a rejected project changes nothing.
  await page.reload();
  await expect(page.locator('#home-load_demo')).toBeVisible();
  await openSaveTab(page);
  await expect(page.locator('#save-rr_summary')).toContainText('No enrichment results');
  const bad = info.outputPath('rejected.zip');
  await fs.writeFile(bad, 'this is not a zip archive');
  await openProject(page, bad);
  await expect(page.locator('.shiny-notification-error')).toContainText('Project could not be opened');
  await expect(page.locator('#save-rr_summary')).toContainText('No enrichment results');

  // 4. The saved project opens and restores exactly the saved results.
  await openProject(page, saved);
  await expect(page.locator('.shiny-notification-message')).toContainText('Project opened successfully');
  await expect(page.locator('#save-rr_summary')).toContainText('go1');
  await expect(page.locator('#save-rr_summary')).toContainText('go2');
  await expect(page.locator('#save-rr_summary')).toContainText('kegg1');

  // 5. Saving again reproduces the same IDs and table digests.
  const again = await downloadProject(page, info, 'project-again.zip');
  const second = JSON.parse(zipMember(again, 'manifest.json').toString('utf8'));
  expect(second.results.map((r: { id: string }) => r.id).sort()).toEqual(
    manifest.results.map((r: { id: string }) => r.id).sort());
  expect(second.files.find((f: { name: string }) => f.name === 'tables.json').sha256).toBe(
    manifest.files.find((f: { name: string }) => f.name === 'tables.json').sha256);
});
