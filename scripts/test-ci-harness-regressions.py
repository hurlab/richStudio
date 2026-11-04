#!/usr/bin/env python3
"""Controlled SPEC-HMAPCI-001 checks of the actual CI/fixture source paths."""

import argparse
import ast
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shlex
import ssl
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest import mock
import urllib.error


NODE_PROOFS = r"""
const fs=require('node:fs'),fsp=require('node:fs/promises'),path=require('node:path');
const vm=require('node:vm'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events');
const {createRequire}=require('node:module');
const tree=process.argv[2],out=process.argv[3],ts=createRequire(path.join(tree,'package.json'))('typescript');
const file=path.join(tree,'tests/e2e/job-lifecycle.spec.ts'),source=fs.readFileSync(file,'utf8');
const ast=ts.createSourceFile(file,source,ts.ScriptTarget.Latest,true);
const declarations=['identity','same','fixtureProcesses'].map(name=>{
 const n=ast.statements.find(n=>ts.isFunctionDeclaration(n)&&n.name?.text===name);
 assert(n,`Actual ${name} declaration missing`);return n.getText(ast);
}).join('\n');
const test=ast.statements.flatMap(n=>ts.isVariableStatement(n)?[...n.declarationList.declarations]:[]).find(n=>n.name.getText(ast)==='test');
const hook=test.initializer.arguments[0].properties.find(p=>p.name?.getText(ast)==='fixture').initializer.getText(ast);
const compiled=ts.transpileModule(declarations+'\nconst fixtureHook='+hook+';',{compilerOptions:{target:ts.ScriptTarget.ES2022}}).outputText;
const owner={pid:100,parent:1,group:100,start:'original-start',state:'S'};
const results=[];
async function check(name,action){try{const evidence=await action();results.push({name,passed:true,...evidence});}catch(e){results.push({name,passed:false,error:String(e),stack:e.stack});}}
function context(mode){
 let reads=0,identityReads=0,clock=0,alive=true;const signals=[],observations=[],attachments=[];
 const child=new EventEmitter();Object.assign(child,{pid:100,exitCode:null,signalCode:null,stdout:new EventEmitter(),stderr:new EventEmitter()});
 const identity=async()=>{identityReads++;if(!alive)return undefined;
  if(mode==='dead'&&identityReads>1)return undefined;
  return {...owner,start:mode==='reused'&&identityReads>1?'reused-start':owner.start};};
 const nonce='controlled-fixture-nonce';
 const files={...fsp,readdir:async p=>p==='/proc'?['100']:fsp.readdir(p),readFile:async(p,...args)=>{
  if(String(p).endsWith('/environ')){reads++;
   if(mode==='permission')throw Object.assign(Error('controlled permission failure'),{code:'EACCES'});
   if(mode==='foreign'||mode==='delayed'&&reads===1)return 'FOREIGN=value\0';
   return 'WS_JOBS_NONCE='+nonce+'\0';}
  return fsp.readFile(p,...args);
 }};
 const ctx={fs:files,path,randomUUID:()=>nonce,fixtureR:'controlled fixture',url:'http://fixture.test',port:3873,
  Date:{now:()=>clock},delay:async ms=>{assert(ms<=500);clock+=ms;},portFree:async()=>{},
  fetch:async()=>({ok:true,text:async()=>nonce}),AbortSignal,
  attach:async(info,name,value)=>attachments.push({name,value}),
  expect:{poll:fn=>({toBe:async expected=>assert.equal(await fn(),expected)})},
  spawn:()=>child,process:{env:{...process.env,WORKSPACE_RUNS_ROOT:out,TMPDIR:out,
   WORKSPACE_INSTALLED_LIBRARY:'/controlled/library',WORKSPACE_DEPENDENCY_LIBRARIES:'/controlled/deps',
   R_LIBS_USER:'/controlled/library:/controlled/deps'},kill:(pid,signal)=>{signals.push({pid,signal});alive=false;child.exitCode=0;child.emit('exit',0);}},
  console,Buffer,setTimeout,clearTimeout};
 child.kill=signal=>{signals.push({pid:100,signal,fallback:true});alive=false;child.exitCode=0;child.emit('exit',0);return true;};
 vm.createContext(ctx);vm.runInContext(compiled,ctx);ctx.identity=identity;
 return {ctx,observations,signals,attachments,counts:()=>({reads,identityReads,clock})};
}
(async()=>{
 await fsp.mkdir(out,{recursive:true});
 await check('delayed_nonce_fresh_same_identity',async()=>{
  const c=context('delayed');const found=await c.ctx.fixtureProcesses(owner,'controlled-fixture-nonce',c.observations);
  assert.equal(found.length,1);const n=c.counts();assert(n.reads>=2&&n.reads<=3);assert(n.identityReads>=n.reads*2);
  assert(n.clock<=2000);assert(c.observations.length>=2);assert.equal(c.observations.at(-1).nonceMatched,true);
  return {counts:n,observations:c.observations};
 });
 for(const mode of ['foreign','permission','reused'])await check(mode+'_fails_closed',async()=>{
  const c=context(mode);let error;try{await c.ctx.fixtureProcesses(owner,'controlled-fixture-nonce',c.observations);}catch(e){error=String(e);}
  assert(error,'Unproven/reused process admitted');assert(c.counts().reads<=3);assert(c.counts().clock<=2000);
  assert(c.observations.length>0,'No durable diagnostic observations');assert.deepEqual(c.signals,[]);
  return {error,counts:c.counts(),observations:c.observations};
 });
 for(const mode of ['foreign','permission','reused','dead'])await check(mode+'_cleanup_never_signals_unproven',async()=>{
  const c=context(mode);let admitted=false,error;
  try{await vm.runInContext('fixtureHook',c.ctx)({workers:1},async()=>{admitted=true;},{});}catch(e){error=String(e);}
  assert(error,'Unsafe fixture unexpectedly succeeded');assert.equal(admitted,false,'Ready listener substituted for ownership');
  assert.deepEqual(c.signals,[],'Actual cleanup path signaled an unproven PID');assert(c.attachments.length>0);
  return {error,counts:c.counts(),signals:c.signals,lifecycle:c.attachments};
 });
 await check('proven_fixture_real_owned_cleanup',async()=>{
  const c=context('owned'),cp=require('node:child_process');let actual,admitted=false;
  c.ctx.fs=fsp;c.ctx.Date=Date;c.ctx.delay=ms=>new Promise(r=>setTimeout(r,ms));
  // Execute the original /proc identity reader for the actual owned subprocess.
  vm.runInContext(ts.transpileModule(declarations,{compilerOptions:{target:ts.ScriptTarget.ES2022}}).outputText,c.ctx);
  c.ctx.spawn=(command,args,options)=>{actual=cp.spawn('timeout',['--kill-after=1s','8s',process.execPath,'-e','setInterval(()=>{},1000)'],options);return actual;};
  c.ctx.process.kill=(pid,signal)=>{c.signals.push({pid,signal});return process.kill(pid,signal);};
  try{await vm.runInContext('fixtureHook',c.ctx)({workers:1},async()=>{admitted=true;},{});
   assert(admitted);assert(actual);assert(actual.exitCode!==null||actual.signalCode!==null);assert(c.signals.length>0);
   assert.equal(await c.ctx.identity(actual.pid),undefined);assert.equal(c.attachments.at(-1).value.safe,true);
   assert.equal(c.attachments.at(-1).value.scratchRemoved,true);
  }finally{if(actual&&actual.exitCode===null&&!actual.signalCode){actual.kill('SIGTERM');await new Promise(r=>actual.once('exit',r));}}
  return {signals:c.signals,lifecycle:c.attachments};
 });
 fs.writeFileSync(path.join(out,'ownership-results.json'),JSON.stringify(results,null,2));
 for(const r of results)console.log((r.passed?'PASS ':'FAIL ')+r.name+(r.error?': '+r.error:''));
 if(results.some(r=>!r.passed))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
"""


class Ownership(unittest.TestCase):
    def test_actual_fixture_proof_and_cleanup(self):
        driver = ARTIFACTS / "ownership-driver.cjs"
        driver.write_text(NODE_PROOFS)
        with tempfile.TemporaryDirectory(prefix="ownership-", dir=ARTIFACTS) as temporary:
            command = ["node", str(driver), str(TREE), temporary]
            result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            (ARTIFACTS / "ownership.log").write_text(result.stdout + result.stderr)
            receipt = Path(temporary, "ownership-results.json")
            self.assertTrue(receipt.exists(), result.stderr)
            (ARTIFACTS / "ownership-results.json").write_bytes(receipt.read_bytes())
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


def workflow_ast():
    source = (TREE / ".github/workflows/workspace-quality.yml").read_text()
    blocks = re.findall(r"          python - <<'PY'\n(.*?)\n          PY", source, re.S)
    code = next(textwrap.dedent(block) for block in blocks if "tooling_sources" in block)
    parsed = ast.parse(code)
    # Substitute only the pinned source table, never retry/verify/install code.
    parsed.body = [node for node in parsed.body if not (
        isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and
        target.id in {"sources", "tooling_sources"} for target in node.targets))]
    return compile(parsed, "actual-workflow-download", "exec")


class Transport(unittest.TestCase):
    def test_controlled_transport_integrity_and_install_matrix(self):
        body = b"verified controlled archive\n"
        digest = hashlib.sha256(body).hexdigest()
        cases = {
            "reset_then_valid": ([ConnectionResetError("controlled reset"), body], digest, False, 2, 1),
            "wrapped_reset_then_valid": ([urllib.error.URLError(ConnectionResetError("reset")), body], digest, False, 2, 1),
            "tls_eof_then_valid": ([ssl.SSLEOFError("controlled TLS interruption"), body], digest, False, 2, 1),
            "timeout_then_valid": ([TimeoutError("controlled timeout"), body], digest, False, 2, 1),
            "three_interruptions": ([ConnectionResetError("reset")] * 3, digest, False, 3, 0),
            "http_hard_failure": ([urllib.error.HTTPError("https://fixture.test", 403, "forbidden", {}, None)], digest, False, 1, 0),
            "certificate_hard_failure": ([urllib.error.URLError(ssl.SSLCertVerificationError("certificate rejected"))], digest, False, 1, 0),
            "malformed_request_hard_failure": ([ValueError("unknown URL type")], digest, False, 1, 0),
            "digest_hard_failure": ([body], "0" * 64, False, 1, 0),
            "install_hard_failure": ([body], digest, True, 1, 1),
        }
        for name, (responses, expected, install_failure, attempts, installations) in cases.items():
            with self.subTest(case=name), tempfile.TemporaryDirectory(prefix=name+"-", dir=ARTIFACTS) as temporary:
                seen_installs = []

                def install(command, **kwargs):
                    self.assertEqual(command[:3], ["R", "CMD", "INSTALL"])
                    seen_installs.append(hashlib.sha256(Path(command[-1]).read_bytes()).hexdigest())
                    if install_failure:
                        raise subprocess.CalledProcessError(7, command)
                    return subprocess.CompletedProcess(command, 0)

                outcomes = [io.BytesIO(item) if isinstance(item, bytes) else item for item in responses]
                error = None
                with mock.patch.dict(os.environ, {"WORKSPACE_ARTIFACTS": temporary}), \
                     mock.patch("urllib.request.urlopen", side_effect=outcomes) as request, \
                     mock.patch("subprocess.run", side_effect=install), mock.patch("time.sleep") as wait:
                    try:
                        exec(workflow_ast(), {"sources": [("canary", "https://fixture.test/archive", expected)]})
                    except BaseException as failure:
                        error = failure
                self.assertEqual(request.call_count, attempts)
                self.assertTrue(all(call.kwargs.get("timeout") == 120 for call in request.call_args_list))
                self.assertEqual(len(seen_installs), installations)
                self.assertTrue(all(value == digest for value in seen_installs))
                self.assertTrue(all(0 <= call.args[0] <= 2 for call in wait.call_args_list))
                self.assertLessEqual(len(wait.call_args_list), 2)
                if name.endswith("then_valid"):
                    self.assertIsNone(error)
                else:
                    self.assertIsNotNone(error)
                receipt = Path(temporary, "archive-download-attempts.jsonl")
                self.assertTrue(receipt.exists(), "Attempt evidence lost on terminal failure")
                rows = [json.loads(line) for line in receipt.read_text().splitlines()]
                (ARTIFACTS / (name+"-attempts.json")).write_text(json.dumps(rows, indent=2))
                self.assertEqual(len(rows), attempts)
                self.assertEqual([row["attempt"] for row in rows], list(range(1, attempts+1)))
                self.assertTrue(all(row["package"] == "canary" and row["url"] == "https://fixture.test/archive" for row in rows))
                self.assertTrue(all("transport_outcome" in row and "digest_outcome" in row for row in rows))
                if installations:
                    self.assertEqual(rows[-1]["digest_outcome"], "verified")
                if name == "digest_hard_failure":
                    self.assertEqual(rows[-1]["digest_outcome"], "mismatch")
                if name == "install_hard_failure":
                    verified = json.loads(Path(temporary, "verified-source-archives.json").read_text())
                    self.assertEqual(verified[-1]["installation_outcome"], "failed")


class Watchdog(unittest.TestCase):
    def test_same_owned_path_timeout_and_normal_terminal_status(self):
        source = (TREE / "scripts/test-workspace.sh").read_text()
        function = re.search(r"(?ms)^serve_watchdog\(\) \{\n.*?^\}", source)
        self.assertIsNotNone(function, "Same-path finite watchdog/receipt hook is absent")
        self.assertRegex(source, r"serve_watchdog\s+1800\s+Rscript")
        self.assertIn('timeout=90', source)
        for name, expected in (("normal", 7), ("timeout", 124)):
            with self.subTest(case=name), tempfile.TemporaryDirectory(prefix=name+"-", dir=ARTIFACTS) as temporary:
                worker_receipt = Path(temporary, "worker.json")
                worker = (
                    "import os,pathlib,json,time; pid=os.getpid(); "
                    "stat=pathlib.Path('/proc/'+str(pid)+'/stat').read_text(); "
                    "fields=stat[stat.rfind(')')+2:].split(); "
                    f"pathlib.Path({str(worker_receipt)!r}).write_text(json.dumps("
                    "{'pid':pid,'start':fields[19]})); "
                    + ("raise SystemExit(7)" if name == "normal" else "time.sleep(10)")
                )
                command = [sys.executable, "-c", worker]
                script = "set -euo pipefail\nARTIFACTS=$1\n" + function.group() + "\nserve_watchdog 0.2 " + shlex.join(command)
                result = subprocess.run(["bash", "-c", script, "canary", temporary], capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, expected, result.stdout+result.stderr)
                start = json.loads(Path(temporary, "serve-start.json").read_text())
                terminal = json.loads(Path(temporary, "serve-terminal.json").read_text())
                (ARTIFACTS / (name+"-serve-start.json")).write_text(json.dumps(start, indent=2))
                (ARTIFACTS / (name+"-serve-terminal.json")).write_text(json.dumps(terminal, indent=2))
                self.assertEqual(terminal["terminal_status"], expected)
                self.assertTrue(terminal["reaped"])
                self.assertEqual(float(start["configured_lifetime_seconds"]), 0.2)
                self.assertIn("pid", start["identity"])
                self.assertIn("start", start["identity"])
                pid = int(start["identity"]["pid"])
                self.assertFalse(Path("/proc", str(pid)).exists(), "Owned watchdog was not reaped")
                worker_identity = json.loads(worker_receipt.read_text())
                self.assertNotEqual(worker_identity["pid"], pid)
                self.assertFalse(Path("/proc", str(worker_identity["pid"])).exists(),
                                 "Owned worker was not terminated and reaped")
                (ARTIFACTS / (name+"-worker.json")).write_text(json.dumps(worker_identity))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tree", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--component", choices=["all", "ownership", "transport", "watchdog"], default="all")
    options = parser.parse_args()
    TREE = options.tree.resolve(strict=True)
    ARTIFACTS = options.artifacts.resolve()
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    classes = {"ownership": Ownership, "transport": Transport, "watchdog": Watchdog}
    selected = classes.values() if options.component == "all" else [classes[options.component]]
    suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(cls) for cls in selected)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    (ARTIFACTS / "regression-summary.json").write_text(json.dumps({
        "tree": str(TREE), "tests": result.testsRun, "failures": len(result.failures),
        "errors": len(result.errors), "skips": len(result.skipped), "passed": result.wasSuccessful(),
        "files": {str(p.relative_to(TREE)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (
            TREE/"tests/e2e/job-lifecycle.spec.ts", TREE/"scripts/test-workspace.sh",
            TREE/".github/workflows/workspace-quality.yml")},
    }, indent=2))
    sys.exit(0 if result.wasSuccessful() else 1)
