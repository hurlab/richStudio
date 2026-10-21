import { test as base, expect, chromium, type Page, type TestInfo } from '@playwright/test';
import type { AxeResults, RunOptions } from 'axe-core';
import { createRequire } from 'node:module';
import { createHash, randomUUID } from 'node:crypto';
import { spawn, type ChildProcess } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import net from 'node:net';

// Fixture caller behavior is tested here; this does not establish route adoption.
const sourceRoot = path.resolve(__dirname, '../..');
const requireLocal = createRequire(__filename);
const url = 'http://127.0.0.1:3872';
const frozen = {
  'R/workspace_components.R': 'f13e697ffcae12303cb0ff9aa159df9bf4f3284fb9272f366205de7744a8d9a1',
  'inst/application/www/custom.css': '92fdf6e04d0660037165b958c3dccf181f1b2f3258f25156f46b328dedb29d5e',
  'tests/testthat/test-workspace-components.R': 'a3c6ba91477caa5b2666c24c8e3b7dd93e02b0cc71fc3203e086f37bf5d66c42',
  'docs/design/workspace-design-system.md': '808b54610ab346c3037aaff2a9309baf24ab3a7d53862d9febea4a8f396d0ef0',
  'docs/design/workspace-screens.md': '448758fb68c9d005f6e69f18fc179a76d7ce35e705d8fcec3944705d4f9a527d',
  'docs/design/workspace-handoff.md': '086f3f8fa2b148f6807e9bf3e06d8e953f455e46e502337121eb08b418ebdd3c',
};
const sha = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
async function snapshot() {
  const result: Record<string, string> = {};
  for (const file of [...Object.keys(frozen), 'tests/e2e/design-system.spec.ts', 'package.json', 'package-lock.json']) {
    result[file] = sha(await fs.readFile(path.join(sourceRoot, file)));
  }
  for (const [file, digest] of Object.entries(frozen)) expect(result[file], file).toBe(digest);
  return result;
}
async function attach(info: TestInfo, name: string, value: unknown) {
  await info.attach(name, { body: JSON.stringify(value, null, 2), contentType: 'application/json' });
}

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
async function descendants(owner: Identity): Promise<Identity[]> {
  const records = (await Promise.all((await fs.readdir('/proc')).filter(x => /^\d+$/.test(x))
    .map(x => identity(Number(x))))).filter((x): x is Identity => !!x);
  const owned = [owner];
  for (let i = 0; i < owned.length; i++) {
    for (const child of records) if (child.parent === owned[i].pid && !owned.some(x => x.pid === child.pid)) owned.push(child);
  }
  return owned;
}
async function same(record: Identity) { return (await identity(record.pid))?.start === record.start; }
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));
async function profileProcesses(profile: string) {
  const found: Identity[] = [];
  for (const entry of (await fs.readdir('/proc')).filter(x => /^\d+$/.test(x))) {
    const record = await identity(Number(entry));
    if (!record) continue;
    try {
      const args = (await fs.readFile(`/proc/${entry}/cmdline`, 'utf8')).split('\0');
      if (args.includes(`--user-data-dir=${profile}`)) found.push(...await descendants(record));
    } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
  }
  return [...new Map(found.map(record => [record.pid, record])).values()];
}
async function fixtureProcesses(owner: Identity, nonce: string) {
  const found: Identity[] = [];
  for (const entry of (await fs.readdir('/proc')).filter(x => /^\d+$/.test(x))) {
    const record=await identity(Number(entry));
    if (!record || record.group !== owner.group) continue;
    try {
      const environment=(await fs.readFile(`/proc/${entry}/environ`,'utf8')).split('\0');
      if (!environment.includes(`WS_COMPONENT_NONCE=${nonce}`)) throw new Error('Unknown process joined owned fixture group');
      found.push(record);
    } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
  }
  return found;
}
async function listeners(port: number, processes: Identity[]) {
  const sockets = (await fs.readFile('/proc/net/tcp', 'utf8')).trim().split('\n').slice(1)
    .map(line => line.trim().split(/\s+/)).filter(row => row[1] === `0100007F:${port.toString(16).toUpperCase().padStart(4,'0')}` && row[3] === '0A').map(row => row[9]);
  const owners: number[] = [];
  for (const record of processes) {
    try {
      for (const fd of await fs.readdir(`/proc/${record.pid}/fd`)) {
        try { const link = await fs.readlink(`/proc/${record.pid}/fd/${fd}`); if (sockets.some(inode => `socket:[${inode}]` === link)) owners.push(record.pid); }
        catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
      }
    } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
  }
  return { port, sockets, owners: [...new Set(owners)] };
}
async function portFree() {
  const server = net.createServer();
  try {
    await new Promise<void>((resolve, reject) => { server.once('error', reject); server.listen(3872, '127.0.0.1', resolve); });
  } finally {
    if (server.listening) await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
}

// All caller-only dialog state is synthetic. Helpers supply the real markup.
const callerScript = String.raw`
document.addEventListener('DOMContentLoaded', () => {
  const dialog = document.getElementById('a-confirm');
  const context = document.getElementById('context');
  let invoker, captured, target = 'ds-a', revision = 1, applied = 0;
  window.fixtureState = () => ({target, revision, applied});
  document.getElementById('a-open').addEventListener('click', event => {
    invoker = event.currentTarget; captured = {target, revision};
    dialog.returnValue = ''; document.getElementById('diagnostic').textContent = '';
    dialog.showModal(); dialog.querySelector('[value=cancel]').focus();
  });
  document.getElementById('a-change').addEventListener('click', () => { revision++; });
  document.getElementById('a-remove').addEventListener('click', () => { invoker.remove(); });
  const form = dialog.querySelector('form');
  // Opt this native dialog form out of Shiny's delegated form:not([action]) interception.
  form.setAttribute('action', '#workspace-confirmation');
  form.addEventListener('submit', event => {
    if (event.submitter.value === 'confirm') {
      if (captured.target !== target || captured.revision !== revision) {
        event.preventDefault(); document.getElementById('diagnostic').textContent = 'Target changed; open a fresh confirmation';
      } else { applied++; document.getElementById('applied').textContent = String(applied); }
    }
  });
  dialog.addEventListener('close', () => { (invoker?.isConnected ? invoker : context).focus(); });
});`;

const fixtureR = String.raw`
library(shiny)
lib <- normalizePath(Sys.getenv('WORKSPACE_INSTALLED_LIBRARY'), mustWork=TRUE)
ns <- loadNamespace('richStudio', lib.loc=lib)
package_path <- normalizePath(getNamespaceInfo(ns, 'path'), mustWork=TRUE)
stopifnot(identical(package_path, file.path(lib, 'richStudio')))
source_root <- Sys.getenv('WS_COMPONENT_SOURCE')
parsed <- parse(file.path(source_root, 'R/workspace_components.R'))
names <- c('workspace_text','workspace_action','workspace_card','workspace_field',
  'workspace_status','workspace_table','workspace_dataset_cue','workspace_confirmation')
api <- lapply(names, function(name) {
  actual <- getFromNamespace(name, 'richStudio')
  definition <- Filter(function(x) is.call(x) && identical(x[[1]], as.name('<-')) &&
    identical(x[[2]], as.name(name)), as.list(parsed))
  stopifnot(length(definition)==1L)
  expected <- eval(definition[[1]][[3]], envir=new.env(parent=baseenv()))
  stopifnot(identical(body(actual),body(expected)), identical(formals(actual),formals(expected)),
    identical(environment(actual),ns), !name %in% getNamespaceExports('richStudio'))
  list(name=name, body=deparse(body(actual)), formals=deparse(formals(actual)), private=TRUE)
})
css <- system.file('application/www/custom.css',package='richStudio',lib.loc=lib,mustWork=TRUE)
stopifnot(file.info(css)$size == file.info(file.path(source_root,'inst/application/www/custom.css'))$size)
stopifnot(identical(readBin(css,'raw',n=file.info(css)$size),
  readBin(file.path(source_root,'inst/application/www/custom.css'),'raw',n=file.info(css)$size)))
jsonlite::write_json(list(package_path=package_path, library=lib, library_paths=.libPaths(),
  R=R.version.string, shiny=as.character(packageVersion('shiny')), shiny_path=find.package('shiny'), api=api,
  css=css, pid=Sys.getpid()), 'installed-identity.json',auto_unbox=TRUE,pretty=TRUE)
action <- getFromNamespace('workspace_action','richStudio')
card <- getFromNamespace('workspace_card','richStudio')
field <- getFromNamespace('workspace_field','richStudio')
status <- getFromNamespace('workspace_status','richStudio')
table <- getFromNamespace('workspace_table','richStudio')
cue <- getFromNamespace('workspace_dataset_cue','richStudio')
confirmation <- getFromNamespace('workspace_confirmation','richStudio')
addResourcePath('component-css',dirname(css))
hostile <- '<img src=x onerror=alert(1)> =SUM(1,2)'
ui <- fluidPage(lang='en', title='Synthetic component contract',
  tags$head(tags$link(rel='stylesheet',href='component-css/custom.css'),
    tags$script(HTML(readChar('caller.js',file.info('caller.js')$size)))),
  tags$main(id='fixture', class='rs-workspace', 'data-nonce'=Sys.getenv('WS_COMPONENT_NONCE'),
    tags$h1(id='context',tabindex='-1','Synthetic component contract'),
    tags$h2('Reusable presentation components'),
    card('a','card',hostile,list(Organism=NA_character_,Count='0'),'Setup draft'),
    cue('D-A',hostile,'ds-a','circle'), cue('D-B',hostile,'ds-b','square'),
    field('a','field','Display filter',help='Preview only',error='Keep the recorded value'),
    field('b','field','Second namespace',value='Preserved'),
    tags$div(class='rs-workspace-actions',
      action('a','act',hostile),action('b','act','Second action'),
      action('a','update','Replace action label'),
      action('a','unavailable','Unavailable action',FALSE,'Membership not supplied')),
    tags$div(style='background:#1e293b;padding:8px',
      tagAppendAttributes(action('a','filled','Filled action on dark surface'),style='background:#0f6fc5;color:white')),
    textOutput('activations'),
    lapply(c('queued','running','failed','succeeded','stop-requested','cancelled','detached','interrupted'),
      function(state) status('a',state,state)),
    table('a','table','Synthetic recorded results',data.frame(
      'Stable identifier'=paste0('SYN:',paste(rep('long-identifier',12),collapse='')),
      setNames(rep(list('Not supplied'),24L),paste('Recorded field',seq_len(24L))), check.names=FALSE)),
    tags$div(class='rs-workspace-actions',action('a','open','Remove the named synthetic dataset ds-a'),
      action('a','change','Change target revision'),action('a','remove','Remove dialog invoker')),
    tags$p('Applied: ',tags$span(id='applied','0')),
    confirmation('a','confirm','Remove named synthetic dataset',c('D-A / ds-a'),'Remove ds-a'),
    tags$p(id='diagnostic',role='status'),
    tags$div(id='loading-overlay',style='position:static;opacity:1;visibility:visible;pointer-events:none;',
      tags$span(class='loading-logo','Loading application'),tags$span(class='loading-spinner'))))
server <- function(input, output, session) {
  count <- reactiveVal(0L)
  observeEvent(input[['a-act']], { count(count()+1L) }, ignoreInit=TRUE)
  output$activations <- renderText(paste('Activations',count()))
  observeEvent(input[['a-update']], {
    updateActionButton(session,'a-act',label='Updated native action')
  },ignoreInit=TRUE)
}
runApp(shinyApp(ui,server),host='127.0.0.1',port=3872,launch.browser=FALSE)
`;

type Component = { nonce: string; root: string; cleanup: { safe: boolean; reason: string } };
const test = base.extend<{ component: Component }>({
  component: async ({}, use, info) => {
    let root: string | undefined, inode: number | undefined, device: number | undefined, child: ChildProcess | undefined;
    let owner: Identity | undefined, owned: Identity[] = [], reaped = false, log = '', safe = true;
    const nonce = randomUUID(), before = await snapshot(), cleanup = { safe:true, reason:'' };
    const runs = process.env.WORKSPACE_RUNS_ROOT, temporary = process.env.TMPDIR;
    if (!runs || !temporary || !path.isAbsolute(runs) || !path.isAbsolute(temporary)) throw new Error('Explicit project-local runs root/TMPDIR required');
    const canonicalTemporary = await fs.realpath(temporary), canonicalRuns = await fs.realpath(runs);
    if (canonicalTemporary !== temporary || canonicalRuns !== runs || (temporary !== runs && !temporary.startsWith(runs + path.sep))) throw new Error('TMPDIR outside canonical runs root');
    const parent = canonicalRuns;
    const lifecycle: Record<string, unknown> = { nonce, source: before, node: process.version, productionPort: 3871, componentPort: 3872, parent };
    // Registered before allocation. The outer reviewed command also bounds this worker.
    try {
      await portFree();
      root = await fs.mkdtemp(path.join(parent, 'c3-'));
      const stat = await fs.lstat(root); inode = stat.ino; device = stat.dev;
      await fs.writeFile(path.join(root, 'nonce'), nonce, { flag: 'wx', mode: 0o600 });
      lifecycle.root = { path: root, inode, device };
      await fs.writeFile(path.join(root, 'app.R'), fixtureR);
      await fs.writeFile(path.join(root, 'caller.js'), callerScript);
      const library = process.env.WORKSPACE_INSTALLED_LIBRARY, chain = process.env.WORKSPACE_DEPENDENCY_LIBRARIES;
      if (!library || !chain || process.env.R_LIBS_USER !== library + path.delimiter + chain) throw new Error('Live runner candidate and exact approved dependency chain required');
      for (const entry of [library, ...chain.split(path.delimiter)]) if (!path.isAbsolute(entry) || !(await fs.stat(entry)).isDirectory()) throw new Error('Missing absolute library input');
      const env = { ...process.env };
      for (const key of ['R_PROFILE','R_PROFILE_USER','R_ENVIRON','R_ENVIRON_USER','R_LIBS','R_LIBS_USER','R_LIBS_SITE','R_HOME','R_COVR','R_TESTS']) delete env[key];
      Object.assign(env, { R_LIBS_USER: library + path.delimiter + chain, RENV_CONFIG_AUTOLOADER_ENABLED: 'FALSE',
        WS_COMPONENT_SOURCE: sourceRoot, WS_COMPONENT_NONCE: nonce });
      child = spawn('timeout', ['--signal=TERM','--kill-after=5s','150s','Rscript','--vanilla','app.R'],
        { cwd: root, env, detached: true, stdio: ['ignore','pipe','pipe'] });
      // Observe immediately: no fallible identity work precedes handle ownership.
      child.once('exit', () => { reaped = true; });
      child.once('error', error => { log += String(error); safe = false; });
      child.stdout?.on('data', chunk => { log += chunk.toString(); });
      child.stderr?.on('data', chunk => { log += chunk.toString(); });
      lifecycle.attemptedPid = child.pid;
      if (!child.pid) throw new Error('Fixture spawn allocated no PID');
      const attempted = await identity(child.pid); lifecycle.identityAttempt = attempted;
      if (!attempted || attempted.group !== attempted.pid) { safe=false; throw new Error('Fixture process identity unavailable'); }
      owner=attempted; lifecycle.owner = owner; owned = await fixtureProcesses(owner,nonce);
      await expect.poll(async () => {
        if (reaped || child?.exitCode !== null || child?.signalCode) throw new Error(`Fixture exited before ready: ${log}`);
        try { const response = await fetch(url, { signal: AbortSignal.timeout(1000) }); return response.ok && (await response.text()).includes(nonce); }
        catch { return false; }
      }, { timeout: 30_000 }).toBe(true);
      owned = await fixtureProcesses(owner,nonce); lifecycle.started = owned;
      const listener = await listeners(3872, owned); lifecycle.listener = listener;
      if (listener.sockets.length !== 1 || listener.owners.length !== 1) throw new Error('Component listener is not exclusively owned');
      lifecycle.installed = JSON.parse(await fs.readFile(path.join(root, 'installed-identity.json'), 'utf8'));
      await attach(info, 'component-started', lifecycle);
      await use({ nonce, root, cleanup });
    } finally {
      try {
        if (child?.pid) {
          try { if (owner) owned = [...new Map([...owned,...await fixtureProcesses(owner,nonce)].map(record => [record.pid,record])).values()]; }
          catch (error) { safe=false; lifecycle.discoveryError=String(error); }
          if (safe && owner && await same(owner) && (await identity(owner.pid))?.group === owner.group) {
            lifecycle.beforeTerm = owned;
            try { process.kill(-owner.group, 'SIGTERM'); } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error; }
          } else if (child.exitCode === null && !child.signalCode) { if (!owner) safe=false; child.kill('SIGTERM'); }
          const deadline = Date.now() + 5500;
          while (!reaped && Date.now() < deadline) await delay(25);
          try { if (owner) owned = [...new Map([...owned,...await fixtureProcesses(owner,nonce)].map(record => [record.pid,record])).values()]; }
          catch (error) { safe=false; lifecycle.discoveryError=String(error); }
          for (const record of [...owned].reverse()) if (await same(record)) {
            try { process.kill(record.pid, 'SIGKILL'); } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error; }
          }
          if (child.exitCode === null && !child.signalCode) child.kill('SIGKILL');
          const end = Date.now()+2000;
          while (Date.now()<end && (!reaped || (await Promise.all(owned.map(same))).some(Boolean))) await delay(25);
          lifecycle.exit = { code: child.exitCode, signal: child.signalCode, reaped };
          lifecycle.remaining = await Promise.all(owned.map(async record => ({ ...record, alive: await same(record) })));
          if (!reaped || (lifecycle.remaining as {alive:boolean}[]).some(record => record.alive)) safe = false;
        }
        if (root) {
          lifecycle.zoomCleanup=cleanup; if (!cleanup.safe) safe=false;
          try { lifecycle.retentionReason=await fs.readFile(path.join(root,'retain-scratch'),'utf8'); safe=false; }
          catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
          const profile = path.join(root,'zoom-profile');
          lifecycle.profileRemaining = await profileProcesses(profile);
          if ((lifecycle.profileRemaining as Identity[]).length) safe = false;
          const stat = await fs.lstat(root);
          safe &&= inode !== undefined && device === stat.dev && stat.ino === inode && !stat.isSymbolicLink() &&
            await fs.realpath(root) === root && path.dirname(root) === parent && await fs.readFile(path.join(root,'nonce'),'utf8') === nonce;
          if (!safe) throw new Error('Uncertain cleanup ownership; retained scratch');
          lifecycle.listenerAfter=await listeners(3872,owned);
          await portFree(); lifecycle.portFreeAfter=true;
          await fs.rm(root, { recursive: true }); lifecycle.scratchRemoved = true;
        }
      } finally {
        lifecycle.log = log; lifecycle.safe = safe; lifecycle.postSource = await snapshot();
        await attach(info,'component-cleanup',lifecycle); expect(lifecycle.postSource).toEqual(before);
      }
    }
  },
});

async function open(page: Page, component: { nonce: string }) {
  await page.goto(url);
  await expect(page.locator('#fixture')).toHaveAttribute('data-nonce', component.nonce);
  await expect(page.locator('#activations')).toHaveText('Activations 0');
  await expect(page.locator('#a-act')).toHaveClass(/(?:^|\s)shiny-bound-input(?:\s|$)/);
}
const actionIds = ['a-act','b-act','a-update','a-unavailable','a-filled','a-open','a-change','a-remove'];
const dialogKeys = ['a-confirm-cancel','a-confirm-confirm'];
async function layout(page: Page, info: TestInfo, name: string) {
  const bounds = await page.evaluate(() => {
    const region = document.querySelector<HTMLElement>('.rs-workspace-table-scroll')!;
    return { innerWidth, innerHeight, outerWidth, outerHeight, dpr: devicePixelRatio,
      visualScale: visualViewport?.scale, screenWidth: screen.width, screenHeight: screen.height, rootWidth: document.documentElement.scrollWidth,
      region: { width: region.clientWidth, scroll: region.scrollWidth, label: region.getAttribute('aria-labelledby'), tab: region.tabIndex },
      inventory: [...document.querySelectorAll<HTMLButtonElement>('#fixture button')].map(button => button.id || 'a-confirm-'+button.value) };
  });
  expect(bounds.inventory.sort()).toEqual([...actionIds,...dialogKeys].sort());
  expect(bounds.rootWidth).toBeLessThanOrEqual(bounds.innerWidth);
  if (bounds.innerWidth <= 640) expect(bounds.region.scroll).toBeGreaterThan(bounds.region.width);
  expect(bounds.region.tab).toBe(0); expect(bounds.region.label).toBe('a-table-heading');
  const actions = [];
  for (const id of actionIds) {
    const button=page.locator('#'+id); await expect(button).toHaveCount(1);
    const rect=await button.boundingBox(); expect(rect,id).not.toBeNull();
    expect(rect!.width,id).toBeGreaterThanOrEqual(44); expect(rect!.height,id).toBeGreaterThanOrEqual(44);
    expect(rect!.x,id).toBeGreaterThanOrEqual(0); expect(rect!.x+rect!.width,id).toBeLessThanOrEqual(bounds.innerWidth);
    expect(await button.evaluate(element => !!element.closest('.rs-workspace-table-scroll')),id).toBe(false);
    actions.push({id,...rect});
  }
  // Native Tab traversal scrolls enabled actions into view; unavailable controls are inspected separately.
  const keyboardIds=actionIds.filter(id => id !== 'a-unavailable'), reached: string[] = [];
  await page.locator('#context').focus();
  for (let index=0;index<20 && reached.length<keyboardIds.length;index++) {
    await page.keyboard.press('Tab');
    const id=await page.evaluate(() => document.activeElement?.id ?? '');
    if (keyboardIds.includes(id) && !reached.includes(id)) { await expect(page.locator('#'+id)).toBeInViewport(); reached.push(id); }
  }
  expect(reached).toEqual(keyboardIds);
  await page.locator('#a-unavailable').scrollIntoViewIfNeeded();
  await expect(page.locator('#a-unavailable')).toBeInViewport(); await expect(page.locator('#a-unavailable')).toBeDisabled();
  const dialog=page.locator('#a-confirm'), cancel=dialog.locator('button[value=cancel]'), confirm=dialog.locator('button[value=confirm]');
  const applied=Number(await page.locator('#applied').textContent());
  await page.locator('#a-open').focus(); await page.keyboard.press('Enter'); await expect(cancel).toBeFocused();
  const dialogActions=[];
  for (const [key,button] of [[dialogKeys[0],cancel],[dialogKeys[1],confirm]] as const) {
    await button.scrollIntoViewIfNeeded(); const rect=await button.boundingBox(); expect(rect,key).not.toBeNull();
    expect(rect!.width,key).toBeGreaterThanOrEqual(44); expect(rect!.height,key).toBeGreaterThanOrEqual(44);
    expect(rect!.x,key).toBeGreaterThanOrEqual(0); expect(rect!.x+rect!.width,key).toBeLessThanOrEqual(bounds.innerWidth);
    await expect(button).toBeInViewport(); dialogActions.push({key,...rect});
  }
  await page.keyboard.press('Tab'); await expect(confirm).toBeFocused(); await expect(confirm).toBeInViewport();
  await page.keyboard.press('Shift+Tab'); await expect(cancel).toBeFocused(); await page.keyboard.press('Enter');
  await expect(dialog).not.toBeVisible(); await expect(page.locator('#applied')).toHaveText(String(applied));
  await expect(page.locator('#a-open')).toBeFocused(); await page.keyboard.press('Enter'); await expect(cancel).toBeFocused();
  await page.keyboard.press('Tab'); await expect(confirm).toBeFocused(); await page.keyboard.press('Enter');
  await expect(dialog).not.toBeVisible(); await expect(page.locator('#applied')).toHaveText(String(applied+1));
  await expect(page.locator('#a-open')).toBeFocused(); await expect(page.locator('#a-open')).toBeInViewport();
  await attach(info,name,{...bounds,actions,keyboardReached:reached,dialogActions});
  await info.attach(`${name}.png`, { body: await page.screenshot({ fullPage: true }), contentType: 'image/png' });
  return bounds;
}

async function focusContrast(page: Page, selector: string, info: TestInfo) {
  await page.locator(selector).focus();
  const initial=(await focusSettlement(page,selector,false)).immediate;
  await page.keyboard.press('Tab'); await page.keyboard.press('Shift+Tab');
  const settlement=await focusSettlement(page,selector,true);
  const settled=settlement.settled;
  const measured={selector,nativeKeys:['Tab','Shift+Tab'],initial,settlement,
    outlineToSeparator:settled?.ratios?.outlineToSeparator,outlineToAdjacent:settled?.ratios?.outlineToAdjacent,
    separatorToFill:settled?.ratios?.separatorToFill,separatorToAdjacent:settled?.ratios?.separatorToAdjacent,text:settled?.ratios?.text,
    outlineStyle:settled?.style.outlineStyle,outlineWidth:settled?.style.outlineWidth,outlineOffset:settled?.style.outlineOffset};
  await attach(info,'focused-contrast-'+selector.slice(1),measured);
  expect(settlement.completion.status).toBe('settled'); expect(settlement.completion.stableFrames).toBeGreaterThanOrEqual(2);
  expect(settled?.measurementError).toBeNull(); expect(settled?.focused).toBe(true);
  expect(settled?.documentFocused).toBe(true); expect(settled?.focusVisible).toBe(true);
  await expect(page.locator(selector)).toBeFocused();
  expect(measured.outlineStyle).toBe('solid'); expect(measured.outlineWidth).toBe('3px'); expect(measured.outlineOffset).toBe('2px');
  expect(measured.outlineToSeparator).toBeGreaterThanOrEqual(3);
  expect(Math.max(measured.outlineToAdjacent!,measured.separatorToAdjacent!)).toBeGreaterThanOrEqual(3);
  expect(measured.text).toBeGreaterThanOrEqual(4.5);
  if (selector === '#a-filled') { expect(measured.separatorToFill).toBeGreaterThanOrEqual(3); expect(measured.separatorToAdjacent).toBeGreaterThanOrEqual(3); }
}

async function effectiveContrast(page: Page, selector: string) {
  return page.locator(selector).first().evaluate((element,selector) => {
    type Color=[number,number,number,number];
    const color=(value:string):Color => {
      const n=value.match(/[\d.]+/g)?.map(Number); if (!n || n.length<3) throw new Error('Unsupported computed color');
      return [n[0]/255,n[1]/255,n[2]/255,n[3] ?? 1];
    };
    const blend=(a:Color,b:Color):Color => [a[0]*a[3]+b[0]*(1-a[3]),a[1]*a[3]+b[1]*(1-a[3]),a[2]*a[3]+b[2]*(1-a[3]),1];
    const lum=(c:Color) => c.slice(0,3).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
    const ratio=(a:Color,b:Color)=>(Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
    const chain:Element[]=[]; for (let e:Element|null=element;e;e=e.parentElement) chain.unshift(e);
    let background:Color=[1,1,1,1], opacity=1;
    for (const e of chain) {
      const c=getComputedStyle(e); if (c.backgroundImage!=='none') throw new Error('Background image requires explicit composed-surface review');
      background=blend(color(c.backgroundColor),background); opacity*=Number(c.opacity);
    }
    if (opacity!==1) throw new Error('Opacity requires explicit composed-layer review');
    const c=getComputedStyle(element);
    return {selector,color:c.color,background,opacity,text:ratio(blend(color(c.color),background),background),
      boundary:ratio(color(c.borderTopColor),background),outline:c.outlineStyle,outlineColor:c.outlineColor,
      outlineWidth:c.outlineWidth,outlineOffset:c.outlineOffset,shadow:c.boxShadow};
  },selector);
}

async function resolveIncomplete(page: Page, info: TestInfo, nonce: string, results: AxeResults) {
  const decorative=[{selector:'.rs-workspace-dataset-circle > span[aria-hidden="true"]',code:'D-A',id:'ds-a',symbol:'●'},
    {selector:'.rs-workspace-dataset-square > span[aria-hidden="true"]',code:'D-B',id:'ds-b',symbol:'■'}];
  const cells=info.project.name==='chromium-narrow' ? Array.from({length:15},(_,index)=>`td:nth-child(${index+11})`) : [];
  const key=(rule:string,target:unknown,group:string,check:string,message:unknown)=>JSON.stringify([rule,target,group,check,message]);
  const observed=results.incomplete.flatMap(rule=>rule.nodes.flatMap(node=>(['any','all','none'] as const)
    .flatMap(group=>node[group].map(check=>({key:key(rule.id,node.target,group,check.id,check.data?.messageKey),ruleId:rule.id,node,group,check})))));
  const expected=[...decorative.map(item=>key('color-contrast',[item.selector],'any','color-contrast','nonBmp')),
    ...cells.map(selector=>key('color-contrast',[selector],'any','color-contrast','elmPartiallyObscured'))].sort();
  const observedKeys=observed.map(item=>item.key).sort(), ledger: unknown[]=[], resolvedKeys:string[]=[], collectionErrors:string[]=[];
  let restoration: {before:unknown;after:unknown;restored:boolean}|undefined;
  const region=page.locator('#a-table .rs-workspace-table-scroll');
  const initial=await region.evaluate(element=>({left:element.scrollLeft,top:element.scrollTop,x:scrollX,y:scrollY}));
  try {
    for (const item of observed) {
      const entry:Record<string,unknown>={...item,target:item.node.target,disposition:'unresolved'}; ledger.push(entry);
      try {
      expect(item.node.target).toHaveLength(1); const selector=String(item.node.target[0]);
      const element=page.locator(selector); await expect(element).toHaveCount(1);
      const cue=decorative.find(cue=>cue.selector===selector);
      let observation: unknown, threshold: number;
      if (cue) {
        await element.evaluate(element=>element.scrollIntoView({block:'nearest',inline:'center',behavior:'instant'}));
        const state=await element.evaluate(element=>{
          const parent=element.parentElement!, rect=element.getBoundingClientRect(), style=getComputedStyle(element);
          return {ariaHidden:element.getAttribute('aria-hidden'),tabIndex:(element as HTMLElement).tabIndex,
            interactive:!!element.closest('a,button,input,select,textarea,[role=button],[role=link],[contenteditable=true]'),
            parentHidden:!!parent.closest('[aria-hidden=true],[inert]'),parentText:parent.textContent,symbol:element.textContent,
            width:rect.width,height:rect.height,visibility:style.visibility,display:style.display};
        });
        entry.observation=state;
        expect(state).toMatchObject({ariaHidden:'true',interactive:false,parentHidden:false,symbol:cue.symbol,visibility:'visible'});
        expect(state.tabIndex).toBeLessThan(0); expect(state.width).toBeGreaterThan(0); expect(state.height).toBeGreaterThan(0);
        expect(state.parentText).toContain(cue.code); expect(state.parentText).toContain(cue.id);
        const labelContrast=await effectiveContrast(page,selector.split(' > ')[0]);
        observation={...state,accessibleTextCode:cue.code,stableId:cue.id,labelContrast}; entry.observation=observation;
        expect(labelContrast.text).toBeGreaterThanOrEqual(4.5); threshold=3;
      } else {
        const state:{scrollControl:{block:string;inline:string;behavior:string};before?:Awaited<ReturnType<typeof cellObservation>>;
          after?:Awaited<ReturnType<typeof cellObservation>>}={scrollControl:{block:'center',inline:'center',behavior:'instant'}};
        entry.observation=state;
        state.before=await cellObservation(page,selector);
        await element.evaluate(element=>element.scrollIntoView({block:'center',inline:'center',behavior:'instant'}));
        state.after=await cellObservation(page,selector);
        const after=state.after;
        entry.measurement=await effectiveContrast(page,selector);
        expect(cells).toContain(selector); await expect(region).toHaveAttribute('aria-labelledby','a-table-heading');
        await expect(region).toHaveAttribute('aria-describedby','a-table-help');
        await expect(page.locator('#a-table-heading')).toHaveText('Synthetic recorded results');
        await expect(page.locator('#a-table-help')).toHaveText('Scroll horizontally to view all columns');
        expect(after.cell.text).toBe('Not supplied'); expect(after.region.style.overflowX).toBe('auto');
        expect(after.region.scrollWidth).toBeGreaterThan(after.region.clientWidth); expect(after.region.scrollLeft).toBeGreaterThan(0);
        expect(after.textRanges.length).toBeGreaterThan(0);
        for (const range of after.textRanges) {
          expect(range.rects.length).toBeGreaterThan(0);
          for (const text of range.rects) {
            const bounds=text.bounds;
            expect(bounds.width).toBeGreaterThan(0); expect(bounds.height).toBeGreaterThan(0);
            expect(bounds.left).toBeGreaterThanOrEqual(0); expect(bounds.right).toBeLessThanOrEqual(after.window.innerWidth);
            expect(bounds.top).toBeGreaterThanOrEqual(0); expect(bounds.bottom).toBeLessThanOrEqual(after.window.innerHeight);
            for (const clip of after.clippingAncestors) {
              expect(clip.style.clip).toBe('auto'); expect(clip.style.clipPath).toBe('none');
              if (clip.style.overflowX!=='visible') {
                expect(bounds.left).toBeGreaterThanOrEqual(clip.clientBounds.left); expect(bounds.right).toBeLessThanOrEqual(clip.clientBounds.right);
              }
              if (clip.style.overflowY!=='visible') {
                expect(bounds.top).toBeGreaterThanOrEqual(clip.clientBounds.top); expect(bounds.bottom).toBeLessThanOrEqual(clip.clientBounds.bottom);
              }
            }
            expect(text.samples).toHaveLength(5);
            for (const sample of text.samples) {
              expect(sample.withinCell).toBe(true); expect(sample.hit?.tag).toBe('TD');
              expect(sample.hit?.path.endsWith(' > '+selector)).toBe(true);
              expect(sample.hitColors?.opacity).toBe('1'); expect(sample.hitColors?.backgroundImage).toBe('none');
            }
          }
        }
        observation=state; threshold=4.5;
      }
      const measured=(entry.measurement as Awaited<ReturnType<typeof effectiveContrast>>|undefined) ?? await effectiveContrast(page,selector);
      Object.assign(entry,{observation,measurement:measured,contrast:measured.text,threshold});
      expect(measured.text).toBeGreaterThanOrEqual(threshold);
      entry.disposition='resolved'; resolvedKeys.push(item.key);
      } catch (error) { entry.error=String(error); collectionErrors.push(item.key+': '+String(error)); }
    }
    expect(observedKeys,'Every raw incomplete check must have exactly one explicit resolution').toEqual(expected);
    expect(collectionErrors,'Every raw check requires complete retained proof').toEqual([]);
    expect(resolvedKeys.sort()).toEqual(observedKeys);
  } finally {
    try {
      const after=await region.evaluate((element,before)=>{element.scrollTo({left:before.left,top:before.top,behavior:'instant'});
        window.scrollTo({left:before.x,top:before.y,behavior:'instant'}); return {left:element.scrollLeft,top:element.scrollTop,x:scrollX,y:scrollY};},initial);
      restoration={before:initial,after,restored:Object.keys(initial).every(key=>initial[key as keyof typeof initial]===after[key as keyof typeof after])};
      if (!restoration.restored) collectionErrors.push('Scroll restoration mismatch');
    } catch (error) { collectionErrors.push('Scroll restoration: '+String(error)); }
    await attach(info,'axe-incomplete-resolution',{project:info.project.name,nonce,observedKeys,resolvedKeys:resolvedKeys.sort(),ledger,collectionErrors,restoration});
  }
  expect(collectionErrors,'Complete proof and exact scroll restoration required').toEqual([]);
}

// Measurement only: settlement depends on transitions and stable rendered styles, never ratios.
async function focusSettlement(page: Page, selector: string, settle: boolean) {
  return page.evaluate(async ({selector,settle}) => {
    const element=document.querySelector<HTMLElement>(selector);
    if (!element || typeof element.getAnimations!=='function') throw new Error('Focus animation observation unavailable');
    const started=performance.now(), timeoutMs=2000;
    const capture=() => {
      const c=getComputedStyle(element), rect=element.getBoundingClientRect();
      const chain:Element[]=[]; for (let node=element.parentElement;node;node=node.parentElement) chain.unshift(node);
      const surfaces=chain.map(node=>{const s=getComputedStyle(node); return {tag:node.tagName,id:node.id,
        background:s.backgroundColor,image:s.backgroundImage,opacity:s.opacity};});
      const sample={atMs:performance.now(),elapsedMs:performance.now()-started,timeOrigin:performance.timeOrigin,
        focused:document.activeElement===element,documentFocused:document.hasFocus(),focusVisible:element.matches(':focus-visible'),
        geometry:{x:rect.x,y:rect.y,width:rect.width,height:rect.height},
        style:{color:c.color,background:c.backgroundColor,opacity:c.opacity,image:c.backgroundImage,shadow:c.boxShadow,
          outline:c.outlineColor,outlineStyle:c.outlineStyle,outlineWidth:c.outlineWidth,outlineOffset:c.outlineOffset,
          borderColor:c.borderColor},surfaces,
        animations:element.getAnimations().map(animation=>({type:animation.constructor.name,id:animation.id,
          playState:animation.playState,pending:animation.pending,currentTime:String(animation.currentTime),startTime:String(animation.startTime),
          playbackRate:animation.playbackRate,timing:animation.effect?.getComputedTiming(),
          property:typeof CSSTransition!=='undefined' && animation instanceof CSSTransition ? animation.transitionProperty : undefined})),
        ratios:null as Record<string,number>|null,measurementError:null as string|null};
      try {
        type Color=[number,number,number,number];
        const color=(text:string):Color=>{const n=text.match(/[\d.]+/g)?.map(Number); if (!n || n.length<3) throw new Error('Unsupported computed color');
          return [n[0]/255,n[1]/255,n[2]/255,n[3] ?? 1];};
        const blend=(a:Color,b:Color):Color=>[a[0]*a[3]+b[0]*(1-a[3]),a[1]*a[3]+b[1]*(1-a[3]),a[2]*a[3]+b[2]*(1-a[3]),1];
        const lum=(a:Color)=>a.slice(0,3).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,index)=>sum+v*[.2126,.7152,.0722][index],0);
        const ratio=(a:Color,b:Color)=>(Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
        let adjacent:Color=[1,1,1,1];
        for (const surface of surfaces) {
          if (Number(surface.opacity)!==1 || surface.image!=='none') throw new Error('Unsupported composed focus surface');
          adjacent=blend(color(surface.background),adjacent);
        }
        if (Number(c.opacity)!==1 || c.backgroundImage!=='none') throw new Error('Unsupported focused surface');
        const shadows=c.boxShadow.match(/rgba?\([^)]*\)/g);
        if (!shadows || shadows.length!==1 || c.boxShadow.includes('inset')) throw new Error('Unsupported focus separator');
        const fill=blend(color(c.backgroundColor),adjacent), outline=blend(color(c.outlineColor),adjacent), separator=blend(color(shadows[0]),adjacent);
        sample.ratios={outlineToSeparator:ratio(outline,separator),outlineToAdjacent:ratio(outline,adjacent),
          separatorToFill:ratio(separator,fill),separatorToAdjacent:ratio(separator,adjacent),text:ratio(blend(color(c.color),fill),fill)};
      } catch (error) { sample.measurementError=String(error); }
      return sample;
    };
    const immediate=capture(), frames:ReturnType<typeof capture>[]=[];
    const result=(status:string,stableFrames:number,error?:string)=>({immediate,settled:status==='settled' ? frames.at(-1) : undefined,
      frames,completion:{status,timeoutMs,elapsedMs:performance.now()-started,stableFrames,error}});
    if (!settle) return result('initial',0);
    return new Promise<ReturnType<typeof result>>(resolve=>{
      let signature='', stableFrames=0, frame=0, finished=false;
      const finish=(status:string,error?:string)=>{if (finished) return; finished=true; clearTimeout(deadline); cancelAnimationFrame(frame); resolve(result(status,stableFrames,error));};
      const deadline=setTimeout(()=>finish('timeout','Relevant animation/style settlement not established'),timeoutMs);
      const tick=()=>{
        try {
          const sample=capture(); frames.push(sample);
          if (!sample.focused || !sample.documentFocused) { finish('focus-lost','Native focus left measured control'); return; }
          if (sample.measurementError) { finish('unsupported',sample.measurementError); return; }
          const active=sample.animations.some(animation=>animation.pending || !['finished','idle'].includes(animation.playState));
          const next=JSON.stringify({style:sample.style,surfaces:sample.surfaces,geometry:sample.geometry,focusVisible:sample.focusVisible});
          stableFrames=!active ? (next===signature ? stableFrames+1 : 1) : 0;
          signature=active ? '' : next;
          if (stableFrames>=2) { finish('settled'); return; }
          frame=requestAnimationFrame(tick);
        } catch (error) { finish('unsupported',String(error)); }
      };
      frame=requestAnimationFrame(tick);
    });
  },{selector,settle});
}

async function cellObservation(page: Page, selector: string) {
  return page.evaluate(selector=>{
    const elements=document.querySelectorAll<HTMLElement>(selector);
    if (elements.length!==1) throw new Error('Expected one exact cell: '+selector);
    const cell=elements[0], region=cell.closest<HTMLElement>('.rs-workspace-table-scroll');
    if (!region) throw new Error('Missing contained table region');
    const bounds=(rect:DOMRect)=>({x:rect.x,y:rect.y,left:rect.left,right:rect.right,top:rect.top,bottom:rect.bottom,width:rect.width,height:rect.height});
    const identity=(node:Element)=>{
      const parts:string[]=[]; for (let e:Element|null=node;e;e=e.parentElement) {
        parts.unshift(e.tagName.toLowerCase()+(e.id ? '#'+e.id : ':nth-child('+(e.parentElement ? Array.from(e.parentElement.children).indexOf(e)+1 : 1)+')'));
      }
      return {tag:node.tagName,id:node.id,classes:node.getAttribute('class'),role:node.getAttribute('role'),path:parts.join(' > '),text:node.textContent?.slice(0,160)};
    };
    const styles=(node:Element)=>{const c=getComputedStyle(node); return {color:c.color,backgroundColor:c.backgroundColor,
      backgroundImage:c.backgroundImage,opacity:c.opacity,overflowX:c.overflowX,overflowY:c.overflowY,clip:c.clip,clipPath:c.clipPath,
      position:c.position,zIndex:c.zIndex,fontSize:c.fontSize,lineHeight:c.lineHeight,whiteSpace:c.whiteSpace,padding:c.padding,border:c.border,
      borderCollapse:c.borderCollapse,visibility:c.visibility,display:c.display};};
    const samples=(rect:DOMRect)=>{
      const inset=Math.min(2,rect.width/4,rect.height/4);
      return [[rect.left+inset,rect.top+inset],[rect.right-inset,rect.top+inset],[rect.left+inset,rect.bottom-inset],
        [rect.right-inset,rect.bottom-inset],[(rect.left+rect.right)/2,(rect.top+rect.bottom)/2]]
        .map(([x,y])=>{const hit=document.elementFromPoint(x,y); return {x,y,hit:hit ? identity(hit) : null,hitColors:hit ? styles(hit) : null,
          withinCell:!!hit && cell.contains(hit)};});
    };
    const clippingAncestors=[];
    for (let node=cell.parentElement;node;node=node.parentElement) {
      const style=styles(node), rect=node.getBoundingClientRect();
      if (style.overflowX!=='visible' || style.overflowY!=='visible' || style.clip!=='auto' || style.clipPath!=='none') {
        clippingAncestors.push({identity:identity(node),bounds:bounds(rect),clientBounds:{left:rect.left+node.clientLeft,
          right:rect.left+node.clientLeft+node.clientWidth,top:rect.top+node.clientTop,bottom:rect.top+node.clientTop+node.clientHeight},style});
      }
    }
    const textRanges=[]; const walker=document.createTreeWalker(cell,NodeFilter.SHOW_TEXT);
    for (let node=walker.nextNode();node;node=walker.nextNode()) {
      if (!node.textContent?.trim()) continue;
      const range=document.createRange(); range.selectNodeContents(node);
      textRanges.push({text:node.textContent,rects:Array.from(range.getClientRects()).map(rect=>({bounds:bounds(rect),samples:samples(rect)}))});
    }
    return {atMs:performance.now(),timeOrigin:performance.timeOrigin,window:{scrollX,scrollY,innerWidth,innerHeight},
      region:{bounds:bounds(region.getBoundingClientRect()),scrollLeft:region.scrollLeft,scrollTop:region.scrollTop,
        clientWidth:region.clientWidth,clientHeight:region.clientHeight,scrollWidth:region.scrollWidth,scrollHeight:region.scrollHeight,style:styles(region)},
      cell:{bounds:bounds(cell.getBoundingClientRect()),text:cell.textContent,style:styles(cell)},clippingAncestors,
      wholeCellSamples:samples(cell.getBoundingClientRect()),textRanges};
  },selector);
}

test('REQ002 AC002 native bindings, namespaces, escaped text and computed typography', async ({ page, component }, info) => {
  await open(page, component);
  const hostile = '<img src=x onerror=alert(1)> =SUM(1,2)';
  await expect(page.locator('#a-act')).toHaveText(hostile); await expect(page.locator('#a-card-heading')).toHaveText(hostile);
  await expect(page.locator('#fixture img')).toHaveCount(0);
  await expect(page.locator('.rs-workspace-dataset-circle')).toContainText('D-A');
  await expect(page.locator('.rs-workspace-dataset-square')).toContainText('D-B');
  await expect(page.locator('#a-field')).toHaveAccessibleName('Display filter');
  await expect(page.locator('#a-field')).toHaveAccessibleDescription('Preview only Keep the recorded value');
  await expect(page.locator('#a-field')).toHaveAttribute('aria-invalid','true');
  await expect(page.locator('#b-field')).toHaveValue('Preserved');
  await expect(page.locator('#a-a-act')).toHaveCount(0); await expect(page.locator('#b-act')).toHaveCount(1);
  await expect(page.locator('#a-card dd').first()).toHaveText('Not recorded');
  await expect(page.locator('#a-card dd').nth(1)).toHaveText('0');
  await expect(page.locator('#a-unavailable')).toBeDisabled();
  await expect(page.locator('#a-unavailable')).toHaveAccessibleDescription('Membership not supplied');
  await page.locator('#a-act').focus(); await page.keyboard.press('Enter');
  await expect(page.locator('#activations')).toHaveText('Activations 1');
  await page.keyboard.press('Space'); await expect(page.locator('#activations')).toHaveText('Activations 2');
  await page.locator('#a-update').click();
  await expect(page.locator('#a-act')).toHaveText('Updated native action');
  await expect(page.locator('#a-act > .action-label')).toHaveCount(1);
  await page.locator('#a-act').focus(); await page.keyboard.press('Enter');
  await expect(page.locator('#activations')).toHaveText('Activations 3');
  const styles = await page.evaluate(() => {
    const css = (selector: string, properties: string[]) => {
      const c = getComputedStyle(document.querySelector(selector)!);
      return Object.fromEntries(properties.map(key => [key, c.getPropertyValue(key)]));
    };
    return { root: css('html',['font-size']), body: css('#fixture',['font-size']), input: css('#a-field',['font-size']),
      heading: css('#a-card h3',['font-size']), helper: css('#a-field-help',['font-size']), table: css('#a-table table',['font-size']),
      label: css('label[for=a-field]',['margin-bottom']), field: css('#a-field-help',['margin-top']),
      fieldGroup: css('.rs-workspace-field',['margin-bottom']),
      card: css('#a-card',['padding-top','padding-right']), actions: css('.rs-workspace-actions',['gap']),
      th: css('th',['padding-top','padding-right']), td: css('td',['padding-top','padding-right']) };
  });
  await attach(info,'computed-typography',styles);
  expect(styles.root['font-size']).toBe('10px');
  for (const item of [styles.body,styles.input]) expect(item['font-size']).toBe('14px');
  expect(styles.heading['font-size']).toBe('16px');
  for (const item of [styles.helper,styles.table]) expect(item['font-size']).toBe('13px');
  expect(styles.label['margin-bottom']).toBe('4px'); expect(styles.fieldGroup['margin-bottom']).toBe('12px');
  expect(styles.card).toEqual({ 'padding-top':'16px','padding-right':'16px' });
  expect(styles.actions.gap).toBe('8px'); expect(styles.th).toEqual({ 'padding-top':'10px','padding-right':'12px' });
  expect(styles.td).toEqual({ 'padding-top':'8px','padding-right':'12px' });
  await layout(page,info,'native-layout');
});

test('REQ002 AC002 native modal safe cancel, containment, fresh revalidation and fallback', async ({ page, component }, info) => {
  await open(page,component);
  const dialog=page.locator('#a-confirm'), cancel=dialog.getByRole('button',{name:'Cancel'}), confirm=dialog.getByRole('button',{name:'Remove ds-a'});
  const focusStates: unknown[]=[];
  const recordFocus=async (step:string) => {
    const state=await page.evaluate(() => {
      const dialog=document.querySelector<HTMLDialogElement>('#a-confirm')!, active=document.activeElement;
      return {activeTag:active?.tagName,activeId:active?.id,activeValue:active?.getAttribute('value'),documentFocused:document.hasFocus(),
        insideDialog:!!active && dialog.contains(active),dialogOpen:dialog.open,modal:dialog.matches(':modal')};
    });
    focusStates.push({step,...state}); return state;
  };
  const reopen=async () => {
    await page.locator('#a-open').focus(); await page.keyboard.press('Enter');
    await expect(dialog).toBeVisible(); await expect(cancel).toBeFocused();
  };
  await reopen(); await recordFocus('opened-Cancel');
  await page.keyboard.press('Shift+Tab'); const previous=await recordFocus('Shift+Tab-from-Cancel');
  expect(previous.dialogOpen && previous.modal).toBe(true);
  if (previous.documentFocused) { expect(previous.insideDialog).toBe(true); await expect(confirm).toBeFocused(); }
  else { expect(previous.activeTag).toBe('BODY'); expect(previous.insideDialog).toBe(false); }
  // A native Tab returns from outside-document focus; no page control may become active while modal.
  await page.keyboard.press('Tab'); await expect(cancel).toBeFocused(); await recordFocus('Tab-to-Cancel');
  await page.keyboard.press('Tab'); await expect(confirm).toBeFocused(); await recordFocus('Tab-to-confirm');
  await page.keyboard.press('Shift+Tab'); await expect(cancel).toBeFocused(); await recordFocus('Shift+Tab-to-Cancel');
  await expect(page.locator('#activations')).toHaveText('Activations 0');
  await page.keyboard.press('Escape'); await expect(dialog).not.toBeVisible(); await expect(page.locator('#a-open')).toBeFocused();
  await expect(page.locator('#applied')).toHaveText('0');
  await reopen(); await page.keyboard.press('Enter'); await expect(dialog).not.toBeVisible();
  await expect(page.locator('#applied')).toHaveText('0'); await expect(page.locator('#a-open')).toBeFocused();
  await reopen();
  // This caller-only dispatch models a concurrent revision change; submission stays native.
  await page.locator('#a-change').dispatchEvent('click');
  await page.keyboard.press('Tab'); await expect(confirm).toBeFocused(); await page.keyboard.press('Enter');
  await expect(dialog).toBeVisible(); await expect(page.locator('#diagnostic')).toHaveText('Target changed; open a fresh confirmation');
  await expect(page.locator('#applied')).toHaveText('0');
  await page.keyboard.press('Shift+Tab'); await expect(cancel).toBeFocused(); await page.keyboard.press('Enter'); await expect(dialog).not.toBeVisible();
  await reopen(); await expect(page.locator('#diagnostic')).toBeEmpty();
  await page.keyboard.press('Tab'); await expect(confirm).toBeFocused(); await page.keyboard.press('Enter');
  await expect(dialog).not.toBeVisible(); await expect(page.locator('#applied')).toHaveText('1'); await expect(page.locator('#a-open')).toBeFocused();
  await reopen(); await page.locator('#a-remove').dispatchEvent('click');
  await page.keyboard.press('Enter'); await expect(dialog).not.toBeVisible(); await expect(page.locator('#context')).toBeFocused();
  await page.keyboard.press('Tab'); await expect(page.locator('#a-field')).toBeFocused();
  await attach(info,'modal-keyboard',{project:info.project.name,nonce:component.nonce,focusStates,applied:1,fallback:true});
});

test('REQ002 REQ004 AC002 AC003 real axe, effective contrast, focus and reduced motion', async ({ page, component }, info) => {
  await open(page,component);
  const asset = requireLocal.resolve('axe-core/axe.min.js');
  const metadata = requireLocal('axe-core/package.json') as { name: string; version: string; license: string };
  expect(metadata).toMatchObject({ name:'axe-core',version:'4.14.0',license:'MPL-2.0' });
  await page.addScriptTag({ path: asset });
  const options: RunOptions = { reporter:'v2', resultTypes:['violations','incomplete','passes','inapplicable'] };
  const scan = await page.evaluate(async options => {
    const axe = (window as unknown as { axe: { version: string; run(context: Document, options: RunOptions): Promise<AxeResults> } }).axe;
    return { version: axe.version, results: await axe.run(document,options) };
  },options);
  await attach(info,'axe-full',{ project:info.project.name, url:page.url(), nonce:component.nonce, options, metadata,
    assetSha256:sha(await fs.readFile(asset)), ...scan });
  expect(scan.version).toBe('4.14.0'); expect(scan.results.violations).toEqual([]);
  await resolveIncomplete(page,info,component.nonce,scan.results);
  await page.locator('#a-act').focus(); await page.keyboard.press('Tab'); await page.keyboard.press('Shift+Tab');
  const selectors=['#a-act','#a-filled','#a-unavailable','#a-field','#a-field-help','#a-field-error','#a-card','#a-table th','#a-table td',
    ...['queued','running','failed','succeeded','stop-requested','cancelled','detached','interrupted'].map(x => '#a-'+x)];
  const contrast=[];
  for (const selector of selectors) contrast.push(await effectiveContrast(page,selector));
  await attach(info,'effective-contrast',contrast);
  for (const item of contrast) expect(item.text,item.selector).toBeGreaterThanOrEqual(4.5);
  for (const item of contrast.filter(x => ['#a-act','#a-unavailable','#a-field'].includes(x.selector))) expect(item.boundary,item.selector).toBeGreaterThanOrEqual(3);
  await focusContrast(page,'#a-act',info);
  await focusContrast(page,'#a-filled',info);
  for (const state of ['running','failed','succeeded']) {
    await expect(page.locator('#a-'+state)).toBeVisible(); await expect(page.locator('#a-'+state)).not.toHaveAttribute('aria-busy','true');
  }
  await page.emulateMedia({ reducedMotion:'reduce' });
  const motion = await page.locator('.rs-workspace, .rs-workspace *, #loading-overlay, #loading-overlay *').evaluateAll(elements =>
    elements.map(element => { const c=getComputedStyle(element); return { id:element.id, animation:c.animationName, transition:c.transitionDuration, transform:c.transform }; }));
  await attach(info,'reduced-motion',motion);
  for (const item of motion) { expect(item.animation).toBe('none'); expect(item.transition).toBe('0s'); expect(item.transform).toBe('none'); }
  await expect(page.locator('#a-running')).toContainText('Running — progress not reported');
});

test('REQ003 AC003 recreated MV3 native 200 percent zoom retains reachable actions', async ({ component }, info) => {
  test.setTimeout(120_000); await nativeZoom(component,info);
});
async function nativeZoom(component: Component, info: TestInfo) {
  let context: Awaited<ReturnType<typeof chromium.launchPersistentContext>> | undefined;
  const profile=path.join(component.root,'zoom-profile'), extension=path.join(component.root,'zoom-extension');
  let restore: (() => Promise<number>) | undefined;
  // Shared memory stays unsafe even if writing a retention marker fails.
  component.cleanup.safe=false; component.cleanup.reason='Zoom allocation/cleanup not yet verified';
  let launched=false, launchSettled=false;
  let launchObserved: Identity[]=[], observationError: unknown;
  const nativeTemporary=path.join(component.root,'t');
  try {
    await fs.mkdir(profile); await fs.mkdir(extension);
    await fs.mkdir(nativeTemporary);
    await attach(info,'native-launch-input',{profile,extension,TMPDIR:nativeTemporary,
      nonce:component.nonce,profileLength:profile.length,nativeTemporaryLength:nativeTemporary.length,
      executable:await fs.realpath(chromium.executablePath()),executableSha256:sha(await fs.readFile(chromium.executablePath())),
      plannedPublicApiCalls:1,internalStartsMaximum:2,internalRecovery:'SDK conditional ld.so recovery; any activation blocks acceptance',
      worker:await identity(process.pid),profileStat:await fs.lstat(profile),rootStat:await fs.lstat(component.root),
      nativeTemporaryStat:await fs.lstat(nativeTemporary)});
    await fs.writeFile(path.join(extension,'manifest.json'),JSON.stringify({manifest_version:3,name:'Owned loopback zoom fixture',version:'1.0',
      host_permissions:['http://127.0.0.1:3872/*'],background:{service_worker:'worker.js'}}));
    await fs.writeFile(path.join(extension,'worker.js'),'chrome.runtime.onInstalled.addListener(() => {});');
    try {
      const launching=chromium.launchPersistentContext(profile,{channel:'chromium',headless:true,viewport:null,
        args:['--window-size=1280,720',`--disable-extensions-except=${extension}`,`--load-extension=${extension}`],
        env:{...process.env,TMPDIR:nativeTemporary},timeout:30_000});
      // Observe supported API's native profile identities while launch is pending; no extra process or API retry.
      const observeLaunch=(async () => {
        while (!launchSettled) {
          launchObserved=[...new Map([...launchObserved,...await profileProcesses(profile)].map(record => [record.pid,record])).values()];
          await delay(25);
        }
      })().catch(error => { observationError=error; });
      try { context=await launching; launched=true; } finally { launchSettled=true; await observeLaunch; }
      if (observationError) throw observationError;
    } catch (error) {
      await attach(info,'native-launch-failure',{error:String(error),profile,launchObserved,observationError:String(observationError)});
      await fs.writeFile(path.join(component.root,'retain-scratch'),'Persistent launch rejected or observation failed; native cleanup/identity requires review');
      throw error;
    }
    const page=context.pages()[0] ?? await context.newPage(); await open(page,component);
    const browserVersion=context.browser()?.version();
    if (!browserVersion) throw new Error('Actual persistent browser version unavailable');
    const worker=context.serviceWorkers()[0] ?? await context.waitForEvent('serviceworker',{timeout:10_000});
    const zoom = async (factor: number) => worker.evaluate(async factor => {
      const api=(globalThis as unknown as {chrome:{tabs:{query(q:{url:string}):Promise<{id:number}[]>;setZoom(id:number,factor:number):Promise<void>;getZoom(id:number):Promise<number>}}}).chrome;
      const tabs=await api.tabs.query({url:'http://127.0.0.1:3872/*'});
      if(tabs.length!==1) throw new Error('Expected one owned loopback tab');
      await api.tabs.setZoom(tabs[0].id,factor); return api.tabs.getZoom(tabs[0].id);
    },factor);
    restore=() => zoom(1);
    expect(await zoom(1)).toBe(1); const before=await layout(page,info,'native-zoom-100');
    expect(await zoom(2)).toBe(2);
    await expect.poll(() => page.evaluate(() => innerWidth)).toBe(Math.round(before.innerWidth/2));
    const after=await layout(page,info,'native-zoom-200');
    expect(after.screenWidth).toBe(before.screenWidth); expect(after.screenHeight).toBe(before.screenHeight);
    expect(after.outerWidth).toBe(before.outerWidth); expect(after.outerHeight).toBe(before.outerHeight);
    expect(after.visualScale).toBe(1); expect(Math.abs(after.innerHeight-before.innerHeight/2)).toBeLessThanOrEqual(1);
    await attach(info,'native-zoom-identity',{ mechanism:'New test-local MV3 source; historical executable bytes were unavailable',
      profile,extension,TMPDIR:nativeTemporary,
      browserVersion,before,after,zoomBefore:1,zoomAfter:2,publicApiCalls:1,launchObserved });
    const restored=await zoom(1); expect(restored).toBe(1);
    await attach(info,'native-zoom-restored',{profile,browserVersion,zoomRestored:restored});
  } finally {
    // Close via Playwright even after assertions fail. A rejected launch is checked by its exact profile token.
    let observed: Identity[] = [], discoveryComplete=false;
    try {
      observed = [...new Map([...launchObserved,...await profileProcesses(profile)].map(record => [record.pid,record])).values()]; discoveryComplete=true;
      await attach(info,'zoom-processes',{ profile,extension,worker:await identity(process.pid),observed });
      if (restore) expect(await restore()).toBe(1);
    } finally {
      await context?.close();
      const end=Date.now()+5000;
      while ((await profileProcesses(profile)).length && Date.now()<end) await delay(25);
      const remaining=await profileProcesses(profile);
      const observedRemaining=await Promise.all(observed.map(async record => ({...record,alive:await same(record)})));
      await attach(info,'zoom-cleanup',{ profile,remaining,observedRemaining });
      if (remaining.length || observedRemaining.some(record => record.alive)) { component.cleanup.reason='Observed Chromium survivor'; throw new Error('Owned Chromium remains; fixture retains scratch'); }
      if (launched && discoveryComplete && !observationError) { component.cleanup.safe=true; component.cleanup.reason='Native close and all observed identities verified absent'; }
    }
  }
}
