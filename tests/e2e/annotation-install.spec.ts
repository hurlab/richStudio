import { test as base, expect, type Page } from '@playwright/test';
import { spawn, type ChildProcess } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import net from 'node:net';

// SPEC-WS-014 M2 in a real browser: the "installing annotation" row (AC-021), the structured failure with
// the Copy command panel (AC-022) and the dropdown (AC-019). The fixture app (tests/e2e/annotation-app.R,
// installed richStudio only) builds a throw-away annotation world and a fake downloader whose behaviour this
// spec switches through files in <world>/ctl. The spec owns one detached process group: the Rscript fixture,
// its future workers and any installer it launches; cleanup kills that session and group.

const port = 3874;
const url = `http://127.0.0.1:${port}`;
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function portFree() {
  await new Promise<void>((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => server.close(() => resolve()));
  });
}

type Fixture = { world: string; ctl: (mode: string, seconds?: number) => Promise<void> };

const test = base.extend<{ fixture: Fixture }>({
  fixture: async ({}, use) => {
    const library = process.env.WORKSPACE_INSTALLED_LIBRARY;
    const chain = process.env.WORKSPACE_DEPENDENCY_LIBRARIES;
    if (!library || !chain) throw new Error('WORKSPACE_INSTALLED_LIBRARY and WORKSPACE_DEPENDENCY_LIBRARIES are required');
    await portFree();
    const world = await fs.mkdtemp(path.join(process.env.WORKSPACE_RUNS_ROOT ?? os.tmpdir(), 'ws14-ann-'));
    const env = { ...process.env };
    for (const key of ['R_PROFILE', 'R_PROFILE_USER', 'R_ENVIRON', 'R_ENVIRON_USER', 'R_LIBS', 'R_LIBS_USER', 'R_LIBS_SITE']) delete env[key];
    Object.assign(env, { R_LIBS_USER: library + path.delimiter + chain, RENV_CONFIG_AUTOLOADER_ENABLED: 'FALSE',
      ANN_WORLD: world, ANN_PORT: String(port), WORKSPACE_INSTALLED_LIBRARY: library });
    let log = '';
    let exited = false;
    const child: ChildProcess = spawn('timeout', ['--signal=TERM', '--kill-after=5s', '240s', 'Rscript', '--vanilla',
      path.resolve(__dirname, 'annotation-app.R')], { cwd: world, env, detached: true, stdio: ['ignore', 'pipe', 'pipe'] });
    child.once('exit', () => { exited = true; });
    child.stdout?.on('data', chunk => { log += chunk.toString(); });
    child.stderr?.on('data', chunk => { log += chunk.toString(); });
    try {
      await expect.poll(async () => {
        if (exited) throw new Error(`Fixture exited before ready: ${log}`);
        try { const response = await fetch(url, { signal: AbortSignal.timeout(1000) }); return response.ok; } catch { return false; }
      }, { timeout: 90_000 }).toBe(true);
      await use({ world, ctl: async (mode, seconds) => {
        await fs.mkdir(path.join(world, 'ctl'), { recursive: true });
        await fs.writeFile(path.join(world, 'ctl', 'mode'), mode);
        if (seconds !== undefined) await fs.writeFile(path.join(world, 'ctl', 'seconds'), String(seconds));
      } });
    } finally {
      // The installer is a setsid session of its own: kill sessions led by processes whose cmdline names it.
      try { process.kill(-child.pid!, 'SIGTERM'); } catch { /* already gone */ }
      await delay(500);
      try { process.kill(-child.pid!, 'SIGKILL'); } catch { /* already gone */ }
      await new Promise<void>(resolve => { const cp = spawn('pkill', ['-KILL', '-f', `${world}`]); cp.once('exit', () => resolve()); cp.once('error', () => resolve()); });
      await fs.rm(world, { recursive: true, force: true });
    }
  },
});

async function open(page: Page) {
  await page.goto(url);
  await expect(page.locator('#fixture')).toBeAttached();
  await expect(page.locator('#enrich-enrich_deg')).toHaveClass(/(?:^|\s)shiny-bound-input(?:\s|$)/);
}
async function chooseSelectize(page: Page, id: string, value: string) {
  await expect.poll(() => page.evaluate(([selectId, option]) => {
    const select = document.getElementById(selectId) as (HTMLElement & { selectize?: { options: Record<string, unknown> } }) | null;
    return Boolean(select?.selectize && Object.prototype.hasOwnProperty.call(select.selectize.options, option));
  }, [id, value] as const)).toBe(true);
  const control = page.locator(`#${id} + .selectize-control`);
  await control.locator('.selectize-input').click();
  await control.locator(`.selectize-dropdown .option[data-value="${value}"]`).click();
  await page.keyboard.press('Escape');
}
async function showEnrichTab(page: Page) {
  await page.locator('a[href="#shiny-tab-enrich_tab"]').evaluate(link => (link as HTMLElement).click());
  await expect(page.locator('#shiny-tab-enrich_tab')).toHaveClass(/\bactive\b/);
}
async function runSpecies(page: Page, species: string) {
  await showEnrichTab(page);
  await chooseSelectize(page, 'enrich-degs_to_enrich', 'deg_a');
  // the species control sits in the closed "Adjust" disclosure
  const adjust = page.locator('#shiny-tab-enrich_tab details.rs-adjust');
  if (!(await adjust.evaluate(el => (el as HTMLDetailsElement).open))) await adjust.locator('summary').click();
  await chooseSelectize(page, 'enrich-species_select', species);
  await page.locator('#enrich-enrich_deg').click();
}
async function openTray(page: Page) {
  const tray = page.locator('#jobs-tray');
  if (!(await tray.isVisible())) await page.locator('#jobs-job_badge').click();
  await expect(tray).toBeVisible();
}
const installRow = (page: Page) => page.locator('#jobs-jobs_list li.rs-install');

test.describe('SPEC-WS-014 M2 annotation install', () => {
  test('AC-019 the species dropdown offers installable species with a hint and never an unavailable one', async ({ page, fixture }) => {
    await open(page);
    const options = await page.evaluate(() => {
      const select = document.getElementById('enrich-species_select') as HTMLElement & { selectize?: { options: Record<string, { text?: string; label?: string }> } };
      return Object.fromEntries(Object.entries(select.selectize!.options).map(([k, v]) => [k, v.text ?? v.label]));
    });
    expect(Object.keys(options)).toEqual(expect.arrayContaining(['human', 'sp1', 'sp2']));
    expect(Object.keys(options)).not.toContain('sco');
    expect(options['sp1']).toMatch(/installs on first use, about 7 MB/);
    expect(options['human']).not.toMatch(/installs on first use/);
    void fixture;
  });

  test('AC-021 the row names the package and species, its state text moves on, one live region announces, nothing reads as a failure', async ({ page, fixture }) => {
    await fixture.ctl('slowtar', 6);
    await open(page);
    await runSpecies(page, 'sp1');
    await openTray(page);
    const row = installRow(page);
    await expect(row).toContainText('org.Fake1.eg.db');
    await expect(row).toContainText('sp1');
    const seen = new Set<string>();
    const announced = new Set<string>();
    await expect.poll(async () => {
      const state = (await row.locator('.rs-job-state').first().textContent().catch(() => null)) ?? '';
      if (state) seen.add(state.trim());
      const line = (await page.locator('#jobs-jobs_announce').textContent().catch(() => null)) ?? '';
      if (line) announced.add(line.trim());
      return seen.has('Done');
    }, { timeout: 90_000, intervals: [250] }).toBe(true);
    expect([...seen].some(s => /Downloading/.test(s)), `states seen: ${[...seen].join(' | ')}`).toBe(true);
    expect([...seen].some(s => /Installing|Verifying/.test(s))).toBe(true);
    // exactly one polite live region for job status, and no failure notification or error class
    await expect(page.locator('#jobs-jobs_announce')).toHaveAttribute('aria-live', 'polite');
    expect([...announced].some(l => l === 'Annotation install org.Fake1.eg.db (sp1): Downloading'),
      `announced: ${[...announced].join(' | ')}`).toBe(true);
    await expect(page.locator('.shiny-notification-error, .shiny-notification-warning')).toHaveCount(0);
    await expect(row.locator('.rs-job-status, .text-danger, .has-error')).toHaveCount(0);
    // the analysis continues automatically once the package is there
    await expect(page.locator('#jobs-jobs_list li.rs-job:not(.rs-install)')).toHaveCount(1, { timeout: 60_000 });
    const tsv = await fs.readFile(path.join(fixture.world, 'annotation', (await fs.readdir(path.join(fixture.world, 'annotation')))[0], 'INSTALLED.tsv'), 'utf8');
    expect(tsv).toMatch(/org\.Fake1\.eg\.db\t1\.0\.0\t/);
  });

  test('AC-022 a failed download shows the fixed reason, the manual command in the Copy command panel, and starts no analysis', async ({ page, fixture }) => {
    await fixture.ctl('netfail');
    await open(page);
    await runSpecies(page, 'sp2');
    await openTray(page);
    const row = installRow(page);
    await expect(row.locator('.rs-job-state')).toHaveText('Failed', { timeout: 60_000 });
    const copy = page.locator('#jobs-jobs_list button.rs-copy');
    await expect(copy).toHaveAttribute('data-copy', 'BiocManager::install("org.Fake2.eg.db")');
    await expect(page.locator('#jobs-jobs_list')).toContainText('could not reach the Bioconductor server');
    await expect(page.locator('#jobs-jobs_list li.rs-job:not(.rs-install)')).toHaveCount(0);
    // Retry is offered; Dismiss clears the row
    await expect(page.locator('#jobs-jobs_list button', { hasText: /^\s*Retry\s*$/ })).toBeVisible();
    await page.locator('#jobs-jobs_list button', { hasText: /^\s*Dismiss\s*$/ }).click();
    await expect(installRow(page)).toHaveCount(0);
  });
});
