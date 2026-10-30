import { test as base, expect, type Browser, type Page, type TestInfo } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { spawn, type ChildProcess } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import net from 'node:net';

// SPEC-WS-006 job lifecycle in a real browser. The spec spawns its own fixture app
// (installed richStudio, latched enrichment runner) and owns every process it starts:
// the fixture is a detached process group whose members carry this run's nonce, and
// cleanup kills exactly those PIDs and verifies they are gone. The production app is
// not modified for testing. Cancellation is proven from /proc, not from panel text.

const port = 3873;
const url = `http://127.0.0.1:${port}`;

type Identity = { pid: number; parent: number; group: number; start: string; state: string };
async function identity(pid: number): Promise<Identity | undefined> {
  try {
    const stat = await fs.readFile(`/proc/${pid}/stat`, 'utf8');
    const fields = stat.slice(stat.lastIndexOf(')') + 2).split(' ');
    return { pid, parent: Number(fields[1]), group: Number(fields[2]), start: fields[19], state: fields[0] };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
    throw error;
  }
}
async function same(record: Identity) {
  const now = await identity(record.pid);
  return !!now && now.start === record.start && now.state !== 'Z';
}
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));
async function attach(info: TestInfo, name: string, value: unknown) {
  await info.attach(name, { body: JSON.stringify(value, null, 2), contentType: 'application/json' });
}
// Every process in the owner's group must carry the nonce; anything else is a foreign joiner.
async function fixtureProcesses(owner: Identity, nonce: string) {
  const found: Identity[] = [];
  for (const entry of (await fs.readdir('/proc')).filter(x => /^\d+$/.test(x))) {
    const record = await identity(Number(entry));
    if (!record || record.group !== owner.group) continue;
    try {
      const environment = (await fs.readFile(`/proc/${entry}/environ`, 'utf8')).split('\0');
      if (!environment.includes(`WS_JOBS_NONCE=${nonce}`)) throw new Error('Unknown process joined owned fixture group');
      found.push(record);
    } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
  }
  return found;
}
async function portFree() {
  const server = net.createServer();
  try {
    await new Promise<void>((resolve, reject) => { server.once('error', reject); server.listen(port, '127.0.0.1', resolve); });
  } finally {
    if (server.listening) await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
}

// The fixture: installed richStudio only, a registry installed as app.R installs it,
// the job panel above two tabs, and an enrichment runner latched on files in <root>.
const fixtureR = String.raw`
library(shiny)
library(shinydashboard)
library(shinyjs)
library(shinyWidgets)
lib <- normalizePath(Sys.getenv('WORKSPACE_INSTALLED_LIBRARY'), mustWork=TRUE)
ns <- loadNamespace('richStudio', lib.loc=lib)
stopifnot(identical(normalizePath(getNamespaceInfo(ns, 'path'), mustWork=TRUE), file.path(lib, 'richStudio')))
root <- normalizePath(getwd(), mustWork=TRUE)
dir.create(file.path(root, 'pids'), showWarnings=FALSE)
dir.create(file.path(root, 'release'), showWarnings=FALSE)
future::plan(future::multisession, workers=I(as.integer(Sys.getenv('WS_JOBS_WORKERS'))))
enrich_tab_ui <- getFromNamespace('enrich_tab_ui', 'richStudio')
enrich_tab_server <- getFromNamespace('enrich_tab_server', 'richStudio')
jobs_ui <- getFromNamespace('workspace_jobs_ui', 'richStudio')
jobs_server <- getFromNamespace('workspace_jobs_server', 'richStudio')
jobs_registry <- getFromNamespace('workspace_jobs_registry', 'richStudio')
jobs_close <- getFromNamespace('workspace_jobs_close', 'richStudio')
# Latched runner: claims <label>.<k>, writes its PID to pids/<key>, waits at most 30 s
# for release/<key>, then returns a fixed valid result.
latch_runner <- local({
  root <- root
  function(deg_inputs, cutoff, species, anntype, keytype, ontology) {
    label <- gsub('[^A-Za-z0-9_]', '_', deg_inputs[[1]]$name)
    k <- 1L
    while (!dir.create(file.path(root, 'pids', paste0(label, '.', k, '.claim')), showWarnings=FALSE)) k <- k + 1L
    key <- paste0(label, '.', k)
    writeLines(as.character(Sys.getpid()), file.path(root, 'pids', paste0(key, '.tmp')))
    file.rename(file.path(root, 'pids', paste0(key, '.tmp')), file.path(root, 'pids', key))
    deadline <- Sys.time() + 30
    while (!file.exists(file.path(root, 'release', key)) && Sys.time() < deadline) Sys.sleep(0.05)
    lapply(deg_inputs, function(inp) list(name=inp$name,
      result=data.frame(Annot='Term one', Term='T1', Pvalue=0.01, Padj=0.02, GeneID='g1,g2'),
      anntype=anntype, keytype=keytype, ontology=ontology, species=species))
  }
})
ui <- dashboardPage(
  dashboardHeader(title='Job lifecycle fixture'),
  dashboardSidebar(sidebarMenu(id='tabs',
    menuItem('Enrichment', tabName='enrich_tab'),
    menuItem('Other tab', tabName='other_tab'))),
  dashboardBody(shinyjs::useShinyjs(),
    tags$div(id='fixture', 'data-nonce'=Sys.getenv('WS_JOBS_NONCE')),
    jobs_ui('jobs'),
    tabItems(enrich_tab_ui('enrich', tabName='enrich_tab'),
      tabItem(tabName='other_tab', h2('Other tab'), p('Navigation target'))))
)
server <- function(input, output, session) {
  u_degnames <- reactiveValues(labels=c('deg_a', 'deg_b'))
  df <- data.frame(gene=paste0('g', 1:4), Padj=rep(0.01, 4))
  u_degdfs <- reactiveValues(deg_a=df, deg_b=df)
  u_big_degdf <- reactiveValues(df=richStudio::add_file_degdf(richStudio::add_file_degdf(NULL, 'deg_a', df), 'deg_b', df))
  u_rrnames <- reactiveValues(labels=NULL)
  u_rrdfs <- reactiveValues()
  u_big_rrdf <- reactiveValues()
  jobs <- jobs_registry(session)
  session$userData$workspace_jobs <- jobs
  session$onSessionEnded(function() jobs_close(jobs))
  jobs_server('jobs', jobs)
  enrich_tab_server('enrich', u_degnames=u_degnames, u_degdfs=u_degdfs, u_big_degdf=u_big_degdf,
    u_rrnames=u_rrnames, u_rrdfs=u_rrdfs, u_big_rrdf=u_big_rrdf, enrichment_runner=latch_runner)
}
runApp(shinyApp(ui, server), host='127.0.0.1', port=${port}, launch.browser=FALSE)
`;

type Fixture = { root: string; nonce: string; record: (pid: number) => Promise<Identity> };
const test = base.extend<{ workers: number; fixture: Fixture }>({
  workers: [2, { option: true }],
  fixture: async ({ workers }, use, info) => {
    let root: string | undefined, child: ChildProcess | undefined, owner: Identity | undefined;
    let owned: Identity[] = [], reaped = false, log = '', safe = true;
    const nonce = randomUUID();
    const runs = process.env.WORKSPACE_RUNS_ROOT, temporary = process.env.TMPDIR;
    if (!runs || !temporary || !path.isAbsolute(runs) || !path.isAbsolute(temporary)) throw new Error('Explicit project-local runs root/TMPDIR required');
    const canonicalRuns = await fs.realpath(runs);
    if (canonicalRuns !== runs) throw new Error('Runs root is not canonical');
    const lifecycle: Record<string, unknown> = { nonce, port, workers, parent: canonicalRuns };
    const merge = (more: Identity[]) => { owned = [...new Map([...owned, ...more].map(record => [record.pid, record])).values()]; };
    try {
      await portFree();
      root = await fs.mkdtemp(path.join(canonicalRuns, 'ws6-jobs-'));
      await fs.writeFile(path.join(root, 'nonce'), nonce, { flag: 'wx', mode: 0o600 });
      await fs.writeFile(path.join(root, 'app.R'), fixtureR);
      const library = process.env.WORKSPACE_INSTALLED_LIBRARY, chain = process.env.WORKSPACE_DEPENDENCY_LIBRARIES;
      if (!library || !chain || process.env.R_LIBS_USER !== library + path.delimiter + chain) throw new Error('Live runner candidate and exact approved dependency chain required');
      const env = { ...process.env };
      for (const key of ['R_PROFILE','R_PROFILE_USER','R_ENVIRON','R_ENVIRON_USER','R_LIBS','R_LIBS_USER','R_LIBS_SITE','R_HOME','R_COVR','R_TESTS']) delete env[key];
      Object.assign(env, { R_LIBS_USER: library + path.delimiter + chain, RENV_CONFIG_AUTOLOADER_ENABLED: 'FALSE',
        WS_JOBS_NONCE: nonce, WS_JOBS_WORKERS: String(workers) });
      child = spawn('timeout', ['--signal=TERM', '--kill-after=5s', '150s', 'Rscript', '--vanilla', 'app.R'],
        { cwd: root, env, detached: true, stdio: ['ignore', 'pipe', 'pipe'] });
      child.once('exit', () => { reaped = true; });
      child.once('error', error => { log += String(error); safe = false; });
      child.stdout?.on('data', chunk => { log += chunk.toString(); });
      child.stderr?.on('data', chunk => { log += chunk.toString(); });
      if (!child.pid) throw new Error('Fixture spawn allocated no PID');
      const attempted = await identity(child.pid);
      if (!attempted || attempted.group !== attempted.pid) { safe = false; throw new Error('Fixture process identity unavailable'); }
      owner = attempted; lifecycle.owner = owner; merge(await fixtureProcesses(owner, nonce));
      await expect.poll(async () => {
        if (reaped || child?.exitCode !== null || child?.signalCode) throw new Error(`Fixture exited before ready: ${log}`);
        try { const response = await fetch(url, { signal: AbortSignal.timeout(1000) }); return response.ok && (await response.text()).includes(nonce); }
        catch { return false; }
      }, { timeout: 60_000 }).toBe(true);
      merge(await fixtureProcesses(owner, nonce)); lifecycle.started = owned;
      const fixtureRoot = root;
      await use({ root: fixtureRoot, nonce, record: async (pid: number) => {
        const record = await identity(pid);
        if (!record || !owner || record.group !== owner.group) throw new Error(`Worker ${pid} is not in the owned fixture group`);
        merge([record]);
        return record;
      } });
    } finally {
      try {
        if (child?.pid) {
          try { if (owner) merge(await fixtureProcesses(owner, nonce)); }
          catch (error) { safe = false; lifecycle.discoveryError = String(error); }
          if (safe && owner && await same(owner)) {
            lifecycle.beforeTerm = owned;
            try { process.kill(-owner.group, 'SIGTERM'); } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error; }
          } else if (child.exitCode === null && !child.signalCode) { if (!owner) safe = false; child.kill('SIGTERM'); }
          const deadline = Date.now() + 5500;
          while (!reaped && Date.now() < deadline) await delay(25);
          try { if (owner) merge(await fixtureProcesses(owner, nonce)); }
          catch (error) { safe = false; lifecycle.discoveryError = String(error); }
          for (const record of [...owned].reverse()) if (await same(record)) {
            try { process.kill(record.pid, 'SIGKILL'); } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error; }
          }
          if (child.exitCode === null && !child.signalCode) child.kill('SIGKILL');
          const end = Date.now() + 2000;
          while (Date.now() < end && (!reaped || (await Promise.all(owned.map(same))).some(Boolean))) await delay(25);
          lifecycle.exit = { code: child.exitCode, signal: child.signalCode, reaped };
          lifecycle.remaining = await Promise.all(owned.map(async record => ({ ...record, alive: await same(record) })));
          if (!reaped || (lifecycle.remaining as { alive: boolean }[]).some(record => record.alive)) safe = false;
        }
        if (root) {
          const stat = await fs.lstat(root);
          safe &&= !stat.isSymbolicLink() && await fs.realpath(root) === root && path.dirname(root) === canonicalRuns &&
            await fs.readFile(path.join(root, 'nonce'), 'utf8') === nonce;
          if (!safe) throw new Error('Uncertain cleanup ownership; retained scratch');
          await portFree(); lifecycle.portFreeAfter = true;
          await fs.rm(root, { recursive: true }); lifecycle.scratchRemoved = true;
        }
      } finally {
        lifecycle.log = log; lifecycle.safe = safe;
        await attach(info, 'job-fixture-cleanup', lifecycle);
      }
    }
  },
});

async function open(page: Page, fixture: Fixture) {
  await page.goto(url);
  await expect(page.locator('#fixture')).toHaveAttribute('data-nonce', fixture.nonce);
  await expect(page.locator('#enrich-enrich_deg')).toHaveClass(/(?:^|\s)shiny-bound-input(?:\s|$)/);
}
async function showTab(page: Page, tab: string) {
  await page.locator(`a[href="#shiny-tab-${tab}"]`).evaluate(link => (link as HTMLElement).click());
  await expect(page.locator(`#shiny-tab-${tab}`)).toHaveClass(/\bactive\b/);
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
async function run(page: Page, label: string) {
  await showTab(page, 'enrich_tab');
  await chooseSelectize(page, 'enrich-degs_to_enrich', label);
  await page.locator('#enrich-enrich_deg').click();
}
// The worker PID the latched runner wrote for `<label>.<k>`, recorded as owned.
async function workerPid(fixture: Fixture, key: string) {
  const file = path.join(fixture.root, 'pids', key);
  await expect.poll(async () => { try { return (await fs.readFile(file, 'utf8')).trim().length > 0; } catch { return false; } },
    { timeout: 30_000 }).toBe(true);
  const pid = Number((await fs.readFile(file, 'utf8')).trim());
  return fixture.record(pid);
}
const release = (fixture: Fixture, key: string) => fs.writeFile(path.join(fixture.root, 'release', key), '');
const panel = (page: Page) => page.locator('section[aria-label="Analysis jobs"]');
const status = (page: Page) => page.locator('#jobs-jobs_status');
const stopButton = (page: Page) => page.locator('#jobs-jobs_list button', { hasText: /^\s*Stop\s*$/ });
async function newPage(browser: Browser, info: TestInfo) {
  const context = await browser.newContext({ viewport: info.project.use.viewport ?? undefined });
  return context.newPage();
}

test.describe('workers = 2', () => {
  test.use({ workers: 2 });

  test('AC-003 REQ-001 the panel survives navigation with live elapsed time and no invented progress', async ({ page, fixture }, info) => {
    const errors: string[] = [];
    page.on('pageerror', error => errors.push(error.message));
    await open(page, fixture);
    await run(page, 'deg_a');
    const worker = await workerPid(fixture, 'deg_a.1');
    await expect(status(page)).toContainText(/running/i);
    await showTab(page, 'other_tab');
    await showTab(page, 'enrich_tab');
    await expect(panel(page)).toBeVisible();
    await expect(status(page)).toContainText('Progress: not reported by this engine');
    const time = page.locator('#jobs-jobs_time');
    const first = (await time.innerText()).trim();
    await page.waitForTimeout(2200);
    const second = (await time.innerText()).trim();
    expect(second).not.toBe(first);
    expect(await panel(page).innerText()).not.toContain('%');
    const before = await stopButton(page).elementHandle();
    expect(before).not.toBeNull();
    await page.waitForTimeout(1500);
    const after = await stopButton(page).elementHandle();
    expect(await before!.evaluate(node => node.isConnected)).toBe(true);
    expect(await page.evaluate(([a, b]) => a === b, [before, after] as const)).toBe(true);
    await release(fixture, 'deg_a.1');
    await expect(status(page)).toContainText(/succeeded/i, { timeout: 30_000 });
    await expect.poll(() => page.evaluate(() => {
      const select = document.getElementById('enrich-rr_table_select') as (HTMLElement & { selectize?: { options: Record<string, unknown> } }) | null;
      return Boolean(select?.selectize && Object.prototype.hasOwnProperty.call(select.selectize.options, 'deg_a_enriched'));
    })).toBe(true);
    await attach(info, 'panel-navigation', { project: info.project.name, worker, first, second, errors });
    expect(errors).toEqual([]);
  });

  test('AC-002 REQ-003 Stop in one session ends only its worker, and only after the PID is gone', async ({ browser, fixture }, info) => {
    const one = await newPage(browser, info), two = await newPage(browser, info);
    try {
      await open(one, fixture);
      await open(two, fixture);
      await run(one, 'deg_a');
      await run(two, 'deg_b');
      const pid1 = await workerPid(fixture, 'deg_a.1');
      const pid2 = await workerPid(fixture, 'deg_b.1');
      expect(pid1.pid).not.toBe(pid2.pid);
      await expect(status(one)).toContainText(/running/i);
      await stopButton(one).click();
      // Panel text never leads the process: "Cancelled" may appear only once /proc shows pid1 gone.
      const observations: { cancelled: boolean; alive: boolean }[] = [];
      await expect.poll(async () => {
        const cancelled = /cancelled/i.test(await status(one).innerText());
        const alive = await same(pid1);
        observations.push({ cancelled, alive });
        return cancelled;
      }, { timeout: 15_000 }).toBe(true);
      expect(observations.some(o => o.cancelled && o.alive)).toBe(false);
      expect(await same(pid1)).toBe(false);
      expect(await same(pid2)).toBe(true);
      await expect(status(two)).toContainText(/running/i);
      await release(fixture, 'deg_b.1');
      await expect(status(two)).toContainText(/succeeded/i, { timeout: 30_000 });
      await attach(info, 'two-session-stop', { project: info.project.name, pid1, pid2, observations });
    } finally {
      await one.context().close();
      await two.context().close();
    }
  });
});

test.describe('workers = 1', () => {
  test.use({ workers: 1 });

  test('D3 REQ-001 a second session queues honestly and starts when the worker frees', async ({ browser, fixture }, info) => {
    const one = await newPage(browser, info), two = await newPage(browser, info);
    try {
      await open(one, fixture);
      await open(two, fixture);
      await run(one, 'deg_a');
      await workerPid(fixture, 'deg_a.1');
      await expect(status(one)).toContainText(/running/i);
      await run(two, 'deg_b');
      await expect(status(two)).toContainText("Queued: 0 job(s) ahead in this server's queue");
      const text = await panel(two).innerText();
      for (const word of ['ETA', 'remaining', '%']) expect(text).not.toContain(word);
      await release(fixture, 'deg_a.1');
      await expect(status(one)).toContainText(/succeeded/i, { timeout: 30_000 });
      await workerPid(fixture, 'deg_b.1');
      await expect(status(two)).toContainText(/running/i, { timeout: 30_000 });
      await release(fixture, 'deg_b.1');
      await expect(status(two)).toContainText(/succeeded/i, { timeout: 30_000 });
      await attach(info, 'queue-two-sessions', { project: info.project.name });
    } finally {
      await one.context().close();
      await two.context().close();
    }
  });
});
