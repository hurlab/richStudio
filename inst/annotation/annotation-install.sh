#!/usr/bin/env bash
# SPEC-WS-014 annotation installer: bash supervisor.
#
#   annotation-install.sh <package> [<package> ...]     names only, never a URL or a path
#   annotation-install.sh --print-plan
#
# Library path: RICHSTUDIO_ANNOTATION_LIB. Request token (optional, [A-Za-z0-9]{8,32}):
# RICHSTUDIO_ANNOTATION_REQUEST. Rscript: RICHSTUDIO_RSCRIPT (default Rscript).
#
# The supervisor owns the kernel flock, the signals, the child pids and exit codes, the
# heartbeat and the status file. annotation-install.R does the package logic, one phase per
# process. Exit codes: 0 completed, 1 failed, 2 bad arguments, 75 busy (another installer
# holds the library lock), 127 a required tool is missing, 130 stopped by TERM/INT/HUP.
set -u

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKER="$SELF_DIR/annotation-install.R"
RSCRIPT=${RICHSTUDIO_RSCRIPT:-Rscript}

log() { printf 'annotation-install: %s\n' "$*" >&2; }
die_tool() { log "required tool missing: $1"; exit 127; }

# 1. Tools. 127 is distinct from busy (75).
if ! (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then die_tool "bash>=5.1 (wait -n -p)"; fi
for t in flock timeout curl; do command -v "$t" >/dev/null 2>&1 || die_tool "$t"; done
command -v "$RSCRIPT" >/dev/null 2>&1 || die_tool "Rscript"

# Defaults are the production limits (OD-3). The test-only seams need BOTH variables (REQ-010).
LIMIT_PREPARE=120 LIMIT_DOWNLOAD=1200 LIMIT_INSTALL=1200 LIMIT_VALIDATE=1200 LIMIT_FINALIZE=120
DEADLINE=2400 GRACE=30 TICK=10
TEST_MODE=0 TEST_WORKER=""
if [[ ${RICHSTUDIO_ANNOTATION_TEST_MODE:-} == 1 && -n ${RICHSTUDIO_ANNOTATION_TEST_CONFIG:-} ]]; then
    [[ -r $RICHSTUDIO_ANNOTATION_TEST_CONFIG ]] || { log "test config not readable"; exit 2; }
    TEST_MODE=1
    while IFS= read -r line || [[ -n $line ]]; do
        key=${line%%:*}
        val=${line#*:}
        val=${val# }
        case $key in
            limit_prepare|limit_download|limit_install|limit_validate|limit_finalize|deadline|grace|tick)
                [[ $val =~ ^[0-9]+$ ]] || { log "bad numeric test seam: $key"; exit 2; }
                case $key in
                    limit_prepare) LIMIT_PREPARE=$val ;; limit_download) LIMIT_DOWNLOAD=$val ;;
                    limit_install) LIMIT_INSTALL=$val ;; limit_validate) LIMIT_VALIDATE=$val ;;
                    limit_finalize) LIMIT_FINALIZE=$val ;; deadline) DEADLINE=$val ;;
                    grace) GRACE=$val ;; tick) TICK=$val ;;
                esac ;;
            worker) TEST_WORKER=$val ;;
        esac
    done < "$RICHSTUDIO_ANNOTATION_TEST_CONFIG"
fi

if [[ ${1:-} == --print-plan ]]; then
    printf 'test_mode=%s\nlimit_prepare=%s\nlimit_download=%s\nlimit_install=%s\nlimit_validate=%s\nlimit_finalize=%s\ndeadline_per_package=%s\nkill_after_grace=%s\nheartbeat_tick=%s\n' \
        "$TEST_MODE" "$LIMIT_PREPARE" "$LIMIT_DOWNLOAD" "$LIMIT_INSTALL" "$LIMIT_VALIDATE" "$LIMIT_FINALIZE" "$DEADLINE" "$GRACE" "$TICK"
    exec "$RSCRIPT" --vanilla "$WORKER" print-plan
fi

# ---- state, status file, signal handling ---------------------------------------
HAVE_LOCK=0
PHASE_PID=""
TICK_PID=""
STAGING=""
S_PHASE=starting S_STATE=running S_REASON="" S_CURRENT="" S_DEADLINE=0 S_HEARTBEAT=0 STARTED=0
declare -a PKGS=()

write_status() {
    local now tmp
    printf -v now '%(%s)T' -1
    tmp="$STATUS.tmp.$$"
    {
        printf 'schema=1\npid=%s\nrequest=%s\npackages=%s\ncurrent=%s\nphase=%s\nstate=%s\nreason=%s\n' \
            "$$" "$TOKEN" "$(IFS=,; printf '%s' "${PKGS[*]}")" "$S_CURRENT" "$S_PHASE" "$S_STATE" "$S_REASON"
        printf 'started=%s\ndeadline=%s\nheartbeat=%s\nupdated=%s\n' "$STARTED" "$S_DEADLINE" "$S_HEARTBEAT" "$now"
    } > "$tmp" 2>/dev/null && mv -f "$tmp" "$STATUS" 2>/dev/null
    return 0
}

alive() {
    local state
    [[ -r /proc/$1/stat ]] || return 1
    read -r _ _ state _ < "/proc/$1/stat" || return 1
    [[ $state != Z ]]
}

# Stop the running phase: TERM the `timeout` process group, escalate to KILL after the grace.
stop_phase() {
    local waited=0
    [[ -n $PHASE_PID ]] || return 0
    alive "$PHASE_PID" || return 0
    kill -TERM -- "-$PHASE_PID" 2>/dev/null || kill -TERM "$PHASE_PID" 2>/dev/null
    while alive "$PHASE_PID" && (( waited < GRACE * 10 )); do
        sleep 0.1
        waited=$((waited + 1))
    done
    if alive "$PHASE_PID"; then
        kill -KILL -- "-$PHASE_PID" 2>/dev/null || kill -KILL "$PHASE_PID" 2>/dev/null
    fi
    # Reap so no zombie keeps the descriptor view confusing; the group is dead by now.
    wait "$PHASE_PID" 2>/dev/null
}

on_signal() {
    trap '' TERM INT HUP
    if (( HAVE_LOCK )); then
        [[ -n $TICK_PID ]] && kill "$TICK_PID" 2>/dev/null
        stop_phase
        [[ -n $STAGING ]] && rm -rf -- "$STAGING"
        S_STATE=stopped S_PHASE=done S_REASON=""
        write_status
    fi
    exit 130
}

# 2. The trap is installed before the lock, the status file or staging are touched.
trap on_signal TERM INT HUP

# ---- arguments and library -------------------------------------------------------
(( $# >= 1 )) || { log "usage: annotation-install.sh <package> [<package> ...]"; exit 2; }
for p in "$@"; do
    [[ $p =~ ^[A-Za-z][A-Za-z0-9.]*$ ]] || { log "invalid package name"; exit 2; }
    PKGS+=("$p")
done
LIB=${RICHSTUDIO_ANNOTATION_LIB:-}
LIB=${LIB%/}
[[ $LIB == /* && $LIB != */../* && $LIB != */.. && -d $LIB && ! -L $LIB ]] || { log "RICHSTUDIO_ANNOTATION_LIB is not an absolute existing directory"; exit 2; }
TOKEN=${RICHSTUDIO_ANNOTATION_REQUEST:-}
if [[ -z $TOKEN ]]; then
    printf -v TOKEN 'sup%s%s' "$(date +%s)" "$$"
elif [[ ! $TOKEN =~ ^[A-Za-z0-9]{8,32}$ ]]; then
    log "invalid request token"; exit 2
fi
LOCK="$LIB.lock"
STATUS="$LIB.status"

# 3. One installer per library, held for this process's whole life by a kernel flock. The
# children inherit descriptor 9 on purpose (an orphaned worker keeps the lock until it ends).
exec 9>"$LOCK" || { log "cannot open the lock file $LOCK"; exit 1; }
flock -n 9 || exit 75
HAVE_LOCK=1

# 4. Sweep leftover staging: safe without an age rule because the lock is held.
shopt -s nullglob
for d in "$LIB"/.staging-*; do rm -rf -- "$d"; done
shopt -u nullglob

printf -v STARTED '%(%s)T' -1
S_HEARTBEAT=$STARTED

PHASE_RC=0
PHASE_ELAPSED=0
PHASE_LIMIT=0

# Run one worker phase under `timeout`, ticking the heartbeat without a second writer.
run_phase() {
    local ph=$1 base=$2 t0 t1 remaining finished
    printf -v t0 '%(%s)T' -1
    remaining=$((S_DEADLINE - t0))
    PHASE_LIMIT=$base
    if (( remaining <= 0 )); then PHASE_RC=124 PHASE_ELAPSED=0; return; fi
    (( base < remaining )) || PHASE_LIMIT=$remaining
    case $ph in
        prepare) S_PHASE=preparing ;; download) S_PHASE=downloading ;; install) S_PHASE=installing ;;
        validate) S_PHASE=validating ;; finalize) S_PHASE=finalizing ;;
    esac
    write_status
    if (( TEST_MODE )) && [[ -n $TEST_WORKER ]]; then
        RICHSTUDIO_PHASE_LIMIT=$PHASE_LIMIT timeout --signal=TERM --kill-after="$GRACE" "$PHASE_LIMIT" \
            "$TEST_WORKER" "$ph" "$pkg" "$STAGING" </dev/null &
    else
        RICHSTUDIO_PHASE_LIMIT=$PHASE_LIMIT timeout --signal=TERM --kill-after="$GRACE" "$PHASE_LIMIT" \
            "$RSCRIPT" --vanilla "$WORKER" "$ph" "$pkg" "$STAGING" </dev/null &
    fi
    PHASE_PID=$!
    # The tick is a plain sleep with descriptor 9 closed (it must never hold the lock).
    sleep "$TICK" 9>&- &
    TICK_PID=$!
    while :; do
        wait -n -p finished "$PHASE_PID" "$TICK_PID"
        PHASE_RC=$?
        if [[ $finished == "$PHASE_PID" ]]; then break; fi
        printf -v S_HEARTBEAT '%(%s)T' -1
        write_status
        sleep "$TICK" 9>&- &
        TICK_PID=$!
    done
    kill "$TICK_PID" 2>/dev/null
    wait "$TICK_PID" 2>/dev/null
    TICK_PID=""
    PHASE_PID=""
    printf -v t1 '%(%s)T' -1
    PHASE_ELAPSED=$((t1 - t0))
}

# Worker exit code -> OUTCOME (ok | present | fail) and REASON.
OUTCOME=ok REASON=""
map_rc() {
    local rc=$1
    OUTCOME=fail
    case $rc in
        0) OUTCOME=ok REASON="" ;;
        10) REASON=no_network ;;
        11) REASON=checksum_mismatch ;;
        12) REASON=not_enough_disk ;;
        13) REASON=dependency_missing ;;
        14) REASON=entry_invalid ;;
        15) REASON=index_no_md5 ;;
        16) REASON=unavailable ;;
        17) REASON=timed_out ;;
        20) OUTCOME=present REASON="" ;;
        124) REASON=timed_out ;;
        137) if (( PHASE_ELAPSED >= PHASE_LIMIT )); then REASON=timed_out; else REASON=internal_error; fi ;;
        *) REASON=internal_error ;;
    esac
}

finish_failed() {
    S_STATE=failed S_PHASE=done S_REASON=$1
    [[ -n $STAGING ]] && rm -rf -- "$STAGING"
    STAGING=""
    write_status
    log "failed: ${S_CURRENT}: $1"
    exit 1
}

# Per package, 2400 s deadline (OD-3); phases prepare, download, install, validate, finalize.
for pkg in "${PKGS[@]}"; do
    S_CURRENT=$pkg
    printf -v now '%(%s)T' -1
    S_DEADLINE=$((now + DEADLINE))
    STAGING="$LIB/.staging-$pkg-$$"
    mkdir -m 0700 -- "$STAGING" || finish_failed internal_error
    S_STATE=running S_PHASE=starting S_REASON=""
    write_status
    skip=0
    for ph in prepare download install validate finalize; do
        case $ph in
            prepare) lim=$LIMIT_PREPARE ;; download) lim=$LIMIT_DOWNLOAD ;; install) lim=$LIMIT_INSTALL ;;
            validate) lim=$LIMIT_VALIDATE ;; finalize) lim=$LIMIT_FINALIZE ;;
        esac
        run_phase "$ph" "$lim"
        map_rc "$PHASE_RC"
        case $OUTCOME in
            fail) finish_failed "$REASON" ;;
            present) skip=1; break ;;
        esac
    done
    rm -rf -- "$STAGING"
    STAGING=""
    (( skip )) && log "$pkg already present; nothing to install"
done

S_STATE=completed S_PHASE=done S_REASON="" S_CURRENT=""
write_status
exit 0
