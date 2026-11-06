#!/usr/bin/env python3
"""SPEC-DEPLOYRECOVERY-001: execute the actual publication tail with safe mocks."""

import argparse
import getpass
import os
import re
import shlex
import shutil
import sys
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = Path(os.environ.get("DEPLOY_RECOVERY_SOURCE", Path(__file__).with_name("deploy-r46-release.sh")))
MOCKS = r'''
set -Eeuo pipefail
APP_PATH=/mock/app
APP_PARENT=/mock
PREVIOUS_TARGET=/mock/previous
RELEASE_DIR=/mock/candidate
APP_USER=mock
SHINY_URL=http://mock.invalid/
WORK_ROOT=/mock/build
RELEASE_SHA=mock-sha
LIVE_TARGET=$PREVIOUS_TARGET
PENDING_TARGET=
FAILED=0
record() { printf 'CALL %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
readlink() {
    record "readlink $*"
    [[ $CASE != readlink_failure || $FAILED == 0 ]] || return 2
    printf '%s\n' "$LIVE_TARGET"
}
as_app_user() {
    shift
    local operation=$1 target
    record "link $*"
    if [[ $operation == ln ]]; then
        target=${@: -2:1}
        [[ $CASE != pre_swap_failure || $target != "$RELEASE_DIR" ]] || return 11
        [[ $CASE != restore_link_failure || $target != "$PREVIOUS_TARGET" ]] || return 19
        PENDING_TARGET=$target
    elif [[ $operation == mv ]]; then
        [[ $CASE != restore_move_failure || $PENDING_TARGET != "$PREVIOUS_TARGET" ]] || return 19
        LIVE_TARGET=$PENDING_TARGET
        if [[ $LIVE_TARGET == "$RELEASE_DIR" ]]; then
            case "$CASE" in
                boundary_exit) exit 23 ;;
                signal_int) kill -INT "$$" ;;
                signal_term) kill -TERM "$$" ;;
            esac
        fi
    else
        printf 'UNEXPECTED MOCK OPERATION\n' >&2; exit 90
    fi
}
timeout() {
    record "timeout $*"
    [[ $1 == --kill-after=* ]] && shift
    [[ $1 =~ ^[0-9]+s$ ]] || { printf 'MISSING DEADLINE\n' >&2; return 91; }
    shift
    "$@"
}
systemctl() {
    record "service $LIVE_TARGET $*"
    if [[ $1 == restart ]]; then
        if [[ $LIVE_TARGET == "$RELEASE_DIR" ]]; then
            case "$CASE" in
                success|publish_health_failure|publish_inactive|post_swap_verify_failure) return 0 ;;
                foreign_target) LIVE_TARGET=/mock/foreign ;;
            esac
            FAILED=1
            return 17
        fi
        [[ $CASE != recovery_restart_failure ]] || return 24
    elif [[ $1 == is-active ]]; then
        [[ $CASE != recovery_inactive || $LIVE_TARGET != "$PREVIOUS_TARGET" ]] || return 3
        [[ $CASE != publish_inactive || $LIVE_TARGET != "$RELEASE_DIR" ]] || return 3
    fi
}
curl() {
    record "http $LIVE_TARGET $*"
    if [[ $LIVE_TARGET == "$RELEASE_DIR" && $CASE == publish_health_failure ]] ||
       [[ $LIVE_TARGET == "$PREVIOUS_TARGET" && $CASE == recovery_http_failure ]]; then
        printf 'Unavailable\n503'; return 0
    fi
    if [[ $LIVE_TARGET == "$PREVIOUS_TARGET" && $CASE == recovery_error_page ]]; then
        printf 'An error has occurred\n200'; return 0
    fi
    if [[ $LIVE_TARGET == "$PREVIOUS_TARGET" && $CASE == recovery_transport_failure ]]; then
        printf 'OK\n200'; return 22
    fi
    printf 'OK\n200'
}
sleep() { record "sleep $*"; }
pgrep() { return 1; }
rm() { record "cleanup $*"; }
# WS-014: the post-swap real-environment verification and the live-process scan. The mock fails the
# verification only while the new release is live, with HTTP still answering 200 (a 200 never passes).
verify_runtime_env() {
    record "verify_runtime_env $LIVE_TARGET $*"
    if [[ $CASE == post_swap_verify_failure && $LIVE_TARGET == "$RELEASE_DIR" ]]; then
        printf 'ERROR: real-environment verification failed for %s\n' "$1" >&2
        return 1
    fi
}
check_live_process_env() { record "live_process_env"; }
'''


class RecoveryTests(unittest.TestCase):
    def run_case(self, case):
        source = SOURCE.read_text()
        marker = "# ---- publish: atomic symlink swap, then full shiny-server restart -----------"
        self.assertEqual(source.count(marker), 1)
        with tempfile.TemporaryDirectory(prefix="deploy-recovery-test-") as directory:
            script = Path(directory) / "case.sh"
            script.write_text(MOCKS + "\n" + source[source.index(marker):])
            result = subprocess.run(
                ["bash", str(script)], capture_output=True, text=True, timeout=5,
                env={"PATH": "/usr/bin:/bin", "CASE": case},
            )
        self.assertNotIn("UNEXPECTED MOCK", result.stderr)
        return result

    def assert_recovered(self, case, code):
        result = self.run_case(case)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        self.assertIn("ROLLBACK VERIFIED", result.stdout)
        self.assertNotIn("DEPLOY COMPLETE", result.stdout)
        self.assertEqual(result.stderr.count("service /mock/previous restart shiny-server"), 1)
        self.assertIn("service /mock/previous is-active --quiet shiny-server", result.stderr)
        self.assertIn("http /mock/previous", result.stderr)
        link = result.stderr.index("link mv -T -- /mock/app.swap /mock/app", result.stderr.index("link ln -sfn -- /mock/previous"))
        self.assertLess(link, result.stderr.index("service /mock/previous restart"))
        self.assertLess(result.stderr.index("service /mock/previous restart"), result.stderr.index("http /mock/previous"))
        self.assertIn("timeout --kill-after=5s 210s systemctl restart shiny-server", result.stderr)
        self.assertIn("timeout --kill-after=5s 5s systemctl is-active --quiet shiny-server", result.stderr)
        self.assertIn("--max-time 30", result.stderr)
        return result

    def test_failed_publish_restart_restores_and_verifies(self):
        self.assert_recovered("publish_restart_failure", 17)

    def test_failed_publish_health_restores_and_verifies(self):
        self.assert_recovered("publish_health_failure", 1)

    def test_inactive_publish_service_cannot_pass(self):
        self.assert_recovered("publish_inactive", 1)

    def test_switch_before_marker_still_recovers(self):
        self.assert_recovered("boundary_exit", 23)

    def test_interrupt_status_and_once_only_cleanup(self):
        for case, code in [("signal_int", 130), ("signal_term", 143)]:
            with self.subTest(case=case):
                self.assert_recovered(case, code)

    def test_post_swap_verification_failure_restores_even_when_http_is_200(self):
        result = self.assert_recovered("post_swap_verify_failure", 1)
        self.assertIn("verify_runtime_env /mock/candidate /mock/app", result.stderr)
        self.assertIn("real-environment verification failed", result.stderr)
        # HTTP answered 200 for the candidate before verification ran: a 200 alone never passes.
        self.assertLess(result.stderr.index("http /mock/candidate"), result.stderr.index("verify_runtime_env /mock/candidate"))
        self.assertNotIn("DEPLOY COMPLETE", result.stdout)

    def test_success_runs_the_live_verification_after_the_http_check(self):
        result = self.run_case("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("verify_runtime_env /mock/candidate /mock/app", result.stderr)
        self.assertLess(result.stderr.index("http /mock/candidate"), result.stderr.index("verify_runtime_env /mock/candidate"))
        self.assertLess(result.stderr.index("verify_runtime_env /mock/candidate"), result.stderr.index("live_process_env"))

    def test_pre_switch_failure_does_not_restart_or_restore(self):
        result = self.run_case("pre_swap_failure")
        self.assertEqual(result.returncode, 11)
        self.assertNotIn("link ln -sfn -- /mock/previous", result.stderr)
        self.assertNotIn("service ", result.stderr)
        self.assertNotIn("ROLLBACK VERIFIED", result.stdout)

    def test_foreign_target_is_not_overwritten_or_restarted(self):
        result = self.run_case("foreign_target")
        self.assertEqual(result.returncode, 17)
        self.assertNotIn("link ln -sfn -- /mock/previous", result.stderr)
        self.assertNotIn("service /mock/foreign", result.stderr)
        self.assertIn("ROLLBACK FAILED: ownership", result.stdout)

    def test_unreadable_target_is_not_overwritten(self):
        result = self.run_case("readlink_failure")
        self.assertEqual(result.returncode, 17)
        self.assertNotIn("link ln -sfn -- /mock/previous", result.stderr)
        self.assertNotIn("service /mock/previous", result.stderr)
        self.assertIn("ROLLBACK FAILED: ownership", result.stdout)

    def test_recovery_failures_preserve_original_status_and_stop(self):
        for case, stage in [
            ("restore_link_failure", "restore"), ("restore_move_failure", "restore"),
            ("recovery_restart_failure", "restart"), ("recovery_inactive", "health"),
            ("recovery_http_failure", "health"), ("recovery_error_page", "health"),
            ("recovery_transport_failure", "health"),
        ]:
            with self.subTest(case=case):
                result = self.run_case(case)
                self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
                self.assertIn("ROLLBACK FAILED: " + stage, result.stdout)
                self.assertNotIn("ROLLBACK VERIFIED", result.stdout)
                self.assertNotIn("DEPLOY COMPLETE", result.stdout)
                self.assertNotIn("cleanup ", result.stderr)
                self.assertLessEqual(result.stderr.count("service /mock/previous restart"), 1)
                self.assertLessEqual(result.stderr.count("http /mock/previous"), 20)
                if stage == "restore":
                    self.assertNotIn("service /mock/previous", result.stderr)
                if stage == "restart":
                    self.assertNotIn("http /mock/previous", result.stderr)

    def test_legacy_runtime_guard_matches_literal_dot(self):
        line = next(line for line in SOURCE.read_text().splitlines() if line.startswith("if pgrep "))
        pattern = shlex.split(line)[5]
        result = subprocess.run(["grep", "-E", "--", pattern], input="R-4.5\nR-4x5\nR-4.6\n", text=True, capture_output=True, timeout=5)
        self.assertEqual(result.stdout, "R-4.5\n")

    def test_success_does_not_run_recovery(self):
        result = self.run_case("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("DEPLOY COMPLETE", result.stdout)
        self.assertNotIn("ROLLBACK", result.stdout)
        self.assertNotIn("link ln -sfn -- /mock/previous", result.stderr)
        self.assertIn("cleanup -rf -- /mock/build", result.stderr)


ANNOTATION_BLOCK = re.compile(r"# >>> WS-014 annotation functions >>>\n(.*?)# <<< WS-014 annotation functions <<<", re.S)
LIB_LEAF = "r4.6-bioc3.23"


class AnnotationFunctionTests(unittest.TestCase):
    """SPEC-WS-014 M1 deploy functions, sourced from the real script into a harness with fakes.

    AC-002 (.Renviron generator), AC-011 (real-environment verification fails before the swap on a
    mistyped or reversed library order), AC-016 (R minor and Bioconductor pin)."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="deploy-annotation-test-")).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.annot = self.tmp / "annotation" / LIB_LEAF

    def run_bash(self, body, path=None, extra_env=None):
        match = ANNOTATION_BLOCK.search(SOURCE.read_text())
        self.assertIsNotNone(match, "annotation function block markers not found")
        script = self.tmp / "harness.sh"
        script.write_text(
            "set -Eeuo pipefail\n"
            "PINNED_R_MINOR=4.6\nBIOC_VERSION=3.23\nLIB_RELATIVE=renv/library/release-r46\n"
            "APP_HOME=%s\nAPP_USER=%s\nANNOTATION_LIB=%s\nANNOTATION_PARENT=%s\n"
            "fail() { printf 'ERROR: %%s\\n' \"$*\" >&2; exit 1; }\n"
            "as_app_user() { shift; \"$@\"; }\n" % (self.tmp, getpass.getuser(), self.annot, self.annot.parent)
            + match.group(1) + "\n" + body + "\n")
        env = {"PATH": path or "/usr/bin:/bin"}
        env.update(extra_env or {})
        return subprocess.run(["bash", str(script)], capture_output=True, text=True, timeout=60, env=env)

    def release(self, name="rel"):
        rel = self.tmp / name
        (rel / "renv" / "library" / "release-r46").mkdir(parents=True)
        self.annot.mkdir(parents=True, exist_ok=True)
        return rel

    # AC-002
    def test_renviron_generator_has_exactly_three_variables_and_cmp_detects_a_typo(self):
        rel = self.release()
        result = self.run_bash('render_renviron "%s" > "%s/.Renviron"' % (rel, rel))
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = (rel / ".Renviron").read_text().splitlines()
        self.assertEqual(lines, [
            "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE",
            "R_LIBS_USER=%s/renv/library/release-r46:%s" % (rel, self.annot),
            "RICHSTUDIO_ANNOTATION_LIB=%s" % self.annot])
        self.assertEqual(self.run_bash('cmp <(render_renviron "%s") "%s/.Renviron"' % (rel, rel)).returncode, 0)
        (rel / ".Renviron").write_text("\n".join(lines).replace("richStudio/annotation", "richStudio/annotatoin").replace(str(self.annot), str(self.annot) + "x") + "\n")
        self.assertNotEqual(self.run_bash('cmp <(render_renviron "%s") "%s/.Renviron"' % (rel, rel)).returncode, 0)

    # AC-011 (logic: bytes mismatch stops before R runs)
    def test_mistyped_or_reversed_renviron_fails_before_the_verification_r_runs(self):
        rel = self.release()
        good = self.run_bash('render_renviron "%s"' % rel).stdout.splitlines()
        reversed_libs = "R_LIBS_USER=%s:%s/renv/library/release-r46" % (self.annot, rel)
        cases = {
            "mistyped": [good[0], good[1].replace(LIB_LEAF, "r4.6-bioc3.22"), good[2]],
            "reversed": [good[0], reversed_libs, good[2]],
            "test_variable": good + ["RICHSTUDIO_ANNOTATION_TEST_MODE=1"],
        }
        for name, lines in cases.items():
            with self.subTest(case=name):
                (rel / ".Renviron").write_text("\n".join(lines) + "\n")
                body = 'as_app_user() { printf "R-INVOKED\\n"; }\nverify_runtime_env "%s"' % rel
                result = self.run_bash(body)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("R-INVOKED", result.stdout + result.stderr)
                self.assertIn("ERROR:", result.stderr)
        (rel / ".Renviron").write_text("\n".join(good) + "\n")
        body = 'as_app_user() { shift; printf "R-INVOKED %%s\\n" "$*"; }\nverify_runtime_env "%s"' % (rel, )
        result = self.run_bash(body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("verify-env", result.stdout)
        self.assertIn("env -i", result.stdout)

    # AC-011 (mechanism: R really reads ./.Renviron from the release directory and orders the libraries)
    def test_real_r_reads_the_release_renviron_and_orders_the_libraries(self):
        rel = self.release()
        (rel / ".Renviron").write_text(self.run_bash('render_renviron "%s"' % rel).stdout)
        probe = "cat(.libPaths()[1:2], sep = '\\n')"
        run = subprocess.run(["env", "-i", "HOME=" + str(self.tmp), "PATH=/usr/local/bin:/usr/bin:/bin", "Rscript",
                              "-e", probe], cwd=rel, capture_output=True, text=True, timeout=120)
        self.assertEqual(run.stdout.split(), [str(rel / "renv/library/release-r46"), str(self.annot)], run.stderr)
        (rel / ".Renviron").write_text("R_LIBS_USER=%s:%s/renv/library/release-r46\n" % (self.annot, rel))
        run = subprocess.run(["env", "-i", "HOME=" + str(self.tmp), "PATH=/usr/local/bin:/usr/bin:/bin", "Rscript",
                              "-e", probe], cwd=rel, capture_output=True, text=True, timeout=120)
        self.assertEqual(run.stdout.split(), [str(self.annot), str(rel / "renv/library/release-r46")])

    # AC-016
    def test_version_pin_accepts_any_4_6_patch_and_rejects_other_minors(self):
        shim = self.tmp / "shim"
        shim.mkdir()
        cases = [("4.6.2", "3.23", True), ("4.6.1", "3.23", True), ("4.7.0", "3.23", False),
                 ("4.5.9", "3.23", False), ("4.6.2", "3.24", False)]
        for r_version, bioc, accepted in cases:
            with self.subTest(r=r_version, bioc=bioc):
                (shim / "R").write_text("#!/bin/sh\necho 'R version %s (2026-10-29) -- \"Diversified Portfolio\"'\n" % r_version)
                (shim / "Rscript").write_text("#!/bin/sh\nprintf '%s'\n" % bioc)
                os.chmod(shim / "R", 0o755)
                os.chmod(shim / "Rscript", 0o755)
                result = self.run_bash("check_runtime_versions", path="%s:/usr/bin:/bin" % shim)
                self.assertIn("Measured R %s, Bioconductor %s" % (r_version, bioc), result.stdout)
                if accepted:
                    self.assertEqual(result.returncode, 0, result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0)
                    if r_version.rsplit(".", 1)[0] != "4.6":
                        self.assertIn(r_version, result.stderr)
                        self.assertIn("4.6", result.stderr)
                    else:
                        self.assertIn(bioc, result.stderr)
                        self.assertIn("3.23", result.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--script", type=Path, help="Actual deployment script to verify; no Git or external packages required.")
    options, remaining = parser.parse_known_args()
    if options.script is not None:
        SOURCE = options.script
    unittest.main(argv=[sys.argv[0], *remaining], verbosity=2)
