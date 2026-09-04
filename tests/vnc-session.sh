#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_TMP=$(mktemp -d /tmp/orynquix-vnc-tests.XXXXXX)
TEST_HOME="$TEST_TMP/home"
mkdir -p "$TEST_HOME"
background_pid=''

cleanup() {
    if [[ "$background_pid" =~ ^[0-9]+$ ]] && kill -0 "$background_pid" 2>/dev/null; then
        kill -TERM "$background_pid" 2>/dev/null || true
        wait "$background_pid" 2>/dev/null || true
    fi
    case "$TEST_TMP" in
        /tmp/orynquix-vnc-tests.*) find "$TEST_TMP" -depth -delete ;;
    esac
}
trap cleanup EXIT

session_script="$PROJECT_ROOT/rootfs/scripts/vnc-session.sh"
tests=0
failures=0

check() {
    local description=$1
    shift
    tests=$((tests + 1))
    if "$@"; then
        printf 'ok %d - %s\n' "$tests" "$description"
    else
        printf 'not ok %d - %s\n' "$tests" "$description" >&2
        failures=$((failures + 1))
    fi
}

stopped_output="$TEST_TMP/stopped-output"
if HOME="$TEST_HOME" bash "$session_script" status 77 1280x720 24 >"$stopped_output" 2>&1; then
    stopped_rc=0
else
    stopped_rc=$?
fi
check 'stopped status uses the documented non-running exit code' test "$stopped_rc" -eq 3
check 'stopped status is machine readable' grep -Fxq state=stopped "$stopped_output"

injection_marker="$TEST_TMP/arithmetic-injection-ran"
payload='77+$(touch '"$injection_marker"')'
if HOME="$TEST_HOME" bash "$session_script" status "$payload" 1280x720 24 >/dev/null 2>&1; then
    injection_rc=0
else
    injection_rc=$?
fi
check 'malicious display input is rejected' test "$injection_rc" -eq 64
check 'display validation occurs before arithmetic evaluation' test ! -e "$injection_marker"

check 'invalid geometry is rejected' bash -c '! HOME="$1" bash "$2" status 77 1280-by-720 24 >/dev/null 2>&1' _ "$TEST_HOME" "$session_script"
check 'invalid depth is rejected' bash -c '! HOME="$1" bash "$2" status 77 1280x720 12 >/dev/null 2>&1' _ "$TEST_HOME" "$session_script"

fake_vnc="$TEST_TMP/Xtigervnc"
printf '#!/bin/sh\nsleep 30\n' >"$fake_vnc"
chmod +x "$fake_vnc"
"$fake_vnc" :77 &
background_pid=$!
state_dir="$TEST_HOME/.local/share/orynquix/state"
mkdir -p "$state_dir"
cat >"$state_dir/vnc-session.ini" <<EOF
pid=$background_pid
start_ticks=1
display=:77
port=5977
resolution=1280x720
depth=24
localhost=true
EOF
chmod 600 "$state_dir/vnc-session.ini"

stale_output="$TEST_TMP/stale-output"
HOME="$TEST_HOME" bash "$session_script" status 77 1280x720 24 >"$stale_output" 2>&1 || stale_rc=$?
check 'PID start-time mismatch is reported as stale' grep -Fxq state=stale "$stale_output"
check 'stale metadata never terminates a PID-reused process' kill -0 "$background_pid"

unregistered_output="$TEST_TMP/unregistered-output"
if HOME="$TEST_HOME" bash "$session_script" start 77 1280x720 24 >"$unregistered_output" 2>&1; then
    unregistered_rc=0
else
    unregistered_rc=$?
fi
check 'start refuses an active unregistered display' test "$unregistered_rc" -eq 4
check 'start never takes ownership of the unregistered process' kill -0 "$background_pid"

stop_stale_output="$TEST_TMP/stop-stale-output"
HOME="$TEST_HOME" bash "$session_script" stop 77 1280x720 24 >"$stop_stale_output" 2>&1
check 'stop recovers stale metadata without reporting a running session' grep -Fxq state=stopped "$stop_stale_output"
check 'stop never terminates the PID-reused process' kill -0 "$background_pid"

printf '1..%d\n' "$tests"
(( failures == 0 )) || exit 1
printf 'All %d VNC session safety tests passed.\n' "$tests"
