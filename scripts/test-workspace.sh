#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export WORKSPACE_SOURCE_ROOT="$ROOT" RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
export PATH="$ROOT/node_modules/.bin:$PATH"
ARTIFACTS=${WORKSPACE_ARTIFACTS:-"$ROOT/.moai/reports/SPEC-WORKSPACE-001/implementation/001/runner"}
mkdir -p "$ARTIFACTS"
ARTIFACTS=$(cd "$ARTIFACTS" && pwd -P)
export ARTIFACTS
export WORKSPACE_ARTIFACTS="$ARTIFACTS"
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
paths=list(root.glob('R/*.R'))+list((root/'src').rglob('*'))+list((root/'tests/fixtures/workspace').glob('*'))
paths += [root/'DESCRIPTION', root/'NAMESPACE']
paths += [root/p for p in ('package-lock.json','tsconfig.json','playwright.config.ts','docs/quality/workspace-policy-bundle.json','inst/config/workspace-resources.json','scripts/test-workspace.sh','scripts/measure-workspace-resources.R')]
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
import hashlib,io,json,os,pathlib,queue,shutil,subprocess,sys,tarfile,tempfile,threading,time
import yaml
source,out,policy=map(pathlib.Path,sys.argv[1:])
constitution=yaml.safe_load((policy/'.moai/config/sections/quality.yaml').read_text())['constitution']
quality=constitution['lsp_quality_gates']
regression=constitution['lsp_integration']['regression_detection']
config=yaml.safe_load((policy/'.moai/config/sections/lsp.yaml').read_text())['lsp']
if not quality['enabled']:
    raise SystemExit('Diagnostics policy disabled: explicit disposition required')
server=config['servers']['r']
command=[server['command'],*server['args']]
timeout=config['aggregator']['server_startup_timeout_seconds']+config['aggregator']['request_timeout_seconds']


# Minimal startup adapter: preserve configured binary/flags/expression and emit no
# protocol stdout. Identity is measured inside the actual fresh server process.
namespace_probe = r'''receipt <- Sys.getenv("WORKSPACE_NAMESPACE_RECEIPT")
ns <- tryCatch(loadNamespace("richStudio"),error=function(e) {
 jsonlite::write_json(list(pid=Sys.getpid(),verified=FALSE,error=conditionMessage(e)),receipt,auto_unbox=TRUE)
 stop("PREP namespace unavailable",call.=FALSE)
})
p <- normalizePath(getNamespaceInfo(ns,"path"),mustWork=TRUE)
expected <- file.path(Sys.getenv("WORKSPACE_STAGE_LIBRARY"),"richStudio")
stamp_file <- file.path(p,"workspace-source-identity")
stamp <- if(file.exists(stamp_file)) readLines(stamp_file) else character()
v <- as.character(getNamespaceVersion(ns))
ok <- identical(p,expected) && identical(stamp,c(Sys.getenv("WORKSPACE_STAGE_IDENTITY"),Sys.getenv("WORKSPACE_STAGE_NAME"))) && identical(v,unname(read.dcf("DESCRIPTION")[1,"Version"]))
jsonlite::write_json(list(pid=Sys.getpid(),verified=ok,package_path=p,expected_package_path=expected,
 version=v,source_identity=stamp[1],stage=stamp[2],expected_source_identity=Sys.getenv("WORKSPACE_STAGE_IDENTITY"),
 expected_stage=Sys.getenv("WORKSPACE_STAGE_NAME"),library_paths=.libPaths(),
 library_environment=Sys.getenv(c("R_LIBS","R_LIBS_USER","R_LIBS_SITE"))),receipt,auto_unbox=TRUE,pretty=TRUE)
if(!ok) stop("PREP namespace wrong stage/version/origin",call.=FALSE)
'''

class Client:
    children=[]
    def __init__(self,root,stage,env=None):
        self.stderr=(out/f'lsp-{stage}.stderr').open('w')
        launch_command=list(command)
        self.namespace_receipt=out/f'namespace-server-{stage}.json'
        if env is not None:
            env=dict(env,WORKSPACE_NAMESPACE_RECEIPT=str(self.namespace_receipt))
            if len(command)<3 or command[-2]!='-e' or command[-1]!='languageserver::run()':
                raise ValueError('Unsupported canonical R server expression for identity startup adapter')
            launch_command[-1]=namespace_probe+'\n'+command[-1]
        self.command=launch_command
        self.process=subprocess.Popen(launch_command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.stderr,cwd=root,env=env)
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
            if env is not None:
                self.namespace=json.loads(self.namespace_receipt.read_text())
                if not self.namespace.get('verified') or self.namespace['pid']!=self.process.pid:
                    raise ValueError('Actual server namespace/PID mismatch')
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
        self.send({'method':'textDocument/didOpen','params':{'textDocument':{'uri':uri,'languageId':'r','version':1,'text':path.read_bytes().decode('utf-8')}}})
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
        stages=[]
        for stage in ('baseline','candidate'):
            stage_root=root/stage;stage_root.mkdir()
            # Install the complete frozen package, preserving original lint context.
            if stage=='baseline':
                archive=subprocess.check_output(['git','-C',str(source),'archive',baseline_sha])
                with tarfile.open(fileobj=io.BytesIO(archive)) as package:
                    package.extractall(stage_root,filter='data')
            else:
                tracked=subprocess.check_output(['git','-C',str(source),'ls-files','--cached','--others','--exclude-standard'],text=True).splitlines()
                for relative in tracked:
                    original=source/relative
                    if original.is_file():
                        target=stage_root/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original,target)
            intended=sorted(p.relative_to(stage_root).as_posix() for p in (stage_root/'R').rglob('*') if p.is_file() and p.suffix in ('.R','.r'))
            context=[{'source_path':p.relative_to(stage_root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(stage_root.rglob('*')) if p.is_file()]
            identity=hashlib.sha256(json.dumps(context,sort_keys=True).encode()).hexdigest()
            library=root/(stage+'-library');library.mkdir()
            install=subprocess.run(['R','CMD','INSTALL','--preclean','--library='+str(library),str(stage_root)],capture_output=True,text=True,timeout=240)
            (out/f'install-{stage}.log').write_text(install.stdout+install.stderr)
            if install.returncode:raise ValueError('PREP stage installation failed: '+stage)
            (library/'richStudio/workspace-source-identity').write_text(identity+'\n'+stage+'\n')
            env=dict(os.environ)
            # Explicit prefix in every R library variable, independent of caller aliases.
            dependencies=subprocess.check_output(['Rscript','--vanilla','-e','cat(paste(.libPaths(),collapse=.Platform$path.sep))'],text=True).strip()
            for name in ('R_LIBS','R_LIBS_USER','R_LIBS_SITE'):env[name]=str(library)+os.pathsep+dependencies
            env.update(WORKSPACE_STAGE_LIBRARY=str(library),WORKSPACE_STAGE_IDENTITY=identity,WORKSPACE_STAGE_NAME=stage)
            stages.append((stage,stage_root,intended,context,identity,library,env))
        for stage,stage_root,intended,context,identity,library,env in stages:
            other=next(row for row in stages if row[0]!=stage)
            negative_cases=[]
            for case in ('absent','wrong-stage'):
                negative_env=dict(env)
                if case=='absent':
                    hidden=library/'richStudio-hidden';(library/'richStudio').rename(hidden)
                else:
                    for name in ('R_LIBS','R_LIBS_USER','R_LIBS_SITE'):
                        negative_env[name]=str(other[5])+os.pathsep+dependencies
                name=stage+'-'+case
                try:
                    try:Client(stage_root,name,negative_env)
                    except Exception as error:
                        observed=json.loads((out/f'namespace-server-{name}.json').read_text())
                        if observed.get('verified'):raise ValueError('Invalid actual server namespace marked verified')
                        if case=='wrong-stage' and (observed.get('stage')!=other[0] or observed.get('source_identity')!=other[4] or observed.get('package_path')!=str(other[5]/'richStudio')):
                            raise ValueError('Negative did not load the actual other-stage installation')
                        if not all(p.poll() is not None for p in Client.children):raise ValueError('Namespace negative left a server alive')
                        negative_cases.append({'case':case,'rejected':True,'error':str(error),'actual_server':observed,'all_children_reaped':True})
                    else:raise ValueError('PREP invalid namespace admitted: '+case)
                finally:
                    if case=='absent':hidden.rename(library/'richStudio')
            client=None;records=[]
            try:
                client=Client(stage_root,stage,env)
                canary=stage_root/'invalid-canary.R';canary.write_text('workspace_broken <- function( {\n')
                observed=client.open(canary)
                if not any(d.get('severity')==1 for d in observed['diagnostics']):raise ValueError('Invalid R canary did not produce an actual error')
                canary.unlink()
                receipt['stages'][stage]={'canary':observed,'installed_namespace':client.namespace,'server_pid':client.process.pid,'effective_server_command':client.command,'startup_adapter':'namespace identity prefix only; canonical command flags and languageserver::run expression retained','namespace_negative_cases':negative_cases,'source_identity':identity,'staging':'full-frozen-package-private-stage-install','context':context,'lintr_configuration':'present' if (stage_root/'.lintr').is_file() else 'absent-in-measured-source','files':records}
                for relative in intended:
                    record=client.open(stage_root/relative);record['source_path']=relative;records.append(record)
                if not records:raise ValueError('No intended R files diagnosed')
            finally:
                if client:client.close()
    def counts(stage):
        data=[d for f in receipt['stages'][stage]['files'] for d in f['diagnostics']]
        if any(d.get('severity') not in (1,2,3,4) for d in data):raise ValueError('Unrecognized diagnostic severity')
        return {'errors':sum(d['severity']==1 for d in data),'warnings':sum(d['severity']==2 for d in data),'information':sum(d['severity']==3 for d in data),'hints':sum(d['severity']==4 for d in data),'total':len(data),'lint_errors':sum(d['severity']==1 and d.get('source')=='lintr' for d in data)}
    baseline,candidate=counts('baseline'),counts('candidate')
    receipt.update(baseline=baseline,candidate=candidate)
    run,sync=quality['run'],quality['sync']
    typescript_membership=json.loads((out/'typescript-membership.json').read_text())
    if typescript_membership['missing']:raise ValueError('TypeScript inputs missing')
    receipt['typecheck']={'tool':'tsc --noEmit --project tsconfig.json','observed_exit_code':0,'type_errors':0,'intended_inputs':typescript_membership['expected'],'r_static_type_checker':'not configured; dynamic R parse/lint diagnostics remain separate'}
    has_regression = candidate['errors']-baseline['errors']>regression['error_increase_threshold'] or candidate['warnings']-baseline['warnings']>regression['warning_increase_threshold']
    run_ok = candidate['errors']<=run['max_errors'] and candidate['lint_errors']<=run['max_lint_errors'] and receipt['typecheck']['type_errors']<=run['max_type_errors'] and (run['allow_regression'] or not has_regression)
    sync_ok = candidate['errors']<=sync['max_errors'] and candidate['warnings']<=sync['max_warnings'] and (not sync['require_clean_lsp'] or candidate['total']==0)
    receipt['phase_assessments']={'run':{'status':'PASS' if run_ok else 'FAIL','policy':run,'regression_policy':regression,'has_regression':has_regression},'sync':{'status':'PASS' if sync_ok else 'FAIL','policy':sync,'total_diagnostics':candidate['total'],'release_hold':not sync_ok}}
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

coverage_receipt() {
  local calibration="$ARTIFACTS/coverage-calibration.R"
  cat > "$calibration" <<'RCALIBRATION'
probe <- function(role) {
  ns <- asNamespace("richStudio")
  path <- normalizePath(getNamespaceInfo(ns, "path"), mustWork=TRUE)
  expected <- normalizePath(file.path(Sys.getenv("WORKSPACE_COVERAGE_LIBRARY"),"richStudio"),mustWork=TRUE)
  stopifnot(identical(path,expected))
  fun <- get("workspace_resource_keys",ns)
  counters <- get(".counters",asNamespace("covr"))
  selected <- function() Filter(function(x) "workspace_resource_keys" %in% x$functions, as.list(counters))
  before <- sum(vapply(selected(),function(x)x$value,numeric(1)))
  stopifnot(length(fun())==15L,length(fun())==15L)
  hits <- sum(vapply(selected(),function(x)x$value,numeric(1)))-before
  stopifnot(hits==2)
  saveRDS(selected(),file.path(Sys.getenv("ARTIFACTS"),paste0("coverage-",role,"-calibration.rds")))
  source <- Sys.getenv("WORKSPACE_SOURCE_ROOT")
  metadata <- c("DESCRIPTION","NAMESPACE")
  stopifnot(identical(unname(tools::md5sum(file.path(path,"NAMESPACE"))),unname(tools::md5sum(file.path(source,"NAMESPACE")))))
  identity <- list(role=role,pid=Sys.getpid(),package_path=path,
    installed_metadata_md5=as.list(tools::md5sum(file.path(path,metadata))),
    version=as.character(packageVersion("richStudio")),library_paths=.libPaths(),
    library_environment=Sys.getenv(c("R_LIBS","R_LIBS_USER","R_LIBS_SITE","R_COVR")),
    source_identity=Sys.getenv("WORKSPACE_COVERAGE_SOURCE_IDENTITY"),calibration_hits=hits,
    instrumented_function=deparse(body(fun)))
  jsonlite::write_json(identity,file.path(Sys.getenv("ARTIFACTS"),paste0("coverage-",role,".json")),auto_unbox=TRUE,pretty=TRUE)
  identity
}
parent <- probe("parent")
# Exercise the application's real future multisession backend, then reap its worker.
(function() {
  old <- future::plan()
  on.exit(future::plan(old),add=TRUE)
  future::plan(future::multisession,workers=I(1))
  worker <- future::value(future::future(probe("worker"),packages=c("richStudio","covr"),seed=TRUE))
  stopifnot(parent$pid!=worker$pid,identical(parent$package_path,worker$package_path),
    identical(parent$source_identity,worker$source_identity))
  future::plan(old)
  deadline <- Sys.time()+5
  while(dir.exists(file.path("/proc",worker$pid)) && Sys.time()<deadline) Sys.sleep(0.01)
  stopifnot(!dir.exists(file.path("/proc",worker$pid)))
  jsonlite::write_json(list(backend="future::multisession",pid=worker$pid,worker_reaped=TRUE),
    file.path(Sys.getenv("ARTIFACTS"),"coverage-worker-cleanup.json"),auto_unbox=TRUE,pretty=TRUE)
})()
RCALIBRATION
  export WORKSPACE_COVERAGE_CALIBRATION="$calibration"
  export WORKSPACE_COVERAGE_LIBRARY="$SCRATCH/coverage-library"
  export WORKSPACE_COVERAGE_SOURCE_IDENTITY
  WORKSPACE_COVERAGE_SOURCE_IDENTITY=$(sha256sum "$ARTIFACTS/source-digests.json" | cut -d' ' -f1)
}

local_urls() {
  : "${WORKSPACE_URL_SOURCE:=$ROOT}"
  export WORKSPACE_URL_SOURCE
  timeout --kill-after=5s 60s Rscript --vanilla - "$SCRATCH" <<'RURL'
source <- normalizePath(Sys.getenv("WORKSPACE_URL_SOURCE"),mustWork=TRUE)
out <- file.path(Sys.getenv("ARTIFACTS"),"local-urls")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
ns <- asNamespace("tools")
expected <- c(check_url_db="197a2f66520d287c805349b201a5be023148c5501ea018db271eaecd3cc73511",
 format.check_url_db="ab92723a8bc8f012589ca73534f30055792cfc584e5fe840a432dbb7adc7dbc7",
 url_db_from_package_sources="84a5841f467a8d528143a8d30d3b44e83ce6feeefa3a0eb5da64b9bf07101009",
 .check_packages="6c0803478a049cd3a07d5724a7c637f52174fc49ac6e8fe5ef5b79428be30e04")
stopifnot(identical(as.character(getRversion()),"4.6.1"),identical(as.character(packageVersion("tools")),"4.6.1"))
observed <- vapply(names(expected),function(name) {
 path <- file.path(out,paste0(name,".R"));writeLines(deparse(get(name,ns),width.cutoff=500),path)
 digest::digest(file=path,algo="sha256")
},character(1))
stopifnot("Unknown installed tools URL source; PREP held"=identical(observed,expected))
mirror_file <- file.path(R.home("doc"),"CRAN_mirrors.csv")
mirror_sha <- digest::digest(file=mirror_file,algo="sha256")
stopifnot(identical(mirror_sha,"7e3149ae43ae164539a4e41068a72f51af845b1dad8622417e7e9b190c488037"))
body <- body(get("check_url_db",ns))
stopifnot(length(body)==26L,identical(body[[9L]][[2L]],as.name(".check_http_B")),
 identical(body[[4L]][[2L]],as.name(".gather")),identical(body[[12L]][[2L]],as.name("mirrors")),
 identical(body[[23L]][[2L]],as.name("pos")),identical(body[[24L]][[1L]],as.name("if")))
# Fixed expressions of the digest-verified installed function, not a checker fork.
# Includes exact HTTP eligibility filtering; excludes all header fetch/network code.
indices <- c(4L,9L,10L,12L,13L,14L,15L,18L,23L,24L)
writeLines(vapply(indices,function(i)paste(deparse(body[[i]],width.cutoff=500),collapse="\n"),character(1)),file.path(out,"evaluated-local-expressions.R"))
companion <- function(db) {
 if(!NROW(db)) return(tools:::check_url_db(db,remote=FALSE))
 e <- new.env(parent=ns);e$db <- db
 for(i in indices) eval(body[[i]],e)
 values <- vapply(e$urls[e$pos],e$.check_http_B,character(3))
 ind <- if(length(e$pos)) apply(values,2L,function(x)any(nzchar(x))) else logical()
 e$.gather(e$urls[e$pos[ind]],e$parents[e$pos[ind]],cran=values[1L,ind],spaces=values[2L,ind],R=values[3L,ind])
}
check <- function(db) rbind(tools:::check_url_db(db,remote=FALSE),companion(db))
stopifnot(requireNamespace("xml2",quietly=TRUE))
db <- tools:::url_db_from_package_sources(source)
saveRDS(db,file.path(out,"package-source-url-db.rds"))
jsonlite::write_json(db,file.path(out,"package-source-url-db.json"),pretty=TRUE)
before <- tools:::check_url_db(db,remote=FALSE);added <- companion(db);after <- check(db)
saveRDS(list(before=before,local_companion=added,after=after),file.path(out,"package-url-results.rds"))
writeLines(format(before),file.path(out,"package-before.txt"));writeLines(format(after),file.path(out,"package-after.txt"))
fixtures <- file.path(commandArgs(TRUE)[1],"url-fixtures");dir.create(fixtures)
cases <- list(valid=list(url="https://example.invalid/reference",field=NULL),
 valid_cran=list(url="https://cran.r-project.org/package=stats",field=NULL),
 valid_r=list(url="https://www.r-project.org/",field=NULL),
 valid_mirror_exception=list(url="https://cloud.r-project.org/doc/manuals/r-release/R-lang.html",field=NULL),
 literal_space=list(url="https://example.invalid/has space",field="Spaces"),
 cran_http=list(url="http://cran.r-project.org/package=stats",field="CRAN"),
 cran_package=list(url="https://cran.r-project.org/web/packages/stats/",field="CRAN"),
 cran_view=list(url="https://cran.r-project.org/web/views/Genetics.html",field="CRAN"),
 cran_mirror=list(url="https://cran.rstudio.com/web/packages/stats/",field="CRAN"),
 r_http=list(url="http://www.r-project.org/",field="R"))
receipts <- list()
for(name in names(cases)) {
 case <- cases[[name]];pkg <- file.path(fixtures,name);dir.create(file.path(pkg,"man"),recursive=TRUE)
 writeLines(c("Package: localurlcanary","Version: 0.0.1","Title: Local URL Calibration","Description: Calibrates local checks without network access.","Author: Test Author","Maintainer: Test Author <test@example.org>","License: GPL-3"),file.path(pkg,"DESCRIPTION"))
 writeLines(c("\\name{localurlcanary}","\\alias{localurlcanary}","\\title{Calibration}",paste0("\\description{See \\url{",case$url,"}.}")),file.path(pkg,"man/localurlcanary.Rd"))
 input <- tools:::url_db_from_package_sources(pkg)
 narrow <- tools:::check_url_db(input,remote=FALSE);local <- companion(input);combined <- check(input)
 stopifnot(identical(input$URL,case$url),nrow(narrow)==0L)
 if(is.null(case$field)) stopifnot(nrow(combined)==0L) else stopifnot(nrow(combined)==1L,identical(unname(combined[[case$field]]),case$url))
 rendered <- format(combined)
 if(!is.null(case$field)) stopifnot(any(grepl(switch(case$field,Spaces="URL contains spaces",CRAN="CRAN URL not in canonical form",R="R-project URL not in canonical form"),rendered,fixed=TRUE)))
 receipts[[name]] <- list(source_url_db=input,before=narrow,added=local,after=combined,formatted=rendered,intended_field=case$field,verified=TRUE)
}
# The digest-verified original incoming wrapper reports bad_urls as NOTE.
# Preserve that classification: error_on="warning" does not reject notes.
actual_status <- if(nrow(after)) "PASS_WITH_NOTES" else "CLEAN"
if(nrow(after)) cat("LOCAL URL NOTE (actual source):\n",paste(format(after),collapse="\n"),"\n")
receipt <- list(status="LOCAL_URL_PRESERVATION_OBSERVED",default_profile_changed=TRUE,
 actual_source_acceptance=list(status=actual_status,findings=nrow(after),original_severity="NOTE in CRAN incoming feasibility",error_on="warning",blocked_by_local_notes=FALSE,profile_authorized=TRUE),
 R=R.version.string,tools_version=as.character(packageVersion("tools")),tools_path=find.package("tools"),
 source_sha256=observed,mirror_sha256=mirror_sha,shape_guard=TRUE,evaluated_expression_indices=indices,
 source_snapshot=source,source_url_records=nrow(db),source_url_unique=length(unique(db$URL)),
 package_before=before,package_added=added,package_after=after,controls=receipts,
 scope="Only skipped literal-space/canonical-CRAN/canonical-R-project local helper checks; existing remoteFALSE local checks retained; no HTTP/header fetch or remote liveness executed")
jsonlite::write_json(receipt,file.path(out,"receipt.json"),auto_unbox=TRUE,pretty=TRUE,null="null")
cat("LOCAL URL COMPANION: 4 valid and 6 intended invalid controls verified; actual source URL records",nrow(db),"; original NOTE disposition retained\n")
RURL
}

owned_profile() {
  python3 - "$1" "$SCRATCH" "$ARTIFACTS" "${2:-profile}" <<'PYOWNED'
import ctypes,hashlib,json,os,pathlib,signal,subprocess,sys,time,uuid
script,scratch,out=map(pathlib.Path,sys.argv[1:4]);mode=sys.argv[4]
if sys.platform!='linux' or ctypes.CDLL(None,use_errno=True).prctl(36,1,0,0,0)!=0:
    raise SystemExit('PREP: owned profile cleanup requires Linux child-subreaper support')
owner=uuid.uuid4().hex;ready=out/'profile-cleanup-ready.txt'
env=dict(os.environ,WORKSPACE_PROFILE_OWNER=owner,WORKSPACE_PROFILE_READY=str(ready))
requested=[]
for sig in (signal.SIGTERM,signal.SIGINT):signal.signal(sig,lambda sig,frame:requested.append(sig))
child=subprocess.Popen(['Rscript','--vanilla',str(script),str(scratch)],env=env,start_new_session=True)
registered={};signals=[];reaped=[];reason='running'
def stat(pid):
    try:
        raw=pathlib.Path(f'/proc/{pid}/stat').read_text();v=raw[raw.rfind(')')+2:].split()
        return {'pid':pid,'state':v[0],'ppid':int(v[1]),'pgid':int(v[2]),'start_ticks':int(v[19])}
    except (OSError,ValueError):return None
def labelled(pid):
    try:
        values=pathlib.Path(f'/proc/{pid}/environ').read_bytes().split(b'\0')
        return ('WORKSPACE_PROFILE_OWNER='+owner).encode() in values and ('ARTIFACTS='+str(out)).encode() in values
    except OSError:return False
def discover():
    # Traverse only this supervisor's children, including adopted descendants.
    pending=[os.getpid()];seen=set()
    while pending:
        pid=pending.pop()
        if pid in seen:continue
        seen.add(pid)
        try:pending.extend(map(int,pathlib.Path(f'/proc/{pid}/task/{pid}/children').read_text().split()))
        except OSError:pass
        if pid==os.getpid():continue
        info=stat(pid)
        if info and (labelled(pid) or (info['state']=='Z' and info['ppid']==os.getpid())):
            registered.setdefault(pid,info)
def remaining():
    return [pid for pid,old in registered.items() if (current:=stat(pid)) and current['start_ticks']==old['start_ticks']]
def send(sig):
    discover()
    initial=[pid for pid in remaining() if (info:=stat(pid)) and info['pgid']==child.pid and labelled(pid)]
    if initial:
        try:os.killpg(child.pid,sig);signals.append({'pgid':child.pid,'signal':sig})
        except ProcessLookupError:pass
    for pid in remaining():
        if not labelled(pid):continue
        try:os.kill(pid,sig);signals.append({'pid':pid,'signal':sig})
        except ProcessLookupError:pass
def reap():
    child.poll()
    for pid in registered:
        if pid==child.pid:continue
        try:
            waited,status=os.waitpid(pid,os.WNOHANG)
            if waited:reaped.append({'pid':pid,'status':os.waitstatus_to_exitcode(status)})
        except ChildProcessError:pass
started=time.monotonic();deadline=started+(15 if mode=='cleanup' else 900);error=None
try:
    while child.poll() is None:
        discover()
        if requested:reason='signal';break
        if mode=='cleanup' and ready.is_file() and len(registered)>=2:
            reason='controlled_timeout';break
        if time.monotonic()>deadline:reason='timeout';break
        time.sleep(.05)
    if reason=='running':reason='natural_exit'
except BaseException as exc:error=repr(exc);reason='supervisor_error'
finally:
    # This boundary owns its process group and reaps detached callr/Rcheck children.
    send(signal.SIGTERM);grace=time.monotonic()+1
    while remaining() and time.monotonic()<grace:discover();reap();time.sleep(.05)
    send(signal.SIGKILL);limit=time.monotonic()+2
    while remaining() and time.monotonic()<limit:discover();reap();time.sleep(.05)
    discover();reap();left=remaining()
    receipt={'owner':owner,'artifacts':str(out),'script_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),
      'root_pid':child.pid,'root_exit':child.returncode,'reason':reason,'registered_ancestry':list(registered.values()),
      'signals':signals,'reaped_adopted_children':reaped,'remaining':left,'error':error,
      'cleanup_verified':not left,'platform':sys.platform,'subreaper':True}
    (out/f'profile-process-{mode}.json').write_text(json.dumps(receipt,indent=2))
if left or error:raise SystemExit('PREP: owned profile cleanup failed')
if mode=='cleanup':
    if reason!='controlled_timeout' or not ready.is_file() or len(registered)<2:raise SystemExit('Controlled cleanup canary did not reach its owned child')
    print('Owned profile timeout: registered descendants terminated and reaped')
    raise SystemExit(0)
if reason!='natural_exit':raise SystemExit(124)
raise SystemExit(child.returncode)
PYOWNED
}

profile_cleanup() {
  local program="$SCRATCH/profile-cleanup.R"
  cat > "$program" <<'RCLEANUP'
child <- callr::r_bg(function(ready) {
 writeLines(as.character(Sys.getpid()),ready)
 Sys.sleep(60)
},args=list(Sys.getenv("WORKSPACE_PROFILE_READY")),supervise=FALSE)
Sys.sleep(60)
RCLEANUP
  owned_profile "$program" cleanup
}

check_profile() {
  local_urls
  # This is a bounded tool fixture gate, never a project-wide local check.
  local profile_script="$SCRATCH/check-profile.R"
  cat > "$profile_script" <<'RPROFILE'
args <- commandArgs(TRUE)
out <- file.path(Sys.getenv("ARTIFACTS"), "check-profile")
dir.create(out, recursive=TRUE, showWarnings=FALSE)
ns <- asNamespace("tools")
inventory <- list()
for (name in ls(ns, all.names=TRUE)) {
  value <- get(name, ns)
  if (!is.function(value)) next
  text <- deparse(value, width.cutoff=500)
  if (!any(grepl("_R_CHECK_|check_incoming|as_cran|checkingLog", text))) next
  file <- file.path(out, paste0(name, ".R"))
  writeLines(text, file)
  inventory[[name]] <- list(source=file, md5=unname(tools::md5sum(file)),
    controls=unique(unlist(regmatches(text, gregexpr("_R_CHECK_[A-Z0-9_]+_", text)))),
    incoming_context=lapply(grep("check_incoming", text, fixed=TRUE), function(i) text[seq.int(max(1,i-3),min(length(text),i+6))]))
}
# The approved profile keeps master incoming controls and excludes remote
# eligibility/liveness. Its skipped local URL predicates are guarded above.
application_env <- c(`_R_CHECK_CRAN_INCOMING_`="TRUE", `_R_CHECK_CRAN_INCOMING_REMOTE_`="FALSE",
 `_R_CHECK_OVERWRITE_REGISTERED_S3_METHODS_`="TRUE", `_R_CHECK_AUTOCONF_`="TRUE")
local_urls <- jsonlite::read_json(file.path(Sys.getenv("ARTIFACTS"),"local-urls/receipt.json"),simplifyVector=TRUE)
stopifnot(isTRUE(local_urls$shape_guard),local_urls$actual_source_acceptance$status %in% c("CLEAN","PASS_WITH_NOTES"))
receipt <- list(status="FAIL", R=R.version.string, tools_path=find.package("tools"),
 tools_version=as.character(packageVersion("tools")), source_inventory=inventory,
 args=c("--no-manual", "--as-cran"), error_on="warning",
 preserved_strict_controls=c("_R_CHECK_OVERWRITE_REGISTERED_S3_METHODS_", "_R_CHECK_AUTOCONF_"),
 application_env=as.list(application_env), local_url_receipt=file.path(Sys.getenv("ARTIFACTS"),"local-urls/receipt.json"),
 scope_exclusions="External repository/publication eligibility and URL/DOI/ORCID/ROR liveness; local URL companion retained",
 canaries=list(), publication_readiness_claim=FALSE)
write_receipt <- function() jsonlite::write_json(receipt, file.path(out,"receipt.json"),auto_unbox=TRUE,pretty=TRUE,null="null")
write_receipt()
fixtures <- file.path(args[1], "check-canaries")
dir.create(fixtures)
for (case in c("valid", "code", "documentation", "example", "test", "build", "no-exercises")) {
  pkg <- file.path(fixtures,case,"workspacecanary")
  dir.create(file.path(pkg,"R"),recursive=TRUE);dir.create(file.path(pkg,"man"));dir.create(file.path(pkg,"tests"))
  writeLines(c("Package: workspacecanary", "Version: 0.0.1", "Title: Check Profile Calibration", "Description: Exercises installed check tools with bounded deterministic fixtures.",
    "Authors@R: person('Test', 'Author', email='test@example.org', role=c('aut','cre'))", "License: GPL-3", "Encoding: UTF-8"),file.path(pkg,"DESCRIPTION"))
  writeLines("export(answer)",file.path(pkg,"NAMESPACE"))
  writeLines(if(case=="code") "answer <- function() workspace_intentionally_undefined" else "answer <- function() 42",file.path(pkg,"R/answer.R"))
  writeLines(c("\\name{answer}","\\alias{answer}","\\title{Calibration answer}","\\description{Returns the calibration answer.}",
    if(case=="documentation") "\\usage{answer(unexpected_argument)}" else "\\usage{answer()}","\\value{The number forty two.}",
    if(case=="example") "\\examples{stop('WORKSPACE_EXAMPLE_DEFECT')}" else "\\examples{stopifnot(answer() == 42)}"),file.path(pkg,"man/answer.Rd"))
  writeLines(if(case=="test") "stop('WORKSPACE_TEST_DEFECT')" else "library(workspacecanary); stopifnot(answer() == 42)",file.path(pkg,"tests/calibration.R"))
  if(case=="build") {dir.create(file.path(pkg,"src"));writeLines('#error WORKSPACE_BUILD_DEFECT',file.path(pkg,"src/calibration.c"))}
  if(case=="no-exercises") {
    unlink(file.path(pkg,"tests"),recursive=TRUE)
    rd <- file.path(pkg,"man/answer.Rd");text <- readLines(rd)
    writeLines(text[!grepl("examples",text,fixed=TRUE)],rd)
  }
  for (profile in c("strict","application")) {
    destination <- file.path(out,paste(case,profile,sep="-"));dir.create(destination)
    env <- application_env
    if(profile=="strict") env <- env[names(env)!="_R_CHECK_CRAN_INCOMING_REMOTE_"]
    # Unset inherited check knobs; only the explicit profile reaches the child.
    inherited <- grep("^_R_CHECK_", names(Sys.getenv()), value=TRUE)
    overrides <- c(setNames(rep(NA_character_,length(inherited)),inherited),env)
    overrides <- overrides[!duplicated(names(overrides),fromLast=TRUE)]
    error <- NULL
    result <- withr::with_envvar(overrides,tryCatch(rcmdcheck::rcmdcheck(pkg,args=c("--no-manual","--as-cran"),error_on="warning",check_dir=destination,quiet=TRUE,timeout=90),error=function(e){error <<- e; e$result}))
    logs <- list.files(destination,pattern="00check.log$",recursive=TRUE,full.names=TRUE)
    text <- if(length(logs)) readLines(logs[1],warn=FALSE) else character()
    expected <- switch(case,code="workspace_intentionally_undefined",documentation="unexpected_argument",example="WORKSPACE_EXAMPLE_DEFECT",test="WORKSPACE_TEST_DEFECT",build="WORKSPACE_BUILD_DEFECT",valid="DONE",`no-exercises`="No examples, no tests, no vignettes")
    evidence_files <- list.files(destination,pattern="00check.log$|00install.out$|Rout.fail$",recursive=TRUE,full.names=TRUE)
    diagnostic_text <- unlist(lapply(evidence_files,readLines,warn=FALSE))
    saveRDS(list(result=result,condition=error),file.path(destination,"result.rds"))
    sections <- grep("^\\* checking",text,value=TRUE)
    intended <- any(grepl(expected,diagnostic_text,fixed=TRUE))
    required_sections <- switch(case,valid=c("examples","tests","R code","Rd"),
      code=c("R code","examples","tests"),documentation=c("code/documentation mismatches","Rd \\usage"),
      example="examples",test="tests",build="can be installed",`no-exercises`="code which exercises the package")
    terminal <- inherits(result,"rcmdcheck") && isFALSE(result$timeout) &&
      is.numeric(result$status) && length(result$status)==1L && !is.na(result$status) && result$status %in% c(0L,1L)
    completed <- terminal && length(logs)==1L &&
      identical(normalizePath(dirname(logs)),normalizePath(result$checkdir)) &&
      any(grepl("^\\* DONE$",text)) && any(grepl("^Status: ",text)) &&
      any(grepl("^\\* DONE$",strsplit(result$stdout,"\n",fixed=TRUE)[[1L]])) &&
      all(vapply(required_sections,function(x)any(grepl(x,sections,fixed=TRUE)),logical(1))) &&
      ((result$status==0L && !length(result$errors)) || (result$status==1L && length(result$errors)>0L))
    execution_failure <- !completed || (!is.null(error) && !inherits(error,"rcmdcheck_failure"))
    rejection <- !execution_failure && inherits(error,"rcmdcheck_failure") &&
      ((inherits(error,"rcmdcheck_error") && length(result$errors)>0L) ||
       (inherits(error,"rcmdcheck_warning") && length(result$warnings)>0L))
    success <- !execution_failure && is.null(error) && result$status==0L
    proof <- if(case=="valid") success else rejection && intended
    observed <- list(case=case,profile=profile,argv=c("R CMD check","--no-manual","--as-cran"),env=as.list(env),
      check_exit_status=result$status, evidence_files=evidence_files, completed=completed,execution_failure=execution_failure,
      successful=success,error=if(is.null(error)) NULL else conditionMessage(error),intended_diagnostic=intended,sections=sections,proof=proof)
    receipt$canaries[[paste(case,profile,sep="-")]] <- observed
    write_receipt()
  }
}
stopifnot(length(receipt$canaries)==14L,all(vapply(receipt$canaries,function(x)isTRUE(x$proof),logical(1))))
receipt$status <- "PASS"
write_receipt()
cat("CHECK PROFILE: strict/application valid controls and six intended invalid cases verified; guarded local URLs retained\n")
RPROFILE
  owned_profile "$profile_script"
}

resource_measurements() {
  local resource_dir="$ARTIFACTS/resources"
  mkdir -p "$resource_dir"
  local measurement
  for measurement in "$@"; do
    timeout --kill-after=5s 120s /usr/bin/time -v -o "$resource_dir/$measurement.time.log" \
      Rscript --vanilla "$ROOT/scripts/measure-workspace-resources.R" "$measurement" "$resource_dir/$measurement.json" \
      > "$resource_dir/$measurement.stdout.log" 2> "$resource_dir/$measurement.stderr.log"
    cat "$resource_dir/$measurement.stdout.log"
  done
}

# Keep GNU timeout's process-group cleanup and retain its real terminal status.
# The duration is an argument solely so a short canary can exercise this same path.
serve_watchdog() {
  local lifetime="$1"
  shift
  python3 - "$ARTIFACTS" "$lifetime" "$@" <<'PYSERVE'
import json,os,pathlib,signal,subprocess,sys,time
out=pathlib.Path(sys.argv[1]); lifetime=sys.argv[2]; command=sys.argv[3:]
started=time.time(); process=None; terminal=None; error=None
receipt={'configured_lifetime_seconds':float(lifetime),'wrapper_pid':os.getpid(),
         'started_at':started,'command':command,'identity':None}
def persist(name,value):
    target=out/name
    with target.open('w') as stream:
        json.dump(value,stream,indent=2);stream.flush();os.fsync(stream.fileno())
def forward(signum,frame):
    if process is not None and process.poll() is None:
        process.send_signal(signum)
signal.signal(signal.SIGTERM,forward);signal.signal(signal.SIGINT,forward)
persist('serve-start.json',receipt)
persist('serve-terminal.json',{**receipt,'terminal_status':'unknown','reaped':False})
try:
    process=subprocess.Popen(['timeout','--kill-after=5s',lifetime+'s',*command],start_new_session=True)
    stat=pathlib.Path(f'/proc/{process.pid}/stat').read_text()
    fields=stat[stat.rfind(')')+2:].split()
    receipt['identity']={'pid':process.pid,'parent':int(fields[1]),'group':int(fields[2]),'start':fields[19]}
    persist('serve-start.json',receipt)
    terminal=process.wait()
except BaseException as failure:
    error=repr(failure)
finally:
    # The unreaped child still belongs to this Popen instance. GNU timeout
    # forwards TERM and bounds the owned process group's shutdown with KILL.
    if process is not None:
        if process.poll() is None:process.terminate()
        terminal=process.wait()
    persist('serve-terminal.json',{**receipt,'finished_at':time.time(),
        'terminal_status':terminal if terminal is not None else 'unknown',
        'terminal_signal':-terminal if terminal is not None and terminal<0 else None,
        'reaped':process is not None and process.returncode is not None,'error':error})
if error is not None:raise SystemExit(error)
raise SystemExit(terminal if terminal is not None and terminal>=0 else 128-terminal if terminal is not None else 1)
PYSERVE
}

case "$MODE" in
  serve)
    installed
    serve_watchdog 1800 Rscript --vanilla -e 'tryCatch(shiny::runApp(system.file("application",package="richStudio"),host="127.0.0.1",port=3871,launch.browser=FALSE),finally=future::plan(future::sequential))'
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
  resources)
    install_candidate; installed; receipt
    resource_measurements small representative upper render worker worker-error
    ;;
  browser)
    install_candidate; installed; receipt
    resource_measurements render
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
  coverage-calibration)
    receipt; coverage_receipt
    # covr compiles only a disposable snapshot; no project tests/examples are run.
    mkdir -p "$SCRATCH/coverage-source"
    python3 - "$ROOT" "$SCRATCH/coverage-source" <<'PYCOPY'
import pathlib,shutil,subprocess,sys
source,target=map(pathlib.Path,sys.argv[1:])
for relative in subprocess.check_output(['git','-C',str(source),'ls-files'],text=True).splitlines():
    p=source/relative
    if p.is_file():
        q=target/relative;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
PYCOPY
    export WORKSPACE_CALIBRATION_SOURCE="$SCRATCH/coverage-source"
    timeout --kill-after=5s 300s Rscript --vanilla - <<'RCOVERAGE'
root <- Sys.getenv("WORKSPACE_CALIBRATION_SOURCE")
out <- Sys.getenv("ARTIFACTS")
coverage <- covr::package_coverage(root, quiet = TRUE, clean = FALSE, type="none",
  install_path=Sys.getenv("WORKSPACE_COVERAGE_LIBRARY"),
  code=paste0("source(",deparse(Sys.getenv("WORKSPACE_COVERAGE_CALIBRATION")),")"))
stopifnot(file.exists(file.path(out,"coverage-parent.json")),file.exists(file.path(out,"coverage-worker.json")))
lines <- covr::tally_coverage(coverage, by="line")
file_totals <- do.call(rbind,lapply(split(lines,lines$filename),function(x) data.frame(filename=x$filename[1],covered=sum(x$value>0),total=nrow(x))))
utils::write.csv(file_totals,file.path(out,"coverage-file-totals.csv"),row.names=FALSE)
saveRDS(coverage, file.path(out, "coverage.rds"))
covr::to_cobertura(coverage, file.path(out, "coverage.xml"))
cat("Installed parent and owned worker calibration verified; no project tests or full coverage verdict\n")
RCOVERAGE
    ;;
  profile-cleanup)
    profile_cleanup
    ;;
  local-urls)
    local_urls
    ;;
  check-profile)
    receipt; check_profile
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
    WORKSPACE_URL_SOURCE="$ROOT" check_profile
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
    coverage_receipt
    Rscript --vanilla - <<'R'
root <- Sys.getenv("WORKSPACE_SOURCE_ROOT")
out <- Sys.getenv("ARTIFACTS")
check_error <- NULL
profile <- jsonlite::read_json(file.path(out,"check-profile/receipt.json"),simplifyVector=TRUE)
stopifnot(identical(profile$status,"PASS"))
env <- unlist(profile$application_env)
expected_env <- c(`_R_CHECK_CRAN_INCOMING_`="TRUE", `_R_CHECK_CRAN_INCOMING_REMOTE_`="FALSE",
 `_R_CHECK_OVERWRITE_REGISTERED_S3_METHODS_`="TRUE", `_R_CHECK_AUTOCONF_`="TRUE")
stopifnot(!anyDuplicated(names(env)),setequal(names(env),names(expected_env)),identical(env[names(expected_env)],expected_env))
inherited <- grep("^_R_CHECK_",names(Sys.getenv()),value=TRUE)
overrides <- c(setNames(rep(NA_character_,length(inherited)),inherited),env)
overrides <- overrides[!duplicated(names(overrides),fromLast=TRUE)]
jsonlite::write_json(list(args=c("--no-manual","--as-cran"),error_on="warning",env=as.list(env),local_url_receipt=profile$local_url_receipt),file.path(out,"application-check-profile.json"),auto_unbox=TRUE,pretty=TRUE)
check <- withr::with_envvar(overrides,tryCatch(rcmdcheck::rcmdcheck(root, args = c("--no-manual", "--as-cran"), error_on = "warning", check_dir = file.path(out, "R-check")), error = function(e) { check_error <<- conditionMessage(e); NULL }))
# Retain the instrumented install until identity/worker/calibration evidence is read.
coverage <- covr::package_coverage(root, quiet = TRUE, clean = FALSE,
  install_path=Sys.getenv("WORKSPACE_COVERAGE_LIBRARY"),
  code=paste0("source(",deparse(Sys.getenv("WORKSPACE_COVERAGE_CALIBRATION")),")"))
stopifnot(file.exists(file.path(out,"coverage-parent.json")),file.exists(file.path(out,"coverage-worker.json")))
lines <- covr::tally_coverage(coverage, by="line")
file_totals <- do.call(rbind,lapply(split(lines,lines$filename),function(x) data.frame(filename=x$filename[1],covered=sum(x$value>0),total=nrow(x))))
utils::write.csv(file_totals,file.path(out,"coverage-file-totals.csv"),row.names=FALSE)
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
  *) echo "Usage: $0 prepare|scoped|browser|negative|diagnostics|diagnostics-negative|local-urls|profile-cleanup|check-profile|coverage-calibration|full|serve|resources" >&2; exit 2 ;;
esac
