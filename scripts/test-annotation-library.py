#!/usr/bin/env python3
"""SPEC-WS-014 M1: real-process tests for the annotation installer.

Drives inst/annotation/annotation-install.sh (bash supervisor) and annotation-install.R
(base-R worker) as real child processes: setsid session, kernel flock, GNU timeout, kill by
session id. The downloader is a fake (no internet); the repository is a local directory of
tiny source packages. Nothing here touches the host, the live library or the network.

Process hygiene: every spawned session is registered and killed in cleanup, an atexit hook
and a global SIGALRM watchdog; every wait is bounded.

    python3 scripts/test-annotation-library.py

Classes: InstallerTests (AC-004..AC-010 on the supervisor and worker), DeployFaultTests
(AC-015 on the deploy functions), MergeGatePlaceholders (fails on purpose while the data the
lead must measure on the host is still a placeholder; see docs/quality/ws014-m1-deploy-record.md).
"""

import atexit
import getpass
import hashlib
import os
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUPERVISOR = ROOT / "inst" / "annotation" / "annotation-install.sh"
WORKER_R = ROOT / "inst" / "annotation" / "annotation-install.R"
ALLOWLIST = ROOT / "inst" / "extdata" / "annotation-allowlist.tsv"
FLOORS = ROOT / "inst" / "extdata" / "annotation-verify-floors.tsv"
DEPLOY = ROOT / "scripts" / "deploy-r46-release.sh"
RECORD = ROOT / "docs" / "quality" / "ws014-m1-deploy-record.md"
BASH = shutil.which("bash") or "/usr/bin/bash"
RSCRIPT = shutil.which("Rscript") or "/usr/bin/Rscript"
PLACEHOLDER = "PENDING-LEAD"
BIOC = "3.23"
APP_USER_NAME = getpass.getuser()

# ---- process hygiene ------------------------------------------------------------

_SESSIONS = set()


def kill_session(sid):
    """Kill every process in session `sid` (never our own session, never init)."""
    if not sid or sid <= 1 or sid == os.getsid(0):
        return
    subprocess.run(["pkill", "-KILL", "-s", str(sid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _kill_all():
    for sid in list(_SESSIONS):
        kill_session(sid)


def _watchdog(signum, frame):
    _kill_all()
    sys.stderr.write("WATCHDOG: global time budget exhausted; all test sessions killed\n")
    os._exit(3)


atexit.register(_kill_all)
signal.signal(signal.SIGALRM, _watchdog)
signal.signal(signal.SIGTERM, _watchdog)


def wait_for(cond, timeout, step=0.05):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = cond()
        if value:
            return value
        time.sleep(step)
    return cond()


def r_lib_name():
    out = subprocess.run(
        [RSCRIPT, "--vanilla", "-e", 'cat(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1])'],
        capture_output=True, text=True, timeout=60).stdout.split()
    return "r%s.%s-bioc%s" % (out[0], out[1], BIOC)


LIB_NAME = r_lib_name()

# ---- fakes ---------------------------------------------------------------------

FAKE_DOWNLOADER = r"""#!/usr/bin/env bash
# Test downloader: same argv as curl. Behaviour comes from files in $FAKE_DL_CTL.
out="" url="" i=0
args=("$@")
while (( i < $# )); do
  a=${args[i]}
  case $a in
    --output) out=${args[i+1]}; i=$((i+2)) ;;
    --max-time|--write-out|--proto|--proto-redir|--max-redirs) i=$((i+2)) ;;
    --*) i=$((i+1)) ;;
    *) url=$a; i=$((i+1)) ;;
  esac
done
printf '%s %s %s\n' "$(date +%s.%N)" "$$" "$url" >> "$FAKE_DL_LOG"
mode=$(cat "$FAKE_DL_CTL/mode" 2>/dev/null || echo ok)
secs=$(cat "$FAKE_DL_CTL/seconds" 2>/dev/null || echo 600)
case $mode in
  sleep) sleep "$secs" ;;
  slowtar) [[ $url == *.tar.gz ]] && sleep "$secs" ;;
  fail22) exit 22 ;;
  netfail) exit 7 ;;
esac
path=${url#file://}
cp -- "$path" "$out" || exit 37
if [[ -s $FAKE_DL_CTL/finalurl ]]; then
  cat "$FAKE_DL_CTL/finalurl"
else
  printf 'https://bioconductor.org/packages/%s/data/annotation/src/contrib/%s' "3.23" "$(basename "$url")"
fi
"""

# A fake worker (bash), named annotation-install.R so pgrep -f sees the same argv shape as the
# real one. Behaviour per phase comes from files in $FAKEW_CTL: "exit N" | "sleep N" |
# "ignoreterm N" | "selfkill".
FAKE_WORKER = r"""#!/usr/bin/env bash
act=$(cat "$FAKEW_CTL/$1" 2>/dev/null || echo "exit 0")
case $act in
  "exit "*) exit "${act#exit }" ;;
  "sleep "*) sleep "${act#sleep }" ;;
  "ignoreterm "*) trap '' TERM; sleep "${act#ignoreterm }" ;;
  selfkill) kill -KILL $$ ;;
esac
exit 0
"""

ALLOW_HEADER = "species\tpackage\tkind\tstatus\tpreinstall\test_mb\tinst_mb\treactome_supported\treason"


class Pkg:
    def __init__(self, name, version="1.0.0", probe=True, configure_sleep=None, md5=True, est_mb="1"):
        self.name, self.version, self.probe, self.configure_sleep = name, version, probe, configure_sleep
        self.md5, self.est_mb = md5, est_mb


class Env:
    """One isolated annotation world: library, local repository, fake downloader, test config."""

    def __init__(self, testcase, pkgs, limits=None, cfg_extra=None):
        self.tc = testcase
        self.base = Path(tempfile.mkdtemp(prefix="ws014-ann-"))
        testcase.addCleanup(self.cleanup)
        self.parent = self.base / "annotation"
        self.parent.mkdir(mode=0o755)
        os.chmod(self.parent, 0o755)
        self.lib = self.parent / LIB_NAME
        self.lib.mkdir(mode=0o755)
        os.chmod(self.lib, 0o755)
        self.lock = self.parent / (LIB_NAME + ".lock")
        self.status_path = self.parent / (LIB_NAME + ".status")
        self.ctl = self.base / "ctl"
        self.ctl.mkdir()
        self.wctl = self.base / "wctl"
        self.wctl.mkdir()
        self.dl_log = self.base / "dl.log"
        self.dl_log.write_text("")
        self.pkgs = pkgs
        self.contrib = self.base / "repo" / "src" / "contrib"
        self.contrib.mkdir(parents=True)
        self._build_repo(pkgs)
        self.downloader = self._script("fake-downloader.sh", FAKE_DOWNLOADER)
        fw = self.base / "fakeworker"
        fw.mkdir()
        self.fake_worker = fw / "annotation-install.R"
        self.fake_worker.write_text(FAKE_WORKER)
        os.chmod(self.fake_worker, 0o755)
        self.allowlist = self.base / "allowlist.tsv"
        self.write_allowlist(pkgs)
        self.cfg = self.base / "test.cfg"
        self.cfg_values = {"repo": "file://" + str(self.base / "repo"), "allowlist": str(self.allowlist),
                           "downloader": str(self.downloader), "probe": "stub"}
        self.cfg_values.update(limits or {})
        self.cfg_values.update(cfg_extra or {})
        self.write_cfg()
        self.runs = []

    # -- construction helpers
    def _script(self, name, text):
        p = self.base / name
        p.write_text(text)
        os.chmod(p, 0o755)
        return p

    def _build_repo(self, pkgs):
        entries = []
        for pkg in pkgs:
            work = self.base / ("src-" + pkg.name)
            (work / pkg.name / "R").mkdir(parents=True)
            (work / pkg.name / "DESCRIPTION").write_text(
                "Package: %s\nVersion: %s\nTitle: Tiny fake annotation package\n"
                "Description: Tiny fake annotation package used only by installer tests.\n"
                "License: GPL-2\nEncoding: UTF-8\n" % (pkg.name, pkg.version))
            (work / pkg.name / "NAMESPACE").write_text("export(probe_ok)\n")
            (work / pkg.name / "R" / "probe.R").write_text("probe_ok <- function() %s\n" % ("TRUE" if pkg.probe else "FALSE"))
            if pkg.configure_sleep:
                conf = work / pkg.name / "configure"
                conf.write_text("#!/bin/sh\nsleep %s\n" % pkg.configure_sleep)
                os.chmod(conf, 0o755)
            tar = self.contrib / ("%s_%s.tar.gz" % (pkg.name, pkg.version))
            subprocess.run(["tar", "-czf", str(tar), "-C", str(work), pkg.name], check=True)
            md5 = hashlib.md5(tar.read_bytes()).hexdigest()
            entry = "Package: %s\nVersion: %s\n" % (pkg.name, pkg.version)
            if pkg.md5:
                entry += "MD5sum: %s\n" % md5
            entries.append(entry)
        (self.contrib / "PACKAGES").write_text("\n".join(entries) + "\n")

    def write_allowlist(self, pkgs, extra_rows=()):
        rows = [ALLOW_HEADER]
        for i, pkg in enumerate(pkgs):
            rows.append("\t".join(["sp%d" % i, pkg.name, "organism", "available", "yes", pkg.est_mb, "1", "yes", ""]))
        rows.extend(extra_rows)
        self.allowlist.write_text("\n".join(rows) + "\n")

    def write_cfg(self):
        self.cfg.write_text("".join("%s: %s\n" % (k, v) for k, v in self.cfg_values.items()))

    def set_cfg(self, **kw):
        self.cfg_values.update({k: str(v) for k, v in kw.items()})
        self.write_cfg()

    def dl_mode(self, mode, seconds=None, finalurl=None):
        (self.ctl / "mode").write_text(mode)
        if seconds is not None:
            (self.ctl / "seconds").write_text(str(seconds))
        fu = self.ctl / "finalurl"
        if finalurl is None:
            fu.write_text("")
        else:
            fu.write_text(finalurl)

    def worker_ctl(self, phase, action):
        (self.wctl / phase).write_text(action)

    # -- process helpers
    def env(self, extra=None, test_mode=True, path=None):
        e = {k: v for k, v in os.environ.items() if not k.startswith(("RICHSTUDIO_", "R_PROFILE", "R_ENVIRON")) and k not in ("BASH_ENV", "ENV")}
        e.update({"RICHSTUDIO_ANNOTATION_LIB": str(self.lib), "RICHSTUDIO_RSCRIPT": RSCRIPT,
                  "FAKE_DL_LOG": str(self.dl_log), "FAKE_DL_CTL": str(self.ctl), "FAKEW_CTL": str(self.wctl),
                  "HOME": str(self.base)})
        if test_mode:
            e["RICHSTUDIO_ANNOTATION_TEST_MODE"] = "1"
            e["RICHSTUDIO_ANNOTATION_TEST_CONFIG"] = str(self.cfg)
        if path is not None:
            e["PATH"] = path
        e.update(extra or {})
        return e

    def start(self, *names, fake_worker=False, extra_env=None, via_setsid=False):
        if fake_worker:
            self.set_cfg(worker=str(self.fake_worker))
        n = len(self.runs)
        out = open(self.base / ("run-%d.log" % n), "wb")
        cmd = [BASH, str(SUPERVISOR), *names]
        if via_setsid:
            cmd = ["setsid"] + cmd
        proc = subprocess.Popen(cmd, env=self.env(extra_env), stdout=out, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, start_new_session=not via_setsid)
        run = Run(self, proc, out)
        self.runs.append(run)
        if via_setsid:
            # setsid(1) may fork: the supervisor's pid and session come from its own status file.
            st = wait_for(lambda: self.status(), 60)
            self.tc.assertTrue(st, "no status file from the setsid-launched supervisor")
            run.sid = int(subprocess.run(["ps", "-o", "sid=", "-p", st["pid"]], capture_output=True, text=True).stdout.strip() or 0)
            run.proc_pid = int(st["pid"])
        _SESSIONS.add(run.sid)
        return run

    def run(self, *names, timeout=120, **kw):
        r = self.start(*names, **kw)
        rc = r.wait(timeout)
        self.tc.assertIsNotNone(rc, "supervisor did not finish in %ss:\n%s" % (timeout, r.output()))
        return r

    def lock_free(self):
        return subprocess.run(["flock", "-n", str(self.lock), "true"], timeout=10).returncode == 0

    def staging(self):
        return sorted(p.name for p in self.lib.glob(".staging-*"))

    def status(self):
        return read_status(self.status_path)

    def downloads(self):
        return [l.split()[2] for l in self.dl_log.read_text().splitlines() if l.strip()]

    def tree_digest(self, root=None):
        h = hashlib.sha256()
        root = Path(root or self.lib)
        for p in sorted(root.rglob("*")):
            rel = p.relative_to(root).as_posix()
            if p.is_file() and not p.is_symlink():
                h.update(rel.encode() + b"\0" + p.read_bytes())
            else:
                h.update(rel.encode() + b"\1")
        return h.hexdigest()

    def cleanup(self):
        for r in self.runs:
            kill_session(r.sid)
            _SESSIONS.discard(r.sid)
            try:
                r.proc.wait(timeout=5)
            except Exception:
                pass
            r.out.close()
        shutil.rmtree(self.base, ignore_errors=True)


class Run:
    def __init__(self, env, proc, out):
        self.env, self.proc, self.out = env, proc, out
        self.sid = proc.pid  # start_new_session: the supervisor leads its own session

    def wait(self, timeout):
        try:
            return self.proc.wait(timeout)
        except subprocess.TimeoutExpired:
            return None

    def output(self):
        self.out.flush()
        return Path(self.out.name).read_text(errors="replace")

    def session_pids(self, pattern=None):
        cmd = ["pgrep", "-s", str(self.sid)]
        if pattern:
            cmd += ["-f", pattern]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return [int(x) for x in r.stdout.split()]

    def kill_session(self):
        kill_session(self.sid)
        self.proc.wait(timeout=10)


STATUS_KEYS = ["schema", "pid", "request", "packages", "current", "phase", "state", "reason",
               "started", "deadline", "heartbeat", "updated"]
PHASES = {"starting", "preparing", "downloading", "installing", "validating", "finalizing", "done"}
STATES = {"running", "completed", "failed", "stopped"}
REASONS = {"", "no_network", "timed_out", "checksum_mismatch", "not_enough_disk", "dependency_missing",
           "entry_invalid", "index_no_md5", "unavailable", "internal_error"}


def read_status(path):
    try:
        text = Path(path).read_text()
    except FileNotFoundError:
        return None
    d = {}
    for line in text.splitlines():
        k, _, v = line.partition("=")
        d[k] = v
    return d


def status_problems(d):
    """Schema validation of a status file dict; [] means valid."""
    p = []
    if d is None:
        return ["missing"]
    if list(d.keys()) != STATUS_KEYS:
        p.append("keys %s" % list(d.keys()))
        return p
    if d["schema"] != "1":
        p.append("schema")
    for k in ("pid", "started", "deadline", "heartbeat", "updated"):
        if not re.fullmatch(r"[0-9]+", d[k]):
            p.append("integer " + k)
    if not re.fullmatch(r"[A-Za-z0-9]{8,32}", d["request"]):
        p.append("request token")
    if d["phase"] not in PHASES:
        p.append("phase " + d["phase"])
    if d["state"] not in STATES:
        p.append("state " + d["state"])
    if d["reason"] not in REASONS:
        p.append("reason " + d["reason"])
    if d["reason"] and d["state"] != "failed":
        p.append("reason without failed")
    return p


class InstallerBase(unittest.TestCase):
    def setUp(self):
        signal.alarm(900)

    def worker_cmd(self, env, *args, test_mode=True):
        e = env.env(test_mode=test_mode)
        return subprocess.run([RSCRIPT, "--vanilla", str(WORKER_R), *args], env=e, capture_output=True,
                              text=True, timeout=120)

    def wait_phase(self, env, phase, timeout=60):
        ok = wait_for(lambda: (env.status() or {}).get("phase") == phase, timeout)
        self.assertTrue(ok, "never reached phase %s; status=%s" % (phase, env.status()))

    def wait_worker(self, run, timeout=60):
        pids = wait_for(lambda: run.session_pids("annotation-install.R"), timeout)
        self.assertTrue(pids, "no worker process observed in session %s (a check on a dead worker would pass vacuously)" % run.sid)


# ---- AC-004 .. AC-010 ---------------------------------------------------------------


class InstallerTests(InstallerBase):
    # AC-004 -----------------------------------------------------------------
    def test_ac004_success_leaves_no_staging_and_records_installed_tsv(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        r = env.run("org.Fake1.eg.db")
        self.assertEqual(r.proc.returncode, 0, r.output())
        self.assertEqual(env.staging(), [])
        self.assertTrue((env.lib / "org.Fake1.eg.db" / "DESCRIPTION").is_file())
        st = env.status()
        self.assertEqual((st["state"], st["phase"], st["reason"]), ("completed", "done", ""))
        self.assertEqual(status_problems(st), [])
        rows = (env.lib / "INSTALLED.tsv").read_text().splitlines()
        self.assertEqual(rows[0].split("\t"), ["package", "version", "sha256", "md5", "source_url", "installed_at"])
        self.assertEqual(len(rows), 2)
        f = rows[1].split("\t")
        self.assertEqual((f[0], f[1]), ("org.Fake1.eg.db", "1.0.0"))
        tar = env.contrib / "org.Fake1.eg.db_1.0.0.tar.gz"
        self.assertEqual(f[2], hashlib.sha256(tar.read_bytes()).hexdigest())
        self.assertEqual(f[3], hashlib.md5(tar.read_bytes()).hexdigest())
        self.assertTrue(f[4].startswith("https://bioconductor.org/"))
        self.assertTrue(r.proc.returncode == 0 and env.lock_free())

    def test_ac004_changed_tarball_bytes_end_checksum_mismatch_library_unchanged(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        tar = env.contrib / "org.Fake1.eg.db_1.0.0.tar.gz"
        tar.write_bytes(tar.read_bytes() + b"tamper")
        before = env.tree_digest()
        r = env.run("org.Fake1.eg.db")
        self.assertEqual(r.proc.returncode, 1, r.output())
        st = env.status()
        self.assertEqual((st["state"], st["reason"]), ("failed", "checksum_mismatch"))
        self.assertEqual(env.tree_digest(), before)
        self.assertEqual(env.staging(), [])

    def test_ac004_sigterm_mid_download_stops_cleanly(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")], limits={"grace": 3})
        env.dl_mode("slowtar", seconds=120)
        r = env.start("org.Fake1.eg.db")
        self.wait_phase(env, "downloading")
        self.wait_worker(r)
        os.kill(r.proc.pid, signal.SIGTERM)
        self.assertEqual(r.wait(30), 130, r.output())
        st = env.status()
        self.assertEqual((st["state"], st["phase"]), ("stopped", "done"))
        self.assertEqual(env.staging(), [])
        self.assertEqual(r.session_pids(), [])
        self.assertTrue(env.lock_free())
        self.assertFalse((env.lib / "org.Fake1.eg.db").exists())

    def test_ac004_session_kill_mid_install_leaves_staging_and_next_run_sweeps(self):
        env = Env(self, [Pkg("org.Fake1.eg.db", configure_sleep=300), Pkg("org.Fake2.eg.db")])
        r = env.start("org.Fake1.eg.db")
        self.wait_phase(env, "installing")
        self.assertTrue(wait_for(lambda: len(r.session_pids()) >= 3, 30), "install phase never had worker descendants")
        sid = int(subprocess.run(["ps", "-o", "sid=", "-p", str(r.proc.pid)], capture_output=True, text=True).stdout)
        self.assertEqual(sid, r.sid)
        r.kill_session()
        self.assertEqual(r.session_pids(), [])
        self.assertTrue(wait_for(env.lock_free, 1), "lock must be free at once after a whole-session kill")
        self.assertTrue(env.staging(), "staging must remain after a SIGKILL of the whole session")
        self.assertFalse((env.lib / "org.Fake1.eg.db").exists())
        self.assertFalse((env.lib / "INSTALLED.tsv").exists())
        r2 = env.run("org.Fake2.eg.db")
        self.assertEqual(r2.proc.returncode, 0, r2.output())
        self.assertEqual(env.staging(), [], "the next lock holder removes leftover staging")

    def test_ac004_valid_existing_entry_is_a_noop_success(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        self.assertEqual(env.run("org.Fake1.eg.db").proc.returncode, 0)
        calls = len(env.downloads())
        digest = env.tree_digest()
        r = env.run("org.Fake1.eg.db")
        self.assertEqual(r.proc.returncode, 0, r.output())
        self.assertEqual(len(env.downloads()), calls, "a present, valid entry must not download anything")
        self.assertEqual(env.tree_digest(), digest)
        self.assertEqual(env.status()["state"], "completed")

    def test_ac004_invalid_existing_entry_fails_entry_invalid_and_is_untouched(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        self.assertEqual(env.run("org.Fake1.eg.db").proc.returncode, 0)
        desc = env.lib / "org.Fake1.eg.db" / "DESCRIPTION"
        desc.write_text(desc.read_text().replace("Version: 1.0.0", "Version: 9.9.9"))
        digest = env.tree_digest()
        r = env.run("org.Fake1.eg.db")
        self.assertEqual(r.proc.returncode, 1, r.output())
        st = env.status()
        self.assertEqual((st["state"], st["reason"]), ("failed", "entry_invalid"))
        self.assertEqual(env.tree_digest(), digest)

    def test_ac004_failed_validation_probe_never_reaches_the_library(self):
        env = Env(self, [Pkg("org.Fake3.eg.db", probe=False)])
        r = env.run("org.Fake3.eg.db")
        self.assertEqual(r.proc.returncode, 1, r.output())
        self.assertEqual(env.status()["state"], "failed")
        self.assertFalse((env.lib / "org.Fake3.eg.db").exists())
        self.assertFalse((env.lib / "INSTALLED.tsv").exists())
        self.assertEqual(env.staging(), [])

    # AC-005 -----------------------------------------------------------------
    def test_ac005_lock_is_a_regular_file_and_nothing_else_is_created(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        env.dl_mode("slowtar", seconds=4)
        r = env.start("org.Fake1.eg.db")
        self.wait_phase(env, "downloading")
        self.assertTrue(stat.S_ISREG(os.stat(env.lock).st_mode))
        names = sorted(p.name for p in env.parent.iterdir())
        self.assertEqual(names, sorted([LIB_NAME, LIB_NAME + ".lock", LIB_NAME + ".status"]))
        self.assertEqual(r.wait(60), 0, r.output())
        names = sorted(p.name for p in env.parent.iterdir())
        self.assertEqual(names, sorted([LIB_NAME, LIB_NAME + ".lock", LIB_NAME + ".status"]))
        self.assertFalse(any(re.search("owner|tombstone|\\.d$", n) for n in names))

    def test_ac005_second_supervisor_exits_75_and_touches_nothing(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        env.dl_mode("slowtar", seconds=6)
        r = env.start("org.Fake1.eg.db")
        self.wait_phase(env, "downloading")
        status_before = env.status_path.read_bytes()
        staging_before = env.staging()
        t0 = time.monotonic()
        r2 = env.start("org.Fake1.eg.db")
        self.assertEqual(r2.wait(10), 75, r2.output())
        self.assertLess(time.monotonic() - t0, 2.0)
        self.assertEqual(env.staging(), staging_before)
        self.assertEqual(env.status_path.read_bytes(), status_before)
        self.assertEqual(r.wait(60), 0, r.output())

    def test_ac005_three_supervisors_give_0_75_75_and_one_download(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        env.dl_mode("slowtar", seconds=3)
        runs = [env.start("org.Fake1.eg.db") for _ in range(3)]
        codes = sorted(r.wait(90) for r in runs)
        self.assertEqual(codes, [0, 75, 75], [r.output() for r in runs])
        self.assertEqual(sum(1 for u in env.downloads() if u.endswith(".tar.gz")), 1)

    def test_ac005_session_kill_frees_the_lock_but_a_bare_supervisor_kill_does_not(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        env.dl_mode("slowtar", seconds=120)
        r = env.start("org.Fake1.eg.db")
        self.wait_phase(env, "downloading")
        self.wait_worker(r)
        r.kill_session()
        self.assertEqual(r.session_pids(), [])
        t0 = time.monotonic()
        self.assertTrue(wait_for(env.lock_free, 1))
        self.assertLess(time.monotonic() - t0, 1.0)
        # Second case: kill only the supervisor; the orphaned worker keeps descriptor 9.
        env.dl_mode("slowtar", seconds=6)
        r2 = env.start("org.Fake1.eg.db")
        self.wait_phase(env, "downloading")
        self.wait_worker(r2)
        os.kill(r2.proc.pid, signal.SIGKILL)
        r2.proc.wait(10)
        left = r2.session_pids()
        self.assertTrue(left, "the worker must outlive a bare supervisor kill")
        self.assertFalse(env.lock_free(), "an orphaned worker holds the lock")
        self.assertTrue(wait_for(env.lock_free, 40), "the lock frees once the orphan ends")
        # The orphaned heartbeat tick (descriptor 9 closed) may outlive the lock by up to one tick.
        self.assertTrue(wait_for(lambda: r2.session_pids() == [], 15), r2.session_pids())

    def test_ac005_missing_flock_exits_127_not_75(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        shim = env.base / "bin"
        shim.mkdir()
        for tool in ("timeout", "curl", "sleep", "mkdir", "rm", "date", "mv"):
            real = shutil.which(tool)
            if real:
                (shim / tool).symlink_to(real)
        (shim / "Rscript").symlink_to(RSCRIPT)
        proc = subprocess.run([BASH, str(SUPERVISOR), "org.Fake1.eg.db"], env=env.env(path=str(shim)),
                              capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL)
        self.assertEqual(proc.returncode, 127, proc.stderr)
        self.assertIn("flock", proc.stderr)
        self.assertEqual(env.staging(), [])
        self.assertFalse(env.status_path.exists())

    # AC-006 -----------------------------------------------------------------
    def test_ac006_heartbeat_advances_with_production_tick_while_download_hangs(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        env.dl_mode("slowtar", seconds=120)
        r = env.start("org.Fake1.eg.db")
        self.wait_phase(env, "downloading")
        self.wait_worker(r)
        beats = []
        end = time.monotonic() + 27
        while time.monotonic() < end:
            hb = int(env.status()["heartbeat"])
            if not beats or hb != beats[-1][0]:
                beats.append((hb, time.monotonic()))
            time.sleep(0.25)
        self.assertGreaterEqual(len(beats), 3, beats)
        gaps = [b[1] - a[1] for a, b in zip(beats, beats[1:])]
        self.assertLessEqual(max(gaps), 15.0, gaps)
        self.assertTrue(r.proc.poll() is None)
        plan = subprocess.run([BASH, str(SUPERVISOR), "--print-plan"], env=env.env(test_mode=False),
                              capture_output=True, text=True, timeout=60).stdout
        self.assertIn("heartbeat_tick=10", plan)

    def test_ac006_hanging_download_and_install_end_at_their_limits(self):
        for what in ("download", "install"):
            with self.subTest(phase=what):
                pkg = Pkg("org.Fake1.eg.db", configure_sleep=300 if what == "install" else None)
                env = Env(self, [pkg], limits={"limit_download": 4, "limit_install": 5, "grace": 2})
                if what == "download":
                    env.dl_mode("slowtar", seconds=600)
                r = env.start("org.Fake1.eg.db")
                self.wait_phase(env, "downloading" if what == "download" else "installing")
                self.wait_worker(r)
                self.assertEqual(r.wait(60), 1, r.output())
                st = env.status()
                self.assertEqual((st["state"], st["reason"]), ("failed", "timed_out"))
                self.assertEqual(r.session_pids(), [])
                self.assertEqual(env.staging(), [])
                self.assertTrue(env.lock_free())

    def test_ac006_package_deadline_bounds_the_run(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")], limits={"deadline": 8, "limit_download": 1200, "grace": 2})
        env.dl_mode("slowtar", seconds=600)
        r = env.start("org.Fake1.eg.db")
        self.assertEqual(r.wait(60), 1, r.output())
        st = env.status()
        self.assertEqual((st["state"], st["reason"]), ("failed", "timed_out"))
        self.assertEqual(r.session_pids(), [])

    def test_ac006_sigterm_ignored_worker_is_killed_after_grace_and_second_term_changes_nothing(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")], limits={"grace": 4})
        env.worker_ctl("download", "ignoreterm 120")
        r = env.start("org.Fake1.eg.db", fake_worker=True)
        self.wait_phase(env, "downloading")
        self.wait_worker(r)
        t0 = time.monotonic()
        os.kill(r.proc.pid, signal.SIGTERM)
        time.sleep(1.0)
        os.kill(r.proc.pid, signal.SIGTERM)
        time.sleep(0.5)
        self.assertIsNone(r.proc.poll(), "a second TERM during the grace wait must change nothing")
        self.assertEqual(env.status()["state"], "running")
        self.assertEqual(r.wait(30), 130, r.output())
        self.assertGreaterEqual(time.monotonic() - t0, 3.0, "KILL must wait for the grace period")
        st = env.status()
        self.assertEqual((st["state"], st["phase"]), ("stopped", "done"))
        self.assertEqual(r.session_pids(), [])
        self.assertEqual(env.staging(), [])
        self.assertTrue(env.lock_free())

    def test_ac006_worker_exit_codes_map_to_reason_codes(self):
        cases = {10: "no_network", 11: "checksum_mismatch", 12: "not_enough_disk", 13: "dependency_missing",
                 14: "entry_invalid", 15: "index_no_md5", 16: "unavailable", 17: "timed_out",
                 99: "internal_error", 1: "internal_error"}
        env = Env(self, [Pkg("org.Fake1.eg.db"), Pkg("org.Fake2.eg.db")], limits={"grace": 2})
        for code, reason in cases.items():
            with self.subTest(code=code):
                env.worker_ctl("prepare", "exit %d" % code)
                r = env.run("org.Fake1.eg.db", fake_worker=True)
                self.assertEqual(r.proc.returncode, 1)
                self.assertEqual(env.status()["reason"], reason)
        env.worker_ctl("prepare", "exit 20")
        r = env.run("org.Fake1.eg.db", "org.Fake2.eg.db", fake_worker=True)
        self.assertEqual(r.proc.returncode, 0, "exit 20 skips to the next package; " + r.output())
        self.assertEqual(env.status()["state"], "completed")

    def test_ac006_timeout_killed_and_self_killed_workers(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")], limits={"limit_prepare": 2, "grace": 2})
        env.worker_ctl("prepare", "sleep 60")
        r = env.run("org.Fake1.eg.db", fake_worker=True)
        self.assertEqual(env.status()["reason"], "timed_out", "timeout exit 124 maps to timed_out")
        env.worker_ctl("prepare", "ignoreterm 60")
        r = env.run("org.Fake1.eg.db", fake_worker=True)
        self.assertEqual(env.status()["reason"], "timed_out", "exit 137 at the limit maps to timed_out")
        self.assertEqual(r.session_pids(), [])
        env.worker_ctl("prepare", "selfkill")
        r = env.run("org.Fake1.eg.db", fake_worker=True)
        self.assertEqual(env.status()["reason"], "internal_error", "exit 137 without the limit is internal_error")

    def test_ac006_reader_never_sees_a_partial_status_file(self):
        names = ["pkg%03d" % i for i in range(120)]
        env = Env(self, [Pkg("org.Fake1.eg.db")], limits={"tick": 1})
        env.worker_ctl("prepare", "exit 20")
        stop = threading.Event()
        seen = {"reads": 0, "bad": []}

        def reader():
            while not stop.is_set():
                d = read_status(env.status_path)
                if d is not None:
                    seen["reads"] += 1
                    p = status_problems(d)
                    if p:
                        seen["bad"].append(p)

        t = threading.Thread(target=reader, daemon=True)
        t.start()
        r = env.run(*names, fake_worker=True, timeout=120)
        stop.set()
        t.join(5)
        self.assertEqual(r.proc.returncode, 0, r.output())
        self.assertGreaterEqual(seen["reads"], 1000)
        self.assertEqual(seen["bad"], [])

    def test_ac006_host_tools_and_bash_are_present(self):
        for tool in ("setsid", "flock", "timeout", "curl"):
            self.assertTrue(shutil.which(tool), tool)
        v = subprocess.run([BASH, "--version"], capture_output=True, text=True).stdout.splitlines()[0]
        print("bash:", v, file=sys.stderr)
        self.assertTrue(subprocess.run([BASH, "-c", "(( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) ))"]).returncode == 0)

    def test_ac006_runs_under_the_setsid_binary_as_the_app_does(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        r = env.start("org.Fake1.eg.db", via_setsid=True)
        self.assertNotEqual(r.sid, os.getsid(0), "setsid must put the supervisor in its own session")
        st = wait_for(lambda: (env.status() or {}).get("state") == "completed" and env.status(), 120)
        self.assertTrue(st, "never completed: " + r.output())
        self.assertEqual(status_problems(st), [])
        self.assertTrue((env.lib / "org.Fake1.eg.db" / "DESCRIPTION").is_file())

    def test_ac006_production_plan_limits(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        plan = subprocess.run([BASH, str(SUPERVISOR), "--print-plan"], env=env.env(test_mode=False),
                              capture_output=True, text=True, timeout=60).stdout
        for line in ("limit_download=1200", "limit_install=1200", "deadline_per_package=2400", "kill_after_grace=30"):
            self.assertIn(line, plan)

    # AC-007 -----------------------------------------------------------------
    def test_ac007_url_policy(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        bad = {"http://bioconductor.org/packages/3.23/data/annotation": "scheme_not_https:http",
               "ftp://bioconductor.org/x": "scheme_not_https:ftp",
               "https://example.org/packages": "host_not_bioconductor.org:example.org",
               "https://bioconductor.org.evil.example/x": "host_not_bioconductor.org:bioconductor.org.evil.example",
               "https://bioconductor.org@evil.example/x": "malformed_url", "": "empty_url"}
        for url, reason in bad.items():
            with self.subTest(url=url):
                p = self.worker_cmd(env, "check-url", url, test_mode=False)
                self.assertEqual(p.returncode, 1)
                self.assertIn("REJECT " + reason, p.stdout)
        p = self.worker_cmd(env, "check-url", "https://bioconductor.org/packages/3.23/data/annotation", test_mode=False)
        self.assertEqual((p.returncode, p.stdout.strip()), (0, "OK"))
        p = self.worker_cmd(env, "check-url", "file:///tmp/x", test_mode=False)
        self.assertEqual(p.returncode, 1, "file:// is a test-mode-only scheme")

    def test_ac007_redirect_to_another_host_or_http_is_rejected(self):
        for final in ("https://evil.example/pkg.tar.gz", "http://bioconductor.org/pkg.tar.gz"):
            with self.subTest(final=final):
                env = Env(self, [Pkg("org.Fake1.eg.db")])
                env.dl_mode("ok", finalurl=final)
                r = env.run("org.Fake1.eg.db")
                self.assertEqual(r.proc.returncode, 1, r.output())
                self.assertFalse((env.lib / "org.Fake1.eg.db").exists())
                self.assertEqual(env.staging(), [])
                self.assertIn("rejected redirect target", r.output())

    def test_ac007_http_repository_is_refused_before_any_download(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        env.set_cfg(repo="http://bioconductor.org/packages/3.23/data/annotation")
        r = env.run("org.Fake1.eg.db")
        self.assertEqual(r.proc.returncode, 1, r.output())
        self.assertEqual(env.downloads(), [])
        self.assertIn("refused URL", r.output())

    def test_ac007_index_entry_without_md5_fails_index_no_md5(self):
        env = Env(self, [Pkg("org.Fake1.eg.db", md5=False)])
        r = env.run("org.Fake1.eg.db")
        self.assertEqual(r.proc.returncode, 1, r.output())
        self.assertEqual(env.status()["reason"], "index_no_md5")
        self.assertFalse((env.lib / "org.Fake1.eg.db").exists())

    def test_ac007_production_repository_constant(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        p = self.worker_cmd(env, "print-plan", test_mode=False)
        self.assertIn("repository=https://bioconductor.org/packages/3.23/data/annotation\n", p.stdout)

    def test_ac007_download_failures_map_to_network_and_timeout_reasons(self):
        for mode, reason in (("netfail", "no_network"), ("fail22", "no_network")):
            with self.subTest(mode=mode):
                env = Env(self, [Pkg("org.Fake1.eg.db")])
                env.dl_mode(mode)
                r = env.run("org.Fake1.eg.db")
                self.assertEqual(env.status()["reason"], reason, r.output())

    # AC-008 -----------------------------------------------------------------
    def test_ac008_cap_formula_on_a_synthetic_allowlist(self):
        env = Env(self, [Pkg("org.Fake1.eg.db"), Pkg("org.Fake2.eg.db")])
        p = self.worker_cmd(env, "cap")
        self.assertEqual(p.stdout.strip(), "cap_bytes=%d" % (5 * 1024 ** 3), p.stderr)
        rows = [ALLOW_HEADER,
                "a\torg.Big1.eg.db\torganism\tavailable\tno\t1\t4000\tyes\t",
                "b\torg.Big2.eg.db\torganism\tavailable\tno\t1\t2500\tyes\t",
                "c\torg.Gone.eg.db\torganism\tunavailable\tno\tn/a\tn/a\tno\tnot in the index"]
        env.allowlist.write_text("\n".join(rows) + "\n")
        p = self.worker_cmd(env, "cap")
        self.assertEqual(p.stdout.strip(), "cap_bytes=%d" % (2 * 6500 * 1024 ** 2))
        env.allowlist.write_text("\n".join([ALLOW_HEADER, "a\torg.Big1.eg.db\torganism\tavailable\tno\t1\t\tyes\t"]) + "\n")
        p = self.worker_cmd(env, "cap")
        self.assertNotEqual(p.returncode, 0, "an empty inst_mb must be an error")

    def test_ac008_free_space_floor_and_cap_stop_before_any_download(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        env.set_cfg(free_space_bytes=2 * 1024 ** 3 - 1)
        r = env.run("org.Fake1.eg.db")
        self.assertEqual(env.status()["reason"], "not_enough_disk", r.output())
        self.assertEqual(env.downloads(), [])
        env.set_cfg(free_space_bytes=2 * 1024 ** 3)
        r = env.run("org.Fake1.eg.db")
        self.assertEqual(r.proc.returncode, 0, "exactly the floor is allowed; " + r.output())
        env2 = Env(self, [Pkg("org.Fake1.eg.db", est_mb="6000")])
        r = env2.run("org.Fake1.eg.db")
        self.assertEqual(env2.status()["reason"], "not_enough_disk", r.output())
        self.assertEqual(env2.downloads(), [])

    # AC-009 -----------------------------------------------------------------
    def test_ac009_installed_tsv_has_six_columns_and_survives_a_kill_before_rename(self):
        env = Env(self, [Pkg("org.Fake1.eg.db"), Pkg("org.Fake2.eg.db")])
        self.assertEqual(env.run("org.Fake1.eg.db").proc.returncode, 0)
        tsv = env.lib / "INSTALLED.tsv"
        before = tsv.read_bytes()
        env.set_cfg(finalize_pause=60)
        r = env.start("org.Fake2.eg.db")
        tmp = wait_for(lambda: list(env.lib.glob("INSTALLED.tsv.tmp.*")), 90)
        self.assertTrue(tmp, "never reached the pause between the temporary file and the rename; " + r.output())
        r.kill_session()
        self.assertEqual(tsv.read_bytes(), before, "previous INSTALLED.tsv must stay byte-identical")
        env.set_cfg(finalize_pause=0)
        for t in env.lib.glob("INSTALLED.tsv.tmp.*"):
            t.unlink()
        shutil.rmtree(env.lib / "org.Fake2.eg.db", ignore_errors=True)
        r = env.run("org.Fake2.eg.db")
        self.assertEqual(r.proc.returncode, 0, r.output())
        rows = tsv.read_text().splitlines()
        self.assertEqual(len(rows), 3)
        self.assertTrue(all(len(x.split("\t")) == 6 for x in rows))

    # AC-010 -----------------------------------------------------------------
    def test_ac010_test_config_alone_is_ignored(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")])
        only_cfg = env.env(test_mode=False)
        only_cfg["RICHSTUDIO_ANNOTATION_TEST_CONFIG"] = str(env.cfg)
        plan = subprocess.run([BASH, str(SUPERVISOR), "--print-plan"], env=only_cfg, capture_output=True,
                              text=True, timeout=60).stdout
        self.assertIn("test_mode=0", plan)
        self.assertIn("repository=https://bioconductor.org/packages/3.23/data/annotation", plan)
        self.assertIn("allowlist=%s" % (ROOT / "inst" / "extdata" / "annotation-allowlist.tsv"), plan)
        self.assertIn("downloader=curl", plan)
        both = env.env()
        plan = subprocess.run([BASH, str(SUPERVISOR), "--print-plan"], env=both, capture_output=True,
                              text=True, timeout=60).stdout
        self.assertIn("test_mode=1", plan)
        self.assertIn("repository=file://" + str(env.base / "repo"), plan)
        self.assertIn("downloader=%s" % env.downloader, plan)
        only_mode = env.env(test_mode=False)
        only_mode["RICHSTUDIO_ANNOTATION_TEST_MODE"] = "1"
        plan = subprocess.run([BASH, str(SUPERVISOR), "--print-plan"], env=only_mode, capture_output=True,
                              text=True, timeout=60).stdout
        self.assertIn("test_mode=0", plan)

    def test_ac010_seams_are_inert_without_both_variables(self):
        env = Env(self, [Pkg("org.Fake1.eg.db")], limits={"limit_download": 1})
        plan = subprocess.run([BASH, str(SUPERVISOR), "--print-plan"], env=env.env(test_mode=False),
                              capture_output=True, text=True, timeout=60).stdout
        self.assertIn("limit_download=1200", plan)


# ---- AC-015 (deploy functions) ----------------------------------------------------------


def deploy_block():
    text = DEPLOY.read_text()
    m = re.search(r"# >>> WS-014 annotation functions >>>\n(.*?)# <<< WS-014 annotation functions <<<", text, re.S)
    if not m:
        raise AssertionError("annotation function block markers not found in the deploy script")
    return m.group(1)


class VerifyEnvLogicTests(unittest.TestCase):
    """AC-011 / AC-012 logic of `annotation-install.R verify-env`, run with stub builder/enricher.

    The real buildAnnot and shiny_enrich need the real annotation packages, which no local library
    has: those are host steps. These tests prove the checks decide correctly on injected inputs."""

    def setUp(self):
        signal.alarm(300)
        self.tmp = Path(tempfile.mkdtemp(prefix="ws014-verify-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.rel = self.tmp / "release"
        self.rel_lib = self.rel / "renv" / "library" / "release-r46"
        self.rel_lib.mkdir(parents=True)
        self.annot = self.tmp / "annotation" / LIB_NAME
        self.annot.mkdir(parents=True)
        major_minor = LIB_NAME[1:].split("-")[0]
        self.built = "R %s.2; ; 2026-01-01 00:00:00 UTC; unix" % major_minor
        pre = [r["package"] for r in table_rows(ALLOWLIST) if r["preinstall"] == "yes"]
        for pkg in pre:
            self.add_pkg(self.annot, pkg)

    def add_pkg(self, lib, pkg, built=None):
        d = lib / pkg
        d.mkdir(parents=True, exist_ok=True)
        (d / "DESCRIPTION").write_text("Package: %s\nVersion: 1.0\nBuilt: %s\n" % (pkg, built or self.built))

    def verify(self, builder="ok", enricher="ok", worker="ok", environ='c(HOME = "x")', libpaths=None):
        fixture = self.tmp / "fixture.tsv"
        fixture.write_text("symbol\nTP53\n")
        lp = libpaths or 'c("%s", "%s")' % (self.rel_lib, self.annot)
        builders = {"ok": "mk(6000, 1500)", "small": "mk(10, 5)"}
        enrichers = {"ok": 'data.frame(Annot = c("GO:0006915", paste0("GO:", 1:5)), Padj = rep(0.001, 6))',
                     "few": 'data.frame(Annot = c("GO:0006915", "GO:1"), Padj = c(0.001, 0.2))',
                     "noterm": 'data.frame(Annot = paste0("GO:", 1:6), Padj = rep(0.001, 6))'}
        workers = {"ok": 'c("%s", "%s")' % (self.rel_lib, self.annot), "reversed": 'c("%s", "%s")' % (self.annot, self.rel_lib)}
        code = "\n".join([
            '.annotation_script_dir <- "%s"' % WORKER_R.parent,
            'source("%s")' % WORKER_R,
            'mk <- function(g, t) { n <- max(g, t); data.frame(a = rep_len(seq_len(g), n), b = rep_len(seq_len(t), n)) }',
            'res <- verify_env("%s", "%s", "%s", "%s", "%s",' % (self.rel, self.annot, ALLOWLIST, FLOORS, fixture),
            '  builder = function(species, keytype, anntype) %s,' % builders[builder],
            '  enricher = function(df, header, species, anntype, keytype, ontology) %s,' % enrichers[enricher],
            '  worker_libpaths = function() %s, libpaths = %s, environ = %s)' % (workers[worker], lp, environ),
            'quit(status = if (res) 0L else 1L)'])
        script = self.tmp / "v.R"
        script.write_text(code)
        env = {k: v for k, v in os.environ.items() if not k.startswith(("RICHSTUDIO_", "R_"))}
        env["R_LIBS_USER"] = "%s:%s" % (self.rel_lib, self.annot)
        return subprocess.run([RSCRIPT, "--vanilla", str(script)], capture_output=True, text=True, timeout=120, env=env)

    def test_all_checks_pass_on_good_inputs(self):
        p = self.verify()
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("VERIFY PASS", p.stdout)
        self.assertEqual(p.stdout.count("CHECK floor_"), 11)
        self.assertEqual(p.stdout.count("FAIL"), 0)

    def test_emptied_annotation_library_fails(self):
        shutil.rmtree(self.annot)
        self.annot.mkdir()
        p = self.verify()
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("CHECK pkg_org.Hs.eg.db: FAIL", p.stdout)

    def test_counts_below_the_floor_fail(self):
        p = self.verify(builder="small")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("CHECK floor_human_GO: FAIL", p.stdout)

    def test_fixture_needs_five_significant_rows_and_the_apoptosis_term(self):
        for kind in ("few", "noterm"):
            with self.subTest(kind=kind):
                p = self.verify(enricher=kind)
                self.assertNotEqual(p.returncode, 0)
                self.assertIn("CHECK fixture_enrichment: FAIL", p.stdout)

    def test_worker_or_main_library_order_reversed_fails(self):
        p = self.verify(worker="reversed")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("CHECK worker_libpaths_order: FAIL", p.stdout)
        p = self.verify(libpaths='c("%s", "%s")' % (self.annot, self.rel_lib))
        self.assertIn("CHECK libpaths_order: FAIL", p.stdout)

    def test_test_only_variable_in_the_environment_fails(self):
        p = self.verify(environ='c(RICHSTUDIO_ANNOTATION_TEST_MODE = "1")')
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("CHECK test_env_absent: FAIL", p.stdout)

    def test_package_also_in_the_release_library_fails(self):
        self.add_pkg(self.rel_lib, "org.Hs.eg.db")
        p = self.verify()
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("CHECK pkg_org.Hs.eg.db: FAIL", p.stdout)

    def test_package_built_for_another_r_fails(self):
        self.add_pkg(self.annot, "org.Mm.eg.db", built="R 4.5.2; ; 2026-01-01 00:00:00 UTC; unix")
        p = self.verify()
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("CHECK pkg_org.Mm.eg.db: FAIL", p.stdout)


class DeployFaultTests(unittest.TestCase):
    """AC-015: three planted faults, each fails before the swap with a message naming it."""

    def setUp(self):
        signal.alarm(300)
        self.tmp = Path(tempfile.mkdtemp(prefix="ws014-fault-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def call(self, body):
        script = self.tmp / "h.sh"
        script.write_text(
            "set -Eeuo pipefail\n"
            "APP_USER=%s\nLIB_RELATIVE=renv/library/release-r46\nRELEASE_ROOT=/opt/richStudio/releases\n"
            "fail() { printf 'ERROR: %%s\\n' \"$*\" >&2; exit 1; }\n" % APP_USER_NAME +
            deploy_block() + "\n" + body + "\n")
        return subprocess.run([BASH, str(script)], capture_output=True, text=True, timeout=60,
                              env={"PATH": "/usr/bin:/bin"})

    def make_lib(self, mode=0o755):
        parent = self.tmp / "annotation"
        lib = parent / LIB_NAME
        lib.mkdir(parents=True)
        os.chmod(parent, 0o755)
        os.chmod(lib, mode)
        return lib

    def test_ac015_annotation_package_in_the_release_library_is_refused(self):
        rel = self.tmp / "release" / "renv" / "library" / "release-r46" / "org.Hs.eg.db"
        rel.mkdir(parents=True)
        (self.tmp / "release" / "inst" / "extdata").mkdir(parents=True)
        shutil.copy(ALLOWLIST, self.tmp / "release" / "inst" / "extdata" / "annotation-allowlist.tsv")
        p = self.call('check_release_lib_clean "%s"' % (self.tmp / "release"))
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("org.Hs.eg.db", p.stderr)
        self.assertIn("release library", p.stderr)
        clean = self.tmp / "clean"
        (clean / "renv" / "library" / "release-r46").mkdir(parents=True)
        (clean / "inst" / "extdata").mkdir(parents=True)
        shutil.copy(ALLOWLIST, clean / "inst" / "extdata" / "annotation-allowlist.tsv")
        self.assertEqual(self.call('check_release_lib_clean "%s"' % clean).returncode, 0)

    def test_ac015_world_writable_annotation_directory_is_refused(self):
        lib = self.make_lib(mode=0o777)
        p = self.call('check_annotation_library "%s" "%s"' % (lib, APP_USER_NAME))
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("writable", p.stderr)

    def test_ac015_wrong_owner_is_refused(self):
        lib = self.make_lib()
        p = self.call('check_annotation_library "%s" root' % lib)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("owned by", p.stderr)

    def test_ac015_good_library_and_bad_shapes(self):
        lib = self.make_lib()
        user = APP_USER_NAME
        self.assertEqual(self.call('check_annotation_library "%s" "%s"' % (lib, user)).returncode, 0)
        self.assertNotEqual(self.call('check_annotation_library "%s/../%s" "%s"' % (lib, LIB_NAME, user)).returncode, 0)
        self.assertNotEqual(self.call('check_annotation_library "relative/%s" "%s"' % (LIB_NAME, user)).returncode, 0)
        wrong = lib.parent / "r4.5-bioc3.22"
        wrong.mkdir(mode=0o755)
        # an old minor is still shaped correctly; only the running-version comparison is the app's job
        self.assertEqual(self.call('check_annotation_library "%s" "%s"' % (wrong, user)).returncode, 0)
        (lib.parent / "link").symlink_to(lib)
        self.assertNotEqual(self.call('check_annotation_library "%s" "%s"' % (lib.parent / "link", user)).returncode, 0)

    def test_ac015_package_built_for_r45_is_refused_by_the_r_check(self):
        lib = self.tmp / "alib"
        (lib / "org.Old.eg.db").mkdir(parents=True)
        (lib / "org.Old.eg.db" / "DESCRIPTION").write_text(
            "Package: org.Old.eg.db\nVersion: 1.0\nBuilt: R 4.5.2; ; 2026-01-01 00:00:00 UTC; unix\n")
        (lib / "org.New.eg.db").mkdir(parents=True)
        major_minor = LIB_NAME[1:].split("-")[0]
        (lib / "org.New.eg.db" / "DESCRIPTION").write_text(
            "Package: org.New.eg.db\nVersion: 1.0\nBuilt: R %s.2; ; 2026-01-01 00:00:00 UTC; unix\n" % major_minor)
        script = self.tmp / "r.R"
        script.write_text('.annotation_script_dir <- "%s"\nsource("%s")\ncat(built_for_this_r("%s", "org.Old.eg.db"), built_for_this_r("%s", "org.New.eg.db"), "\\n")\n'
                          % (WORKER_R.parent, WORKER_R, lib, lib))
        p = subprocess.run([RSCRIPT, "--vanilla", str(script)], capture_output=True, text=True, timeout=60)
        self.assertEqual(p.stdout.split(), ["FALSE", "TRUE"], p.stderr)


# ---- merge gate: fails loudly while the lead's host measurements are placeholders -------------


def table_rows(path):
    lines = path.read_text().splitlines()
    header = lines[0].split("\t")
    return [dict(zip(header, l.split("\t"))) for l in lines[1:] if l.strip()]


class MergeGatePlaceholders(unittest.TestCase):
    """These FAIL while any value the lead must measure on the host is still a placeholder
    (AC-008 measured installed sizes, AC-012 floors confirmed at <= 50% of the measured
    counts, deploy record filled). A red result here means M1 must not merge."""

    def test_ac008_every_available_row_has_a_measured_inst_mb(self):
        rows = table_rows(ALLOWLIST)
        bad = [r["package"] for r in rows if r["status"] == "available" and not re.fullmatch(r"[0-9]+(\.[0-9]+)?", r["inst_mb"])]
        self.assertEqual(bad, [], "inst_mb is not measured (placeholder %s) for: %s" % (PLACEHOLDER, bad))

    def test_ac008_cap_equals_the_formula_over_measured_sizes(self):
        rows = [r for r in table_rows(ALLOWLIST) if r["status"] == "available"]
        if any(not re.fullmatch(r"[0-9]+(\.[0-9]+)?", r["inst_mb"]) for r in rows):
            self.fail("inst_mb placeholders remain; the cap cannot be computed")
        expected = max(5 * 1024 ** 3, 2 * sum(float(r["inst_mb"]) for r in rows) * 1024 ** 2)
        out = subprocess.run([RSCRIPT, "--vanilla", str(WORKER_R), "cap"], capture_output=True, text=True,
                             timeout=60, env={k: v for k, v in os.environ.items() if not k.startswith("RICHSTUDIO_")}).stdout
        self.assertEqual(out.strip(), "cap_bytes=%d" % expected)

    def test_ac012_deploy_record_has_no_placeholders(self):
        text = RECORD.read_text()
        n = text.count(PLACEHOLDER)
        self.assertEqual(n, 0, "%d %s placeholders remain in %s" % (n, PLACEHOLDER, RECORD.name))

    def test_ac012_floors_are_numeric(self):
        for r in table_rows(FLOORS):
            self.assertRegex(r["min_genes"], r"^[0-9]+$")
            self.assertRegex(r["min_terms"], r"^[0-9]+$")


class AllowlistShape(unittest.TestCase):
    """Data-file shape tests that need no host measurement."""

    def test_allowlist_columns_rows_and_unavailable_reasons(self):
        rows = table_rows(ALLOWLIST)
        self.assertEqual(len(rows), 23)
        self.assertEqual(sum(1 for r in rows if r["status"] == "available"), 19)
        for r in rows:
            if r["status"] == "unavailable":
                self.assertTrue(r["reason"].strip(), r["species"])
            else:
                self.assertRegex(r["package"], r"^[A-Za-z][A-Za-z0-9.]*$")
        pre = sorted(r["package"] for r in rows if r["preinstall"] == "yes")
        self.assertEqual(pre, sorted(["org.Hs.eg.db", "org.Mm.eg.db", "org.Rn.eg.db", "org.Dr.eg.db", "org.Ce.eg.db", "reactome.db"]))
        self.assertEqual([r["species"] for r in rows if r["kind"] == "reactome"], ["*"])

    def test_floors_cover_five_species_go_reactome_and_human_kegg(self):
        rows = table_rows(FLOORS)
        got = {(r["species"], r["anntype"]) for r in rows}
        five = ["human", "mouse", "rat", "zebrafish", "celegans"]
        self.assertEqual(got, {(s, a) for s in five for a in ("GO", "Reactome")} | {("human", "KEGG")})


if __name__ == "__main__":
    unittest.main(verbosity=2)
