#!/usr/bin/env python3
"""SPEC-DEPLOYRECOVERY-001: execute the actual publication tail with safe mocks."""

import argparse
import os
import shlex
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
                success|publish_health_failure|publish_inactive) return 0 ;;
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--script", type=Path, help="Actual deployment script to verify; no Git or external packages required.")
    options, remaining = parser.parse_known_args()
    if options.script is not None:
        SOURCE = options.script
    unittest.main(argv=[sys.argv[0], *remaining], verbosity=2)
