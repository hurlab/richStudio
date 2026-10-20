#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export WORKSPACE_SOURCE_ROOT="$ROOT" RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
export PATH="$ROOT/node_modules/.bin:$PATH"
ARTIFACTS=${WORKSPACE_ARTIFACTS:-"$ROOT/.moai/reports/SPEC-WORKSPACE-001/implementation/001/runner"}
mkdir -p "$ARTIFACTS"
ARTIFACTS=$(cd "$ARTIFACTS" && pwd -P)
export ARTIFACTS
MODE=${1:-scoped}
export WORKSPACE_DIAGNOSTIC_PHASE=${2:-run}
[[ "$WORKSPACE_DIAGNOSTIC_PHASE" == run || "$WORKSPACE_DIAGNOSTIC_PHASE" == sync ]] || { echo "Invalid diagnostic phase" >&2; exit 2; }
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/richstudio-workspace-gate.XXXXXXXX")
trap 'rm -rf -- "$SCRATCH"' EXIT
trap 'exit 143' TERM INT
export WORKSPACE_POLICY_ROOT="$SCRATCH/policy"

receipt() {
  git -C "$ROOT" rev-parse HEAD > "$ARTIFACTS/source-head.txt"
  git -C "$ROOT" status --short > "$ARTIFACTS/source-status.txt"
  git -C "$ROOT" diff --binary HEAD > "$ARTIFACTS/candidate.diff"
  python3 - "$ROOT" "$ARTIFACTS" <<'PY'
import hashlib,json,pathlib,sys
root,out=map(pathlib.Path,sys.argv[1:])
paths=list(root.glob('R/*.R'))+list((root/'tests/fixtures/workspace').glob('*'))
paths += [root/p for p in ('package-lock.json','tsconfig.json','playwright.config.ts','docs/quality/workspace-policy-bundle.json','inst/config/workspace-resources.json','scripts/test-workspace.sh')]
(out/'source-digests.json').write_text(json.dumps({p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()},indent=2))
PY
  Rscript --vanilla -e 'cat(R.version.string,"\n"); print(Sys.info()); print(.libPaths()); for(p in c("richStudio","richR","richCluster","bioAnno","testthat","covr","languageserver","lintr")) if(requireNamespace(p,quietly=TRUE)) cat(p,as.character(packageVersion(p)),find.package(p),"\n") else cat(p,"UNAVAILABLE\n")' > "$ARTIFACTS/runtime.txt" 2>&1
}

policy() {
  python3 "$ROOT/scripts/export-workspace-policy.py" --materialize "$WORKSPACE_POLICY_ROOT" > "$ARTIFACTS/policy-receipt.json"
}

types() {
  cd "$ROOT"
  npx --no-install tsc --noEmit --project tsconfig.json > "$ARTIFACTS/typescript.log" 2>&1
  npx --no-install tsc --noEmit --project tsconfig.json --listFilesOnly > "$ARTIFACTS/typescript-files.txt"
  python3 - "$ROOT" "$ARTIFACTS" <<'PY'
import json,os,pathlib,sys
root,out=map(pathlib.Path,sys.argv[1:])
actual={pathlib.Path(p).resolve() for p in (out/'typescript-files.txt').read_text().splitlines() if p}
if os.environ.get('WORKSPACE_NEGATIVE_FILESET')=='1': actual=set()
expected={root/'playwright.config.ts',root/'tests/e2e/fixtures.ts',*root.glob('tests/e2e/**/*.ts')}
missing=expected-actual
(out/'typescript-membership.json').write_text(json.dumps({'expected':sorted(map(str,expected)),'observed':sorted(map(str,actual)),'missing':sorted(map(str,missing))},indent=2))
if len(expected)<3 or missing: raise SystemExit('FAIL: intended TypeScript config/fixture/spec membership absent')
print(f'TypeScript membership verified: {len(expected)} intended inputs')
PY
}

install_candidate() {
  local candidate="$SCRATCH/library"
  mkdir -p "$candidate"
  R CMD INSTALL --preclean --library="$candidate" "$ROOT" > "$ARTIFACTS/install.log" 2>&1
  export WORKSPACE_INSTALLED_LIBRARY="$candidate"
  export R_LIBS_USER="$candidate${R_LIBS_USER:+:$R_LIBS_USER}"
}

installed() {
  : "${WORKSPACE_INSTALLED_LIBRARY:?Set candidate library; source-only loading is prohibited}"
  cd "$SCRATCH"
  Rscript --vanilla -e 'actual<-normalizePath(find.package("richStudio")); expected<-normalizePath(file.path(Sys.getenv("WORKSPACE_INSTALLED_LIBRARY"),"richStudio")); stopifnot(identical(actual,expected)); cat("INSTALLED",actual,"\n")'
}

r_tests() {
  local filter="$1"
  export WORKSPACE_TEST_FILTER="$filter"
  cd "$SCRATCH"
  Rscript --vanilla - <<'R'
library(richStudio)
results <- testthat::test_dir(file.path(Sys.getenv("WORKSPACE_SOURCE_ROOT"), "tests/testthat"),
  package = "richStudio", load_package = "installed", filter = Sys.getenv("WORKSPACE_TEST_FILTER"),
  reporter = "summary", stop_on_failure = FALSE)
summary <- as.data.frame(results)
utils::write.csv(summary[, setdiff(names(summary), "result"), drop = FALSE], file.path(Sys.getenv("ARTIFACTS"), "testthat-results.csv"), row.names = FALSE)
counts <- c(tests = nrow(summary), passed = sum(summary$passed), failed = sum(summary$failed), errors = sum(summary$error), skipped = sum(summary$skipped), warnings = sum(summary$warning))
print(counts)
jsonlite::write_json(as.list(counts), file.path(Sys.getenv("ARTIFACTS"), "testthat-totals.json"), auto_unbox = TRUE, pretty = TRUE)
if (any(counts[c("failed", "errors", "skipped")] > 0)) stop("Required tests failed or were skipped")
R
}

scan() {
  cd "$ROOT"
  command -v moai >/dev/null
  command -v ast-grep >/dev/null
  moai ast-grep --help > "$ARTIFACTS/moai-ast-grep-help.txt"
  grep -q -- '--rules-dir' "$ARTIFACTS/moai-ast-grep-help.txt"
  ast-grep scan --help > "$ARTIFACTS/ast-grep-scan-help.txt"
  grep -q -- '--inline-rules' "$ARTIFACTS/ast-grep-scan-help.txt"
  ast-grep --version > "$ARTIFACTS/ast-grep-version.txt"
  grep -qx 'ast-grep 0.42.0' "$ARTIFACTS/ast-grep-version.txt"
  python3 - "$ROOT" "$WORKSPACE_POLICY_ROOT" "$ARTIFACTS" "$SCRATCH" <<'PYSCAN'
import hashlib,json,pathlib,re,subprocess,sys,yaml
source,policy,out,scratch=map(pathlib.Path,sys.argv[1:])
config_path=policy/'.moai/config/astgrep-rules/sgconfig.yml'
config=yaml.safe_load(config_path.read_text())
if set(config)-{'ruleDirs','testConfigs'}:raise SystemExit('Unhandled sgconfig execution semantics')
gate=yaml.safe_load((policy/'.moai/config/sections/gate.yaml').read_text())['gate']['ast_grep_gate']
quality=yaml.safe_load((policy/'.moai/config/sections/quality.yaml').read_text())['constitution']['ast_grep_gate']
blocking=any(p['enabled'] and p['block_on_error'] and not p['warn_only_mode'] for p in (gate,quality))
bulk=subprocess.run(['ast-grep','scan','--config',str(config_path),'--json',str(source)],capture_output=True,text=True)
(out/'ast-grep-canonical-bulk.json').write_text(json.dumps({'returncode':bulk.returncode,'stdout':bulk.stdout,'stderr':bulk.stderr},indent=2))
if bulk.returncode not in (0,1) and 'Duplicate rule id' not in bulk.stderr:raise SystemExit('Unexpected canonical bulk scan tooling error')
canary=scratch/'rule-canary.ts';canary.write_text('cp.exec(userInput)\n')
records=[];all_findings=[];canary_detected=False
try:
    for directory in config['ruleDirs']:
        rule_root=config_path.parent/directory
        for path in sorted(rule_root.rglob('*')):
            if not path.is_file() or path.suffix not in ('.yml','.yaml'):continue
            raw=path.read_text(encoding='utf-8')
            for index,document in enumerate(re.split(r'(?m)^---[ \t]*(?:#.*)?$',raw)):
                rule=yaml.safe_load(document)
                if rule is None:continue
                if not isinstance(rule,dict) or not all(k in rule for k in ('id','language','severity','rule')):raise ValueError('Unrecognized production rule document')
                record={'source_path':path.relative_to(policy).as_posix(),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'document_index':index,'document_sha256':hashlib.sha256(document.encode()).hexdigest(),'id':rule['id'],'language':rule['language'],'severity':rule['severity']}
                result=subprocess.run(['ast-grep','scan','--inline-rules',document,'--json',str(source)],capture_output=True,text=True)
                record.update(returncode=result.returncode,stderr=result.stderr)
                records.append(record)
                if result.returncode not in (0,1):raise ValueError('Required rule tooling failure: '+str(record))
                findings=json.loads(result.stdout)
                if not isinstance(findings,list):raise ValueError('Invalid scanner output')
                record['findings']=findings;all_findings+=findings
                if rule['id']=='sec-command-injection-exec' and rule['language']=='typescript':
                    bad=subprocess.run(['ast-grep','scan','--inline-rules',document,'--json',str(canary)],capture_output=True,text=True)
                    bad_findings=json.loads(bad.stdout)
                    record['negative_canary']={'returncode':bad.returncode,'findings':bad_findings,'stderr':bad.stderr}
                    canary_detected=bad.returncode==1 and any(f['ruleId']==rule['id'] for f in bad_findings)
    if not records or not canary_detected:raise ValueError('Required rule inventory or actual rule canary absent')
    errors=[f for f in all_findings if f['severity'].lower()=='error']
    receipt={'execution':'exact-source-document-inline-isolation-preserving-duplicate-language-IDs','config_sha256':hashlib.sha256(config_path.read_bytes()).hexdigest(),'optional_test_configs':config.get('testConfigs',[]),'documents':records,'executed_documents':len(records),'findings':len(all_findings),'errors':len(errors),'blocking':blocking,'canary_detected':canary_detected}
    (out/'ast-grep.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps({k:v for k,v in receipt.items() if k!='documents'}))
    if blocking and errors:raise ValueError('Blocking ast-grep findings')
finally:
    (out/'ast-grep-document-inventory.json').write_text(json.dumps(records,indent=2))
PYSCAN
}

diagnostics() {
  cd "$SCRATCH"
  python3 - "$ROOT" "$ARTIFACTS" "$WORKSPACE_POLICY_ROOT" <<'PY'
import hashlib,json,os,pathlib,queue,subprocess,sys,tempfile,threading,time
import yaml
source,out,policy=map(pathlib.Path,sys.argv[1:])
quality=yaml.safe_load((policy/'.moai/config/sections/quality.yaml').read_text())['constitution']['lsp_quality_gates']
config=yaml.safe_load((policy/'.moai/config/sections/lsp.yaml').read_text())['lsp']
if not quality['enabled']:
    raise SystemExit('Diagnostics policy disabled: explicit disposition required')
server=config['servers']['r']
command=[server['command'],*server['args']]
timeout=config['aggregator']['server_startup_timeout_seconds']+config['aggregator']['request_timeout_seconds']

class Client:
    children=[]
    def __init__(self,root,stage):
        self.stderr=(out/f'lsp-{stage}.stderr').open('w')
        self.process=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.stderr,cwd=root)
        self.children.append(self.process)
        self.messages=queue.Queue()
        def receive():
            try:
                while True:
                    headers={}
                    while True:
                        line=self.process.stdout.readline()
                        if not line: raise EOFError('Language server closed stdout')
                        if line in (b'\r\n',b'\n'): break
                        key,value=line.decode().split(':',1);headers[key.lower()]=value.strip()
                    self.messages.put(json.loads(self.process.stdout.read(int(headers['content-length']))))
            except Exception as error:self.messages.put(error)
        threading.Thread(target=receive,daemon=True).start()
        try:
            self.send({'id':1,'method':'initialize','params':{'processId':None,'rootUri':root.as_uri(),'capabilities':{'textDocument':{'publishDiagnostics':{'versionSupport':True}}},'workspaceFolders':[{'uri':root.as_uri(),'name':stage}]}})
            self.wait(lambda m:m.get('id')==1)
            self.send({'method':'initialized','params':{}})
        except BaseException:
            self.close()
            raise
    def send(self,message):
        data=json.dumps({'jsonrpc':'2.0',**message}).encode()
        self.process.stdin.write(f'Content-Length: {len(data)}\r\n\r\n'.encode()+data);self.process.stdin.flush()
    def wait(self,predicate):
        end=time.monotonic()+timeout
        while time.monotonic()<end:
            message=self.messages.get(timeout=max(.01,end-time.monotonic()))
            if isinstance(message,Exception):raise message
            if message.get('method')=='workspace/configuration' and 'id' in message:
                self.send({'id':message['id'],'result':[None for _ in message['params']['items']]})
            elif 'id' in message and 'method' in message:
                self.send({'id':message['id'],'result':None})
            if predicate(message):return message
        raise TimeoutError('Required language server response absent')
    def open(self,path):
        uri=path.as_uri()
        self.send({'method':'textDocument/didOpen','params':{'textDocument':{'uri':uri,'languageId':'r','version':1,'text':path.read_text()}}})
        message=self.wait(lambda m:m.get('method')=='textDocument/publishDiagnostics' and m.get('params',{}).get('uri')==uri)
        result=message['params']
        if result.get('version',1)!=1:raise ValueError('Wrong diagnostics document version')
        self.send({'method':'textDocument/didClose','params':{'textDocument':{'uri':uri}}})
        return {'uri':uri,'requested_version':1,'published_version':result.get('version'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'diagnostics':result['diagnostics']}
    def close(self):
        self.process.terminate()
        try:self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:self.process.kill();self.process.wait()
        self.stderr.close()

if os.environ.get('WORKSPACE_LSP_NEGATIVE')=='1':
    timeout=0.2
    outcomes=[]
    for name,program in (('timeout','import time;time.sleep(30)'),('early-eof','pass')):
        command=[sys.executable,'-c',program]
        with tempfile.TemporaryDirectory(prefix='workspace-lsp-negative-') as tmp:
            try:
                Client(pathlib.Path(tmp),name)
            except Exception as error:
                outcomes.append({'case':name,'error':repr(error),'all_children_reaped':all(p.poll() is not None for p in Client.children)})
            else:raise SystemExit('Broken diagnostics server unexpectedly initialized')
    (out/'lsp-negative-cleanup.json').write_text(json.dumps(outcomes,indent=2))
    if len(outcomes)!=2 or not all(row['all_children_reaped'] for row in outcomes):raise SystemExit('Diagnostics cleanup regression')
    print('Constructor timeout and early-EOF children terminated and reaped')
    raise SystemExit(0)

baseline_sha=subprocess.check_output(['git','-C',str(source),'rev-parse',os.environ.get('WORKSPACE_BASELINE_SHA','HEAD')],text=True).strip()
receipt={'command':command,'baseline_sha':baseline_sha,'dynamic_r_typecheck':'No independent static R type checker configured; actual R parse/lint diagnostics recorded. TypeScript compilation is separate.','stages':{}}
try:
    with tempfile.TemporaryDirectory(prefix='workspace-lsp-') as tmp:
        root=pathlib.Path(tmp)
        for stage in ('baseline','candidate'):
            stage_root=root/stage;stage_root.mkdir()
            client=None;records=[]
            try:
                client=Client(stage_root,stage)
                canary=stage_root/'invalid-canary.R';canary.write_text('workspace_broken <- function( {\n')
                observed=client.open(canary)
                if not any(d.get('severity')==1 for d in observed['diagnostics']):raise ValueError('Invalid R canary did not produce an actual error')
                receipt['stages'][stage]={'canary':observed,'files':records}
                for path in sorted((source/'R').glob('*.R')):
                    if stage=='baseline':
                        old=subprocess.run(['git','-C',str(source),'show',f'{baseline_sha}:R/{path.name}'],capture_output=True,text=True)
                        if old.returncode:continue
                        text=old.stdout
                    else:text=path.read_text()
                    target=stage_root/path.name;target.write_text(text)
                    record=client.open(target);record['source_path']='R/'+path.name;records.append(record)
                if not records:raise ValueError('No intended R files diagnosed')
            finally:
                if client:client.close()
    def counts(stage):
        data=[d for f in receipt['stages'][stage]['files'] for d in f['diagnostics']]
        return {'errors':sum(d.get('severity')==1 for d in data),'warnings':sum(d.get('severity')==2 for d in data),'lint_errors':sum(d.get('severity')==1 and d.get('source')=='lintr' for d in data)}
    baseline,candidate=counts('baseline'),counts('candidate')
    receipt.update(baseline=baseline,candidate=candidate)
    run,sync=quality['run'],quality['sync']
    run_ok = candidate['errors']<=run['max_errors'] and candidate['lint_errors']<=run['max_lint_errors'] and (run['allow_regression'] or all(candidate[k]<=baseline[k] for k in candidate))
    sync_ok = candidate['errors']<=sync['max_errors'] and candidate['warnings']<=sync['max_warnings']
    receipt['phase_assessments']={'run':{'status':'PASS' if run_ok else 'FAIL','policy':run},'sync':{'status':'PASS' if sync_ok else 'FAIL','policy':sync,'release_hold':not sync_ok}}
    phase=os.environ['WORKSPACE_DIAGNOSTIC_PHASE']
    receipt['evaluated_phase']=phase
    if not {'run':run_ok,'sync':sync_ok}[phase]:raise ValueError(f'Canonical {phase} diagnostic thresholds exceeded')
    receipt['status']='PASS'
except Exception as error:
    receipt['status']='FAIL';receipt['error']=repr(error)
finally:
    (out/'lsp-diagnostics.json').write_text(json.dumps(receipt,indent=2))
if receipt['status']!='PASS':raise SystemExit(receipt['error'])
print('Actual R JSON-RPC diagnostics and invalid canary verified')
PY
}

case "$MODE" in
  serve)
    installed
    timeout --kill-after=5s 300s Rscript --vanilla -e 'tryCatch(shiny::runApp(system.file("application",package="richStudio"),host="127.0.0.1",port=3871,launch.browser=FALSE),finally=future::plan(future::sequential))' &
    server_pid=$!
    trap 'kill -TERM "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; rm -rf -- "$SCRATCH"' EXIT
    wait "$server_pid"
    ;;
  prepare)
    receipt; policy; types; python3 "$ROOT/scripts/export-workspace-policy.py" --self-test
    ;;
  install)
    install_candidate; installed; receipt
    printf '%s\n' "$WORKSPACE_INSTALLED_LIBRARY" > "$ARTIFACTS/candidate-library.txt"
    # Install mode is for inspection only: its scratch library is removed at exit.
    ;;
  scoped)
    install_candidate; installed; receipt; r_tests '^workspace-(baseline|resources)$'
    ;;
  browser)
    install_candidate; installed; receipt
    cd "$ROOT"; npx --no-install playwright test
    ;;
  negative)
    receipt; policy
    if WORKSPACE_NEGATIVE_FILESET=1 types > "$ARTIFACTS/negative-typescript.log" 2>&1; then
      echo 'FAIL: empty TypeScript membership was admitted' >&2; exit 1
    fi
    grep -q 'intended TypeScript' "$ARTIFACTS/negative-typescript.log"
    python3 "$ROOT/scripts/export-workspace-policy.py" --self-test > "$ARTIFACTS/negative-policy.log" 2>&1
    install_candidate; installed
    cd "$ROOT"
    if WORKSPACE_NEGATIVE_ASSERTION=1 npx --no-install playwright test --grep 'negative assertion canary' > "$ARTIFACTS/negative-browser.log" 2>&1; then
      echo 'FAIL: intentionally broken assertion was admitted' >&2; exit 1
    fi
    grep -q 'INTENTIONALLY BROKEN FIXTURE EXPECTATION' "$ARTIFACTS/negative-browser.log"
    cp "$ARTIFACTS/browser-results.json" "$ARTIFACTS/negative-browser-results.json"
    echo 'Negative policy, TypeScript and real browser assertion gates rejected intentionally broken inputs'
    ;;
  scan)
    receipt; policy; scan
    ;;
  diagnostics-negative)
    receipt; policy; export WORKSPACE_LSP_NEGATIVE=1; diagnostics
    ;;
  diagnostics)
    receipt; policy; types; diagnostics
    ;;
  full)
    [[ ${CI:-} == true ]] || { echo 'Full suite/check/coverage belongs in clean CI' >&2; exit 1; }
    install_candidate; installed; receipt; policy
    test_result=0
    r_tests '.*' > "$ARTIFACTS/full-tests.log" 2>&1 || test_result=$?
    tail -20 "$ARTIFACTS/full-tests.log"
    export WORKSPACE_COVERAGE_TARGET
    WORKSPACE_COVERAGE_TARGET=$(python3 - "$WORKSPACE_POLICY_ROOT" <<'PY'
import pathlib,sys,yaml
p=pathlib.Path(sys.argv[1])/'.moai/config/sections/quality.yaml'
print(yaml.safe_load(p.read_text())['constitution']['test_coverage_target'])
PY
)
    Rscript --vanilla - <<'R'
root <- Sys.getenv("WORKSPACE_SOURCE_ROOT")
out <- Sys.getenv("ARTIFACTS")
check_error <- NULL
check <- tryCatch(rcmdcheck::rcmdcheck(root, args = c("--no-manual", "--as-cran"), error_on = "warning", check_dir = file.path(out, "R-check")), error = function(e) { check_error <<- conditionMessage(e); NULL })
coverage <- covr::package_coverage(root, quiet = TRUE)
saveRDS(coverage, file.path(out, "coverage.rds"))
covr::to_cobertura(coverage, file.path(out, "coverage.xml"))
percent <- covr::percent_coverage(coverage)
cat("FULL COVERAGE", percent, "CANONICAL TARGET", Sys.getenv("WORKSPACE_COVERAGE_TARGET"), "\n")
if (!is.null(check_error)) message(check_error)
if (percent < as.numeric(Sys.getenv("WORKSPACE_COVERAGE_TARGET"))) stop("Canonical full-suite coverage target not met")
if (!is.null(check_error)) stop("R CMD check failed")
R
    (( test_result == 0 ))
    ;;
  *) echo "Usage: $0 prepare|scoped|browser|negative|diagnostics|full|serve" >&2; exit 2 ;;
esac
